-- production_defs.lua - Shared production catalog data

local ProductionDefs = {}

local ITEMS = {
    -- Raw resources
    raw_wood     = { name = 'Raw Wood',       stack = 50, category = 'raw' },
    raw_stone    = { name = 'Raw Stone',       stack = 50, category = 'raw' },
    raw_ore      = { name = 'Raw Ore',         stack = 50, category = 'raw' },
    raw_ice      = { name = 'Raw Ice',         stack = 50, category = 'raw' },
    raw_meat     = { name = 'Raw Meat',        stack = 20, category = 'raw' },
    raw_hide     = { name = 'Raw Hide',        stack = 20, category = 'raw' },
    thermal_core = { name = 'Thermal Core',    stack = 10, category = 'raw' },
    plant_fiber  = { name = 'Plant Fiber',     stack = 50, category = 'raw' },
    coal         = { name = 'Coal',            stack = 50, category = 'raw' },
    berries      = { name = 'Berries',         stack = 30, category = 'raw' },
    mushrooms    = { name = 'Mushrooms',       stack = 30, category = 'raw' },
    medicinal_herb = { name = 'Medicinal Herb', stack = 20, category = 'raw' },
    lead_ore     = { name = 'Lead Ore',        stack = 50, category = 'raw' },

    -- Processed materials
    lumber       = { name = 'Lumber',          stack = 50, category = 'material' },
    cut_stone    = { name = 'Cut Stone',       stack = 50, category = 'material' },
    metal_ingot  = { name = 'Metal Ingot',     stack = 50, category = 'material' },
    leather      = { name = 'Leather',         stack = 20, category = 'material' },
    cloth        = { name = 'Cloth',           stack = 30, category = 'material' },
    water        = { name = 'Water',           stack = 50, category = 'material' },
    charcoal     = { name = 'Charcoal',        stack = 50, category = 'material' },
    lead         = { name = 'Lead',            stack = 40, category = 'material' },

    -- Advanced materials
    steel        = { name = 'Steel',           stack = 30, category = 'advanced' },
    plasteel     = { name = 'Plasteel',        stack = 30, category = 'advanced' },
    components   = { name = 'Components',      stack = 20, category = 'advanced' },
    circuit      = { name = 'Circuit',         stack = 20, category = 'advanced' },
    insulation   = { name = 'Insulation',      stack = 30, category = 'advanced' },
    pipe         = { name = 'Pipe',            stack = 30, category = 'advanced' },
    glass        = { name = 'Glass',           stack = 30, category = 'advanced' },

    -- Food products
    cooked_meat  = { name = 'Grilled Meat',    stack = 20, category = 'food' },
    stew         = { name = 'Hearty Stew',     stack = 10, category = 'food' },
    jerky        = { name = 'Smoked Jerky',    stack = 30, category = 'food' },
    bread        = { name = 'Frost Bread',     stack = 20, category = 'food' },
    ration       = { name = 'Pemmican',        stack = 15, category = 'food' },
    feast        = { name = 'Frontier Feast',  stack = 5,  category = 'food' },

    -- Medicine & drugs
    bandage      = { name = 'Bandage',     stack = 20, category = 'medicine' },
    medicine     = { name = 'Medicine',    stack = 10, category = 'medicine' },
    spike        = { name = 'Spike',        stack = 10, category = 'drug' },
    stardust     = { name = 'Stardust',    stack = 10, category = 'drug' },
    drift        = { name = 'Drift',       stack = 10, category = 'drug' },
    smog         = { name = 'Smog',        stack = 10, category = 'drug' },
    rotgut       = { name = 'Rotgut',      stack = 10, category = 'drug' },
    shards       = { name = 'Shards',      stack = 5,  category = 'drug' },
    glimpse      = { name = 'Glimpse',     stack = 5,  category = 'drug' },
    surge        = { name = 'Surge',       stack = 5,  category = 'drug' },
    voidbloom    = { name = 'Voidbloom',   stack = 5,  category = 'drug' },
    berserker    = { name = 'Berserker',   stack = 5,  category = 'drug' },
    stim         = { name = 'Stim',        stack = 5,  category = 'drug' },
    thaw         = { name = 'Thaw',        stack = 10, category = 'medical' },
    advanced_medicine = { name = 'Advanced Medicine', stack = 5, category = 'medicine' },
    revivify_serum = { name = 'Revivify Serum', stack = 5, category = 'medical' },
    fang         = { name = 'Fang',        stack = 10, category = 'drug' },

    -- Corpses
    corpse_creature = { name = 'Creature Corpse', stack = 5,  category = 'corpse' },
    corpse_human    = { name = 'Human Corpse',    stack = 5,  category = 'corpse' },

    -- Dark processing
    human_meat      = { name = 'Human Meat',      stack = 20, category = 'food' },
    human_leather   = { name = 'Human Leather',   stack = 20, category = 'material' },

    -- Organs
    organ_heart     = { name = 'Heart',           stack = 1,  category = 'organ' },
    organ_lung      = { name = 'Lung',            stack = 2,  category = 'organ' },
    organ_kidney    = { name = 'Kidney',          stack = 2,  category = 'organ' },
    organ_liver     = { name = 'Liver',           stack = 1,  category = 'organ' },
    organ_eye       = { name = 'Eye',             stack = 2,  category = 'organ' },

    -- Prosthetics (wood)
    peg_leg         = { name = 'Peg Leg',         stack = 2,  category = 'prosthetic' },
    wooden_arm      = { name = 'Wooden Arm',      stack = 2,  category = 'prosthetic' },

    -- Prosthetics (metal)
    prosthetic_leg  = { name = 'Prosthetic Leg',  stack = 1,  category = 'prosthetic' },
    prosthetic_arm  = { name = 'Prosthetic Arm',  stack = 1,  category = 'prosthetic' },

    -- Bionics
    bionic_leg      = { name = 'Bionic Leg',      stack = 1,  category = 'bionic' },
    bionic_arm      = { name = 'Bionic Arm',      stack = 1,  category = 'bionic' },
    bionic_eye      = { name = 'Bionic Eye',      stack = 1,  category = 'bionic' },

    -- Drug crop raw materials
    psychoid_leaf   = { name = 'Psychoid Leaf',   stack = 30, category = 'raw' },
    smokeleaf_leaf  = { name = 'Smokeleaf Leaf',  stack = 30, category = 'raw' },
    hops            = { name = 'Hops',            stack = 30, category = 'raw' },

    -- Equipment — clothing
    parka        = { name = 'Parka',           stack = 1,  category = 'equipment' },
    boots        = { name = 'Insulated Boots', stack = 1,  category = 'equipment' },

    -- Equipment — improvised melee
    weapon_club        = { name = 'Club',        stack = 1, category = 'equipment' },
    weapon_shiv        = { name = 'Shiv',        stack = 1, category = 'equipment' },
    weapon_pipe_wrench = { name = 'Pipe Wrench', stack = 1, category = 'equipment' },
    weapon_torch       = { name = 'Torch',       stack = 5, category = 'equipment' },

    -- Equipment — crafted melee
    weapon_knife   = { name = 'Knife',   stack = 1, category = 'equipment' },
    weapon_hatchet = { name = 'Hatchet', stack = 1, category = 'equipment' },
    weapon_machete = { name = 'Machete', stack = 1, category = 'equipment' },
    weapon_spear   = { name = 'Spear',   stack = 1, category = 'equipment' },
    weapon_sword   = { name = 'Sword',   stack = 1, category = 'equipment' },
    weapon_axe     = { name = 'Ice Axe', stack = 1, category = 'equipment' },

    -- Equipment — bows / crossbows
    weapon_shortbow = { name = 'Short Bow', stack = 1, category = 'equipment' },
    weapon_bow      = { name = 'Hunting Bow', stack = 1, category = 'equipment' },
    weapon_crossbow = { name = 'Crossbow',  stack = 1, category = 'equipment' },

    -- Equipment — pistols
    weapon_revolver = { name = 'Revolver', stack = 1, category = 'equipment' },
    weapon_pistol   = { name = 'Pistol',   stack = 1, category = 'equipment' },

    -- Equipment — shotguns
    weapon_sawed_off    = { name = 'Sawed-Off',    stack = 1, category = 'equipment' },
    weapon_pump_shotgun = { name = 'Pump Shotgun',  stack = 1, category = 'equipment' },

    -- Equipment — rifles
    weapon_bolt_action    = { name = 'Bolt-Action Rifle', stack = 1, category = 'equipment' },
    weapon_assault_rifle  = { name = 'Assault Rifle',     stack = 1, category = 'equipment' },
    weapon_battle_rifle   = { name = 'Battle Rifle',      stack = 1, category = 'equipment' },

    -- Equipment — thermal weapons
    weapon_thermal_lance = { name = 'Thermal Lance', stack = 1, category = 'equipment' },
    weapon_thermal_blade = { name = 'Thermal Blade', stack = 1, category = 'equipment' },

    -- Throwables (consumable weapons)
    grenade       = { name = 'Grenade',          stack = 5, category = 'throwable' },
    ied           = { name = 'IED',              stack = 3, category = 'throwable' },
    molotov       = { name = 'Molotov Cocktail', stack = 5, category = 'throwable' },
    pipe_bomb     = { name = 'Pipe Bomb',        stack = 5, category = 'throwable' },
    cryo_grenade  = { name = 'Cryo Grenade',     stack = 5, category = 'throwable' },

    -- Ammunition — thermal
    ammo_thermal  = { name = 'Thermal Charges', stack = 30, category = 'ammo' },

    -- Eldritch eggs
    flesh_egg       = { name = 'Flesh Egg',         stack = 5,  category = 'eldritch' },
    ichor_egg       = { name = 'Ichor Egg',         stack = 5,  category = 'eldritch' },
    chitin_egg      = { name = 'Chitin Egg',        stack = 5,  category = 'eldritch' },
    void_egg        = { name = 'Void Egg',          stack = 5,  category = 'eldritch' },

    -- Eldritch spores
    spore_bile      = { name = 'Bile Spore',        stack = 5,  category = 'eldritch' },
    spore_thorn     = { name = 'Thorn Spore',       stack = 5,  category = 'eldritch' },
    spore_nerve     = { name = 'Nerve Spore',       stack = 5,  category = 'eldritch' },
    spore_rot       = { name = 'Rot Spore',         stack = 5,  category = 'eldritch' },

    -- Eldritch node resources
    eldritch_ichor  = { name = 'Eldritch Ichor',    stack = 20, category = 'eldritch' },
    raw_fat         = { name = 'Raw Fat',           stack = 20, category = 'eldritch' },
    chitin_plate    = { name = 'Chitin Plate',      stack = 15, category = 'eldritch' },
    void_crystal    = { name = 'Void Crystal',      stack = 10, category = 'eldritch' },
    raw_fur         = { name = 'Raw Fur',           stack = 20, category = 'eldritch' },
    caustic_liquid  = { name = 'Caustic Liquid',    stack = 15, category = 'eldritch' },
    serpent_venom   = { name = 'Serpent Venom',     stack = 10, category = 'eldritch' },
    wyrm_egg        = { name = 'Wyrm Egg',         stack = 5,  category = 'eldritch' },

    -- Ammunition
    ammo_arrow        = { name = 'Arrows',         stack = 50, category = 'ammo' },
    ammo_fire_arrow   = { name = 'Fire Arrows',    stack = 30, category = 'ammo' },
    ammo_bolt         = { name = 'Crossbow Bolts', stack = 50, category = 'ammo' },
    ammo_bullet       = { name = 'Bullets',        stack = 50, category = 'ammo' },
    ammo_shell        = { name = 'Shells',         stack = 30, category = 'ammo' },
    ammo_rocket       = { name = 'Rockets',        stack = 10, category = 'ammo' },
    ammo_mortar_shell = { name = 'Mortar Shells',  stack = 10, category = 'ammo' },
    napalm_fuel       = { name = 'Napalm Fuel',   stack = 10, category = 'ammo' },
    foam_canister     = { name = 'Foam Canister',  stack = 10, category = 'ammo' },
    gas_canister      = { name = 'Gas Canister',   stack = 10, category = 'ammo' },
    acid_canister     = { name = 'Acid Canister',  stack = 10, category = 'ammo' },
    poison_darts      = { name = 'Poison Darts',   stack = 20, category = 'ammo' },

    -- Ordnance (placed explosives)
    placed_charge   = { name = 'Placed Charge',   stack = 3, category = 'ordnance' },
    timed_bomb      = { name = 'Timed Bomb',       stack = 3, category = 'ordnance' },
    tripwire_bomb   = { name = 'Tripwire Bomb',    stack = 3, category = 'ordnance' },
    napalm_grenade  = { name = 'Napalm Grenade',   stack = 5, category = 'ordnance' },
    napalm_bomb     = { name = 'Napalm Bomb',      stack = 2, category = 'ordnance' },
    bio_grenade     = { name = 'Bio Grenade',       stack = 5, category = 'ordnance' },
    bio_bomb        = { name = 'Bio Bomb',          stack = 2, category = 'ordnance' },
    foam_grenade    = { name = 'Foam Grenade',      stack = 5, category = 'ordnance' },
    foam_bomb       = { name = 'Foam Bomb',         stack = 2, category = 'ordnance' },
    c4_charge       = { name = 'C4 Charge',         stack = 3, category = 'ordnance' },
    emp_charge      = { name = 'EMP Charge',        stack = 3, category = 'ordnance' },
    emp_grenade     = { name = 'EMP Grenade',       stack = 5, category = 'ordnance' },
    briefcase_nuke  = { name = 'Briefcase Nuke',    stack = 1, category = 'ordnance' },
    nuclear_core    = { name = 'Nuclear Core',      stack = 1, category = 'ordnance' },

    -- Missiles (silo-crafted)
    missile_he      = { name = 'HE Missile',       stack = 3, category = 'missile' },
    missile_napalm  = { name = 'Napalm Missile',   stack = 3, category = 'missile' },
    missile_bio     = { name = 'Bio Missile',       stack = 2, category = 'missile' },
    missile_foam    = { name = 'Foam Missile',      stack = 3, category = 'missile' },
    missile_bunker  = { name = 'Bunker Buster',    stack = 2, category = 'missile' },
    missile_nuke    = { name = 'Mini Nuke',         stack = 1, category = 'missile' },

    -- Power
    fuel_cell    = { name = 'Fuel Cell',       stack = 10, category = 'power' },

    -- Physical item IDs (match item_defs.lua; used by inserter-fed recipes)
    iron_ore         = { name = 'Iron Ore',          stack = 50, category = 'raw' },
    copper_ore       = { name = 'Copper Ore',         stack = 50, category = 'raw' },
    uranium_ore      = { name = 'Uranium Ore',        stack = 20, category = 'raw' },
    stone_chunk      = { name = 'Stone Chunk',        stack = 50, category = 'raw' },
    logs             = { name = 'Logs',               stack = 50, category = 'raw' },
    ice_block        = { name = 'Ice Block',          stack = 50, category = 'raw' },
    iron_ingot       = { name = 'Iron Ingot',         stack = 50, category = 'material' },
    lead_ingot       = { name = 'Lead Ingot',         stack = 50, category = 'material' },
    copper_ingot     = { name = 'Copper Ingot',       stack = 50, category = 'material' },
    enriched_uranium = { name = 'Enriched Uranium',   stack = 10, category = 'advanced' },
    depleted_uranium = { name = 'Depleted Uranium',   stack = 20, category = 'material' },
    planks           = { name = 'Planks',             stack = 50, category = 'material' },
    fuel             = { name = 'Fuel',               stack = 20, category = 'fuel' },
}

