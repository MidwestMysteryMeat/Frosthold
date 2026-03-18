-- radiation.lua — Radiation exposure system for nuclear proximity danger
-- Nuclear buildings emit radiation in a radius. Colonists accumulate dose
-- over time. High dose causes radiation sickness (disease-like severity race).
-- Lead walls/doors block radiation. Distance attenuates exposure.
-- Runs as ECS system at priority 12 (after status effects).

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')

local Radiation = {}

---------------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------------

-- Radiation sources: building defIds that emit radiation when active.
-- radius: tiles of radiation reach
-- doseRate: rads/second at distance 0 (attenuates with distance)
local RADIATION_SOURCES = {
    nuclear_reactor = { radius = 6, doseRate = 0.08 },
    mini_reactor    = { radius = 4, doseRate = 0.04 },
    fusion_reactor  = { radius = 5, doseRate = 0.03 },
    plasma_arc      = { radius = 4, doseRate = 0.05 },
}

Radiation.SOURCES = RADIATION_SOURCES

-- Dose thresholds (accumulated rads)
local DOSE_MILD     = 20   -- mild sickness: nausea, work debuff
local DOSE_MODERATE = 50   -- moderate: vomiting, hair loss, health drain
local DOSE_SEVERE   = 80   -- severe: organ damage, high lethality
local DOSE_LETHAL   = 100  -- lethal threshold

-- Natural decay rate (rads/second when not exposed)
local DOSE_DECAY    = 0.005

-- Ambient planet radiation (applied to all outdoor colonists)
local AMBIENT_RADIATION = 0
do
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then
        AMBIENT_RADIATION = Planet.get('radiation.ambientDose', 0)
    end
end

-- How often we check (seconds) — throttled to avoid per-tick expense
local CHECK_INTERVAL = 2.0

---------------------------------------------------------------------------
-- Active radiation sources (populated from Building system)
---------------------------------------------------------------------------

local activeSources = {}  -- { {x, y, depth, radius, doseRate}, ... }
local sourceTimer = 0
local SOURCE_REFRESH = 5.0  -- seconds between source list refresh
local _ordnanceLoaded = false
local _Ordnance = nil

local function getOrdnance()
    if not _ordnanceLoaded then
        _ordnanceLoaded = true
        local ok, mod = pcall(require, 'src.combat.ordnance')
        if ok then _Ordnance = mod end
    end
    return _Ordnance
end

local function refreshSources()
    activeSources = {}
    local bok, Building = pcall(require, 'src.building.building')
    if not bok or not Building.getAll then return end

    for _, info in pairs(Building.getAll()) do
        if info.def and info.active ~= false then
            -- Find defId by scanning defs
            local defId
            for id, d in pairs(Building.defs) do
                if d == info.def then defId = id; break end
            end
            if defId and RADIATION_SOURCES[defId] then
                local src = RADIATION_SOURCES[defId]
                activeSources[#activeSources + 1] = {
                    x = info.x, y = info.y,
                    depth = info.depth or 0,
                    radius = src.radius,
                    doseRate = src.doseRate,
                }
            end
        end
    end
end

---------------------------------------------------------------------------
-- Shielding check: trace line from source to target, count lead walls
---------------------------------------------------------------------------

local function isShielded(sx, sy, tx, ty, depth)
    -- Simple Bresenham-ish: check tiles between source and target
    local World = require('src.world.tilemap')
    local dx = math.abs(tx - sx)
    local dy = math.abs(ty - sy)
    local stepX = sx < tx and 1 or -1
    local stepY = sy < ty and 1 or -1
    local err = dx - dy
    local cx, cy = sx, sy
    local shieldCount = 0

    while cx ~= tx or cy ~= ty do
        local e2 = err * 2
        if e2 > -dy then err = err - dy; cx = cx + stepX end
        if e2 < dx  then err = err + dx; cy = cy + stepY end
        if cx == tx and cy == ty then break end

        local tile = World.getTile(cx, cy, depth)
        local props = Tiles.get(tile)
        if props and props.radiationShield then
            shieldCount = shieldCount + 1
        end
        -- Any solid wall provides partial shielding
        if props and props.solid and not props.radiationShield then
            shieldCount = shieldCount + 0.3
        end
    end

    return shieldCount
