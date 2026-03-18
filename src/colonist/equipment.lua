-- equipment.lua -- Equipment slot system for colonists
-- Slots: weapon, armor, accessory
-- Weapon: provides typed damage (sharp/blunt/fire/etc) and range.
-- Armor: provides per-type damage resistance.
-- Quality: affects stat multipliers on weapons and armor.
-- Equipment stored as 'equipment' component on colonist entities.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local _StorageNet
local function getStorageNet()
    if _StorageNet == nil then
        local ok, mod = pcall(require, 'src.logistics.storage_network')
        _StorageNet = ok and mod or false
    end
    return _StorageNet or nil
end

local Equipment = {}

---------------------------------------------------------------------------
-- Weapon definitions
---------------------------------------------------------------------------

local WEAPONS = {
    --------------- Improvised melee (tier 0) ---------------
    club        = { id = 'club',        name = 'Club',        dmg = 6,  range = 1, twoHanded = false, category = 'melee', material = 'wood',  damageType = 'blunt' },
    shiv        = { id = 'shiv',        name = 'Shiv',        dmg = 5,  range = 1, twoHanded = false, category = 'melee', material = 'wood',  damageType = 'sharp' },
    pipe_wrench = { id = 'pipe_wrench', name = 'Pipe Wrench', dmg = 10, range = 1, twoHanded = false, category = 'melee', material = 'metal', damageType = 'blunt' },
    torch       = { id = 'torch',       name = 'Torch',       dmg = 4,  range = 1, twoHanded = false, category = 'melee', material = 'wood',  damageType = 'fire', fire = true },

    --------------- Crafted melee (tier 1-2) ---------------
    knife   = { id = 'knife',   name = 'Knife',   dmg = 8,  range = 1, twoHanded = false, category = 'melee', material = 'metal', damageType = 'sharp' },
    hatchet = { id = 'hatchet', name = 'Hatchet', dmg = 10, range = 1, twoHanded = false, category = 'melee', material = 'metal', damageType = 'sharp' },
    machete = { id = 'machete', name = 'Machete', dmg = 12, range = 1, twoHanded = false, category = 'melee', material = 'metal', damageType = 'sharp' },
    spear   = { id = 'spear',   name = 'Spear',   dmg = 14, range = 2, twoHanded = true,  category = 'melee', material = 'wood',  damageType = 'sharp' },
    sword   = { id = 'sword',   name = 'Sword',   dmg = 16, range = 1, twoHanded = false, category = 'melee', material = 'metal', damageType = 'sharp' },
    axe     = { id = 'axe',     name = 'Ice Axe', dmg = 18, range = 1, twoHanded = true,  category = 'melee', material = 'metal', damageType = 'sharp' },

    --------------- Advanced melee (tier 2-3) ---------------
    hammer       = { id = 'hammer',       name = 'War Hammer',    dmg = 20, range = 1, twoHanded = true,  category = 'melee', material = 'metal',    damageType = 'blunt' },
    power_fist   = { id = 'power_fist',   name = 'Power Fist',    dmg = 22, range = 1, twoHanded = false, category = 'melee', material = 'plasteel', damageType = 'blunt' },
    stun_baton   = { id = 'stun_baton',   name = 'Stun Baton',    dmg = 8,  range = 1, twoHanded = false, category = 'melee', material = 'metal',    damageType = 'electric' },
    thermal_blade = { id = 'thermal_blade', name = 'Thermal Blade', dmg = 24, range = 1, twoHanded = false, category = 'melee', material = 'thermal_alloy', damageType = 'fire' },

    --------------- Thermal weapons (tier 3) ---------------
    thermal_lance = { id = 'thermal_lance', name = 'Thermal Lance', dmg = 30, range = 8, twoHanded = true, accuracy = 0.70, category = 'ranged', ammoType = 'ammo_thermal', material = 'thermal_alloy', damageType = 'fire', fire = true },

    --------------- Thermal throwables ---------------
    cryo_grenade = { id = 'cryo_grenade', name = 'Cryo Grenade', dmg = 20, range = 5, twoHanded = false, accuracy = 0.65, category = 'thrown', aoe = 3, singleUse = true, damageType = 'cold' },

    --------------- Bows / crossbows (tier 1-2) ---------------
    shortbow    = { id = 'shortbow',    name = 'Short Bow',  dmg = 10, range = 5, twoHanded = true, accuracy = 0.65, category = 'ranged', ammoType = 'ammo_arrow', material = 'wood',  damageType = 'sharp' },
    hunting_bow = { id = 'hunting_bow', name = 'Hunting Bow', dmg = 15, range = 6, twoHanded = true, accuracy = 0.70, category = 'ranged', ammoType = 'ammo_arrow', material = 'wood',  damageType = 'sharp' },
    crossbow    = { id = 'crossbow',    name = 'Crossbow',   dmg = 22, range = 7, twoHanded = true, accuracy = 0.80, category = 'ranged', ammoType = 'ammo_bolt',  material = 'metal', damageType = 'sharp' },

    --------------- Pistols (tier 2) ---------------
    revolver = { id = 'revolver', name = 'Revolver', dmg = 16, range = 6, twoHanded = false, accuracy = 0.65, category = 'ranged', ammoType = 'ammo_bullet', damageType = 'sharp' },
    pistol   = { id = 'pistol',   name = 'Pistol',   dmg = 14, range = 7, twoHanded = false, accuracy = 0.70, category = 'ranged', ammoType = 'ammo_bullet', damageType = 'sharp' },

    --------------- Shotguns (tier 2) ---------------
    sawed_off    = { id = 'sawed_off',    name = 'Sawed-Off',    dmg = 30, range = 3, twoHanded = false, accuracy = 0.75, category = 'ranged', ammoType = 'ammo_shell', damageType = 'sharp' },
    pump_shotgun = { id = 'pump_shotgun', name = 'Pump Shotgun', dmg = 28, range = 5, twoHanded = true,  accuracy = 0.80, category = 'ranged', ammoType = 'ammo_shell', damageType = 'sharp' },

    --------------- Rifles (tier 2-3) ---------------
    bolt_action    = { id = 'bolt_action',    name = 'Bolt-Action Rifle', dmg = 28, range = 10, twoHanded = true, accuracy = 0.85, category = 'ranged', ammoType = 'ammo_bullet', damageType = 'sharp' },
    assault_rifle  = { id = 'assault_rifle',  name = 'Assault Rifle',     dmg = 18, range = 9,  twoHanded = true, accuracy = 0.60, category = 'ranged', ammoType = 'ammo_bullet', damageType = 'sharp' },
    battle_rifle   = { id = 'battle_rifle',   name = 'Battle Rifle',      dmg = 24, range = 11, twoHanded = true, accuracy = 0.75, category = 'ranged', ammoType = 'ammo_bullet', damageType = 'sharp' },

    --------------- Thrown (single-use, AOE) ---------------
    grenade   = { id = 'grenade',   name = 'Grenade',          dmg = 40, range = 5, twoHanded = false, accuracy = 0.60, category = 'thrown', aoe = 3, singleUse = true, damageType = 'explosive' },
    ied       = { id = 'ied',       name = 'IED',              dmg = 50, range = 3, twoHanded = false, accuracy = 0.50, category = 'thrown', aoe = 4, singleUse = true, damageType = 'explosive' },
    molotov   = { id = 'molotov',   name = 'Molotov Cocktail', dmg = 15, range = 4, twoHanded = false, accuracy = 0.65, category = 'thrown', aoe = 2, singleUse = true, damageType = 'fire', fire = true },
    pipe_bomb = { id = 'pipe_bomb', name = 'Pipe Bomb',        dmg = 35, range = 4, twoHanded = false, accuracy = 0.55, category = 'thrown', aoe = 2, singleUse = true, damageType = 'explosive' },

    --------------- Ordnance throwables ---------------
    napalm_grenade = { id = 'napalm_grenade', name = 'Napalm Grenade', dmg = 15, range = 5, twoHanded = false, accuracy = 0.60, category = 'thrown', aoe = 3, singleUse = true, damageType = 'fire', fire = true, ordnanceType = 'napalm_grenade' },
    bio_grenade    = { id = 'bio_grenade',    name = 'Bio Grenade',    dmg = 5,  range = 5, twoHanded = false, accuracy = 0.55, category = 'thrown', aoe = 4, singleUse = true, damageType = 'bio', ordnanceType = 'bio_grenade' },
    foam_grenade   = { id = 'foam_grenade',   name = 'Foam Grenade',   dmg = 0,  range = 6, twoHanded = false, accuracy = 0.70, category = 'thrown', aoe = 3, singleUse = true, damageType = 'blunt', ordnanceType = 'foam_grenade' },
    emp_grenade    = { id = 'emp_grenade',    name = 'EMP Grenade',    dmg = 3,  range = 5, twoHanded = false, accuracy = 0.65, category = 'thrown', aoe = 3, singleUse = true, damageType = 'electric', ordnanceType = 'emp_grenade' },
}

