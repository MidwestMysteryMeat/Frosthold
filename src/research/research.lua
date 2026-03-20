-- research.lua — Colony-wide research tree (6 tiers)
-- Research is colony-wide, not per-colonist. Colonists operating research
-- benches generate research points that accumulate here.
-- Completing a node unlocks recipes, buildings, or equipment.
-- Prerequisites form a DAG — a node requires all listed prereqs to be done.

local GameState  = require('src.game_state')

local Research = {}

---------------------------------------------------------------------------
-- Research node definitions — 6 tiers
---------------------------------------------------------------------------

local NODES = {
    ----------- Tier 1 — Fundamentals (no prerequisites) -----------
    basic_construction = {
        id     = 'basic_construction',
        name   = 'Basic Construction',
        tier   = 1,
        cost   = 50,
        prereqs = {},
        unlocks = { recipes = { 'saw_lumber', 'cut_stone', 'make_charcoal' } },
        desc   = 'Unlocks sawmill, stonecutter, and charcoal kiln recipes. Foundation of all building.',
    },
    basic_survival = {
        id     = 'basic_survival',
        name   = 'Basic Survival',
        tier   = 1,
        cost   = 40,
        prereqs = {},
        unlocks = { recipes = { 'cook_meat', 'melt_ice', 'craft_bandage', 'make_bread' }, buildings = { 'melter' } },
        desc   = 'Unlocks basic cooking, ice melting, bread, and bandage crafting. Keep your people alive.',
    },
    basic_textiles = {
        id     = 'basic_textiles',
        name   = 'Basic Textiles',
        tier   = 1,
        cost   = 45,
        prereqs = {},
        unlocks = { recipes = { 'tan_leather', 'weave_cloth' } },
        desc   = 'Unlocks tannery and loom operations. Raw materials into workable fabric and hide.',
    },
    basic_smelting = {
        id     = 'basic_smelting',
        name   = 'Basic Smelting',
        tier   = 1,
        cost   = 60,
        prereqs = {},
        unlocks = { recipes = { 'smelt_ore' }, buildings = { 'smelter' } },
        desc   = 'Unlocks the smelter and ore processing. Everything else needs metal.',
    },
    basic_tools = {
        id     = 'basic_tools',
        name   = 'Basic Toolcraft',
        tier   = 1,
        cost   = 55,
        prereqs = {},
        unlocks = { recipes = { 'craft_axe', 'craft_spear' } },
        desc   = 'Unlocks ice axe and hunting spear. Arms your colonists for survival.',
    },

    -- Tier 2 — Intermediate (require 1-2 Tier 1)
    advanced_materials = {
        id     = 'advanced_materials',
        name   = 'Advanced Materials',
        tier   = 2,
        cost   = 120,
        prereqs = { 'basic_construction', 'basic_smelting' },
        unlocks = { recipes = { 'forge_steel', 'craft_components', 'craft_pipe', 'craft_glass', 'forge_plasteel' }, buildings = { 'forge' } },
        desc   = 'Unlocks the forge, steel, plasteel, components, pipes, and glass.',
    },
    thermal_tech = {
        id     = 'thermal_tech',
        name   = 'Thermal Technology',
        tier   = 2,
        cost   = 100,
        prereqs = { 'basic_smelting' },
        unlocks = { buildings = { 'coal_burner', 'thermal_gen' } },
        desc   = 'Unlocks coal burner and thermal generator. Reliable heat and power for sealed rooms.',
    },
    field_medicine = {
        id     = 'field_medicine',
        name   = 'Field Medicine',
        tier   = 2,
        cost   = 90,
        prereqs = { 'basic_survival', 'basic_textiles' },
        unlocks = { recipes = { 'craft_medicine' }, buildings = { 'med_bench' } },
        desc   = 'Unlocks medicine crafting and the medical bench. Infection is now treatable.',
    },
    food_preservation = {
        id     = 'food_preservation',
        name   = 'Food Preservation',
        tier   = 2,
        cost   = 80,
        prereqs = { 'basic_survival' },
        unlocks = { recipes = { 'make_jerky', 'make_stew', 'pack_rations' }, buildings = { 'smokehouse' } },
        desc   = 'Unlocks the smokehouse, jerky, stew, and ration packs. Your food supply lasts longer.',
    },
    cold_gear = {
        id     = 'cold_gear',
        name   = 'Cold Weather Gear',
        tier   = 2,
        cost   = 85,
        prereqs = { 'basic_textiles' },
        unlocks = { recipes = { 'craft_insulation', 'craft_boots', 'craft_parka' } },
        desc   = 'Unlocks insulation crafting, parkas, and insulated boots. Colonists can survive outside.',
    },

    water_vehicles = {
        id     = 'water_vehicles',
        name   = 'Water Vehicles',
        tier   = 2,
        cost   = 80,
        prereqs = { 'basic_construction' },
        unlocks = { buildings = { 'rowboat', 'fishing_boat', 'cargo_barge', 'floating_platform', 'water_pump_station', 'seawall' } },
        desc   = 'Unlocks boats, barges, and water structures. Rafts are available without research.',
    },

    -- Tier 3 — Advanced (require Tier 2)
    automation = {
        id     = 'automation',
        name   = 'Automation',
        tier   = 3,
        cost   = 200,
        prereqs = { 'advanced_materials' },
        unlocks = { buildings = { 'basic_inserter', 'conveyor', 'storage_chest' } },
        desc   = 'Unlocks conveyor belts, inserters, and storage chests. Machines feed machines.',
    },
    circuitry = {
        id     = 'circuitry',
        name   = 'Circuitry',
        tier   = 3,
        cost   = 180,
        prereqs = { 'advanced_materials' },
        unlocks = { recipes = { 'craft_circuit' } },
        desc   = 'Unlocks circuit board fabrication. Required for advanced machines and weapons.',
    },
    pharmacology = {
        id     = 'pharmacology',
        name   = 'Pharmacology',
        tier   = 3,
        cost   = 160,
        prereqs = { 'field_medicine' },
        unlocks = { recipes = { 'cook_spike', 'cut_stardust', 'brew_drift', 'roll_smog', 'drop_shards', 'cook_glimpse', 'brew_surge', 'brew_thaw', 'brew_rotgut' }, buildings = { 'drug_lab' } },
        desc   = 'Unlocks the drug lab and all pharmaceutical recipes. Side effects vary.',
    },
    fluid_systems = {
        id     = 'fluid_systems',
        name   = 'Fluid Systems',
        tier   = 3,
        cost   = 150,
        prereqs = { 'advanced_materials', 'thermal_tech' },
        unlocks = { buildings = { 'small_pipe', 'water_pump', 'small_duct', 'fluid_tank_small', 'gas_canister' } },
        desc   = 'Unlocks basic pipe networks, water pumps, ducts, and small storage tanks.',
    },
    deep_drilling = {
        id     = 'deep_drilling',
        name   = 'Deep Drilling',
        tier   = 3,
        cost   = 170,
        prereqs = { 'advanced_materials' },
        unlocks = { buildings = { 'deep_drill' } },
        desc   = 'Unlocks deep drill excavators. Access ore veins beneath permafrost.',
    },
    feast_cooking = {
        id     = 'feast_cooking',
        name   = 'Feast Preparation',
        tier   = 3,
        cost   = 110,
        prereqs = { 'food_preservation' },
        unlocks = { recipes = { 'prepare_feast' } },
        desc   = 'Unlocks lavish feast preparation. Massive morale boost for the whole colony.',
    },

    -- Tier 4 — High-tech (require Tier 3)
    fast_logistics = {
        id     = 'fast_logistics',
        name   = 'Fast Logistics',
        tier   = 4,
        cost   = 280,
        prereqs = { 'automation', 'circuitry' },
        unlocks = { buildings = { 'fast_inserter', 'splitter', 'steel_chest' } },
        desc   = 'Unlocks fast inserters, splitters, and steel chests. Throughput doubles.',
    },
    precision_filters = {
        id     = 'precision_filters',
        name   = 'Precision Filters',
        tier   = 4,
        cost   = 250,
        prereqs = { 'fast_logistics' },
        unlocks = { buildings = { 'filter_inserter' } },
        desc   = 'Unlocks filter inserters. Route specific items to specific machines.',
    },
    advanced_weapons = {
        id     = 'advanced_weapons',
        name   = 'Advanced Weaponry',
        tier   = 4,
        cost   = 300,
        prereqs = { 'circuitry', 'basic_tools' },
        unlocks = { recipes = { 'craft_bolt_action', 'craft_assault_rifle', 'craft_battle_rifle' } },
        desc   = 'Unlocks military-grade firearms. Lethal at range against megafauna.',
    },
    fuel_synthesis = {
        id     = 'fuel_synthesis',
        name   = 'Fuel Synthesis',
        tier   = 4,
        cost   = 260,
        prereqs = { 'fluid_systems', 'circuitry' },
        unlocks = { recipes = { 'refine_fuel' }, buildings = { 'refinery' } },
        desc   = 'Unlocks the refinery and fuel cell production. High-density portable energy.',
    },
    advanced_plumbing = {
        id     = 'advanced_plumbing',
        name   = 'Advanced Plumbing',
        tier   = 4,
        cost   = 250,
        prereqs = { 'fluid_systems', 'circuitry' },
        unlocks = { buildings = { 'large_pipe', 'insulated_pipe', 'large_duct', 'sealed_duct', 'fluid_tank_large', 'pressurized_tank', 'oil_refinery', 'coolant_refiner', 'waste_processor', 'gas_separator' } },
        desc   = 'Unlocks large and insulated pipes, sealed ducts, large tanks, and fluid processors.',
    },
    combat_drugs = {
        id     = 'combat_drugs',
        name   = 'Combat Pharmaceuticals',
        tier   = 4,
        cost   = 220,
        prereqs = { 'pharmacology' },
        unlocks = { recipes = { 'brew_berserker', 'brew_stim' } },
        desc   = 'Unlocks field combat chems. Keep your people standing when they shouldn\'t be.',
    },

    revival_biochem = {
        id     = 'revival_biochem',
        name   = 'Revival Biochemistry',
        tier   = 4,
        cost   = 280,
        prereqs = { 'pharmacology', 'field_medicine' },
        unlocks = { recipes = { 'brew_revivify' } },
        desc   = 'Unlocks revivify serum synthesis. One chance to bring someone back.',
    },
    ship_repair = {
        id     = 'ship_repair',
        name   = 'Ship Repair Systems',
        tier   = 4,
        cost   = 200,
        prereqs = { 'advanced_materials' },
        unlocks = { buildings = { 'ship_workshop' } },
        desc   = 'Unlocks the ship workshop module. Hull patch kits and EVA repair capability.',
    },
    space_suit_engineering = {
        id     = 'space_suit_engineering',
        name   = 'Space Suit Engineering',
        tier   = 4,
        cost   = 180,
        prereqs = { 'advanced_materials' },
        unlocks = {},
        desc   = 'Unlocks basic, reinforced, and combat space suit crafting.',
    },
    shipboard_weapons = {
        id     = 'shipboard_weapons',
        name   = 'Shipboard Weapons',
        tier   = 4,
        cost   = 220,
        prereqs = { 'advanced_weapons' },
        unlocks = { buildings = { 'weapon_mount', 'ship_laser', 'missile_launcher', 'point_defense' } },
        desc   = 'Unlocks laser batteries, missile launchers, and point defense for ships.',
    },
    advanced_shipboard_weapons = {
        id     = 'advanced_shipboard_weapons',
        name   = 'Advanced Ship Weapons',
        tier   = 5,
        cost   = 350,
        prereqs = { 'shipboard_weapons' },
        unlocks = { buildings = { 'railgun', 'heavy_warhead_launcher', 'emp_missile_launcher' } },
        desc   = 'Unlocks railguns, heavy warheads, and EMP missiles. Devastate enemy systems at range.',
    },
    electronic_warfare = {
        id     = 'electronic_warfare',
        name   = 'Electronic Warfare',
        tier   = 5,
        cost   = 300,
        prereqs = { 'shipboard_weapons', 'stealth_technology' },
        unlocks = { buildings = { 'emp_mine_launcher', 'emp_field_generator' } },
        desc   = 'Unlocks EMP mines and field generators. Disable electronics in an area — including your own.',
    },
    nanite_weapons = {
        id     = 'nanite_weapons',
        name   = 'Nanite Weapons',
        tier   = 6,
        cost   = 600,
        prereqs = { 'advanced_shipboard_weapons', 'electronic_warfare' },
        unlocks = { buildings = { 'nano_dump_launcher' } },
        desc   = 'Unlocks the nano dump launcher. Hostile nanomachine clouds shred ship modules, ignoring shields.',
    },

    -- Tier 5 — Endgame (require Tier 4)
    expedition_prep = {
        id     = 'expedition_prep',
        name   = 'Expedition Preparation',
        tier   = 5,
        cost   = 400,
        prereqs = { 'fuel_synthesis', 'cold_gear', 'advanced_weapons' },
        unlocks = { buildings = { 'expedition_table' } },
        desc   = 'Unlocks the expedition planning table. Send teams into the field to scout ruins and resources.',
    },
    lava_tap_mastery = {
        id     = 'lava_tap_mastery',
        name   = 'Lava Vent Exploitation',
        tier   = 5,
        cost   = 350,
        prereqs = { 'deep_drilling', 'thermal_tech' },
        unlocks = { buildings = { 'lava_tap' } },
        desc   = 'Unlocks lava vent tap generators. 100W free power with no fuel cost.',
    },
    pollution_control = {
        id     = 'pollution_control',
        name   = 'Pollution Control',
        tier   = 5,
        cost   = 320,
        prereqs = { 'fluid_systems', 'pharmacology' },
        unlocks = { buildings = { 'scrubber' } },
        desc   = 'Unlocks pollution scrubber buildings. Lowers pollution-triggered raid chance.',
    },
    full_automation = {
        id     = 'full_automation',
        name   = 'Full Automation',
        tier   = 5,
        cost   = 500,
        prereqs = { 'fast_logistics', 'precision_filters', 'fuel_synthesis' },
        unlocks = { equipment = { 'auto_crafter' } },
        desc   = 'Unlocks auto-crafter module. Machines operate at full speed without a colonist assigned.',
    },
    cryogenic_stasis = {
        id     = 'cryogenic_stasis',
        name   = 'Cryogenic Stasis',
        tier   = 5,
        cost   = 450,
        prereqs = { 'fuel_synthesis', 'pharmacology' },
        unlocks = { buildings = { 'cryo_pod' } },
        desc   = 'Unlocks cryo pods. Suspend injured colonists indefinitely until medicine is available.',
    },

    exotic_fluids = {
        id     = 'exotic_fluids',
        name   = 'Exotic Fluid Processing',
        tier   = 5,
        cost   = 380,
        prereqs = { 'advanced_plumbing' },
        unlocks = { buildings = { 'steam_boiler', 'ichor_converter' } },
        desc   = 'Unlocks steam generation from heat and ichor processing.',
    },

    -- Phase 12: New system research nodes
    agriculture = {
        id     = 'agriculture',
        name   = 'Agriculture',
        tier   = 2,
        cost   = 100,
        prereqs = { 'basic_survival' },
        unlocks = { buildings = { 'greenhouse', 'farm_plot', 'sun_lamp' } },
        desc   = 'Unlocks greenhouses, farm plots, and sun lamps for indoor growing.',
    },
    conditional_circuits = {
        id     = 'conditional_circuits',
        name   = 'Conditional Circuits',
        tier   = 3,
        cost   = 200,
        prereqs = { 'circuitry' },
        unlocks = { buildings = { 'circuit_sensor', 'circuit_comparator', 'circuit_actuator' } },
        desc   = 'Unlocks sensor/logic/actuator chains. Automate doors, heaters, and alarms based on conditions.',
        archived = true,
    },
    vehicle_construction = {
        id     = 'vehicle_construction',
        name   = 'Vehicle Construction (Legacy)',
        tier   = 3,
        cost   = 180,
        prereqs = { 'advanced_materials' },
        unlocks = { buildings = { 'vehicle_workbench' } },
        desc   = 'Archived cut-scope research retained only for compatibility with older saves.',
        archived = true,
    },
    megabeast_research = {
        id     = 'megabeast_research',
        name   = 'Megafauna Studies',
        tier   = 4,
        cost   = 250,
        prereqs = { 'deep_drilling' },
        unlocks = {},
        desc   = 'Unlocks megafauna autopsy data. Reveals creature weak points.',
    },

    -- Terraforming research
    terraforming = {
        id     = 'terraforming',
        name   = 'Terraforming',
        tier   = 2,
        cost   = 120,
        prereqs = { 'basic_construction' },
        unlocks = { terraform = { 'smooth', 'clear', 'excavate_rock', 'excavate_permafrost', 'drain' } },
        desc   = 'Unlocks terrain modification. Smooth debris, clear ground, excavate rock, drain water.',
    },
    underground_construction = {
        id     = 'underground_construction',
        name   = 'Underground Construction',
        tier   = 3,
        cost   = 200,
        prereqs = { 'terraforming', 'advanced_materials' },
        unlocks = { terraform = { 'dig_shaft', 'excavate_deep_rock', 'excavate_underground_rock' }, buildings = { 'sump_pump', 'wood_column' } },
        desc   = 'Unlocks shaft digging, deep excavation, and wood support columns. Build underground rooms with geothermal insulation.',
    },
    structural_engineering = {
        id     = 'structural_engineering',
        name   = 'Structural Engineering',
        tier   = 3,
        cost   = 150,
        prereqs = { 'underground_construction' },
        unlocks = { buildings = { 'support_column' } },
        desc   = 'Stone columns. No degradation, wider support radius. Extends safe excavation span by 6 tiles.',
    },
    advanced_structural = {
        id     = 'advanced_structural',
        name   = 'Advanced Structural Support',
        tier   = 4,
        cost   = 250,
        prereqs = { 'structural_engineering', 'advanced_materials' },
        unlocks = { buildings = { 'reinforced_column' } },
        desc   = 'Reinforced columns. Maximum support radius, extends safe span by 12 tiles. Massive underground halls.',
    },

    -- Defense research
    basic_defenses = {
        id     = 'basic_defenses',
        name   = 'Basic Defenses',
        tier   = 2,
        cost   = 80,
        prereqs = { 'basic_survival' },
        unlocks = { buildings = { 'sandbag', 'spike_trap', 'turret_ballista', 'turret_crossbow', 'pit_trap', 'snare_trap', 'barbed_fence_trap', 'bait_lure_trap' } },
        desc   = 'Unlocks sandbags, spike traps, ballista, crossbow turrets, pit traps, snares, barbed fences, and bait lures.',
    },
    advanced_defenses = {
        id     = 'advanced_defenses',
        name   = 'Advanced Defenses',
        tier   = 3,
        cost   = 180,
        prereqs = { 'basic_defenses', 'circuitry' },
        unlocks = { buildings = { 'turret_gun', 'turret_minigun', 'turret_shotgun', 'barricade', 'steel_barrier', 'deadfall_trap', 'bear_trap', 'razor_wire', 'spring_blade', 'watchtower', 'pressure_plate_trap', 'chain_mine_trap', 'directional_mine_trap' } },
        desc   = 'Unlocks gun turrets, minigun, shotgun turrets, metal barricades, steel barriers, bear traps, razor wire, spring blades, watchtowers, pressure plates, chain mines, and directional mines.',
    },
    heavy_ordnance = {
        id     = 'heavy_ordnance',
        name   = 'Heavy Ordnance',
        tier   = 4,
        cost   = 280,
        prereqs = { 'advanced_defenses', 'advanced_weapons' },
        unlocks = {
            buildings = { 'turret_laser', 'turret_tesla', 'turret_flamethrower', 'turret_cryo', 'turret_rocket', 'mortar', 'incendiary_trap', 'frag_mine', 'emp_mine', 'acid_trap', 'gas_trap', 'bunker', 'emp_floor_mine', 'concussion_mine_trap' },
            recipes = { 'craft_emp_grenade', 'craft_emp_charge' },
        },
        desc   = 'Unlocks laser, tesla, flamethrower, cryo, and rocket turrets. EMP grenades and charges. Mortars, mines, acid and gas traps, bunkers.',
    },

    experimental_defenses = {
        id     = 'experimental_defenses',
        name   = 'Experimental Defenses',
        tier   = 5,
        cost   = 400,
        prereqs = { 'heavy_ordnance' },
        unlocks = { buildings = { 'turret_railgun', 'turret_emp', 'cryo_mine', 'shield_generator', 'thermobaric_trap_building', 'sinkhole_charge_trap', 'nuclear_mine_trap' } },
        desc   = 'Unlocks railgun turrets, EMP cannons, cryo mines, shield generators, thermobaric traps, sinkhole charges, and nuclear mines.',
    },

    -- Advanced medicine (prereq for biological warfare)
    advanced_medicine = {
        id     = 'advanced_medicine',
        name   = 'Advanced Medicine',
        tier   = 3,
        cost   = 180,
        prereqs = { 'field_medicine', 'circuitry' },
        unlocks = { recipes = { 'craft_advanced_medicine' }, buildings = { 'surgery_table' } },
        desc   = 'Unlocks advanced medicine production and the surgery table. Treat severe injuries and infections.',
    },

    -- Chemical warfare
    chemical_warfare = {
        id     = 'chemical_warfare',
        name   = 'Chemical Warfare',
        tier   = 3,
        cost   = 200,
        prereqs = { 'advanced_defenses' },
        unlocks = {
            buildings = { 'turret_gas', 'turret_acid', 'turret_poison' },
            recipes = { 'craft_gas_canister', 'craft_acid_canister', 'craft_poison_darts' },
        },
        desc   = 'Unlocks gas, acid, and poison turrets. Craft chemical ammo at a workbench.',
    },

    -- Energy barriers
    energy_barriers = {
        id     = 'energy_barriers',
        name   = 'Energy Barriers',
        tier   = 4,
        cost   = 300,
        prereqs = { 'heavy_ordnance', 'circuitry' },
        unlocks = {
            buildings = { 'laser_gate', 'laser_fence', 'electrified_wall', 'motion_sensor' },
        },
        desc   = 'Unlocks laser gates, laser fences, electrified walls, and motion sensors.',
    },
    advanced_barriers = {
        id     = 'advanced_barriers',
        name   = 'Advanced Barriers',
        tier   = 5,
        cost   = 400,
        prereqs = { 'energy_barriers', 'experimental_defenses' },
        unlocks = {
            buildings = { 'laser_grid', 'shield_curtain', 'seismic_sensor' },
        },
        desc   = 'Unlocks laser grids, shield curtains, and seismic sensors.',
    },

    -- Ordnance research tree
    field_explosives = {
        id     = 'field_explosives',
        name   = 'Field Explosives',
        tier   = 2,
        cost   = 150,
        prereqs = { 'basic_defenses' },
        unlocks = {
            recipes = { 'craft_placed_charge', 'craft_timed_bomb', 'craft_tripwire_bomb', 'craft_c4' },
        },
        desc   = 'Unlocks placed charges, timed bombs, tripwire bombs, and C4 for field use.',
    },
    fire_suppression = {
        id     = 'fire_suppression',
        name   = 'Fire Suppression',
        tier   = 2,
        cost   = 120,
        prereqs = { 'basic_defenses' },
        unlocks = {
            recipes = { 'craft_foam_grenade', 'craft_foam_bomb', 'craft_foam_canister' },
            buildings = { 'turret_foam_nozzle', 'foam_trap' },
        },
        desc   = 'Unlocks foam grenades, foam bombs, foam canisters, and foam nozzle turrets.',
    },
    incendiary_weapons = {
        id     = 'incendiary_weapons',
        name   = 'Incendiary Weapons',
        tier   = 3,
        cost   = 200,
        prereqs = { 'field_explosives', 'fuel_synthesis' },
        unlocks = {
            recipes = { 'craft_napalm_grenade', 'craft_napalm_bomb', 'craft_napalm_fuel' },
            buildings = { 'turret_napalm_sprayer', 'napalm_tripwire_trap' },
        },
        desc   = 'Unlocks napalm grenades, napalm bombs, napalm fuel, and napalm sprayer turrets.',
    },
    biological_warfare = {
        id     = 'biological_warfare',
        name   = 'Biological Warfare',
        tier   = 4,
        cost   = 300,
        prereqs = { 'field_explosives', 'advanced_medicine' },
        unlocks = {
            recipes = { 'craft_bio_grenade', 'craft_bio_bomb' },
            buildings = { 'bio_mine_trap' },
        },
        desc   = 'Unlocks biological grenades, bombs, and bio mines that disperse pathogens.',
    },
    missile_systems = {
        id     = 'missile_systems',
        name   = 'Missile Systems',
        tier   = 4,
        cost   = 350,
        prereqs = { 'heavy_ordnance' },
        unlocks = {
            recipes = { 'assemble_missile_he', 'assemble_missile_napalm', 'assemble_missile_foam' },
            buildings = { 'rocket_pod', 'missile_battery', 'sam_launcher', 'missile_silo' },
        },
        desc   = 'Unlocks rocket pods, guided missile batteries, SAM launchers, and the missile silo foundry.',
    },
    advanced_warheads = {
        id     = 'advanced_warheads',
        name   = 'Advanced Warheads',
        tier   = 5,
        cost   = 450,
        prereqs = { 'missile_systems', 'biological_warfare' },
        unlocks = {
            recipes = { 'assemble_missile_bio', 'assemble_missile_bunker', 'craft_nuclear_core', 'assemble_missile_nuke', 'craft_briefcase_nuke' },
        },
        desc   = 'Unlocks biological missiles, bunker busters, nuclear cores, mini nukes, and briefcase nukes.',
    },

    -- Power research
    renewable_energy = {
        id     = 'renewable_energy',
        name   = 'Renewable Energy',
        tier   = 2,
        cost   = 120,
        prereqs = { 'basic_survival' },
        unlocks = { buildings = { 'solar_panel', 'wind_turbine', 'lightning_rod', 'thermopile' } },
        desc   = 'Unlocks solar panels, wind turbines, lightning rods, and thermopiles. Intermittent but clean.',
    },
    combustion_engines = {
        id     = 'combustion_engines',
        name   = 'Combustion Engines',
        tier   = 2,
        cost   = 100,
        prereqs = { 'basic_survival' },
        unlocks = { buildings = { 'coal_burner', 'gas_burner', 'fire_pit', 'deep_fire_pit', 'hand_crank' } },
        desc   = 'Unlocks combustion generators and hand cranks. CO2 or muscle. Your choice.',
    },
    advanced_power = {
        id     = 'advanced_power',
        name   = 'Advanced Power',
        tier   = 3,
        cost   = 200,
        prereqs = { 'combustion_engines', 'circuitry' },
        unlocks = { buildings = { 'bio_reactor', 'chemical_burner', 'waste_incinerator', 'steam_turbine', 'treadmill', 'chain_gang_wheel' } },
        desc   = 'Unlocks bio reactors, chemical burners, waste incinerators, steam turbines, treadmills, and chain gang wheels.',
    },
    compact_reactors = {
        id     = 'compact_reactors',
        name   = 'Compact Reactors',
        tier   = 4,
        cost   = 350,
        prereqs = { 'advanced_power' },
        unlocks = { buildings = { 'mini_reactor', 'hydrogen_cell' } },
        desc   = 'Unlocks mini nuclear reactors and hydrogen fuel cells. High output, manageable risk.',
    },
    nuclear_power = {
        id     = 'nuclear_power',
        name   = 'Nuclear Power',
        tier   = 5,
        cost   = 500,
        prereqs = { 'compact_reactors', 'deep_drilling' },
        unlocks = { buildings = { 'nuclear_reactor' } },
        desc   = 'Unlocks the nuclear reactor. 250W output. Meltdown risk if faulted. Handle with care.',
    },
    geothermal_power = {
        id     = 'geothermal_power',
        name   = 'Geothermal Power',
        tier   = 4,
        cost   = 300,
        prereqs = { 'advanced_power', 'deep_drilling' },
        unlocks = { buildings = { 'geothermal' } },
        desc   = 'Unlocks geothermal vents. 120W clean output from the planet itself.',
    },
    thermal_weaponry = {
        id     = 'thermal_weaponry',
        name   = 'Thermal Weaponry',
        tier   = 4,
        cost   = 250,
        prereqs = { 'thermal_tech', 'advanced_materials' },
        unlocks = { recipes = { 'craft_thermal_blade', 'craft_thermal_lance', 'craft_cryo_grenade', 'craft_thermal_ammo' }, buildings = { 'turret_heat_drain' } },
        desc   = 'Unlocks thermal blades, lances, cryo grenades, and heat-drain turrets.',
    },
    thermal_synthesis = {
        id     = 'thermal_synthesis',
        name   = 'Thermal Core Synthesis',
        tier   = 4,
        cost   = 280,
        prereqs = { 'thermal_tech', 'advanced_materials' },
        unlocks = { recipes = { 'synthesize_thermal_core' } },
        desc   = 'Unlocks thermal core fabrication. Craft cores from raw metals and fuel instead of scavenging.',
    },

    -- Endgame research (tier 5 — victory paths)
    mammona_uplink = {
        id     = 'mammona_uplink',
        name   = 'Mammona Uplink Protocol',
        tier   = 5,
        cost   = 600,
        prereqs = { 'full_automation', 'nuclear_power' },
        unlocks = { buildings = { 'transmission_array' } },
        desc   = 'Unlocks the transmission array. Declare the colony viable enough for Mammona to secure the claim openly.',
    },
    shuttle_engineering = {
        id     = 'shuttle_engineering',
        name   = 'Shuttle Engineering',
        tier   = 5,
        cost   = 700,
        prereqs = { 'fuel_synthesis', 'full_automation' },
        unlocks = { buildings = { 'launch_pad', 'shipyard' } },
        desc   = 'Unlocks the shipyard. Build a colony ship and leave this world behind.',
    },
    precursor_sealing = {
        id     = 'precursor_sealing',
        name   = 'Precursor Sealing Tech',
        tier   = 5,
        cost   = 550,
        prereqs = { 'expedition_prep', 'exotic_fluids' },
        unlocks = { buildings = { 'sealing_apparatus' } },
        desc   = 'Unlocks the sealing apparatus. Reconstruct the mechanism that kept Erebus dormant.',
    },
    mammona_extraction = {
        id     = 'mammona_extraction',
        name   = 'Mammona Extraction Protocol',
        tier   = 5,
        cost   = 500,
        prereqs = { 'mammona_uplink', 'thermal_synthesis' },
        unlocks = { buildings = { 'extraction_beacon' } },
        desc   = 'Unlocks the extraction beacon. Defeat That Which Sleeps, then call Mammona for the corporate extraction ending.',
    },
    shield_systems = {
        id     = 'shield_systems',
        name   = 'Shield Systems',
        tier   = 5,
        cost   = 350,
        prereqs = { 'shipboard_weapons' },
        unlocks = { buildings = { 'shield_generator' } },
        desc   = 'Unlocks shield generator modules for ships. Energy barriers absorb incoming fire.',
    },
    stealth_technology = {
        id     = 'stealth_technology',
        name   = 'Stealth Technology',
        tier   = 5,
        cost   = 300,
        prereqs = { 'ship_repair' },
        unlocks = { buildings = { 'stealth_module' } },
        desc   = 'Unlocks active stealth modules. Scout ships only. Reduces heat signature.',
    },
    interplanetary_navigation = {
        id     = 'interplanetary_navigation',
        name   = 'Interplanetary Navigation',
        tier   = 5,
        cost   = 400,
        prereqs = { 'shuttle_engineering' },
        unlocks = { buildings = { 'sensor_array', 'comms_array' } },
        desc   = 'Unlocks autopilot, long-range sensors, and star chart systems.',
    },

    ----------- Tier 6 — Ship Endgame -----------
    warp_drive = {
        id     = 'warp_drive',
        name   = 'Warp Drive',
        tier   = 6,
        cost   = 800,
        prereqs = { 'interplanetary_navigation', 'shield_systems' },
        unlocks = {},
        desc   = 'Skip vast distances at extreme fuel cost. Requires Janus warp key fragments.',
    },
}