end

---------------------------------------------------------------------------
-- Calculate radiation dose at a position from all active sources
---------------------------------------------------------------------------

function Radiation.getDoseRate(x, y, depth)
    local totalRate = 0
    for _, src in ipairs(activeSources) do
        if src.depth == depth then
            local dist = math.max(1, math.abs(x - src.x) + math.abs(y - src.y))
            if dist <= src.radius then
                -- Inverse distance falloff
                local falloff = 1.0 - (dist - 1) / src.radius
                local shielding = isShielded(src.x, src.y, x, y, depth)
                -- Each shield layer halves radiation
                local shieldMult = 1.0 / (2 ^ shielding)
                totalRate = totalRate + src.doseRate * falloff * shieldMult
            end
        end
    end
    local Ord = getOrdnance()
    if Ord and Ord.getFalloutDoseRate then
        totalRate = totalRate + Ord.getFalloutDoseRate(x, y, depth)
    end
    return totalRate
end

---------------------------------------------------------------------------
-- Query: get colonist radiation state
---------------------------------------------------------------------------

function Radiation.getDose(colonistId)
    local rad = ECS.get(colonistId, 'radiation')
    if not rad then return 0 end
    return rad.dose
end

function Radiation.getSeverityTier(dose)
    if dose >= DOSE_LETHAL   then return 'lethal' end
    if dose >= DOSE_SEVERE   then return 'severe' end
    if dose >= DOSE_MODERATE then return 'moderate' end
    if dose >= DOSE_MILD     then return 'mild' end
    return 'none'
end

function Radiation.getInfo(colonistId)
    local rad = ECS.get(colonistId, 'radiation')
    if not rad then return { dose = 0, tier = 'none', exposed = false } end
    return {
        dose    = rad.dose,
        tier    = Radiation.getSeverityTier(rad.dose),
        exposed = rad.currentRate > 0,
    }
end

---------------------------------------------------------------------------
-- ECS system: radiation exposure tick
---------------------------------------------------------------------------

local checkTimer = 0

local function radiationExposureSystem(dt, id, comps)
    local col = comps.colonist
    local pos = comps.pos
    if col.state == 'dead' then return end

    -- Ensure radiation component
    if not ECS.has(id, 'radiation') then
        ECS.set(id, 'radiation', { dose = 0, currentRate = 0, sickNotified = false })
    end
    local rad = ECS.get(id, 'radiation')

    -- Calculate current exposure rate
    local rate = Radiation.getDoseRate(pos.x, pos.y, pos.depth or 0)

    -- Ambient planet radiation applies to colonists outdoors (not in a sealed room)
    if AMBIENT_RADIATION > 0 then
        local World = require('src.world.tilemap')
        local roomId = World.getRoom(pos.x, pos.y, pos.depth or 0)
        if not roomId or roomId == 0 then
            rate = rate + AMBIENT_RADIATION
        end
    end

    rad.currentRate = rate

    if rate > 0 then
        -- Accumulate dose
        rad.dose = math.min(DOSE_LETHAL, rad.dose + rate * dt)
    else
        -- Decay when not exposed
        rad.dose = math.max(0, rad.dose - DOSE_DECAY * dt)
    end

    -- Apply effects based on dose tier
    local tier = Radiation.getSeverityTier(rad.dose)

    -- Apply radiation_sickness status effect at the correct severity for tier
    -- Use remove+apply to SET severity, not stack it
    local sok, StatusFx = pcall(require, 'src.sim.status_effects')
    if tier == 'mild' then
        if sok then
            StatusFx.remove(id, 'radiation_sickness')
            StatusFx.apply(id, 'radiation_sickness', 0.2)
        end
    elseif tier == 'moderate' then
        if sok then
            StatusFx.remove(id, 'radiation_sickness')
            StatusFx.apply(id, 'radiation_sickness', 0.5)
        end
        -- Occasional vomiting
        if math.random() < 0.003 * dt then
            local filthOk, Filth = pcall(require, 'src.sim.filth')
            if filthOk then Filth.onVomit(pos.x, pos.y) end
        end
    elseif tier == 'severe' then
        if sok then
            StatusFx.remove(id, 'radiation_sickness')
            StatusFx.apply(id, 'radiation_sickness', 0.8)
        end
        -- Health drain
        col.health = math.max(0, col.health - 0.15 * dt)
    elseif tier == 'none' then
        -- Clear radiation sickness when dose drops
        if sok then StatusFx.remove(id, 'radiation_sickness') end
    elseif tier == 'lethal' then
        -- Fatal radiation — kill colonist
        local cok, ColMod = pcall(require, 'src.colonist.colonist')
        if cok then ColMod.kill(id) end

        local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if stOk and Storyteller.logEvent then
            Storyteller.logEvent('death', (col.name or 'A colonist') .. ' died of acute radiation poisoning.')
        end
        return
    end

    -- Notify storyteller on first sickness
    if tier ~= 'none' and not rad.sickNotified then
        rad.sickNotified = true
        local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if stOk and Storyteller.logEvent then
            Storyteller.logEvent('radiation', (col.name or 'A colonist') .. ' is showing signs of radiation sickness.')
        end
    end
    if tier == 'none' and rad.sickNotified then
        rad.sickNotified = false
    end
