-- test_colonist.lua — Colonist spawning, components, and needs tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Colonist')

T.test('spawn creates entity with all required components', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')

    local id = Colonist.spawn(10, 20)
    T.ok(ECS.isAlive(id), 'entity is alive')
    T.ok(ECS.has(id, 'pos'), 'has pos component')
    T.ok(ECS.has(id, 'colonist'), 'has colonist component')
    T.ok(ECS.has(id, 'needs'), 'has needs component')
    T.ok(ECS.has(id, 'inventory'), 'has inventory component')
    T.ok(ECS.has(id, 'path'), 'has path component')
    T.ok(ECS.has(id, 'schedule'), 'has schedule component')
    T.ok(ECS.has(id, 'workPriority'), 'has workPriority component')
end)

T.test('spawn places entity at correct position', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')

    local id = Colonist.spawn(30, 45)
    local pos = ECS.get(id, 'pos')
    T.eq(pos.x, 30, 'x position')
    T.eq(pos.y, 45, 'y position')
    T.eq(pos.prevX, 30, 'prevX matches x')
    T.eq(pos.prevY, 45, 'prevY matches y')
end)

T.test('spawned colonist has valid health and state', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')

    local id = Colonist.spawn(5, 5)
    local col = ECS.get(id, 'colonist')
    T.eq(col.health, 100, 'health is 100')
    T.eq(col.maxHealth, 100, 'maxHealth is 100')
    T.eq(col.sanity, 100, 'sanity is 100')
    T.eq(col.state, 'idle', 'initial state is idle')
    T.isnil(col.task, 'no task assigned')
end)

T.test('spawned colonist has generated identity', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')

    local id = Colonist.spawn(5, 5)
    local col = ECS.get(id, 'colonist')
    T.notnil(col.name, 'has a name')
    T.ok(#col.name > 0, 'name is non-empty')
    T.notnil(col.backstory, 'has a backstory')
    T.notnil(col.traits, 'has traits table')
    T.notnil(col.skills, 'has skills table')
end)

T.test('spawned colonist has all six skill keys', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')

    local id = Colonist.spawn(5, 5)
    local col = ECS.get(id, 'colonist')
    local skills = col.skills
    T.has_key(skills, 'mining', 'has mining')
    T.has_key(skills, 'building', 'has building')
    T.has_key(skills, 'cooking', 'has cooking')
    T.has_key(skills, 'hunting', 'has hunting')
    T.has_key(skills, 'research', 'has research')
    T.has_key(skills, 'medical', 'has medical')

    -- All skills in valid range (1-10)
    for k, v in pairs(skills) do
        T.gte(v, 1, k .. ' >= 1')
        T.ok(v <= 10, k .. ' <= 10')
    end
end)

T.test('spawn sets initial needs values', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')

    local id = Colonist.spawn(5, 5)
    local needs = ECS.get(id, 'needs')
    T.eq(needs.warmth, 60, 'spawn warmth is 60')
    T.eq(needs.food, 60, 'spawn food is 60')
    T.eq(needs.rest, 60, 'spawn rest is 60')
    T.eq(needs.morale, 50, 'spawn morale is 50')
end)

T.test('helper spawnTestColonist sets custom needs', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')

    local id = H.spawnTestColonist(10, 10, { warmth = 20, food = 30 })
    local needs = ECS.get(id, 'needs')
    T.eq(needs.warmth, 20, 'custom warmth')
    T.eq(needs.food, 30, 'custom food')
end)

T.test('inventory starts empty with at least base max weight', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')

    local id = Colonist.spawn(5, 5)
    local inv = ECS.get(id, 'inventory')
    T.notnil(inv, 'has inventory')
    T.tablelen(inv.items, 0, 'no items')
    T.gte(inv.maxWeight, 50, 'maxWeight is at least the base 50')
    T.eq(inv.currentWeight, 0, 'currentWeight starts at 0')
end)

T.test('colonist can escape a tile buried by impassable snow', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')
    local Lighting = require('src.sim.lighting')
    local Occupancy = require('src.util.occupancy')
    local World = require('src.world.tilemap')

    World.init(16, 16)
    Lighting.init(World)
    local id = H.spawnTestColonist(5, 5)
    ECS.get(id, 'path').nodes = { { x = 6, y = 5 } }
    World.setSnow(5, 5, 7, 0)
    World.setSnow(6, 5, 0, 0)
    Occupancy.rebuild()
    Colonist.registerSystems()

    ECS.update(3)
    local pos = ECS.get(id, 'pos')
    T.eq(pos.x, 6, 'movement retains a nonzero escape speed')
    T.eq(pos.y, 5, 'colonist reaches the clear neighboring tile')
end)

T.test('persistent occupied destination releases the blocked path', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')
    local Lighting = require('src.sim.lighting')
    local Occupancy = require('src.util.occupancy')
    local World = require('src.world.tilemap')

    World.init(16, 16)
    Lighting.init(World)
    local mover = H.spawnTestColonist(5, 5)
    local blocker = H.spawnTestColonist(6, 5)
    ECS.get(mover, 'path').nodes = { { x = 6, y = 5 } }
    Occupancy.rebuild()
    Colonist.registerSystems()

    for _ = 1, 24 do
        ECS.update(1)
    end

    T.isnil(ECS.get(mover, 'path').nodes,
        'path is returned to work AI after repeated blocked reroutes')
    T.eq(ECS.get(mover, 'pos').x, 5, 'mover never overlaps the blocker')
    T.eq(Occupancy.getAt(6, 5, 0), blocker, 'blocker keeps its tile reservation')
end)
