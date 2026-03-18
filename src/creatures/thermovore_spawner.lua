-- thermovore_spawner.lua — Underground thermovore emergence system
-- Thermovores spawn at depth > 0 in response to seismic noise (mining,
-- drilling, building) and thermal energy (reactor heat, steam hubs).
-- Think Dune sandworms: dig too greedily and too deep, they come.
-- Late game they swarm in large numbers from below.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Spawner = {}

---------------------------------------------------------------------------
-- Seismic noise accumulator (per depth layer)
---------------------------------------------------------------------------

local seismicNoise = {}  -- seismicNoise[depth] = { total, x, y }
local NOISE_DECAY      = 0.4   -- noise lost per second
local SPAWN_THRESHOLD  = 5.0   -- noise needed to trigger a spawn
local CHECK_INTERVAL   = 3.0   -- seconds between spawn checks
local THERMAL_INTERVAL = 60.0  -- seconds between thermal attraction checks
local checkTimer       = CHECK_INTERVAL
local thermalTimer     = THERMAL_INTERVAL

-- Mining intensity by depth — deeper = more sensitive
local function depthSensitivity(depth)
    return 1.0 + (depth or 0) * 0.5
end

--- Called when a noisy action occurs underground.
--- Sources: mining (1.0), building (1.5), deep drilling (2.0).
function Spawner.onNoise(x, y, depth, intensity)
    local d = depth or 0
    if d < 1 then return end  -- surface noise doesn't attract thermovores

    local entry = seismicNoise[d]
    if not entry then
        entry = { total = 0, x = x, y = y }
        seismicNoise[d] = entry
    end

    local scaled = (intensity or 1.0) * depthSensitivity(d)
    entry.total = entry.total + scaled
    -- Weighted average of noise source position
    local w = scaled / (entry.total + 0.01)
    entry.x = entry.x + (x - entry.x) * w
    entry.y = entry.y + (y - entry.y) * w
end

---------------------------------------------------------------------------
-- Species pool by depth
---------------------------------------------------------------------------