end

---------------------------------------------------------------------------
-- ECS system: creature radiation exposure tick
-- Creatures with radiationImmune species trait skip radiation entirely.
---------------------------------------------------------------------------

local _speciesDefsLoaded = false
local _speciesDefs = nil

local function getSpeciesDefs()
    if not _speciesDefsLoaded then
        _speciesDefsLoaded = true
        local ok, defs = pcall(require, 'src.creatures.species_defs')
        if ok then _speciesDefs = defs end
    end
    return _speciesDefs
end

local function creatureRadiationSystem(dt, id, comps)
    local cr  = comps.creature
    local pos = comps.pos

    -- Skip dead creatures
    if cr.health and cr.health <= 0 then return end

    -- Check species-level radiation immunity
    local defs = getSpeciesDefs()
    if defs then
        local specDef = defs[cr.species]
        if specDef and specDef.radiationImmune then return end
    end

    -- Calculate current exposure rate at creature position
    local rate = Radiation.getDoseRate(pos.x, pos.y, pos.depth or 0)

    -- Ambient planet radiation for outdoor creatures
    if AMBIENT_RADIATION > 0 then
        local wok, World = pcall(require, 'src.world.tilemap')
        if wok then
            local roomId = World.getRoom(pos.x, pos.y, pos.depth or 0)
            if not roomId or roomId == 0 then
                rate = rate + AMBIENT_RADIATION
            end
        end
    end

    if rate <= 0 then return end

    -- Apply radiation as direct health damage (creatures have no dose tracking)
    -- Scale: at full dose rate, creature loses health proportional to exposure
    local dmg = rate * dt * 50  -- 50x multiplier: same lethality curve as colonists
    cr.health = math.max(0, cr.health - dmg)
end

---------------------------------------------------------------------------
-- Source refresh system (runs once, refreshes source list periodically)
---------------------------------------------------------------------------

local function radiationSourceRefreshSystem(dt)
    sourceTimer = sourceTimer + dt
    if sourceTimer >= SOURCE_REFRESH then
        sourceTimer = 0
        refreshSources()
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Radiation.registerSystems()
    -- Per-colonist radiation exposure (priority 12, after status effects)
    ECS.addSystem('radiation_exposure',
        { 'colonist', 'pos' },
        radiationExposureSystem, 12)

    -- Per-creature radiation exposure (priority 12, after status effects)
    ECS.addSystem('creature_radiation_exposure',
        { 'creature', 'pos' },
        creatureRadiationSystem, 12)
end

Radiation.registerSystems()

-- Hook into main step for source refresh (non-ECS periodic)
Radiation.step = radiationSourceRefreshSystem

return Radiation
