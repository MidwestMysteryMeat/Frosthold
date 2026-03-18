-- bosses.lua — Multi-phase boss encounters triggered by the storyteller.
-- Each boss has combat phases with escalating damage/abilities and
-- telegraphed attacks (1s warning). Unique drops on kill.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Creatures = require('src.creatures.creatures')
local Pathfind  = require('src.util.pathfind')
local Occupancy = require('src.util.occupancy')

local Bosses = {}

---------------------------------------------------------------------------
-- Boss definitions
---------------------------------------------------------------------------

local BOSS_DEFS = {
    frost_titan = {
        species     = 'frost_titan',
        name        = 'Frost Titan',
        health      = 500,
        baseDamage  = 50,
        speed       = 1.5,
        aggroRange  = 15,
        leashRange  = 60,    -- bosses have a very long leash
        color       = { 0.3, 0.35, 0.5 },
        size        = 2.0,

        -- Phase thresholds (fraction of max HP)
        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.50, name = 'enraged',   damageMult = 1.5, speedMult = 1.2 },
            { threshold = 0.25, name = 'desperate', damageMult = 2.0, speedMult = 1.0 },
        },

        -- Abilities per phase
        abilities = {
            normal = {
                { id = 'slam', cooldown = 8, radius = 3, damage = 30,
                  telegraph = 1.0, desc = 'The Frost Titan raises its fist!' },
            },
            enraged = {
                { id = 'slam', cooldown = 6, radius = 3, damage = 45,
                  telegraph = 1.0, desc = 'The Frost Titan raises its fist!' },
                { id = 'ground_pound', cooldown = 12, radius = 5, damage = 25,
                  telegraph = 1.0, desc = 'The ground shakes violently!' },
            },
            desperate = {
                { id = 'slam', cooldown = 4, radius = 3, damage = 55,
                  telegraph = 1.0, desc = 'The Frost Titan raises its fist!' },
                { id = 'ground_pound', cooldown = 8, radius = 5, damage = 35,
                  telegraph = 1.0, desc = 'The ground shakes violently!' },
                { id = 'ice_nova', cooldown = 15, radius = 7, damage = 20,
                  telegraph = 1.0, desc = 'Frost blast from the Titan!' },
            },
        },

        drop = { itemId = 'titan_heart', name = 'Titan Heart', amount = 1 },
    },

    thermal_wurm = {
        species     = 'thermal_wurm',
        name        = 'Thermal Wurm',
        health      = 400,
        baseDamage  = 40,
        speed       = 2.0,
        aggroRange  = 12,
        leashRange  = 50,
        color       = { 0.7, 0.3, 0.2 },
        size        = 1.8,

        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.50, name = 'enraged',   damageMult = 1.4, speedMult = 1.5 },
            { threshold = 0.25, name = 'desperate', damageMult = 1.8, speedMult = 1.3 },
        },

        abilities = {
            normal = {
                { id = 'fire_breath', cooldown = 10, radius = 4, damage = 35,
                  telegraph = 1.0, desc = 'The Wurm rears back, heat shimmering!' },
            },
            enraged = {
                { id = 'fire_breath', cooldown = 7, radius = 4, damage = 45,
                  telegraph = 1.0, desc = 'The Wurm rears back, heat shimmering!' },
                { id = 'burrow', cooldown = 15, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'The Wurm dives underground!' },
            },
            desperate = {
                { id = 'fire_breath', cooldown = 5, radius = 5, damage = 55,
                  telegraph = 1.0, desc = 'The Wurm rears back, heat shimmering!' },
                { id = 'burrow', cooldown = 10, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'The Wurm dives underground!' },
                { id = 'eruption', cooldown = 20, radius = 6, damage = 40,
                  telegraph = 1.0, desc = 'Magma erupts from the ground!' },
            },
        },

        drop = { itemId = 'wurm_scale', name = 'Wurm Scale', amount = 1 },
    },

    glacial_leviathan = {
        species     = 'glacial_leviathan',
        name        = 'Glacial Leviathan',
        health      = 800,
        baseDamage  = 70,
        speed       = 1.0,
        aggroRange  = 20,
        leashRange  = 60,
        color       = { 0.2, 0.25, 0.45 },
        size        = 2.5,

        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.50, name = 'enraged',   damageMult = 1.3, speedMult = 1.1 },
            { threshold = 0.25, name = 'desperate', damageMult = 1.6, speedMult = 0.8 },
        },

        abilities = {
            normal = {
                { id = 'ice_armor', cooldown = 20, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'Ice crystallizes around the Leviathan!' },
            },
            enraged = {
                { id = 'ice_armor', cooldown = 15, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'Ice crystallizes around the Leviathan!' },
                { id = 'tail_sweep', cooldown = 8, radius = 4, damage = 40,
                  telegraph = 1.0, desc = 'The Leviathan coils for a sweeping blow!' },
            },
            desperate = {
                { id = 'ice_armor', cooldown = 12, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'Ice crystallizes around the Leviathan!' },
                { id = 'tail_sweep', cooldown = 6, radius = 4, damage = 55,
                  telegraph = 1.0, desc = 'The Leviathan coils for a sweeping blow!' },
                { id = 'summon_minions', cooldown = 25, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'The Leviathan lets out a piercing shriek!' },
            },
        },

        drop = { itemId = 'leviathan_core', name = 'Leviathan Core', amount = 1 },
    },
    the_bull = {
        species     = 'ancient_brute',
        name        = 'Ice Brute King',
        health      = 600,
        baseDamage  = 55,
        speed       = 1.5,
        aggroRange  = 18,
        leashRange  = 50,
        color       = { 0.4, 0.35, 0.3 },
        size        = 2.2,

        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.60, name = 'enraged',   damageMult = 1.4, speedMult = 1.1 },
            { threshold = 0.25, name = 'desperate', damageMult = 1.8, speedMult = 0.9 },
        },

        abilities = {
            normal = {
                { id = 'boulder_throw', cooldown = 10, radius = 3, damage = 35,
                  telegraph = 1.2, desc = 'The Ice Brute King hurls a boulder!' },
            },
            enraged = {
                { id = 'boulder_throw', cooldown = 7, radius = 3, damage = 45,
                  telegraph = 1.0, desc = 'The Ice Brute King hurls a boulder!' },
                { id = 'ground_slam', cooldown = 12, radius = 4, damage = 30,
                  telegraph = 1.0, desc = 'The Ice Brute King raises both fists!' },
            },
            desperate = {
                { id = 'boulder_throw', cooldown = 5, radius = 4, damage = 55,
                  telegraph = 0.8, desc = 'The Ice Brute King hurls a massive boulder!' },
                { id = 'ground_slam', cooldown = 8, radius = 5, damage = 40,
                  telegraph = 0.8, desc = 'The Ice Brute King raises both fists!' },
                { id = 'rally_cry', cooldown = 20, radius = 0, damage = 0,
                  telegraph = 1.5, desc = 'The Ice Brute King bellows a war cry!' },
            },
        },

        drop = { itemId = 'giant_crown', name = 'Brute Crown', amount = 1 },
    },

    the_stalker = {
        species     = 'alpha_stalker',
        name        = 'Alpha Stalker',
        health      = 350,
        baseDamage  = 45,
        speed       = 4.0,
        aggroRange  = 20,
        leashRange  = 999,
        color       = { 0.15, 0.1, 0.1 },
        size        = 1.6,

        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.50, name = 'enraged',   damageMult = 1.5, speedMult = 1.3 },
            { threshold = 0.20, name = 'desperate', damageMult = 2.0, speedMult = 1.5 },
        },

        abilities = {
            normal = {
                { id = 'fear_howl', cooldown = 15, radius = 8, damage = 5,
                  telegraph = 0.5, desc = 'The Stalker shrieks. Morale hit.' },
            },
            enraged = {
                { id = 'fear_howl', cooldown = 10, radius = 10, damage = 10,
                  telegraph = 0.5, desc = 'The Stalker shrieks. Morale hit.' },
                { id = 'shadow_dash', cooldown = 8, radius = 0, damage = 0,
                  telegraph = 0.3, desc = 'The Stalker disappears!' },
            },
            desperate = {
                { id = 'fear_howl', cooldown = 8, radius = 12, damage = 15,
                  telegraph = 0.3, desc = 'The Stalker shrieks. Severe morale hit.' },
                { id = 'shadow_dash', cooldown = 5, radius = 0, damage = 0,
                  telegraph = 0.2, desc = 'The Stalker disappears!' },
                { id = 'feeding_frenzy', cooldown = 20, radius = 3, damage = 60,
                  telegraph = 0.5, desc = 'The Stalker lunges!' },
            },
        },

        drop = { itemId = 'stalker_skull', name = 'Stalker Skull', amount = 1 },
    },

    mountain_titan_boss = {
        species     = 'mountain_titan',
        name        = 'Mountain Titan',
        health      = 1000,
        baseDamage  = 80,
        speed       = 0.8,
        aggroRange  = 15,
        leashRange  = 50,
        color       = { 0.35, 0.3, 0.25 },
        size        = 3.0,

        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.50, name = 'enraged',   damageMult = 1.3, speedMult = 1.2 },
            { threshold = 0.20, name = 'desperate', damageMult = 1.6, speedMult = 0.7 },
        },

        abilities = {
            normal = {
                { id = 'earthquake', cooldown = 15, radius = 6, damage = 25,
                  telegraph = 1.5, desc = 'The Titan stomps. The earth cracks!' },
            },
            enraged = {
                { id = 'earthquake', cooldown = 10, radius = 7, damage = 35,
                  telegraph = 1.2, desc = 'The Titan stomps. The earth cracks!' },
                { id = 'avalanche', cooldown = 18, radius = 5, damage = 45,
                  telegraph = 1.5, desc = 'The Titan hurls chunks of permafrost!' },
            },
            desperate = {
                { id = 'earthquake', cooldown = 8, radius = 8, damage = 45,
                  telegraph = 1.0, desc = 'The Titan stomps. Fissures open!' },
                { id = 'avalanche', cooldown = 12, radius = 6, damage = 55,
                  telegraph = 1.0, desc = 'The Titan hurls chunks of permafrost!' },
                { id = 'world_breaker', cooldown = 25, radius = 10, damage = 60,
                  telegraph = 2.0, desc = 'The Mountain Titan winds up!' },
            },
        },

        drop = { itemId = 'titan_spine', name = 'Titan Spine', amount = 1 },
    },

    -- Eldritch bosses — world-ender tier

    the_hungering_boss = {
        species     = 'the_hungering',
        name        = 'The Hungering',
        health      = 2000,
        baseDamage  = 100,
        speed       = 1.2,
        aggroRange  = 25,
        leashRange  = 999,
        color       = { 0.1, 0.05, 0.05 },
        size        = 4.0,

        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.60, name = 'enraged',   damageMult = 1.3, speedMult = 1.2 },
            { threshold = 0.30, name = 'desperate', damageMult = 1.8, speedMult = 1.4 },
            { threshold = 0.10, name = 'apocalypse', damageMult = 2.5, speedMult = 1.0 },
        },

        abilities = {
            normal = {
                { id = 'devour', cooldown = 12, radius = 4, damage = 50,
                  telegraph = 1.0, desc = 'The Hungering opens its maw wide!' },
            },
            enraged = {
                { id = 'devour', cooldown = 8, radius = 5, damage = 65,
                  telegraph = 0.8, desc = 'The Hungering opens its maw wide!' },
                { id = 'summon_minions', cooldown = 20, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'Smaller horrors crawl from The Hungering!' },
            },
            desperate = {
                { id = 'devour', cooldown = 6, radius = 6, damage = 80,
                  telegraph = 0.6, desc = 'The Hungering opens wide!' },
                { id = 'summon_minions', cooldown = 15, radius = 0, damage = 0,
                  telegraph = 0.8, desc = 'More hostiles from The Hungering!' },
                { id = 'void_scream', cooldown = 25, radius = 12, damage = 30,
                  telegraph = 1.5, desc = 'The Hungering screams. Visibility drops.' },
            },
            apocalypse = {
                { id = 'devour', cooldown = 4, radius = 7, damage = 100,
                  telegraph = 0.5, desc = 'The Hungering feeds!' },
                { id = 'void_scream', cooldown = 15, radius = 15, damage = 50,
                  telegraph = 1.0, desc = 'Massive void pulse from The Hungering!' },
                { id = 'summon_minions', cooldown = 10, radius = 0, damage = 0,
                  telegraph = 0.5, desc = 'More hostiles incoming!' },
            },
        },

        drop = { itemId = 'void_heart', name = 'Void Heart', amount = 1 },
    },

    that_which_sleeps_boss = {
        species     = 'that_which_sleeps',
        name        = 'That Which Sleeps',
        health      = 3000,
        baseDamage  = 120,
        speed       = 0.5,
        aggroRange  = 20,
        leashRange  = 999,
        color       = { 0.2, 0.3, 0.5 },
        size        = 5.0,

        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.60, name = 'enraged',   damageMult = 1.3, speedMult = 1.0 },
            { threshold = 0.30, name = 'desperate', damageMult = 1.6, speedMult = 0.8 },
            { threshold = 0.10, name = 'apocalypse', damageMult = 2.0, speedMult = 0.5 },
        },

        abilities = {
            normal = {
                { id = 'ice_armor', cooldown = 20, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'Glacial ice hardens around That Which Sleeps!' },
                { id = 'ice_nova', cooldown = 15, radius = 8, damage = 30,
                  telegraph = 1.5, desc = 'Frost blast from That Which Sleeps!' },
            },
            enraged = {
                { id = 'ice_armor', cooldown = 15, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'Glacial ice hardens around That Which Sleeps!' },
                { id = 'ice_nova', cooldown = 10, radius = 10, damage = 45,
                  telegraph = 1.2, desc = 'Frost blast from That Which Sleeps!' },
                { id = 'summon_minions', cooldown = 25, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'Ice constructs form from the frozen ground!' },
            },
            desperate = {
                { id = 'ice_nova', cooldown = 8, radius = 12, damage = 60,
                  telegraph = 1.0, desc = 'The temperature plummets. Everything freezes!' },
                { id = 'absolute_zero', cooldown = 30, radius = 15, damage = 40,
                  telegraph = 2.0, desc = 'That Which Sleeps channels absolute zero!' },
                { id = 'summon_minions', cooldown = 18, radius = 0, damage = 0,
                  telegraph = 0.8, desc = 'Frozen constructs incoming!' },
            },
            apocalypse = {
                { id = 'absolute_zero', cooldown = 15, radius = 20, damage = 70,
                  telegraph = 1.5, desc = 'Massive freeze pulse!' },
                { id = 'ice_nova', cooldown = 5, radius = 15, damage = 80,
                  telegraph = 0.8, desc = 'Lethal frost pulse from That Which Sleeps!' },
                { id = 'summon_minions', cooldown = 10, radius = 0, damage = 0,
                  telegraph = 0.5, desc = 'More frozen constructs incoming!' },
            },
        },

        drop = { itemId = 'godstone', name = 'Godstone', amount = 1 },
    },

    -- Thermovore bosses

    iron_carapace_boss = {
        species     = 'iron_carapace',
        name        = 'The Iron Empress',
        health      = 900,
        baseDamage  = 65,
        speed       = 0.9,
        aggroRange  = 12,
        leashRange  = 40,
        color       = { 0.4, 0.25, 0.15 },
        size        = 2.8,

        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.50, name = 'enraged',   damageMult = 1.4, speedMult = 1.3 },
            { threshold = 0.20, name = 'desperate', damageMult = 1.8, speedMult = 0.8 },
        },

        abilities = {
            normal = {
                { id = 'shell_slam', cooldown = 10, radius = 4, damage = 40,
                  telegraph = 1.2, desc = 'The Iron Empress rears up on its hind legs!' },
            },
            enraged = {
                { id = 'shell_slam', cooldown = 7, radius = 5, damage = 55,
                  telegraph = 1.0, desc = 'The Iron Empress rears up on its hind legs!' },
                { id = 'iron_shell', cooldown = 18, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'The Empress withdraws into reinforced plating!' },
            },
            desperate = {
                { id = 'shell_slam', cooldown = 5, radius = 5, damage = 70,
                  telegraph = 0.8, desc = 'The Iron Empress crashes down with full weight!' },
                { id = 'iron_shell', cooldown = 12, radius = 0, damage = 0,
                  telegraph = 0.8, desc = 'Exoskeleton locks into siege configuration!' },
                { id = 'summon_minions', cooldown = 20, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'Bore beetles burst from the ground around the Empress!' },
            },
        },

        drop = { itemId = 'empress_plate', name = 'Empress Plate', amount = 1 },
    },

    the_thermophage_boss = {
        species     = 'the_thermophage',
        name        = 'The Thermophage',
        health      = 2200,
        baseDamage  = 95,
        speed       = 1.0,
        aggroRange  = 25,
        leashRange  = 999,
        color       = { 0.8, 0.15, 0.0 },
        size        = 4.5,

        phases = {
            { threshold = 1.00, name = 'normal',    damageMult = 1.0, speedMult = 1.0 },
            { threshold = 0.60, name = 'enraged',   damageMult = 1.4, speedMult = 1.2 },
            { threshold = 0.30, name = 'desperate', damageMult = 1.8, speedMult = 1.3 },
            { threshold = 0.10, name = 'apocalypse', damageMult = 2.2, speedMult = 1.0 },
        },

        abilities = {
            normal = {
                { id = 'heat_drain', cooldown = 12, radius = 6, damage = 25,
                  telegraph = 1.0, desc = 'The Thermophage opens its thermal vents!' },
            },
            enraged = {
                { id = 'heat_drain', cooldown = 8, radius = 7, damage = 40,
                  telegraph = 0.8, desc = 'The Thermophage opens its thermal vents!' },
                { id = 'carapace_charge', cooldown = 10, radius = 3, damage = 60,
                  telegraph = 0.6, desc = 'The Thermophage lowers its head and charges!' },
            },
            desperate = {
                { id = 'heat_drain', cooldown = 6, radius = 8, damage = 55,
                  telegraph = 0.6, desc = 'The Thermophage drains heat from the area!' },
                { id = 'carapace_charge', cooldown = 7, radius = 4, damage = 75,
                  telegraph = 0.5, desc = 'The Thermophage charges, exoskeleton glowing!' },
                { id = 'summon_minions', cooldown = 18, radius = 0, damage = 0,
                  telegraph = 1.0, desc = 'Thermovores swarm from the ground at its call!' },
            },
            apocalypse = {
                { id = 'heat_drain', cooldown = 4, radius = 10, damage = 70,
                  telegraph = 0.5, desc = 'Massive heat drain from the Thermophage!' },
                { id = 'carapace_charge', cooldown = 5, radius = 5, damage = 90,
                  telegraph = 0.4, desc = 'Unstoppable charge!' },
                { id = 'summon_minions', cooldown = 12, radius = 0, damage = 0,
                  telegraph = 0.5, desc = 'Arthropod swarm incoming!' },
            },
        },

        drop = { itemId = 'thermophage_core', name = 'Thermophage Core', amount = 1 },
    },
}