---------------------------------------------------------------------------
-- Armor definitions
---------------------------------------------------------------------------

local ARMORS = {
    hide_coat = {
        id = 'hide_coat', name = 'Hide Coat',
        reduction = 3,
        warmthBonus = 5,
        material = 'hide',
        resist = { sharp = 0.10, blunt = 0.05, cold = 0.30, fire = 0.10, bio = 0.00, electric = 0.00, explosive = 0.05 },
    },
    leather_armor = {
        id = 'leather_armor', name = 'Leather Armor',
        reduction = 5,
        warmthBonus = 3,
        material = 'hide',
        resist = { sharp = 0.20, blunt = 0.10, cold = 0.25, fire = 0.10, bio = 0.05, electric = 0.00, explosive = 0.10 },
    },
    metal_plate = {
        id = 'metal_plate', name = 'Metal Plate',
        reduction = 10,
        warmthBonus = 0,
        speedPenalty = 0.15,
        material = 'metal',
        resist = { sharp = 0.55, blunt = 0.45, cold = 0.05, fire = 0.30, bio = 0.10, electric = 0.15, explosive = 0.35 },
    },
    thermal_suit = {
        id = 'thermal_suit', name = 'Thermal Suit',
        reduction = 4,
        warmthBonus = 15,
        material = 'components',
        resist = { sharp = 0.10, blunt = 0.05, cold = 0.60, fire = 0.20, bio = 0.15, electric = 0.10, explosive = 0.10 },
    },
}

