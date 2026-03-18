-- deep_drill.lua — Deep drilling machine for rare resource extraction
-- Placed on PERMAFROST or ROCK tiles. Requires 50W power, fully automated.
-- Produces thermal_cores, rare_ore, and ancient_artifacts over time.
-- Operating the drill generates noise that attracts hostile creatures.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')
local Power     = require('src.sim.power')
local Production = require('src.building.production')

local DeepDrill = {}

-- Lazy-loaded modules (avoid pcall in drill tick system)
local _AnomalyMod
local function lazyLoadDrill()
    if _AnomalyMod ~= nil then return end
    local ok
    ok, _AnomalyMod = pcall(require, 'src.sim.anomaly')
    if not ok then _AnomalyMod = false end
end

---------------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------------

local DRILL_POWER     = 50    -- watts required
local RESEARCH_TIER   = 4     -- research tier required to unlock
local CYCLE_TIME      = 20    -- seconds per extraction cycle
local NOISE_RADIUS    = 30    -- tiles — creature attraction range
local NOISE_INTERVAL  = 45    -- seconds between noise checks
local CREATURE_CHANCE = 0.25  -- chance per noise check to attract a creature

-- What the drill can extract and at what relative weights
local DRILL_OUTPUTS = {
    { itemId = 'thermal_core', min = 1, max = 3, weight = 40 },
    { itemId = 'raw_ore',      min = 2, max = 5, weight = 35 },
    { itemId = 'coal',         min = 2, max = 4, weight = 15 },
    { itemId = 'components',   min = 1, max = 2, weight = 7 },
    { itemId = 'lead',         min = 1, max = 3, weight = 8 },
    { itemId = 'circuit',      min = 1, max = 1, weight = 3 },
}

-- Seabed drill outputs (Nerthus-9 underwater)
local SEABED_OUTPUTS = {
    { itemId = 'metal',      min = 3, max = 6, weight = 30 },
    { itemId = 'stone',      min = 2, max = 5, weight = 20 },
    { itemId = 'components', min = 1, max = 3, weight = 15 },
    { itemId = 'food',       min = 2, max = 4, weight = 10 },  -- coral/kelp byproduct
    { itemId = 'fuel',       min = 1, max = 3, weight = 10 },  -- brine extraction
    { itemId = 'glass',      min = 1, max = 2, weight = 8 },   -- silica from seabed
    { itemId = 'lead',       min = 1, max = 2, weight = 5 },
    { itemId = 'circuit',    min = 1, max = 1, weight = 2 },   -- wreckage salvage
}

local DRILL_TOTAL_WEIGHT = 0
for _, entry in ipairs(DRILL_OUTPUTS) do
    DRILL_TOTAL_WEIGHT = DRILL_TOTAL_WEIGHT + entry.weight
end

local SEABED_TOTAL_WEIGHT = 0
for _, entry in ipairs(SEABED_OUTPUTS) do
    SEABED_TOTAL_WEIGHT = SEABED_TOTAL_WEIGHT + entry.weight
end

DeepDrill.DRILL_POWER    = DRILL_POWER
DeepDrill.RESEARCH_TIER  = RESEARCH_TIER
DeepDrill.CYCLE_TIME     = CYCLE_TIME

---------------------------------------------------------------------------
-- Register drill as a machine and item
---------------------------------------------------------------------------

if not Production.MACHINES.deep_drill then
    Production.MACHINES.deep_drill = {
        name      = 'Deep Drill',
        size      = { 2, 2 },
        cost      = { steel = 8, components = 5, circuit = 2 },
        powerDraw = DRILL_POWER,
    }
end

if not Production.ITEMS.rare_ore then
    Production.ITEMS.rare_ore = {
        name     = 'Rare Ore',
        stack    = 20,
        category = 'raw',
    }
end

