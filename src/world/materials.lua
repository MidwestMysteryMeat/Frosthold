-- materials.lua -- Material definitions and properties
-- 24 materials across 6 categories. Each material has properties that affect
-- items, buildings, and armor made from it.

local Materials = {}

---------------------------------------------------------------------------
-- Material properties
---------------------------------------------------------------------------
-- hardness:       0-1, structural strength and mining resistance
-- beauty:         0-1, aesthetic value for rooms/items
-- flammability:   0-1, fire susceptibility (0 = fireproof)
-- conductivity:   0-1, thermal transfer rate (high = poor insulator)
-- durability:     0-1, wear and deterioration resistance
-- value:          float, trade value multiplier
-- density:        0-1, weight factor (affects carry speed)
-- sharp_resist:   0-1, resistance to sharp/cutting damage
-- blunt_resist:   0-1, resistance to blunt/impact damage
-- cold_resist:    0-1, cold protection when worn as armor/clothing

---------------------------------------------------------------------------
-- Material definitions
---------------------------------------------------------------------------

local DEFS = {
    --------------- Stone ---------------
    granite = {
        name = 'Granite', category = 'stone',
        hardness = 0.85, beauty = 0.30, flammability = 0.00, conductivity = 0.40,
        durability = 0.90, value = 1.0, density = 0.90,
        sharp_resist = 0.70, blunt_resist = 0.80, cold_resist = 0.10,
    },
    slate = {
        name = 'Slate', category = 'stone',
        hardness = 0.60, beauty = 0.45, flammability = 0.00, conductivity = 0.35,
        durability = 0.65, value = 1.0, density = 0.75,
        sharp_resist = 0.55, blunt_resist = 0.50, cold_resist = 0.10,
    },
    marble = {
        name = 'Marble', category = 'stone',
        hardness = 0.50, beauty = 0.85, flammability = 0.00, conductivity = 0.30,
        durability = 0.55, value = 1.8, density = 0.80,
        sharp_resist = 0.45, blunt_resist = 0.45, cold_resist = 0.10,
    },
    sandstone = {
        name = 'Sandstone', category = 'stone',
        hardness = 0.40, beauty = 0.35, flammability = 0.00, conductivity = 0.25,
        durability = 0.40, value = 0.8, density = 0.65,
        sharp_resist = 0.35, blunt_resist = 0.35, cold_resist = 0.15,
    },

    --------------- Wood ---------------
    wood = {
        name = 'Wood', category = 'wood',
        hardness = 0.30, beauty = 0.40, flammability = 0.80, conductivity = 0.15,
        durability = 0.35, value = 0.8, density = 0.35,
        sharp_resist = 0.15, blunt_resist = 0.20, cold_resist = 0.20,
    },
    hardwood = {
        name = 'Hardwood', category = 'wood',
        hardness = 0.50, beauty = 0.55, flammability = 0.60, conductivity = 0.12,
        durability = 0.55, value = 1.5, density = 0.50,
        sharp_resist = 0.25, blunt_resist = 0.35, cold_resist = 0.25,
    },

    --------------- Metals ---------------
    iron = {
        name = 'Iron', category = 'metal',
        hardness = 0.60, beauty = 0.15, flammability = 0.00, conductivity = 0.75,
        durability = 0.60, value = 1.5, density = 0.80,
        sharp_resist = 0.60, blunt_resist = 0.55, cold_resist = 0.05,
    },
    steel = {
        name = 'Steel', category = 'metal',
        hardness = 0.80, beauty = 0.20, flammability = 0.00, conductivity = 0.70,
        durability = 0.80, value = 2.5, density = 0.85,
        sharp_resist = 0.75, blunt_resist = 0.70, cold_resist = 0.05,
    },
    plasteel = {
        name = 'Plasteel', category = 'metal',
        hardness = 0.95, beauty = 0.30, flammability = 0.00, conductivity = 0.50,
        durability = 0.95, value = 5.0, density = 0.60,
        sharp_resist = 0.90, blunt_resist = 0.85, cold_resist = 0.15,
    },
    thermal_alloy = {
        name = 'Thermal Alloy', category = 'metal',
        hardness = 0.70, beauty = 0.40, flammability = 0.00, conductivity = 0.05,
        durability = 0.75, value = 4.0, density = 0.70,
        sharp_resist = 0.60, blunt_resist = 0.55, cold_resist = 0.60,
    },
    gold = {
        name = 'Gold', category = 'metal',
        hardness = 0.20, beauty = 0.95, flammability = 0.00, conductivity = 0.90,
        durability = 0.30, value = 8.0, density = 0.95,
        sharp_resist = 0.10, blunt_resist = 0.10, cold_resist = 0.00,
    },

    --------------- Cloth / Leather ---------------
    cloth = {
        name = 'Cloth', category = 'textile',
        hardness = 0.05, beauty = 0.40, flammability = 0.90, conductivity = 0.10,
        durability = 0.20, value = 1.2, density = 0.10,
        sharp_resist = 0.05, blunt_resist = 0.02, cold_resist = 0.30,
    },
    leather = {
        name = 'Leather', category = 'textile',
        hardness = 0.20, beauty = 0.30, flammability = 0.50, conductivity = 0.12,
        durability = 0.45, value = 1.5, density = 0.25,
        sharp_resist = 0.25, blunt_resist = 0.15, cold_resist = 0.35,
    },
    hide = {
        name = 'Hide', category = 'textile',
        hardness = 0.15, beauty = 0.15, flammability = 0.55, conductivity = 0.10,
        durability = 0.35, value = 1.0, density = 0.30,
        sharp_resist = 0.15, blunt_resist = 0.10, cold_resist = 0.40,
    },
    sinew = {
        name = 'Sinew', category = 'textile',
        hardness = 0.25, beauty = 0.10, flammability = 0.40, conductivity = 0.08,
        durability = 0.50, value = 1.2, density = 0.15,
        sharp_resist = 0.20, blunt_resist = 0.10, cold_resist = 0.20,
    },

    --------------- Exotic ---------------
    precursor_chitin = {
        name = 'Precursor Chitin', category = 'exotic',
        hardness = 0.85, beauty = 0.60, flammability = 0.05, conductivity = 0.15,
        durability = 0.90, value = 10.0, density = 0.40,
        sharp_resist = 0.85, blunt_resist = 0.60, cold_resist = 0.40,
    },
    void_crystal = {
        name = 'Void Crystal', category = 'exotic',
        hardness = 0.70, beauty = 0.90, flammability = 0.00, conductivity = 0.02,
        durability = 0.40, value = 15.0, density = 0.50,
        sharp_resist = 0.30, blunt_resist = 0.20, cold_resist = 0.50,
    },
    ichor_resin = {
        name = 'Ichor Resin', category = 'exotic',
        hardness = 0.55, beauty = 0.20, flammability = 0.30, conductivity = 0.20,
        durability = 0.70, value = 6.0, density = 0.45,
        sharp_resist = 0.50, blunt_resist = 0.45, cold_resist = 0.30,
    },

    --------------- Organic ---------------
    bone = {
        name = 'Bone', category = 'organic',
        hardness = 0.45, beauty = 0.15, flammability = 0.30, conductivity = 0.20,
        durability = 0.50, value = 0.5, density = 0.40,
        sharp_resist = 0.35, blunt_resist = 0.25, cold_resist = 0.05,
    },

    --------------- Manufactured ---------------
    glass = {
        name = 'Glass', category = 'manufactured',
        hardness = 0.25, beauty = 0.70, flammability = 0.00, conductivity = 0.60,
        durability = 0.15, value = 1.5, density = 0.55,
        sharp_resist = 0.05, blunt_resist = 0.05, cold_resist = 0.05,
    },
    ceramic = {
        name = 'Ceramic', category = 'manufactured',
        hardness = 0.65, beauty = 0.50, flammability = 0.00, conductivity = 0.08,
        durability = 0.60, value = 2.0, density = 0.60,
        sharp_resist = 0.50, blunt_resist = 0.30, cold_resist = 0.20,
    },
    insulation_foam = {
        name = 'Insulation Foam', category = 'manufactured',
        hardness = 0.05, beauty = 0.05, flammability = 0.70, conductivity = 0.02,
        durability = 0.25, value = 1.0, density = 0.05,
        sharp_resist = 0.00, blunt_resist = 0.00, cold_resist = 0.70,
    },
    composite = {
        name = 'Composite', category = 'manufactured',
        hardness = 0.75, beauty = 0.25, flammability = 0.10, conductivity = 0.30,
        durability = 0.80, value = 3.5, density = 0.45,
        sharp_resist = 0.70, blunt_resist = 0.65, cold_resist = 0.25,
    },
    reinforced_steel = {
        name = 'Reinforced Steel', category = 'manufactured',
        hardness = 0.90, beauty = 0.15, flammability = 0.00, conductivity = 0.65,
        durability = 0.92, value = 4.0, density = 0.92,
        sharp_resist = 0.85, blunt_resist = 0.80, cold_resist = 0.05,
    },
}

