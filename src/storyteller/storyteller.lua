-- storyteller.lua — Event director (Rimworld-style "storyteller AI")
-- Tracks colony threat level, paces events, escalates over time.
-- Three personalities: Steady (balanced), Cruel (relentless), Quiet (buildup→spike).

local GameState = require('src.game_state')
local Weather   = require('src.weather.weather')
local Creatures = require('src.creatures.creatures')
local ECS       = require('src.ecs.ecs')
local Elastic   = require('src.sim.elastic_difficulty')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

local Storyteller = {}

---------------------------------------------------------------------------
-- Planet-aware event filtering & creature/disease mapping
---------------------------------------------------------------------------

--- Returns false if an event should not fire on the current planet.
local function isEventValidForPlanet(eventId)
    local planet = GameState.planet or 'erebus'
    -- Blizzard/whiteout events only on cold planets (ice/snow worlds)
    if eventId == 'blizzard_warning' or eventId == 'whiteout' then
        return planet == 'erebus' or planet == 'gaia_a1x'
    end
    -- Ice plague only on cold/wet planets
    if eventId == 'ice_plague' then
        return planet == 'erebus' or planet == 'nerthus_9'
    end
    -- Warm front only meaningful where cold is the baseline
    if eventId == 'warm_front' then
        return planet == 'erebus' or planet == 'gaia_a1x' or planet == 'nerthus_9' or planet == 'paxtera_prime'
    end
    -- Aurora only on planets with atmosphere + magnetosphere
    if eventId == 'aurora_borealis' then
        return planet ~= 'nemaea' and planet ~= 'rhea_2'
    end
    return true  -- default: allow
end

--- Returns the appropriate creature species for a role on the current planet.
local function getPlanetCreature(role)
    local planet = GameState.planet or 'erebus'
    local PLANET_CREATURES = {
        erebus       = { pack = 'tundra_wolf',       big = 'glacier_bear',      mega = 'frost_titan',          herd = 'frost_hare',  brute = 'ice_brute' },
        rhea_2       = { pack = 'dune_stalker',      big = 'sand_wurm',         mega = 'desert_colossus',      herd = 'sand_hare',   brute = 'dune_brute' },
        morvos       = { pack = 'corrosion_hound',   big = 'caustic_wurm',      mega = 'acid_titan',           herd = 'acid_hare',   brute = 'acid_brute' },
        nerthus_9    = { pack = 'depth_lurker',      big = 'reef_shark',        mega = 'storm_leviathan',      herd = 'shell_crab',  brute = 'reef_brute' },
        paxtera_prime= { pack = 'timber_wolf',       big = 'plains_bear',       mega = 'territorial_megabear', herd = 'field_hare',  brute = 'plains_brute' },
        nemaea       = { pack = 'patrol_automaton',  big = 'siege_automaton',   mega = 'titan_automaton',      herd = 'scrap_drone', brute = 'war_automaton' },
        gaia_a1x     = { pack = 'husk_crawler',      big = 'brood_mother',      mega = 'the_emergence',        herd = 'spore_hare',  brute = 'husk_brute' },
    }
    local pool = PLANET_CREATURES[planet] or PLANET_CREATURES.erebus
    return pool[role] or pool.pack
end

--- Returns the appropriate disease name for the current planet.
local function getPlanetDisease()
    local planet = GameState.planet or 'erebus'
    local diseases = {
        erebus        = 'frostlung',
        rhea_2        = 'heat_stroke',
        morvos        = 'acid_burn',
        nerthus_9     = 'pressure_sickness',
        paxtera_prime = 'crop_fever',
        nemaea        = 'radiation_sickness',
        gaia_a1x      = 'spore_infection',
    }
    return diseases[planet] or 'frostlung'
end

--- Returns planet-flavored event text via adlib, falling back to defaultText.
local function getPlanetEventText(category, defaultText)
    local aok, Adlib = pcall(require, 'src.util.adlib')
    if aok and Adlib.getPlanetEventFlavor then
        local flavor = Adlib.getPlanetEventFlavor(category)
        if flavor then return flavor end
    end
    return defaultText
end

---------------------------------------------------------------------------
-- Threat & colony strength assessment
---------------------------------------------------------------------------

local function getColonyWealth()
    if GameState.getColonyWealth then
        return GameState.getColonyWealth()
    end
    return 0
end

local function getColonyStrength()
    local colonists = ECS.countWith('colonist')
    local cores = GameState.resources.thermalCores
    local day = GameState.day
    local wealth = getColonyWealth()
    return colonists * 10 + cores * 2 + day * 3 + wealth * 0.02
end

local function getThreatBudget()
    local strength = getColonyStrength()
    return math.max(20, strength * 0.6)
end

---------------------------------------------------------------------------
-- Event definitions
---------------------------------------------------------------------------

