-- test_items.lua -- Ground item entity system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Ground Items')

local Items = require('src.world.items')
local ECS   = require('src.ecs.ecs')

T.test('spawn creates entity with pos and item components', function()
    H.resetAll()
    local id = Items.spawn(10, 20, 'raw_wood', 5, 'resource')

    T.notnil(id, 'spawn returns entity ID')
    T.ok(ECS.isAlive(id), 'entity is alive')

    local pos = ECS.get(id, 'pos')
    T.notnil(pos, 'has pos component')
    T.eq(pos.x, 10, 'correct x')
    T.eq(pos.y, 20, 'correct y')

    local item = ECS.get(id, 'item')
    T.notnil(item, 'has item component')
    T.eq(item.itemId, 'raw_wood', 'correct item ID')
    T.eq(item.amount, 5, 'correct amount')
    T.eq(item.category, 'resource', 'correct category')
    T.eq(item.hauled, false, 'starts unhauled')
end)

T.test('spawn defaults amount to 1 and category to raw', function()
    H.resetAll()
    local id = Items.spawn(5, 5, 'coal')

    local item = ECS.get(id, 'item')
    T.eq(item.amount, 1, 'default amount is 1')
    T.eq(item.category, 'raw', 'default category is raw')
end)

T.test('getAt finds unhauled item at position', function()
    H.resetAll()
    local id = Items.spawn(15, 25, 'raw_stone', 3)

    local foundId, foundItem = Items.getAt(15, 25)
    T.eq(foundId, id, 'found the spawned item')
    T.eq(foundItem.itemId, 'raw_stone', 'correct item data')
end)

T.test('getAt returns nil for empty position', function()
    H.resetAll()
    Items.spawn(10, 10, 'wood', 1)

    local foundId = Items.getAt(99, 99)
    T.isnil(foundId, 'no item at empty position')
end)

T.test('getAt skips hauled items', function()
    H.resetAll()
    local id = Items.spawn(30, 30, 'raw_ore', 2)
    Items.pickup(id)

    local foundId = Items.getAt(30, 30)
    T.isnil(foundId, 'hauled item not returned by getAt')
end)

T.test('getAllUnhauled returns only unhauled items', function()
    H.resetAll()
    local id1 = Items.spawn(1, 1, 'wood', 5)
    local id2 = Items.spawn(2, 2, 'stone', 3)
    local id3 = Items.spawn(3, 3, 'coal', 1)

    Items.pickup(id2)

    local unhauled = Items.getAllUnhauled()
    T.eq(#unhauled, 2, 'two unhauled items')

    local foundIds = {}
    for _, entry in ipairs(unhauled) do
        foundIds[entry.id] = true
    end
    T.ok(foundIds[id1], 'includes first item')
    T.ok(foundIds[id3], 'includes third item')
    T.isnil(foundIds[id2], 'excludes hauled item')
end)

T.test('pickup marks item as hauled', function()
    H.resetAll()
    local id = Items.spawn(40, 40, 'metal_ingot', 1)

    local item = ECS.get(id, 'item')
    T.eq(item.hauled, false, 'starts unhauled')

    Items.pickup(id)
    T.eq(item.hauled, true, 'marked hauled after pickup')
end)

T.test('destroy removes entity from ECS', function()
    H.resetAll()
    local id = Items.spawn(50, 50, 'food', 10)
    T.ok(ECS.isAlive(id), 'alive before destroy')

    Items.destroy(id)
    ECS.update(0) -- flush deferred destroys
    T.eq(ECS.isAlive(id), false, 'dead after destroy and flush')
end)
