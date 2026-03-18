-- test_tiles.lua — Tile definitions and property tests

local T = require('tests.test_framework')

T.suite('Tiles')

T.test('all tile types have properties', function()
    local Tiles = require('src.world.tiles')
    for i = 0, 15 do
        local props = Tiles.get(i)
        T.notnil(props, 'props for tile ' .. i)
        T.notnil(props.name, 'name for tile ' .. i)
        T.notnil(props.color, 'color for tile ' .. i)
        T.eq(#props.color, 3, 'color has 3 components for tile ' .. i)
    end
end)

T.test('walkability correct for key tiles', function()
    local Tiles = require('src.world.tiles')
    T.eq(Tiles.isWalkable(Tiles.SNOW), true, 'snow walkable')
    T.eq(Tiles.isWalkable(Tiles.ROCK), false, 'rock not walkable')
    T.eq(Tiles.isWalkable(Tiles.WALL_WOOD), false, 'wall not walkable')
    T.eq(Tiles.isWalkable(Tiles.DOOR), true, 'door walkable')
    T.eq(Tiles.isWalkable(Tiles.FLOOR_WOOD), true, 'wood floor walkable')
end)

T.test('solidity correct', function()
    local Tiles = require('src.world.tiles')
    T.eq(Tiles.isSolid(Tiles.ROCK), true, 'rock solid')
    T.eq(Tiles.isSolid(Tiles.WALL_STONE), true, 'stone wall solid')
    T.eq(Tiles.isSolid(Tiles.SNOW), false, 'snow not solid')
    T.eq(Tiles.isSolid(Tiles.FLOOR_STONE), false, 'floor not solid')
end)

T.test('buildability correct', function()
    local Tiles = require('src.world.tiles')
    T.eq(Tiles.isBuildable(Tiles.SNOW), true, 'snow buildable')
    T.eq(Tiles.isBuildable(Tiles.DEBRIS), true, 'debris buildable')
    T.eq(Tiles.isBuildable(Tiles.ROCK), false, 'rock not buildable')
    T.eq(Tiles.isBuildable(Tiles.FLOOR_WOOD), false, 'already built not buildable')
end)

T.test('get returns void props for unknown tile type', function()
    local Tiles = require('src.world.tiles')
    local props = Tiles.get(999)
    T.notnil(props, 'returns something')
    T.eq(props.name, 'void', 'falls back to void')
end)