Bosses.BOSS_DEFS = BOSS_DEFS

---------------------------------------------------------------------------
-- Register unique drop items into Production.ITEMS
---------------------------------------------------------------------------

local Production = require('src.building.production')

local UNIQUE_ITEMS = {
    titan_heart    = { name = 'Titan Heart',    stack = 1, category = 'unique',
                       desc = 'Beating crystalline organ. Powers advanced generators.' },
    wurm_scale     = { name = 'Wurm Scale',     stack = 5, category = 'unique',
                       desc = 'Heat-resistant plating. Premium armor material.' },
    leviathan_core = { name = 'Leviathan Core', stack = 1, category = 'unique',
                       desc = 'Frozen energy lattice. Accelerates research.' },
    giant_crown    = { name = 'Brute Crown',    stack = 1, category = 'unique',
                       desc = 'Stone crown with precursor carvings. Colonists respect the wearer.' },
    stalker_skull  = { name = 'Stalker Skull',  stack = 1, category = 'unique',
                       desc = 'Antlered skull. Faint movement behind the eye sockets.' },
    titan_spine    = { name = 'Titan Spine',    stack = 1, category = 'unique',
                       desc = 'Fossilized vertebra the size of a man. Impervious structural material.' },
    void_heart     = { name = 'Void Heart',     stack = 1, category = 'unique',
                       desc = 'Dense void matter. Colonists refuse to go near it.' },
    godstone       = { name = 'Godstone',       stack = 1, category = 'unique',
                       desc = 'Precursor fragment. Unknown properties.' },
    empress_plate  = { name = 'Empress Plate',  stack = 1, category = 'unique',
                       desc = 'Segmented carapace plating. Harder than anything smelted on Erebus.' },
    thermophage_core = { name = 'Thermophage Core', stack = 1, category = 'unique',
                       desc = 'Pulsing thermal organ. Radiates heat even severed from the body.' },
}