Research.NODES = NODES

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local completed  = {}   -- completed[nodeId] = true
local current    = nil  -- currently researching node ID
local progress   = 0    -- research points accumulated toward current node
local initialized = false

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Research.init()
    completed = {}
    current   = nil
    progress  = 0
    initialized = true
end

function Research.isInitialized()
    return initialized
end

---------------------------------------------------------------------------
-- Node queries
---------------------------------------------------------------------------

function Research.isCompleted(nodeId)
    return completed[nodeId] == true
end

function Research.canResearch(nodeId)
    local node = NODES[nodeId]
    if not node then return false end
    if node.archived then return false end
    if completed[nodeId] then return false end

    for _, prereq in ipairs(node.prereqs) do
        if not completed[prereq] then return false end
    end

    return true
end

function Research.getAvailable()
    local result = {}
    for nodeId, node in pairs(NODES) do
        if Research.canResearch(nodeId) then
            result[#result + 1] = node
        end
    end
    table.sort(result, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        return a.name < b.name
    end)
    return result
end

function Research.getCompleted()
    local result = {}
    for nodeId in pairs(completed) do
        result[#result + 1] = NODES[nodeId]
    end
    return result
end

function Research.getCurrent()
    return current, progress
end

function Research.getNode(nodeId)
    return NODES[nodeId]
end

function Research.getAllNodes()
    return NODES
end

---------------------------------------------------------------------------
-- Research selection
---------------------------------------------------------------------------

function Research.setCurrent(nodeId)
    if not Research.canResearch(nodeId) then return false end
    current  = nodeId
    progress = 0
    return true
end

function Research.cancelCurrent()
    current  = nil
    progress = 0
end

---------------------------------------------------------------------------
-- Progress accumulation — called by research bench system
-- Returns true + node data when a research completes.
---------------------------------------------------------------------------

function Research.addPoints(points)
    if not current then return false end

    local node = NODES[current]
    if not node then
        current = nil
        progress = 0
        return false
    end

    progress = progress + points

    if progress >= node.cost then
        completed[current] = true
        local finishedNode = node
        current  = nil
        progress = 0
        return true, finishedNode
    end

    return false
end

function Research.getProgress()
    if not current then return 0, 0 end
    local node = NODES[current]
    if not node then return 0, 0 end
    return progress, node.cost
end

function Research.getProgressPercent()
    local prog, cost = Research.getProgress()
    if cost == 0 then return 0 end
    return prog / cost
end

function Research.getCompletedList()
    local list = {}
    for nodeId, done in pairs(completed) do
        if done then
            local node = NODES[nodeId]
            list[#list + 1] = { techId = nodeId, tier = node and node.tier or 1 }
        end
    end
    return list
end

function Research.getInProgressList()
    if not current then return {} end
    local node = NODES[current]
    if not node then return {} end
    return {
        { techId = current, progress = progress / node.cost }
    }
end

function Research.applyDiscProgress(techId, quality, partialFraction)
    local node = NODES[techId]
    if not node then return false end
    if completed[techId] then return false end

    if quality == 'intact' then
        Research.complete(techId)
        return true
    elseif quality == 'degraded' then
        local bonus = node.cost * (0.50 + math.random() * 0.25)
        current = techId
        progress = math.max(progress or 0, bonus)
        return true
    elseif quality == 'partial' then
        local bonus = node.cost * (partialFraction or 0.25)
        current = techId
        progress = math.max(progress or 0, bonus)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Unlock checking — used by production/building systems to gate access
---------------------------------------------------------------------------

function Research.isRecipeUnlocked(recipeId)
    for nodeId, done in pairs(completed) do
        if done then
            local node = NODES[nodeId]
            if node and node.unlocks and node.unlocks.recipes then
                for _, r in ipairs(node.unlocks.recipes) do
                    if r == recipeId then return true end
                end
            end
        end
    end
    return false
end

function Research.isBuildingUnlocked(buildingId)
    for nodeId, done in pairs(completed) do
        if done then
            local node = NODES[nodeId]
            if node and node.unlocks and node.unlocks.buildings then
                for _, b in ipairs(node.unlocks.buildings) do
                    if b == buildingId then return true end
                end
            end
        end
    end
    return false
end

--- Returns true if the building is available to build:
--- either it has no research requirement, or the required research is completed.
function Research.isBuildingAvailable(buildingId)
    local gated = false
    for _, node in pairs(NODES) do
        if node.unlocks and node.unlocks.buildings then
            for _, b in ipairs(node.unlocks.buildings) do
                if b == buildingId then
                    gated = true
                    break
                end
            end
        end
        if gated then break end
    end
    if not gated then return true end
    return Research.isBuildingUnlocked(buildingId)
end

--- Returns the research node name that unlocks a building, or nil if not gated.
function Research.getBuildingResearchName(buildingId)
    for _, node in pairs(NODES) do
        if node.unlocks and node.unlocks.buildings then
            for _, b in ipairs(node.unlocks.buildings) do
                if b == buildingId then return node.name end
            end
        end
    end
    return nil
end

function Research.isEquipmentUnlocked(equipId)
    for nodeId, done in pairs(completed) do
        if done then
            local node = NODES[nodeId]
            if node and node.unlocks and node.unlocks.equipment then
                for _, e in ipairs(node.unlocks.equipment) do
                    if e == equipId then return true end
                end
            end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Tier queries
---------------------------------------------------------------------------

function Research.getNodesByTier(tier)
    local result = {}
    for nodeId, node in pairs(NODES) do
        if node.tier == tier and not node.archived then
            result[#result + 1] = node
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function Research.getMaxTierCompleted()
    local maxTier = 0
    for nodeId in pairs(completed) do
        local node = NODES[nodeId]
        if node and node.tier > maxTier then
            maxTier = node.tier
        end
    end
    return maxTier
end

function Research.getTotalCompleted()
    local n = 0
    for _ in pairs(completed) do n = n + 1 end
    return n
end

function Research.getTotalNodes()
    local n = 0
    for _ in pairs(NODES) do n = n + 1 end
    return n
end

function Research.complete(nodeId)
    if NODES[nodeId] then
        initialized = true
        completed[nodeId] = true
    end
end

function Research.unlockAll()
    initialized = true
    for nodeId in pairs(NODES) do
        completed[nodeId] = true
    end
    current = nil
    progress = 0
end

function Research.step(dt) end  -- research progress driven by bench ECS system

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

function Research.getState()
    if not initialized then return nil end
    return {
        completed = completed,
        current   = current,
        progress  = progress,
    }
end

function Research.restoreState(state)
    if not state then return end
    initialized = true
    completed = state.completed or {}
    current   = state.current
    progress  = state.progress or 0
end

return Research
