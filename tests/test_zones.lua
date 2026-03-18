-- test_zones.lua — Zone designation system tests

local T = require('tests.test_framework')

T.suite('Zones')

T.test('create stockpile zone', function()
    local Zones = require('src.world.zones')
    local tiles = { {x=10,y=10}, {x=11,y=10}, {x=10,y=11}, {x=11,y=11} }
    local id = Zones.create('stockpile', tiles)
    T.notnil(id, 'zone created')
end)

T.test('getZoneAt finds zone', function()
    local Zones = require('src.world.zones')
    local tiles = { {x=20,y=20} }
    Zones.create('stockpile', tiles)
    local zone = Zones.getZoneAt(20, 20)
    T.notnil(zone, 'zone found')
    T.eq(zone.type, 'stockpile')
end)

T.test('getZoneAt returns nil for empty tile', function()
    local Zones = require('src.world.zones')
    local zone = Zones.getZoneAt(99, 99)
    T.isnil(zone, 'no zone at empty tile')
end)

T.test('zone types are valid', function()
    local Zones = require('src.world.zones')
    T.notnil(Zones.TYPES.stockpile)
    T.notnil(Zones.TYPES.dumping)
    T.notnil(Zones.TYPES.restricted)
end)

T.test('acceptsItem with empty filter accepts all', function()
    local Zones = require('src.world.zones')
    local tiles = { {x=30,y=30} }
    local id = Zones.create('stockpile', tiles, {})
    T.eq(Zones.acceptsItem(id, 'food'), true, 'empty filter accepts food')
    T.eq(Zones.acceptsItem(id, 'metal'), true, 'empty filter accepts metal')
end)

T.test('acceptsItem with filter rejects non-matching', function()
    local Zones = require('src.world.zones')
    local tiles = { {x=31,y=31} }
    local id = Zones.create('stockpile', tiles, { food = true })
    T.eq(Zones.acceptsItem(id, 'food'), true, 'accepts food')
    T.eq(Zones.acceptsItem(id, 'metal'), false, 'rejects metal')
end)

T.test('storeItem and getItemAt', function()
    local Zones = require('src.world.zones')
    local tiles = { {x=32,y=32} }
    local id = Zones.create('stockpile', tiles)
    Zones.storeItem(id, 32, 32, 'wood', 5)
    local item = Zones.getItemAt(id, 32, 32)
    T.notnil(item)
    T.eq(item.itemId, 'wood')
    T.eq(item.amount, 5)
end)

T.test('takeItem removes from zone', function()
    local Zones = require('src.world.zones')
    local tiles = { {x=33,y=33} }
    local id = Zones.create('stockpile', tiles)
    Zones.storeItem(id, 33, 33, 'stone', 3)
    local item = Zones.takeItem(id, 33, 33)
    T.notnil(item)
    T.eq(item.itemId, 'stone')
    T.isnil(Zones.getItemAt(id, 33, 33), 'tile empty after take')
end)

T.test('delete zone cleans up tile mapping', function()
    local Zones = require('src.world.zones')
    local tiles = { {x=34,y=34} }
    local id = Zones.create('stockpile', tiles)
    T.notnil(Zones.getZoneAt(34, 34))
    Zones.delete(id)
    T.isnil(Zones.getZoneAt(34, 34), 'zone removed after delete')
end)

T.test('tile can hold stockpile and allowed area layers at once', function()
    local Zones = require('src.world.zones')
    Zones.reset()

    local stockId = Zones.create('stockpile', { {x=40,y=40,depth=0} })
    local allowedId = Zones.create('restricted', { {x=40,y=40,depth=0} })
    local layered = Zones.getZonesAt(40, 40, 0)

    T.notnil(layered, 'layer map exists')
    T.eq(layered.stockpile.id, stockId, 'stockpile layer preserved')
    T.eq(layered.restricted.id, allowedId, 'allowed area layer preserved')
end)

T.test('allowed area applies per-depth instead of globally', function()
    local Zones = require('src.world.zones')
    Zones.reset()

    Zones.create('restricted', { {x=5,y=5,depth=1} })
    T.eq(Zones.isTileAllowed(20, 20, 0), true, 'surface remains unrestricted')

    Zones.create('restricted', { {x=10,y=10,depth=0} })
    T.eq(Zones.isTileAllowed(10, 10, 0), true, 'tile inside allowed area remains valid')
    T.eq(Zones.isTileAllowed(20, 20, 0), false, 'tiles outside allowed area are rejected on that depth')
end)
