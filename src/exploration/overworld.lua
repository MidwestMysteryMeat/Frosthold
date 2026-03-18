-- overworld.lua — Expedition destination catalog and reward tables
-- Defines off-map locations colonists can be sent to, per-planet.
-- Each destination has a risk level, party requirements, duration,
-- and a weighted reward table rolled on expedition return.

local Overworld = {}

---------------------------------------------------------------------------
-- Reward pool helpers
---------------------------------------------------------------------------

-- Weighted pick: entries = { { item, weight }, ... }
-- Returns the item string.
local function weightedPick(entries)
    local total = 0
    for _, e in ipairs(entries) do
        total = total + e.weight
    end
    local roll = math.random() * total
    local acc = 0
    for _, e in ipairs(entries) do
        acc = acc + e.weight
        if roll <= acc then return e.item end
    end
    return entries[#entries].item
end

Overworld.weightedPick = weightedPick

local function weightedPickEntry(entries)
    local total = 0
    for _, e in ipairs(entries) do
        total = total + e.weight
    end
    local roll = math.random() * total
    local acc = 0
    for _, e in ipairs(entries) do
        acc = acc + e.weight
        if roll <= acc then return e end
    end
    return entries[#entries]
end

local function copyOverrides(src)
    local out = {}
    for k, v in pairs(src or {}) do
        out[k] = v
    end
    return out
end

---------------------------------------------------------------------------
-- Destination definitions
---------------------------------------------------------------------------

local EREBUS_DESTINATIONS = {
    frozen_wastes = {
        name        = 'Frozen Wastes',
        description = 'Surface sweep. Open tundra, basic salvage. Low risk.',
        risk        = 1,
        minParty    = 1,
        duration    = 30,   -- game-seconds
        rewards     = {
            success = {
                { item = 'raw_wood',    min = 6,  max = 15, weight = 30 },
                { item = 'raw_stone',   min = 4,  max = 10, weight = 25 },
                { item = 'plant_fiber', min = 3,  max = 8,  weight = 20 },
                { item = 'raw_meat',    min = 2,  max = 5,  weight = 15 },
                { item = 'raw_hide',    min = 1,  max = 3,  weight = 10 },
            },
            partial = {
                { item = 'raw_wood',    min = 2, max = 6, weight = 40 },
                { item = 'raw_stone',   min = 1, max = 4, weight = 35 },
                { item = 'plant_fiber', min = 1, max = 3, weight = 25 },
            },
        },
    },

    ice_caves = {
        name        = 'Ice Caves',
        description = 'Natural cave network. Ore veins and ice deposits. Moderate risk.',
        risk        = 2,
        minParty    = 1,
        duration    = 60,
        findings    = {
            success = {
                min = 1, max = 1,
                entries = {
                    { template = 'latent_survivor', weight = 35, overrides = { source = 'an ice-cave shelter', desc = 'A cave survivor hauled back from the dark. Their smile arrives before their answer does.' } },
                    { template = 'node_sample', weight = 40, overrides = { source = 'a frozen growth seam', desc = 'Fibrous tissue chipped from a living seam below the cave ice.' } },
                    { template = 'mimic_tissue', weight = 25, overrides = { source = 'a false camp in the caves' } },
                },
            },
            partial = {
                min = 1, max = 1,
                entries = {
                    { template = 'node_sample', weight = 60, overrides = { source = 'an ice-cave seam' } },
                    { template = 'mimic_tissue', weight = 40, overrides = { source = 'a chewed bedroll cache' } },
                },
            },
        },
        rewards     = {
            success = {
                { item = 'raw_ore',   min = 5, max = 12, weight = 30 },
                { item = 'raw_ice',   min = 8, max = 20, weight = 25 },
                { item = 'raw_stone', min = 4, max = 10, weight = 20 },
                { item = 'coal',      min = 3, max = 8,  weight = 15 },
                { item = 'metal_ingot', min = 1, max = 3, weight = 10 },
            },
            partial = {
                { item = 'raw_ore',   min = 2, max = 5, weight = 35 },
                { item = 'raw_ice',   min = 3, max = 8, weight = 35 },
                { item = 'raw_stone', min = 1, max = 4, weight = 30 },
            },
        },
    },

    wolf_den = {
        name        = 'Predator Territory',
        description = 'Territorial fauna. Active predator zone. Thermal cores cluster here.',
        risk        = 3,
        minParty    = 2,
        duration    = 90,
        rewards     = {
            success = {
                { item = 'thermal_core', min = 3, max = 8,  weight = 30 },
                { item = 'raw_meat',     min = 6, max = 15, weight = 25 },
                { item = 'raw_hide',     min = 4, max = 10, weight = 20 },
                { item = 'raw_ore',      min = 2, max = 6,  weight = 15 },
                { item = 'coal',         min = 2, max = 5,  weight = 10 },
            },
            partial = {
                { item = 'thermal_core', min = 1, max = 3, weight = 30 },
                { item = 'raw_meat',     min = 2, max = 6, weight = 40 },
                { item = 'raw_hide',     min = 1, max = 4, weight = 30 },
            },
        },
    },

    abandoned_outpost = {
        name        = 'Abandoned Outpost',
        description = 'Prior Mammona crew site. Salvageable hardware and supplies.',
        risk        = 2,
        minParty    = 1,
        duration    = 75,
        findings    = {
            success = {
                min = 1, max = 1,
                entries = {
                    { template = 'latent_survivor', weight = 45, overrides = { source = 'a sealed Mammona bunkroom', desc = "A survivor from an abandoned outpost. They still answer to yesterday's shift bell." } },
                    { template = 'resonant_shard', weight = 30, overrides = { source = 'a locker wrapped in warning tape' } },
                    { template = 'mimic_tissue', weight = 25, overrides = { source = 'a stripped infirmary cot' } },
                },
            },
            partial = {
                min = 1, max = 1,
                entries = {
                    { template = 'resonant_shard', weight = 55, overrides = { source = 'a burned-out comms rack' } },
                    { template = 'latent_survivor', weight = 45, overrides = { source = 'an abandoned cryobed' } },
                },
            },
        },
        rewards     = {
            success = {
                { item = 'components', min = 2, max = 5,  weight = 25 },
                { item = 'metal_ingot', min = 3, max = 8, weight = 25 },
                { item = 'cloth',      min = 2, max = 6,  weight = 15 },
                { item = 'lumber',     min = 3, max = 8,  weight = 15 },
                { item = 'circuit',    min = 1, max = 2,  weight = 10 },
                { item = 'weapon_spear', min = 1, max = 1, weight = 10 },
            },
            partial = {
                { item = 'metal_ingot', min = 1, max = 3, weight = 35 },
                { item = 'components',  min = 1, max = 2, weight = 30 },
                { item = 'lumber',      min = 1, max = 4, weight = 35 },
            },
        },
    },

    glacier_peak = {
        name        = 'Glacier Peak',
        description = 'Summit ascent. Crystalline deposits at altitude. Treacherous conditions.',
        risk        = 4,
        minParty    = 2,
        duration    = 180,
        rewards     = {
            success = {
                { item = 'thermal_core',  min = 5, max = 12, weight = 25 },
                { item = 'steel',         min = 3, max = 8,  weight = 20 },
                { item = 'raw_ore',       min = 6, max = 15, weight = 20 },
                { item = 'circuit',       min = 1, max = 3,  weight = 15 },
                { item = 'components',    min = 2, max = 5,  weight = 10 },
                { item = 'insulation',    min = 2, max = 4,  weight = 10 },
            },
            partial = {
                { item = 'thermal_core', min = 1, max = 4, weight = 30 },
                { item = 'raw_ore',      min = 2, max = 6, weight = 40 },
                { item = 'steel',        min = 1, max = 3, weight = 30 },
            },
        },
    },

    thermal_vents = {
        name        = 'Thermal Vents',
        description = 'Geothermal fissures. High heat and gas output. Rich fuel and core deposits.',
        risk        = 3,
        minParty    = 2,
        duration    = 120,
        findings    = {
            success = {
                min = 1, max = 1,
                entries = {
                    { template = 'resonant_shard', weight = 50, overrides = { source = 'a vent-side shrine of slag and bone' } },
                    { template = 'signal_idol', weight = 25, overrides = { source = 'a glassy chamber above the vents' } },
                    { template = 'thrall_prisoner', weight = 25, overrides = { source = 'a vent tunnel camp' } },
                },
            },
        },
        rewards     = {
            success = {
                { item = 'thermal_core', min = 4, max = 10, weight = 30 },
                { item = 'coal',         min = 6, max = 15, weight = 25 },
                { item = 'fuel_cell',    min = 2, max = 5,  weight = 20 },
                { item = 'raw_ore',      min = 3, max = 8,  weight = 15 },
                { item = 'pipe',         min = 1, max = 3,  weight = 10 },
            },
            partial = {
                { item = 'thermal_core', min = 1, max = 4, weight = 35 },
                { item = 'coal',         min = 2, max = 6, weight = 35 },
                { item = 'fuel_cell',    min = 1, max = 2, weight = 30 },
            },
        },
    },

    deep_rift = {
        name        = 'Deep Rift',
        description = 'Deep crevasse into Erebus. Extreme danger. Highest-value resources.',
        risk        = 5,
        minParty    = 3,
        duration    = 300,
        findings    = {
            success = {
                min = 1, max = 2,
                entries = {
                    { template = 'vessel_host', weight = 35, overrides = { source = 'the deep rift', desc = 'Recovered from a rift ledge in a cocoon of mineral frost. Something inside them hates the pressure changes.' } },
                    { template = 'herald_captive', weight = 15, overrides = { source = 'the deep rift' } },
                    { template = 'node_sample', weight = 30, overrides = { source = 'a living rift growth' } },
                    { template = 'signal_idol', weight = 20, overrides = { source = 'a signal chamber under the rift' } },
                },
            },
            partial = {
                min = 1, max = 1,
                entries = {
                    { template = 'vessel_host', weight = 30, overrides = { source = 'the lip of the deep rift' } },
                    { template = 'node_sample', weight = 45, overrides = { source = 'a rift growth seam' } },
                    { template = 'resonant_shard', weight = 25, overrides = { source = 'the deep rift' } },
                },
            },
        },
        rewards     = {
            success = {
                { item = 'thermal_core', min = 8,  max = 20, weight = 20 },
                { item = 'steel',        min = 5,  max = 12, weight = 20 },
                { item = 'circuit',      min = 3,  max = 6,  weight = 15 },
                { item = 'components',   min = 4,  max = 8,  weight = 15 },
                { item = 'fuel_cell',    min = 3,  max = 6,  weight = 10 },
                { item = 'weapon_bolt_action', min = 1, max = 1, weight = 10 },
                { item = 'insulation',   min = 3,  max = 6,  weight = 10 },
            },
            partial = {
                { item = 'thermal_core', min = 2, max = 6, weight = 30 },
                { item = 'steel',        min = 1, max = 4, weight = 35 },
                { item = 'components',   min = 1, max = 3, weight = 35 },
            },
        },
    },

    ancient_ruins = {
        name        = 'Precursor Site',
        description = 'Alien structures beneath the ice. Precursor artifacts and research data.',
        risk        = 4,
        minParty    = 2,
        duration    = 210,
        findings    = {
            success = {
                min = 1, max = 2,
                entries = {
                    { template = 'signal_idol', weight = 35, overrides = { source = 'a sealed precursor altar' } },
                    { template = 'resonant_shard', weight = 35, overrides = { source = 'a precursor vault' } },
                    { template = 'latent_survivor', weight = 20, overrides = { source = 'a precursor sleep chamber', desc = 'A survivor dragged from a ruin pod. They know doors your colony has not found yet.' } },
                    { template = 'mimic_tissue', weight = 10, overrides = { source = 'a false body in the ruins' } },
                },
            },
            partial = {
                min = 1, max = 1,
                entries = {
                    { template = 'resonant_shard', weight = 45, overrides = { source = 'a cracked precursor cache' } },
                    { template = 'signal_idol', weight = 25, overrides = { source = 'a precursor signal nest' } },
                    { template = 'latent_survivor', weight = 30, overrides = { source = 'a collapsed ruin chamber' } },
                },
            },
        },
        rewards     = {
            success = {
                { item = 'circuit',      min = 3, max = 7,  weight = 25 },
                { item = 'components',   min = 3, max = 8,  weight = 20 },
                { item = 'steel',        min = 2, max = 6,  weight = 15 },
                { item = 'glass',        min = 2, max = 5,  weight = 15 },
                { item = 'insulation',   min = 2, max = 5,  weight = 10 },
                { item = 'thermal_core', min = 3, max = 8,  weight = 10 },
                { item = 'medicine',     min = 2, max = 4,  weight = 5 },
            },
            partial = {
                { item = 'circuit',    min = 1, max = 3, weight = 30 },
                { item = 'components', min = 1, max = 3, weight = 35 },
                { item = 'steel',      min = 1, max = 3, weight = 35 },
            },
        },
    },
}

---------------------------------------------------------------------------
-- RHEA-2 — Desert world destinations
---------------------------------------------------------------------------

local RHEA2_DESTINATIONS = {
    sand_sweep = {
        name        = 'Dune Sweep',
        description = 'Surface sweep across open dunes. Basic salvage under the sand.',
        risk        = 1,
        minParty    = 1,
        duration    = 30,
        rewards     = {
            success = {
                { item = 'raw_stone',   min = 5,  max = 12, weight = 30 },
                { item = 'sand',        min = 8,  max = 20, weight = 25 },
                { item = 'raw_water',   min = 2,  max = 6,  weight = 20 },
                { item = 'raw_ore',     min = 2,  max = 5,  weight = 15 },
                { item = 'plant_fiber', min = 1,  max = 3,  weight = 10 },
            },
            partial = {
                { item = 'raw_stone', min = 2, max = 5, weight = 40 },
                { item = 'sand',      min = 3, max = 8, weight = 35 },
                { item = 'raw_water', min = 1, max = 2, weight = 25 },
            },
        },
    },

    canyon_run = {
        name        = 'Canyon Expedition',
        description = 'Narrow canyon network. Ore veins exposed in the walls. Watch for ambushes.',
        risk        = 2,
        minParty    = 1,
        duration    = 60,
        rewards     = {
            success = {
                { item = 'raw_ore',     min = 6, max = 15, weight = 30 },
                { item = 'metal_ingot', min = 2, max = 6,  weight = 25 },
                { item = 'raw_stone',   min = 4, max = 10, weight = 20 },
                { item = 'coal',        min = 2, max = 5,  weight = 15 },
                { item = 'raw_water',   min = 1, max = 3,  weight = 10 },
            },
            partial = {
                { item = 'raw_ore',     min = 2, max = 6, weight = 40 },
                { item = 'metal_ingot', min = 1, max = 3, weight = 30 },
                { item = 'raw_stone',   min = 1, max = 4, weight = 30 },
            },
        },
    },

    oasis_search = {
        name        = 'Oasis Search',
        description = 'Follow dry riverbeds toward rumored water sources. Wildlife clusters there.',
        risk        = 2,
        minParty    = 1,
        duration    = 75,
        rewards     = {
            success = {
                { item = 'raw_water',   min = 6, max = 15, weight = 30 },
                { item = 'food',        min = 4, max = 10, weight = 25 },
                { item = 'raw_hide',    min = 3, max = 8,  weight = 20 },
                { item = 'plant_fiber', min = 2, max = 5,  weight = 15 },
                { item = 'raw_meat',    min = 2, max = 5,  weight = 10 },
            },
            partial = {
                { item = 'raw_water', min = 2, max = 6, weight = 40 },
                { item = 'food',      min = 1, max = 4, weight = 30 },
                { item = 'raw_hide',  min = 1, max = 3, weight = 30 },
            },
        },
    },

    ruins_dig = {
        name        = 'Buried Ruins',
        description = 'Sand-covered precursor structures. High-value salvage beneath the dunes.',
        risk        = 3,
        minParty    = 2,
        duration    = 120,
        rewards     = {
            success = {
                { item = 'components',   min = 3, max = 8,  weight = 25 },
                { item = 'circuit',      min = 2, max = 5,  weight = 25 },
                { item = 'thermal_core', min = 2, max = 5,  weight = 20 },
                { item = 'metal_ingot',  min = 2, max = 6,  weight = 15 },
                { item = 'glass',        min = 1, max = 3,  weight = 15 },
            },
            partial = {
                { item = 'components',  min = 1, max = 3, weight = 35 },
                { item = 'circuit',     min = 1, max = 2, weight = 30 },
                { item = 'metal_ingot', min = 1, max = 3, weight = 35 },
            },
        },
    },

    sun_temple = {
        name        = 'Sun Temple',
        description = 'Precursor solar shrine. Dangerous guardians protect high-value artifacts.',
        risk        = 4,
        minParty    = 2,
        duration    = 180,
        rewards     = {
            success = {
                { item = 'components',   min = 4, max = 10, weight = 25 },
                { item = 'steel',        min = 3, max = 8,  weight = 20 },
                { item = 'circuit',      min = 2, max = 5,  weight = 20 },
                { item = 'glass',        min = 2, max = 6,  weight = 15 },
                { item = 'thermal_core', min = 3, max = 7,  weight = 10 },
                { item = 'medicine',     min = 1, max = 3,  weight = 10 },
            },
            partial = {
                { item = 'components', min = 1, max = 4, weight = 35 },
                { item = 'steel',      min = 1, max = 3, weight = 35 },
                { item = 'circuit',    min = 1, max = 2, weight = 30 },
            },
        },
    },

    deep_aquifer = {
        name        = 'Deep Aquifer',
        description = 'A vast underground water source. Extremely deep excavation through unstable sand.',
        risk        = 5,
        minParty    = 3,
        duration    = 300,
        rewards     = {
            success = {
                { item = 'raw_water',    min = 15, max = 35, weight = 25 },
                { item = 'raw_ice',      min = 8,  max = 20, weight = 20 },
                { item = 'raw_ore',      min = 6,  max = 15, weight = 15 },
                { item = 'thermal_core', min = 3,  max = 8,  weight = 15 },
                { item = 'steel',        min = 2,  max = 6,  weight = 10 },
                { item = 'components',   min = 2,  max = 5,  weight = 10 },
                { item = 'circuit',      min = 1,  max = 3,  weight = 5 },
            },
            partial = {
                { item = 'raw_water', min = 5, max = 12, weight = 40 },
                { item = 'raw_ice',   min = 2, max = 8,  weight = 30 },
                { item = 'raw_ore',   min = 2, max = 6,  weight = 30 },
            },
        },
    },
}

---------------------------------------------------------------------------
-- MORVOS — Acid world destinations
---------------------------------------------------------------------------

local MORVOS_DESTINATIONS = {
    acid_flats = {
        name        = 'Acid Flats',
        description = 'Corroded surface landscape. Salvageable metal and stone among the pools.',
        risk        = 1,
        minParty    = 1,
        duration    = 30,
        rewards     = {
            success = {
                { item = 'raw_stone',   min = 5,  max = 12, weight = 30 },
                { item = 'metal_ingot', min = 2,  max = 6,  weight = 25 },
                { item = 'raw_ore',     min = 3,  max = 8,  weight = 20 },
                { item = 'coal',        min = 2,  max = 5,  weight = 15 },
                { item = 'pipe',        min = 1,  max = 2,  weight = 10 },
            },
            partial = {
                { item = 'raw_stone',   min = 2, max = 5, weight = 40 },
                { item = 'metal_ingot', min = 1, max = 3, weight = 30 },
                { item = 'raw_ore',     min = 1, max = 3, weight = 30 },
            },
        },
    },

    fungal_forest = {
        name        = 'Fungal Forest',
        description = 'Dense fungal growth zone. Edible species and medicinal compounds.',
        risk        = 2,
        minParty    = 1,
        duration    = 60,
        rewards     = {
            success = {
                { item = 'food',            min = 6, max = 15, weight = 30 },
                { item = 'medicinal_herb',  min = 3, max = 8,  weight = 25 },
                { item = 'plant_fiber',     min = 4, max = 10, weight = 20 },
                { item = 'raw_hide',        min = 2, max = 5,  weight = 15 },
                { item = 'raw_meat',        min = 1, max = 4,  weight = 10 },
            },
            partial = {
                { item = 'food',           min = 2, max = 6, weight = 40 },
                { item = 'medicinal_herb', min = 1, max = 3, weight = 30 },
                { item = 'plant_fiber',    min = 1, max = 4, weight = 30 },
            },
        },
    },

    sealed_bunker = {
        name        = 'Sealed Bunker',
        description = 'Pre-collapse bunker sealed against the acid. Hardware and weapons inside.',
        risk        = 3,
        minParty    = 2,
        duration    = 90,
        rewards     = {
            success = {
                { item = 'components',   min = 3, max = 8,  weight = 25 },
                { item = 'metal_ingot',  min = 4, max = 10, weight = 25 },
                { item = 'weapon_spear', min = 1, max = 2,  weight = 15 },
                { item = 'cloth',        min = 2, max = 5,  weight = 15 },
                { item = 'circuit',      min = 1, max = 3,  weight = 10 },
                { item = 'medicine',     min = 1, max = 3,  weight = 10 },
            },
            partial = {
                { item = 'metal_ingot', min = 2, max = 5, weight = 35 },
                { item = 'components',  min = 1, max = 3, weight = 35 },
                { item = 'cloth',       min = 1, max = 3, weight = 30 },
            },
        },
    },

    spore_caves = {
        name        = 'Spore Caves',
        description = 'Bioluminescent cave system. Organic matter and strange biological samples.',
        risk        = 3,
        minParty    = 2,
        duration    = 120,
        rewards     = {
            success = {
                { item = 'eldritch_ichor', min = 2, max = 6,  weight = 25 },
                { item = 'raw_hide',       min = 4, max = 10, weight = 25 },
                { item = 'food',           min = 3, max = 8,  weight = 20 },
                { item = 'medicinal_herb', min = 2, max = 5,  weight = 15 },
                { item = 'plant_fiber',    min = 2, max = 6,  weight = 15 },
            },
            partial = {
                { item = 'eldritch_ichor', min = 1, max = 2, weight = 30 },
                { item = 'raw_hide',       min = 1, max = 4, weight = 35 },
                { item = 'food',           min = 1, max = 3, weight = 35 },
            },
        },
    },

    acid_lake = {
        name        = 'Acid Lake Shore',
        description = 'Edge of a vast acid lake. Fuel deposits and rare chemical compounds.',
        risk        = 4,
        minParty    = 2,
        duration    = 180,
        rewards     = {
            success = {
                { item = 'fuel_cell',    min = 3, max = 8,  weight = 25 },
                { item = 'glass',        min = 3, max = 7,  weight = 20 },
                { item = 'coal',         min = 4, max = 10, weight = 20 },
                { item = 'steel',        min = 2, max = 6,  weight = 15 },
                { item = 'components',   min = 2, max = 5,  weight = 10 },
                { item = 'thermal_core', min = 1, max = 4,  weight = 10 },
            },
            partial = {
                { item = 'fuel_cell', min = 1, max = 3, weight = 35 },
                { item = 'glass',     min = 1, max = 3, weight = 30 },
                { item = 'coal',      min = 2, max = 5, weight = 35 },
            },
        },
    },
}

---------------------------------------------------------------------------
-- NERTHUS-9 — Ocean world destinations
---------------------------------------------------------------------------

local NERTHUS9_DESTINATIONS = {
    reef_dive = {
        name        = 'Reef Dive',
        description = 'Shallow reef exploration. Coral, fish, and fresh water.',
        risk        = 1,
        minParty    = 1,
        duration    = 30,
        rewards     = {
            success = {
                { item = 'food',      min = 6,  max = 15, weight = 30 },
                { item = 'raw_stone', min = 4,  max = 10, weight = 25 },
                { item = 'raw_water', min = 3,  max = 8,  weight = 20 },
                { item = 'raw_hide',  min = 2,  max = 5,  weight = 15 },
                { item = 'raw_meat',  min = 1,  max = 4,  weight = 10 },
            },
            partial = {
                { item = 'food',      min = 2, max = 6, weight = 40 },
                { item = 'raw_stone', min = 1, max = 4, weight = 30 },
                { item = 'raw_water', min = 1, max = 3, weight = 30 },
            },
        },
    },

    island_hop = {
        name        = 'Island Hop',
        description = 'Navigate between volcanic islands. Timber, stone, and wildlife.',
        risk        = 2,
        minParty    = 1,
        duration    = 75,
        rewards     = {
            success = {
                { item = 'raw_wood',  min = 6, max = 15, weight = 30 },
                { item = 'raw_stone', min = 4, max = 10, weight = 25 },
                { item = 'food',      min = 3, max = 8,  weight = 20 },
                { item = 'raw_hide',  min = 2, max = 5,  weight = 15 },
                { item = 'raw_meat',  min = 2, max = 5,  weight = 10 },
            },
            partial = {
                { item = 'raw_wood',  min = 2, max = 6, weight = 40 },
                { item = 'raw_stone', min = 1, max = 4, weight = 30 },
                { item = 'food',      min = 1, max = 3, weight = 30 },
            },
        },
    },

    wreck_dive = {
        name        = 'Shipwreck Dive',
        description = 'Submerged vessel on the seabed. Metal and components. Need diving gear.',
        risk        = 3,
        minParty    = 2,
        duration    = 120,
        rewards     = {
            success = {
                { item = 'metal_ingot',  min = 4, max = 10, weight = 25 },
                { item = 'components',   min = 3, max = 7,  weight = 25 },
                { item = 'weapon_spear', min = 1, max = 2,  weight = 15 },
                { item = 'cloth',        min = 2, max = 6,  weight = 15 },
                { item = 'circuit',      min = 1, max = 3,  weight = 10 },
                { item = 'pipe',         min = 1, max = 3,  weight = 10 },
            },
            partial = {
                { item = 'metal_ingot', min = 1, max = 4, weight = 35 },
                { item = 'components',  min = 1, max = 3, weight = 35 },
                { item = 'cloth',       min = 1, max = 3, weight = 30 },
            },
        },
    },

    deep_trench = {
        name        = 'Deep Trench',
        description = 'Descent into an ocean trench. Extreme pressure. Thermal vents and rare minerals.',
        risk        = 4,
        minParty    = 2,
        duration    = 180,
        rewards     = {
            success = {
                { item = 'thermal_core', min = 4, max = 10, weight = 25 },
                { item = 'metal_ingot',  min = 3, max = 8,  weight = 20 },
                { item = 'circuit',      min = 2, max = 5,  weight = 20 },
                { item = 'raw_ore',      min = 4, max = 10, weight = 15 },
                { item = 'steel',        min = 2, max = 5,  weight = 10 },
                { item = 'components',   min = 2, max = 5,  weight = 10 },
            },
            partial = {
                { item = 'thermal_core', min = 1, max = 4, weight = 35 },
                { item = 'metal_ingot',  min = 1, max = 3, weight = 30 },
                { item = 'raw_ore',      min = 1, max = 4, weight = 35 },
            },
        },
    },

    volcanic_vent = {
        name        = 'Volcanic Vent',
        description = 'Active undersea volcano. Lethal heat but incredible mineral deposits.',
        risk        = 5,
        minParty    = 3,
        duration    = 300,
        rewards     = {
            success = {
                { item = 'steel',        min = 5,  max = 12, weight = 20 },
                { item = 'fuel_cell',    min = 3,  max = 8,  weight = 20 },
                { item = 'thermal_core', min = 5,  max = 12, weight = 20 },
                { item = 'components',   min = 3,  max = 7,  weight = 15 },
                { item = 'circuit',      min = 2,  max = 5,  weight = 10 },
                { item = 'raw_ore',      min = 5,  max = 12, weight = 10 },
                { item = 'glass',        min = 2,  max = 5,  weight = 5 },
            },
            partial = {
                { item = 'steel',        min = 2, max = 5, weight = 35 },
                { item = 'thermal_core', min = 1, max = 4, weight = 30 },
                { item = 'fuel_cell',    min = 1, max = 3, weight = 35 },
            },
        },
    },

    thalassa_approach = {
        name        = 'Thalassa Deep Approach',
        description = 'The prison is miles below the surface. The approach alone is deadly. Descent pods have a 50% implosion rate.',
        risk        = 5,
        minParty    = 3,
        duration    = 150,
        rewards     = {
            success = {
                { item = 'thermal_core', min = 10, max = 20, weight = 25 },
                { item = 'circuit',      min = 5,  max = 10, weight = 25 },
                { item = 'components',   min = 4,  max = 10, weight = 20 },
                { item = 'steel',        min = 3,  max = 8,  weight = 15 },
                { item = 'medicine',     min = 2,  max = 5,  weight = 15 },
            },
            partial = {
                { item = 'thermal_core', min = 3, max = 8, weight = 35 },
                { item = 'circuit',      min = 1, max = 4, weight = 35 },
                { item = 'components',   min = 1, max = 4, weight = 30 },
            },
        },
    },
}

---------------------------------------------------------------------------
-- PAXTERA PRIME — Temperate world destinations
---------------------------------------------------------------------------

local PAXTERA_DESTINATIONS = {
    meadow_forage = {
        name        = 'Meadow Forage',
        description = 'Open grassland sweep. Food, hides, and timber at the tree line.',
        risk        = 1,
        minParty    = 1,
        duration    = 30,
        rewards     = {
            success = {
                { item = 'food',      min = 6,  max = 15, weight = 30 },
                { item = 'raw_hide',  min = 3,  max = 8,  weight = 25 },
                { item = 'raw_wood',  min = 4,  max = 10, weight = 20 },
                { item = 'raw_meat',  min = 2,  max = 5,  weight = 15 },
                { item = 'plant_fiber', min = 2, max = 5, weight = 10 },
            },
            partial = {
                { item = 'food',     min = 2, max = 6, weight = 40 },
                { item = 'raw_hide', min = 1, max = 3, weight = 30 },
                { item = 'raw_wood', min = 1, max = 4, weight = 30 },
            },
        },
    },

    forest_expedition = {
        name        = 'Forest Expedition',
        description = 'Dense woodland trek. Timber, foraging, and medicinal plants.',
        risk        = 2,
        minParty    = 1,
        duration    = 60,
        rewards     = {
            success = {
                { item = 'raw_wood',       min = 8, max = 20, weight = 30 },
                { item = 'food',           min = 4, max = 10, weight = 25 },
                { item = 'medicinal_herb', min = 3, max = 7,  weight = 20 },
                { item = 'raw_hide',       min = 2, max = 5,  weight = 15 },
                { item = 'plant_fiber',    min = 2, max = 6,  weight = 10 },
            },
            partial = {
                { item = 'raw_wood',       min = 3, max = 8, weight = 40 },
                { item = 'food',           min = 1, max = 4, weight = 30 },
                { item = 'medicinal_herb', min = 1, max = 3, weight = 30 },
            },
        },
    },

    hill_mine = {
        name        = 'Hill Quarry',
        description = 'Open-pit quarry in the hills. Stone, ore, and metal deposits.',
        risk        = 2,
        minParty    = 1,
        duration    = 75,
        rewards     = {
            success = {
                { item = 'raw_stone',   min = 6, max = 15, weight = 30 },
                { item = 'metal_ingot', min = 3, max = 8,  weight = 25 },
                { item = 'raw_ore',     min = 4, max = 10, weight = 20 },
                { item = 'coal',        min = 2, max = 5,  weight = 15 },
                { item = 'raw_wood',    min = 1, max = 3,  weight = 10 },
            },
            partial = {
                { item = 'raw_stone',   min = 2, max = 6, weight = 40 },
                { item = 'metal_ingot', min = 1, max = 3, weight = 30 },
                { item = 'raw_ore',     min = 1, max = 4, weight = 30 },
            },
        },
    },

    raider_camp = {
        name        = 'Raider Camp',
        description = 'Hostile camp in the hills. Weapons and salvage if you can take it.',
        risk        = 3,
        minParty    = 2,
        duration    = 90,
        rewards     = {
            success = {
                { item = 'metal_ingot',  min = 4, max = 10, weight = 25 },
                { item = 'weapon_spear', min = 1, max = 2,  weight = 20 },
                { item = 'components',   min = 2, max = 5,  weight = 20 },
                { item = 'cloth',        min = 3, max = 8,  weight = 15 },
                { item = 'food',         min = 3, max = 8,  weight = 10 },
                { item = 'medicine',     min = 1, max = 3,  weight = 10 },
            },
            partial = {
                { item = 'metal_ingot', min = 1, max = 4, weight = 35 },
                { item = 'components',  min = 1, max = 2, weight = 30 },
                { item = 'cloth',       min = 1, max = 3, weight = 35 },
            },
        },
    },

    old_settlement = {
        name        = 'Old Settlement',
        description = 'Ruins of a prior colony. Building materials, hardware, and electronics.',
        risk        = 3,
        minParty    = 2,
        duration    = 120,
        rewards     = {
            success = {
                { item = 'raw_wood',    min = 5, max = 12, weight = 20 },
                { item = 'metal_ingot', min = 4, max = 10, weight = 20 },
                { item = 'components',  min = 3, max = 7,  weight = 20 },
                { item = 'circuit',     min = 1, max = 3,  weight = 15 },
                { item = 'lumber',      min = 3, max = 8,  weight = 15 },
                { item = 'glass',       min = 1, max = 3,  weight = 10 },
            },
            partial = {
                { item = 'raw_wood',    min = 2, max = 5, weight = 30 },
                { item = 'metal_ingot', min = 1, max = 4, weight = 35 },
                { item = 'components',  min = 1, max = 3, weight = 35 },
            },
        },
    },
}

---------------------------------------------------------------------------
-- NEMAEA — Dead world destinations
---------------------------------------------------------------------------

local NEMAEA_DESTINATIONS = {
    surface_sweep = {
        name        = 'Surface Sweep',
        description = 'Regolith plains scavenging. Metal debris and crushed rock under vacuum.',
        risk        = 2,
        minParty    = 1,
        duration    = 45,
        rewards     = {
            success = {
                { item = 'metal_ingot', min = 4, max = 10, weight = 30 },
                { item = 'raw_stone',   min = 3, max = 8,  weight = 25 },
                { item = 'raw_ore',     min = 3, max = 8,  weight = 20 },
                { item = 'pipe',        min = 1, max = 3,  weight = 15 },
                { item = 'coal',        min = 1, max = 3,  weight = 10 },
            },
            partial = {
                { item = 'metal_ingot', min = 1, max = 4, weight = 40 },
                { item = 'raw_stone',   min = 1, max = 3, weight = 30 },
                { item = 'raw_ore',     min = 1, max = 3, weight = 30 },
            },
        },
    },

    wreckage_field = {
        name        = 'Wreckage Field',
        description = 'Ship debris field. Components, hull plating, and intact circuits.',
        risk        = 3,
        minParty    = 2,
        duration    = 90,
        rewards     = {
            success = {
                { item = 'components', min = 4, max = 10, weight = 25 },
                { item = 'steel',      min = 3, max = 8,  weight = 25 },
                { item = 'circuit',    min = 2, max = 5,  weight = 20 },
                { item = 'pipe',       min = 2, max = 5,  weight = 15 },
                { item = 'glass',      min = 1, max = 3,  weight = 15 },
            },
            partial = {
                { item = 'components', min = 1, max = 4, weight = 35 },
                { item = 'steel',      min = 1, max = 3, weight = 35 },
                { item = 'circuit',    min = 1, max = 2, weight = 30 },
            },
        },
    },

    automaton_graveyard = {
        name        = 'Automaton Graveyard',
        description = 'Deactivated automaton pile. Salvageable metal, components, and lead shielding.',
        risk        = 3,
        minParty    = 2,
        duration    = 120,
        rewards     = {
            success = {
                { item = 'metal_ingot', min = 5, max = 12, weight = 25 },
                { item = 'components',  min = 3, max = 8,  weight = 25 },
                { item = 'circuit',     min = 2, max = 5,  weight = 20 },
                { item = 'steel',       min = 2, max = 6,  weight = 15 },
                { item = 'pipe',        min = 1, max = 3,  weight = 15 },
            },
            partial = {
                { item = 'metal_ingot', min = 2, max = 5, weight = 35 },
                { item = 'components',  min = 1, max = 3, weight = 35 },
                { item = 'circuit',     min = 1, max = 2, weight = 30 },
            },
        },
    },

    dyson_fragment = {
        name        = 'Dyson Fragment',
        description = 'Fallen Dyson Sphere segment. Extreme radiation but incredible technology.',
        risk        = 4,
        minParty    = 2,
        duration    = 210,
        rewards     = {
            success = {
                { item = 'steel',        min = 4, max = 10, weight = 20 },
                { item = 'circuit',      min = 3, max = 7,  weight = 25 },
                { item = 'glass',        min = 3, max = 8,  weight = 20 },
                { item = 'thermal_core', min = 3, max = 8,  weight = 15 },
                { item = 'components',   min = 2, max = 5,  weight = 10 },
                { item = 'insulation',   min = 2, max = 5,  weight = 10 },
            },
            partial = {
                { item = 'steel',   min = 1, max = 4, weight = 35 },
                { item = 'circuit', min = 1, max = 3, weight = 35 },
                { item = 'glass',   min = 1, max = 3, weight = 30 },
            },
        },
    },

    deep_vault = {
        name        = 'Deep Vault',
        description = 'Sealed underground installation. Heavy automaton presence. Maximum salvage.',
        risk        = 5,
        minParty    = 3,
        duration    = 300,
        rewards     = {
            success = {
                { item = 'components',   min = 8,  max = 18, weight = 20 },
                { item = 'circuit',      min = 4,  max = 10, weight = 20 },
                { item = 'steel',        min = 5,  max = 12, weight = 15 },
                { item = 'weapon_bolt_action', min = 1, max = 2, weight = 10 },
                { item = 'thermal_core', min = 3,  max = 8,  weight = 10 },
                { item = 'glass',        min = 2,  max = 5,  weight = 10 },
                { item = 'insulation',   min = 2,  max = 5,  weight = 10 },
                { item = 'medicine',     min = 2,  max = 4,  weight = 5 },
            },
            partial = {
                { item = 'components', min = 2, max = 6, weight = 35 },
                { item = 'circuit',    min = 1, max = 4, weight = 35 },
                { item = 'steel',      min = 1, max = 4, weight = 30 },
            },
        },
    },
}

---------------------------------------------------------------------------
-- GAIA A^1x — Lush world destinations
---------------------------------------------------------------------------

local GAIA_DESTINATIONS = {
    meadow_gather = {
        name        = 'Meadow Gathering',
        description = 'Open meadow harvest. Abundant food, timber, and small game.',
        risk        = 1,
        minParty    = 1,
        duration    = 30,
        rewards     = {
            success = {
                { item = 'food',      min = 8,  max = 20, weight = 30 },
                { item = 'raw_wood',  min = 5,  max = 12, weight = 25 },
                { item = 'raw_hide',  min = 3,  max = 8,  weight = 20 },
                { item = 'raw_meat',  min = 2,  max = 6,  weight = 15 },
                { item = 'plant_fiber', min = 2, max = 5, weight = 10 },
            },
            partial = {
                { item = 'food',     min = 3, max = 8, weight = 40 },
                { item = 'raw_wood', min = 2, max = 5, weight = 30 },
                { item = 'raw_hide', min = 1, max = 3, weight = 30 },
            },
        },
    },

    river_valley = {
        name        = 'River Valley',
        description = 'Follow the river downstream. Fresh water, fish, and stone deposits.',
        risk        = 2,
        minParty    = 1,
        duration    = 60,
        rewards     = {
            success = {
                { item = 'raw_water', min = 6, max = 15, weight = 30 },
                { item = 'food',      min = 4, max = 10, weight = 25 },
                { item = 'raw_stone', min = 4, max = 10, weight = 20 },
                { item = 'raw_meat',  min = 2, max = 6,  weight = 15 },
                { item = 'raw_hide',  min = 1, max = 4,  weight = 10 },
            },
            partial = {
                { item = 'raw_water', min = 2, max = 6, weight = 40 },
                { item = 'food',      min = 1, max = 4, weight = 30 },
                { item = 'raw_stone', min = 1, max = 4, weight = 30 },
            },
        },
    },

    deep_woods = {
        name        = 'Deep Woods',
        description = 'Ancient forest interior. Massive timber, rare herbs, and hidden clearings.',
        risk        = 2,
        minParty    = 1,
        duration    = 75,
        rewards     = {
            success = {
                { item = 'raw_wood',       min = 8, max = 20, weight = 30 },
                { item = 'food',           min = 4, max = 10, weight = 20 },
                { item = 'medicinal_herb', min = 3, max = 8,  weight = 25 },
                { item = 'raw_hide',       min = 2, max = 5,  weight = 15 },
                { item = 'plant_fiber',    min = 2, max = 5,  weight = 10 },
            },
            partial = {
                { item = 'raw_wood',       min = 3, max = 8, weight = 40 },
                { item = 'medicinal_herb', min = 1, max = 3, weight = 30 },
                { item = 'food',           min = 1, max = 4, weight = 30 },
            },
        },
    },

    corruption_edge = {
        name        = 'Corruption Edge',
        description = 'Border of Baldrungen corruption. Dangerous creatures guard strange biological matter.',
        risk        = 4,
        minParty    = 2,
        duration    = 180,
        rewards     = {
            success = {
                { item = 'eldritch_ichor', min = 3, max = 8,  weight = 25 },
                { item = 'raw_hide',       min = 4, max = 10, weight = 20 },
                { item = 'chitin_plate',   min = 2, max = 6,  weight = 20 },
                { item = 'raw_meat',       min = 3, max = 8,  weight = 15 },
                { item = 'medicinal_herb', min = 2, max = 5,  weight = 10 },
                { item = 'food',           min = 2, max = 5,  weight = 10 },
            },
            partial = {
                { item = 'eldritch_ichor', min = 1, max = 3, weight = 30 },
                { item = 'raw_hide',       min = 1, max = 4, weight = 35 },
                { item = 'chitin_plate',   min = 1, max = 2, weight = 35 },
            },
        },
    },

    heart_chamber = {
        name        = 'Heart Chamber',
        description = 'Deep Baldrungen lair. Void crystals and organic horror. Few return unchanged.',
        risk        = 5,
        minParty    = 3,
        duration    = 300,
        rewards     = {
            success = {
                { item = 'void_crystal',   min = 2, max = 5,  weight = 20 },
                { item = 'eldritch_ichor', min = 5, max = 12, weight = 20 },
                { item = 'raw_fat',        min = 4, max = 10, weight = 15 },
                { item = 'chitin_plate',   min = 3, max = 8,  weight = 15 },
                { item = 'raw_hide',       min = 3, max = 8,  weight = 10 },
                { item = 'thermal_core',   min = 2, max = 5,  weight = 10 },
                { item = 'medicinal_herb', min = 2, max = 5,  weight = 10 },
            },
            partial = {
                { item = 'eldritch_ichor', min = 2, max = 5, weight = 35 },
                { item = 'void_crystal',   min = 1, max = 2, weight = 30 },
                { item = 'raw_fat',        min = 1, max = 4, weight = 35 },
            },
        },
    },

    maw_of_foras = {
        name        = 'The Maw of Foras',
        description = 'The crater at the heart of the dead colony. Wind rises from the depths. Nobody comes back the same.',
        risk        = 5,
        minParty    = 2,
        duration    = 120,
        rewards     = {
            success = {
                { item = 'thermal_core', min = 8,  max = 15, weight = 25 },
                { item = 'components',   min = 5,  max = 12, weight = 25 },
                { item = 'circuit',      min = 3,  max = 7,  weight = 20 },
                { item = 'steel',        min = 3,  max = 8,  weight = 15 },
                { item = 'eldritch_ichor', min = 2, max = 5, weight = 15 },
            },
            partial = {
                { item = 'thermal_core', min = 2, max = 6, weight = 35 },
                { item = 'components',   min = 1, max = 5, weight = 35 },
                { item = 'steel',        min = 1, max = 3, weight = 30 },
            },
        },
    },

    acedia_ruins = {
        name        = 'Acedia Ruins',
        description = 'The City of Rot. Sixty years of decay. Supplies left behind by people who could not carry them.',
        risk        = 3,
        minParty    = 1,
        duration    = 80,
        rewards     = {
            success = {
                { item = 'food',           min = 10, max = 25, weight = 30 },
                { item = 'medicine',       min = 3,  max = 8,  weight = 20 },
                { item = 'metal_ingot',    min = 4,  max = 10, weight = 20 },
                { item = 'cloth',          min = 3,  max = 8,  weight = 15 },
                { item = 'components',     min = 2,  max = 5,  weight = 15 },
            },
            partial = {
                { item = 'food',        min = 3, max = 10, weight = 40 },
                { item = 'medicine',    min = 1, max = 3,  weight = 30 },
                { item = 'metal_ingot', min = 1, max = 4,  weight = 30 },
            },
        },
    },

    nyxport_docks = {
        name        = 'Nyxport Docks',
        description = 'The port where the desperate fled. Warehouses, flooded streets, and the ghosts of everyone who did not make it.',
        risk        = 4,
        minParty    = 2,
        duration    = 100,
        rewards     = {
            success = {
                { item = 'metal_ingot',  min = 10, max = 20, weight = 25 },
                { item = 'steel',        min = 5,  max = 12, weight = 25 },
                { item = 'components',   min = 3,  max = 8,  weight = 20 },
                { item = 'pipe',         min = 2,  max = 6,  weight = 15 },
                { item = 'circuit',      min = 1,  max = 4,  weight = 15 },
            },
            partial = {
                { item = 'metal_ingot', min = 3, max = 8, weight = 35 },
                { item = 'steel',       min = 1, max = 5, weight = 35 },
                { item = 'components',  min = 1, max = 3, weight = 30 },
            },
        },
    },
}

---------------------------------------------------------------------------
-- Planet destination lookup
---------------------------------------------------------------------------

local PLANET_DESTINATIONS = {
    erebus        = EREBUS_DESTINATIONS,
    rhea_2        = RHEA2_DESTINATIONS,
    morvos        = MORVOS_DESTINATIONS,
    nerthus_9     = NERTHUS9_DESTINATIONS,
    paxtera_prime = PAXTERA_DESTINATIONS,
    nemaea        = NEMAEA_DESTINATIONS,
    gaia_a1x      = GAIA_DESTINATIONS,
}

local function getActiveDestinations()
    local ok, GameState = pcall(require, 'src.game_state')
    local planet = ok and GameState.planet or 'erebus'
    return PLANET_DESTINATIONS[planet] or EREBUS_DESTINATIONS
end

-- Backward compatibility: point at current planet's table
Overworld.DESTINATIONS = getActiveDestinations()

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Overworld.getDestination(destId)
    local dests = getActiveDestinations()
    return dests[destId]
end

function Overworld.getAllDestinations()
    local dests = getActiveDestinations()
    local result = {}
    for id, dest in pairs(dests) do
        result[#result + 1] = { id = id, dest = dest }
    end
    table.sort(result, function(a, b) return a.dest.risk < b.dest.risk end)
    return result
end

-- Roll rewards from a reward tier table.
-- Returns a list of { itemId, amount } entries (2-4 reward rolls).
function Overworld.rollRewards(rewardTable)
    if not rewardTable or #rewardTable == 0 then return {} end

    local rewards = {}
    local rollCount = 2 + math.random(2) -- 2-4 reward entries

    -- Compute total weight once
    local totalWeight = 0
    for _, e in ipairs(rewardTable) do
        totalWeight = totalWeight + e.weight
    end

    for _ = 1, rollCount do
        local roll = math.random() * totalWeight
        local acc = 0
        for _, entry in ipairs(rewardTable) do
            acc = acc + entry.weight
            if roll <= acc then
                local amount = math.random(entry.min, entry.max)
                rewards[#rewards + 1] = { itemId = entry.item, amount = amount }
                break
            end
        end
    end

    return rewards
end

function Overworld.rollContainmentFinds(destId, outcome)
    local dests = getActiveDestinations()
    local dest = dests[destId]
    local pool = dest and dest.findings and dest.findings[outcome]
    if not pool or not pool.entries or #pool.entries == 0 then
        return {}
    end

    local countMin = pool.min or 1
    local countMax = pool.max or countMin
    local count = math.max(0, math.random(countMin, countMax))
    local results = {}

    for _ = 1, count do
        local picked = weightedPickEntry(pool.entries)
        if picked and picked.template then
            results[#results + 1] = {
                template = picked.template,
                overrides = copyOverrides(picked.overrides),
            }
        end
    end

    return results
end

return Overworld