local RECIPES = {
    -- Sawmill: wood processing
    saw_lumber = {
        name     = 'Saw Lumber',
        machine  = 'sawmill',
        inputs   = { raw_wood = 2 },
        outputs  = { lumber = 3 },
        time     = 5,     -- seconds per craft
        power    = 0,     -- watts required
        skill    = 'building',
        minSkill = 1,
    },

    -- Stonecutter: stone processing
    cut_stone = {
        name     = 'Cut Stone',
        machine  = 'stonecutter',
        inputs   = { raw_stone = 2 },
        outputs  = { cut_stone = 2 },
        time     = 6,
        power    = 0,
        skill    = 'mining',
        minSkill = 1,
    },

    -- Smelter: ore → metal
    smelt_ore = {
        name     = 'Smelt Ore',
        machine  = 'smelter',
        inputs   = { raw_ore = 3, coal = 1 },
        outputs  = { metal_ingot = 2 },
        time     = 10,
        power    = 5,
        skill    = 'building',
        minSkill = 3,
    },

    -- Smelter: lead ore → lead
    smelt_lead = {
        name     = 'Smelt Lead',
        machine  = 'smelter',
        inputs   = { lead_ore = 3, coal = 1 },
        outputs  = { lead = 2 },
        time     = 8,
        power    = 5,
        skill    = 'building',
        minSkill = 3,
    },

    -- Forge: metal → steel
    forge_steel = {
        name     = 'Forge Steel',
        machine  = 'forge',
        inputs   = { metal_ingot = 3, coal = 2 },
        outputs  = { steel = 2 },
        time     = 15,
        power    = 10,
        skill    = 'building',
        minSkill = 5,
    },

    forge_plasteel = {
        name     = 'Forge Plasteel',
        machine  = 'forge',
        inputs   = { steel = 3, circuit = 2 },
        outputs  = { plasteel = 1 },
        time     = 20,
        power    = 15,
        skill    = 'building',
        minSkill = 8,
    },

    -- Forge: components
    craft_components = {
        name     = 'Craft Components',
        machine  = 'forge',
        inputs   = { metal_ingot = 2, raw_wood = 1 },
        outputs  = { components = 1 },
        time     = 12,
        power    = 5,
        skill    = 'building',
        minSkill = 4,
    },

    -- Workbench: circuits
    craft_circuit = {
        name     = 'Craft Circuit',
        machine  = 'workbench',
        inputs   = { metal_ingot = 1, components = 1 },
        outputs  = { circuit = 1 },
        time     = 20,
        power    = 10,
        skill    = 'research',
        minSkill = 5,
    },

    -- Tannery: hides → leather
    tan_leather = {
        name     = 'Tan Leather',
        machine  = 'tannery',
        inputs   = { raw_hide = 2 },
        outputs  = { leather = 2 },
        time     = 8,
        power    = 0,
        skill    = 'cooking',
        minSkill = 2,
    },

    -- Loom: fiber → cloth
    weave_cloth = {
        name     = 'Weave Cloth',
        machine  = 'loom',
        inputs   = { plant_fiber = 4 },
        outputs  = { cloth = 2 },
        time     = 10,
        power    = 0,
        skill    = 'cooking',
        minSkill = 2,
    },

    -- Kitchen: bread (flour from plant fiber)
    make_bread = {
        name     = 'Make Bread',
        machine  = 'kitchen',
        inputs   = { plant_fiber = 3, water = 1 },
        outputs  = { bread = 2 },
        time     = 8,
        power    = 0,
        skill    = 'cooking',
        minSkill = 2,
    },

    -- Kitchen: basic cooking (meat)
    cook_meat = {
        name     = 'Grill Meat',
        machine  = 'kitchen',
        inputs   = { raw_meat = 1 },
        outputs  = { cooked_meat = 1 },
        time     = 4,
        power    = 0,
        skill    = 'cooking',
        minSkill = 1,
    },

    -- Kitchen: cook foraged ingredients into a simple meal
    cook_forage = {
        name     = 'Cook Foraged Meal',
        machine  = 'kitchen',
        inputs   = { berries = 2, mushrooms = 1 },
        outputs  = { cooked_meat = 1 },
        time     = 5,
        power    = 0,
        skill    = 'cooking',
        minSkill = 1,
    },

    -- Kitchen: hearty stew (meat + water)
    make_stew = {
        name     = 'Make Hearty Stew',
        machine  = 'kitchen',
        inputs   = { cooked_meat = 2, water = 1 },
        outputs  = { stew = 2 },
        time     = 8,
        power    = 0,
        skill    = 'cooking',
        minSkill = 3,
    },

    -- Kitchen: mushroom stew (vegetarian alternative)
    make_mushroom_stew = {
        name     = 'Make Mushroom Stew',
        machine  = 'kitchen',
        inputs   = { mushrooms = 3, water = 1 },
        outputs  = { stew = 2 },
        time     = 10,
        power    = 0,
        skill    = 'cooking',
        minSkill = 3,
    },

    -- Smokehouse: smoked jerky (long-lasting)
    make_jerky = {
        name     = 'Smoke Jerky',
        machine  = 'smokehouse',
        inputs   = { raw_meat = 3, coal = 1 },
        outputs  = { jerky = 4 },
        time     = 15,
        power    = 0,
        skill    = 'cooking',
        minSkill = 2,
    },

    -- Kitchen: frontier feast (morale boost food)
    prepare_feast = {
        name     = 'Prepare Frontier Feast',
        machine  = 'kitchen',
        inputs   = { cooked_meat = 3, stew = 1, berries = 2 },
        outputs  = { feast = 1 },
        time     = 20,
        power    = 0,
        skill    = 'cooking',
        minSkill = 6,
    },

    -- Kitchen: pemmican (travel rations)
    pack_rations = {
        name     = 'Make Pemmican',
        machine  = 'kitchen',
        inputs   = { jerky = 2, bread = 1 },
        outputs  = { ration = 2 },
        time     = 10,
        power    = 0,
        skill    = 'cooking',
        minSkill = 3,
    },

    -- Medical: bandages
    craft_bandage = {
        name     = 'Craft Bandage',
        machine  = 'med_bench',
        inputs   = { cloth = 2 },
        outputs  = { bandage = 3 },
        time     = 5,
        power    = 0,
        skill    = 'medical',
        minSkill = 1,
    },

    -- Medical: medicine
    craft_medicine = {
        name     = 'Craft Medicine',
        machine  = 'med_bench',
        inputs   = { plant_fiber = 3, cloth = 1, water = 1 },
        outputs  = { medicine = 1 },
        time     = 15,
        power    = 5,
        skill    = 'medical',
        minSkill = 4,
    },

    -- Drug lab: Spike (crystal meth)
    cook_spike = {
        name     = 'Cook Spike',
        machine  = 'drug_lab',
        inputs   = { psychoid_leaf = 6, thermal_core = 1, water = 1 },
        outputs  = { spike = 2 },
        time     = 15,
        power    = 10,
        skill    = 'medical',
        minSkill = 6,
    },

    -- Drug lab: Stardust (cocaine)
    cut_stardust = {
        name     = 'Cut Stardust',
        machine  = 'drug_lab',
        inputs   = { psychoid_leaf = 8, water = 2 },
        outputs  = { stardust = 2 },
        time     = 12,
        power    = 10,
        skill    = 'medical',
        minSkill = 5,
    },

    -- Drug lab: Drift (opiate)
    brew_drift = {
        name     = 'Brew Drift',
        machine  = 'drug_lab',
        inputs   = { plant_fiber = 4, medicinal_herb = 2, water = 1 },
        outputs  = { drift = 2 },
        time     = 10,
        power    = 5,
        skill    = 'medical',
        minSkill = 4,
    },

    -- Drug lab: Smog (marijuana)
    roll_smog = {
        name     = 'Roll Smog',
        machine  = 'drug_lab',
        inputs   = { smokeleaf_leaf = 4 },
        outputs  = { smog = 3 },
        time     = 5,
        power    = 0,
        skill    = 'cooking',
        minSkill = 2,
    },

    -- Drug lab: Shards (acid)
    drop_shards = {
        name     = 'Drop Shards',
        machine  = 'drug_lab',
        inputs   = { mushrooms = 4, thermal_core = 1, water = 2 },
        outputs  = { shards = 1 },
        time     = 20,
        power    = 10,
        skill    = 'medical',
        minSkill = 7,
    },

    -- Drug lab: Glimpse (DMT)
    cook_glimpse = {
        name     = 'Cook Glimpse',
        machine  = 'drug_lab',
        inputs   = { thermal_core = 3, shards = 1, water = 2 },
        outputs  = { glimpse = 1 },
        time     = 30,
        power    = 15,
        skill    = 'medical',
        minSkill = 9,
    },

    -- Drug lab: Surge (combat stimulant)
    brew_surge = {
        name     = 'Brew Surge',
        machine  = 'drug_lab',
        inputs   = { spike = 1, raw_meat = 2, thermal_core = 1 },
        outputs  = { surge = 1 },
        time     = 25,
        power    = 15,
        skill    = 'medical',
        minSkill = 7,
    },

    -- Drug lab: Thaw (medical warmth)
    brew_thaw = {
        name     = 'Brew Thaw',
        machine  = 'drug_lab',
        inputs   = { thermal_core = 1, water = 2, plant_fiber = 2 },
        outputs  = { thaw = 2 },
        time     = 15,
        power    = 10,
        skill    = 'medical',
        minSkill = 5,
    },

    -- Drug lab: Voidbloom (eldritch psychoactive)
    brew_voidbloom = {
        name     = 'Brew Voidbloom',
        machine  = 'drug_lab',
        inputs   = { eldritch_ichor = 2, medicinal_herb = 2, void_crystal = 1 },
        outputs  = { voidbloom = 1 },
        time     = 30,
        power    = 15,
        skill    = 'medical',
        minSkill = 7,
    },

    -- Drug lab: Revivify Serum (resurrection chem)
    brew_revivify = {
        name     = 'Brew Revivify Serum',
        machine  = 'drug_lab',
        inputs   = { medicine = 2, thermal_core = 1, eldritch_ichor = 1 },
        outputs  = { revivify_serum = 1 },
        time     = 60,
        power    = 15,
        skill    = 'medical',
        minSkill = 8,
    },

    -- Drug lab: Berserker (combat rage drug)
    brew_berserker = {
        name     = 'Brew Berserker',
        machine  = 'drug_lab',
        inputs   = { surge = 1, spike = 1, thermal_core = 1 },
        outputs  = { berserker = 1 },
        time     = 20,
        power    = 15,
        skill    = 'medical',
        minSkill = 8,
    },

    -- Drug lab: Stim (combat focus drug)
    brew_stim = {
        name     = 'Brew Stim',
        machine  = 'drug_lab',
        inputs   = { drift = 1, stardust = 1, medicinal_herb = 2 },
        outputs  = { stim = 1 },
        time     = 18,
        power    = 15,
        skill    = 'medical',
        minSkill = 7,
    },

    -- Medical: advanced medicine
    craft_advanced_medicine = {
        name     = 'Craft Advanced Medicine',
        machine  = 'med_bench',
        inputs   = { medicine = 2, components = 1, thermal_core = 1 },
        outputs  = { advanced_medicine = 1 },
        time     = 25,
        power    = 10,
        skill    = 'medical',
        minSkill = 6,
    },

    -- Fuel refinery: thermal cores → fuel cells
    refine_fuel = {
        name     = 'Refine Fuel Cell',
        machine  = 'refinery',
        inputs   = { thermal_core = 1, coal = 2 },
        outputs  = { fuel_cell = 2 },
        time     = 20,
        power    = 15,
        skill    = 'research',
        minSkill = 4,
    },

    -- Water melter: ice → water
    melt_ice = {
        name     = 'Melt Ice',
        machine  = 'melter',
        inputs   = { raw_ice = 3 },
        outputs  = { water = 3 },
        time     = 6,
        power    = 5,
        skill    = 'building',
        minSkill = 1,
    },

    -- Butcher table: corpse processing
    butcher_creature = {
        name     = 'Butcher Creature',
        machine  = 'butcher_table',
        inputs   = { corpse_creature = 1 },
        outputs  = { raw_meat = 4, raw_hide = 2 },
        time     = 8,
        power    = 0,
        skill    = 'cooking',
        minSkill = 1,
    },
    butcher_human = {
        name     = 'Butcher Human',
        machine  = 'butcher_table',
        inputs   = { corpse_human = 1 },
        outputs  = { human_meat = 6, human_leather = 3 },
        time     = 12,
        power    = 0,
        skill    = 'cooking',
        minSkill = 1,
        dark     = true,  -- triggers colony morale penalties
    },

    -- Prosthetics: wood (workbench)
    craft_peg_leg = {
        name     = 'Craft Peg Leg',
        machine  = 'workbench',
        inputs   = { raw_wood = 5 },
        outputs  = { peg_leg = 1 },
        time     = 8,
        power    = 0,
        skill    = 'building',
        minSkill = 3,
    },
    craft_wooden_arm = {
        name     = 'Craft Wooden Arm',
        machine  = 'workbench',
        inputs   = { raw_wood = 5 },
        outputs  = { wooden_arm = 1 },
        time     = 8,
        power    = 0,
        skill    = 'building',
        minSkill = 3,
    },

    -- Prosthetics: metal (forge)
    craft_prosthetic_leg = {
        name     = 'Craft Prosthetic Leg',
        machine  = 'forge',
        inputs   = { metal_ingot = 4, components = 1 },
        outputs  = { prosthetic_leg = 1 },
        time     = 15,
        power    = 5,
        skill    = 'building',
        minSkill = 5,
    },
    craft_prosthetic_arm = {
        name     = 'Craft Prosthetic Arm',
        machine  = 'forge',
        inputs   = { metal_ingot = 4, components = 1 },
        outputs  = { prosthetic_arm = 1 },
        time     = 15,
        power    = 5,
        skill    = 'building',
        minSkill = 5,
    },

    -- Bionics (forge)
    craft_bionic_leg = {
        name     = 'Craft Bionic Leg',
        machine  = 'forge',
        inputs   = { steel = 4, components = 3, circuit = 1 },
        outputs  = { bionic_leg = 1 },
        time     = 30,
        power    = 15,
        skill    = 'building',
        minSkill = 8,
    },
    craft_bionic_arm = {
        name     = 'Craft Bionic Arm',
        machine  = 'forge',
        inputs   = { steel = 4, components = 3, circuit = 1 },
        outputs  = { bionic_arm = 1 },
        time     = 30,
        power    = 15,
        skill    = 'building',
        minSkill = 8,
    },
    craft_bionic_eye = {
        name     = 'Craft Bionic Eye',
        machine  = 'forge',
        inputs   = { steel = 2, components = 2, circuit = 2 },
        outputs  = { bionic_eye = 1 },
        time     = 25,
        power    = 15,
        skill    = 'building',
        minSkill = 9,
    },

    -- Drug production from farm crops
    refine_psychoid = {
        name     = 'Refine Psychoid',
        machine  = 'drug_lab',
        inputs   = { psychoid_leaf = 4, water = 1 },
        outputs  = { stardust = 2 },
        time     = 10,
        power    = 5,
        skill    = 'medical',
        minSkill = 4,
    },
    roll_smokeleaf = {
        name     = 'Roll Smokeleaf',
        machine  = 'drug_lab',
        inputs   = { smokeleaf_leaf = 4 },
        outputs  = { smog = 3 },
        time     = 6,
        power    = 0,
        skill    = 'cooking',
        minSkill = 2,
    },
    brew_rotgut = {
        name     = 'Brew Rotgut',
        machine  = 'drug_lab',
        inputs   = { hops = 5, water = 3 },
        outputs  = { rotgut = 3 },
        time     = 15,
        power    = 0,
        skill    = 'cooking',
        minSkill = 3,
    },

    -- Fang: refined serpent venom, snorting drug — euphoric
    refine_fang = {
        name     = 'Refine Fang',
        machine  = 'drug_lab',
        inputs   = { serpent_venom = 2, caustic_liquid = 1 },
        outputs  = { fang = 3 },
        time     = 18,
        power    = 5,
        skill    = 'research',
        minSkill = 4,
    },

    -- Charcoal kiln: wood → charcoal (fuel)
    make_charcoal = {
        name     = 'Make Charcoal',
        machine  = 'kiln',
        inputs   = { raw_wood = 4 },
        outputs  = { charcoal = 3 },
        time     = 12,
        power    = 0,
        skill    = 'building',
        minSkill = 1,
    },

    -- Insulation crafting
    craft_insulation = {
        name     = 'Craft Insulation',
        machine  = 'workbench',
        inputs   = { cloth = 2, leather = 1 },
        outputs  = { insulation = 2 },
        time     = 10,
        power    = 0,
        skill    = 'building',
        minSkill = 3,
    },

    -- Pipe crafting
    craft_pipe = {
        name     = 'Craft Pipe',
        machine  = 'forge',
        inputs   = { metal_ingot = 2 },
        outputs  = { pipe = 3 },
        time     = 8,
        power    = 5,
        skill    = 'building',
        minSkill = 3,
    },

    -- Glass crafting (from ice/stone)
    craft_glass = {
        name     = 'Craft Glass',
        machine  = 'smelter',
        inputs   = { raw_stone = 3, coal = 2 },
        outputs  = { glass = 2 },
        time     = 12,
        power    = 10,
        skill    = 'building',
        minSkill = 4,
    },

    -- Parka (cold protection)
    craft_parka = {
        name     = 'Craft Parka',
        machine  = 'workbench',
        inputs   = { leather = 3, cloth = 2, insulation = 2 },
        outputs  = { parka = 1 },
        time     = 25,
        power    = 0,
        skill    = 'cooking',
        minSkill = 5,
    },

    -- Boots
    craft_boots = {
        name     = 'Craft Insulated Boots',
        machine  = 'workbench',
        inputs   = { leather = 2, insulation = 1 },
        outputs  = { boots = 1 },
        time     = 15,
        power    = 0,
        skill    = 'cooking',
        minSkill = 3,
    },

    -- Weapons
    craft_axe = {
        name     = 'Craft Ice Axe',
        machine  = 'forge',
        inputs   = { metal_ingot = 3, raw_wood = 2 },
        outputs  = { weapon_axe = 1 },
        time     = 15,
        power    = 5,
        skill    = 'building',
        minSkill = 4,
    },

    craft_spear = {
        name     = 'Craft Hunting Spear',
        machine  = 'forge',
        inputs   = { metal_ingot = 2, raw_wood = 3 },
        outputs  = { weapon_spear = 1 },
        time     = 12,
        power    = 5,
        skill    = 'building',
        minSkill = 3,
    },

    -- Improvised melee
    craft_club = {
        name = 'Craft Club', machine = 'workbench',
        inputs = { raw_wood = 2 }, outputs = { weapon_club = 1 },
        time = 3, power = 0, skill = 'building', minSkill = 0,
    },
    craft_shiv = {
        name = 'Craft Shiv', machine = 'workbench',
        inputs = { metal_ingot = 1 }, outputs = { weapon_shiv = 1 },
        time = 4, power = 0, skill = 'building', minSkill = 1,
    },
    craft_pipe_wrench = {
        name = 'Craft Pipe Wrench', machine = 'forge',
        inputs = { metal_ingot = 2 }, outputs = { weapon_pipe_wrench = 1 },
        time = 6, power = 5, skill = 'building', minSkill = 2,
    },
    craft_torch = {
        name = 'Craft Torch', machine = 'workbench',
        inputs = { raw_wood = 1, cloth = 1 }, outputs = { weapon_torch = 3 },
        time = 3, power = 0, skill = 'building', minSkill = 0,
    },

    -- Crafted melee
    craft_knife = {
        name = 'Craft Knife', machine = 'forge',
        inputs = { metal_ingot = 2 }, outputs = { weapon_knife = 1 },
        time = 6, power = 5, skill = 'building', minSkill = 2,
    },
    craft_hatchet = {
        name = 'Craft Hatchet', machine = 'forge',
        inputs = { metal_ingot = 2, raw_wood = 1 }, outputs = { weapon_hatchet = 1 },
        time = 8, power = 5, skill = 'building', minSkill = 3,
    },
    craft_machete = {
        name = 'Craft Machete', machine = 'forge',
        inputs = { metal_ingot = 3, raw_wood = 1 }, outputs = { weapon_machete = 1 },
        time = 10, power = 5, skill = 'building', minSkill = 3,
    },
    craft_sword = {
        name = 'Craft Sword', machine = 'forge',
        inputs = { metal_ingot = 4, raw_wood = 1 }, outputs = { weapon_sword = 1 },
        time = 18, power = 5, skill = 'building', minSkill = 5,
    },

    -- Thermal weapons
    craft_thermal_blade = {
        name = 'Craft Thermal Blade', machine = 'forge',
        inputs = { steel = 3, thermal_core = 2, components = 1 }, outputs = { weapon_thermal_blade = 1 },
        time = 25, power = 15, skill = 'building', minSkill = 7,
    },
    craft_thermal_lance = {
        name = 'Craft Thermal Lance', machine = 'forge',
        inputs = { steel = 4, thermal_core = 3, components = 2, circuit = 1 }, outputs = { weapon_thermal_lance = 1 },
        time = 35, power = 20, skill = 'building', minSkill = 8,
    },
    craft_cryo_grenade = {
        name = 'Craft Cryo Grenade', machine = 'workbench',
        inputs = { metal_ingot = 1, water = 3, components = 1 }, outputs = { cryo_grenade = 2 },
        time = 12, power = 5, skill = 'building', minSkill = 5,
    },
    craft_thermal_ammo = {
        name = 'Craft Thermal Charges', machine = 'forge',
        inputs = { thermal_core = 1, metal_ingot = 2 }, outputs = { ammo_thermal = 10 },
        time = 15, power = 10, skill = 'building', minSkill = 5,
    },

    -- Thermal core synthesis (late-game crafting of cores from raw materials)
    synthesize_thermal_core = {
        name = 'Synthesize Thermal Core', machine = 'forge',
        inputs = { metal_ingot = 5, coal = 4, components = 2 }, outputs = { thermal_core = 1 },
        time = 40, power = 25, skill = 'building', minSkill = 8,
    },

    -- Bows / crossbows
    craft_shortbow = {
        name = 'Craft Short Bow', machine = 'workbench',
        inputs = { raw_wood = 3, plant_fiber = 2 }, outputs = { weapon_shortbow = 1 },
        time = 8, power = 0, skill = 'building', minSkill = 2,
    },
    craft_bow = {
        name = 'Craft Hunting Bow', machine = 'workbench',
        inputs = { lumber = 3, plant_fiber = 3 }, outputs = { weapon_bow = 1 },
        time = 14, power = 0, skill = 'building', minSkill = 4,
    },
    craft_crossbow = {
        name = 'Craft Crossbow', machine = 'workbench',
        inputs = { lumber = 3, metal_ingot = 2, components = 1 }, outputs = { weapon_crossbow = 1 },
        time = 20, power = 0, skill = 'building', minSkill = 5,
    },

    -- Pistols
    craft_revolver = {
        name = 'Craft Revolver', machine = 'forge',
        inputs = { steel = 2, components = 1, raw_wood = 1 }, outputs = { weapon_revolver = 1 },
        time = 20, power = 10, skill = 'building', minSkill = 5,
    },
    craft_pistol = {
        name = 'Craft Pistol', machine = 'forge',
        inputs = { steel = 2, components = 2 }, outputs = { weapon_pistol = 1 },
        time = 22, power = 10, skill = 'building', minSkill = 5,
    },

    -- Shotguns
    craft_sawed_off = {
        name = 'Craft Sawed-Off', machine = 'forge',
        inputs = { steel = 3, components = 1, raw_wood = 1 }, outputs = { weapon_sawed_off = 1 },
        time = 25, power = 10, skill = 'building', minSkill = 5,
    },
    craft_pump_shotgun = {
        name = 'Craft Pump Shotgun', machine = 'forge',
        inputs = { steel = 4, components = 2, raw_wood = 1 }, outputs = { weapon_pump_shotgun = 1 },
        time = 30, power = 10, skill = 'building', minSkill = 6,
    },

    -- Rifles
    craft_bolt_action = {
        name = 'Craft Bolt-Action Rifle', machine = 'forge',
        inputs = { steel = 4, components = 3, circuit = 1 }, outputs = { weapon_bolt_action = 1 },
        time = 40, power = 15, skill = 'building', minSkill = 7,
    },
    craft_assault_rifle = {
        name = 'Craft Assault Rifle', machine = 'forge',
        inputs = { steel = 6, components = 4, circuit = 1 }, outputs = { weapon_assault_rifle = 1 },
        time = 50, power = 15, skill = 'building', minSkill = 8,
    },
    craft_battle_rifle = {
        name = 'Craft Battle Rifle', machine = 'forge',
        inputs = { steel = 5, components = 3, circuit = 1 }, outputs = { weapon_battle_rifle = 1 },
        time = 45, power = 15, skill = 'building', minSkill = 7,
    },

    -- Throwables
    craft_grenade = {
        name = 'Craft Grenade', machine = 'forge',
        inputs = { metal_ingot = 2, charcoal = 2 }, outputs = { grenade = 2 },
        time = 12, power = 5, skill = 'building', minSkill = 4,
    },
    craft_ied = {
        name = 'Craft IED', machine = 'workbench',
        inputs = { metal_ingot = 1, charcoal = 3, cloth = 1 }, outputs = { ied = 1 },
        time = 10, power = 0, skill = 'building', minSkill = 3,
    },
    craft_molotov = {
        name = 'Craft Molotov', machine = 'workbench',
        inputs = { glass = 1, charcoal = 1, cloth = 1 }, outputs = { molotov = 2 },
        time = 5, power = 0, skill = 'building', minSkill = 1,
    },
    craft_pipe_bomb = {
        name = 'Craft Pipe Bomb', machine = 'forge',
        inputs = { pipe = 1, charcoal = 2 }, outputs = { pipe_bomb = 2 },
        time = 10, power = 5, skill = 'building', minSkill = 3,
    },

    -- Ammunition
    craft_arrows = {
        name = 'Craft Arrows', machine = 'workbench',
        inputs = { lumber = 1, raw_stone = 1 }, outputs = { ammo_arrow = 10 },
        time = 8, power = 0, skill = 'building', minSkill = 1,
    },
    craft_fire_arrows = {
        name = 'Craft Fire Arrows', machine = 'workbench',
        inputs = { ammo_arrow = 5, cloth = 1, charcoal = 1 }, outputs = { ammo_fire_arrow = 5 },
        time = 6, power = 0, skill = 'building', minSkill = 2,
    },
    craft_bolts = {
        name = 'Craft Bolts', machine = 'workbench',
        inputs = { metal_ingot = 1, lumber = 1 }, outputs = { ammo_bolt = 10 },
        time = 10, power = 0, skill = 'building', minSkill = 2,
    },
    craft_bullets = {
        name = 'Craft Bullets', machine = 'forge',
        inputs = { metal_ingot = 2 }, outputs = { ammo_bullet = 15 },
        time = 12, power = 10, skill = 'building', minSkill = 4,
    },
    craft_shells = {
        name = 'Craft Shells', machine = 'forge',
        inputs = { metal_ingot = 3, charcoal = 1 }, outputs = { ammo_shell = 8 },
        time = 15, power = 10, skill = 'building', minSkill = 5,
    },
    craft_rockets = {
        name = 'Craft Rockets', machine = 'forge',
        inputs = { metal_ingot = 3, charcoal = 2, components = 1 }, outputs = { ammo_rocket = 3 },
        time = 18, power = 10, skill = 'building', minSkill = 6,
    },
    craft_mortar_shells = {
        name = 'Craft Mortar Shells', machine = 'forge',
        inputs = { metal_ingot = 2, charcoal = 3 }, outputs = { ammo_mortar_shell = 4 },
        time = 15, power = 10, skill = 'building', minSkill = 5,
    },

    -- Ordnance crafting (workbench / forge)
    craft_placed_charge = {
        name = 'Craft Placed Charge', machine = 'workbench',
        inputs = { metal_ingot = 3, charcoal = 4 }, outputs = { placed_charge = 1 },
        time = 15, power = 0, skill = 'building', minSkill = 4,
    },
    craft_timed_bomb = {
        name = 'Craft Timed Bomb', machine = 'workbench',
        inputs = { metal_ingot = 2, charcoal = 3, components = 1 }, outputs = { timed_bomb = 1 },
        time = 18, power = 0, skill = 'building', minSkill = 5,
    },
    craft_tripwire_bomb = {
        name = 'Craft Tripwire Bomb', machine = 'workbench',
        inputs = { metal_ingot = 2, charcoal = 2, cloth = 1 }, outputs = { tripwire_bomb = 1 },
        time = 15, power = 0, skill = 'building', minSkill = 4,
    },
    craft_napalm_grenade = {
        name = 'Craft Napalm Grenade', machine = 'forge',
        inputs = { metal_ingot = 1, charcoal = 4 }, outputs = { napalm_grenade = 2 },
        time = 12, power = 5, skill = 'building', minSkill = 4,
    },
    craft_napalm_bomb = {
        name = 'Craft Napalm Bomb', machine = 'forge',
        inputs = { metal_ingot = 2, charcoal = 7 }, outputs = { napalm_bomb = 1 },
        time = 20, power = 5, skill = 'building', minSkill = 5,
    },
    craft_bio_grenade = {
        name = 'Craft Bio Grenade', machine = 'workbench',
        inputs = { glass = 2, medicinal_herb = 3 }, outputs = { bio_grenade = 2 },
        time = 15, power = 0, skill = 'building', minSkill = 6,
    },
    craft_bio_bomb = {
        name = 'Craft Bio Bomb', machine = 'workbench',
        inputs = { glass = 3, medicinal_herb = 5, components = 2 }, outputs = { bio_bomb = 1 },
        time = 25, power = 0, skill = 'building', minSkill = 7,
    },
    craft_foam_grenade = {
        name = 'Craft Foam Grenade', machine = 'workbench',
        inputs = { glass = 1, raw_ice = 3 }, outputs = { foam_grenade = 2 },
        time = 8, power = 0, skill = 'building', minSkill = 2,
    },
    craft_foam_bomb = {
        name = 'Craft Foam Bomb', machine = 'workbench',
        inputs = { metal_ingot = 2, raw_ice = 5, components = 1 }, outputs = { foam_bomb = 1 },
        time = 15, power = 0, skill = 'building', minSkill = 4,
    },
    craft_napalm_fuel = {
        name = 'Craft Napalm Fuel', machine = 'forge',
        inputs = { charcoal = 4 }, outputs = { napalm_fuel = 4 },
        time = 10, power = 5, skill = 'building', minSkill = 3,
    },
    craft_foam_canister = {
        name = 'Craft Foam Canister', machine = 'workbench',
        inputs = { raw_ice = 4, metal_ingot = 1 }, outputs = { foam_canister = 4 },
        time = 10, power = 0, skill = 'building', minSkill = 2,
    },
    craft_gas_canister = {
        name = 'Craft Gas Canister', machine = 'workbench',
        inputs = { charcoal = 3, glass = 2 }, outputs = { gas_canister = 4 },
        time = 12, power = 0, skill = 'building', minSkill = 3,
    },
    craft_acid_canister = {
        name = 'Craft Acid Canister', machine = 'workbench',
        inputs = { raw_ice = 2, metal_ingot = 1, components = 1 }, outputs = { acid_canister = 3 },
        time = 15, power = 0, skill = 'building', minSkill = 4,
    },
    craft_poison_darts = {
        name = 'Craft Poison Darts', machine = 'workbench',
        inputs = { metal_ingot = 1, medicinal_herb = 3 }, outputs = { poison_darts = 10 },
        time = 10, power = 0, skill = 'building', minSkill = 3,
    },
    craft_c4 = {
        name = 'Craft C4 Charge', machine = 'workbench',
        inputs = { metal_ingot = 2, charcoal = 5, components = 2 }, outputs = { c4_charge = 1 },
        time = 20, power = 0, skill = 'building', minSkill = 6,
    },
    craft_emp_charge = {
        name = 'Craft EMP Charge', machine = 'forge',
        inputs = { metal_ingot = 3, components = 4, circuit = 2 }, outputs = { emp_charge = 1 },
        time = 25, power = 15, skill = 'building', minSkill = 7,
    },
    craft_emp_grenade = {
        name = 'Craft EMP Grenade', machine = 'forge',
        inputs = { metal_ingot = 1, components = 2, circuit = 1 }, outputs = { emp_grenade = 2 },
        time = 15, power = 10, skill = 'building', minSkill = 5,
    },
    craft_briefcase_nuke = {
        name = 'Craft Briefcase Nuke', machine = 'forge',
        inputs = { metal_ingot = 5, components = 6, nuclear_core = 1 }, outputs = { briefcase_nuke = 1 },
        time = 60, power = 25, skill = 'building', minSkill = 9,
    },
    craft_nuclear_core = {
        name = 'Refine Nuclear Core', machine = 'forge',
        inputs = { thermal_core = 5, components = 5, metal_ingot = 10 }, outputs = { nuclear_core = 1 },
        time = 60, power = 30, skill = 'building', minSkill = 8,
    },

    -- Missile assembly (missile_foundry machine)
    assemble_missile_he = {
        name = 'Assemble HE Missile', machine = 'missile_foundry',
        inputs = { metal_ingot = 5, charcoal = 4, components = 3 }, outputs = { missile_he = 1 },
        time = 30, power = 20, skill = 'building', minSkill = 6,
    },
    assemble_missile_napalm = {
        name = 'Assemble Napalm Missile', machine = 'missile_foundry',
        inputs = { metal_ingot = 4, charcoal = 6, components = 2 }, outputs = { missile_napalm = 1 },
        time = 30, power = 20, skill = 'building', minSkill = 6,
    },
    assemble_missile_bio = {
        name = 'Assemble Bio Missile', machine = 'missile_foundry',
        inputs = { metal_ingot = 3, medicinal_herb = 8, components = 3 }, outputs = { missile_bio = 1 },
        time = 35, power = 20, skill = 'building', minSkill = 7,
    },
    assemble_missile_foam = {
        name = 'Assemble Foam Missile', machine = 'missile_foundry',
        inputs = { metal_ingot = 3, raw_ice = 8, components = 2 }, outputs = { missile_foam = 1 },
        time = 25, power = 20, skill = 'building', minSkill = 5,
    },
    assemble_missile_bunker = {
        name = 'Assemble Bunker Buster', machine = 'missile_foundry',
        inputs = { metal_ingot = 8, charcoal = 6, components = 5 }, outputs = { missile_bunker = 1 },
        time = 45, power = 25, skill = 'building', minSkill = 7,
    },
    assemble_missile_nuke = {
        name = 'Assemble Mini Nuke', machine = 'missile_foundry',
        inputs = { metal_ingot = 10, charcoal = 8, components = 8, nuclear_core = 1 }, outputs = { missile_nuke = 1 },
        time = 90, power = 30, skill = 'building', minSkill = 9,
    },

    -- Vehicle construction
    build_sled = {
        name = 'Build Sled (Legacy)', machine = 'vehicle_workbench',
        inputs = { lumber = 15, leather = 5, metal_ingot = 3 }, outputs = {},
        time = 60, power = 10, skill = 'building', minSkill = 4,
        hidden = true, -- archived system; retained only so legacy saves do not hard-fail
    },

    ---------------------------------------------------------------------------
    -- Physical-item processing chains (fed by inserters from ground items)
    ---------------------------------------------------------------------------

    -- Smelter: iron ore → iron ingot
    smelt_iron = {
        name     = 'Smelt Iron',
        machine  = 'smelter',
        inputs   = { iron_ore = 1 },
        outputs  = { iron_ingot = 1 },
        time     = 5,
        power    = 5,
        skill    = 'building',
        minSkill = 1,
    },

    -- Smelter: lead ore → lead ingot
    smelt_lead_ingot = {
        name     = 'Smelt Lead',
        machine  = 'smelter',
        inputs   = { lead_ore = 1 },
        outputs  = { lead_ingot = 1 },
        time     = 5,
        power    = 5,
        skill    = 'building',
        minSkill = 1,
    },

    -- Smelter: copper ore → copper ingot
    smelt_copper = {
        name     = 'Smelt Copper',
        machine  = 'smelter',
        inputs   = { copper_ore = 1 },
        outputs  = { copper_ingot = 1 },
        time     = 5,
        power    = 5,
        skill    = 'building',
        minSkill = 1,
    },

    -- Forge: iron ingot + fuel → steel
    forge_steel_ingot = {
        name     = 'Forge Steel',
        machine  = 'forge',
        inputs   = { iron_ingot = 1, fuel = 1 },
        outputs  = { steel = 1 },
        time     = 8,
        power    = 10,
        skill    = 'building',
        minSkill = 3,
    },

    -- Centrifuge: uranium ore × 2 → enriched uranium + depleted uranium
    enrich_uranium = {
        name     = 'Enrich Uranium',
        machine  = 'centrifuge',
        inputs   = { uranium_ore = 2 },
        outputs  = { enriched_uranium = 1, depleted_uranium = 1 },
        time     = 15,
        power    = 20,
        skill    = 'research',
        minSkill = 6,
    },

    -- Sawmill: logs → planks × 2
    saw_planks = {
        name     = 'Saw Planks',
        machine  = 'sawmill',
        inputs   = { logs = 1 },
        outputs  = { planks = 2 },
        time     = 4,
        power    = 0,
        skill    = 'building',
        minSkill = 1,
    },

    -- Stonecutter: stone chunk × 2 → cut stone
    cut_stone_chunk = {
        name     = 'Cut Stone',
        machine  = 'stonecutter',
        inputs   = { stone_chunk = 2 },
        outputs  = { cut_stone = 1 },
        time     = 6,
        power    = 0,
        skill    = 'mining',
        minSkill = 1,
    },

    -- Refiner: ice block × 2 → water
    refine_ice = {
        name     = 'Refine Ice',
        machine  = 'refiner',
        inputs   = { ice_block = 2 },
        outputs  = { water = 1 },
        time     = 3,
        power    = 5,
        skill    = 'building',
        minSkill = 1,
    },
}

