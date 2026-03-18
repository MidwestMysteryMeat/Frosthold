-- baldrungen.lua -- Baldrungen escalation system (Gaia A^1x)
-- Insectoid undead spawn waves increase each corruption season.
-- After 5 corruption cycles, Baldrungen fully awakens.
-- Containment artifacts can shield the colony: enough contained specimens
-- create a ward that suppresses corruption, preventing the fall ending.
-- Without artifacts, the world is lost.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Baldrungen = {}

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

local FINAL_CYCLE         = 5      -- Baldrungen fully awakens after this many corruption seasons
local SPAWN_MIN_INTERVAL  = 30     -- seconds between wave spawns (minimum)
local SPAWN_MAX_INTERVAL  = 60     -- seconds between wave spawns (maximum)
local ARTIFACTS_TO_SHIELD = 3      -- contained artifacts needed to ward off corruption
local SHIELD_SPAWN_REDUCTION = 0.7 -- spawn rate multiplied by (1 - this) when shielded

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local active           = false
local corruptionCycles = 0
local prevSeason       = nil
local spawnTimer       = 0
local nextSpawnDelay   = 0
local endingTriggered  = false

---------------------------------------------------------------------------
-- Init -- check planet, activate only on Gaia A^1x
---------------------------------------------------------------------------

function Baldrungen.init()
    active = (GameState.planet == 'gaia_a1x')
    corruptionCycles = 0
    prevSeason = GameState.season
    spawnTimer = 0
    nextSpawnDelay = SPAWN_MIN_INTERVAL + math.random() * (SPAWN_MAX_INTERVAL - SPAWN_MIN_INTERVAL)
    endingTriggered = false
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function pickEdgePosition()
    local wok, World = pcall(require, 'src.world.tilemap')
    if not wok then return nil, nil end

    local w, h = World.width(), World.height()
    local side = math.random(4)
    local x, y
    if side == 1 then     x = math.random(5, 15);          y = math.random(5, h - 5)
    elseif side == 2 then x = math.random(w - 15, w - 5);  y = math.random(5, h - 5)
    elseif side == 3 then x = math.random(5, w - 5);       y = math.random(5, 15)
    else                  x = math.random(5, w - 5);       y = math.random(h - 15, h - 5)
    end

    if World.isWalkable(x, y, 0) then
        return x, y
    end
    return nil, nil
end

local function spawnWave(cycle)
    local cok, Creatures = pcall(require, 'src.creatures.creatures')
    if not cok then return end

    local x, y = pickEdgePosition()
    if not x then return end

    if cycle <= 1 then
        -- Small packs of husk_crawlers (2-4)
        local count = math.random(2, 4)
        Creatures.spawnPack('husk_crawler', x, y, count)
    elseif cycle == 2 then
        -- husk_crawlers + bone_beetles (3-5 total)
        local total = math.random(3, 5)
        local crawlers = math.random(1, math.max(1, total - 1))
        local beetles = total - crawlers
        Creatures.spawnPack('husk_crawler', x, y, crawlers)
        if beetles > 0 then
            Creatures.spawnPack('bone_beetle', x, y, beetles)
        end
    elseif cycle == 3 then
        -- husk_crawlers + bone_beetles + rot_wasps (4-7 total)
        local total = math.random(4, 7)
        local crawlers = math.random(1, math.max(1, math.floor(total * 0.4)))
        local beetles = math.random(1, math.max(1, math.floor(total * 0.3)))
        local wasps = math.max(1, total - crawlers - beetles)
        Creatures.spawnPack('husk_crawler', x, y, crawlers)
        Creatures.spawnPack('bone_beetle', x, y, beetles)
        Creatures.spawnPack('rot_wasp', x, y, wasps)
    else
        -- Cycle 4+: above + brood_mothers, the_emergence (massive swarm)
        local total = math.random(6, 10) + (cycle - 4) * 2
        local crawlers = math.random(2, 4)
        local beetles = math.random(1, 3)
        local wasps = math.random(1, 3)
        local heavies = math.max(1, total - crawlers - beetles - wasps)
        Creatures.spawnPack('husk_crawler', x, y, crawlers)
        Creatures.spawnPack('bone_beetle', x, y, beetles)
        Creatures.spawnPack('rot_wasp', x, y, wasps)

        -- Split heavies between brood_mothers and the_emergence
        local broodCount = math.floor(heavies * 0.6 + 0.5)
        local emergeCount = heavies - broodCount
        if broodCount > 0 then
            Creatures.spawnPack('brood_mother', x, y, broodCount)
        end
        if emergeCount > 0 then
            Creatures.spawnPack('the_emergence', x, y, emergeCount)
        end
    end

    -- Notify player
    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        if cycle >= FINAL_CYCLE then
            Alerts.send('The Emergence',
                'Baldrungen tears through the surface. The end has come.',
                'critical')
        elseif cycle >= 3 then
            Alerts.send('Baldrungen Swarm',
                'A massive wave of insectoid undead erupts from the corrupted ground.',
                'major')
        else
            Alerts.send('Corruption Wave',
                'Insectoid undead crawl from the earth.',
                'minor')
        end
    end