for itemId, def in pairs(UNIQUE_ITEMS) do
    if not Production.ITEMS[itemId] then
        Production.ITEMS[itemId] = def
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function distSq(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return dx * dx + dy * dy
end

-- Determine which phase a boss is in based on current HP.
local function getCurrentPhase(bossDef, currentHp)
    local ratio = currentHp / bossDef.health
    local current = bossDef.phases[1]
    for i = 2, #bossDef.phases do
        if ratio <= bossDef.phases[i].threshold then
            current = bossDef.phases[i]
        end
    end
    return current
end

---------------------------------------------------------------------------
-- Boss spawning
---------------------------------------------------------------------------

-- Spawn a boss creature with the 'boss' component.
-- Returns the entity ID.
function Bosses.spawn(bossId, x, y, depth)
    local def = BOSS_DEFS[bossId]
    if not def then return nil end

    -- Use the base creature spawner for the underlying entity
    local id = Creatures.spawn(def.species, x, y, depth)
    if not id then return nil end

    -- Override creature stats to match boss definition
    local cr = ECS.get(id, 'creature')
    if cr then
        cr.health      = def.health
        cr.maxHealth   = def.health
        cr.damage      = def.baseDamage
        cr.speed       = def.speed
        cr.aggroRange  = def.aggroRange
        cr.leashRange  = def.leashRange
        cr.color       = def.color
        cr.size        = def.size
    end

    -- Attach boss component
    ECS.set(id, 'boss', {
        bossId        = bossId,
        name          = def.name,
        phase         = 'normal',
        phaseDef      = def.phases[1],
        abilityCds    = {},       -- { [abilityId] = remaining cooldown }
        telegraphing  = nil,      -- { ability, timer, targetX, targetY } or nil
        iceArmor      = 0,        -- damage absorption shield
        burrowed      = false,
        burrowTimer   = 0,
    })

    return id
end

---------------------------------------------------------------------------
-- Ability execution
---------------------------------------------------------------------------

-- AoE damage to all colonists within radius of (cx, cy).
local function aoeHit(cx, cy, radius, damage, sourceId)
    local radiusSq = radius * radius
    for cid, comps in ECS.query('colonist', 'pos') do
        local cpos = comps.pos
        if distSq(cx, cy, cpos.x, cpos.y) <= radiusSq then
            local col = comps.colonist
            if col.state ~= 'dead' then
                col.health = col.health - damage
                if col.health <= 0 then
                    local cOk, ColMod = pcall(require, 'src.colonist.colonist')
                    if cOk then ColMod.kill(cid) end
                end
            end
        end
    end
end

-- Execute a specific ability.
local function executeAbility(abilityDef, bossId, bossPos, boss, bossDef)
    local cr = ECS.get(bossId, 'creature')
    if not cr then return end
    local phase = getCurrentPhase(bossDef, cr.health)

    -- AoE damage abilities
    local AOE_ABILITIES = {
        slam = true, ground_pound = true, fire_breath = true, eruption = true,
        tail_sweep = true, ice_nova = true, boulder_throw = true, ground_slam = true,
        earthquake = true, avalanche = true, world_breaker = true,
        feeding_frenzy = true, devour = true, void_scream = true, absolute_zero = true,
        shell_slam = true, heat_drain = true, carapace_charge = true,
    }

    if AOE_ABILITIES[abilityDef.id] then
        local dmg = abilityDef.damage * phase.damageMult
        aoeHit(bossPos.x, bossPos.y, abilityDef.radius, dmg, bossId)

        -- Heat drain: thermophage feeds on colonist warmth
        if abilityDef.id == 'heat_drain' then
            local radiusSq = abilityDef.radius * abilityDef.radius
            for cid, ccomps in ECS.query('colonist', 'pos', 'needs') do
                if distSq(bossPos.x, bossPos.y, ccomps.pos.x, ccomps.pos.y) <= radiusSq then
                    ccomps.needs.warmth = math.max(0, ccomps.needs.warmth - 20)
                end
            end
        end

        -- Absolute zero: also drain warmth of colonists in range
        if abilityDef.id == 'absolute_zero' then
            local radiusSq = abilityDef.radius * abilityDef.radius
            for cid, ccomps in ECS.query('colonist', 'pos', 'needs') do
                if distSq(bossPos.x, bossPos.y, ccomps.pos.x, ccomps.pos.y) <= radiusSq then
                    ccomps.needs.warmth = math.max(0, ccomps.needs.warmth - 30)
                end
            end
        end

        -- Void scream: massive morale drain
        if abilityDef.id == 'void_scream' then
            local radiusSq = abilityDef.radius * abilityDef.radius
            for cid, ccomps in ECS.query('colonist', 'pos', 'needs') do
                if distSq(bossPos.x, bossPos.y, ccomps.pos.x, ccomps.pos.y) <= radiusSq then
                    ccomps.needs.morale = math.max(0, ccomps.needs.morale - 25)
                end
            end
        end

        -- Fear howl: morale drain (not direct damage-focused)
        if abilityDef.id == 'fear_howl' then
            local radiusSq = abilityDef.radius * abilityDef.radius
            for cid, ccomps in ECS.query('colonist', 'pos', 'needs') do
                if distSq(bossPos.x, bossPos.y, ccomps.pos.x, ccomps.pos.y) <= radiusSq then
                    ccomps.needs.morale = math.max(0, ccomps.needs.morale - 15)
                end
            end
        end

        -- World breaker: also ignite tiles in radius
        if abilityDef.id == 'world_breaker' then
            local fok, Fire = pcall(require, 'src.sim.fire')
            if fok then
                for dx = -3, 3 do
                    for dy = -3, 3 do
                        if math.random() < 0.3 then
                            Fire.ignite(bossPos.x + dx, bossPos.y + dy, 'titan', bossPos.depth)
                        end
                    end
                end
            end
        end

    elseif abilityDef.id == 'burrow' or abilityDef.id == 'shadow_dash' then
        -- Go underground/shadow, become untargetable, re-emerge near a colonist
        boss.burrowed = true
        boss.burrowTimer = 2 + math.random() * 2

    elseif abilityDef.id == 'ice_armor' or abilityDef.id == 'iron_shell' then
        local baseArmor = abilityDef.id == 'iron_shell' and 120 or 80
        boss.iceArmor = baseArmor + math.random(40) + (phase.damageMult - 1) * 60

    elseif abilityDef.id == 'rally_cry' then
        -- Ice Brute King summons ice brutes
        local World = require('src.world.tilemap')
        local count = 1 + math.random(2)
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + math.random() * 0.5
            local d = 3 + math.random(3)
            local sx = math.floor(bossPos.x + math.cos(angle) * d)
            local sy = math.floor(bossPos.y + math.sin(angle) * d)
            local bpd = bossPos.depth or 0
            if World.inBounds(sx, sy) and World.isWalkable(sx, sy, bpd) then
                Creatures.spawn('ice_brute', sx, sy, bpd)
            end
        end

    elseif abilityDef.id == 'summon_minions' then
        local World = require('src.world.tilemap')
        -- Pick minion type based on boss species
        local minionType = 'ice_stalker'
        if boss.bossId == 'the_hungering_boss' then minionType = 'spawnling'
        elseif boss.bossId == 'that_which_sleeps_boss' then minionType = 'skitterer'
        elseif boss.bossId == 'iron_carapace_boss' then minionType = 'bore_beetle'
        elseif boss.bossId == 'the_thermophage_boss' then minionType = 'char_hound'
        end
        local bpd = bossPos.depth or 0
        local count = 2 + math.random(2)
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + math.random() * 0.5
            local d = 3 + math.random(3)
            local sx = math.floor(bossPos.x + math.cos(angle) * d)
            local sy = math.floor(bossPos.y + math.sin(angle) * d)
            if World.inBounds(sx, sy) and World.isWalkable(sx, sy, bpd) then
                Creatures.spawn(minionType, sx, sy, bpd)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Boss kill — unique drops
---------------------------------------------------------------------------

function Bosses.onKill(bossEntityId)
    local boss = ECS.get(bossEntityId, 'boss')
    if not boss then return end

    local def = BOSS_DEFS[boss.bossId]
    if not def then return end

    local pos = ECS.get(bossEntityId, 'pos')
    if not pos then return end

    -- Spawn unique drop as ground item
    local ok, Items = pcall(require, 'src.world.items')
    if ok and Items and Items.spawn then
        Items.spawn(pos.x, pos.y, def.drop.itemId, def.drop.amount, 'unique')
    end

    -- Also grant base creature thermal cores / meat (handled by Creatures.kill)
    -- Log the event
    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk then Storyteller.logEvent('Boss Slain',
        string.format('The %s has been defeated! A %s lies in the snow.',
            def.name, def.drop.name)) end
end

-- Override creature kill to also handle boss drops.
-- This patches Creatures.kill to check for boss component.
local _originalKill = Creatures.kill
function Creatures.kill(id)
    if ECS.has(id, 'boss') then
        Bosses.onKill(id)
    end
    _originalKill(id)
end

---------------------------------------------------------------------------
-- Override creature damage to handle ice armor absorption.
---------------------------------------------------------------------------

local _originalDamage = Creatures.damageCreature
function Creatures.damageCreature(creatureId, amount, attackerId)
    local boss = ECS.get(creatureId, 'boss')
    if boss then
        -- Burrowed bosses can't be damaged
        if boss.burrowed then return false end

        -- Ice armor absorbs damage first
        if boss.iceArmor > 0 then
            if amount <= boss.iceArmor then
                boss.iceArmor = boss.iceArmor - amount
                return false
            else
                amount = amount - boss.iceArmor
                boss.iceArmor = 0
            end
        end
    end
    return _originalDamage(creatureId, amount, attackerId)
end

---------------------------------------------------------------------------
-- ECS system: boss AI (runs alongside base creature AI)
---------------------------------------------------------------------------

local function bossAISystem(dt, id, comps)
    local boss    = comps.boss
    local cr      = comps.creature
    local pos     = comps.pos

    if cr.state == 'dead' then return end

    local def = BOSS_DEFS[boss.bossId]
    if not def then return end

    -- Handle burrow state
    if boss.burrowed then
        boss.burrowTimer = boss.burrowTimer - dt
        if boss.burrowTimer <= 0 then
            boss.burrowed = false
            -- Re-emerge near a random colonist
            local nearestId, nearestDist = nil, math.huge
            for cid, ccomps in ECS.query('colonist', 'pos') do
                local d = distSq(pos.x, pos.y, ccomps.pos.x, ccomps.pos.y)
                if d < nearestDist then
                    nearestDist = d
                    nearestId = cid
                end
            end
            if nearestId then
                local tpos = ECS.get(nearestId, 'pos')
                if tpos then
                    local World = require('src.world.tilemap')
                    local angle = math.random() * math.pi * 2
                    local nx = math.floor(tpos.x + math.cos(angle) * 2)
                    local ny = math.floor(tpos.y + math.sin(angle) * 2)
                    if World.inBounds(nx, ny) and World.isWalkable(nx, ny, pos.depth or 0) then
                        Occupancy.release(pos.x, pos.y, id)
                        pos.x = nx
                        pos.y = ny
                        pos.prevX = nx
                        pos.prevY = ny
                        Occupancy.reserve(pos.x, pos.y, id)
                    end
                end
            end
        end
        return -- Skip all other AI while burrowed
    end

    -- Update phase
    local phase = getCurrentPhase(def, cr.health)
    if boss.phase ~= phase.name then
        boss.phase = phase.name
        boss.phaseDef = phase
        -- Initialize cooldowns only for abilities new to this phase
        local phaseAbilities = def.abilities[phase.name]
        if phaseAbilities then
            for _, ab in ipairs(phaseAbilities) do
                if not boss.abilityCds[ab.id] then
                    boss.abilityCds[ab.id] = 0
                end
            end
        end
        -- Apply speed modifier
        cr.speed = def.speed * phase.speedMult
    end

    -- Apply damage multiplier to base creature damage
    cr.damage = math.floor(def.baseDamage * phase.damageMult)

    -- Ability cooldown ticks
    for abilId, cd in pairs(boss.abilityCds) do
        boss.abilityCds[abilId] = cd - dt
        if boss.abilityCds[abilId] < 0 then boss.abilityCds[abilId] = 0 end
    end

    -- Handle telegraph resolution
    if boss.telegraphing then
        boss.telegraphing.timer = boss.telegraphing.timer - dt
        if boss.telegraphing.timer <= 0 then
            executeAbility(boss.telegraphing.ability, id, pos, boss, def)
            boss.abilityCds[boss.telegraphing.ability.id] = boss.telegraphing.ability.cooldown
            boss.telegraphing = nil
        end
        return -- Don't move or do anything else while telegraphing
    end

    -- Try to use an ability if a colonist is in range
    local abilities = def.abilities[boss.phase]
    if abilities then
        -- Find nearest colonist
        local nearestId, nearestDistSq = nil, math.huge
        for cid, ccomps in ECS.query('colonist', 'pos') do
            if ccomps.colonist.state ~= 'dead' then
                local d = distSq(pos.x, pos.y, ccomps.pos.x, ccomps.pos.y)
                if d < nearestDistSq then
                    nearestDistSq = d
                    nearestId = cid
                end
            end
        end
        local nearDist = math.sqrt(nearestDistSq)

        if nearestId and nearDist <= cr.aggroRange then
            for _, ability in ipairs(abilities) do
                local cd = boss.abilityCds[ability.id] or 0
                if cd <= 0 then
                    -- For AoE abilities, check if target is within ability radius
                    local inRange = ability.radius == 0 or nearDist <= ability.radius + 2
                    if inRange then
                        -- Start telegraph
                        boss.telegraphing = {
                            ability = ability,
                            timer   = ability.telegraph,
                            targetX = pos.x,
                            targetY = pos.y,
                        }
                        -- Log the telegraph as a warning
                        local stOk2, ST2 = pcall(require, 'src.storyteller.storyteller')
                        if stOk2 then ST2.logEvent('Boss Warning', ability.desc) end
                        break -- Only one ability at a time
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Bosses.registerSystems()
    ECS.addSystem('boss_ai', { 'boss', 'creature', 'pos' }, bossAISystem, 26)
end

Bosses.registerSystems()

---------------------------------------------------------------------------
-- Storyteller integration: spawn a boss on demand
---------------------------------------------------------------------------

-- Called by the storyteller when threat budget allows a boss event.
-- Picks a boss appropriate to the colony's day/strength.
function Bosses.spawnBossEvent()
    local day = GameState.day
    local World = require('src.world.tilemap')
    local w, h = World.width(), World.height()

    -- Pick boss based on game day — harder bosses appear later
    local bossId
    if day < 20 then
        bossId = 'frost_titan'
    elseif day < 30 then
        local pool = { 'frost_titan', 'thermal_wurm', 'the_bull' }
        bossId = pool[math.random(#pool)]
    elseif day < 45 then
        local pool = { 'frost_titan', 'thermal_wurm', 'glacial_leviathan', 'the_bull', 'the_stalker', 'mountain_titan_boss', 'iron_carapace_boss' }
        bossId = pool[math.random(#pool)]
    elseif day < 60 then
        local pool = { 'glacial_leviathan', 'mountain_titan_boss', 'the_stalker', 'the_bull', 'the_hungering_boss', 'iron_carapace_boss' }
        bossId = pool[math.random(#pool)]
    else
        -- Endgame: eldritch horrors dominate
        local pool = { 'mountain_titan_boss', 'the_hungering_boss', 'that_which_sleeps_boss', 'the_stalker', 'the_thermophage_boss' }
        bossId = pool[math.random(#pool)]
    end

    -- Spawn at map edge
    local side = math.random(4)
    local cx, cy
    if side == 1 then     cx = 3;     cy = math.random(5, h - 5)
    elseif side == 2 then cx = w - 3; cy = math.random(5, h - 5)
    elseif side == 3 then cx = math.random(5, w - 5); cy = 3
    else                  cx = math.random(5, w - 5); cy = h - 3
    end

    if not World.isWalkable(cx, cy, 0) then
        -- Try a few fallback positions
        for _ = 1, 5 do
            cx = cx + math.random(-3, 3)
            cy = cy + math.random(-3, 3)
            cx = math.max(2, math.min(w - 2, cx))
            cy = math.max(2, math.min(h - 2, cy))
            if World.isWalkable(cx, cy, 0) then break end
        end
    end

    local entityId = Bosses.spawn(bossId, cx, cy)
    if entityId then
        local def = BOSS_DEFS[bossId]
        local stOk3, ST3 = pcall(require, 'src.storyteller.storyteller')
        if stOk3 then ST3.logEvent('Boss Approaches',
            string.format('%s spotted at the perimeter!', def.name)) end
    end
    return entityId
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Bosses.isBoss(entityId)
    return ECS.has(entityId, 'boss')
end

function Bosses.getBoss(entityId)
    return ECS.get(entityId, 'boss')
end

function Bosses.getActiveBosses()
    local result = {}
    for id, comps in ECS.query('boss', 'creature', 'pos') do
        if comps.creature.state ~= 'dead' then
            result[#result + 1] = {
                id       = id,
                boss     = comps.boss,
                creature = comps.creature,
                pos      = comps.pos,
            }
        end
    end
    return result
end

function Bosses.getBossPhase(entityId)
    local boss = ECS.get(entityId, 'boss')
    if not boss then return nil end
    return boss.phase
end

function Bosses.isTelegraphing(entityId)
    local boss = ECS.get(entityId, 'boss')
    if not boss then return false end
    return boss.telegraphing ~= nil
end

return Bosses