local MACHINES = {
    sawmill    = { name = 'Sawmill',       size = {2,2}, cost = { lumber = 10, metal_ingot = 2 },            powerDraw = 0 },
    stonecutter= { name = 'Stonecutter',   size = {2,1}, cost = { lumber = 5, metal_ingot = 3 },             powerDraw = 0 },
    smelter    = { name = 'Smelter',       size = {2,2}, cost = { cut_stone = 15, metal_ingot = 5 },         powerDraw = 5 },
    forge      = { name = 'Forge',         size = {3,2}, cost = { cut_stone = 20, metal_ingot = 10 },        powerDraw = 10 },
    workbench  = { name = 'Workbench',     size = {2,1}, cost = { lumber = 8 },                              powerDraw = 0 },
    kitchen    = { name = 'Kitchen',       size = {2,2}, cost = { lumber = 10, cut_stone = 5 },              powerDraw = 0 },
    smokehouse = { name = 'Smokehouse',    size = {2,2}, cost = { lumber = 15, cut_stone = 5 },              powerDraw = 0 },
    tannery    = { name = 'Tannery',       size = {2,1}, cost = { lumber = 8, raw_stone = 5 },               powerDraw = 0 },
    loom       = { name = 'Loom',          size = {2,1}, cost = { lumber = 10 },                             powerDraw = 0 },
    med_bench  = { name = 'Medical Bench', size = {2,1}, cost = { lumber = 8, metal_ingot = 3 },             powerDraw = 0 },
    drug_lab   = { name = 'Drug Lab',      size = {2,2}, cost = { cut_stone = 10, metal_ingot = 5, glass = 3 }, powerDraw = 10 },
    refinery   = { name = 'Refinery',      size = {3,2}, cost = { steel = 10, components = 5, pipe = 8 },    powerDraw = 15 },
    melter     = { name = 'Ice Melter',    size = {1,1}, cost = { metal_ingot = 5, pipe = 2 },               powerDraw = 5 },
    kiln          = { name = 'Charcoal Kiln', size = {2,2}, cost = { cut_stone = 10, raw_wood = 5 },            powerDraw = 0 },
    butcher_table = { name = 'Butcher Table', size = {2,1}, cost = { lumber = 10, metal_ingot = 3 },            powerDraw = 0 },
    surgery_table = { name = 'Surgery Table', size = {2,2}, cost = { steel = 5, components = 3 },               powerDraw = 10 },
    missile_foundry = { name = 'Missile Foundry', size = {3,3}, cost = { steel = 20, components = 10, cut_stone = 15 }, powerDraw = 25 },
    vehicle_workbench = { name = 'Vehicle Workbench (Legacy)', size = {2,2}, cost = { metal_ingot = 10, steel = 5, components = 5 }, powerDraw = 10 },

    centrifuge = { name = 'Centrifuge',  size = {2,2}, cost = { steel = 8, components = 4, circuit = 1 },        powerDraw = 20 },
    refiner    = { name = 'Refiner',     size = {2,1}, cost = { metal_ingot = 6, pipe = 3 },                       powerDraw = 5 },

    -- Advanced machines (upgrade tiers — speedMult applied to recipe progress)
    powered_sawmill    = { name = 'Powered Sawmill',       size = {2,2}, cost = { metal_ingot = 10, components = 3 },               powerDraw = 15, speedMult = 1.5, baseMachine = 'sawmill' },
    advanced_smelter   = { name = 'Advanced Smelter',      size = {2,2}, cost = { steel = 10, components = 5, circuit = 2 },        powerDraw = 40, speedMult = 2.0, baseMachine = 'smelter' },
    precision_forge    = { name = 'Precision Forge',       size = {3,2}, cost = { steel = 12, components = 6, circuit = 3 },        powerDraw = 45, speedMult = 2.0, baseMachine = 'forge' },
    industrial_kitchen = { name = 'Industrial Kitchen',    size = {2,2}, cost = { metal_ingot = 12, components = 4, circuit = 1 },   powerDraw = 20, speedMult = 1.5, baseMachine = 'kitchen' },
    advanced_drug_lab  = { name = 'Advanced Drug Lab',     size = {2,2}, cost = { steel = 8, components = 6, circuit = 3 },          powerDraw = 25, speedMult = 2.0, baseMachine = 'drug_lab' },
    sterile_surgery    = { name = 'Sterile Surgery Suite', size = {2,2}, cost = { steel = 8, components = 5, circuit = 2 },          powerDraw = 15, speedMult = 1.5, baseMachine = 'surgery_table' },
}

