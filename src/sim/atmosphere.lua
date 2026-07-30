-- atmosphere.lua — Per-room air quality effects (derived from tile_gas.lua)
-- Room O2/CO2 levels are now derived from per-tile gas simulation.
-- This module handles colonist breathing effects, ventilation building
-- registration, and CO2 emitter tracking. Source of truth: tile_gas.lua.

local Thermal   = require('src.sim.thermal')
local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Atmosphere = {}

-- Per-room atmosphere: { [roomId] = { o2 = 0-100, co2 = 0-100 } }
local roomAtmo = {}

-- Ventilation buildings registered by room
-- { [entityId] = { type, roomId, x, y, depth } }
local vents = {}

-- CO2 emitters registered by room (generators, machines)
-- { [entityId] = { roomId, rate } }
local co2Emitters = {}

-- Constants
local AMBIENT_O2          = 100   -- outdoor O2 percentage
local AMBIENT_CO2         = 0     -- outdoor CO2 percentage
local COLONIST_O2_RATE    = 0.08  -- O2 consumed per colonist per second
local COLONIST_CO2_RATE   = 0.06  -- CO2 produced per colonist per second
local UNSEALED_EQUALIZE   = 0.5   -- rate unsealed rooms equalize with ambient
local DOOR_LEAK_RATE      = 0.08  -- passive air leak per ordinary door per second
local AIR_INTAKE_RATE     = 0.4   -- O2 pulled in per second by air_intake
local AIR_EXHAUST_RATE    = 0.3   -- CO2 pushed out per second by air_exhaust
local AIR_PURIFIER_RATE   = 0.5   -- CO2 converted to O2 per second by purifier
local WALL_VENT_RATE      = 0.15  -- passive equalization rate between rooms
local CIRCULATION_FAN_RATE = 0.45 -- powered equalization rate between rooms

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Atmosphere.init()
    roomAtmo    = {}
    vents       = {}
    co2Emitters = {}

    -- Apply planet-specific atmosphere constants
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then
        AMBIENT_O2  = Planet.get('atmosphere.ambientO2', AMBIENT_O2)
        AMBIENT_CO2 = Planet.get('atmosphere.ambientCO2', AMBIENT_CO2)
    end

    local tgOk, TileGas = pcall(require, 'src.sim.tile_gas')
    if tgOk and TileGas.init then
        TileGas.init()
    end
end

---------------------------------------------------------------------------
-- Ventilation building registration
---------------------------------------------------------------------------

--- Find distinct rooms adjacent to a vent position.
--- Returns a list of distinct room IDs (0 = outdoor/unsealed).
--- Typically 1-2 entries; 3+ is rare but handled.
local DIRS = { {1,0}, {-1,0}, {0,1}, {0,-1} }
local VENT_MODE = { air_intake = 'intake', air_exhaust = 'exhaust', air_purifier = 'purifier' }
local _adjSeen = {}
local _adjRooms = {}
local function findAdjacentRooms(x, y, depth, World)
    -- Reuse scratch tables to avoid per-call allocations
    for k in pairs(_adjSeen)  do _adjSeen[k]  = nil end
    for i = 1, #_adjRooms do _adjRooms[i] = nil end
    local n = 0
    for _, d in ipairs(DIRS) do
        local nx, ny = x + d[1], y + d[2]
        if World.inBounds(nx, ny) then
            local rid = World.getRoom(nx, ny, depth) or 0
            if not _adjSeen[rid] then
                _adjSeen[rid] = true
                n = n + 1
                _adjRooms[n] = rid
            end
        end
    end
    return _adjRooms, n
end

function Atmosphere.addVent(entityId, ventType, roomId, x, y, ecsEntityId, depth)
    vents[entityId] = { type = ventType, roomId = roomId, x = x, y = y, entityId = ecsEntityId or entityId, depth = depth or 0 }
end

function Atmosphere.removeVent(entityId)
    vents[entityId] = nil
end

