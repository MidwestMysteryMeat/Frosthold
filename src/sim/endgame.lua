-- endgame.lua — Endgame building system
-- Manages endgame buildings: Mammona claim, escape, containment, and extraction.
-- Phases: idle → charging → ready → (player activates) → activating → complete.
-- Transmission array spawns a final assault wave before locking the corporate-claim outcome.
-- Launch pad and sealing apparatus grant victory immediately on activation.
-- Extraction beacon: requires defeating That Which Sleeps first (anomaly.lua).

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Endgame = {}

-- Charge time in sim-seconds: 3 in-game days.
-- 1 day = 24h * 60min = 1440 sim-seconds (GameState.hour advances 24/day).
local CHARGE_TIME = 3 * 24 * 60  -- 4320 sim-seconds

Endgame.CHARGE_TIME = CHARGE_TIME  -- exposed for UI

---------------------------------------------------------------------------
-- ECS system: tick endgame buildings
---------------------------------------------------------------------------

local function endgameBuildingSystem(dt, id, comps)
    local eg = comps.endgame_building
    if not eg then return end

    -- Check power
    local pok, Power = pcall(require, 'src.sim.power')
    if pok then
        eg.powered = Power.isConsumerPowered(id)
    end

    -- Endless mode: skip all victory processing
    if GameState.endlessMode then return end

    if eg.phase == 'idle' then
        return

    elseif eg.phase == 'charging' then
        if not eg.powered then return end
        eg.chargeProgress = eg.chargeProgress + dt
        if eg.chargeProgress >= CHARGE_TIME then
            eg.chargeProgress = CHARGE_TIME
            eg.phase = 'ready'
        end

    elseif eg.phase == 'ready' then
        -- Waiting for player to press Activate in UI
        return

    elseif eg.phase == 'activating' then
        if eg.type == 'transmission_array' then
            if not eg.finalWaveSpawned then
                local rok, Raids = pcall(require, 'src.sim.raids')
                if rok then
                    local ok = Raids.startRaid('swarm')
                    if not ok then
                        Raids.startRaid('coordinated')
                    end
                    eg.finalWaveSpawned = true
                end
            else
                local rok, Raids = pcall(require, 'src.sim.raids')
                if rok and not Raids.isRaidActive() then
                    eg.phase = 'complete'
                    local mok, Milestones = pcall(require, 'src.sim.milestones')
                    if mok then Milestones.complete('mammona_claim') end
                end
            end

        elseif eg.type == 'launch_pad' then
            -- Launch pad no longer ends the game — it becomes a shipyard prerequisite
            -- in the interplanetary travel system. Just mark as complete.
            eg.phase = 'complete'

        elseif eg.type == 'sealing_apparatus' then
            eg.phase = 'complete'
            local mok, Milestones = pcall(require, 'src.sim.milestones')
            if mok then Milestones.complete('seal_deep') end

        elseif eg.type == 'extraction_beacon' then
            -- Mammona extraction: requires That Which Sleeps defeated
            local aok, AnomalyMod = pcall(require, 'src.sim.anomaly')
            if aok and AnomalyMod.isExtractionReady() then
                eg.phase = 'complete'
                local mok, Milestones = pcall(require, 'src.sim.milestones')
                if mok then Milestones.complete('mammona_extraction') end
            else
                -- Boss not yet defeated: revert to ready, cannot activate
                eg.phase = 'ready'
                local alOk, AlertsMod = pcall(require, 'src.ui.alerts')
                if alOk and AlertsMod.send then
                    AlertsMod.send('Extraction Failed',
                        'Anomaly interference blocks the beacon signal. Defeat That Which Sleeps first.',
                        'major')
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Player actions (called from UI)
---------------------------------------------------------------------------

function Endgame.startCharging(entityId)
    local eg = ECS.get(entityId, 'endgame_building')
    if not eg then return false, 'Not an endgame building' end
    if eg.phase ~= 'idle' then return false, 'Already started' end
    eg.phase = 'charging'
    eg.chargeProgress = 0
    return true
end

function Endgame.activate(entityId)
    local eg = ECS.get(entityId, 'endgame_building')
    if not eg then return false, 'Not an endgame building' end
    if eg.phase ~= 'ready' then return false, 'Not ready' end
    eg.phase = 'activating'
    return true
end

function Endgame.getChargePercent(entityId)
    local eg = ECS.get(entityId, 'endgame_building')
    if not eg then return 0 end
    if CHARGE_TIME <= 0 then return 100 end
    return math.min(100, (eg.chargeProgress / CHARGE_TIME) * 100)
end

function Endgame.getPhase(entityId)
    local eg = ECS.get(entityId, 'endgame_building')
    if not eg then return 'none' end
    return eg.phase
end

---------------------------------------------------------------------------
-- Query: find all endgame buildings
---------------------------------------------------------------------------

function Endgame.getBuildings()
    local result = {}
    for id, comps in ECS.query('endgame_building', 'pos') do
        result[#result + 1] = {
            id = id,
            eg = comps.endgame_building,
            pos = comps.pos,
        }
    end
    return result
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Endgame.registerSystems()
    ECS.addSystem('endgame_building', { 'endgame_building' }, endgameBuildingSystem, 55)
end

Endgame.registerSystems()

return Endgame
