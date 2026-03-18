-- planet_defs.lua — Central data file for all planet definitions
-- Each planet is a config table that overrides system defaults.
-- If a field is nil, the system uses its current hard-coded default (Erebus behavior).
-- This means Erebus has zero regression risk — its planet def is effectively all nil.

local PlanetDefs = {}

---------------------------------------------------------------------------
-- Planet definitions
---------------------------------------------------------------------------

local PLANETS = {
    ---------------------------------------------------------------------------
    -- EREBUS — The frozen world (current game, all defaults)
    ---------------------------------------------------------------------------
    erebus = {
        id       = 'erebus',
        name     = 'Erebus',
        subtitle = 'Frozen World',
        desc     = 'A dying planet locked in perpetual cold. The ground itself seems alive, and something stirs beneath the ice. Survival means mastering heat in a world that devours it.',
        color    = { 0.4, 0.7, 1.0 },
        difficultyLabel = 'Standard',
        -- All gameplay fields nil — systems fall through to existing behavior.
        -- This is the reference planet. Every other planet overrides from this baseline.
        scenarios = { 'crashlanded', 'lone_wanderer', 'lost_tribe', 'rich_explorer', 'naked_brutality', 'frozen_siege' },
        worldMap = {
            biomes = {
                { id = 'tundra',    name = 'Tundra',         color = {0.85, 0.88, 0.92}, weight = 0.3 },
                { id = 'glacier',   name = 'Glacier',        color = {0.6, 0.8, 0.95},   weight = 0.2 },
                { id = 'volcanic',  name = 'Volcanic',       color = {0.6, 0.25, 0.15},  weight = 0.1 },
                { id = 'marsh',     name = 'Frozen Marsh',   color = {0.35, 0.5, 0.4},   weight = 0.15 },
                { id = 'forest',    name = 'Frozen Forest',  color = {0.2, 0.4, 0.25},   weight = 0.25 },
            },
            biomeProperties = {
                tundra   = { tempMod = 0,   resourceBias = 'normal', threatBias = 'medium' },
                glacier  = { tempMod = -10, resourceBias = 'sparse', threatBias = 'low' },
                volcanic = { tempMod = 15,  resourceBias = 'rich',   threatBias = 'high' },
                marsh    = { tempMod = 5,   resourceBias = 'normal', threatBias = 'high' },
                forest   = { tempMod = 3,   resourceBias = 'rich',   threatBias = 'medium' },
            },
        },
    },

    ---------------------------------------------------------------------------
    -- RHEA-2 — Desert world (twin suns, heat/water management)
    ---------------------------------------------------------------------------
    rhea_2 = {
        id       = 'rhea_2',
        name     = 'Rhea-2',
        subtitle = 'Scorched Desert',
        desc     = 'Binary star system. Daytime surface temperatures melt steel. Survival means digging deep, hoarding water, and moving at night. The dunes hide things that were here before you.',
        color    = { 1.0, 0.7, 0.3 },
        difficultyLabel = 'Hard',
        scenarios = { 'crashlanded', 'lone_wanderer', 'naked_brutality' },
        secrets = {
            types = {
                buried_survivor = {
                    name   = 'Buried Cryopod',
                    weight = 25,
                    desc   = 'A cryopod half-swallowed by sand. Someone is still alive inside.',
                },
                sandstone_cache = {
                    name   = 'Sandstone Cache',
                    weight = 30,
                    desc   = 'A sealed supply crate carved into sandstone. The lock is corroded shut.',
                },
                sun_shrine = {
                    name   = 'Sun Shrine',
                    weight = 15,
                    desc   = 'A precursor structure aligned with both suns. The walls hum at noon.',
                },
                sand_wurm_nest = {
                    name   = 'Sand Wurm Nest',
                    weight = 20,
                    desc   = 'A ring of disturbed sand marks the lair of something large beneath the dunes.',
                },
            },
        },
        seasons = {
            length = 15,
            order = { 'scorching', 'dry', 'dust_storm', 'cool' },
            startSeason = 'dry',
            defs = {
                scorching = {
                    name = 'Scorching', order = 1,
                    baseTemp = 55, tempRange = 8,
                    daylight = { rise = 5, set = 21 },
                    forageBonus = -0.8, growthMult = 0.2, raidMult = 0.6,
                    weatherBias = { heat_wave = 2.0, sandstorm = 1.5, clear = 0.5 },
                    desc = 'Peak heat. Nothing survives outside without shade.',
                },
                dry = {
                    name = 'Dry Season', order = 2,
                    baseTemp = 35, tempRange = 10,
                    daylight = { rise = 6, set = 20 },
                    forageBonus = -0.3, growthMult = 0.6, raidMult = 1.0,
                    weatherBias = { clear = 2.0, dust_devil = 1.0 },
                    desc = 'Temperatures drop enough to work the surface.',
                },
                dust_storm = {
                    name = 'Dust Storm Season', order = 3,
                    baseTemp = 40, tempRange = 12,
                    daylight = { rise = 6, set = 19 },
                    forageBonus = -0.5, growthMult = 0.4, raidMult = 0.8,
                    weatherBias = { sandstorm = 3.0, dust_devil = 2.0, clear = 0.3 },
                    desc = 'Walls of sand strip exposed structures.',
                },
                cool = {
                    name = 'Cool Season', order = 4,
                    baseTemp = 20, tempRange = 8,
                    daylight = { rise = 7, set = 18 },
                    forageBonus = 0.3, growthMult = 1.2, raidMult = 1.3,
                    weatherBias = { clear = 3.0, overcast = 1.0 },
                    desc = 'The best season. Build fast.',
                },
            },
        },
        thermal = { outdoorSnap = 0.6, undergroundBaseTemp = 25 },
        atmosphere = { ambientO2 = 100, ambientCO2 = 0 },
        creatures = {
            pools = {
                'sand_lizard', 'dust_scarab', 'canyon_sparrow',
                'dune_stalker', 'sand_viper', 'ridge_raptor',
                'sand_wurm', 'sun_scorpion', 'wasteland_hyena',
                'desert_colossus', 'heat_drake', 'dune_leviathan',
            },
        },
        tuning = {
            raids = { budget_base = 25, budget_per_day = 2.5 },
            weather = { harshness_min = 0.6, harshness_max = 2.2 },
        },
        weatherTypes = {
            types = {
                sandstorm  = { name = 'Sandstorm',  tempMod = 5,  visibility = 0.2, solarPenalty = 0.7, movePenalty = 0.5 },
                dust_devil = { name = 'Dust Devil', tempMod = 3,  visibility = 0.5, solarPenalty = 0.3 },
                heat_wave  = { name = 'Heat Wave',  tempMod = 15, visibility = 1.0, solarPenalty = 0 },
            },
        },
        worldMap = {
            biomes = {
                { id = 'dunes',     name = 'Dune Sea',    color = {0.9, 0.82, 0.58},  weight = 0.3 },
                { id = 'canyon',    name = 'Canyon',      color = {0.75, 0.55, 0.35},  weight = 0.2 },
                { id = 'oasis',     name = 'Oasis',       color = {0.3, 0.6, 0.4},     weight = 0.1 },
                { id = 'badlands',  name = 'Badlands',    color = {0.65, 0.45, 0.3},   weight = 0.25 },
                { id = 'salt_flat', name = 'Salt Flat',   color = {0.92, 0.9, 0.85},   weight = 0.15 },
            },
            biomeProperties = {
                dunes     = { tempMod = 5,   resourceBias = 'sparse', threatBias = 'medium' },
                canyon    = { tempMod = -5,  resourceBias = 'rich',   threatBias = 'high' },
                oasis     = { tempMod = -10, resourceBias = 'rich',   threatBias = 'low' },
                badlands  = { tempMod = 8,   resourceBias = 'normal', threatBias = 'high' },
                salt_flat = { tempMod = 12,  resourceBias = 'sparse', threatBias = 'low' },
            },
        },
    },

    ---------------------------------------------------------------------------
    -- MORVOS — Acid world (corrosion, toxic atmosphere)
    ---------------------------------------------------------------------------
    morvos = {
        id       = 'morvos',
        name     = 'Morvos',
        subtitle = 'Acid World',
        desc     = 'Corrosive rain eats through metal. The atmosphere burns exposed skin. Every structure degrades unless sealed. Build on platforms above the melt, or carve into the one rock the acid cannot touch.',
        color    = { 0.6, 1.0, 0.3 },
        difficultyLabel = 'Very Hard',
        scenarios = { 'crashlanded', 'lone_wanderer' },
        secrets = {
            types = {
                acid_survivor = {
                    name   = 'Sealed Pod',
                    weight = 25,
                    desc   = 'An acid-proof pod with a living occupant. The seal is holding. Barely.',
                },
                toxic_cache = {
                    name   = 'Toxic Cache',
                    weight = 30,
                    desc   = 'A supply crate wrapped in corrosion-proof sheeting. Still sealed.',
                },
                spore_node = {
                    name   = 'Spore Node',
                    weight = 20,
                    desc   = 'A pulsing biological mass rooted in the acid rock. It reacts to movement.',
                },
                corrosion_nest = {
                    name   = 'Corrosion Nest',
                    weight = 25,
                    desc   = 'A mound of dissolved metal and organic slime. Something nests inside.',
                },
            },
        },
        seasons = {
            length = 20,
            order = { 'acid_rain', 'toxic_calm', 'spore_bloom', 'corrosion_peak' },
            startSeason = 'toxic_calm',
            defs = {
                acid_rain = {
                    name = 'Acid Rain', order = 1,
                    baseTemp = 15, tempRange = 5,
                    daylight = { rise = 7, set = 17 },
                    forageBonus = -0.6, growthMult = 0.3, raidMult = 0.5,
                    weatherBias = { acid_storm = 3.0, corrosive_fog = 2.0 },
                    desc = 'Rain eats through unprotected metal.',
                },
                toxic_calm = {
                    name = 'Toxic Calm', order = 2,
                    baseTemp = 20, tempRange = 8,
                    daylight = { rise = 6, set = 19 },
                    forageBonus = 0.0, growthMult = 0.8, raidMult = 1.0,
                    weatherBias = { clear = 2.0, toxic_haze = 1.0 },
                    desc = 'The air is still bad but the rain stops.',
                },
                spore_bloom = {
                    name = 'Spore Bloom', order = 3,
                    baseTemp = 25, tempRange = 6,
                    daylight = { rise = 5, set = 20 },
                    forageBonus = 0.5, growthMult = 1.5, raidMult = 1.2,
                    weatherBias = { spore_cloud = 2.0, clear = 1.5 },
                    desc = 'Fungal growth peaks. Good foraging if you can breathe.',
                },
                corrosion_peak = {
                    name = 'Corrosion Peak', order = 4,
                    baseTemp = 10, tempRange = 4,
                    daylight = { rise = 8, set = 16 },
                    forageBonus = -0.8, growthMult = 0.1, raidMult = 0.4,
                    weatherBias = { acid_storm = 4.0, corrosive_fog = 3.0, clear = 0.2 },
                    desc = 'Maximum atmospheric corrosion. Seal everything.',
                },
            },
        },
        thermal = { outdoorSnap = 0.4, undergroundBaseTemp = 18 },
        atmosphere = { ambientO2 = 70, ambientCO2 = 15 },
        creatures = {
            pools = {
                'acid_mite', 'spore_crawler', 'slime_beetle',
                'corrosion_hound', 'acid_spitter', 'fungal_stalker',
                'bile_brute', 'caustic_wurm', 'plague_carrier',
                'acid_titan', 'the_dissolvent', 'mire_colossus',
            },
        },
        tuning = {
            raids = { budget_base = 20, budget_per_day = 1.5 },
            weather = { harshness_min = 0.8, harshness_max = 2.5 },
        },
        weatherTypes = {
            types = {
                acid_storm    = { name = 'Acid Storm',    tempMod = -5, visibility = 0.3, solarPenalty = 0.8, corrosionMult = 2.0 },
                corrosive_fog = { name = 'Corrosive Fog', tempMod = -2, visibility = 0.5, solarPenalty = 0.3, corrosionMult = 1.5 },
                toxic_haze    = { name = 'Toxic Haze',    tempMod = 0,  visibility = 0.7, solarPenalty = 0.2 },
                spore_cloud   = { name = 'Spore Cloud',   tempMod = 2,  visibility = 0.6, solarPenalty = 0.1 },
            },
        },
        worldMap = {
            biomes = {
                { id = 'acid_basin',    name = 'Acid Basin',     color = {0.4, 0.6, 0.2},   weight = 0.25 },
                { id = 'fungal_grove',  name = 'Fungal Grove',   color = {0.3, 0.5, 0.35},  weight = 0.2 },
                { id = 'rock_platform', name = 'Rock Platform',  color = {0.5, 0.45, 0.4},  weight = 0.25 },
                { id = 'toxic_marsh',   name = 'Toxic Marsh',    color = {0.35, 0.45, 0.2},  weight = 0.15 },
                { id = 'spore_field',   name = 'Spore Field',    color = {0.55, 0.6, 0.25},  weight = 0.15 },
            },
            biomeProperties = {
                acid_basin    = { tempMod = -3,  resourceBias = 'sparse', threatBias = 'high' },
                fungal_grove  = { tempMod = 3,   resourceBias = 'rich',   threatBias = 'medium' },
                rock_platform = { tempMod = 0,   resourceBias = 'normal', threatBias = 'low' },
                toxic_marsh   = { tempMod = -5,  resourceBias = 'normal', threatBias = 'extreme' },
                spore_field   = { tempMod = 5,   resourceBias = 'rich',   threatBias = 'medium' },
            },
        },
    },

    ---------------------------------------------------------------------------
    -- NERTHUS-9 — Ocean world (pressure, flooding, underwater)
    ---------------------------------------------------------------------------
    nerthus_9 = {
        id       = 'nerthus_9',
        name     = 'Nerthus-9',
        subtitle = 'Ocean World',
        desc     = 'Scattered volcanic islands on an endless sea. The water rises. Pressure increases with depth. Flood management is not optional — it is the game.',
        color    = { 0.3, 0.5, 1.0 },
        difficultyLabel = 'Hard',
        scenarios = { 'crashlanded', 'lone_wanderer' },
        secrets = {
            types = {
                sunken_pod = {
                    name   = 'Sunken Pod',
                    weight = 25,
                    desc   = 'A cryopod wedged in coral below the waterline. Air bubbles rise from the seal.',
                },
                coral_cache = {
                    name   = 'Coral Cache',
                    weight = 30,
                    desc   = 'A supply crate encrusted with living coral. Still watertight.',
                },
                depth_beacon = {
                    name   = 'Depth Beacon',
                    weight = 15,
                    desc   = 'A precursor device anchored to the seabed. It pulses with deep light.',
                },
                kraken_nest = {
                    name   = 'Kraken Nest',
                    weight = 20,
                    desc   = 'A tangle of massive tentacle marks around a deep cave. The water is warm here.',
                },
                xenolith_wreck = {
                    name   = 'BioVault Research Vessel',
                    weight = 3,
                    desc   = 'Mammona BioVault boat half-sunk in the shallows. Hull breached from inside. Containment warnings still flash.',
                },
                mammona_oil_rig = {
                    name   = 'Abandoned Mammona Rig',
                    weight = 8,
                    desc   = 'Rusted Mammona drilling platform listing in the waves. Crew left in a hurry.',
                },
                mammona_sea_lab = {
                    name   = 'Sunken Mammona Lab',
                    weight = 5,
                    desc   = 'Mammona research module on the seafloor. BioVault markings on the airlock. Something grew through the walls.',
                },
                abandoned_cargo_boat = {
                    name   = 'Abandoned Cargo Boat',
                    weight = 12,
                    desc   = 'Mammona cargo barge run aground. Barnacles up to the waterline. Cargo nets still tied down.',
                },
                capsized_trawler = {
                    name   = 'Capsized Trawler',
                    weight = 10,
                    desc   = 'Fishing trawler belly-up in the shallows. Nets full of something that is not fish.',
                },
                mammona_patrol_boat = {
                    name   = 'Scuttled Mammona Patrol Boat',
                    weight = 7,
                    desc   = 'Mammona security boat scuttled on the reef. Holes punched from inside. Weapons locker forced open.',
                },
                drifting_lifeboat = {
                    name   = 'Drifting Lifeboat',
                    weight = 15,
                    desc   = 'Emergency lifeboat. No crew. Rations half eaten. Three words scratched into the seat.',
                },
                sunken_freighter = {
                    name   = 'Sunken Freighter',
                    weight = 6,
                    desc   = 'OmniCorp cargo freighter on the bottom. Top deck above water at low tide. Hull groans.',
                },
                thalassa_log = {
                    name   = 'Thalassa Deep Fragment',
                    weight = 6,
                    desc   = 'Prison-issue recorder. Waterlogged. The playback is garbled but something is on it.',
                },
            },
        },
        seasons = {
            length = 18,
            order = { 'monsoon', 'low_tide', 'storm_season', 'calm_waters' },
            startSeason = 'low_tide',
            defs = {
                monsoon = {
                    name = 'Monsoon', order = 1,
                    baseTemp = 22, tempRange = 5,
                    daylight = { rise = 6, set = 19 },
                    forageBonus = 0.3, growthMult = 1.2, raidMult = 0.6,
                    weatherBias = { heavy_rain = 3.0, storm = 2.0, clear = 0.3 },
                    desc = 'Constant rain. Water rises. Everything floods.',
                },
                low_tide = {
                    name = 'Low Tide', order = 2,
                    baseTemp = 18, tempRange = 8,
                    daylight = { rise = 5, set = 21 },
                    forageBonus = 0.5, growthMult = 1.0, raidMult = 1.0,
                    weatherBias = { clear = 3.0, overcast = 1.5 },
                    desc = 'Waters recede. Best time to build and expand.',
                },
                storm_season = {
                    name = 'Storm Season', order = 3,
                    baseTemp = 15, tempRange = 6,
                    daylight = { rise = 7, set = 17 },
                    forageBonus = -0.3, growthMult = 0.5, raidMult = 0.8,
                    weatherBias = { hurricane = 2.0, heavy_rain = 2.5, storm = 1.5 },
                    desc = 'Violent storms batter the islands.',
                },
                calm_waters = {
                    name = 'Calm Waters', order = 4,
                    baseTemp = 20, tempRange = 6,
                    daylight = { rise = 6, set = 20 },
                    forageBonus = 0.2, growthMult = 0.8, raidMult = 1.3,
                    weatherBias = { clear = 2.5, overcast = 1.0 },
                    desc = 'Peaceful seas. Raiders take advantage.',
                },
            },
        },
        thermal = { outdoorSnap = 0.3, undergroundBaseTemp = 15 },
        atmosphere = { ambientO2 = 100, ambientCO2 = 0 },
        creatures = {
            pools = {
                'tide_crab', 'reef_fish', 'kelp_drifter',
                'depth_lurker', 'reef_shark', 'pressure_eel',
                'kraken_spawn', 'abyssal_hunter', 'barnacle_titan_juvenile',
                'storm_leviathan', 'the_depth_mother', 'tidal_colossus',
            },
        },
        flooding = { flowRate = 2.0, evapRate = 0.3 },
        tuning = {
            raids = { budget_base = 25, budget_per_day = 2 },
            weather = { harshness_min = 0.5, harshness_max = 2.0 },
        },
        weatherTypes = {
            types = {
                hurricane  = { name = 'Hurricane',  tempMod = -3, visibility = 0.15, solarPenalty = 0.9, floods = true, windMult = 3.0 },
                heavy_rain = { name = 'Heavy Rain', tempMod = -2, visibility = 0.4,  solarPenalty = 0.6, floods = true },
                storm      = { name = 'Storm',      tempMod = -1, visibility = 0.3,  solarPenalty = 0.7, windMult = 2.0 },
            },
        },
        worldMap = {
            biomes = {
                { id = 'island',     name = 'Volcanic Island', color = {0.35, 0.55, 0.3},  weight = 0.25 },
                { id = 'reef',       name = 'Coral Reef',      color = {0.3, 0.6, 0.7},    weight = 0.2 },
                { id = 'volcano',    name = 'Active Volcano',  color = {0.7, 0.3, 0.15},   weight = 0.1 },
                { id = 'deep_ocean', name = 'Deep Ocean',      color = {0.1, 0.2, 0.5},    weight = 0.15 },
                { id = 'atoll',      name = 'Atoll',           color = {0.5, 0.75, 0.65},  weight = 0.3 },
            },
            biomeProperties = {
                island     = { tempMod = 0,   resourceBias = 'normal', threatBias = 'medium' },
                reef       = { tempMod = -2,  resourceBias = 'rich',   threatBias = 'medium' },
                volcano    = { tempMod = 15,  resourceBias = 'rich',   threatBias = 'extreme' },
                deep_ocean = { tempMod = -5,  resourceBias = 'sparse', threatBias = 'high' },
                atoll      = { tempMod = 2,   resourceBias = 'normal', threatBias = 'low' },
            },
        },
    },

    ---------------------------------------------------------------------------
    -- PAXTERA PRIME — Temperate world (easy climate, human raids, classic colony sim)
    ---------------------------------------------------------------------------
    paxtera_prime = {
        id       = 'paxtera_prime',
        name     = 'Paxtera Prime',
        subtitle = 'Temperate World',
        desc     = 'Mild climate, breathable air, fertile soil. The easiest planet to survive on. Seasons change, crops grow, and raiders come from the hills. A straightforward colony experience.',
        color    = { 0.9, 0.8, 0.4 },
        difficultyLabel = 'Easy',
        scenarios = { 'crashlanded', 'lone_wanderer', 'lost_tribe', 'rich_explorer', 'naked_brutality' },
        secrets = {
            types = {
                abandoned_shelter = {
                    name   = 'Abandoned Shelter',
                    weight = 25,
                    desc   = 'A weathered lean-to with a sleeping figure inside. They stir when you approach.',
                },
                supply_drop = {
                    name   = 'Supply Drop',
                    weight = 30,
                    desc   = 'A cargo pod from an orbital drop. Parachute tangled in the trees.',
                },
                old_bunker = {
                    name   = 'Old Bunker',
                    weight = 20,
                    desc   = 'A pre-war bunker door set into a hillside. The lock is mechanical.',
                },
                wildlife_den = {
                    name   = 'Wildlife Den',
                    weight = 25,
                    desc   = 'A large burrow surrounded by gnawed bones. The occupant is out hunting.',
                },
            },
        },
        seasons = {
            length = 15,
            order = { 'spring', 'summer', 'autumn', 'winter' },
            startSeason = 'spring',
            defs = {
                spring = {
                    name = 'Spring', order = 1,
                    baseTemp = 12, tempRange = 8,
                    daylight = { rise = 6, set = 20 },
                    forageBonus = 0.5, growthMult = 1.5, raidMult = 1.0,
                    weatherBias = { clear = 2.0, rain = 1.5 },
                    desc = 'Planting season. Warm soil, long days.',
                },
                summer = {
                    name = 'Summer', order = 2,
                    baseTemp = 25, tempRange = 6,
                    daylight = { rise = 5, set = 21 },
                    forageBonus = 0.3, growthMult = 1.2, raidMult = 1.2,
                    weatherBias = { clear = 3.0, heat_wave = 0.5 },
                    desc = 'Warm days. Raiders get bold.',
                },
                autumn = {
                    name = 'Autumn', order = 3,
                    baseTemp = 10, tempRange = 10,
                    daylight = { rise = 7, set = 18 },
                    forageBonus = 0.8, growthMult = 0.8, raidMult = 1.5,
                    weatherBias = { overcast = 2.0, rain = 1.5, clear = 1.0 },
                    desc = 'Harvest season. Raids peak as everyone wants your stockpile.',
                },
                winter = {
                    name = 'Winter', order = 4,
                    baseTemp = -5, tempRange = 8,
                    daylight = { rise = 8, set = 16 },
                    forageBonus = -0.3, growthMult = 0.3, raidMult = 0.8,
                    weatherBias = { snowfall = 1.5, overcast = 2.0, clear = 1.0 },
                    desc = 'Mild cold. Nothing like Erebus.',
                },
            },
        },
        thermal = { outdoorSnap = 0.4, undergroundBaseTemp = 10 },
        atmosphere = { ambientO2 = 100, ambientCO2 = 0 },
        creatures = {
            pools = {
                'field_hare', 'grain_bird', 'orchard_snake',
                'timber_wolf', 'plains_bear', 'wild_boar',
                'feral_bull', 'apex_cat', 'razorback_hog',
                'great_elk', 'territorial_megabear',
            },
        },
        tuning = {
            raids = { budget_base = 25, budget_per_day = 2 },
            weather = { harshness_min = 0.3, harshness_max = 1.5 },
        },
        worldMap = {
            biomes = {
                { id = 'grassland', name = 'Grassland',  color = {0.45, 0.65, 0.3},  weight = 0.3 },
                { id = 'forest',    name = 'Forest',     color = {0.2, 0.45, 0.2},   weight = 0.2 },
                { id = 'farmland',  name = 'Farmland',   color = {0.6, 0.55, 0.3},   weight = 0.2 },
                { id = 'hills',     name = 'Hills',      color = {0.5, 0.55, 0.45},  weight = 0.15 },
                { id = 'wetland',   name = 'Wetland',    color = {0.3, 0.5, 0.45},   weight = 0.15 },
            },
            biomeProperties = {
                grassland = { tempMod = 0,   resourceBias = 'normal', threatBias = 'low' },
                forest    = { tempMod = -2,  resourceBias = 'rich',   threatBias = 'medium' },
                farmland  = { tempMod = 2,   resourceBias = 'rich',   threatBias = 'low' },
                hills     = { tempMod = -3,  resourceBias = 'normal', threatBias = 'medium' },
                wetland   = { tempMod = 0,   resourceBias = 'normal', threatBias = 'high' },
            },
        },
    },

    ---------------------------------------------------------------------------
    -- NEMAEA — Dead world (vacuum, radiation, Automatons)
    ---------------------------------------------------------------------------
    nemaea = {
        id       = 'nemaea',
        name     = 'Nemaea',
        subtitle = 'Dead World',
        desc     = 'No atmosphere. No life. A crumbling Dyson Sphere casts broken light across a radiation-scarred surface. Automatons patrol the ruins — kill one and you might find a person inside.',
        color    = { 0.8, 0.3, 0.3 },
        difficultyLabel = 'Extreme',
        scenarios = { 'hull_breach', 'lone_wanderer' },
        secrets = {
            types = {
                automaton_pod = {
                    name   = 'Automaton Pod',
                    weight = 25,
                    desc   = 'A damaged automaton shell. Life signs inside — someone is trapped in the chassis.',
                },
                dyson_cache = {
                    name   = 'Dyson Cache',
                    weight = 30,
                    desc   = 'A sealed Dyson maintenance locker. Components and circuits inside.',
                },
                signal_beacon = {
                    name   = 'Signal Beacon',
                    weight = 15,
                    desc   = 'A precursor transmitter lodged in regolith. It broadcasts on frequencies no one assigned.',
                },
                drone_nest = {
                    name   = 'Drone Nest',
                    weight = 20,
                    desc   = 'A heap of deactivated drones arranged in concentric rings. They twitch when scanned.',
                },
            },
        },
        seasons  = {
            length = 30,
            order = { 'solar_maximum', 'eclipse', 'solar_minimum', 'debris_season' },
            startSeason = 'solar_minimum',
            defs = {
                solar_maximum = {
                    name = 'Solar Maximum', order = 1,
                    baseTemp = 120, tempRange = 20,
                    daylight = { rise = 0, set = 24 },
                    forageBonus = -1.0, growthMult = 0.0, raidMult = 0.5,
                    weatherBias = { solar_flare = 3.0, clear = 1.0 },
                    desc = 'Dyson Sphere fragments focus starlight. Lethal surface temps.',
                },
                eclipse = {
                    name = 'Eclipse', order = 2,
                    baseTemp = -80, tempRange = 15,
                    daylight = { rise = 0, set = 0 },
                    forageBonus = -1.0, growthMult = 0.0, raidMult = 1.5,
                    weatherBias = { clear = 2.0, meteor_shower = 1.0 },
                    desc = 'Dyson fragment blocks the star. Total darkness, extreme cold.',
                },
                solar_minimum = {
                    name = 'Solar Minimum', order = 3,
                    baseTemp = 5, tempRange = 10,
                    daylight = { rise = 6, set = 18 },
                    forageBonus = -0.5, growthMult = 0.0, raidMult = 1.0,
                    weatherBias = { clear = 3.0, radiation_burst = 0.5 },
                    desc = 'Livable surface temps. Automatons are most active.',
                },
                debris_season = {
                    name = 'Debris Season', order = 4,
                    baseTemp = -20, tempRange = 25,
                    daylight = { rise = 4, set = 20 },
                    forageBonus = -1.0, growthMult = 0.0, raidMult = 0.8,
                    weatherBias = { meteor_shower = 3.0, clear = 1.5 },
                    desc = 'Dyson Sphere fragments rain down. Shelter or die.',
                },
            },
        },
        thermal = {
            outdoorSnap = 0.8,
            undergroundBaseTemp = -10,
        },
        atmosphere = {
            ambientO2 = 0,
            ambientCO2 = 0,
        },
        radiation = {
            ambientDose = 0.02,
            doseLethal = 5.0,
        },
        creatures = {
            pools = {
                'scout_drone', 'maintenance_bot', 'patrol_automaton', 'enforcer_unit',
                'salvage_drone', 'siege_automaton', 'hunter_killer', 'containment_unit',
                'titan_automaton', 'the_warden', 'dyson_sentinel',
            },
        },
        hermes = { enabled = false },
        tuning = {
            raids = {
                budget_base = 40,
                budget_per_day = 3,
                human_chance_scale = 0,
            },
            weather = {
                harshness_min = 1.0,
                harshness_max = 3.0,
            },
        },
        weatherTypes = {
            types = {
                solar_flare     = { name = 'Solar Flare',     tempMod = 30, visibility = 0.8, solarPenalty = 0, radiationBurst = 0.1 },
                meteor_shower   = { name = 'Meteor Shower',   tempMod = 0,  visibility = 0.4, solarPenalty = 0.5, structuralDamage = 0.02 },
                radiation_burst = { name = 'Radiation Burst', tempMod = 5,  visibility = 1.0, solarPenalty = 0, radiationBurst = 0.2 },
            },
        },
        worldMap = {
            biomes = {
                { id = 'crater_field',      name = 'Crater Field',      color = {0.4, 0.38, 0.35},  weight = 0.25 },
                { id = 'ruins',             name = 'Dyson Ruins',       color = {0.5, 0.45, 0.42},  weight = 0.2 },
                { id = 'irradiated_wastes', name = 'Irradiated Wastes', color = {0.45, 0.5, 0.3},   weight = 0.15 },
                { id = 'wreckage',          name = 'Ship Wreckage',     color = {0.55, 0.5, 0.48},  weight = 0.15 },
                { id = 'regolith_plains',   name = 'Regolith Plains',   color = {0.5, 0.48, 0.45},  weight = 0.25 },
            },
            biomeProperties = {
                crater_field      = { tempMod = -5,  resourceBias = 'sparse', threatBias = 'medium' },
                ruins             = { tempMod = 0,   resourceBias = 'rich',   threatBias = 'high' },
                irradiated_wastes = { tempMod = 10,  resourceBias = 'sparse', threatBias = 'extreme' },
                wreckage          = { tempMod = 0,   resourceBias = 'rich',   threatBias = 'medium' },
                regolith_plains   = { tempMod = -3,  resourceBias = 'normal', threatBias = 'low' },
            },
        },
    },

    ---------------------------------------------------------------------------
    -- GAIA A^1x — Fortuna prequel (scripted fall)
    ---------------------------------------------------------------------------
    gaia_a1x = {
        id       = 'gaia_a1x',
        name     = 'Gaia A^1x',
        subtitle = 'The Fall of Fortuna',
        desc     = 'A lush world with something trapped inside it. Baldrungen stirs beneath the crust, spawning waves of insectoid undead abominations. The colony has a fixed ending — the question is what you build before the ground opens.',
        color    = { 0.4, 0.9, 0.5 },
        difficultyLabel = 'Narrative',
        scenarios = { 'crashlanded' },
        secrets = {
            types = {
                forest_shelter = {
                    name   = 'Forest Shelter',
                    weight = 25,
                    desc   = 'A moss-covered shelter built into a hollow tree. Someone left a fire burning.',
                },
                growth_cache = {
                    name   = 'Growth Cache',
                    weight = 30,
                    desc   = 'A root cellar overgrown with living vines. Food and herbs preserved inside.',
                },
                corruption_node = {
                    name   = 'Corruption Node',
                    weight = 15,
                    desc   = 'A Baldrungen growth spike piercing the forest floor. It pulses with dark energy.',
                },
                husk_nest = {
                    name   = 'Husk Nest',
                    weight = 20,
                    desc   = 'A mound of chitin and rotting wood. Insectoid husks twitch in the shadows.',
                },
            },
        },
        seasons  = {
            length = 15,
            order = { 'spring', 'summer', 'autumn', 'corruption' },
            startSeason = 'spring',
            defs = {
                spring = {
                    name = 'Spring', order = 1,
                    baseTemp = 15, tempRange = 8,
                    daylight = { rise = 5, set = 20 },
                    forageBonus = 0.8, growthMult = 1.5, raidMult = 0.8,
                    weatherBias = { clear = 3.0, rain = 1.0 },
                    desc = 'Lush growth. Baldrungen is quiet.',
                },
                summer = {
                    name = 'Summer', order = 2,
                    baseTemp = 28, tempRange = 6,
                    daylight = { rise = 4, set = 22 },
                    forageBonus = 0.5, growthMult = 1.2, raidMult = 1.0,
                    weatherBias = { clear = 2.5, heat_wave = 0.5 },
                    desc = 'Warm days. The ground trembles at night.',
                },
                autumn = {
                    name = 'Autumn', order = 3,
                    baseTemp = 8, tempRange = 10,
                    daylight = { rise = 7, set = 17 },
                    forageBonus = 1.0, growthMult = 0.8, raidMult = 1.2,
                    weatherBias = { overcast = 2.0, rain = 1.5 },
                    desc = 'Harvest what you can. The corruption spreads.',
                },
                corruption = {
                    name = 'Corruption', order = 4,
                    baseTemp = -5, tempRange = 12,
                    daylight = { rise = 8, set = 15 },
                    forageBonus = -0.5, growthMult = 0.2, raidMult = 2.0,
                    weatherBias = { spore_fall = 3.0, overcast = 2.0, clear = 0.5 },
                    desc = 'Baldrungen pushes through. Insectoid undead flood the surface.',
                },
            },
        },
        thermal = {
            outdoorSnap = 0.3,
            undergroundBaseTemp = 12,
        },
        atmosphere = {
            ambientO2 = 100,
            ambientCO2 = 0,
        },
        creatures = {
            pools = {
                'forest_rabbit', 'songbird', 'meadow_vole',
                'timber_predator', 'brook_bear', 'grove_stalker',
                'husk_crawler', 'bone_beetle', 'rot_wasp',
                'brood_mother', 'the_emergence', 'baldrungen_tendril',
            },
        },
        tuning = {
            raids = {
                budget_base = 20,
                budget_per_day = 4,
                swarm_chance_scale = 2.0,
            },
            weather = {
                harshness_min = 0.3,
                harshness_max = 2.0,
            },
        },
        worldMap = {
            biomes = {
                { id = 'meadow',         name = 'Meadow',          color = {0.5, 0.7, 0.35},  weight = 0.25 },
                { id = 'dense_forest',   name = 'Dense Forest',    color = {0.15, 0.4, 0.15},  weight = 0.25 },
                { id = 'corrupted_zone', name = 'Corrupted Zone',  color = {0.45, 0.3, 0.5},   weight = 0.1 },
                { id = 'river_valley',   name = 'River Valley',    color = {0.3, 0.55, 0.5},   weight = 0.2 },
                { id = 'highlands',      name = 'Highlands',       color = {0.55, 0.6, 0.45},  weight = 0.2 },
            },
            biomeProperties = {
                meadow         = { tempMod = 2,   resourceBias = 'normal', threatBias = 'low' },
                dense_forest   = { tempMod = 0,   resourceBias = 'rich',   threatBias = 'medium' },
                corrupted_zone = { tempMod = -8,  resourceBias = 'sparse', threatBias = 'extreme' },
                river_valley   = { tempMod = 3,   resourceBias = 'rich',   threatBias = 'low' },
                highlands      = { tempMod = -5,  resourceBias = 'normal', threatBias = 'medium' },
            },
        },
    },

    ---------------------------------------------------------------------------
    -- SPACE — The void between worlds (not a starting planet)
    ---------------------------------------------------------------------------
    space = {
        id       = 'space',
        name     = 'Space',
        subtitle = 'The Void Between',
        desc     = 'The cold vacuum between worlds. No air, no gravity, no mercy. Your ship is your only shelter.',
        color    = { 0.1, 0.1, 0.2 },
        difficultyLabel = 'N/A',
        scenarios = {},
        thermal = { outdoorSnap = 1.0, undergroundBaseTemp = -270 },
        atmosphere = { ambientO2 = 0, ambientCO2 = 0 },
        radiation = { ambientDose = 0.01, doseLethal = 5.0 },
        hermes = { enabled = false },
        tuning = {
            raids = { budget_base = 0, budget_per_day = 0 },
            weather = { harshness_min = 0, harshness_max = 0 },
        },
    },
}

---------------------------------------------------------------------------
-- Ordered list for UI rendering
---------------------------------------------------------------------------

PlanetDefs.PLANET_ORDER = {
    'erebus', 'rhea_2', 'morvos', 'nerthus_9', 'paxtera_prime', 'nemaea', 'gaia_a1x',
}

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

function PlanetDefs.get(planetId)
    return PLANETS[planetId]
end

function PlanetDefs.getAll()
    return PLANETS
end

function PlanetDefs.exists(planetId)
    return PLANETS[planetId] ~= nil
end

return PlanetDefs
