-- test_atmosphere.lua — Atmosphere O2/CO2 system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Atmosphere')

-- Atmosphere.step() reads Thermal.getRooms() and World.getRoom().
-- We stub Thermal.getRooms() to return controlled room data and
-- set up a minimal tilemap so World.getRoom() resolves correctly.

local function setupThermalRooms(roomTable)
    local Thermal = require('src.sim.thermal')
    -- Overwrite getRooms to return our controlled table
    Thermal._origGetRooms = Thermal._origGetRooms or Thermal.getRooms
    Thermal.getRooms = function() return roomTable end
end

local function restoreThermal()
    local Thermal = require('src.sim.thermal')
    if Thermal._origGetRooms then
        Thermal.getRooms = Thermal._origGetRooms
        Thermal._origGetRooms = nil
    end
end

T.test('init clears all atmosphere state', function()
    local Atmosphere = require('src.sim.atmosphere')
    Atmosphere.init()
    local all = Atmosphere.getAllRoomAtmo()
    T.tablelen(all, 0, 'no rooms after init')
end)

T.test('getRoomO2 returns 100 for outdoor (roomId 0)', function()
    local Atmosphere = require('src.sim.atmosphere')
    Atmosphere.init()
    T.eq(Atmosphere.getRoomO2(0), 100, 'outdoor O2 is ambient 100')
end)

T.test('getRoomCO2 returns 0 for outdoor (roomId 0)', function()
    local Atmosphere = require('src.sim.atmosphere')
    Atmosphere.init()
    T.eq(Atmosphere.getRoomCO2(0), 0, 'outdoor CO2 is ambient 0')
end)

T.test('getRoomO2 returns ambient for unknown room', function()
    local Atmosphere = require('src.sim.atmosphere')
    Atmosphere.init()
    T.eq(Atmosphere.getRoomO2(999), 100, 'unknown room defaults to ambient O2')
end)

T.test('step initializes atmo for new sealed room', function()
    H.resetAll()
    local Atmosphere = require('src.sim.atmosphere')
    local Tilemap = require('src.world.tilemap')
    Atmosphere.init()

    -- Stub a sealed room with 4 tiles
    local sealedRoom = {
        [1] = { tiles = { 1, 2, 3, 4 }, avgTemp = 10, sealed = true },
    }
    setupThermalRooms(sealedRoom)

    -- Stub World.getRoom to return 0 (no colonists in room)
    local origGetRoom = Tilemap.getRoom
    Tilemap.getRoom = function() return 0 end

    Atmosphere.step(1.0)

    local o2 = Atmosphere.getRoomO2(1)
    local co2 = Atmosphere.getRoomCO2(1)
    T.eq(o2, 100, 'sealed room starts at 100 O2')
    T.eq(co2, 0, 'sealed room starts at 0 CO2')

    Tilemap.getRoom = origGetRoom
    restoreThermal()
end)

T.test('sealed room with colonist depletes O2 over time', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Atmosphere = require('src.sim.atmosphere')
    local Tilemap = require('src.world.tilemap')
    Atmosphere.init()

    -- Spawn a living colonist at position (5, 5)
    local id = H.spawnTestColonist(5, 5)

    -- Sealed room with 4 tiles
    local sealedRoom = {
        [1] = { tiles = { 1, 2, 3, 4 }, avgTemp = 10, sealed = true },
    }
    setupThermalRooms(sealedRoom)

    -- Map the colonist's position to room 1
    local origGetRoom = Tilemap.getRoom
    Tilemap.getRoom = function(x, y)
        if x == 5 and y == 5 then return 1 end
        return 0
    end

    -- Run one step to initialize atmo
    Atmosphere.step(0)
    local o2Before = Atmosphere.getRoomO2(1)
    T.eq(o2Before, 100, 'O2 starts at 100')

    -- Simulate 10 seconds of breathing
    Atmosphere.step(10)
    local o2After = Atmosphere.getRoomO2(1)
    T.lt(o2After, o2Before, 'O2 decreased after colonist breathes')

    local co2After = Atmosphere.getRoomCO2(1)
    T.gt(co2After, 0, 'CO2 increased from colonist breathing')

    Tilemap.getRoom = origGetRoom
    restoreThermal()
end)

T.test('CO2 emitter increases CO2 in sealed room', function()
    H.resetAll()
    local Atmosphere = require('src.sim.atmosphere')
    local Tilemap = require('src.world.tilemap')
    Atmosphere.init()

    local sealedRoom = {
        [1] = { tiles = { 1, 2, 3, 4 }, avgTemp = 10, sealed = true },
    }
    setupThermalRooms(sealedRoom)

    local origGetRoom = Tilemap.getRoom
    Tilemap.getRoom = function() return 0 end

    -- Register a CO2 emitter (e.g. a generator) in room 1
    Atmosphere.addCO2Emitter(100, 1, 0.5)

    -- Initialize atmo
    Atmosphere.step(0)
    T.eq(Atmosphere.getRoomCO2(1), 0, 'CO2 starts at 0')

    -- Simulate time
    Atmosphere.step(5)
    T.gt(Atmosphere.getRoomCO2(1), 0, 'CO2 increased from emitter')

    -- Clean up
    Atmosphere.removeCO2Emitter(100)
    Tilemap.getRoom = origGetRoom
    restoreThermal()
end)

T.test('vent air_intake increases O2 in room', function()
    H.resetAll()
    local Atmosphere = require('src.sim.atmosphere')
    local Tilemap = require('src.world.tilemap')
    Atmosphere.init()

    local sealedRoom = {
        [1] = { tiles = { 1, 2, 3, 4 }, avgTemp = 10, sealed = true },
    }
    setupThermalRooms(sealedRoom)

    local origGetRoom = Tilemap.getRoom
    Tilemap.getRoom = function() return 0 end

    -- Initialize atmo then manually lower O2
    Atmosphere.step(0)
    local all = Atmosphere.getAllRoomAtmo()
    all[1].o2 = 50

    -- Add an air intake vent in room 1
    Atmosphere.addVent(200, 'air_intake', 1, 2, 2)

    Atmosphere.step(5)
    T.gt(Atmosphere.getRoomO2(1), 50, 'air intake raised O2 above 50')

    Atmosphere.removeVent(200)
    Tilemap.getRoom = origGetRoom
    restoreThermal()
end)

T.test('tile getters reflect local gas concentration', function()
    H.resetAll()
    local Atmosphere = require('src.sim.atmosphere')
    local Tilemap = require('src.world.tilemap')
    local TileGas = require('src.sim.tile_gas')

    Tilemap.init(4, 4)
    Atmosphere.init()
    setupThermalRooms({
        [1] = { tiles = { 1 }, avgTemp = 10, sealed = true, depth = 0 },
    })

    local origGetRoom = Tilemap.getRoom
    Tilemap.getRoom = function() return 1 end

    Atmosphere.step(0)
    TileGas.addGas(1, 1, 7, TileGas.TYPE_CO2, 0)

    T.lt(Atmosphere.getTileO2(1, 1, 0), 100, 'local tile O2 drops when gas is present')
    T.gt(Atmosphere.getTileCO2(1, 1, 0), 0, 'local tile CO2 rises when CO2 is present')

    Tilemap.getRoom = origGetRoom
    restoreThermal()
end)
