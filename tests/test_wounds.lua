-- test_wounds.lua -- Wound application and treatment tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Combat: Wounds')

T.test('TYPES has four wound types with expected fields', function()
    local Wounds = require('src.combat.wounds')
    local expected = { 'cut', 'burn', 'frostbite', 'fracture' }
    for _, wtype in ipairs(expected) do
        T.notnil(Wounds.TYPES[wtype], 'wound type exists: ' .. wtype)
        T.notnil(Wounds.TYPES[wtype].name, wtype .. ' has name')
        T.notnil(Wounds.TYPES[wtype].painFactor, wtype .. ' has painFactor')
    end
    T.gt(Wounds.TYPES.cut.bleedRate, 0, 'cuts bleed')
    T.eq(Wounds.TYPES.burn.bleedRate, 0, 'burns do not bleed')
end)

T.test('apply creates wound on entity', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Body = require('src.combat.body')
    local Wounds = require('src.combat.wounds')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)

    Wounds.apply(id, 'left_arm', 'cut', 0.5)
    local wcomp = ECS.get(id, 'wounds')
    T.notnil(wcomp, 'wounds component created')
    T.eq(#wcomp.list, 1, 'one wound applied')
    T.eq(wcomp.list[1].type, 'cut')
    T.eq(wcomp.list[1].part, 'left_arm')
    T.eq(wcomp.list[1].treatment, 'untreated')
    T.eq(wcomp.list[1].infected, false)
end)

T.test('apply also damages the body part', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Body = require('src.combat.body')
    local Wounds = require('src.combat.wounds')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)

    local body = ECS.get(id, 'body')
    local origHp = body.parts.torso.hp
    Wounds.apply(id, 'torso', 'burn', 0.8)
    T.lt(body.parts.torso.hp, origHp, 'torso HP reduced by wound')
end)

T.test('treat advances wound through treatment stages', function()
    local Wounds = require('src.combat.wounds')
    local wound = {
        part = 'head', type = 'cut', severity = 1.0,
        treatment = 'untreated', infected = false,
        healTimer = 0, age = 0,
    }

    local ok = Wounds.treat(wound, 3)
    T.ok(ok, 'treatment succeeded')
    T.eq(wound.treatment, 'bandaged', 'advanced to bandaged')

    ok = Wounds.treat(wound, 3)
    T.ok(ok, 'second treatment succeeded')
    T.eq(wound.treatment, 'medicated', 'advanced to medicated')

    ok = Wounds.treat(wound, 3)
    T.ok(ok, 'third treatment succeeded')
    T.eq(wound.treatment, 'healed', 'advanced to healed')

    ok = Wounds.treat(wound, 3)
    T.eq(ok, false, 'cannot treat a healed wound')
end)

T.test('treat with high medical skill skips from untreated to medicated', function()
    local Wounds = require('src.combat.wounds')
    local wound = {
        part = 'torso', type = 'burn', severity = 0.5,
        treatment = 'untreated', infected = false,
        healTimer = 0, age = 0,
    }

    Wounds.treat(wound, 8)
    T.eq(wound.treatment, 'medicated', 'skilled doctor skips bandaged')
end)

T.test('hasUntreatedWounds detects untreated and bandaged wounds', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Body = require('src.combat.body')
    local Wounds = require('src.combat.wounds')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)

    T.eq(Wounds.hasUntreatedWounds(id), false, 'no wounds initially')

    Wounds.apply(id, 'left_leg', 'fracture', 0.6)
    T.ok(Wounds.hasUntreatedWounds(id), 'untreated wound detected')

    -- Treat to bandaged -- still counts as needing treatment
    local wcomp = ECS.get(id, 'wounds')
    Wounds.treat(wcomp.list[1], 3)
    T.eq(wcomp.list[1].treatment, 'bandaged')
    T.ok(Wounds.hasUntreatedWounds(id), 'bandaged wound still counts')

    -- Treat to medicated -- no longer flagged
    Wounds.treat(wcomp.list[1], 3)
    T.eq(wcomp.list[1].treatment, 'medicated')
    T.eq(Wounds.hasUntreatedWounds(id), false, 'medicated wound does not count')
end)

T.test('count returns active wound count excluding healed', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Body = require('src.combat.body')
    local Wounds = require('src.combat.wounds')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)

    T.eq(Wounds.count(id), 0, 'no wounds')

    Wounds.apply(id, 'head', 'cut', 0.3)
    Wounds.apply(id, 'torso', 'burn', 0.5)
    T.eq(Wounds.count(id), 2, 'two active wounds')

    -- Mark one as healed
    local wcomp = ECS.get(id, 'wounds')
    wcomp.list[1].treatment = 'healed'
    T.eq(Wounds.count(id), 1, 'one active after healing first')
end)

T.test('getPain scales with wound severity and treatment', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Body = require('src.combat.body')
    local Wounds = require('src.combat.wounds')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)

    T.eq(Wounds.getPain(id), 0, 'no pain without wounds')

    -- Fracture has painFactor 0.8, severity 1.0 -> untreated pain = 0.8
    Wounds.apply(id, 'left_leg', 'fracture', 1.0)
    local painBefore = Wounds.getPain(id)
    T.gt(painBefore, 0, 'has pain from fracture')

    -- Treat to bandaged: pain reduced by 40%
    local wcomp = ECS.get(id, 'wounds')
    Wounds.treat(wcomp.list[1], 3)
    local painAfter = Wounds.getPain(id)
    T.lt(painAfter, painBefore, 'pain reduced after bandaging')
end)