if not Production.ITEMS.ancient_artifact then
    Production.ITEMS.ancient_artifact = {
        name     = 'Ancient Artifact',
        stack    = 5,
        category = 'advanced',
    }
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Weighted random pick from drill output table.
local function rollDrillOutput()
    -- Use seabed outputs on Nerthus-9
    local outputs = DRILL_OUTPUTS
    local totalWeight = DRILL_TOTAL_WEIGHT
    local pok2, Planet2 = pcall(require, 'src.world.planet')
    if pok2 and Planet2.getId() == 'nerthus_9' then
        outputs = SEABED_OUTPUTS
        totalWeight = SEABED_TOTAL_WEIGHT
    end

    local roll = math.random() * totalWeight
    local acc = 0
    for _, entry in ipairs(outputs) do
        acc = acc + entry.weight
        if roll <= acc then
            local amount = math.random(entry.min, entry.max)
            return entry.itemId, amount
        end
    end
    local last = outputs[#outputs]
    return last.itemId, last.min
end

-- Check if a tile is valid for deep drill placement.
local function isValidDrillTile(x, y, depth)
    local World = require('src.world.tilemap')
    if not World.inBounds(x, y) then return false end
    local tile = World.getTile(x, y, depth or 0)
    -- Standard drill: permafrost or rock
    if tile == Tiles.PERMAFROST or tile == Tiles.ROCK then return true end
    -- Seabed drill: underwater rock, coral deposits, mineral nodules (any minable underwater tile)
    if tile == Tiles.UNDERGROUND_ROCK or tile == Tiles.CORAL_DEPOSIT
        or tile == Tiles.MINERAL_NODULE or tile == Tiles.THERMAL_MINERAL
        or tile == Tiles.SANDSTONE or tile == Tiles.REGOLITH then
        return true
    end
    return false
end

DeepDrill.isValidDrillTile = isValidDrillTile

---------------------------------------------------------------------------
-- Placement
---------------------------------------------------------------------------

-- Place a deep drill at (x, y). Validates tile type and resource cost.
-- Returns entity ID or nil, error.
function DeepDrill.place(x, y, depth)
    depth = depth or 0
    local World = require('src.world.tilemap')
    local machineDef = Production.MACHINES.deep_drill
    local sizeW, sizeH = machineDef.size[1], machineDef.size[2]

    -- Validate all tiles under the drill footprint
    for dy = 0, sizeH - 1 do
        for dx = 0, sizeW - 1 do
            local tx, ty = x + dx, y + dy
            if not World.inBounds(tx, ty) then
                return nil, 'Out of bounds'
            end
            if not isValidDrillTile(tx, ty, depth) then
                return nil, 'Must be placed on drillable ground'
            end
        end
    end

    -- Cost is handled by Building.tryPlace — do not charge again here

    local id = ECS.spawn()

    ECS.set(id, 'pos', { x = x, y = y, depth = depth })

    ECS.set(id, 'deep_drill', {
        progress     = 0,
        cycleTime    = CYCLE_TIME,
        active       = false,
        powered      = false,
        operatorId   = nil,       -- colonist entity ID operating the drill
        noiseTimer   = NOISE_INTERVAL,
        totalCycles  = 0,
        outputBuf    = {},         -- { [itemId] = count }
    })

    ECS.set(id, 'machine', {
        type       = 'deep_drill',
        name       = 'Deep Drill',
        recipe     = nil,
        inputBuf   = {},
        outputBuf  = {},
        progress   = 0,
        active     = false,
        powered    = false,
        assignee   = nil,
    })

    -- Register as power consumer
    Power.addConsumer(id, DRILL_POWER, x, y)

    return id
end

-- Remove a deep drill entity.
function DeepDrill.remove(drillEntityId)
    Power.removeConsumer(drillEntityId)
    ECS.destroy(drillEntityId)
end

---------------------------------------------------------------------------
-- Assign / unassign operator
---------------------------------------------------------------------------

function DeepDrill.assignOperator(drillEntityId, colonistId)
    local drill = ECS.get(drillEntityId, 'deep_drill')
    if not drill then return false end

    local col = ECS.get(colonistId, 'colonist')
    if not col then return false end

    drill.operatorId = colonistId
    return true
end

function DeepDrill.unassignOperator(drillEntityId)
    local drill = ECS.get(drillEntityId, 'deep_drill')
    if not drill then return end
    drill.operatorId = nil
end

---------------------------------------------------------------------------
-- Resource delivery helpers
---------------------------------------------------------------------------

-- Deep drill no longer delivers directly to GameState.resources.
-- Output goes to machine.outputBuf, which inserters can pull from.
-- If no inserter is attached, production.lua's autoStock flushes
-- machine.outputBuf to colony resources every 3 seconds.

---------------------------------------------------------------------------
-- Noise / creature attraction
---------------------------------------------------------------------------

local function attractCreature(drillPos)
    local Creatures = require('src.creatures.creatures')
    local World = require('src.world.tilemap')

    local pd = drillPos.depth or 0

    -- Creature pool depends on planet and depth
    local hostilePool
    local pok, Planet = pcall(require, 'src.world.planet')
    local planetId = pok and Planet.getId() or 'erebus'

    if planetId == 'nerthus_9' then
        -- Underwater drilling attracts ocean predators
        if pd > 0 then
            hostilePool = { 'depth_lurker', 'reef_shark', 'pressure_eel', 'kraken_spawn', 'abyssal_hunter' }
        else
            hostilePool = { 'reef_shark', 'tide_crab', 'depth_lurker' }
        end
    elseif pd > 0 then
        -- Underground drilling attracts thermovores (Erebus default)
        hostilePool = { 'char_hound', 'bore_beetle', 'razorjaw', 'spine_lurker' }
    else
        hostilePool = { 'tundra_wolf', 'ice_stalker', 'glacier_bear' }
    end

    -- Planet creature pool filter: only spawn species that exist on this planet
    local pools = pok and Planet.getCreaturePools() or nil
    if pools then
        local filtered = {}
        for _, sp in ipairs(hostilePool) do
            for _, pp in ipairs(pools) do
                if sp == pp then filtered[#filtered + 1] = sp; break end
            end
        end
        if #filtered > 0 then hostilePool = filtered end
    end
    local speciesId = hostilePool[math.random(#hostilePool)]

    -- Spawn at edge of noise radius
    local angle = math.random() * math.pi * 2
    local dist = NOISE_RADIUS * (0.6 + math.random() * 0.4)
    local sx = math.floor(drillPos.x + math.cos(angle) * dist)
    local sy = math.floor(drillPos.y + math.sin(angle) * dist)

    local w, h = World.width(), World.height()
    sx = math.max(2, math.min(w - 2, sx))
    sy = math.max(2, math.min(h - 2, sy))

    if World.isWalkable(sx, sy, pd) then
        Creatures.spawn(speciesId, sx, sy, pd)
    end

    -- Drilling also feeds the thermovore seismic noise system
    if pd > 0 then
        local tsOk, TSpawn = pcall(require, 'src.creatures.thermovore_spawner')
        if tsOk then TSpawn.onNoise(drillPos.x, drillPos.y, pd, 2.0) end
    end
end

---------------------------------------------------------------------------
-- ECS system: deep drill tick
---------------------------------------------------------------------------

local function deepDrillSystem(dt, id, comps)
    local drill = comps.deep_drill
    local machine = comps.machine
    local pos = comps.pos

    -- Check power status from the machine component (updated by Power.step)
    drill.powered = machine and machine.powered or false

    -- Fully automated — only needs power
    if not drill.powered then
        drill.active = false
        return
    end

    drill.active = true

    -- Optional operator gives speed bonus but is not required
    local speedMult = 1.0
    if machine and machine.assignee and ECS.isAlive(machine.assignee) then
        drill.operatorId = machine.assignee
        local col = ECS.get(machine.assignee, 'colonist')
        if col and col.skills then
            local miningSkill = col.skills.mining or 1
            speedMult = math.max(1.0, 1.0 + (miningSkill - 1) * 0.10)
        end
    else
        drill.operatorId = nil
    end

    -- Advance extraction cycle
    drill.progress = drill.progress + dt * speedMult
    if drill.progress >= drill.cycleTime then
        drill.progress = drill.progress - drill.cycleTime
        drill.totalCycles = drill.totalCycles + 1

        -- Roll output — write to machine.outputBuf for inserter compatibility
        local itemId, amount = rollDrillOutput()
        if machine then
            machine.outputBuf[itemId] = (machine.outputBuf[itemId] or 0) + amount
        end

        -- Drilling disturbs the deep: raise anomaly level
        lazyLoadDrill()
        if _AnomalyMod and _AnomalyMod.onDrillCycle then
            _AnomalyMod.onDrillCycle()
        end

        if math.random() < 0.08 then
            local cok, Containment = pcall(require, 'src.sim.containment')
            if cok and Containment.registerFieldSubject then
                local template = ({ 'resonant_shard', 'signal_idol', 'node_sample', 'thrall_prisoner', 'vessel_host' })[math.random(5)]
                Containment.registerFieldSubject(template, {
                    source = 'deep drill extraction',
                    originX = pos.x,
                    originY = pos.y,
                    originDepth = pos.depth or 0,
                })
            end
        end
    end

    -- Noise mechanic: attract creatures periodically while operating
    drill.noiseTimer = drill.noiseTimer - dt
    if drill.noiseTimer <= 0 then
        drill.noiseTimer = NOISE_INTERVAL
        if math.random() < CREATURE_CHANCE then
            attractCreature(pos)
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function DeepDrill.registerSystems()
    ECS.addSystem('deep_drill', { 'deep_drill', 'machine', 'pos' }, deepDrillSystem, 16)
end

DeepDrill.registerSystems()

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function DeepDrill.getDrill(entityId)
    return ECS.get(entityId, 'deep_drill')
end

function DeepDrill.isActive(entityId)
    local drill = ECS.get(entityId, 'deep_drill')
    return drill and drill.active
end

function DeepDrill.getProgress(entityId)
    local drill = ECS.get(entityId, 'deep_drill')
    if not drill then return 0 end
    return drill.progress / drill.cycleTime
end

function DeepDrill.getAllDrills()
    local result = {}
    for id, comps in ECS.query('deep_drill', 'pos') do
        result[#result + 1] = {
            id    = id,
            pos   = comps.pos,
            drill = comps.deep_drill,
        }
    end
    return result
end

return DeepDrill