end

--- Count contained artifacts/specimens that ward against Baldrungen.
--- Checks containment cells + anomaly lockers for sealed subjects.
local function countContainedArtifacts()
    local count = 0
    local cok, Containment = pcall(require, 'src.sim.containment')
    if cok and Containment.getContainedCount then
        count = Containment.getContainedCount()
    else
        -- Fallback: count entities with containment_cell component that have a subject
        for _, comps in ECS.query('containment_cell') do
            if comps.containment_cell and comps.containment_cell.subjectId then
                count = count + 1
            end
        end
    end
    return count
end

--- Returns true if colony has enough contained artifacts to ward off corruption.
function Baldrungen.isShielded()
    return countContainedArtifacts() >= ARTIFACTS_TO_SHIELD
end

local function triggerEnding()
    if endingTriggered then return end

    -- Artifacts ward off corruption — colony survives if shielded
    if Baldrungen.isShielded() then
        local aok, Alerts = pcall(require, 'src.ui.alerts')
        if aok and Alerts.send then
            Alerts.send('Corruption Warded',
                'The contained artifacts pulse with energy. Baldrungen recoils. The corruption recedes — for now. The colony stands.',
                'major')
        end
        -- Don't end the game — escalation continues but colony is protected
        -- Reduce spawn intensity while shielded
        return
    end

    endingTriggered = true
    GameState.endlessMode = 'baldrungen_fall'

    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send('Baldrungen Falls',
            'The ground opens. Baldrungen has fully awakened. Gaia A^1x is lost. Contain artifacts to ward against corruption in future attempts.',
            'critical')
    end
end

---------------------------------------------------------------------------
-- Step -- called each sim tick with dt
---------------------------------------------------------------------------

function Baldrungen.step(dt)
    if not active then return end
    if endingTriggered then return end

    -- Detect season transition to 'corruption'
    local currentSeason = GameState.season
    if currentSeason == 'corruption' and prevSeason ~= 'corruption' then
        corruptionCycles = corruptionCycles + 1

        -- After final cycle: attempt ending (artifacts can ward it off)
        if corruptionCycles >= FINAL_CYCLE then
            triggerEnding()
            -- If ending was warded off, continue with massive but reduced spawns
            if not endingTriggered then
                spawnWave(corruptionCycles)
            else
                -- One last massive wave as the world falls
                spawnWave(corruptionCycles)
                prevSeason = currentSeason
                return
            end
        end
    end
    prevSeason = currentSeason

    -- During corruption season, spawn waves on a timer
    if currentSeason == 'corruption' and corruptionCycles > 0 then
        local shielded = Baldrungen.isShielded()

        spawnTimer = spawnTimer + dt
        -- Shielded colonies get slower spawn rates
        local effectiveDelay = nextSpawnDelay
        if shielded then
            effectiveDelay = nextSpawnDelay / (1 - SHIELD_SPAWN_REDUCTION)
        end

        if spawnTimer >= effectiveDelay then
            spawnTimer = spawnTimer - effectiveDelay
            nextSpawnDelay = SPAWN_MIN_INTERVAL + math.random() * (SPAWN_MAX_INTERVAL - SPAWN_MIN_INTERVAL)

            -- Shielded colonies face reduced wave sizes (cap at cycle 3 intensity)
            local effectiveCycle = corruptionCycles
            if shielded and effectiveCycle > 3 then
                effectiveCycle = 3
            end
            spawnWave(effectiveCycle)
        end
    else
        -- Reset timer outside corruption season
        spawnTimer = 0
    end
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Baldrungen.getState()
    return {
        active           = active,
        corruptionCycles = corruptionCycles,
        prevSeason       = prevSeason,
        spawnTimer       = spawnTimer,
        nextSpawnDelay   = nextSpawnDelay,
        endingTriggered  = endingTriggered,
    }
end

function Baldrungen.loadState(data)
    if not data then return end
    active           = data.active or false
    corruptionCycles = data.corruptionCycles or 0
    prevSeason       = data.prevSeason
    spawnTimer       = data.spawnTimer or 0
    nextSpawnDelay   = data.nextSpawnDelay or SPAWN_MIN_INTERVAL
    endingTriggered  = data.endingTriggered or false
end

return Baldrungen
