-- stealth.lua — Ship stealth and detection system
-- Heat signature = power output + crew + active systems.
-- NPC ships have detection ranges. Player signature determines visibility.
-- Scout ships can run cold. Colony ships cannot stealth effectively.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Stealth = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local BASE_SIGNATURE_SCOUT  = 10   -- scout ship base heat sig
local BASE_SIGNATURE_COLONY = 60   -- colony ship base heat sig (cannot stealth)
local CREW_SIGNATURE        = 2    -- per crew member
local POWER_SIGNATURE       = 0.5  -- per watt of power draw
local STEALTH_MODULE_REDUCTION = 0.6  -- active stealth reduces sig by 60%
local STEALTH_POWER_DRAIN   = 20   -- watts drained while stealth active

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local stealthActive = false
local currentSignature = 0

---------------------------------------------------------------------------
-- Calculate heat signature
---------------------------------------------------------------------------

function Stealth.calculateSignature()
    if GameState.activeMap ~= 'space' then return 0 end

    local signature
    local shipTier = 'scout'

    -- Find player ship
    for id, comps in ECS.query('ship') do
        if not ECS.has(id, 'npc_ship') then
            shipTier = comps.ship.tier or 'scout'
            break
        end
    end

    -- Base signature by tier
    if shipTier == 'colony' then
        signature = BASE_SIGNATURE_COLONY
    else
        signature = BASE_SIGNATURE_SCOUT
    end

    -- Crew count
    local crewCount = 0
    for _ in ECS.query('colonist') do
        crewCount = crewCount + 1
    end
    signature = signature + crewCount * CREW_SIGNATURE

    -- Active ship modules add to signature
    local totalPowerDraw = 0
    for modId, comps in ECS.query('ship_module') do
        local mod = comps.ship_module
        if mod.operational then
            -- Each operational module adds to signature
            signature = signature + 3
            -- Estimate power draw contribution
            totalPowerDraw = totalPowerDraw + 5
        end
    end
    signature = signature + totalPowerDraw * POWER_SIGNATURE

    -- Engine thrust adds heavily to signature
    for id, comps in ECS.query('ship') do
        if not ECS.has(id, 'npc_ship') then
            local ship = comps.ship
            if ship.velocity and ship.velocity > 0 then
                signature = signature + ship.velocity * 8
            end
            break
        end
    end

    -- Active stealth module reduction
    if stealthActive and shipTier ~= 'colony' then
        signature = signature * (1 - STEALTH_MODULE_REDUCTION)
    end

    -- Running cold (no thrust, minimal power) bonus
    local isRunningCold = true
    for id, comps in ECS.query('ship') do
        if not ECS.has(id, 'npc_ship') then
            if comps.ship.velocity > 0.1 then isRunningCold = false end
            break
        end
    end
    if isRunningCold and not stealthActive then
        signature = signature * 0.5  -- passive cold-running bonus
    end

    currentSignature = math.max(1, math.floor(signature))
    return currentSignature
end

---------------------------------------------------------------------------
-- Detection check
---------------------------------------------------------------------------

function Stealth.isDetectedBy(npcEntityId)
    local npc = ECS.get(npcEntityId, 'npc_ship')
    if not npc then return true end  -- non-NPC always "detects"

    local detRange = npc.detectionRange or 10
    local sig = Stealth.calculateSignature()

    -- Higher signature = detected from further away
    -- Effective detection range scaled by signature
    local effectiveRange = detRange * (sig / 50)

    -- Get distance to player
    local npcPos = ECS.get(npcEntityId, 'pos')
    local playerPos
    for id, comps in ECS.query('ship', 'pos') do
        if not ECS.has(id, 'npc_ship') then
            playerPos = comps.pos
            break
        end
    end
    if not npcPos or not playerPos then return false end

    local dx = playerPos.x - npcPos.x
    local dy = playerPos.y - npcPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    return dist <= effectiveRange
end

---------------------------------------------------------------------------
-- Stealth module control
---------------------------------------------------------------------------

function Stealth.activateStealth()
    -- Only scout ships can use active stealth
    for id, comps in ECS.query('ship') do
        if not ECS.has(id, 'npc_ship') then
            if comps.ship.tier == 'colony' then
                return false, 'Colony ships cannot activate stealth'
            end
            break
        end
    end

    -- Check if stealth module exists and is operational
    local hasModule = false
    for modId, comps in ECS.query('ship_module') do
        if comps.ship_module.systemType == 'stealth_module' and comps.ship_module.operational then
            hasModule = true
            break
        end
    end
    if not hasModule then return false, 'No operational stealth module' end

    stealthActive = true
    return true
end

function Stealth.deactivateStealth()
    stealthActive = false
end

function Stealth.isStealthActive()
    return stealthActive
end

function Stealth.getSignature()
    return currentSignature
end

---------------------------------------------------------------------------
-- Step (drain power while stealth active)
---------------------------------------------------------------------------

function Stealth.step(dt)
    if GameState.activeMap ~= 'space' then return end

    Stealth.calculateSignature()

    if stealthActive then
        -- Drain fuel while stealth is active (represents power cost)
        for id, comps in ECS.query('ship') do
            if not ECS.has(id, 'npc_ship') then
                comps.ship.fuel = math.max(0, comps.ship.fuel - STEALTH_POWER_DRAIN * dt * 0.01)
                if comps.ship.fuel <= 0 then
                    stealthActive = false
                    local alOk, Alerts = pcall(require, 'src.ui.alerts')
                    if alOk and Alerts.send then
                        Alerts.send('POWER OUTAGE', 'Stealth module deactivated — no fuel!')
                    end
                end
                break
            end
        end
    end
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Stealth.getState()
    return {
        stealthActive = stealthActive,
        currentSignature = currentSignature,
    }
end

function Stealth.loadState(state)
    if not state then return end
    stealthActive = state.stealthActive or false
    currentSignature = state.currentSignature or 0
end

return Stealth