local EVENTS = {
    -- Weather events
    blizzard_warning = {
        name = 'Blizzard Warning',
        type = 'weather',
        threatCost = 15,
        minDay = 3,
        execute = function()
            Weather.force('blizzard', 60 + math.random(60))
            return getPlanetEventText('blizzard', 'Blizzard incoming from the wastes.')
        end,
    },
    whiteout = {
        name = 'Whiteout',
        type = 'weather',
        threatCost = 30,
        minDay = 10,
        execute = function()
            Weather.force('whiteout', 30 + math.random(30))
            return getPlanetEventText('blizzard', 'Whiteout conditions. Visibility zero.')
        end,
    },
    warm_front = {
        name = 'Warm Front',
        type = 'weather',
        threatCost = -10,  -- positive event (restores threat budget)
        minDay = 1,
        execute = function()
            Weather.force('warm_front', 60 + math.random(120))
            return 'A warm front passes through. The ice thins.'
        end,
    },
    aurora_borealis = {
        name = 'Aurora Borealis',
        type = 'weather',
        threatCost = -5,
        minDay = 5,
        execute = function()
            Weather.force('aurora', 90 + math.random(120))
            return 'Aurora spotted. Colonists stop to watch.'
        end,
    },

    -- Creature events
    wolf_pack = {
        name = 'Wolf Pack Sighting',
        type = 'creature',
        threatCost = 20,
        minDay = 5,
        execute = function()
            local World = require('src.world.tilemap')
            local w, h = World.width(), World.height()
            local cx = GameState.startX + (math.random() > 0.5 and 25 or -25)
            local cy = GameState.startY + (math.random() > 0.5 and 25 or -25)
            cx = math.max(5, math.min(w - 5, cx))
            cy = math.max(5, math.min(h - 5, cy))
            local count = 3 + math.random(3)
            local species = getPlanetCreature('pack')
            Creatures.spawnPack(species, cx, cy, count)
            local specName = (Creatures.SPECIES[species] and Creatures.SPECIES[species].name) or species
            return getPlanetEventText('creature_sighting',
                string.format('A pack of %d %s has been spotted nearby!', count, specName))
        end,
    },
    bear_sighting = {
        name = 'Large Creature',
        type = 'creature',
        threatCost = 15,
        minDay = 8,
        execute = function()
            local World = require('src.world.tilemap')
            local w, h = World.width(), World.height()
            local cx = GameState.startX + math.random(-20, 20)
            local cy = GameState.startY + math.random(-20, 20)
            cx = math.max(5, math.min(w - 5, cx))
            cy = math.max(5, math.min(h - 5, cy))
            local species = getPlanetCreature('big')
            if World.isWalkable(cx, cy, 0) then
                Creatures.spawn(species, cx, cy, 0)
            end
            local specName = (Creatures.SPECIES[species] and Creatures.SPECIES[species].name) or species
            return getPlanetEventText('creature_sighting',
                specName .. ' spotted near the colony.')
        end,
    },
    megafauna_approach = {
        name = 'Megafauna Approach',
        type = 'creature',
        threatCost = 50,
        minDay = 20,
        execute = function()
            local World = require('src.world.tilemap')
            local w, h = World.width(), World.height()
            local sp = getPlanetCreature('mega')
            local side = math.random(4)
            local cx, cy
            if side == 1 then     cx = 3;     cy = math.random(5, h - 5)
            elseif side == 2 then cx = w - 3; cy = math.random(5, h - 5)
            elseif side == 3 then cx = math.random(5, w - 5); cy = 3
            else                  cx = math.random(5, w - 5); cy = h - 3
            end
            if World.isWalkable(cx, cy, 0) then
                Creatures.spawn(sp, cx, cy, 0)
            end
            local name = (Creatures.SPECIES[sp] and Creatures.SPECIES[sp].name) or sp
            return getPlanetEventText('creature_sighting',
                'Seismic contact. ' .. name .. ' heading this way.')
        end,
    },

    -- Colony events
    wanderer_joins = {
        name = 'Wanderer',
        type = 'colony',
        threatCost = -15,
        minDay = 4,
        execute = function()
            local Colonist = require('src.colonist.colonist')
            local World = require('src.world.tilemap')
            local cx = GameState.startX + math.random(-5, 5)
            local cy = GameState.startY + math.random(-5, 5)
            if World.isWalkable(cx, cy, 0) then
                Colonist.spawn(cx, cy)
            end
            return 'A wanderer stumbles out of the snow and asks for a bunk.'
        end,
    },
    supply_cache = {
        name = 'Supply Cache Found',
        type = 'colony',
        threatCost = -10,
        minDay = 2,
        execute = function()
            local rolls = {
                { res = 'wood',  min = 10, max = 30 },
                { res = 'food',  min = 10, max = 25 },
                { res = 'metal', min = 3,  max = 10 },
                { res = 'fuel',  min = 5,  max = 15 },
            }
            local pick = rolls[math.random(#rolls)]
            local amount = pick.min + math.random(pick.max - pick.min)
            local polOk, Policies = pcall(require, 'src.colony.policies')
            local mult = 1.0
            if polOk and Policies.getSupplyDropMult then
                mult = Policies.getSupplyDropMult()
            end
            amount = math.max(1, math.floor(amount * mult + 0.5))
            local Items = getItems()
            if Items then
                Items.spawn(GameState.startX, GameState.startY, pick.res, amount, nil, 0)
            else
                GameState.addResource(pick.res, amount)
            end
            return string.format('Scouts found a supply cache: +%d %s!', amount, pick.res)
        end,
    },
    food_blight = {
        name = 'Food Contamination',
        type = 'colony',
        threatCost = 10,
        minDay = 7,
        execute = function()
            local lost = math.floor(GameState.resources.food * 0.3)
            GameState.resources.food = GameState.resources.food - lost
            if GameState.resources.food < 0 then GameState.resources.food = 0 end
            return string.format('Stored food has spoiled in the cold. Lost %d food.', lost)
        end,
    },

    -- Merchant caravans
    merchant_visit = {
        name = 'Merchant Caravan',
        type = 'colony',
        threatCost = -8,
        minDay = 6,
        execute = function()
            local ok, Merchants = pcall(require, 'src.trade.merchants')
            if ok then
                local mType = Merchants.pickMerchantType()
                local id, err = Merchants.spawnTrader(mType)
                if id then
                    local typeDef = Merchants.MERCHANT_TYPES[mType]
                    return typeDef.name .. ' approaches from the wastes!'
                end
            end
            return 'Merchant caravan spotted, but they turned away.'
        end,
    },

    -- Disease outbreak
    ice_plague = {
        name = 'Disease Outbreak',
        type = 'colony',
        threatCost = 25,
        minDay = 15,
        execute = function()
            local ok, Disease = pcall(require, 'src.sim.disease')
            local disease = getPlanetDisease()
            if ok then
                local infected = Disease.infectRandom(disease)
                if infected then
                    local dname = disease:gsub('_', ' ')
                    return getPlanetEventText('dread',
                        'A colonist shows signs of ' .. dname .. '! Quarantine immediately!')
                end
            end
            return getPlanetEventText('dread',
                'Reports of illness from distant settlements. Stay vigilant.')
        end,
    },

    -- Raids
    beast_raid = {
        name = 'Beast Assault',
        type = 'creature',
        isRaid = true,
        threatCost = 25,
        minDay = 5,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid, err = Raids.startRaid('beast_assault')
                if raid then
                    return 'Hostile creatures are massing on the perimeter!'
                end
            end
            return 'Animal tracks surround the colony. Stay alert.'
        end,
    },
    creature_siege = {
        name = 'Creature Siege',
        type = 'creature',
        isRaid = true,
        threatCost = 40,
        minDay = 12,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid, err = Raids.startRaid('siege')
                if raid then
                    return 'Burrowing creatures are tunneling toward the colony walls!'
                end
            end
            return 'Vibrations detected underground. Source unknown.'
        end,
    },
    coordinated_attack = {
        name = 'Coordinated Attack',
        type = 'creature',
        isRaid = true,
        threatCost = 55,
        minDay = 20,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid, err = Raids.startRaid('coordinated')
                if raid then
                    return 'Multiple creature packs are converging from different directions!'
                end
            end
            return 'Scouts report unusual creature movement on multiple fronts.'
        end,
    },
    -- Tiered swarm events
    swarm_probe_event = {
        name = 'Swarm Scouts',
        type = 'creature',
        isRaid = true,
        threatCost = 15,
        minDay = 10,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('swarm_probe')
                if raid then return 'Small creatures moving in from the east. Lots of them.' end
            end
            return 'Insect tracks in the snow. Fresh.'
        end,
    },
    swarm_wave_event = {
        name = 'Swarm Wave',
        type = 'creature',
        isRaid = true,
        threatCost = 45,
        minDay = 20,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('swarm_wave')
                if raid then return 'Swarm contact on two fronts. More than last time.' end
            end
            return 'Ground vibrations from multiple directions. Getting closer.'
        end,
    },
    the_swarm = {
        name = 'THE SWARM',
        type = 'creature',
        isRaid = true,
        threatCost = 100,
        minDay = 30,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('swarm')
                if raid then return 'Swarm inbound. All four directions. Brace for contact.' end
            end
            return 'Something big moving under the ice. Lots of legs.'
        end,
    },
    the_tide = {
        name = 'THE TIDE',
        type = 'creature',
        isRaid = true,
        threatCost = 150,
        minDay = 45,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('swarm_tide')
                if raid then return 'Horizon is moving. That\'s not snow. Everything we have, now.' end
            end
            return 'Seismic readings maxed out. Every sensor at once.'
        end,
    },
    -- Tiered thermovore events
    thermovore_probe_event = {
        name = 'Thermovore Scouts',
        type = 'creature',
        isRaid = true,
        isThermovore = true,
        threatCost = 12,
        minDay = 15,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('thermovore_probe')
                if raid then return 'Small arthropods near the heat vents. Attracted to the warmth.' end
            end
            return 'Chitin fragments near the reactor. Something was here.'
        end,
    },
    thermovore_emergence_event = {
        name = 'Thermovore Emergence',
        type = 'creature',
        isRaid = true,
        isThermovore = true,
        threatCost = 40,
        minDay = 25,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('thermovore_swarm')
                if raid then return 'Ground cracking near the reactor. Arthropods coming up.' end
            end
            return 'Heat vents clogged with chitin. They come when it\'s warm.'
        end,
    },
    thermovore_tide_event = {
        name = 'Thermovore Tide',
        type = 'creature',
        isRaid = true,
        isThermovore = true,
        threatCost = 120,
        minDay = 35,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('thermovore_tide')
                if raid then return 'Underground eruption. Arthropods flooding from every crack. Cut the heat or fight.' end
            end
            return 'Thermal readings spiking underground. Something big down there.'
        end,
    },

    -- Faction raids (humanoid)
    pirate_raid_event = {
        name = 'Pirate Raid',
        type = 'threat',
        isRaid = true,
        threatCost = 30,
        minDay = 12,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('pirate_raid')
                if raid then return 'Black Maw raiders incoming. Armed and hostile.' end
            end
            return 'Pirate vessels spotted. They moved on.'
        end,
    },
    serpent_raid_event = {
        name = 'Serpent Infiltration',
        type = 'threat',
        isRaid = true,
        threatCost = 35,
        minDay = 20,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('serpent_infiltration')
                if raid then return 'Void Serpent operatives on the perimeter. Watch the doors.' end
            end
            return 'Motion sensors triggered. Nothing on camera. Probably nothing.'
        end,
    },
    reaver_raid_event = {
        name = 'Reaver Strip Raid',
        type = 'threat',
        isRaid = true,
        threatCost = 25,
        minDay = 14,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('reaver_strip')
                if raid then return 'Rust Reavers spotted heading for the stockpiles.' end
            end
            return 'Scrap tracks around the perimeter. Reavers were here.'
        end,
    },
    syndicate_raid_event = {
        name = 'Syndicate Shakedown',
        type = 'threat',
        isRaid = true,
        threatCost = 40,
        minDay = 18,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('syndicate_shakedown')
                if raid then return 'Zenith Syndicate enforcers. They want what we have.' end
            end
            return 'Syndicate runner left a note. Payment demanded. We ignored it.'
        end,
    },
    pale_moon_raid_event = {
        name = 'Pale Moon Crusade',
        type = 'threat',
        isRaid = true,
        threatCost = 45,
        minDay = 22,
        execute = function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            if ok then
                local raid = Raids.startRaid('pale_moon_crusade')
                if raid then return 'Pale Moon zealots approaching from multiple directions. They want the drill sites.' end
            end
            return 'Pale Moon scouts spotted and withdrew. They know where we are.'
        end,
    },

    -- Rescue events
    rescue_survivor = {
        name = 'Downed Survivor',
        type = 'colony',
        threatCost = -10,
        minDay = 6,
        execute = function()
            local ok, Recruitment = pcall(require, 'src.colonist.recruitment')
            if ok then
                local World = require('src.world.tilemap')
                local w, h = World.width(), World.height()
                local side = math.random(4)
                local rx, ry
                if side == 1 then     rx = math.random(5, w - 5); ry = 3
                elseif side == 2 then rx = math.random(5, w - 5); ry = h - 3
                elseif side == 3 then rx = 3;                      ry = math.random(5, h - 5)
                else                   rx = w - 3;                  ry = math.random(5, h - 5)
                end
                if World.isWalkable(rx, ry, 0) then
                    local id = Recruitment.spawnDowned(rx, ry)
                    if id then
                        return 'Scouts found a survivor collapsed in the snow!'
                    end
                end
            end
            return 'Reports of a collapsed figure, but they could not be found.'
        end,
    },

    -- Megabeast awakening
    megabeast_awakening = {
        name = 'Megabeast Awakening',
        type = 'creature',
        threatCost = 70,
        minDay = 25,
        execute = function()
            local ok, Megabeasts = pcall(require, 'src.creatures.megabeasts')
            if ok then
                local World = require('src.world.tilemap')
                local w, h = World.width(), World.height()
                local side = math.random(4)
                local sx, sy
                if side == 1 then     sx = 3;     sy = math.random(10, h - 10)
                elseif side == 2 then sx = w - 3; sy = math.random(10, h - 10)
                elseif side == 3 then sx = math.random(10, w - 10); sy = 3
                else                   sx = math.random(10, w - 10); sy = h - 3
                end
                local difficulty = 1.0 + (GameState.day / 30) * 0.5
                local id, mega = Megabeasts.spawn(sx, sy, difficulty)
                if id and mega then
                    return mega.name .. ' has awoken from the permafrost!'
                end
            end
            return 'Seismic activity detected. Source unknown.'
        end,
    },

    -- Lovecraftian events
    whispers_below = {
        name = 'Whispers Below',
        type = 'colony',
        threatCost = 12,
        minDay = 8,
        execute = function()
            local Adlib = require('src.util.adlib')
            for cid, comps in ECS.query('colonist', 'needs') do
                comps.needs.morale = math.max(0, comps.needs.morale - 5)
            end
            return Adlib.eventFlavor('eldritch') or 'Subsurface readings are off. Something moving below.'
        end,
    },
    cultist_wanderer = {
        name = 'Cultist Wanderer',
        type = 'colony',
        threatCost = -5,
        minDay = 10,
        execute = function()
            local Colonist = require('src.colonist.colonist')
            local World = require('src.world.tilemap')
            local Adlib = require('src.util.adlib')
            local w, h = World.width(), World.height()
            local side = math.random(4)
            local cx, cy
            if side == 1 then     cx = 3;     cy = math.random(5, h - 5)
            elseif side == 2 then cx = w - 3; cy = math.random(5, h - 5)
            elseif side == 3 then cx = math.random(5, w - 5); cy = 3
            else                  cx = math.random(5, w - 5); cy = h - 3
            end
            if World.isWalkable(cx, cy, 0) then
                local id = Colonist.spawn(cx, cy)
                if id then
                    local col = ECS.get(id, 'colonist')
                    if col then
                        local identity = Adlib.generateCultistIdentity()
                        col.name      = identity.name
                        col.backstory = identity.backstory
                        col.traits    = identity.traits
                    end
                    local needs = ECS.get(id, 'needs')
                    if needs then
                        needs.warmth = 15 + math.random(15)
                        needs.morale = 30 + math.random(20)
                    end
                end
            end
            return Adlib.eventFlavor('cult_arrival') or 'Hooded wanderer walked in from the storm. Won\'t say where they came from.'
        end,
    },
    madness_spread = {
        name = 'Creeping Madness',
        type = 'colony',
        threatCost = 18,
        minDay = 15,
        execute = function()
            local Adlib = require('src.util.adlib')
            local affected = 0
            for cid, comps in ECS.query('colonist', 'needs') do
                if math.random() < 0.4 then
                    comps.needs.morale = math.max(0, comps.needs.morale - 12)
                    affected = affected + 1
                end
            end
            local Hope = require('src.colony.hope')
            Hope.applyDelta(-3, 3)
            return Adlib.eventFlavor('madness') or string.format('A wave of unease passes through the colony. %d colonists affected.', affected)
        end,
    },
    void_rift_event = {
        name = 'Void Rift',
        type = 'creature',
        threatCost = 45,
        minDay = 25,
        execute = function()
            local Adlib = require('src.util.adlib')
            local World = require('src.world.tilemap')
            local w, h = World.width(), World.height()
            local rx = GameState.startX + math.random(-15, 15)
            local ry = GameState.startY + math.random(-15, 15)
            rx = math.max(5, math.min(w - 5, rx))
            ry = math.max(5, math.min(h - 5, ry))
            local riftSpecies = { 'fleshwalker', 'shade', 'spawnling' }
            local count = 2 + math.random(3)
            for i = 1, count do
                local sx = rx + math.random(-3, 3)
                local sy = ry + math.random(-3, 3)
                if World.inBounds(sx, sy) and World.isWalkable(sx, sy, 0) then
                    local sp = riftSpecies[math.random(#riftSpecies)]
                    Creatures.spawn(sp, sx, sy, 0)
                end
            end
            local Hope = require('src.colony.hope')
            Hope.applyDelta(-5, 5)
            return Adlib.eventFlavor('void_rift') or 'Something opened up on the perimeter. Hostiles coming through.'
        end,
    },
    dark_ritual = {
        name = 'Dark Ritual',
        type = 'colony',
        threatCost = 8,
        minDay = 12,
        execute = function()
            local Adlib = require('src.util.adlib')
            local hasSensitive = false
            for cid, comps in ECS.query('colonist') do
                local col = comps.colonist
                if col.traits then
                    for _, t in ipairs(col.traits) do
                        if t.id == 'anomaly_sensitive' or t.id == 'void_touched' then
                            hasSensitive = true
                            break
                        end
                    end
                end
                if hasSensitive then break end
            end
            if not hasSensitive then
                return 'Strange symbols appear in the ice overnight. No one claims them.'
            end
            -- Occultist present: 60% positive, 40% negative
            if math.random() < 0.6 then
                -- Positive: research or resource boon
                local boons = {
                    function()
                        local Items = getItems()
                        if Items then Items.spawn(GameState.startX, GameState.startY, 'thermalCores', 2 + math.random(3), nil, 0)
                        else GameState.addResource('thermalCores', 2 + math.random(3)) end
                        return 'Crystals formed where the ritual was. Nobody wants to touch them.'
                    end,
                    function()
                        local Items = getItems()
                        if Items then Items.spawn(GameState.startX, GameState.startY, 'components', 3 + math.random(4), nil, 0)
                        else GameState.addResource('components', 3 + math.random(4)) end
                        return 'Found usable components at the ritual site.'
                    end,
                    function()
                        for cid, comps in ECS.query('colonist', 'needs') do
                            comps.needs.morale = math.min(100, comps.needs.morale + 8)
                        end
                        return 'Morale improved after the ritual. Nobody can explain why.'
                    end,
                }
                return boons[math.random(#boons)]()
            else
                -- Negative: morale hit or creature spawn
                for cid, comps in ECS.query('colonist', 'needs') do
                    comps.needs.morale = math.max(0, comps.needs.morale - 8)
                end
                local Hope = require('src.colony.hope')
                Hope.applyDelta(-3, 3)
                return 'Ritual went wrong. Loud noise from below. Colonists are shaken.'
            end
        end,
    },
    eldritch_awakening = {
        name = 'Eldritch Awakening',
        type = 'creature',
        threatCost = 90,
        minDay = 40,
        execute = function()
            local Adlib = require('src.util.adlib')
            local World = require('src.world.tilemap')
            local w, h = World.width(), World.height()
            local side = math.random(4)
            local sx, sy
            if side == 1 then     sx = 5;     sy = math.random(10, h - 10)
            elseif side == 2 then sx = w - 5; sy = math.random(10, h - 10)
            elseif side == 3 then sx = math.random(10, w - 10); sy = 5
            else                  sx = math.random(10, w - 10); sy = h - 5
            end
            local eldritch = { 'the_hungering', 'the_pale_thing', 'fleshwalker' }
            local sp = eldritch[math.random(#eldritch)]
            if World.isWalkable(sx, sy, 0) then
                Creatures.spawn(sp, sx, sy, 0)
            end
            local Hope = require('src.colony.hope')
            Hope.applyDelta(-10, 10)
            local name = (Creatures.SPECIES[sp] and Creatures.SPECIES[sp].name) or sp
            return name .. ' broke through from somewhere. ' .. (Adlib.eventFlavor('eldritch') or 'Readings are off the charts.')
        end,
    },
    cult_arrival = {
        name = 'Cult Arrival',
        type = 'colony',
        threatCost = 5,
        minDay = 14,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            -- They bring a gift and seek to convert
            local Items = getItems()
            if Items then Items.spawn(GameState.startX, GameState.startY, 'thermalCores', 1 + math.random(2), nil, 0)
            else GameState.addResource('thermalCores', 1 + math.random(2)) end
            Factions.modifyRep('ruin_delvers', 5)
            return Adlib.eventFlavor('cult_arrival') or 'People out of the blizzard. Carrying precursor artifacts.'
        end,
    },
    -- Ruin delvers gift eldritch spores when allied
    delver_spore_gift = {
        name = 'Precursor Offering',
        type = 'colony',
        threatCost = 3,
        minDay = 20,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            if not Factions.isAllied('ruin_delvers') then
                return nil  -- only fires when allied
            end
            local offerings = {
                'flesh_egg', 'ichor_egg', 'chitin_egg', 'void_egg', 'wyrm_egg',
                'spore_bile', 'spore_thorn', 'spore_nerve', 'spore_rot',
            }
            local gift = offerings[math.random(#offerings)]
            GameState.resources[gift] = (GameState.resources[gift] or 0) + 1
            Factions.modifyRep('ruin_delvers', 2)
            return Adlib.factionFlavor('ruin_delvers', 'allied')
                or 'The delvers deliver a sealed container of living material from the deep bore.'
        end,
    },

    -- Eldritch awareness: growing too many nodes attracts cult/void attention
    eldritch_awareness = {
        name = 'Eldritch Awareness',
        type = 'colony',
        threatCost = 15,
        minDay = 15,
        execute = function()
            local Adlib = require('src.util.adlib')
            local enOk, EldritchNodes = pcall(require, 'src.creatures.eldritch_nodes')
            if not enOk then return nil end
            local producing = EldritchNodes.getProducingCount()
            if producing < 2 then return nil end
            -- More producing nodes = worse effects
            local severity = math.min(3, math.floor(producing / 2))
            -- Morale drain on all colonists (unease)
            for cid, ccomps in ECS.query('colonist', 'needs') do
                ccomps.needs.morale = math.max(0, ccomps.needs.morale - 3 * severity)
            end
            -- Hope drain
            local hok, Hope = pcall(require, 'src.colony.hope')
            if hok then Hope.applyDelta(-2 * severity, severity) end
            -- Small reputation hit/gain with ruin delvers
            local fok, Factions = pcall(require, 'src.colony.factions')
            if fok then Factions.modifyRep('ruin_delvers', severity) end
            return Adlib.eventFlavor('eldritch_node')
                or 'Instruments are picking up resonance between the nodes.'
        end,
    },

    the_dreaming = {
        name = 'The Dreaming',
        type = 'colony',
        threatCost = 20,
        minDay = 20,
        execute = function()
            local Adlib = require('src.util.adlib')
            -- Every colonist loses rest and morale (shared nightmare)
            for cid, comps in ECS.query('colonist', 'needs') do
                comps.needs.rest   = math.max(0, comps.needs.rest - 15)
                comps.needs.morale = math.max(0, comps.needs.morale - 8)
            end
            local Hope = require('src.colony.hope')
            Hope.applyDelta(-4, 4)
            return 'Whole colony woke up at once. Nobody remembers why.'
        end,
    },

    -- Skinwalker lure event
    skinwalker_hunt = {
        name = 'Something Calls',
        type = 'threat',
        threatCost = 25,
        minDay = 20,
        execute = function()
            local sok, SW = pcall(require, 'src.creatures.skinwalker')
            if not sok then return nil end
            if SW.hasActiveHunt() then return nil end  -- only one at a time
            local huntId = SW.startHunt()
            if not huntId then return nil end
            return 'Voice on the perimeter. Sounds like one of ours.'
        end,
    },

    -- Refugees
    refugee_group = {
        name = 'Refugees Arrive',
        type = 'colony',
        threatCost = -12,
        minDay = 8,
        execute = function()
            local ok, Recruitment = pcall(require, 'src.colonist.recruitment')
            if ok then
                local count = 1 + math.random(2)
                local spawned = Recruitment.spawnRefugees(count)
                if spawned > 0 then
                    return string.format('%d refugee(s) stumble out of the blizzard, begging for shelter.', spawned)
                end
            end
            return 'Distant figures were spotted in the snow, but they turned away.'
        end,
    },

    -- Skilled wanderer (comes with one high skill)
    skilled_wanderer = {
        name = 'Skilled Wanderer',
        type = 'colony',
        threatCost = -10,
        minDay = 6,
        execute = function()
            local Colonist = require('src.colonist.colonist')
            local World = require('src.world.tilemap')
            local Adlib = require('src.util.adlib')
            local w, h = World.width(), World.height()
            local side = math.random(4)
            local cx, cy
            if side == 1 then     cx = 3;     cy = math.random(5, h - 5)
            elseif side == 2 then cx = w - 3; cy = math.random(5, h - 5)
            elseif side == 3 then cx = math.random(5, w - 5); cy = 3
            else                  cx = math.random(5, w - 5); cy = h - 3
            end
            if World.isWalkable(cx, cy, 0) then
                local id = Colonist.spawn(cx, cy)
                if id then
                    local col = ECS.get(id, 'colonist')
                    if col and col.skills then
                        local SKILL_NAMES = { 'mining', 'building', 'cooking', 'hunting', 'research', 'medical' }
                        local elite = SKILL_NAMES[math.random(#SKILL_NAMES)]
                        col.skills[elite] = 8 + math.random(2)
                        local npc = Adlib.generateNPC()
                        col.backstory = npc.motivation
                    end
                end
            end
            return Adlib.npcDialogue('greeting') or 'A capable wanderer asks for shelter and a place in the crew.'
        end,
    },

    -- Mammona compliance check
    mammona_compliance = {
        name = 'Mammona Compliance Check',
        type = 'colony',
        threatCost = 15,
        minDay = 12,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            if Factions.isAllied('mastema_ops') then
                return Adlib.factionFlavor('mastema_ops', 'allied') or 'MasTema sends a supply cache.'
            end
            -- Demand tribute: take resources
            local cost = math.min(GameState.resources.metal or 0, 5 + math.random(5))
            if cost > 0 then
                GameState.resources.metal = GameState.resources.metal - cost
                Factions.modifyRep('mastema_ops', -3)
            end
            return Adlib.factionFlavor('mastema_ops', 'greeting')
                or string.format('MasTema demands a resource audit. -%d metal requisitioned.', cost)
        end,
    },

    -- Scavenger crew passes through
    scavenger_passage = {
        name = 'Scavenger Passage',
        type = 'colony',
        threatCost = -8,
        minDay = 5,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            local standing = Factions.getStanding('scavenger_crews')
            if standing == 'hostile' then
                return 'Scavenger scouts are spotted watching the colony from a ridge.'
            end
            -- Free food gift — spawn as items near colony center
            local gift = 3 + math.random(5)
            local Items = getItems()
            if Items then
                Items.spawn(GameState.startX, GameState.startY, 'raw_meat', gift, 'food', 0)
            else
                GameState.addResource('food', gift)
            end
            Factions.modifyRep('scavenger_crews', 1)
            return Adlib.factionFlavor('scavenger_crews', 'greeting')
                or string.format('A scavenger crew passes through and shares provisions. +%d food.', gift)
        end,
    },

    -- Rim runner trade pass
    runner_trade_pass = {
        name = 'Rim Runner Trade Pass',
        type = 'colony',
        threatCost = -5,
        minDay = 10,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            if Factions.isHostile('rim_runners') then
                return 'Independent traders spot the colony but keep their distance.'
            end
            local Items = getItems()
            local compAmt = 1 + math.random(2)
            if Items then Items.spawn(GameState.startX, GameState.startY, 'components', compAmt, nil, 0)
            else GameState.addResource('components', compAmt) end
            Factions.modifyRep('rim_runners', 2)
            return Adlib.factionFlavor('rim_runners', 'greeting')
                or 'A rim runner crew shares spare components. +components.'
        end,
    },

    -- Black Maw shakedown
    maw_shakedown = {
        name = 'Black Maw Shakedown',
        type = 'colony',
        threatCost = 12,
        minDay = 15,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            if Factions.isAllied('black_maw') then
                local Items = getItems()
                local fuelAmt = 5 + math.random(5)
                if Items then Items.spawn(GameState.startX, GameState.startY, 'fuel', fuelAmt, nil, 0)
                else GameState.addResource('fuel', fuelAmt) end
                return Adlib.factionFlavor('black_maw', 'allied')
                    or 'Black Maw drops off surplus fuel. Freight corridor stays clear.'
            end
            local cost = math.min(GameState.resources.fuel or 0, 3 + math.random(5))
            if cost > 0 then
                GameState.resources.fuel = GameState.resources.fuel - cost
                Factions.modifyRep('black_maw', -2)
            end
            return Adlib.factionFlavor('black_maw', 'greeting')
                or string.format('Black Maw demands a corridor toll. -%d fuel.', cost)
        end,
    },

    -- Void Serpent intel drop
    serpent_intel = {
        name = 'Void Serpent Intel',
        type = 'colony',
        threatCost = -5,
        minDay = 20,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            if Factions.isHostile('void_serpents') then
                return 'Equipment goes missing overnight. No sign of forced entry.'
            end
            Factions.modifyRep('void_serpents', 1)
            return Adlib.factionFlavor('void_serpents', 'greeting')
                or 'A data chip appears in the stockpile. Raid timing and patrol routes. No sender.'
        end,
    },

    -- Rust Reaver salvage pass
    reaver_salvage = {
        name = 'Rust Reaver Salvage',
        type = 'colony',
        threatCost = -6,
        minDay = 12,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            if Factions.isHostile('rust_reavers') then
                return 'Reavers strip external wiring from the perimeter overnight.'
            end
            local Items = getItems()
            local metalAmt = 3 + math.random(5)
            if Items then Items.spawn(GameState.startX, GameState.startY, 'metal', metalAmt, nil, 0)
            else GameState.addResource('metal', metalAmt) end
            Factions.modifyRep('rust_reavers', 1)
            return Adlib.factionFlavor('rust_reavers', 'greeting')
                or 'Rust Reavers leave salvaged metal outside the walls. Trade bait.'
        end,
    },

    -- Zenith Syndicate extortion
    zenith_extortion = {
        name = 'Zenith Syndicate Extortion',
        type = 'colony',
        threatCost = 15,
        minDay = 18,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            if Factions.isAllied('zenith_syndicate') then
                return Adlib.factionFlavor('zenith_syndicate', 'allied')
                    or 'Zenith considers your colony part of their network. Supplies arrive.'
            end
            local cost = math.min(GameState.resources.food or 0, 5 + math.random(5))
            if cost > 0 then
                GameState.resources.food = GameState.resources.food - cost
                Factions.modifyRep('zenith_syndicate', -3)
            end
            return string.format('Zenith Syndicate takes a cut. -%d food.', cost)
        end,
    },

    -- Solar Nomad caravan
    nomad_caravan = {
        name = 'Solar Nomad Caravan',
        type = 'colony',
        threatCost = -8,
        minDay = 8,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            if Factions.isHostile('solar_nomads') then
                return 'Nomad riders pass in the distance. They don\'t stop.'
            end
            local gift = 4 + math.random(6)
            local Items = getItems()
            if Items then Items.spawn(GameState.startX, GameState.startY, 'food', gift, nil, 0)
            else GameState.addResource('food', gift) end
            Factions.modifyRep('solar_nomads', 2)
            return string.format('Solar Nomads share provisions from their crossing. +%d food.', gift)
        end,
    },

    -- Sons of the Pale Moon pilgrimage
    pale_moon_pilgrimage = {
        name = 'Pale Moon Pilgrimage',
        type = 'colony',
        threatCost = 8,
        minDay = 25,
        execute = function()
            local Adlib = require('src.util.adlib')
            local Factions = require('src.colony.factions')
            local Items = getItems()
            local coreAmt = 1 + math.random(2)
            if Items then Items.spawn(GameState.startX, GameState.startY, 'thermalCores', coreAmt, nil, 0)
            else GameState.addResource('thermalCores', coreAmt) end
            Factions.modifyRep('sons_of_pale_moon', 3)
            -- Morale hit from creepy visitors
            for cid, ccomps in ECS.query('colonist', 'needs') do
                ccomps.needs.morale = math.max(0, ccomps.needs.morale - 2)
            end
            return 'Robed figures arrived with thermal cores. Knelt facing the drill sites. Colonists don\'t like it.'
        end,
    },

    -- Giant pack migration
    giant_migration = {
        name = 'Giant Migration',
        type = 'creature',
        threatCost = 35,
        minDay = 18,
        execute = function()
            local World = require('src.world.tilemap')
            local w, h = World.width(), World.height()
            local side = math.random(4)
            local sx, sy
            if side == 1 then     sx = 5;     sy = math.random(10, h - 10)
            elseif side == 2 then sx = w - 5; sy = math.random(10, h - 10)
            elseif side == 3 then sx = math.random(10, w - 10); sy = 5
            else                  sx = math.random(10, w - 10); sy = h - 5
            end
            local bruteSpecies = getPlanetCreature('brute')
            local packSpecies = getPlanetCreature('pack')
            local species = { bruteSpecies, packSpecies, bruteSpecies }
            local count = 2 + math.random(2)
            for i = 1, count do
                local cx = sx + math.random(-3, 3)
                local cy = sy + math.random(-3, 3)
                if World.inBounds(cx, cy) and World.isWalkable(cx, cy, 0) then
                    Creatures.spawn(species[math.random(#species)], cx, cy, 0)
                end
            end
            local bruteName = (Creatures.SPECIES[bruteSpecies] and Creatures.SPECIES[bruteSpecies].name) or bruteSpecies
            return getPlanetEventText('creature_sighting',
                string.format('A group of %d %s migrate through the area!', count, bruteName))
        end,
    },

    -- Stalker night hunt
    stalker_hunt = {
        name = 'Stalker Night Hunt',
        type = 'creature',
        threatCost = 30,
        minDay = 15,
        execute = function()
            local h = GameState.hour or 12
            if h >= 6 and h < 20 then
                return 'Stalker howls past the ridge. They\'ll come after dark.'
            end
            local World = require('src.world.tilemap')
            local w, hh = World.width(), World.height()
            local cx = GameState.startX + math.random(-20, 20)
            local cy = GameState.startY + math.random(-20, 20)
            cx = math.max(5, math.min(w - 5, cx))
            cy = math.max(5, math.min(hh - 5, cy))
            local count = 1 + math.random(2)
            for i = 1, count do
                local sx = cx + math.random(-3, 3)
                local sy = cy + math.random(-3, 3)
                if World.inBounds(sx, sy) and World.isWalkable(sx, sy, 0) then
                    Creatures.spawn('stalker', sx, sy, 0)
                end
            end
            return 'The stalkers hunt tonight. Lock the doors.'
        end,
    },

    -- Quest hook: discovery rumor
    discovery_rumor = {
        name = 'Rumor from the Snow',
        type = 'colony',
        threatCost = -3,
        minDay = 5,
        execute = function()
            local Adlib = require('src.util.adlib')
            local rumor = Adlib.generateRumor()
            return rumor or 'A colonist brings a strange scrap of news to dinner.'
        end,
    },

    -- Morale boost: campfire stories
    campfire_stories = {
        name = 'Campfire Stories',
        type = 'colony',
        threatCost = -5,
        minDay = 3,
        execute = function()
            local Adlib = require('src.util.adlib')
            for cid, comps in ECS.query('colonist', 'needs') do
                comps.needs.morale = math.min(100, comps.needs.morale + 5)
            end
            return Adlib.generateRumor() or 'The colonists trade rumors around the fire.'
        end,
    },

    -- Earthquake: structural damage + creature emergence
    earthquake = {
        name = 'Earthquake',
        type = 'weather',
        threatCost = 20,
        minDay = 15,
        execute = function()
            local Hope = require('src.colony.hope')
            Hope.applyDelta(-3, 3)
            for cid, comps in ECS.query('colonist', 'needs') do
                comps.needs.morale = math.max(0, comps.needs.morale - 6)
            end
            return 'Earthquake. Cracks in the ice. Seismic readings spiked.'
        end,
    },

    -- Solar flare: electronics disrupted
    solar_flare = {
        name = 'Solar Flare',
        type = 'weather',
        threatCost = 18,
        minDay = 12,
        execute = function()
            local ok, Power = pcall(require, 'src.sim.power')
            if ok and Power.triggerBrownout then
                Power.triggerBrownout(120)
            end
            return 'A solar flare disrupts electronics. Power grid fluctuates!'
        end,
    },

    -- Herd migration (peaceful, free food)
    herd_migration = {
        name = 'Herd Migration',
        type = 'colony',
        threatCost = -8,
        minDay = 4,
        execute = function()
            local World = require('src.world.tilemap')
            local w, h = World.width(), World.height()
            local cx = GameState.startX + math.random(-15, 15)
            local cy = GameState.startY + math.random(-15, 15)
            cx = math.max(5, math.min(w - 5, cx))
            cy = math.max(5, math.min(h - 5, cy))
            local count = 3 + math.random(4)
            local species = getPlanetCreature('herd')
            for i = 1, count do
                local sx = cx + math.random(-4, 4)
                local sy = cy + math.random(-4, 4)
                if World.inBounds(sx, sy) and World.isWalkable(sx, sy, 0) then
                    Creatures.spawn(species, sx, sy, 0)
                end
            end
            local specName = (Creatures.SPECIES[species] and Creatures.SPECIES[species].name) or species
            return string.format('A herd of %d %s passes through. Good hunting.', count, specName)
        end,
    },

    -- Resource vein exposed by ice shift
    resource_vein = {
        name = 'Exposed Vein',
        type = 'colony',
        threatCost = -10,
        minDay = 8,
        execute = function()
            local Adlib = require('src.util.adlib')
            local veins = {
                { res = 'metal',  min = 5,  max = 15, name = 'metal' },
                { res = 'stone',  min = 10, max = 25, name = 'stone' },
                { res = 'fuel',   min = 5,  max = 12, name = 'fuel' },
            }
            local vein = veins[math.random(#veins)]
            local amount = vein.min + math.random(vein.max - vein.min)
            local Items = getItems()
            if Items then Items.spawn(GameState.startX, GameState.startY, vein.res, amount, nil, 0)
            else GameState.addResource(vein.res, amount) end
            return Adlib.eventFlavor('discovery')
                or string.format('Shifting ice exposes a vein of %s. +%d %s!', vein.name, amount, vein.name)
        end,
    },

    -- New quest posted
    quest_contract = {
        name = 'New Contract',
        type = 'colony',
        threatCost = -3,
        minDay = 5,
        execute = function()
            local ok, Quest = pcall(require, 'src.quest.quest')
            if ok then
                Quest.refreshBoard()
                return 'A new contract has been posted to the quest board.'
            end
            return 'Word of work reaches the colony.'
        end,
    },
}

-- Merge expansion events
do
    local eok, Expansion = pcall(require, 'src.storyteller.events_expansion')
    if eok then
        for k, v in pairs(Expansion) do
            if not EVENTS[k] then EVENTS[k] = v end
        end
    end
end

---------------------------------------------------------------------------
-- Storyteller personalities
---------------------------------------------------------------------------

-- Event intervals are in timer units (1 unit = 1 real second at 1x speed).
-- 1 game-hour = 60 units, 1 game-day = 1440 units.
-- Target: Chronicler ~2.5-5 game-days between events (RimWorld-like pacing).
local PERSONALITIES = {
    -- The Watcher — patient, merciful. Very slow events, mostly positive.
    watcher = {
        name = 'The Watcher',
        eventInterval = { 5760, 10080 },  -- 4-7 game-days
        threatMultiplier = 0.6,
        positiveChance = 0.55,
        desc = 'Slow pacing with more relief events and fewer hard spirals.',
        onOffCycle = { on = 5760, off = 7200 }, -- 4 days on, 5 days off
    },
    -- The Chronicler — balanced, fair escalation. Default director.
    chronicler = {
        name = 'The Chronicler',
        eventInterval = { 3600, 7200 },   -- 2.5-5 game-days
        threatMultiplier = 1.0,
        positiveChance = 0.35,
        desc = 'Steady pressure, readable escalation, and room to recover.',
        onOffCycle = { on = 6624, off = 8640 }, -- 4.6 days on, 6 days off (Cassandra-like)
    },
    -- The Tyrant — relentless, punishing. Short intervals, heavy threats.
    tyrant = {
        name = 'The Tyrant',
        eventInterval = { 2160, 4320 },   -- 1.5-3 game-days
        threatMultiplier = 1.4,
        positiveChance = 0.15,
        desc = 'Fast, punishing pacing with almost no downtime.',
        -- No on/off cycle — Tyrant is relentless by design
    },
    -- The Silence — long calm, then sudden devastating spikes.
    silence = {
        name = 'The Silence',
        eventInterval = { 7200, 14400 },  -- 5-10 game-days
        threatMultiplier = 0.8,
        positiveChance = 0.45,
        desc = 'Long calm stretches, then a hit hard enough to matter.',
        -- No on/off cycle — uses its own spike mechanic instead
    },
    -- The Maelstrom — pure chaos. Random budget, random event selection.
    maelstrom = {
        name = 'The Maelstrom',
        eventInterval = { 1440, 8640 },   -- 1-6 game-days (chaotic range)
        threatMultiplier = 1.0,
        positiveChance = 0.30,
        desc = 'Chaotic pacing with weak patterning and rougher prediction.',
        -- No on/off cycle — chaos doesn't follow patterns
    },
    -- Legacy aliases (backward compat with old saves)
    steady = nil, -- mapped below
    cruel  = nil,
    quiet  = nil,
}
-- Legacy aliases point to new names
PERSONALITIES.steady = PERSONALITIES.chronicler
PERSONALITIES.cruel  = PERSONALITIES.tyrant
PERSONALITIES.quiet  = PERSONALITIES.silence

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local personality = 'chronicler'
local eventTimer  = 3600
local threatSpent = 0          -- threat budget consumed this "cycle"
local eventLog    = {}         -- recent event messages
local MAX_LOG     = 50
local quietBuildup = 0         -- for Quiet personality spike mechanic
local lastRaidDay = 0          -- game-day (fractional) of last raid event
local RAID_COOLDOWN_DAYS = 1.8 -- min game-days between any two raid events
local cyclePhase = 'on'        -- 'on' or 'off' for on/off cycle personalities
local cycleTimer = 0           -- timer for current cycle phase

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Storyteller.init(personalityName)
    personality = personalityName or 'chronicler'
    local p = PERSONALITIES[personality] or PERSONALITIES['chronicler']
    eventTimer = p.eventInterval[1] + math.random(p.eventInterval[2] - p.eventInterval[1])
    threatSpent = 0
    eventLog = {}
    quietBuildup = 0
    lastRaidDay = 0
    cyclePhase = 'on'
    cycleTimer = p.onOffCycle and p.onOffCycle.on or 0
end

function Storyteller.setPersonality(name)
    if PERSONALITIES[name] then
        personality = name
    end
end

---------------------------------------------------------------------------
-- Pick an event
---------------------------------------------------------------------------

-- Check if a raid event is blocked by cooldown
local function isRaidOnCooldown(ev)
    if not ev.isRaid then return false end
    local currentDay = GameState.day + (GameState.hour or 0) / 24
    if currentDay - lastRaidDay < RAID_COOLDOWN_DAYS then return true end
    -- Thermovore-specific cooldown (Fix 5): check raids.lua tracker
    if ev.isThermovore then
        local rOk, Raids = pcall(require, 'src.sim.raids')
        if rOk and Raids.isThermovoreOnCooldown and Raids.isThermovoreOnCooldown() then
            return true
        end
    end
    return false
end

local function pickEvent()
    local p = PERSONALITIES[personality]
    local budget = getThreatBudget() * p.threatMultiplier * Elastic.getAggressionMod()
    local day = GameState.day

    -- On/off cycle: during 'off' phase, only allow positive events (Fix 3)
    local forcePositive = (cyclePhase == 'off' and p.onOffCycle ~= nil)

    -- The Maelstrom: pure chaos — pick any eligible event regardless of budget
    if personality == 'maelstrom' then
        local all = {}
        for eventId, ev in pairs(EVENTS) do
            if day >= ev.minDay and not isRaidOnCooldown(ev)
               and isEventValidForPlanet(eventId) then
                all[#all + 1] = { id = eventId, ev = ev }
            end
        end
        if #all == 0 then return nil end
        return all[math.random(#all)]
    end

    -- Colony wellness influences positive event chance: low wellness → more relief events
    local wellness = Elastic.getColonyWellness()
    local wellnessBonus = 0
    if wellness < 30 then wellnessBonus = 0.15
    elseif wellness < 50 then wellnessBonus = 0.05 end
    local wantPositive = forcePositive or math.random() < (p.positiveChance + wellnessBonus)

    -- Gather eligible events (planet-filtered)
    local eligible = {}
    for eventId, ev in pairs(EVENTS) do
        if day >= ev.minDay and isEventValidForPlanet(eventId) then
            if wantPositive and ev.threatCost < 0 then
                eligible[#eligible + 1] = { id = eventId, ev = ev }
            elseif not wantPositive and ev.threatCost > 0 then
                if threatSpent + ev.threatCost <= budget and not isRaidOnCooldown(ev) then
                    eligible[#eligible + 1] = { id = eventId, ev = ev }
                end
            end
        end
    end

    if #eligible == 0 then return nil end
    return eligible[math.random(#eligible)]
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Storyteller.step(dt)
    -- Natural creature spawning
    Creatures.tryNaturalSpawn(dt)

    -- On/off cycle phase management (Fix 3)
    local p = PERSONALITIES[personality]
    if p.onOffCycle then
        cycleTimer = cycleTimer - dt
        if cycleTimer <= 0 then
            if cyclePhase == 'on' then
                cyclePhase = 'off'
                cycleTimer = p.onOffCycle.off
            else
                cyclePhase = 'on'
                cycleTimer = p.onOffCycle.on
            end
        end
    end

    -- Elastic difficulty: faster/slower events based on colony stress
    local eventSpeedMod = Elastic.getEventSpeedMod()
    eventTimer = eventTimer - dt * eventSpeedMod
    if eventTimer > 0 then return end

    -- Reset timer
    eventTimer = p.eventInterval[1] + math.random(math.max(1, p.eventInterval[2] - p.eventInterval[1]))

    -- Quiet personality: buildup mechanic
    if personality == 'silence' then
        quietBuildup = quietBuildup + 1
        if quietBuildup >= 4 then
            -- Spike: force a big threat event
            quietBuildup = 0
            local megaEvents = {}
            for eventId, ev in pairs(EVENTS) do
                if ev.threatCost >= 30 and GameState.day >= ev.minDay
                   and isEventValidForPlanet(eventId) then
                    megaEvents[#megaEvents + 1] = { id = eventId, ev = ev }
                end
            end
            if #megaEvents > 0 then
                local pick = megaEvents[math.random(#megaEvents)]
                local msg = pick.ev.execute()
                if msg then
                    threatSpent = threatSpent + pick.ev.threatCost
                    Storyteller.logEvent(pick.ev.name, msg, pick.ev.threatCost)
                    if pick.ev.isRaid then
                        lastRaidDay = GameState.day + (GameState.hour or 0) / 24
                        if pick.ev.isThermovore then
                            local rOk, Raids = pcall(require, 'src.sim.raids')
                            if rOk and Raids.recordThermovoreRaid then Raids.recordThermovoreRaid() end
                        end
                    end
                end
                return
            end
        end
    end

    local pick = pickEvent()
    if not pick then return end

    local msg = pick.ev.execute()
    if not msg then return end
    threatSpent = threatSpent + pick.ev.threatCost
    Storyteller.logEvent(pick.ev.name, msg, pick.ev.threatCost)

    -- Track raid cooldowns (Fix 2 + Fix 5)
    if pick.ev.isRaid then
        lastRaidDay = GameState.day + (GameState.hour or 0) / 24
        if pick.ev.isThermovore then
            local rOk, Raids = pcall(require, 'src.sim.raids')
            if rOk and Raids.recordThermovoreRaid then Raids.recordThermovoreRaid() end
        end
    end

    -- Reset threat budget every 10 events
    local totalEvents = #eventLog
    if totalEvents % 10 == 0 then
        threatSpent = math.max(0, threatSpent - getThreatBudget() * 0.5)
    end

    -- Anomaly system: roll for anomaly-triggered events
    local anOk, AnomalyMod = pcall(require, 'src.sim.anomaly')
    if anOk and AnomalyMod.getLevel() > 20 then
        local anomalyEvent = AnomalyMod.rollAnomalyEvent()
        if anomalyEvent then
            Storyteller.logEvent('Anomaly: ' .. anomalyEvent,
                'Anomaly level at ' .. math.floor(AnomalyMod.getLevel()) .. '. Instruments acting up.',
                0)
        end
    end
end

---------------------------------------------------------------------------
-- Event log
---------------------------------------------------------------------------

function Storyteller.logEvent(name, message, threatCost)
    eventLog[#eventLog + 1] = {
        name    = name,
        message = message,
        day     = GameState.day,
        hour    = GameState.hour,
        time    = love.timer.getTime(),
    }
    -- Trim
    while #eventLog > MAX_LOG do
        table.remove(eventLog, 1)
    end

    -- Send letter to alert system
    local aOk, AlertsMod = pcall(require, 'src.ui.alerts')
    if aOk then
        local tc = threatCost or 0
        local priority = 'info'
        if tc >= 40 then priority = 'critical'
        elseif tc >= 15 then priority = 'major'
        elseif tc > 0 then priority = 'minor'
        end
        AlertsMod.send(name, message, priority)
    end
end

function Storyteller.getLog()
    return eventLog
end

function Storyteller.restoreLog(saved)
    if saved and type(saved) == 'table' then
        eventLog = saved
    end
end

function Storyteller.getTimerState()
    return {
        eventTimer = eventTimer,
        threatSpent = threatSpent,
        quietBuildup = quietBuildup,
        lastRaidDay = lastRaidDay,
        cyclePhase = cyclePhase,
        cycleTimer = cycleTimer,
    }
end

function Storyteller.restoreTimerState(saved)
    if not saved then return end
    eventTimer = saved.eventTimer or eventTimer
    threatSpent = saved.threatSpent or 0
    quietBuildup = saved.quietBuildup or 0
    lastRaidDay = saved.lastRaidDay or 0
    cyclePhase = saved.cyclePhase or 'on'
    cycleTimer = saved.cycleTimer or 0
end

function Storyteller.getLatestEvent()
    return eventLog[#eventLog]
end

function Storyteller.getPersonality()
    return personality, PERSONALITIES[personality]
end

---------------------------------------------------------------------------
-- Debug API — used by debug_panel
---------------------------------------------------------------------------

function Storyteller.getEventDefs()
    return EVENTS
end

function Storyteller.executeEvent(eventId)
    local ev = EVENTS[eventId]
    if not ev then return false end
    local msg = ev.execute()
    if msg then
        threatSpent = threatSpent + (ev.threatCost or 0)
        Storyteller.logEvent(ev.name, msg, ev.threatCost)
        return true
    end
    return false
end

return Storyteller