function Atmosphere.refreshRoomIds()
    local wok, World = pcall(require, 'src.world.tilemap')
    if not wok then return end
    for _, vent in pairs(vents) do
        vent.roomId = World.getRoom(vent.x, vent.y, vent.depth or 0) or 0
    end
    for eid, emitter in pairs(co2Emitters) do
        local pos = ECS.get(eid, 'pos')
        if pos then
            emitter.roomId = World.getRoom(pos.x, pos.y, pos.depth or 0) or 0
        end
    end
end

---------------------------------------------------------------------------
-- CO2 emitter registration (generators, running machines)
---------------------------------------------------------------------------

function Atmosphere.addCO2Emitter(entityId, roomId, rate)
    co2Emitters[entityId] = { roomId = roomId, rate = rate }
end

function Atmosphere.removeCO2Emitter(entityId)
    co2Emitters[entityId] = nil
end

function Atmosphere.setCO2Rate(entityId, rate)
    if co2Emitters[entityId] then
        co2Emitters[entityId].rate = rate
    end
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Atmosphere.step(dt)
    local rooms = Thermal.getRooms()
    local World = require('src.world.tilemap')
    local tgOk, TileGas = pcall(require, 'src.sim.tile_gas')

    for rid, room in pairs(rooms) do
        local atmo = roomAtmo[rid]
        if not atmo then
            atmo = { o2 = AMBIENT_O2, co2 = AMBIENT_CO2 }
            roomAtmo[rid] = atmo
        end
        if room.sealed then
            atmo.o2 = clamp(atmo.o2, 0, 100)
            atmo.co2 = clamp(atmo.co2, 0, 100)

            -- Ordinary doors are not airtight: each normal door leaks air
            -- toward the neighboring room (or ambient). Without this, any
            -- enclosed bedroom slowly suffocated its occupants — rooms had
            -- NO air exchange at all. Sealed/lead doors stay airtight.
            local doorSegs = room.doorSegs
            if doorSegs then
                local TilesMod = require('src.world.tiles')
                for _, seg in ipairs(doorSegs) do
                    if seg.tileType == TilesMod.DOOR then
                        local nAtmo = seg.otherRoom and seg.otherRoom > 0
                            and roomAtmo[seg.otherRoom] or nil
                        local nO2  = nAtmo and nAtmo.o2  or AMBIENT_O2
                        local nCO2 = nAtmo and nAtmo.co2 or AMBIENT_CO2
                        local f = math.min(1, DOOR_LEAK_RATE * dt)
                        atmo.o2  = clamp(atmo.o2  + (nO2  - atmo.o2)  * f, 0, 100)
                        atmo.co2 = clamp(atmo.co2 + (nCO2 - atmo.co2) * f, 0, 100)
                    end
                end
            end
        else
            atmo.o2 = clamp(atmo.o2 + (AMBIENT_O2 - atmo.o2) * math.min(1, UNSEALED_EQUALIZE * dt), 0, 100)
            atmo.co2 = clamp(atmo.co2 + (AMBIENT_CO2 - atmo.co2) * math.min(1, UNSEALED_EQUALIZE * dt), 0, 100)
        end
    end

    -- Run sources FIRST (breathing, emitters, ventilation), then derive room values.
    -- This ensures the derived O2/CO2 reflects this tick's changes, not last tick's.

    -- Colonist breathing updates the room mixture used by tests and UI.
    for _, comps in ECS.query('pos', 'colonist') do
        local pos = comps.pos
        local col = comps.colonist
        if col.state ~= 'dead' then
            local rid = World.getRoom(pos.x, pos.y, pos.depth or 0)
            local room = rid and rooms[rid]
            if room and room.sealed then
                local volume = math.max(1, #room.tiles)
                local atmo = roomAtmo[rid]
                atmo.o2 = clamp(atmo.o2 - (COLONIST_O2_RATE * dt * 18) / volume, 0, 100)
                atmo.co2 = clamp(atmo.co2 + (COLONIST_CO2_RATE * dt * 18) / volume, 0, 100)
                -- NOTE: breathing no longer injects tile CO2 gas. The room
                -- O2/CO2 above already accounts for breathing; injecting
                -- tile gas too double-counted it, and indoor tile gas never
                -- dissipates — so every occupied bedroom permanently fouled
                -- until the min()-merged room O2 suffocated its sleeper.
                -- Tile CO2 remains for real emitters (generators, hazards).
            end
        end
    end

    for eid, emitter in pairs(co2Emitters) do
        local pos = ECS.get(eid, 'pos')
        local rid = emitter.roomId
        if pos then
            rid = World.getRoom(pos.x, pos.y, pos.depth or 0)
        end
        local room = rid and rooms[rid]
        if room and room.sealed then
            local volume = math.max(1, #room.tiles)
            local atmo = roomAtmo[rid]
            atmo.co2 = clamp(atmo.co2 + (emitter.rate or 0) * dt * 12 / volume, 0, 100)
            atmo.o2 = clamp(atmo.o2 - (emitter.rate or 0) * dt * 2 / volume, 0, 100)
            if tgOk and pos and math.random() < emitter.rate * dt * 10 then
                TileGas.addGas(pos.x, pos.y, 1, TileGas.TYPE_CO2, pos.depth or 0)
            end
        end
    end

    for _, vent in pairs(vents) do
        local ventDepth = vent.depth or 0
        local rid = vent.roomId
        if rid == nil or rid == 0 then
            rid = World.getRoom(vent.x, vent.y, ventDepth) or 0
            vent.roomId = rid
        end
        local room = rid and rooms[rid]
        local atmo = rid and roomAtmo[rid]
        local machine = vent.entityId and ECS.get(vent.entityId, 'machine')
        local powered = not machine or machine.powered

        if room and room.sealed and atmo and powered then
            if vent.type == 'air_intake' then
                atmo.o2 = clamp(atmo.o2 + AIR_INTAKE_RATE * dt * 12, 0, 100)
                atmo.co2 = clamp(atmo.co2 - AIR_INTAKE_RATE * dt * 8, 0, 100)
            elseif vent.type == 'air_exhaust' then
                atmo.co2 = clamp(atmo.co2 - AIR_EXHAUST_RATE * dt * 12, 0, 100)
            elseif vent.type == 'air_purifier' then
                local purified = math.min(atmo.co2, AIR_PURIFIER_RATE * dt * 10)
                atmo.co2 = clamp(atmo.co2 - purified, 0, 100)
                atmo.o2 = clamp(atmo.o2 + purified * 0.8, 0, 100)
            end
        end

        -- Room-to-room / room-to-outdoor vents
        if vent.type == 'wall_vent' or vent.type == 'circulation_fan' then
            local rate = vent.type == 'circulation_fan'
                and (powered and CIRCULATION_FAN_RATE or 0)
                or WALL_VENT_RATE
            if rate > 0 then
                local adjRooms, adjCount = findAdjacentRooms(vent.x, vent.y, ventDepth, World)
                -- Need at least 2 distinct rooms to equalize between
                if adjCount >= 2 then
                    -- Equalize all unique pairs
                    for i = 1, adjCount - 1 do
                        for j = i + 1, adjCount do
                            local ridA, ridB = adjRooms[i], adjRooms[j]
                            local atmoA = ridA > 0 and roomAtmo[ridA]
                            local atmoB = ridB > 0 and roomAtmo[ridB]
                            local o2A  = atmoA and atmoA.o2  or AMBIENT_O2
                            local co2A = atmoA and atmoA.co2 or AMBIENT_CO2
                            local o2B  = atmoB and atmoB.o2  or AMBIENT_O2
                            local co2B = atmoB and atmoB.co2 or AMBIENT_CO2

                            local o2Diff  = (o2B - o2A) * rate * dt * 8
                            local co2Diff = (co2B - co2A) * rate * dt * 8

                            if atmoA then
                                atmoA.o2  = clamp(atmoA.o2  + o2Diff, 0, 100)
                                atmoA.co2 = clamp(atmoA.co2 + co2Diff, 0, 100)
                            end
                            if atmoB then
                                atmoB.o2  = clamp(atmoB.o2  - o2Diff, 0, 100)
                                atmoB.co2 = clamp(atmoB.co2 - co2Diff, 0, 100)
                            end
                        end
                    end
                end
            end
        end

        if tgOk then
            local mode = VENT_MODE[vent.type]
            if mode then
                if powered then
                    TileGas.addVentilator(vent.entityId, vent.x, vent.y, ventDepth, mode, 1)
                else
                    TileGas.removeVentilator(vent.entityId)
                end
            end
        end
    end

    -- Merge tile-gas contamination into the room compatibility layer so room
    -- readers still see immediate breathing and machine effects.
    for rid, room in pairs(rooms) do
        local atmo = roomAtmo[rid] or { o2 = AMBIENT_O2, co2 = AMBIENT_CO2 }
        if tgOk then
            local o2  = TileGas.getRoomO2(rid)
            local co2 = TileGas.getRoomCO2(rid)
            atmo.o2 = math.min(atmo.o2, o2)
            atmo.co2 = math.max(atmo.co2, co2)
        end
        roomAtmo[rid] = atmo
    end

    -- Clean up atmo data for rooms that no longer exist
    for rid in pairs(roomAtmo) do
        if not rooms[rid] then
            roomAtmo[rid] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Atmosphere.getRoomO2(roomId)
    if roomId == 0 then return AMBIENT_O2 end
    local atmo = roomAtmo[roomId]
    return atmo and atmo.o2 or AMBIENT_O2
end

function Atmosphere.getRoomCO2(roomId)
    if roomId == 0 then return AMBIENT_CO2 end
    local atmo = roomAtmo[roomId]
    return atmo and atmo.co2 or AMBIENT_CO2
end

function Atmosphere.getTileO2(x, y, depth)
    local World = require('src.world.tilemap')
    local rid = World.getRoom(x, y, depth or 0)
    local roomO2 = Atmosphere.getRoomO2(rid)
    local tgOk, TileGas = pcall(require, 'src.sim.tile_gas')
    if tgOk and TileGas.getTileO2 then
        return math.min(roomO2, TileGas.getTileO2(x, y, depth or 0))
    end
    return roomO2
end

function Atmosphere.getTileCO2(x, y, depth)
    local World = require('src.world.tilemap')
    local rid = World.getRoom(x, y, depth or 0)
    local roomCO2 = Atmosphere.getRoomCO2(rid)
    local tgOk, TileGas = pcall(require, 'src.sim.tile_gas')
    if tgOk and TileGas.getTileCO2 then
        return math.max(roomCO2, TileGas.getTileCO2(x, y, depth or 0))
    end
    return roomCO2
end

function Atmosphere.getAllRoomAtmo()
    return roomAtmo
end

---------------------------------------------------------------------------
-- CO2 injection (called by pipe_processors waste_processor)
---------------------------------------------------------------------------

function Atmosphere.addCO2(roomId, amount)
    if not roomId or roomId == 0 then return end
    if not roomAtmo[roomId] then
        roomAtmo[roomId] = { o2 = AMBIENT_O2, co2 = AMBIENT_CO2 }
    end
    roomAtmo[roomId].co2 = math.min(100, roomAtmo[roomId].co2 + amount)
end

function Atmosphere.injectCO2(x, y, amount, depth)
    local World = require('src.world.tilemap')
    local rid = World.getRoom(x, y, depth or 0)
    Atmosphere.addCO2(rid, amount)
    local tgOk, TileGas = pcall(require, 'src.sim.tile_gas')
    if tgOk and TileGas.addGas and amount and amount > 0 then
        local tileAmount = math.max(1, math.floor(amount / 15 + 0.5))
        TileGas.addGas(x, y, tileAmount, TileGas.TYPE_CO2, depth or 0)
    end
end

---------------------------------------------------------------------------
-- Save / Load
-- Vents and co2Emitters reference ECS entity IDs which change on load.
-- Only persist roomAtmo; vents and emitters are rebuilt from ECS state
-- by building_placement and other registration systems during load.
---------------------------------------------------------------------------

function Atmosphere.getState()
    return {
        roomAtmo = roomAtmo,
    }
end

function Atmosphere.loadState(saved)
    if not saved then return end
    roomAtmo    = saved.roomAtmo or {}
    -- vents and co2Emitters are NOT restored from save data.
    -- They are re-registered by building systems during entity restoration.
    vents       = {}
    co2Emitters = {}
end

return Atmosphere