---------------------------------------------------------------------------
-- Accessory definitions
---------------------------------------------------------------------------

local ACCESSORIES = {
    warm_scarf = {
        id = 'warm_scarf', name = 'Warm Scarf',
        effect = 'warmth', value = 8,
    },
    lucky_charm = {
        id = 'lucky_charm', name = 'Lucky Charm',
        effect = 'morale', value = 5,
    },
    medkit_pouch = {
        id = 'medkit_pouch', name = 'Medkit Pouch',
        effect = 'medical', value = 2, -- bonus to medical skill
    },
    scope = {
        id = 'scope', name = 'Rifle Scope',
        effect = 'accuracy', value = 0.1, -- bonus to ranged accuracy
    },
}

Equipment.WEAPONS     = WEAPONS
Equipment.ARMORS      = ARMORS
Equipment.ACCESSORIES = ACCESSORIES

---------------------------------------------------------------------------
-- Create a default (empty) equipment component
---------------------------------------------------------------------------

function Equipment.create()
    return {
        weapon    = nil, -- { id, dmg, range, twoHanded, accuracy, category }
        armor     = nil, -- { id, reduction, warmthBonus, speedPenalty }
        accessory = nil, -- { id, effect, value }
    }
end

---------------------------------------------------------------------------
-- Attach empty equipment to entity
---------------------------------------------------------------------------

function Equipment.attach(entityId)
    if not ECS.has(entityId, 'equipment') then
        ECS.set(entityId, 'equipment', Equipment.create())
    end
end

---------------------------------------------------------------------------
-- Equip / unequip
---------------------------------------------------------------------------

