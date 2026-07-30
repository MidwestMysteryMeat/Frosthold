-- ship_movement.lua — Ship navigation on space tilemap
-- Handles thrust, heading, drift, fuel consumption.
-- Registered as an ECS system for entities with 'ship' + 'pos'.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local ShipMovement = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local FUEL_PER_THRUST = 0.1
local DRIFT_DECAY     = 0.95

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local targetX, targetY = nil, nil
local thrustActive = false

---------------------------------------------------------------------------
-- ECS System
---------------------------------------------------------------------------

function ShipMovement.registerSystems()
    ECS.addSystem('ship_movement', {'ship', 'pos'}, function(dt, id, comps)
        if GameState.activeMap ~= 'space' then return end

        local ship = comps.ship
        local pos  = comps.pos

        -- Autopilot: set heading toward target
        if targetX and targetY then
            local dx = targetX - pos.x
            local dy = targetY - pos.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < 2 then
                targetX, targetY = nil, nil
                ship.velocity = 0
                thrustActive = false
            else
                ship.heading = math.atan2(dy, dx)
                thrustActive = true
            end
        end

        -- Apply thrust
        if thrustActive and ship.fuel > 0 then
            local ok, ShipDefs = pcall(require, 'src.space.ship_defs')
            local tier = ok and ShipDefs.getTier(ship.tier)
            local maxSpeed = tier and tier.baseSpeed or 2

            ship.velocity = math.min(maxSpeed, (ship.velocity or 0) + 0.5)
            ship.fuel = math.max(0, ship.fuel - FUEL_PER_THRUST * ship.velocity)
        else
            ship.velocity = (ship.velocity or 0) * DRIFT_DECAY
            if ship.velocity < 0.01 then ship.velocity = 0 end
        end

        -- Move ship
        if ship.velocity > 0 then
            local moveX = math.cos(ship.heading or 0) * ship.velocity * dt
            local moveY = math.sin(ship.heading or 0) * ship.velocity * dt

            pos.x = pos.x + moveX
            pos.y = pos.y + moveY

            local stOk, SpaceTilemap = pcall(require, 'src.space.space_tilemap')
            if stOk then
                local cx = math.floor(pos.x / SpaceTilemap.CHUNK_SIZE)
                local cy = math.floor(pos.y / SpaceTilemap.CHUNK_SIZE)
                SpaceTilemap.setShipChunk(cx, cy)
                SpaceTilemap.unloadDistantChunks(3)
            end
        end
    end)
end

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

function ShipMovement.setAutopilot(x, y)
    targetX = x
    targetY = y
    thrustActive = true
end

function ShipMovement.cancelAutopilot()
    targetX, targetY = nil, nil
    thrustActive = false
end

function ShipMovement.setThrust(active)
    thrustActive = active
end

function ShipMovement.setHeading(radians)
    local firstShip = ECS.query('ship')
    local _, comps = firstShip()
    if comps then
        comps.ship.heading = radians
    end
end

function ShipMovement.getState()
    return {
        targetX = targetX,
        targetY = targetY,
        thrustActive = thrustActive,
    }
end

function ShipMovement.loadState(state)
    if not state then return end
    targetX = state.targetX
    targetY = state.targetY
    thrustActive = state.thrustActive or false
end

return ShipMovement