local ITEM_TO_RES = {
    raw_wood = 'wood', raw_stone = 'stone', raw_ore = 'metal',
    raw_meat = 'food', raw_hide = 'raw_hide', thermal_core = 'thermalCores',
    coal = 'fuel', water = 'water', components = 'components',
    steel = 'steel', circuit = 'circuit',
    -- Intermediate processed materials
    metal_ingot = 'metal', lumber = 'wood', cut_stone = 'cut_stone',
    leather = 'hide', cloth = 'cloth', insulation = 'insulation',
    pipe = 'pipe', glass = 'glass', charcoal = 'charcoal',
    medicinal_herb = 'medicinal_herb',
    -- Corpses & dark processing
    corpse_creature = 'corpse_creature', corpse_human = 'corpse_human',
    human_meat = 'human_meat', human_leather = 'human_leather',
    -- Drug crop materials
    psychoid_leaf = 'psychoid_leaf', smokeleaf_leaf = 'smokeleaf_leaf', hops = 'hops',
    -- Organs
    organ_heart = 'organ_heart', organ_lung = 'organ_lung',
    organ_kidney = 'organ_kidney', organ_liver = 'organ_liver', organ_eye = 'organ_eye',
    -- Prosthetics
    peg_leg = 'peg_leg', wooden_arm = 'wooden_arm',
    prosthetic_leg = 'prosthetic_leg', prosthetic_arm = 'prosthetic_arm',
    bionic_leg = 'bionic_leg', bionic_arm = 'bionic_arm', bionic_eye = 'bionic_eye',
    -- Drugs (input for recipes that consume drugs, e.g. Surge needs Spike)
    spike = 'spike', stardust = 'stardust', drift = 'drift', smog = 'smog',
    rotgut = 'rotgut', shards = 'shards', glimpse = 'glimpse', surge = 'surge', thaw = 'thaw',
    voidbloom = 'voidbloom',
    -- Medical
    bandage = 'bandage', medicine = 'medicine', revivify_serum = 'revivify_serum',
    -- Eldritch
    eldritch_ichor = 'eldritch_ichor', raw_fat = 'raw_fat',
    chitin_plate = 'chitin_plate', void_crystal = 'void_crystal',
    raw_fur = 'raw_fur', caustic_liquid = 'caustic_liquid',
    serpent_venom = 'serpent_venom', fang = 'fang',
    -- Ammo (as recipe inputs for fire arrows, etc.)
    ammo_arrow = 'ammo_arrow', ammo_fire_arrow = 'ammo_fire_arrow',
    ammo_bolt = 'ammo_bolt', ammo_bullet = 'ammo_bullet',
    ammo_shell = 'ammo_shell', ammo_rocket = 'ammo_rocket',
    ammo_mortar_shell = 'ammo_mortar_shell', ammo_thermal = 'ammo_thermal',
    -- Thermal weapons
    weapon_thermal_lance = 'weapon_thermal_lance',
    weapon_thermal_blade = 'weapon_thermal_blade',
    cryo_grenade = 'cryo_grenade',
    napalm_fuel = 'napalm_fuel', foam_canister = 'foam_canister',
    gas_canister = 'gas_canister', acid_canister = 'acid_canister', poison_darts = 'poison_darts',
    -- Throwables
    grenade = 'grenade', ied = 'ied', molotov = 'molotov', pipe_bomb = 'pipe_bomb',
    -- Ordnance
    placed_charge = 'placed_charge', timed_bomb = 'timed_bomb', tripwire_bomb = 'tripwire_bomb',
    napalm_grenade = 'napalm_grenade', napalm_bomb = 'napalm_bomb',
    bio_grenade = 'bio_grenade', bio_bomb = 'bio_bomb',
    foam_grenade = 'foam_grenade', foam_bomb = 'foam_bomb',
    c4_charge = 'c4_charge', emp_charge = 'emp_charge', emp_grenade = 'emp_grenade',
    briefcase_nuke = 'briefcase_nuke', nuclear_core = 'nuclear_core',
    -- Missiles
    missile_he = 'missile_he', missile_napalm = 'missile_napalm',
    missile_bio = 'missile_bio', missile_foam = 'missile_foam',
    missile_bunker = 'missile_bunker', missile_nuke = 'missile_nuke',
    -- Physical item IDs (inputs to processing recipes)
    iron_ore = 'metal', copper_ore = 'metal', uranium_ore = 'metal',
    stone_chunk = 'stone', logs = 'wood', ice_block = 'stone',
    iron_ingot = 'metal', lead_ingot = 'lead', copper_ingot = 'metal',
    -- Lead: was only present in the production_runtime duplicate of this table
    lead = 'lead', lead_ore = 'lead',
    fuel = 'fuel',
}

