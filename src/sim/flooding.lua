-- flooding.lua — Room-level water effects (derived from tile_fluids.lua)
-- Room water levels are now derived from per-tile water simulation.
-- This module handles the gameplay EFFECTS of flooding: speed penalties,
-- electrical shorts, drowning, fuel ignition. Pumps remove water at tile level.
-- Source of truth for water data: tile_fluids.lua / tilemap water[] arrays.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')

local Flooding = {}

---------------------------------------------------------------------------
-- Per-room water state
-- { [roomId] = { level = 0-1, sources = n, drains = n } }
---------------------------------------------------------------------------

local roomWater = {}

-- Registered pumps: { [entityId] = { roomId, rate } }
local pumps = {}

-- Pending water injections from events (burst pipe, mined ice, etc.)
local pendingInjections = {}  -- { { roomId, amount } ... }

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local FLOW_RATE           = 0.02   -- water flow between connected rooms per second
local EVAPORATION_RATE    = 0.001  -- per second in heated rooms (temp > 10C)
local PUMP_RATE           = 0.03   -- water removed per pump per second
local ICE_MINE_INJECTION  = 0.15   -- water added when mining ice underground
local PIPE_BURST_INJECTION = 0.3   -- water from a burst pipe
local FUEL_LEAK_INJECTION  = 0.1   -- fuel leak into room

-- Threshold effects
local THRESHOLD_SLOW      = 0.2   -- movement penalty begins
local THRESHOLD_DAMAGE    = 0.5   -- item damage, electrical shorts
local THRESHOLD_SWIM      = 0.8   -- massive speed penalty, equipment damage
local THRESHOLD_SUBMERGED = 1.0   -- suffocation (underground only)

-- Fuel leak tracking: { [roomId] = fuelLevel }
local roomFuel = {}

local FUEL_BURN_CHANCE = 0.005  -- per second chance of ignition per unit fuel level
local FUEL_EVAP_RATE   = 0.0005 -- fuel evaporates slowly

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Flooding.init()
    roomWater = {}
    pumps = {}
    pendingInjections = {}
    roomFuel = {}

    -- Override flow/evaporation constants from planet config
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then
        FLOW_RATE = Planet.get('flooding.flowRate', FLOW_RATE)
        EVAPORATION_RATE = Planet.get('flooding.evapRate', EVAPORATION_RATE)
    end
end

---------------------------------------------------------------------------
-- Pump registration
---------------------------------------------------------------------------

function Flooding.addPump(entityId, roomId, rate)
    pumps[entityId] = { roomId = roomId, rate = rate or PUMP_RATE }
end

function Flooding.removePump(entityId)
    pumps[entityId] = nil
end

---------------------------------------------------------------------------
-- Water injection events
---------------------------------------------------------------------------