function Equipment.equipWeapon(entityId, weaponId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip then return false end
    local def = WEAPONS[weaponId]
    if not def then return false end

    -- Check two-handed restriction
    if def.twoHanded then
        local Body = require('src.combat.body')
        if not Body.canUseTwoHanded(entityId) then
            return false
        end
    end

    -- Apply quality multiplier to damage if present
    local baseDmg = def.dmg
    local qOk, Quality = pcall(require, 'src.world.quality')
    local qualityId = 'normal'
    if qOk and equip._pendingQuality then
        qualityId = equip._pendingQuality
        equip._pendingQuality = nil
        baseDmg = math.floor(baseDmg * Quality.getStatMult(qualityId) + 0.5)
    end

    equip.weapon = {
        id         = def.id,
        name       = def.name,
        dmg        = baseDmg,
        baseDmg    = def.dmg,
        range      = def.range,
        twoHanded  = def.twoHanded,
        accuracy   = def.accuracy or 1.0,
        category   = def.category,
        ammoType   = def.ammoType,
        damageType = def.damageType or 'sharp',
        fire       = def.fire,
        aoe        = def.aoe,
        singleUse  = def.singleUse,
        quality    = qualityId,
    }
    return true
end

function Equipment.unequipWeapon(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip then return end
    equip.weapon = nil
end

function Equipment.equipArmor(entityId, armorId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip then return false end
    local def = ARMORS[armorId]
    if not def then return false end

    -- Apply quality multiplier to reduction if present
    local baseReduction = def.reduction
    local qOk, Quality = pcall(require, 'src.world.quality')
    local qualityId = 'normal'
    if qOk and equip._pendingQuality then
        qualityId = equip._pendingQuality
        equip._pendingQuality = nil
        baseReduction = math.floor(baseReduction * Quality.getStatMult(qualityId) + 0.5)
    end

    -- Copy resist table, scale by quality
    local resist = {}
    local defResist = def.resist or {}
    local qMult = qOk and Quality.getStatMult(qualityId) or 1.0
    for k, v in pairs(defResist) do
        resist[k] = math.min(0.95, v * qMult)
    end

    equip.armor = {
        id           = def.id,
        name         = def.name,
        reduction    = baseReduction,
        warmthBonus  = def.warmthBonus or 0,
        speedPenalty = def.speedPenalty or 0,
        resist       = resist,
        quality      = qualityId,
    }
    return true
end

function Equipment.unequipArmor(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip then return end
    equip.armor = nil
end

function Equipment.equipAccessory(entityId, accessoryId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip then return false end
    local def = ACCESSORIES[accessoryId]
    if not def then return false end

    equip.accessory = {
        id     = def.id,
        name   = def.name,
        effect = def.effect,
        value  = def.value,
    }
    return true
end

function Equipment.unequipAccessory(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip then return end
    equip.accessory = nil
end

---------------------------------------------------------------------------
-- Query helpers
---------------------------------------------------------------------------

function Equipment.getWeapon(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip then return nil end
    return equip.weapon
end

function Equipment.getArmor(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip then return nil end
    return equip.armor
end

function Equipment.getWeaponDamage(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.weapon then return 5 end -- unarmed base damage
    return equip.weapon.dmg
end

function Equipment.getWeaponRange(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.weapon then return 1 end -- melee only
    return equip.weapon.range
end

function Equipment.isRanged(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.weapon then return false end
    return equip.weapon.category == 'ranged' or equip.weapon.category == 'thrown'
end

function Equipment.getWeaponAccuracy(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.weapon then return 1.0 end
    return equip.weapon.accuracy or 1.0
end

function Equipment.getArmorReduction(entityId)
    local ok, Clothing = pcall(require, 'src.colonist.clothing')
    if ok and Clothing.getComponent and Clothing.getComponent(entityId) then
        local prot = Clothing.getProtection(entityId)
        return (prot and prot.armor) or 0
    end
    -- Fallback to old armor system
    local equip = ECS.get(entityId, 'equipment')
    if equip and equip.armor then
        return equip.armor.reduction or 0
    end
    return 0
end

--- Get typed armor resistance (0.0-1.0) for a specific damage type
function Equipment.getTypedResist(entityId, damageType)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.armor or not equip.armor.resist then return 0 end
    return equip.armor.resist[damageType] or 0
end

--- Get full armor resistance table
function Equipment.getArmorResist(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.armor or not equip.armor.resist then return nil end
    return equip.armor.resist
end

--- Get weapon damage type
function Equipment.getWeaponDamageType(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.weapon then return 'blunt' end -- unarmed = blunt
    return equip.weapon.damageType or 'sharp'
end

--- Get weapon quality
function Equipment.getWeaponQuality(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.weapon then return 'normal' end
    return equip.weapon.quality or 'normal'
end

--- Get armor quality
function Equipment.getArmorQuality(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.armor then return 'normal' end
    return equip.armor.quality or 'normal'
end

function Equipment.getSpeedPenalty(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.armor then return 0 end
    return equip.armor.speedPenalty or 0
end

function Equipment.getAccessoryEffect(entityId, effectName)
    local equip = ECS.get(entityId, 'equipment')
    if not equip or not equip.accessory then return 0 end
    if equip.accessory.effect == effectName then
        return equip.accessory.value
    end
    return 0
end

---------------------------------------------------------------------------
-- Auto-equip: give a colonist the best available gear from colony stores
-- Called on colonist spawn and periodically by the AI
---------------------------------------------------------------------------

-- Rank weapons by damage to pick "best"
local function bestAvailableWeapon(entityId)
    local Body = require('src.combat.body')
    local canTwoHand = Body.canUseTwoHanded(entityId)

    local best, bestDmg = nil, 0
    for wid, def in pairs(WEAPONS) do
        if def.singleUse then goto next_weapon end
        if def.dmg > bestDmg then
            if not def.twoHanded or canTwoHand then
                local mat = def.material or 'metal'
                if (GameState.resources[mat] or 0) >= 1 then
                    best = wid
                    bestDmg = def.dmg
                end
            end
        end
        ::next_weapon::
    end
    return best
end

-- Rank armor by reduction (prefer warmth in cold)
local function bestAvailableArmor()
    local best, bestScore = nil, 0
    for aid, def in pairs(ARMORS) do
        local score = def.reduction + (def.warmthBonus or 0) * 0.5
        if score > bestScore then
            local mat = def.material or 'hide'
            if (GameState.resources[mat] or 0) >= 1 then
                best = aid
                bestScore = score
            end
        end
    end
    return best
end

function Equipment.autoEquip(entityId)
    local equip = ECS.get(entityId, 'equipment')
    if not equip then return end

    -- Equip weapon if unarmed
    if not equip.weapon then
        local wid = bestAvailableWeapon(entityId)
        if wid then
            Equipment.equipWeapon(entityId, wid)
            local pos = ECS.get(entityId, 'pos')
            local ex = pos and pos.x or GameState.startX
            local ey = pos and pos.y or GameState.startY
            local SNet = getStorageNet()
            if SNet then SNet.withdraw('metal', 1, ex, ey)
            else GameState.spendResource('metal', 1) end
        end
    end

    -- Equip armor if unarmored
    if not equip.armor then
        local aid = bestAvailableArmor()
        if aid then
            Equipment.equipArmor(entityId, aid)
            -- Cost: 1 hide for leather, 2 metal for plate
            local def = ARMORS[aid]
            local pos = ECS.get(entityId, 'pos')
            local ex = pos and pos.x or GameState.startX
            local ey = pos and pos.y or GameState.startY
            local SNet = getStorageNet()
            if def.warmthBonus and def.warmthBonus > 5 then
                if SNet then SNet.withdraw('hide', 1, ex, ey)
                else GameState.spendResource('hide', 1) end
            else
                if SNet then SNet.withdraw('metal', 1, ex, ey)
                else GameState.spendResource('metal', 1) end
            end
        end
    end
end

-- Periodic auto-equip check for all colonists
local equipCheckTimer = 0
local EQUIP_CHECK_INTERVAL = 30.0  -- every 30 seconds

function Equipment.step(dt)
    equipCheckTimer = equipCheckTimer + dt
    if equipCheckTimer < EQUIP_CHECK_INTERVAL then return end
    equipCheckTimer = 0

    for id, comps in ECS.query('colonist', 'equipment') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.state ~= 'away_expedition' then
            Equipment.autoEquip(id)
        end
    end
end

return Equipment
