-- easter_eggs_space.lua — Deep lore encounters in space
-- Ultra-rare Xenolith hive-ship and Praxii forerunner stations.
-- Added as special POI types and rare event encounters.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local EasterEggsSpace = {}

---------------------------------------------------------------------------
-- Definitions
---------------------------------------------------------------------------

local ENCOUNTERS = {
    xenolith_hiveship = {
        name = 'Something Grown, Not Built',
        desc = 'Massive. Drifting. The hull is chitin over pulsing tissue. No match in any database. The corridors breathe. Something lives inside.',
        rarity = 0.002,  -- 0.2% chance per event check
        loot = {
            { itemId = 'components', amount = 50 },
            { itemId = 'circuit', amount = 30 },
        },
        dangerLevel = 'extreme',
        loreText = 'The ship was grown, not built. A bio-organic vessel from the Bootes Void. Inside: a labyrinth of living tunnels, muscular structures, and egg chambers. One chamber held a queen — a drone that evolved in isolation, desperate and territorial. Eggs cluster in mucous sacs throughout the holds. This species was thought extinct after the Heaven\'s Atlas events. These eggs say otherwise.',
    },
    xenolith_egg_cache = {
        name = 'Sealed Mammona Container',
        desc = 'A reinforced Mammona bio-containment crate. BioVault Inc. markings. The contents are alive.',
        rarity = 0.008,  -- 0.8% chance — rarer than Praxii, more common than hive-ship
        loot = {
            { itemId = 'components', amount = 15 },
        },
        dangerLevel = 'high',
        loreText = 'BioVault Inc., a Mammona subsidiary specializing in xenobiological research, has been recovering Xenolith eggs from derelict bio-ships across the outer rim. This container was in transit when the hauler was lost. Inside: four viable eggs in cryostasis, research notes referencing "Project Chrysalis," and a single memo: "Board approval granted. Begin incubation trials at Facility 7." Mammona is trying to bring them back.',
    },
    xenolith_debris_field = {
        name = 'Organic Debris Cloud',
        desc = 'Sensors detect a cloud of biological debris. Chitinous fragments, desiccated tissue. Something enormous died here long ago.',
        rarity = 0.015,  -- 1.5% chance — most common Xenolith encounter
        loot = {
            { itemId = 'components', amount = 10 },
            { itemId = 'circuit', amount = 5 },
        },
        dangerLevel = 'low',
        loreText = 'The remains of a Xenolith bio-ship, destroyed millennia ago during the Heaven\'s Atlas conflicts. The chitin is ancient but remarkably preserved — it does not decay normally. Scans reveal trace DNA patterns that match no known species in UTC databases. Among the wreckage: dormant spore clusters that twitch when exposed to heat.',
    },
    praxii_station = {
        name = 'Forerunner Station',
        desc = 'Pristine geometric architecture. Near-human proportions but no match in UTC records. Eerily preserved. Completely empty.',
        rarity = 0.01,  -- 1% chance
        loot = {
            { itemId = 'circuit', amount = 20 },
            { itemId = 'components', amount = 25 },
            { itemId = 'steel', amount = 40 },
        },
        dangerLevel = 'low',
        loreText = 'The station is immaculate. Dust has not settled here in millennia, yet nothing decays. Consoles display star charts in a language that predates human writing by tens of thousands of years. The Praxii built this. The Praxii are gone. What destroyed a civilization this advanced?',
    },
    praxii_ship = {
        name = 'Forerunner Vessel',
        desc = 'A small ship of impossible material. Perfectly preserved. The crew are dust.',
        rarity = 0.005,  -- 0.5% chance
        loot = {
            { itemId = 'circuit', amount = 15 },
            { itemId = 'components', amount = 10 },
        },
        dangerLevel = 'none',
        loreText = 'Crew seats sized for near-humans. Navigation logs encrypted in crystalline memory. One entry is partially decoded: coordinates pointing toward the Bootes Void, and a single repeated glyph that translates roughly to "never follow."',
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local discoveredEncounters = {}  -- { [encounterId] = true }
local praxiiFragmentsFound = 0

---------------------------------------------------------------------------
-- Check for easter egg encounter (called from space events)
---------------------------------------------------------------------------

function EasterEggsSpace.rollEncounter()
    if GameState.activeMap ~= 'space' then return nil end
    if GameState.day < 15 then return nil end  -- too early

    for encId, def in pairs(ENCOUNTERS) do
        if not discoveredEncounters[encId] or encId == 'praxii_station' then
            if math.random() < def.rarity then
                return encId
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Trigger encounter
---------------------------------------------------------------------------

function EasterEggsSpace.triggerEncounter(encounterId)
    local def = ENCOUNTERS[encounterId]
    if not def then return false end

    discoveredEncounters[encounterId] = true

    local alOk, Alerts = pcall(require, 'src.ui.alerts')

    -- Alert
    if alOk and Alerts.send then
        Alerts.send('DISCOVERY', def.name .. ' — ' .. def.desc)
    end

    -- Spawn loot near player
    local iok, Items = pcall(require, 'src.world.items')
    for id, comps in ECS.query('ship', 'pos') do
        if not ECS.has(id, 'npc_ship') then
            local px = math.floor(comps.pos.x)
            local py = math.floor(comps.pos.y)
            if iok and Items.spawn then
                for _, lootItem in ipairs(def.loot) do
                    Items.spawn(px + math.random(-3, 3), py + math.random(-3, 3),
                               lootItem.itemId, lootItem.amount)
                end
            end
            break
        end
    end

    -- Xenolith encounters
    if encounterId == 'xenolith_hiveship' then
        -- The hive-ship contains a solitary queen (drone turned queen) and eggs
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if cok and Creatures.spawn then
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    local px = math.floor(comps.pos.x)
                    local py = math.floor(comps.pos.y)
                    -- Spawn the queen — boss-tier Xenolith
                    Creatures.spawn('xenolith_queen', px + 8, py, 0)
                    -- Spawn xenolith larvae hatching from disturbed eggs
                    for i = 1, math.random(3, 6) do
                        Creatures.spawn('xenolith_larva', px + 6 + math.random(-3, 3), py + math.random(-3, 3), 0)
                    end
                    -- Spawn xenolith egg items (containable/harvestable)
                    local iok2, Items = pcall(require, 'src.world.items')
                    if iok2 and Items.spawn then
                        Items.spawn(px + 7, py - 2, 'xenolith_egg', math.random(2, 4))
                    end
                    if alOk and Alerts.send then
                        Alerts.send('RAID INCOMING', 'A Xenolith queen — the last of her hive. She is not defending territory. She is defending eggs.')
                    end
                    break
                end
            end
        end

    elseif encounterId == 'xenolith_egg_cache' then
        -- BioVault container with viable eggs — Mammona is bringing them back
        local iok2, Items = pcall(require, 'src.world.items')
        if iok2 and Items.spawn then
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    local px = math.floor(comps.pos.x)
                    local py = math.floor(comps.pos.y)
                    Items.spawn(px + math.random(-2, 2), py + math.random(-2, 2), 'xenolith_egg', 4)
                    break
                end
            end
        end
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', 'BioVault Inc. containment crate. Inside: viable Xenolith eggs in cryostasis. Mammona is trying to bring them back.')
        end

    elseif encounterId == 'xenolith_debris_field' then
        -- Ancient wreckage — spores that react to heat
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if cok and Creatures.spawn then
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    -- Dormant spores twitch awake
                    for i = 1, math.random(2, 4) do
                        Creatures.spawn('xenolith_spore', math.floor(comps.pos.x) + math.random(-5, 5), math.floor(comps.pos.y) + math.random(-5, 5), 0)
                    end
                    break
                end
            end
        end
    end

    -- Praxii discovery chain
    if encounterId == 'praxii_station' or encounterId == 'praxii_ship' then
        praxiiFragmentsFound = praxiiFragmentsFound + 1
        if praxiiFragmentsFound >= 3 then
            if alOk and Alerts.send then
                Alerts.send('DISCOVERY', 'Multiple Praxii sites catalogued. A pattern emerges — their extinction was not natural. Something hunted them.')
            end
        end

        -- Add lore fragment for planet discovery
        local pdOk, PlanetDiscovery = pcall(require, 'src.space.planet_discovery')
        if pdOk and PlanetDiscovery.addLoreFragment then
            PlanetDiscovery.addLoreFragment('nemaea')
        end
    end

    -- Log to storyteller
    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.logEvent then
        Storyteller.logEvent('easter_egg_' .. encounterId, { lore = def.loreText })
    end

    return true
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function EasterEggsSpace.hasDiscovered(encounterId)
    return discoveredEncounters[encounterId] == true
end

function EasterEggsSpace.getPraxiiFragments()
    return praxiiFragmentsFound
end

function EasterEggsSpace.getEncounterDef(encounterId)
    return ENCOUNTERS[encounterId]
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function EasterEggsSpace.getState()
    return {
        discoveredEncounters = discoveredEncounters,
        praxiiFragmentsFound = praxiiFragmentsFound,
    }
end

function EasterEggsSpace.loadState(state)
    if not state then return end
    discoveredEncounters = state.discoveredEncounters or {}
    praxiiFragmentsFound = state.praxiiFragmentsFound or 0
end

return EasterEggsSpace
