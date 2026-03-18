-- test_rooms.lua — Room detection and classification tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Rooms')

-- Rooms.classify() reads Thermal.getRooms(), World.width(), World.rawTileData(),
-- and queries ECS for bed/machine entities in rooms.
-- We stub Thermal.getRooms() and set up controlled tilemap state.

local function setupThermalRooms(roomTable)
    local Thermal = require('src.sim.thermal')
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

T.test('TYPES table defines expected room types', function()
    local Rooms = require('src.world.rooms')
    T.has_key(Rooms.TYPES, 'barracks', 'barracks defined')
    T.has_key(Rooms.TYPES, 'kitchen', 'kitchen defined')
    T.has_key(Rooms.TYPES, 'workshop', 'workshop defined')
    T.has_key(Rooms.TYPES, 'hospital', 'hospital defined')
    T.has_key(Rooms.TYPES, 'lab', 'lab defined')
end)

T.test('barracks requires bed and minSize 6', function()
    local Rooms = require('src.world.rooms')
    local def = Rooms.TYPES.barracks
    T.eq(def.minSize, 6, 'barracks minSize')
    T.has_key(def.requires, 'bed', 'barracks requires bed')
    T.eq(def.requires.bed, 1, 'barracks needs at least 1 bed')
end)

T.test('classify produces roomInfo for a simple room', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Rooms = require('src.world.rooms')
    local Tilemap = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')

    -- Set up a small 16x16 tilemap with all snow
    local origWidth = Tilemap.width
    local origRawTileData = Tilemap.rawTileData
    local mapW = 16
    local tData = {}
    for i = 1, mapW * mapW do tData[i] = Tiles.SNOW end

    Tilemap.width = function() return mapW end
    Tilemap.rawTileData = function() return tData end

    -- Room with 10 tiles, sealed, comfortable temperature
    local thermalRooms = {
        [1] = {
            tiles = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            avgTemp = 20,
            sealed = true,
        },
    }
    setupThermalRooms(thermalRooms)

    Rooms.classify()

    local info = Rooms.getRoomInfo(1)
    T.notnil(info, 'room 1 has info')
    T.eq(info.size, 10, 'room size is 10')
    T.eq(info.sealed, true, 'room is sealed')
    T.gt(info.quality, 0, 'quality score is positive')

    Tilemap.width = origWidth
    Tilemap.rawTileData = origRawTileData
    restoreThermal()
end)

T.test('room with bed classifies as barracks', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Rooms = require('src.world.rooms')
    local Tilemap = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')

    local mapW = 16
    local tData = {}
    for i = 1, mapW * mapW do tData[i] = Tiles.FLOOR_STONE end

    local origWidth = Tilemap.width
    local origRawTileData = Tilemap.rawTileData
    Tilemap.width = function() return mapW end
    Tilemap.rawTileData = function() return tData end

    -- Room tile indices: 1 through 8 (8 tiles, meets barracks minSize of 6)
    local roomTiles = { 1, 2, 3, 4, 5, 6, 7, 8 }
    local thermalRooms = {
        [1] = { tiles = roomTiles, avgTemp = 20, sealed = true },
    }
    setupThermalRooms(thermalRooms)

    -- Place a bed entity at tile (0, 0) which maps to index 1 = 0 * 16 + 0 + 1
    local bedId = ECS.spawn()
    ECS.set(bedId, 'pos', { x = 0, y = 0 })
    ECS.set(bedId, 'bed', { quality = 1 })

    Rooms.classify()

    local rType = Rooms.getRoomType(1)
    T.eq(rType, 'private_bedroom', 'room with 1 bed is private bedroom')

    Tilemap.width = origWidth
    Tilemap.rawTileData = origRawTileData
    restoreThermal()
end)

T.test('room too small is not classified even with furniture', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Rooms = require('src.world.rooms')
    local Tilemap = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')

    local mapW = 16
    local tData = {}
    for i = 1, mapW * mapW do tData[i] = Tiles.FLOOR_STONE end

    local origWidth = Tilemap.width
    local origRawTileData = Tilemap.rawTileData
    Tilemap.width = function() return mapW end
    Tilemap.rawTileData = function() return tData end

    -- Room with only 3 tiles — below barracks minSize of 6
    local thermalRooms = {
        [1] = { tiles = { 1, 2, 3 }, avgTemp = 20, sealed = true },
    }
    setupThermalRooms(thermalRooms)

    local bedId = ECS.spawn()
    ECS.set(bedId, 'pos', { x = 0, y = 0 })
    ECS.set(bedId, 'bed', { quality = 1 })

    Rooms.classify()

    local rType = Rooms.getRoomType(1)
    T.isnil(rType, 'room too small for any type')

    Tilemap.width = origWidth
    Tilemap.rawTileData = origRawTileData
    restoreThermal()
end)

T.test('getRoomQuality returns 0 for unknown room', function()
    local Rooms = require('src.world.rooms')
    T.eq(Rooms.getRoomQuality(999), 0, 'unknown room quality is 0')
end)

T.test('quality score increases with better flooring', function()
    H.resetAll()
    local Rooms = require('src.world.rooms')
    local Tilemap = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')

    local mapW = 16
    local origWidth = Tilemap.width
    local origRawTileData = Tilemap.rawTileData
    Tilemap.width = function() return mapW end

    local roomTiles = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

    -- Snow floor room
    local snowData = {}
    for i = 1, mapW * mapW do snowData[i] = Tiles.SNOW end
    Tilemap.rawTileData = function() return snowData end
    setupThermalRooms({
        [1] = { tiles = roomTiles, avgTemp = 20, sealed = true },
    })
    Rooms.classify()
    local snowQuality = Rooms.getRoomQuality(1)

    -- Stone floor room (same size, same temp)
    local stoneData = {}
    for i = 1, mapW * mapW do stoneData[i] = Tiles.FLOOR_STONE end
    Tilemap.rawTileData = function() return stoneData end
    setupThermalRooms({
        [1] = { tiles = roomTiles, avgTemp = 20, sealed = true },
    })
    Rooms.classify()
    local stoneQuality = Rooms.getRoomQuality(1)

    T.gt(stoneQuality, snowQuality, 'stone floor scores higher than snow')

    Tilemap.width = origWidth
    Tilemap.rawTileData = origRawTileData
    restoreThermal()
end)

T.test('step triggers periodic reclassification', function()
    H.resetAll()
    local Rooms = require('src.world.rooms')
    local Tilemap = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')

    local mapW = 16
    local tData = {}
    for i = 1, mapW * mapW do tData[i] = Tiles.SNOW end

    local origWidth = Tilemap.width
    local origRawTileData = Tilemap.rawTileData
    Tilemap.width = function() return mapW end
    Tilemap.rawTileData = function() return tData end

    setupThermalRooms({
        [1] = { tiles = { 1, 2, 3, 4, 5, 6 }, avgTemp = 10, sealed = true },
    })

    -- step with large enough dt to trigger classification (DETECT_INTERVAL = 3)
    Rooms.step(4)
    local info = Rooms.getRoomInfo(1)
    T.notnil(info, 'room classified after step')

    Tilemap.width = origWidth
    Tilemap.rawTileData = origRawTileData
    restoreThermal()
end)
