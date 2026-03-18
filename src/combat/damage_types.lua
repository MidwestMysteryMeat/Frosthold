-- damage_types.lua -- Damage type definitions
-- 7 damage types: sharp, blunt, cold, fire, bio, electric, explosive.
-- Weapons deal one or more damage types. Armor resists per type.
-- Wound types map to damage types for wound application.

local DamageTypes = {}

---------------------------------------------------------------------------
-- Damage type definitions
---------------------------------------------------------------------------

local TYPES = {
    sharp = {
        name      = 'Sharp',
        desc      = 'Cutting and piercing damage',
        woundType = 'cut',       -- maps to wounds.lua WOUND_TYPES
        armorKey  = 'sharp',     -- key used in armor resistance tables
        bleedMult = 1.0,         -- multiplier on wound bleed rate
        painMult  = 0.8,         -- multiplier on wound pain
    },
    blunt = {
        name      = 'Blunt',
        desc      = 'Impact and crushing damage',
        woundType = 'fracture',
        armorKey  = 'blunt',
        bleedMult = 0.0,
        painMult  = 1.2,
    },
    cold = {
        name      = 'Cold',
        desc      = 'Frostbite and hypothermia',
        woundType = 'frostbite',
        armorKey  = 'cold',
        bleedMult = 0.0,
        painMult  = 0.6,
    },
    fire = {
        name      = 'Fire',
        desc      = 'Burns and heat damage',
        woundType = 'burn',
        armorKey  = 'fire',
        bleedMult = 0.0,
        painMult  = 1.5,
    },
    bio = {
        name      = 'Bio',
        desc      = 'Toxic, acidic, and biological damage',
        woundType = 'burn',      -- bio damage causes chemical burns
        armorKey  = 'bio',
        bleedMult = 0.2,
        painMult  = 1.0,
        infectionBonus = 0.15,   -- extra infection chance
    },
    electric = {
        name      = 'Electric',
        desc      = 'Electrical shock and nerve damage',
        woundType = 'burn',
        armorKey  = 'electric',
        bleedMult = 0.0,
        painMult  = 1.3,
        stunChance = 0.20,       -- chance to stun target for 2s
    },
    explosive = {
        name      = 'Explosive',
        desc      = 'Blast and fragmentation damage',
        woundType = 'cut',       -- shrapnel causes cuts
        armorKey  = 'explosive',
        bleedMult = 0.8,
        painMult  = 1.0,
        aoeRadius = 2,           -- damages tiles in radius
    },
}

DamageTypes.TYPES = TYPES

---------------------------------------------------------------------------
-- Default armor resistance profile (no armor)
---------------------------------------------------------------------------

local ZERO_RESIST = {
    sharp     = 0,
    blunt     = 0,
    cold      = 0,
    fire      = 0,
    bio       = 0,
    electric  = 0,
    explosive = 0,
}

DamageTypes.ZERO_RESIST = ZERO_RESIST

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

--- Get damage type definition
function DamageTypes.get(typeId)
    return TYPES[typeId]
end

--- Get the wound type that a damage type inflicts
function DamageTypes.getWoundType(typeId)
    local def = TYPES[typeId]
    return def and def.woundType or 'cut'
end

--- Calculate damage after armor resistance
--- @param baseDamage number Raw damage amount
--- @param damageType string Damage type id (e.g. 'sharp')
--- @param armorResist table Per-type resistance values {sharp=0.5, blunt=0.3, ...}
--- @return number Final damage (minimum 1)
function DamageTypes.applyArmor(baseDamage, damageType, armorResist)
    if not armorResist then return math.max(1, baseDamage) end
    local resist = armorResist[damageType] or 0
    -- Resistance is a flat reduction (0-1 scale, multiplied by base damage)
    local reduced = baseDamage * (1.0 - resist)
    return math.max(1, math.floor(reduced + 0.5))
end

--- Calculate wound severity from damage amount and type
--- @param damage number Final damage after armor
--- @param damageType string Damage type id
--- @return number severity (0.0-1.0)
--- @return string woundType Wound type to apply
function DamageTypes.calcWoundSeverity(damage, damageType)
    local def = TYPES[damageType]
    if not def then return math.min(1.0, damage / 20), 'cut' end
    local severity = math.min(1.0, damage / 20)
    return severity, def.woundType
end

--- Check for special damage type effects (stun, infection bonus, AoE)
--- @param damageType string
--- @return table Special effects {stunChance, infectionBonus, aoeRadius}
function DamageTypes.getSpecialEffects(damageType)
    local def = TYPES[damageType]
    if not def then return {} end
    local fx = {}
    if def.stunChance then fx.stunChance = def.stunChance end
    if def.infectionBonus then fx.infectionBonus = def.infectionBonus end
    if def.aoeRadius then fx.aoeRadius = def.aoeRadius end
    return fx
end

--- Build an armor resistance table from material properties
--- @param materialId string Material id from materials.lua
--- @return table Resistance values per damage type
function DamageTypes.resistFromMaterial(materialId)
    local mOk, Mats = pcall(require, 'src.world.materials')
    if not mOk then return ZERO_RESIST end
    local mat = Mats.get(materialId)
    if not mat then return ZERO_RESIST end
    return {
        sharp     = mat.sharp_resist or 0,
        blunt     = mat.blunt_resist or 0,
        cold      = mat.cold_resist or 0,
        fire      = math.max(0, 1.0 - (mat.flammability or 0)),
        bio       = (mat.hardness or 0) * 0.3,
        electric  = math.max(0, 1.0 - (mat.conductivity or 0)),
        explosive = ((mat.sharp_resist or 0) + (mat.blunt_resist or 0)) * 0.5,
    }
end

--- Get all damage type ids
function DamageTypes.getAll()
    local out = {}
    for id in pairs(TYPES) do out[#out + 1] = id end
    return out
end

return DamageTypes
