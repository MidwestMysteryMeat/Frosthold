-- test_ecs.lua — ECS core functionality tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('ECS Core')

T.test('spawn returns incrementing IDs', function()
    H.resetECS()
    local ECS = require('src.ecs.ecs')
    local id1 = ECS.spawn()
    local id2 = ECS.spawn()
    T.ok(id1 > 0, 'first id positive')
    T.eq(id2, id1 + 1, 'ids increment')
end)

T.test('set and get component', function()
    H.resetECS()
    local ECS = require('src.ecs.ecs')
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = 10, y = 20 })
    local pos = ECS.get(id, 'pos')
    T.notnil(pos, 'pos not nil')
    T.eq(pos.x, 10, 'x value')
    T.eq(pos.y, 20, 'y value')
end)

T.test('has component', function()
    H.resetECS()
    local ECS = require('src.ecs.ecs')
    local id = ECS.spawn()
    T.eq(ECS.has(id, 'pos'), false, 'no pos yet')
    ECS.set(id, 'pos', { x = 0, y = 0 })
    T.eq(ECS.has(id, 'pos'), true, 'has pos now')
end)

T.test('remove component', function()
    H.resetECS()
    local ECS = require('src.ecs.ecs')
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = 0, y = 0 })
    T.eq(ECS.has(id, 'pos'), true)
    ECS.remove(id, 'pos')
    T.eq(ECS.has(id, 'pos'), false)
end)

T.test('destroy entity', function()
    H.resetECS()
    local ECS = require('src.ecs.ecs')
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = 0, y = 0 })
    T.eq(ECS.isAlive(id), true)
    ECS.destroy(id)
    -- Destruction is deferred, flush via update
    ECS.update(0.05)
    T.eq(ECS.isAlive(id), false)
end)

T.test('query returns matching entities', function()
    H.resetECS()
    local ECS = require('src.ecs.ecs')
    local id1 = ECS.spawn()
    ECS.set(id1, 'pos', { x = 1, y = 1 })
    ECS.set(id1, 'colonist', { name = 'A' })

    local id2 = ECS.spawn()
    ECS.set(id2, 'pos', { x = 2, y = 2 })
    -- id2 has pos but no colonist

    local count = 0
    for id, comps in ECS.query('pos', 'colonist') do
        count = count + 1
        T.eq(id, id1, 'only entity with both components')
    end
    T.eq(count, 1, 'exactly one match')
end)

T.test('countWith counts correct components', function()
    H.resetECS()
    local ECS = require('src.ecs.ecs')
    T.eq(ECS.countWith('colonist'), 0, 'none at start')

    local id1 = ECS.spawn()
    ECS.set(id1, 'colonist', { name = 'A' })
    local id2 = ECS.spawn()
    ECS.set(id2, 'colonist', { name = 'B' })
    local id3 = ECS.spawn()
    ECS.set(id3, 'creature', { name = 'C' })

    T.eq(ECS.countWith('colonist'), 2, 'two colonists')
    T.eq(ECS.countWith('creature'), 1, 'one creature')
end)

T.test('system runs on matching entities', function()
    H.resetECS()
    local ECS = require('src.ecs.ecs')
    local ran = {}
    ECS.addSystem('test_sys', { 'pos', 'marker' }, function(dt, id, comps)
        ran[id] = true
    end, 100)

    local id1 = ECS.spawn()
    ECS.set(id1, 'pos', { x = 0, y = 0 })
    ECS.set(id1, 'marker', { val = 1 })

    local id2 = ECS.spawn()
    ECS.set(id2, 'pos', { x = 1, y = 1 })
    -- no marker

    ECS.update(0.05)
    T.ok(ran[id1], 'system ran on entity with both components')
    T.isnil(ran[id2], 'system did not run on entity missing component')
end)

T.test('deferred destroy flushes after update', function()
    H.resetECS()
    local ECS = require('src.ecs.ecs')
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = 0, y = 0 })
    ECS.destroy(id)
    -- Still alive until update flushes
    T.eq(ECS.isAlive(id), true, 'alive before flush')
    ECS.update(0.05)
    T.eq(ECS.isAlive(id), false, 'dead after flush')
end)
