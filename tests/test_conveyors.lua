-- test_conveyors.lua -- Belt/conveyor transport system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Conveyors')

-- Tilemap must be initialized for inBounds/getTemp to work.
local function initTilemap()
    local Tilemap = require('src.world.tilemap')
    Tilemap.init(128, 128)
end

T.test('place belt on valid tile', function()
    H.resetAll()
    initTilemap()
    local C = require('src.logistics.conveyors')
    C.init()

    local ok = C.place(10, 10, 'E')
    T.ok(ok, 'placement succeeds on valid tile')
    T.ok(C.isBelt(10, 10), 'tile is now a belt')
    T.eq(C.count(), 1, 'belt count is 1')
end)

T.test('place belt rejects invalid direction and out of bounds', function()
    H.resetAll()
    initTilemap()
    local C = require('src.logistics.conveyors')
    C.init()

    T.eq(C.place(10, 10, 'X'), false, 'invalid direction rejected')
    T.eq(C.place(-1, 0, 'N'), false, 'out of bounds rejected')
    T.eq(C.count(), 0, 'no belts placed')
end)

T.test('cannot place belt on occupied tile', function()
    H.resetAll()
    initTilemap()
    local C = require('src.logistics.conveyors')
    C.init()

    C.place(5, 5, 'N')
    local ok = C.place(5, 5, 'S')
    T.eq(ok, false, 'duplicate placement rejected')
    T.eq(C.count(), 1, 'still only one belt')
end)

T.test('remove belt clears tile', function()
    H.resetAll()
    initTilemap()
    local C = require('src.logistics.conveyors')
    C.init()

    C.place(8, 8, 'W')
    T.ok(C.isBelt(8, 8), 'belt exists before removal')
    local removed = C.remove(8, 8)
    T.ok(removed, 'remove returns true')
    T.eq(C.isBelt(8, 8), false, 'belt gone after removal')
    T.eq(C.count(), 0, 'count back to 0')
end)

T.test('insert and extract item on belt', function()
    H.resetAll()
    initTilemap()
    local C = require('src.logistics.conveyors')
    C.init()

    C.place(12, 12, 'E')
    T.eq(C.hasItem(12, 12), false, 'no item initially')

    local inserted = C.insertItem(12, 12, 'metal_ingot')
    T.ok(inserted, 'insert succeeds on empty belt')
    T.ok(C.hasItem(12, 12), 'belt has item after insert')
    T.eq(C.getItemId(12, 12), 'metal_ingot', 'correct item ID')

    -- Cannot insert a second item
    T.eq(C.insertItem(12, 12, 'coal'), false, 'second insert rejected')

    local extracted = C.extractItem(12, 12)
    T.eq(extracted, 'metal_ingot', 'extract returns item ID')
    T.eq(C.hasItem(12, 12), false, 'belt empty after extract')
end)

T.test('belt moves item to next tile on step', function()
    H.resetAll()
    initTilemap()
    local Tilemap = require('src.world.tilemap')
    local C = require('src.logistics.conveyors')
    C.init()

    -- Place two east-facing belts at (20,20) and (21,20)
    C.place(20, 20, 'E')
    C.place(21, 20, 'E')

    -- Warm tiles so belts don't freeze
    Tilemap.setTemp(20, 20, 0)
    Tilemap.setTemp(21, 20, 0)

    C.insertItem(20, 20, 'coal')

    -- Step enough time for item to traverse one belt (speed = 1 tile/s)
    C.step(1.0)

    T.eq(C.hasItem(20, 20), false, 'item left source belt')
    T.ok(C.hasItem(21, 20), 'item arrived on next belt')
    T.eq(C.getItemId(21, 20), 'coal', 'correct item moved')
end)

T.test('frozen belt does not move items', function()
    H.resetAll()
    initTilemap()
    local Tilemap = require('src.world.tilemap')
    local C = require('src.logistics.conveyors')
    C.init()

    C.place(30, 30, 'E')
    C.place(31, 30, 'E')

    -- Set temperature below freeze threshold (-20C)
    Tilemap.setTemp(30, 30, -25)
    Tilemap.setTemp(31, 30, -25)

    C.insertItem(30, 30, 'stone')
    C.step(2.0)

    T.ok(C.isFrozen(30, 30), 'belt is frozen')
    T.ok(C.hasItem(30, 30), 'item still on frozen belt')
    T.eq(C.hasItem(31, 30), false, 'item did not move')
end)

T.test('splitter placement and belt count', function()
    H.resetAll()
    initTilemap()
    local C = require('src.logistics.conveyors')
    C.init()

    local ok = C.placeSplitter(40, 40, 'E')
    T.ok(ok, 'splitter placed')
    T.ok(C.isBelt(40, 40), 'splitter counts as belt')
    T.eq(C.count(), 1, 'count includes splitter')

    local belt = C.getBelt(40, 40)
    T.notnil(belt.splitter, 'belt has splitter data')
end)