Materials.DEFS = DEFS

---------------------------------------------------------------------------
-- Category groupings
---------------------------------------------------------------------------

local CATEGORIES = {
    stone        = { 'granite', 'slate', 'marble', 'sandstone' },
    wood         = { 'wood', 'hardwood' },
    metal        = { 'iron', 'steel', 'plasteel', 'thermal_alloy', 'gold' },
    textile      = { 'cloth', 'leather', 'hide', 'sinew' },
    exotic       = { 'precursor_chitin', 'void_crystal', 'ichor_resin' },
    organic      = { 'bone' },
    manufactured = { 'glass', 'ceramic', 'insulation_foam', 'composite', 'reinforced_steel' },
}

Materials.CATEGORIES = CATEGORIES

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

--- Get a material definition by id
function Materials.get(materialId)
    return DEFS[materialId]
end

--- Get a property value for a material (returns 0 if not found)
function Materials.getProperty(materialId, propertyName)
    local mat = DEFS[materialId]
    if not mat then return 0 end
    return mat[propertyName] or 0
end

--- Get display name
function Materials.getName(materialId)
    local mat = DEFS[materialId]
    return mat and mat.name or materialId
end

--- Get all material ids in a category
function Materials.getByCategory(categoryName)
    return CATEGORIES[categoryName] or {}
