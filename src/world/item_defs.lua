local ItemDefs = {}

ItemDefs.CATEGORIES = {
    'raw_ore', 'raw_stone', 'raw_wood', 'raw_ice',
    'ingot', 'plank', 'cut_stone',
    'food_raw', 'food_cooked',
    'component', 'fuel', 'medicine', 'thermal_core',
    'weapon', 'armor', 'clothing', 'accessory',
    'liquid', 'hazmat',
    'corpse', 'organ', 'prosthetic',
    'drug', 'ordnance', 'ammo',
    'hide', 'eldritch',
}

ItemDefs.ITEMS = {
    -- Raw materials (immune to normal environmental decay)
    iron_ore     = { category = 'raw_ore',   weight = 3.0, immune = true },
    lead_ore     = { category = 'raw_ore',   weight = 3.0, immune = true },
    copper_ore   = { category = 'raw_ore',   weight = 3.0, immune = true },
    coal         = { category = 'raw_ore',   weight = 2.5, immune = true },
    uranium_ore  = { category = 'hazmat',    weight = 4.0, immune = true, radioactive = true },
    stone_chunk  = { category = 'raw_stone', weight = 4.0, immune = true },
    logs         = { category = 'raw_wood',  weight = 5.0, immune = false },
    ice_block    = { category = 'raw_ice',   weight = 2.5, immune = true },

    -- Processed materials
    iron_ingot   = { category = 'ingot', weight = 3.5, immune = true },
    lead_ingot   = { category = 'ingot', weight = 3.5, immune = true },
    copper_ingot = { category = 'ingot', weight = 3.5, immune = true },
    steel        = { category = 'ingot', weight = 3.5, immune = true },
    plasteel     = { category = 'ingot', weight = 4.0, immune = true },
    enriched_uranium  = { category = 'hazmat', weight = 4.0, immune = true, radioactive = true },
    depleted_uranium  = { category = 'ingot',  weight = 4.0, immune = true },
    planks       = { category = 'plank',     weight = 2.0, immune = false },
    cut_stone    = { category = 'cut_stone', weight = 3.5, immune = true },
    charcoal     = { category = 'fuel',      weight = 1.5, immune = false },
    cloth        = { category = 'component', weight = 0.5, immune = false },
    glass        = { category = 'component', weight = 1.0, immune = true },
    insulation   = { category = 'component', weight = 0.5, immune = false },
    pipe         = { category = 'component', weight = 1.5, immune = true },
    circuit      = { category = 'component', weight = 0.5, immune = false },
    raw_hide     = { category = 'hide',      weight = 1.5, immune = false },

    -- Food
    food         = { category = 'food_raw',    weight = 1.0, immune = false },
    cooked_meal  = { category = 'food_cooked', weight = 1.5, immune = false },
    berries      = { category = 'food_raw',    weight = 0.5, immune = false },
    mushrooms    = { category = 'food_raw',    weight = 0.5, immune = false },
    raw_meat     = { category = 'food_raw',    weight = 1.5, immune = false },

    -- Medicine
    bandage      = { category = 'medicine', weight = 0.3, immune = false },
    medicine     = { category = 'medicine', weight = 0.3, immune = false },
    advanced_medicine = { category = 'medicine', weight = 0.3, immune = false },
    revivify_serum    = { category = 'medicine', weight = 0.5, immune = false },
    medicinal_herb    = { category = 'medicine', weight = 0.3, immune = false },

    -- Core resources
    thermalCores = { category = 'thermal_core', weight = 5.0, immune = true },
    water        = { category = 'liquid',        weight = 2.0, immune = false },
    fuel         = { category = 'fuel',          weight = 2.0, immune = false },
    components   = { category = 'component',     weight = 0.5, immune = false },
    hide         = { category = 'hide',          weight = 1.5, immune = false },

    -- Corpses & organs
    corpse_creature = { category = 'corpse', weight = 15.0, immune = false },
    corpse_human    = { category = 'corpse', weight = 20.0, immune = false },
    human_meat      = { category = 'food_raw', weight = 2.0, immune = false },
    human_leather   = { category = 'hide',     weight = 1.5, immune = false },
    organ_heart  = { category = 'organ', weight = 0.5, immune = false },
    organ_lung   = { category = 'organ', weight = 0.5, immune = false },
    organ_kidney = { category = 'organ', weight = 0.3, immune = false },
    organ_liver  = { category = 'organ', weight = 0.5, immune = false },
    organ_eye    = { category = 'organ', weight = 0.1, immune = false },

    -- Prosthetics
    peg_leg        = { category = 'prosthetic', weight = 2.0, immune = true },
    wooden_arm     = { category = 'prosthetic', weight = 1.5, immune = false },
    prosthetic_leg = { category = 'prosthetic', weight = 3.0, immune = true },
    prosthetic_arm = { category = 'prosthetic', weight = 2.5, immune = true },
    bionic_leg     = { category = 'prosthetic', weight = 4.0, immune = true },
    bionic_arm     = { category = 'prosthetic', weight = 3.5, immune = true },
    bionic_eye     = { category = 'prosthetic', weight = 0.5, immune = true },

    -- Eldritch materials
    eldritch_ichor = { category = 'eldritch', weight = 1.0, immune = false },
    raw_fat        = { category = 'eldritch', weight = 2.0, immune = false },
    chitin_plate   = { category = 'eldritch', weight = 3.0, immune = true },
    void_crystal   = { category = 'eldritch', weight = 2.0, immune = true },
    raw_fur        = { category = 'hide',     weight = 1.5, immune = false },
    caustic_liquid = { category = 'eldritch', weight = 1.5, immune = false },
    serpent_venom  = { category = 'eldritch', weight = 0.5, immune = false },
    fang           = { category = 'eldritch', weight = 0.3, immune = true },

    -- Xenolith biological materials
    xenolith_egg   = { category = 'eldritch', weight = 5.0, immune = true, dangerous = true },
    xenolith_chitin = { category = 'eldritch', weight = 4.0, immune = true },
    xenolith_tissue = { category = 'eldritch', weight = 2.0, immune = false },

    -- Legacy names (backward compat with existing code)
    lead           = { category = 'raw_ore',   weight = 3.5, immune = true },
    metal          = { category = 'ingot',     weight = 3.5, immune = true },
    stone          = { category = 'raw_stone', weight = 4.0, immune = true },
    wood           = { category = 'raw_wood',  weight = 5.0, immune = false },
}