function Flooding.injectWater(roomId, amount)
    -- Legacy compat: delegate to tile_fluids for actual water injection
    -- Callers should prefer TileFluids.addWater() directly
    if not roomId or roomId == 0 then return end
    pendingInjections[#pendingInjections + 1] = { roomId = roomId, amount = amount }
end

function Flooding.injectFuel(roomId, amount)
    if not roomId or roomId == 0 then return end
    roomFuel[roomId] = (roomFuel[roomId] or 0) + amount
end

-- Called when a tile is excavated underground (may hit ice pocket)
function Flooding.onTileExcavated(x, y, prevTile, depth)
    local World = require('src.world.tilemap')
    local roomId = World.getRoom(x, y, depth)
    if prevTile == Tiles.ICE then
        Flooding.injectWater(roomId, ICE_MINE_INJECTION)
    end
end

-- Called when a pipe bursts
function Flooding.onPipeBurst(x, y, depth)
    local World = require('src.world.tilemap')
    local roomId = World.getRoom(x, y, depth)
    Flooding.injectWater(roomId, PIPE_BURST_INJECTION)
end

-- Called when fuel storage is damaged
function Flooding.onFuelLeak(x, y, amount, depth)
    local World = require('src.world.tilemap')
    local roomId = World.getRoom(x, y, depth)
    Flooding.injectFuel(roomId, amount or FUEL_LEAK_INJECTION)
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Flooding.getWaterLevel(roomId)
    local rw = roomWater[roomId]
    return rw and rw.level or 0
end

function Flooding.getFuelLevel(roomId)
    return roomFuel[roomId] or 0
end

function Flooding.getMovementMult(roomId)
    local level = Flooding.getWaterLevel(roomId)
    if level >= THRESHOLD_SWIM then return 0.3 end
    if level >= THRESHOLD_DAMAGE then return 0.6 end
    if level >= THRESHOLD_SLOW then return 0.8 end
    return 1.0
end

function Flooding.isFlooded(roomId)
    return Flooding.getWaterLevel(roomId) >= THRESHOLD_SLOW
end

function Flooding.isSubmerged(roomId)
    return Flooding.getWaterLevel(roomId) >= THRESHOLD_SUBMERGED
end

function Flooding.canDrown(roomId, x, y)
    if not Flooding.isSubmerged(roomId) then return false end
    -- Only underground rooms cause drowning
    local tOk, Terraform = pcall(require, 'src.world.terraform')
    if tOk then return Terraform.isUndergroundAt(x, y) end
    return false
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Flooding.step(dt)
    local Thermal = require('src.sim.thermal')
    local World   = require('src.world.tilemap')
    local rooms   = Thermal.getRooms()

    -- Process pending legacy injections (convert to tile-level water)
    local tfOk, TileFluids = pcall(require, 'src.sim.tile_fluids')
    for _, inj in ipairs(pendingInjections) do
        local room = rooms[inj.roomId]
        if room and room.tiles and #room.tiles > 0 and tfOk then
            -- Pick a random tile in the room to inject water
            local tIdx = room.tiles[math.random(#room.tiles)]
            local w = World.width()
            local ix = (tIdx - 1) % w
            local iy = math.floor((tIdx - 1) / w)
            local waterAmount = math.floor(inj.amount * 7 + 0.5)  -- scale 0-1 to 0-7
            TileFluids.addWater(ix, iy, waterAmount, room.depth or 0)
        end
    end
    pendingInjections = {}

    -- Derive room water levels from tile-level data
    for rid, room in pairs(rooms) do
        if room.tiles and #room.tiles > 0 then
            local level = 0
            if tfOk then
                level = TileFluids.getRoomWaterLevel(rid)
            end
            if level > 0.01 then
                if not roomWater[rid] then
                    roomWater[rid] = { level = 0, sources = 0, drains = 0 }
                end
                roomWater[rid].level = level
            else
                roomWater[rid] = nil
            end
        end
    end

    -- Pump drainage (now removes water at tile level)
    for _, pump in pairs(pumps) do
        local room = rooms[pump.roomId]
        if room and room.tiles and #room.tiles > 0 and tfOk then
            -- Remove water from wettest tile in the room
            local w = World.width()
            local waterData = World.rawWaterData(room.depth or 0)
            if waterData then
                local bestIdx, bestLevel = nil, 0
                for _, tIdx in ipairs(room.tiles) do
                    local wl = waterData[tIdx] or 0
                    if wl > bestLevel then
                        bestIdx = tIdx
                        bestLevel = wl
                    end
                end
                if bestIdx and bestLevel > 0 then
                    local px = (bestIdx - 1) % w
                    local py = math.floor((bestIdx - 1) / w)
                    TileFluids.removeWater(px, py, 1, room.depth or 0)
                end
            end
        end
    end

    -- Clean up rooms that no longer exist
    for rid in pairs(roomWater) do
        if not rooms[rid] then
            roomWater[rid] = nil
        end
    end

    -- Fuel evaporation and ignition
    local toRemoveFuel = {}
    for rid, fuelLevel in pairs(roomFuel) do
        -- Evaporate
        roomFuel[rid] = fuelLevel - FUEL_EVAP_RATE * dt
        if roomFuel[rid] <= 0.001 then
            toRemoveFuel[#toRemoveFuel + 1] = rid
        else
            -- Ignition chance: fire in the room
            if math.random() < FUEL_BURN_CHANCE * roomFuel[rid] * dt then
                local room = rooms[rid]
                if room and room.tiles and #room.tiles > 0 then
                    local fOk, Fire = pcall(require, 'src.sim.fire')
                    if fOk then
                        -- Pick a random tile in the room to ignite
                        local tileIdx = room.tiles[math.random(#room.tiles)]
                        local w = World.width()
                        local fx = (tileIdx - 1) % w
                        local fy = math.floor((tileIdx - 1) / w)
                        Fire.ignite(fx, fy, 'fuel_ignition', room.depth)
                    end
                    -- Burn off the fuel
                    roomFuel[rid] = math.max(0, roomFuel[rid] - 0.05)
                end
            end
        end
    end
    for _, rid in ipairs(toRemoveFuel) do
        roomFuel[rid] = nil
    end

    -- Damage effects
    Flooding.applyEffects(dt, rooms)
end

---------------------------------------------------------------------------
-- Apply flooding effects to entities in affected rooms
---------------------------------------------------------------------------

function Flooding.applyEffects(dt, rooms)
    local World = require('src.world.tilemap')

    for rid, rw in pairs(roomWater) do
        if rw.level < THRESHOLD_DAMAGE then goto continue end

        -- Electrical shorts at THRESHOLD_DAMAGE
        if rw.level >= THRESHOLD_DAMAGE then
            local pOk, Power = pcall(require, 'src.sim.power')
            if pOk and math.random() < 0.01 * dt then
                -- Zzzt in flooded room
                Power.onFloodShort(rid)
            end
        end

        -- Drowning check for colonists underground at THRESHOLD_SUBMERGED
        if rw.level >= THRESHOLD_SUBMERGED then
            local tOk, Terraform = pcall(require, 'src.world.terraform')
            local drownedIds = {}

            for id, comps in ECS.query('colonist', 'pos', 'needs') do
                if comps.colonist.state ~= 'dead' then
                    local posDepth = comps.pos.depth or 0
                    local cRoom = World.getRoom(comps.pos.x, comps.pos.y, posDepth)
                    if cRoom == rid then
                        local underground = tOk and Terraform.isUndergroundAt(comps.pos.x, comps.pos.y, posDepth)
                        if underground then
                            local health = comps.colonist.health or 100
                            comps.colonist.health = health - 5 * dt
                            if comps.colonist.health <= 0 then
                                comps.colonist.causeOfDeath = 'drowned'
                                drownedIds[#drownedIds + 1] = id
                            end
                        end
                    end
                end
            end

            -- Kill drowned colonists after query loop (kill mutates ECS)
            if #drownedIds > 0 then
                local cOk, Colonist = pcall(require, 'src.colonist.colonist')
                if cOk then
                    for _, did in ipairs(drownedIds) do
                        Colonist.kill(did)
                    end
                end
            end

            -- Creatures drown too
            for id, comps in ECS.query('creature', 'pos') do
                local posDepth = comps.pos.depth or 0
                local cRoom = World.getRoom(comps.pos.x, comps.pos.y, posDepth)
                if cRoom == rid then
                    local underground = tOk and Terraform.isUndergroundAt(comps.pos.x, comps.pos.y, posDepth)
                    if underground and (comps.creature.health or 0) > 0 then
                        comps.creature.health = comps.creature.health - 8 * dt
                    end
                end
            end
        end

        ::continue::
    end
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Flooding.getState()
    return {
        roomWater = roomWater,
        roomFuel  = roomFuel,
    }
end

function Flooding.loadState(state)
    if not state then return end
    roomWater = state.roomWater or {}
    roomFuel  = state.roomFuel or {}
end

return Flooding