end

--- Get all material ids
function Materials.getAll()
    local out = {}
    for id in pairs(DEFS) do out[#out + 1] = id end
    return out
end

--- Format item name with material prefix
--- e.g. Materials.formatName('Sword', 'steel') -> 'Steel Sword'
function Materials.formatName(baseName, materialId)
    local mat = DEFS[materialId]
    if not mat then return baseName end
    return mat.name .. ' ' .. baseName
end

--- Compare two materials: returns true if matA is strictly better for armor
function Materials.isBetterArmor(matIdA, matIdB)
    local a = DEFS[matIdA]
    local b = DEFS[matIdB]
    if not a or not b then return false end
    local scoreA = a.sharp_resist + a.blunt_resist + a.cold_resist + a.durability
    local scoreB = b.sharp_resist + b.blunt_resist + b.cold_resist + b.durability
    return scoreA > scoreB
end

--- Compare two materials: returns true if matA is strictly better for weapons
function Materials.isBetterWeapon(matIdA, matIdB)
    local a = DEFS[matIdA]
    local b = DEFS[matIdB]
    if not a or not b then return false end
    local scoreA = a.hardness + a.durability + a.value * 0.1
    local scoreB = b.hardness + b.durability + b.value * 0.1
    return scoreA > scoreB
end

return Materials
