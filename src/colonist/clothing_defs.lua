-- clothing_defs.lua — Clothing item definitions
-- All wearable items across 5 slots: under, outer, head, hands, feet.
-- Protection stats (0-100) represent resistance to cold, heat, pressure,
-- radiation, and toxicity. Armor reduces melee/ranged damage.
-- speedMod and workMod are additive fractions (e.g. -0.05 = -5%).
-- Space suit uses multiSlot to occupy outer + head + hands + feet.

local ClothingDefs = {}

ClothingDefs.ITEMS = {
    -- -------------------------------------------------------------------------
    -- UNDER LAYER
    -- -------------------------------------------------------------------------
    thermal_undershirt = {
        slot = 'under', name = 'Thermal Undershirt',
        cold = 15, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 0, speedMod = 0, workMod = 0,
        material = 'cloth', cost = { cloth = 3 },
    },
    cooling_vest = {
        slot = 'under', name = 'Cooling Vest',
        cold = 5, heat = 20, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 0, speedMod = 0, workMod = 0,
        material = 'cloth', cost = { cloth = 2, components = 1 },
    },
    rad_suit_liner = {
        slot = 'under', name = 'Rad-Suit Liner',
        cold = 5, heat = 5, pressure = 10, radiation = 20, toxicity = 10,
        maxDurability = 80, armor = 0, speedMod = 0, workMod = -0.05,
        material = 'cloth', cost = { cloth = 2, lead = 1 },
    },

    -- -------------------------------------------------------------------------
    -- OUTER LAYER (includes migrated armor types)
    -- -------------------------------------------------------------------------
    hide_coat = {
        slot = 'outer', name = 'Hide Coat',
        cold = 25, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 3, speedMod = 0, workMod = 0,
        material = 'hide', cost = { hide = 4 },
    },
    leather_armor = {
        slot = 'outer', name = 'Leather Armor',
        cold = 15, heat = 8, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 5, speedMod = -0.05, workMod = 0,
        material = 'hide', cost = { hide = 6 },
    },
    metal_plate = {
        slot = 'outer', name = 'Metal Plate Armor',
        cold = 5, heat = 5, pressure = 5, radiation = 5, toxicity = 0,
        maxDurability = 150, armor = 10, speedMod = -0.15, workMod = -0.10,
        material = 'metal', cost = { metal = 8 },
    },
    parka = {
        slot = 'outer', name = 'Parka',
        cold = 35, heat = 0, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 2, speedMod = -0.05, workMod = 0,
        material = 'cloth', cost = { cloth = 5, hide = 2 },
    },
    thermal_suit = {
        slot = 'outer', name = 'Thermal Suit',
        cold = 50, heat = 10, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 4, speedMod = -0.05, workMod = 0,
        material = 'insulation', cost = { insulation = 3, metal = 2, circuit = 1 },
    },
    hazmat_suit = {
        slot = 'outer', name = 'Hazmat Suit',
        cold = 10, heat = 15, pressure = 20, radiation = 30, toxicity = 50,
        maxDurability = 80, armor = 2, speedMod = -0.10, workMod = -0.10,
        material = 'cloth', cost = { cloth = 4, components = 2, glass = 1 },
    },
    acid_cloak = {
        slot = 'outer', name = 'Acid Cloak',
        cold = 10, heat = 10, pressure = 0, radiation = 0, toxicity = 40,
        maxDurability = 60, armor = 1, speedMod = 0, workMod = 0,
        material = 'hide', cost = { hide = 3, glass = 2 },
    },
    exosuit = {
        slot = 'outer', name = 'Exosuit',
        cold = 30, heat = 15, pressure = 10, radiation = 5, toxicity = 5,
        maxDurability = 100, armor = 8, speedMod = 0.10, workMod = 0.05,
        material = 'steel', cost = { steel = 5, circuit = 3 },
        carryMod = 0.5, damageMod = 1.0,
    },

    -- -------------------------------------------------------------------------
    -- HEAD
    -- -------------------------------------------------------------------------
    wool_hat = {
        slot = 'head', name = 'Wool Hat',
        cold = 15, heat = 0, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 80, armor = 0, speedMod = 0, workMod = 0,
        material = 'cloth', cost = { cloth = 2 },
    },
    helmet = {
        slot = 'head', name = 'Helmet',
        cold = 5, heat = 5, pressure = 5, radiation = 0, toxicity = 0,
        maxDurability = 120, armor = 5, speedMod = 0, workMod = 0,
        material = 'metal', cost = { metal = 4 },
    },
    rebreather = {
        slot = 'head', name = 'Rebreather',
        cold = 5, heat = 5, pressure = 15, radiation = 5, toxicity = 30,
        maxDurability = 80, armor = 1, speedMod = 0, workMod = -0.05,
        material = 'components', cost = { components = 3, glass = 1 },
    },
    rad_hood = {
        slot = 'head', name = 'Radiation Hood',
        cold = 10, heat = 5, pressure = 0, radiation = 25, toxicity = 10,
        maxDurability = 80, armor = 1, speedMod = 0, workMod = 0,
        material = 'cloth', cost = { cloth = 2, lead = 2 },
    },

    -- -------------------------------------------------------------------------
    -- HANDS
    -- -------------------------------------------------------------------------
    insulated_gloves = {
        slot = 'hands', name = 'Insulated Gloves',
        cold = 15, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 80, armor = 1, speedMod = 0, workMod = -0.05,
        material = 'cloth', cost = { cloth = 2 },
    },
    work_gloves = {
        slot = 'hands', name = 'Work Gloves',
        cold = 5, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 2, speedMod = 0, workMod = 0.05,
        material = 'hide', cost = { hide = 2 },
    },
    rad_gauntlets = {
        slot = 'hands', name = 'Radiation Gauntlets',
        cold = 5, heat = 5, pressure = 5, radiation = 20, toxicity = 5,
        maxDurability = 80, armor = 2, speedMod = 0, workMod = -0.10,
        material = 'metal', cost = { metal = 3, lead = 1 },
    },

    -- -------------------------------------------------------------------------
    -- FEET
    -- -------------------------------------------------------------------------
    boots = {
        slot = 'feet', name = 'Boots',
        cold = 10, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 2, speedMod = 0, workMod = 0,
        material = 'hide', cost = { hide = 3 },
    },
    insulated_boots = {
        slot = 'feet', name = 'Insulated Boots',
        cold = 20, heat = 0, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 2, speedMod = -0.05, workMod = 0,
        material = 'hide', cost = { hide = 3, cloth = 1 },
    },
    mag_boots = {
        slot = 'feet', name = 'Mag-Boots',
        cold = 5, heat = 5, pressure = 20, radiation = 0, toxicity = 0,
        maxDurability = 80, armor = 3, speedMod = -0.10, workMod = 0,
        material = 'metal', cost = { metal = 4, components = 2 },
    },

    -- -------------------------------------------------------------------------
    -- MULTI-SLOT: DIVING SUIT (Nerthus-9)
    -- Pressurized suit for underwater operations.
    -- -------------------------------------------------------------------------
    diving_suit = {
        slot = 'outer', name = 'Diving Suit',
        multiSlot = { 'outer', 'head', 'hands', 'feet' },
        cold = 40, heat = 10, pressure = 60, radiation = 0, toxicity = 20,
        maxDurability = 100, armor = 3, speedMod = -0.10, workMod = -0.10,
        material = 'steel', cost = { steel = 6, circuit = 2, glass = 2 },
        o2MaxTank = 300, o2DrainRate = 1.0,
        carryMod = -0.2,
    },

    -- -------------------------------------------------------------------------
    -- MULTI-SLOT: SPACE SUIT (Nemaea)
    -- Vacuum-rated EVA suit with sealed O2 system.
    -- -------------------------------------------------------------------------
    space_suit = {
        slot = 'outer', name = 'Space Suit',
        multiSlot = { 'outer', 'head', 'hands', 'feet' },
        cold = 40, heat = 20, pressure = 90, radiation = 70, toxicity = 30,
        maxDurability = 100, armor = 5, speedMod = -0.15, workMod = -0.10,
        material = 'steel', cost = { steel = 10, glass = 5, circuit = 3, cloth = 4 },
        o2MaxTank = 600, o2DrainRate = 0.8,
        carryMod = -0.3,
    },
}

---------------------------------------------------------------------------
-- Lookups
---------------------------------------------------------------------------

--- Return the definition table for a clothing item id, or nil.
function ClothingDefs.get(clothingId)
    return ClothingDefs.ITEMS[clothingId]
end

--- Return all items whose primary slot matches the given slot string.
--- Returns an array of { id = string, def = table }.
function ClothingDefs.getBySlot(slot)
    local result = {}
    for id, def in pairs(ClothingDefs.ITEMS) do
        if def.slot == slot then
            result[#result + 1] = { id = id, def = def }
        end
    end
    return result
end

return ClothingDefs