local DRUG_EFFECTS = {
    spike = {
        name = 'Spike',
        duration = 90,
        effects = {
            workSpeedBuff = 0.40,
            restDrain = 0.15,
        },
    },
    stardust = {
        name = 'Stardust',
        duration = 45,
        effects = {
            workSpeedBuff = 0.25,
            morale = 25,
            restDrain = 0.08,
        },
    },
    drift = {
        name = 'Drift',
        duration = 120,
        effects = {
            morale = 20,
            painReduce = 0.5,
            healthRegen = 0.3,
        },
    },
    smog = {
        name = 'Smog',
        duration = 180,
        effects = {
            morale = 15,
            workSpeedBuff = -0.20,
        },
    },
    rotgut = {
        name = 'Rotgut',
        duration = 150,
        effects = {
            morale = 12,
            workSpeedBuff = -0.15,
            socialBuff = 0.2,
        },
    },
    shards = {
        name = 'Shards',
        duration = 240,
        effects = {
            morale = 35,
            workSpeedBuff = -0.40,
            sanityDrain = 5,
        },
    },
    glimpse = {
        name = 'Glimpse',
        duration = 60,
        effects = {
            morale = 50,
            workSpeedBuff = -0.60,
            sanityDrain = 15,
        },
    },
    surge = {
        name = 'Surge',
        duration = 60,
        effects = {
            workSpeedBuff = 0.20,
            damageBuff = 0.50,
            morale = -10,
            restDrain = 0.20,
        },
    },
    thaw = {
        name = 'Thaw',
        duration = 300,
        effects = {
            warmth = 40,
            coldResistBuff = 0.3,
        },
    },
    serpent_venom = {
        name = 'Raw Venom (huffed)',
        duration = 90,
        effects = {
            morale = 30,
            workSpeedBuff = -0.25,
            sanityDrain = 3,
        },
    },
    fang = {
        name = 'Fang',
        duration = 180,
        effects = {
            morale = 55,
            workSpeedBuff = -0.35,
            socialBuff = 0.3,
            sanityDrain = 8,
            restDrain = 0.10,
        },
    },
    voidbloom = {
        name = 'Voidbloom',
        duration = 200,
        effects = {
            morale = 30,
            painReduce = 0.3,
            warmth = 15,
            sanityDrain = 10,
            workSpeedBuff = -0.30,
        },
    },
    berserker = {
        name = 'Berserker',
        duration = 45,
        effects = {
            damageBuff = 1.0,
            armorBuff = 0.30,
            morale = -20,
            painReduce = 0.8,
            restDrain = 0.30,
            workSpeedBuff = -0.50,
        },
    },
    stim = {
        name = 'Stim',
        duration = 90,
        effects = {
            workSpeedBuff = 0.15,
            damageBuff = 0.25,
            morale = 5,
            painReduce = 0.3,
            restDrain = 0.12,
        },
    },
}

