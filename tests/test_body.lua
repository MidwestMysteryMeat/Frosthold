-- test_body.lua -- Body part system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Combat: Body')

T.test('PART_DEFS has six parts with correct vitality', function()
    local Body = require('src.combat.body')
    T.tablelen(Body.PART_DEFS, 6, 'six body parts defined')
    T.ok(Body.PART_DEFS.head.vital, 'head is vital')
    T.ok(Body.PART_DEFS.torso.vital, 'torso is vital')
    T.eq(Body.PART_DEFS.left_arm.vital, false, 'left_arm not vital')
    T.eq(Body.PART_DEFS.right_arm.vital, false, 'right_arm not vital')
    T.eq(Body.PART_DEFS.left_leg.vital, false, 'left_leg not vital')
    T.eq(Body.PART_DEFS.right_leg.vital, false, 'right_leg not vital')
end)

T.test('create builds body with all parts at full HP', function()
    local Body = require('src.combat.body')
    local body = Body.create()
    T.notnil(body.parts, 'body has parts table')
    for _, name in ipairs(Body.PART_NAMES) do
        local part = body.parts[name]
        T.notnil(part, 'has part: ' .. name)
        T.eq(part.hp, part.maxHp, name .. ' at full HP')
        T.eq(part.status, 'healthy', name .. ' healthy')
    end
end)

T.test('attach adds body component to entity', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Body = require('src.combat.body')
    local id = H.spawnTestColonist(10, 10)
    T.ok(not ECS.has(id, 'body'), 'no body before attach')
    Body.attach(id)
    T.ok(ECS.has(id, 'body'), 'body attached')
    local body = ECS.get(id, 'body')
    T.notnil(body.parts.head, 'head exists after attach')
end)

T.test('damagePart reduces HP and sets injured status', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Body = require('src.combat.body')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)

    local killed = Body.damagePart(id, 'left_arm', 25)
    T.eq(killed, false, 'non-vital damage does not kill')
    local body = ECS.get(id, 'body')
    local arm = body.parts.left_arm
    T.eq(arm.hp, 15, 'HP reduced from 40 to 15')
    T.eq(arm.status, 'injured', 'below 50% HP sets injured')
end)

T.test('damagePart on vital part returns true (lethal)', function()
    H.resetAll()
    local Body = require('src.combat.body')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)

    local killed = Body.damagePart(id, 'head', 30)
    T.ok(killed, 'destroying head is lethal')
end)

T.test('randomPart always returns a valid part name', function()
    local Body = require('src.combat.body')
    local validParts = {}
    for _, name in ipairs(Body.PART_NAMES) do
        validParts[name] = true
    end
    for _ = 1, 50 do
        local part = Body.randomPart()
        T.ok(validParts[part], 'randomPart returned valid name: ' .. tostring(part))
    end
end)

T.test('getMoveSpeedMultiplier reflects leg damage', function()
    H.resetAll()
    local Body = require('src.combat.body')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)

    T.eq(Body.getMoveSpeedMultiplier(id), 1.0, 'full speed with both legs')
    Body.damagePart(id, 'left_leg', 999)
    T.eq(Body.getMoveSpeedMultiplier(id), 0.5, 'half speed with one leg destroyed')
    Body.damagePart(id, 'right_leg', 999)
    T.eq(Body.getMoveSpeedMultiplier(id), 0.0, 'immobile with both legs destroyed')
end)

T.test('healPart restores HP but cannot heal destroyed parts', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Body = require('src.combat.body')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)

    Body.damagePart(id, 'torso', 40)
    local body = ECS.get(id, 'body')
    T.eq(body.parts.torso.hp, 20, 'torso at 20 HP after damage')
    Body.healPart(id, 'torso', 15)
    T.eq(body.parts.torso.hp, 35, 'healed to 35')

    -- Destroy left_arm then try to heal
    Body.damagePart(id, 'left_arm', 999)
    T.eq(body.parts.left_arm.status, 'destroyed')
    Body.healPart(id, 'left_arm', 20)
    T.eq(body.parts.left_arm.hp, 0, 'destroyed part stays at 0')
end)