-- Drugs
local drugItems = {
    'psychoid_leaf', 'smokeleaf_leaf', 'hops', 'hay',
    'spike', 'stardust', 'drift', 'smog', 'rotgut', 'shards',
    'glimpse', 'surge', 'thaw', 'voidbloom', 'berserker', 'stim',
}
for _, name in ipairs(drugItems) do
    ItemDefs.ITEMS[name] = { category = 'drug', weight = 0.3, immune = false }
end

-- Weapons (unique per item)
local weaponItems = {
    'weapon_club', 'weapon_shiv', 'weapon_pipe_wrench', 'weapon_torch',
    'weapon_knife', 'weapon_hatchet', 'weapon_machete', 'weapon_spear',
    'weapon_axe', 'weapon_sword', 'weapon_shortbow', 'weapon_bow',
    'weapon_crossbow', 'weapon_revolver', 'weapon_pistol',
    'weapon_sawed_off', 'weapon_pump_shotgun', 'weapon_bolt_action',
    'weapon_assault_rifle', 'weapon_battle_rifle',
}
for _, name in ipairs(weaponItems) do
    ItemDefs.ITEMS[name] = { category = 'weapon', weight = 3.0, immune = true, unique = true }
end

-- Ammo
local ammoItems = {
    'ammo_arrow', 'ammo_fire_arrow', 'ammo_bolt', 'ammo_bullet',
    'ammo_shell', 'ammo_rocket', 'ammo_mortar_shell',
}
for _, name in ipairs(ammoItems) do
    ItemDefs.ITEMS[name] = { category = 'ammo', weight = 0.2, immune = true }
end

-- Ordnance
local ordnanceItems = {
    'grenade', 'ied', 'molotov', 'pipe_bomb', 'placed_charge', 'timed_bomb',
    'tripwire_bomb', 'napalm_grenade', 'napalm_bomb', 'bio_grenade',
    'bio_bomb', 'foam_grenade', 'foam_bomb', 'c4_charge', 'emp_charge',
    'emp_grenade', 'briefcase_nuke', 'nuclear_core',
    'napalm_fuel', 'foam_canister', 'gas_canister', 'acid_canister', 'poison_darts',
}
for _, name in ipairs(ordnanceItems) do
    ItemDefs.ITEMS[name] = { category = 'ordnance', weight = 1.0, immune = true }
end

-- Missiles
local missileItems = {
    'missile_he', 'missile_napalm', 'missile_bio',
    'missile_foam', 'missile_bunker', 'missile_nuke',
}
for _, name in ipairs(missileItems) do
    ItemDefs.ITEMS[name] = { category = 'ordnance', weight = 5.0, immune = true }
end

function ItemDefs.get(itemId)
    return ItemDefs.ITEMS[itemId] or { category = 'component', weight = 1.0, immune = false }
end

function ItemDefs.isImmune(itemId)
    local def = ItemDefs.get(itemId)
    return def.immune == true
end

function ItemDefs.isUnique(itemId)
    local def = ItemDefs.get(itemId)
    return def.unique == true
end

function ItemDefs.getWeight(itemId)
    local def = ItemDefs.get(itemId)
    return def.weight
end

function ItemDefs.getCategory(itemId)
    local def = ItemDefs.get(itemId)
    return def.category
end

return ItemDefs