---------------------------------------------------------------------------
-- Food quality tiers (affects morale when eaten)
---------------------------------------------------------------------------

local FOOD_QUALITY = {
    -- Raw (edible but unpleasant)
    raw_meat    = { nutrition = 15, morale = -10, quality = 'raw' },
    berries     = { nutrition = 10, morale = -3,  quality = 'raw' },
    mushrooms   = { nutrition = 8,  morale = -5,  quality = 'raw' },
    -- Simple (cooked, no penalty)
    cooked_meat = { nutrition = 25, morale = 0,   quality = 'simple' },
    bread       = { nutrition = 20, morale = 3,   quality = 'simple' },
    -- Fine (skilled cooking, morale boost)
    stew        = { nutrition = 35, morale = 5,   quality = 'fine' },
    -- Preserved (long shelf life, travel food)
    jerky       = { nutrition = 20, morale = 0,   quality = 'preserved' },
    ration      = { nutrition = 30, morale = -5,  quality = 'preserved' },
    -- Lavish (expensive, big morale)
    feast       = { nutrition = 50, morale = 20,  quality = 'lavish' },
    -- Forbidden
    human_meat  = { nutrition = 20, morale = -40, quality = 'forbidden' },
}

ProductionDefs.ITEMS = ITEMS
ProductionDefs.RECIPES = RECIPES
ProductionDefs.MACHINES = MACHINES
ProductionDefs.ITEM_TO_RES = ITEM_TO_RES
ProductionDefs.DRUG_EFFECTS = DRUG_EFFECTS
ProductionDefs.FOOD_QUALITY = FOOD_QUALITY

return ProductionDefs