local function pickSpecies(depth, day)
    -- Deeper and later = bigger thermovores
    local d = depth or 1
    local small  = { 'cinder_mite', 'heat_skipper' }
    local med    = { 'char_hound', 'bore_beetle', 'razorjaw', 'spine_lurker' }
    local mega   = { 'hive_matron', 'gorge_worm', 'iron_carapace' }

    local roll = math.random()

    if d == 1 then
        if day < 20 then
            return small[math.random(#small)]
        elseif day < 40 then
            if roll < 0.3 then return small[math.random(#small)]
            else return med[math.random(#med)] end
        else
            if roll < 0.15 then return small[math.random(#small)]
            elseif roll < 0.75 then return med[math.random(#med)]
            else return mega[math.random(#mega)] end
        end
    elseif d == 2 then
        if day < 30 then
            if roll < 0.3 then return small[math.random(#small)]
            else return med[math.random(#med)] end
        else
            if roll < 0.1 then return small[math.random(#small)]
            elseif roll < 0.6 then return med[math.random(#med)]
            else return mega[math.random(#mega)] end
        end
    else -- depth 3+
        if roll < 0.4 then return med[math.random(#med)]
        else return mega[math.random(#mega)] end
    end
end

local function packCount(speciesId)
    local Creatures = require('src.creatures.creatures')
    local sp = Creatures.SPECIES[speciesId]
    if sp and sp.packSize then
        return math.random(sp.packSize[1], sp.packSize[2])
    end
    return 1
end

---------------------------------------------------------------------------
-- Spawn thermovores near a noise epicenter
---------------------------------------------------------------------------

local function spawnNear(x, y, depth, count, speciesId)
    local tok, World = pcall(require, 'src.world.tilemap')
    if not tok then return end
    if not World.hasLayer(depth) then return end

    local Creatures = require('src.creatures.creatures')
    local w, h = World.width(), World.height()
    local spawned = 0

    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + math.random() * 0.8
        local dist = 8 + math.random(12)
        local sx = math.floor(x + math.cos(angle) * dist)
        local sy = math.floor(y + math.sin(angle) * dist)
        sx = math.max(2, math.min(w - 2, sx))
        sy = math.max(2, math.min(h - 2, sy))

        if World.isWalkable(sx, sy, depth) then
            Creatures.spawn(speciesId, sx, sy, depth)
            spawned = spawned + 1
        end
    end
    return spawned
end

---------------------------------------------------------------------------
-- Seismic check — noise accumulator triggers spawns
---------------------------------------------------------------------------

local function checkSeismic(elapsed)
    local day = GameState.day

    for depth, entry in pairs(seismicNoise) do
        -- Decay noise over the full interval
        entry.total = math.max(0, entry.total - NOISE_DECAY * elapsed)

        if entry.total >= SPAWN_THRESHOLD then
            -- Cap total creatures on the map (skip spawn, but still decay)
            local total = ECS.countWith('creature')
            if total >= 40 then
                -- Don't spawn but consume some noise to prevent permanent backlog
                entry.total = entry.total * 0.5
            else
                -- Consume noise and spawn
                entry.total = entry.total - SPAWN_THRESHOLD
                local sp = pickSpecies(depth, day)
                local count = packCount(sp)
                spawnNear(entry.x, entry.y, depth, count, sp)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Thermal attraction — colony heat draws thermovores from below
---------------------------------------------------------------------------

local function checkThermalAttraction()
    local day = GameState.day
    if day < 15 then return end  -- too early for thermal attraction

    -- Use colony heat signature as attraction factor
    local rok, Raids = pcall(require, 'src.sim.raids')
    local heatSig = 0
    if rok and Raids.getHeatSignature then
        heatSig = Raids.getHeatSignature()
    end
    if heatSig < 30 then return end  -- not enough heat to attract

    -- Higher heat = higher chance (scales 0.05 at sig 30 to 0.4 at sig 100+)
    local chance = math.min(0.4, (heatSig - 20) / 200)
    if math.random() > chance then return end

    -- Cap total creatures
    local total = ECS.countWith('creature')
    if total >= 40 then return end

    -- Find the deepest active layer
    local tok, World = pcall(require, 'src.world.tilemap')
    if not tok then return end
    local maxDepth = World.getMaxDepth and World.getMaxDepth() or 0
    if maxDepth < 1 then return end

    -- Spawn at a random active underground depth
    local depth = math.random(1, maxDepth)
    if not World.hasLayer(depth) then return end

    -- Spawn near map center (drawn toward the colony's heat)
    local w, h = World.width(), World.height()
    local cx = math.floor(w / 2) + math.random(-15, 15)
    local cy = math.floor(h / 2) + math.random(-15, 15)

    local sp = pickSpecies(depth, day)
    local count = packCount(sp)
    -- Late game: larger packs
    if day > 40 then count = count + math.random(1, 3) end
    if day > 60 then count = count + math.random(2, 4) end

    spawnNear(cx, cy, depth, count, sp)
end

---------------------------------------------------------------------------
-- Step (called from main loop tick)
---------------------------------------------------------------------------

function Spawner.step(dt)
    -- Seismic noise check
    checkTimer = checkTimer - dt
    if checkTimer <= 0 then
        local elapsed = CHECK_INTERVAL
        checkTimer = CHECK_INTERVAL
        checkSeismic(elapsed)
    end

    -- Thermal attraction check
    thermalTimer = thermalTimer - dt
    if thermalTimer <= 0 then
        thermalTimer = THERMAL_INTERVAL
        checkThermalAttraction()
    end
end

---------------------------------------------------------------------------
-- Save/load — persist noise state
---------------------------------------------------------------------------

function Spawner.getState()
    return {
        seismicNoise = seismicNoise,
        checkTimer   = checkTimer,
        thermalTimer = thermalTimer,
    }
end

function Spawner.loadState(state)
    if not state then return end
    seismicNoise = state.seismicNoise or {}
    checkTimer   = state.checkTimer or CHECK_INTERVAL
    thermalTimer = state.thermalTimer or THERMAL_INTERVAL
end

return Spawner
