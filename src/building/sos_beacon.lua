-- sos_beacon.lua — SOS Beacon ECS system
-- Emergency distress beacon that fires when all colonists are downed.
-- Spawns 2 emergency colonists after a 30-second countdown, then burns out.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local SOSBeacon = {}

local COUNTDOWN_DURATION = 30  -- seconds
local EMERGENCY_COLONISTS = 2

local function sosBeaconSystem(dt, id, comps)
    local beacon = comps.sos_beacon
    local pos = comps.pos

    -- Already fired (burnt out) — nothing to do
    if beacon.fired then return end

    -- Check power status
    local pOk, Power = pcall(require, 'src.sim.power')
    if pOk then
        beacon.powered = Power.isConsumerPowered(id)
    end

    -- Must be active and powered to function
    if not beacon.active or not beacon.powered then
        beacon.countdown = nil
        return
    end

    -- Check colonist states: are all alive colonists downed?
    local allDowned = true
    local anyAlive = false
    for _, ccomps in ECS.query('colonist') do
        local col = ccomps.colonist
        if col.state ~= 'dead' then
            anyAlive = true
            if col.state ~= 'downed' and col.state ~= 'incapacitated' then
                allDowned = false
            end
        end
    end

    -- No one alive (all dead) — beacon can't help the dead
    if not anyAlive then return end

    if allDowned then
        -- Start countdown if not already running
        if not beacon.countdown then
            beacon.countdown = COUNTDOWN_DURATION
            local aOk, Alerts = pcall(require, 'src.ui.alerts')
            if aOk and Alerts.add then
                Alerts.add('SOS Beacon activated. Emergency reinforcements inbound in '
                    .. COUNTDOWN_DURATION .. ' seconds.', 'warning')
            end
        end

        -- Decrement countdown
        beacon.countdown = beacon.countdown - dt
        if beacon.countdown <= 0 then
            -- Fire the beacon: spawn emergency colonists near beacon position
            local cOk, ColMod = pcall(require, 'src.colonist.colonist')
            local wOk, World = pcall(require, 'src.world.tilemap')

            if cOk and wOk then
                local spawned = 0
                -- Search outward from beacon pos for walkable tiles
                for r = 0, 15 do
                    if spawned >= EMERGENCY_COLONISTS then break end
                    for dy = -r, r do
                        if spawned >= EMERGENCY_COLONISTS then break end
                        for dx = -r, r do
                            if spawned >= EMERGENCY_COLONISTS then break end
                            if math.abs(dx) == r or math.abs(dy) == r then
                                local tx = pos.x + dx
                                local ty = pos.y + dy
                                if World.inBounds(tx, ty) and World.isWalkable(tx, ty, pos.depth or 0) then
                                    ColMod.spawn(tx, ty, pos.depth or 0)
                                    spawned = spawned + 1
                                end
                            end
                        end
                    end
                end
            end

            -- Log the event
            local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if stOk and Storyteller.logEvent then
                Storyteller.logEvent('rescue',
                    'SOS Beacon fired. Emergency reinforcements have arrived.')
            end

            local aOk2, Alerts2 = pcall(require, 'src.ui.alerts')
            if aOk2 and Alerts2.add then
                Alerts2.add('SOS Beacon fired. Emergency colonists have arrived.', 'positive')
            end

            -- Burn out the beacon
            beacon.fired = true
            beacon.active = false
            beacon.countdown = nil
        end
    else
        -- Crisis averted — reset countdown
        if beacon.countdown then
            beacon.countdown = nil
            local aOk, Alerts = pcall(require, 'src.ui.alerts')
            if aOk and Alerts.add then
                Alerts.add('SOS Beacon countdown cancelled. Crisis averted.', 'info')
            end
        end
    end
end

function SOSBeacon.registerSystems()
    ECS.addSystem('sos_beacon', { 'sos_beacon', 'pos' }, sosBeaconSystem, 5)
end

SOSBeacon.registerSystems()

return SOSBeacon
