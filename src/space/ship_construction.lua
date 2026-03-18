-- ship_construction.lua — Ship construction at shipyard
-- Handles selecting a prebuilt layout, consuming resources over time,
-- and spawning the ship entity group on completion.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local ShipConstruction = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local activeConstruction = nil
-- { shipyardEntityId, prebuiltId, tierId, progress, totalWork, phase }
-- phase: 'selecting' | 'building' | 'complete'

local WORK_PER_TICK = 1  -- construction progress per sim tick with worker

---------------------------------------------------------------------------
-- Start construction at a shipyard
---------------------------------------------------------------------------

function ShipConstruction.startConstruction(shipyardEntityId, prebuiltId)
    local ok, ShipDefs = pcall(require, 'src.space.ship_defs')
    if not ok then return false, 'Ship defs not available' end

    local prebuilt = ShipDefs.getPrebuilt(prebuiltId)
    if not prebuilt then return false, 'Unknown prebuilt: ' .. tostring(prebuiltId) end

    local tier = ShipDefs.getTier(prebuilt.tier)
    if not tier then return false, 'Unknown tier: ' .. tostring(prebuilt.tier) end

    -- Calculate total work based on ship size
    local totalWork = tier.gridW * tier.gridH * 2  -- bigger ship = more work

    -- Check resource costs (base cost for hull + modules)
    local cost = {
        steel = math.floor(tier.gridW * tier.gridH * 0.5),
        components = math.floor(tier.gridW * tier.gridH * 0.2),
        circuit = math.floor(tier.gridW * tier.gridH * 0.1),
    }

    for resource, amount in pairs(cost) do
        if (GameState.resources[resource] or 0) < amount then
            return false, 'Not enough ' .. resource .. ' (need ' .. amount .. ')'
        end
    end

    -- Consume resources
    for resource, amount in pairs(cost) do
        GameState.resources[resource] = (GameState.resources[resource] or 0) - amount
    end

    activeConstruction = {
        shipyardEntityId = shipyardEntityId,
        prebuiltId = prebuiltId,
        tierId = prebuilt.tier,
        progress = 0,
        totalWork = totalWork,
        phase = 'building',
        cost = cost,
    }

    return true
end

---------------------------------------------------------------------------
-- Advance construction (called by worker colonist at shipyard)
---------------------------------------------------------------------------

function ShipConstruction.addProgress(amount)
    if not activeConstruction then return false end
    if activeConstruction.phase ~= 'building' then return false end

    activeConstruction.progress = activeConstruction.progress + (amount or WORK_PER_TICK)

    if activeConstruction.progress >= activeConstruction.totalWork then
        activeConstruction.phase = 'complete'

        -- Spawn the ship entity group
        local smOk, ShipManager = pcall(require, 'src.space.ship_manager')
        if smOk then
            local shipId = ShipManager.createShip(activeConstruction.tierId, activeConstruction.prebuiltId)
            if shipId then
                -- Position ship at shipyard location
                local shipyardPos = ECS.get(activeConstruction.shipyardEntityId, 'pos')
                if shipyardPos then
                    local shipPos = ECS.get(shipId, 'pos')
                    if shipPos then
                        shipPos.x = shipyardPos.x
                        shipPos.y = shipyardPos.y
                    end
                end

                local alOk, Alerts = pcall(require, 'src.ui.alerts')
                if alOk and Alerts.send then
                    Alerts.send('DISCOVERY', 'Ship construction complete! Your vessel is ready for launch.')
                end
            end
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Cancel construction (refund partial resources)
---------------------------------------------------------------------------

function ShipConstruction.cancel()
    if not activeConstruction then return false end

    -- Refund 50% of consumed resources
    if activeConstruction.cost then
        for resource, amount in pairs(activeConstruction.cost) do
            local refund = math.floor(amount * 0.5)
            GameState.resources[resource] = (GameState.resources[resource] or 0) + refund
        end
    end

    activeConstruction = nil
    return true
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function ShipConstruction.getActive()
    return activeConstruction
end

function ShipConstruction.isBuilding()
    return activeConstruction and activeConstruction.phase == 'building'
end

function ShipConstruction.isComplete()
    return activeConstruction and activeConstruction.phase == 'complete'
end

function ShipConstruction.getProgress()
    if not activeConstruction then return 0, 0 end
    return activeConstruction.progress, activeConstruction.totalWork
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function ShipConstruction.getState()
    return activeConstruction
end

function ShipConstruction.loadState(state)
    activeConstruction = state
end

return ShipConstruction
