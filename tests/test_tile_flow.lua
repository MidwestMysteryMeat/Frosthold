local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Tile Flow')

local function initLineWorld(doorTile)
    local World = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')
    World.init(3, 1)
    World.setTile(0, 0, Tiles.FLOOR_STONE, 0)
    World.setTile(1, 0, doorTile, 0)
    World.setTile(2, 0, Tiles.FLOOR_STONE, 0)
    return World, Tiles
end

T.test('sealed doors block water spread', function()
    H.resetAll()
    local TileFluids = require('src.sim.tile_fluids')
    local World = initLineWorld(require('src.world.tiles').DOOR_SEALED)
    TileFluids.init()

    TileFluids.addWater(0, 0, 7, 0)
    for _ = 1, 120 do
        TileFluids.step(0.05)
    end

    T.eq(World.getWater(1, 0, 0), 0, 'sealed door tile stays dry')
    T.eq(World.getWater(2, 0, 0), 0, 'water does not leak through sealed door')
end)

T.test('sealed doors block gas spread', function()
    H.resetAll()
    local TileGas = require('src.sim.tile_gas')
    local World = initLineWorld(require('src.world.tiles').DOOR_SEALED)
    TileGas.init()

    TileGas.addGas(0, 0, 7, TileGas.TYPE_CO2, 0)
    for _ = 1, 40 do
        TileGas.step(0.1)
    end

    T.eq(World.getGas(1, 0, 0), 0, 'sealed door tile stays clean')
    T.eq(World.getGas(2, 0, 0), 0, 'gas does not leak through sealed door')
end)

T.test('normal doors still leak gas', function()
    H.resetAll()
    local TileGas = require('src.sim.tile_gas')
    local World = initLineWorld(require('src.world.tiles').DOOR)
    TileGas.init()

    TileGas.addGas(0, 0, 7, TileGas.TYPE_CO2, 0)
    for _ = 1, 80 do
        TileGas.step(0.1)
    end

    T.gt(World.getGas(1, 0, 0), 0, 'normal door tile fills with gas')
end)
