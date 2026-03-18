-- test_equipment.lua -- Equipment slot system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Colonist: Equipment')

T.test('create returns empty equipment slots', function()
    local Equipment = require('src.colonist.equipment')
    local equip = Equipment.create()
    T.isnil(equip.weapon, 'no weapon')
    T.isnil(equip.armor, 'no armor')
    T.isnil(equip.accessory, 'no accessory')
end)

T.test('equipWeapon sets weapon data on entity', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Body = require('src.combat.body')
    local Equipment = require('src.colonist.equipment')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)
    Equipment.attach(id)

    local ok = Equipment.equipWeapon(id, 'sword')
    T.ok(ok, 'equip succeeded')
    local equip = ECS.get(id, 'equipment')
    T.notnil(equip.weapon, 'weapon populated')
    T.eq(equip.weapon.id, 'sword')
    T.eq(equip.weapon.dmg, 16)
    T.eq(equip.weapon.twoHanded, false)
end)

T.test('equipWeapon rejects invalid weapon ID', function()
    H.resetAll()
    local Equipment = require('src.colonist.equipment')
    local id = H.spawnTestColonist(10, 10)
    Equipment.attach(id)

    local ok = Equipment.equipWeapon(id, 'plasma_cannon')
    T.eq(ok, false, 'unknown weapon rejected')
end)

T.test('two-handed weapon blocked when arm is destroyed', function()
    H.resetAll()
    local Body = require('src.combat.body')
    local Equipment = require('src.colonist.equipment')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)
    Equipment.attach(id)

    -- Destroy left arm
    Body.damagePart(id, 'left_arm', 999)
    T.eq(Body.canUseTwoHanded(id), false, 'cannot use two-handed with one arm')

    local ok = Equipment.equipWeapon(id, 'axe')
    T.eq(ok, false, 'two-handed weapon blocked')

    -- One-handed weapon still works
    ok = Equipment.equipWeapon(id, 'knife')
    T.ok(ok, 'one-handed weapon allowed')
end)

T.test('unequipWeapon clears the weapon slot', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Equipment = require('src.colonist.equipment')
    local id = H.spawnTestColonist(10, 10)
    Equipment.attach(id)

    Equipment.equipWeapon(id, 'knife')
    T.notnil(ECS.get(id, 'equipment').weapon, 'weapon equipped')
    Equipment.unequipWeapon(id)
    T.isnil(ECS.get(id, 'equipment').weapon, 'weapon cleared')
end)

T.test('getArmorReduction returns correct value', function()
    H.resetAll()
    local Equipment = require('src.colonist.equipment')
    local id = H.spawnTestColonist(10, 10)
    Equipment.attach(id)

    T.eq(Equipment.getArmorReduction(id), 0, 'no armor = 0 reduction')

    Equipment.equipArmor(id, 'metal_plate')
    T.eq(Equipment.getArmorReduction(id), 10, 'metal plate gives 10 reduction')
    T.near(Equipment.getSpeedPenalty(id), 0.15, 0.001, 'metal plate speed penalty')

    Equipment.unequipArmor(id)
    T.eq(Equipment.getArmorReduction(id), 0, 'back to 0 after unequip')
end)

T.test('getWeaponDamage returns unarmed base when no weapon', function()
    H.resetAll()
    local Equipment = require('src.colonist.equipment')
    local id = H.spawnTestColonist(10, 10)
    Equipment.attach(id)

    T.eq(Equipment.getWeaponDamage(id), 5, 'unarmed base damage is 5')
    T.eq(Equipment.getWeaponRange(id), 1, 'unarmed range is 1')
    T.eq(Equipment.isRanged(id), false, 'unarmed is not ranged')
end)

T.test('accessory effect returns correct value for matching effect', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Equipment = require('src.colonist.equipment')
    local id = H.spawnTestColonist(10, 10)
    Equipment.attach(id)

    T.eq(Equipment.getAccessoryEffect(id, 'warmth'), 0, 'no accessory = 0')

    Equipment.equipAccessory(id, 'warm_scarf')
    T.eq(Equipment.getAccessoryEffect(id, 'warmth'), 8, 'scarf gives 8 warmth')
    T.eq(Equipment.getAccessoryEffect(id, 'morale'), 0, 'scarf does not give morale')

    Equipment.unequipAccessory(id)
    T.eq(Equipment.getAccessoryEffect(id, 'warmth'), 0, 'cleared after unequip')
end)
