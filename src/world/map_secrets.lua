-- map_secrets.lua — Procedural map secrets placed during world generation
-- Sealed ruins (walled with loot + dormant threats), frozen colonists (cryopods),
-- Thing-mimics (fake colonists that attack when thawed), precursor artifacts.
-- Spawns ECS entities after structures.lua runs.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

local MapSecrets = {}

---------------------------------------------------------------------------
-- Secret definitions
---------------------------------------------------------------------------

local SECRET_TYPES = {
    frozen_colonist = {
        name   = 'Cryopod',
        weight = 30,
        desc   = 'A sealed cryopod with a living occupant. Thaw to recruit or harvest.',
    },
    thing_mimic = {
        name   = 'Frozen Figure',
        weight = 10,
        desc   = 'Looks like a frozen colonist. Something is wrong.',
    },
    precursor_artifact = {
        name   = 'Precursor Artifact',
        weight = 15,
        desc   = 'An alien device half-buried in ice. Risky to activate.',
    },
    sealed_cache = {
        name   = 'Sealed Cache',
        weight = 25,
        desc   = 'A locked supply crate from a prior expedition.',
    },
    dormant_nest = {
        name   = 'Dormant Nest',
        weight = 20,
        desc   = 'Something hibernates beneath the ice. Mining nearby may wake it.',
    },
    foras_data_pad = {
        name = 'Foras Data Pad',
        weight = 10,
        desc = 'Cracked screen, corroded casing. Mammona-issue. Still has power.',
    },
    signal_room = {
        name   = 'Signal Room',
        weight = 12,
        desc   = 'A sealed chamber answers the drill with a human voice and a second signal underneath it.',
    },
    deep_survivor = {
        name   = 'Deep Survivor',
        weight = 14,
        desc   = 'A living figure crouches in the dark beside a warm artifact. They look relieved to see you. Too relieved.',
    },
    quarantine_cell = {
        name   = 'Quarantine Cell',
        weight = 10,
        desc   = 'Restraints, warning paint, and something still breathing behind the frost on the glass.',
    },
    crashed_survey_vessel = {
        name   = 'Crashed Survey Vessel',
        weight = 5,
        desc   = 'A Mammona scout ship half-buried in ice. Predecessor mission they said never existed.',
    },
    xenolith_egg_cluster = {
        name   = 'Organic Growth',
        weight = 3,
        desc   = 'A cluster of dark, ridged objects wedged into a rock crevice. They pulse faintly with warmth. Old. Very old.',
    },
    crashed_cargo_hauler = {
        name   = 'Crashed Cargo Hauler',
        weight = 15,
        desc   = 'Mammona freight shuttle nose-down in the dirt. Cargo bay door hangs open. Picked mostly clean.',
    },
    abandoned_drop_shuttle = {
        name   = 'Abandoned Drop Shuttle',
        weight = 12,
        desc   = 'OmniCorp drop shuttle with bent landing struts. No crew. Emergency beacon still pinging.',
    },
    stripped_pirate_wreck = {
        name   = 'Stripped Pirate Wreck',
        weight = 8,
        desc   = 'What is left of a raider ship. Rust Reavers got here first. Picked it down to wire.',
    },
    mammona_supply_pod = {
        name   = 'Mammona Supply Pod',
        weight = 18,
        desc   = 'Standard Mammona orbital drop pod. Parachute shredded. Crate dented but sealed.',
    },
    crashed_utc_patrol = {
        name   = 'Crashed UTC Patrol',
        weight = 6,
        desc   = 'UTC ranger vessel. Shot down. Scorch marks on the hull. Cargo hold intact.',
    },
    abandoned_cargo_boat = {
        name   = 'Abandoned Cargo Boat',
        weight = 12,
        desc   = 'A Mammona cargo barge run aground. Barnacles up to the waterline. Cargo nets still tied down.',
    },
    capsized_trawler = {
        name   = 'Capsized Trawler',
        weight = 10,
        desc   = 'Fishing trawler belly-up in the shallows. Nets full of something that is not fish.',
    },
    mammona_patrol_boat = {
        name   = 'Scuttled Mammona Patrol Boat',
        weight = 7,
        desc   = 'Mammona security boat scuttled on the reef. Holes punched through the hull from inside. Weapons locker forced open.',
    },
    drifting_lifeboat = {
        name   = 'Drifting Lifeboat',
        weight = 15,
        desc   = 'Emergency lifeboat. No crew. Rations half eaten. Last log entry: three words scratched into the seat.',
    },
    sunken_freighter = {
        name   = 'Sunken Freighter',
        weight = 6,
        desc   = 'OmniCorp cargo freighter on the bottom. Top deck still above water at low tide. Hull groans with the current.',
    },
}

---------------------------------------------------------------------------
-- Placement records (for save/load awareness and UI discovery)
---------------------------------------------------------------------------

local secretRecords = {}

---------------------------------------------------------------------------
-- Weighted random pick
---------------------------------------------------------------------------

local function pickSecretType()
    local total = 0
    for _, def in pairs(SECRET_TYPES) do total = total + def.weight end
    local roll = math.random() * total
    for id, def in pairs(SECRET_TYPES) do
        roll = roll - def.weight
        if roll <= 0 then return id, def end
    end
    return 'sealed_cache', SECRET_TYPES.sealed_cache
end

---------------------------------------------------------------------------
-- Find valid placement spot (snow/permafrost/ice, away from center)
---------------------------------------------------------------------------

local function findSpot(mapW, mapH, minDistFromCenter)
    local World = require('src.world.tilemap')
    local cx, cy = math.floor(mapW / 2), math.floor(mapH / 2)
    for _ = 1, 40 do
        local x = math.random(5, mapW - 6)
        local y = math.random(5, mapH - 6)
        local dist = math.abs(x - cx) + math.abs(y - cy)
        if dist >= minDistFromCenter then
            local tile = World.getTile(x, y, 0)
            if tile == Tiles.SNOW or tile == Tiles.PERMAFROST or tile == Tiles.ICE then
                return x, y
            end
        end
    end
    return nil, nil
end

---------------------------------------------------------------------------
-- Spawn secret entities after world generation
---------------------------------------------------------------------------

function MapSecrets.generate()
    secretRecords = {}

    -- Apply planet-specific secret type overrides
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then
        local ps = Planet.getSecretTypes()
        if ps then SECRET_TYPES = ps end
    end

    local mapW = GameState.mapWidth
    local mapH = GameState.mapHeight
    local area = mapW * mapH

    -- Scale secret count by map size
    local count = math.max(2, math.min(8, math.floor(area / 4000) + math.random(0, 2)))
    local minDist = math.floor(math.min(mapW, mapH) * 0.15)

    for _ = 1, count do
        local x, y = findSpot(mapW, mapH, minDist)
        if not x then goto next_secret end

        local typeId, typeDef = pickSecretType()

        -- Spawn the secret entity
        local id = ECS.spawn()
        ECS.set(id, 'pos', { x = x, y = y })

        if typeId == 'frozen_colonist' then
            -- Cryopod: can be thawed to gain a colonist
            ECS.set(id, 'artifact', {
                type      = 'cryopod',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                mimic     = false,
            })

        elseif typeId == 'thing_mimic' then
            -- Looks like a cryopod but spawns a hostile creature when activated
            ECS.set(id, 'artifact', {
                type      = 'cryopod',
                name      = 'Frozen Figure',
                desc      = 'A body frozen in ice. It looks... recent.',
                activated = false,
                mimic     = true,
            })

        elseif typeId == 'precursor_artifact' then
            -- Alien device with random effect on activation
            local effects = { 'research_boost', 'heal_all', 'spawn_creatures', 'temperature_spike', 'resource_cache' }
            ECS.set(id, 'artifact', {
                type      = 'precursor_device',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                effect    = effects[math.random(#effects)],
            })

        elseif typeId == 'sealed_cache' then
            -- Supply crate with random loot
            local lootTables = {
                { item = 'food',       min = 15, max = 30 },
                { item = 'metal',      min = 10, max = 20 },
                { item = 'components', min = 3,  max = 8 },
                { item = 'medicine',   min = 3,  max = 6 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type      = 'cache',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                lootItem  = loot.item,
                lootMin   = loot.min,
                lootMax   = loot.max,
            })

        elseif typeId == 'dormant_nest' then
            -- Spawns creatures when disturbed (mining nearby)
            local nestSpecies = { 'frost_beetle', 'ice_locust', 'tundra_wolf' }
            ECS.set(id, 'artifact', {
                type      = 'nest',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                species   = nestSpecies[math.random(#nestSpecies)],
                count     = math.random(3, 6),
            })
        elseif typeId == 'foras_data_pad' then
            -- LOG CONTENT PLACEHOLDER — full logs pending approval from lore document
            local logs = {
                { author = 'Unknown', text = 'Data corrupted. Fragments remain.' },
            }
            local log = logs[math.random(#logs)]
            ECS.set(id, 'artifact', {
                type = 'data_pad',
                name = typeDef.name,
                desc = typeDef.desc,
                activated = false,
                logAuthor = log.author,
                logText = log.text,
            })

        elseif typeId == 'signal_room' then
            local humanTemplate = ({ 'latent_survivor', 'vessel_host' })[math.random(2)]
            ECS.set(id, 'artifact', {
                type      = 'containment_subject',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                recoverable = true,
                actionLabel = 'Recover Chamber',
                subjects = {
                    { template = 'signal_idol', overrides = { source = 'sealed signal room' } },
                    { template = humanTemplate, overrides = { source = 'sealed signal room' } },
                },
            })
        elseif typeId == 'deep_survivor' then
            local template = ({ 'latent_survivor', 'thrall_prisoner', 'vessel_host' })[math.random(3)]
            ECS.set(id, 'artifact', {
                type      = 'containment_subject',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                recoverable = true,
                actionLabel = 'Recover Survivor',
                subjects = {
                    { template = template, overrides = { source = 'deep cave shelter' } },
                },
            })
        elseif typeId == 'crashed_survey_vessel' then
            ECS.set(id, 'artifact', {
                type      = 'crashed_ship',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                repairStage = 0,       -- 0=discovered, 1=hull, 2=engine, 3=life_support, 4=flyable
                shipTier  = 'scout',
                shipPrebuilt = 'scout_survey_runner',
            })
        elseif typeId == 'xenolith_egg_cluster' then
            ECS.set(id, 'artifact', {
                type      = 'xenolith_eggs',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                eggCount  = math.random(1, 3),
                sporeCount = math.random(2, 5),
            })

        ---------------------------------------------------------------
        -- Universal surface wreckage (ships)
        ---------------------------------------------------------------
        elseif typeId == 'crashed_cargo_hauler' then
            local lootTables = {
                { item = 'metal',      min = 15, max = 30 },
                { item = 'food',       min = 10, max = 25 },
                { item = 'components', min = 3,  max = 8 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type = 'cache', name = typeDef.name, desc = typeDef.desc,
                activated = false, lootItem = loot.item, lootMin = loot.min, lootMax = loot.max,
            })
        elseif typeId == 'abandoned_drop_shuttle' then
            local lootTables = {
                { item = 'steel',      min = 10, max = 20 },
                { item = 'circuit',    min = 3,  max = 8 },
                { item = 'medicine',   min = 3,  max = 6 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type = 'cache', name = typeDef.name, desc = typeDef.desc,
                activated = false, lootItem = loot.item, lootMin = loot.min, lootMax = loot.max,
            })
        elseif typeId == 'stripped_pirate_wreck' then
            ECS.set(id, 'artifact', {
                type = 'cache', name = typeDef.name, desc = typeDef.desc,
                activated = false, lootItem = 'metal', lootMin = 5, lootMax = 12,
            })
        elseif typeId == 'mammona_supply_pod' then
            local lootTables = {
                { item = 'food',       min = 20, max = 40 },
                { item = 'fuel',       min = 15, max = 30 },
                { item = 'medicine',   min = 5,  max = 12 },
                { item = 'components', min = 5,  max = 10 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type = 'cache', name = typeDef.name, desc = typeDef.desc,
                activated = false, lootItem = loot.item, lootMin = loot.min, lootMax = loot.max,
            })
        elseif typeId == 'crashed_utc_patrol' then
            local lootTables = {
                { item = 'steel',      min = 10, max = 25 },
                { item = 'components', min = 5,  max = 12 },
                { item = 'circuit',    min = 3,  max = 8 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type = 'cache', name = typeDef.name, desc = typeDef.desc,
                activated = false, lootItem = loot.item, lootMin = loot.min, lootMax = loot.max,
            })

        ---------------------------------------------------------------
        -- Universal surface wreckage (boats — water maps)
        ---------------------------------------------------------------
        elseif typeId == 'abandoned_cargo_boat' then
            local lootTables = {
                { item = 'metal',      min = 10, max = 25 },
                { item = 'food',       min = 15, max = 30 },
                { item = 'fuel',       min = 10, max = 20 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type = 'cache', name = typeDef.name, desc = typeDef.desc,
                activated = false, lootItem = loot.item, lootMin = loot.min, lootMax = loot.max,
            })
        elseif typeId == 'capsized_trawler' then
            ECS.set(id, 'artifact', {
                type = 'cache', name = typeDef.name, desc = typeDef.desc,
                activated = false, lootItem = 'food', lootMin = 15, lootMax = 35,
            })
        elseif typeId == 'mammona_patrol_boat' then
            local lootTables = {
                { item = 'steel',      min = 10, max = 20 },
                { item = 'components', min = 5,  max = 10 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type = 'cache', name = typeDef.name, desc = typeDef.desc,
                activated = false, lootItem = loot.item, lootMin = loot.min, lootMax = loot.max,
            })
        elseif typeId == 'drifting_lifeboat' then
            -- Chance of survivor or just rations
            if math.random() < 0.4 then
                ECS.set(id, 'artifact', {
                    type = 'cryopod', name = typeDef.name, desc = typeDef.desc,
                    activated = false, mimic = false,
                })
            else
                ECS.set(id, 'artifact', {
                    type = 'cache', name = typeDef.name, desc = typeDef.desc,
                    activated = false, lootItem = 'food', lootMin = 5, lootMax = 12,
                })
            end
        elseif typeId == 'sunken_freighter' then
            local lootTables = {
                { item = 'metal',      min = 20, max = 40 },
                { item = 'components', min = 8,  max = 16 },
                { item = 'steel',      min = 10, max = 25 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type = 'cache', name = typeDef.name, desc = typeDef.desc,
                activated = false, lootItem = loot.item, lootMin = loot.min, lootMax = loot.max,
            })

        elseif typeId == 'quarantine_cell' then
            local template = ({ 'thrall_prisoner', 'vessel_host', 'herald_captive' })[math.random(3)]
            ECS.set(id, 'artifact', {
                type      = 'containment_subject',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                recoverable = true,
                actionLabel = 'Secure Specimens',
                subjects = {
                    { template = template, overrides = { source = 'collapsed quarantine cell' } },
                    { template = 'mimic_tissue', overrides = { source = 'collapsed quarantine cell' } },
                },
            })

        ---------------------------------------------------------------
        -- Rhea-2 secrets
        ---------------------------------------------------------------
        elseif typeId == 'buried_survivor' then
            ECS.set(id, 'artifact', {
                type      = 'cryopod',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                mimic     = false,
                planet    = 'rhea_2',
            })
        elseif typeId == 'sandstone_cache' then
            local lootTables = {
                { item = 'food',       min = 20, max = 40 },
                { item = 'metal',      min = 10, max = 25 },
                { item = 'components', min = 3,  max = 8 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type      = 'cache',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                lootItem  = loot.item,
                lootMin   = loot.min,
                lootMax   = loot.max,
            })
        elseif typeId == 'sun_shrine' then
            ECS.set(id, 'artifact', {
                type      = 'shrine',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                effect    = 'research_boost',
                revealRadius = 30,
            })
        elseif typeId == 'sand_wurm_nest' then
            ECS.set(id, 'artifact', {
                type      = 'nest',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                species   = 'sand_wurm',
                count     = math.random(2, 4),
            })

        ---------------------------------------------------------------
        -- Morvos secrets
        ---------------------------------------------------------------
        elseif typeId == 'acid_survivor' then
            ECS.set(id, 'artifact', {
                type      = 'cryopod',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                mimic     = false,
                planet    = 'morvos',
            })
        elseif typeId == 'toxic_cache' then
            local lootTables = {
                { item = 'medicine',   min = 5,  max = 12 },
                { item = 'metal',      min = 10, max = 20 },
                { item = 'components', min = 4,  max = 10 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type      = 'cache',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                lootItem  = loot.item,
                lootMin   = loot.min,
                lootMax   = loot.max,
            })
        elseif typeId == 'spore_node' then
            ECS.set(id, 'artifact', {
                type      = 'node',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                nodeType  = 'spore',
                anomalyAmount = math.random(5, 12),
            })
        elseif typeId == 'corrosion_nest' then
            ECS.set(id, 'artifact', {
                type      = 'nest',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                species   = 'corrosion_hound',
                count     = math.random(3, 6),
            })

        ---------------------------------------------------------------
        -- Nerthus-9 secrets
        ---------------------------------------------------------------
        elseif typeId == 'sunken_pod' then
            ECS.set(id, 'artifact', {
                type      = 'cryopod',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                mimic     = false,
                planet    = 'nerthus_9',
            })
        elseif typeId == 'coral_cache' then
            local lootTables = {
                { item = 'food',       min = 20, max = 35 },
                { item = 'metal',      min = 8,  max = 18 },
                { item = 'medicine',   min = 4,  max = 8 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type      = 'cache',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                lootItem  = loot.item,
                lootMin   = loot.min,
                lootMax   = loot.max,
            })
        elseif typeId == 'depth_beacon' then
            ECS.set(id, 'artifact', {
                type      = 'shrine',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                effect    = 'map_reveal',
                revealRadius = 40,
            })
        elseif typeId == 'kraken_nest' then
            ECS.set(id, 'artifact', {
                type      = 'nest',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                species   = 'kraken_spawn',
                count     = math.random(2, 4),
            })
        elseif typeId == 'xenolith_wreck' then
            ECS.set(id, 'artifact', {
                type      = 'xenolith_nest',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                sporeCount = math.random(3, 6),
                hasEgg     = math.random() < 0.3,
            })
        elseif typeId == 'mammona_oil_rig' then
            local lootTables = {
                { item = 'fuel',       min = 30, max = 60 },
                { item = 'metal',      min = 15, max = 30 },
                { item = 'pipe',       min = 5,  max = 12 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type      = 'mammona_rig',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                lootItem  = loot.item,
                lootMin   = loot.min,
                lootMax   = loot.max,
                hasXenolith = math.random() < 0.2,  -- 20% chance of spores in the rig
            })
        elseif typeId == 'mammona_sea_lab' then
            ECS.set(id, 'artifact', {
                type      = 'mammona_lab',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                sporeCount = math.random(2, 5),
                eggCount   = math.random(1, 2),
                hasXenolith = true,  -- always has xenolith material
            })

        elseif typeId == 'thalassa_log' then
            -- LOG CONTENT PLACEHOLDER — full prison logs pending approval from lore document
            local prisonLogs = {
                { author = 'Unknown Inmate', text = 'Water-damaged recording. Fragments remain.' },
            }
            local log = prisonLogs[math.random(#prisonLogs)]
            ECS.set(id, 'artifact', {
                type = 'data_pad',
                name = typeDef.name,
                desc = typeDef.desc,
                activated = false,
                logAuthor = log.author,
                logText = log.text,
            })

        ---------------------------------------------------------------
        -- Paxtera Prime secrets
        ---------------------------------------------------------------
        elseif typeId == 'abandoned_shelter' then
            ECS.set(id, 'artifact', {
                type      = 'cryopod',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                mimic     = false,
                planet    = 'paxtera_prime',
            })
        elseif typeId == 'supply_drop' then
            local lootTables = {
                { item = 'food',       min = 25, max = 50 },
                { item = 'metal',      min = 15, max = 30 },
                { item = 'components', min = 5,  max = 12 },
                { item = 'medicine',   min = 5,  max = 10 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type      = 'cache',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                lootItem  = loot.item,
                lootMin   = loot.min,
                lootMax   = loot.max,
            })
        elseif typeId == 'old_bunker' then
            ECS.set(id, 'artifact', {
                type      = 'shrine',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                effect    = 'research_boost',
                revealRadius = 20,
            })
        elseif typeId == 'wildlife_den' then
            local nestSpecies = { 'timber_wolf', 'plains_bear', 'wild_boar' }
            ECS.set(id, 'artifact', {
                type      = 'nest',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                species   = nestSpecies[math.random(#nestSpecies)],
                count     = math.random(3, 5),
            })

        ---------------------------------------------------------------
        -- Nemaea secrets
        ---------------------------------------------------------------
        elseif typeId == 'automaton_pod' then
            ECS.set(id, 'artifact', {
                type      = 'cryopod',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                mimic     = false,
                planet    = 'nemaea',
            })
        elseif typeId == 'dyson_cache' then
            local lootTables = {
                { item = 'components', min = 8,  max = 16 },
                { item = 'circuit',    min = 5,  max = 12 },
                { item = 'metal',      min = 15, max = 30 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type      = 'cache',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                lootItem  = loot.item,
                lootMin   = loot.min,
                lootMax   = loot.max,
            })
        elseif typeId == 'signal_beacon' then
            ECS.set(id, 'artifact', {
                type      = 'shrine',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                effect    = 'map_reveal',
                revealRadius = 50,
            })
        elseif typeId == 'drone_nest' then
            ECS.set(id, 'artifact', {
                type      = 'nest',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                species   = 'scout_drone',
                count     = math.random(4, 7),
            })

        ---------------------------------------------------------------
        -- Gaia A^1x secrets
        ---------------------------------------------------------------
        elseif typeId == 'forest_shelter' then
            ECS.set(id, 'artifact', {
                type      = 'cryopod',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                mimic     = false,
                planet    = 'gaia_a1x',
            })
        elseif typeId == 'growth_cache' then
            local lootTables = {
                { item = 'food',       min = 30, max = 60 },
                { item = 'medicine',   min = 5,  max = 12 },
                { item = 'wood',       min = 20, max = 40 },
            }
            local loot = lootTables[math.random(#lootTables)]
            ECS.set(id, 'artifact', {
                type      = 'cache',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                lootItem  = loot.item,
                lootMin   = loot.min,
                lootMax   = loot.max,
            })
        elseif typeId == 'corruption_node' then
            ECS.set(id, 'artifact', {
                type      = 'node',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                nodeType  = 'corruption',
                anomalyAmount = math.random(8, 18),
            })
        elseif typeId == 'husk_nest' then
            local nestSpecies = { 'husk_crawler', 'bone_beetle', 'rot_wasp' }
            ECS.set(id, 'artifact', {
                type      = 'nest',
                name      = typeDef.name,
                desc      = typeDef.desc,
                activated = false,
                species   = nestSpecies[math.random(#nestSpecies)],
                count     = math.random(4, 8),
            })
        end

        secretRecords[#secretRecords + 1] = {
            id = id, x = x, y = y, type = typeId, name = typeDef.name,
        }

        ::next_secret::
    end

    return secretRecords
end

---------------------------------------------------------------------------
-- Activate a secret (called when colonist interacts with it)
---------------------------------------------------------------------------

function MapSecrets.activate(entityId)
    local art = ECS.get(entityId, 'artifact')
    if not art or art.activated then return false, 'Already activated' end

    art.activated = true
    local pos = ECS.get(entityId, 'pos')
    if not pos then return false end

    if art.recoverable or art.subjectTemplate or art.subjectTemplates or art.subjects then
        local cok, Containment = pcall(require, 'src.sim.containment')
        if not cok or not Containment.registerFieldSubject then
            art.activated = false
            return false, 'Containment system unavailable'
        end

        local entries = art.subjects or {}
        if #entries == 0 then
            if art.subjectTemplate then
                entries[1] = { template = art.subjectTemplate, overrides = art.subjectOverrides or {} }
            elseif art.subjectTemplates then
                for _, templateId in ipairs(art.subjectTemplates) do
                    entries[#entries + 1] = { template = templateId, overrides = art.subjectOverrides or {} }
                end
            end
        end

        local recovered = 0
        for _, entry in ipairs(entries) do
            if entry.template then
                local overrides = {}
                for k, v in pairs(entry.overrides or {}) do overrides[k] = v end
                overrides.source = overrides.source or (art.name or 'ice recovery')
                overrides.originX = pos.x
                overrides.originY = pos.y
                overrides.originDepth = pos.depth or 0
                if Containment.registerFieldSubject(entry.template, overrides) then
                    recovered = recovered + 1
                end
            end
        end

        local aOk, Anomaly = pcall(require, 'src.sim.anomaly')
        if aOk and Anomaly.addAnomaly then
            Anomaly.addAnomaly(2 + recovered, 'artifact')
        end
        ECS.destroy(entityId)
        return true, 'recovered'
    end

    if art.type == 'data_pad' then
        local alOk, Alerts = pcall(require, 'src.ui.alerts')
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', '[' .. (art.logAuthor or 'Unknown') .. '] ' .. (art.logText or 'Corrupted data.'))
        end
        -- Small research bonus for reading old logs
        local rok, Res = pcall(require, 'src.research.research')
        if rok and Res.addPoints then Res.addPoints(25) end
        -- Foras logs on Gaia A^1x add anomaly
        local planet = GameState.planet
        if planet == 'gaia_a1x' then
            local aok, Anomaly = pcall(require, 'src.sim.anomaly')
            if aok and Anomaly.addAnomaly then Anomaly.addAnomaly(1, 'log') end
        end
        -- Add lore fragment for planet discovery
        local pdOk, PlanetDiscovery = pcall(require, 'src.space.planet_discovery')
        if pdOk and PlanetDiscovery.addLoreFragment then
            PlanetDiscovery.addLoreFragment('gaia_a1x')
        end
        ECS.destroy(entityId)
        return true, 'data_pad'

    elseif art.type == 'cryopod' then
        if art.mimic then
            -- Spawn hostile creature
            local cok, Creatures = pcall(require, 'src.creatures.creatures')
            if cok then
                local mimicSpecies = { 'stalker', 'ice_stalker', 'fleshwalker' }
                local species = mimicSpecies[math.random(#mimicSpecies)]
                Creatures.spawn(species, pos.x, pos.y)
            end
            ECS.destroy(entityId)
            return true, 'mimic'
        else
            -- Thaw a colonist: spawn a new recruit
            local cOk, Colonist = pcall(require, 'src.colonist.colonist')
            if cOk and Colonist.spawn then
                Colonist.spawn(pos.x + 1, pos.y)
            end
            ECS.destroy(entityId)
            return true, 'colonist'
        end

    elseif art.type == 'precursor_device' then
        local effect = art.effect
        if effect == 'research_boost' then
            local rok, Res = pcall(require, 'src.research.research')
            if rok and Res.addProgress then Res.addProgress(500) end
        elseif effect == 'heal_all' then
            for id, comps in ECS.query('colonist') do
                local col = comps.colonist
                if col.state ~= 'dead' then
                    col.health = col.maxHealth or 100
                end
            end
        elseif effect == 'spawn_creatures' then
            local cok, Creatures = pcall(require, 'src.creatures.creatures')
            if cok then
                for _ = 1, math.random(3, 5) do
                    local dx = math.random(-5, 5)
                    local dy = math.random(-5, 5)
                    Creatures.spawn('frost_beetle', pos.x + dx, pos.y + dy)
                end
            end
        elseif effect == 'temperature_spike' then
            -- Warm the area dramatically for a short time
            local wok, World = pcall(require, 'src.world.tilemap')
            if wok then
                for dy = -8, 8 do
                    for dx = -8, 8 do
                        local tx, ty = pos.x + dx, pos.y + dy
                        if World.inBounds(tx, ty) then
                            local temp = World.getTemp(tx, ty, 0) or -40
                            World.setTemp(tx, ty, 0, temp + 60)
                        end
                    end
                end
            end
        elseif effect == 'resource_cache' then
            local Items = getItems()
            if Items then
                Items.spawn(pos.x, pos.y, 'thermalCores', math.random(2, 5), nil, pos.depth or 0)
                Items.spawn(pos.x, pos.y, 'components', math.random(5, 10), nil, pos.depth or 0)
            else
                GameState.addResource('thermalCores', math.random(2, 5))
                GameState.addResource('components', math.random(5, 10))
            end
        end
        ECS.destroy(entityId)
        return true, effect

    elseif art.type == 'cache' then
        local amount = math.random(art.lootMin, art.lootMax)
        local Items = getItems()
        if Items then Items.spawn(pos.x, pos.y, art.lootItem, amount, nil, pos.depth or 0)
        else GameState.addResource(art.lootItem, amount) end
        ECS.destroy(entityId)
        return true, 'loot'

    elseif art.type == 'nest' then
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if cok then
            for _ = 1, art.count do
                local dx = math.random(-3, 3)
                local dy = math.random(-3, 3)
                Creatures.spawn(art.species, pos.x + dx, pos.y + dy)
            end
        end
        ECS.destroy(entityId)
        return true, 'nest'

    elseif art.type == 'shrine' then
        -- Shrine/beacon: grant research points and/or reveal surrounding map
        if art.effect == 'research_boost' then
            local rok, Res = pcall(require, 'src.research.research')
            if rok and Res.addPoints then Res.addPoints(500) end
        end
        if art.revealRadius and art.revealRadius > 0 then
            local vok, Vis = pcall(require, 'src.sim.visibility')
            if vok and Vis.revealArea then
                Vis.revealArea(pos.x, pos.y, art.revealRadius)
            end
        end
        if art.effect == 'map_reveal' then
            local rok, Res = pcall(require, 'src.research.research')
            if rok and Res.addPoints then Res.addPoints(250) end
        end
        local alOk, Alerts = pcall(require, 'src.ui.alerts')
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', (art.name or 'Shrine') .. ' activated — area revealed.')
        end
        ECS.destroy(entityId)
        return true, 'shrine'

    elseif art.type == 'node' then
        -- Anomaly/contamination node: adds anomaly and spawns a temperature effect
        local aOk, Anomaly = pcall(require, 'src.sim.anomaly')
        if aOk and Anomaly.addAnomaly then
            Anomaly.addAnomaly(art.anomalyAmount or 10, 'artifact')
        end
        -- Temperature distortion around the node
        local wok, World = pcall(require, 'src.world.tilemap')
        if wok then
            local tempDelta = art.nodeType == 'corruption' and -20 or 15
            for dy = -5, 5 do
                for dx = -5, 5 do
                    local tx, ty = pos.x + dx, pos.y + dy
                    if World.inBounds(tx, ty) then
                        local temp = World.getTemp(tx, ty, 0) or 0
                        World.setTemp(tx, ty, 0, temp + tempDelta)
                    end
                end
            end
        end
        local alOk, Alerts = pcall(require, 'src.ui.alerts')
        if alOk and Alerts.send then
            if art.nodeType == 'corruption' then
                Alerts.send('THREAT', 'Corruption node disturbed — anomaly surges.')
            else
                Alerts.send('THREAT', 'Spore node ruptured — toxic contamination spreading.')
            end
        end
        ECS.destroy(entityId)
        return true, 'node'

    elseif art.type == 'xenolith_nest' then
        -- Derelict boat with Xenolith spores (and maybe an egg)
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if cok and Creatures.spawn then
            for i = 1, (art.sporeCount or 3) do
                Creatures.spawn('xenolith_spore', pos.x + math.random(-2, 2), pos.y + math.random(-2, 2), pos.depth or 0)
            end
        end
        if art.hasEgg then
            local iok, Items = pcall(require, 'src.world.items')
            if iok and Items.spawn then
                Items.spawn(pos.x, pos.y, 'xenolith_egg', 1)
            end
            local alOk, Alerts = pcall(require, 'src.ui.alerts')
            if alOk and Alerts.send then
                Alerts.send('DISCOVERY', 'Spores burst from the wreck. Among them — a single intact egg.')
            end
        else
            local alOk, Alerts = pcall(require, 'src.ui.alerts')
            if alOk and Alerts.send then
                Alerts.send('THREAT', 'The hull splits open. Xenolith spores scatter across the water.')
            end
        end
        ECS.destroy(entityId)
        return true, 'xenolith_nest'

    elseif art.type == 'xenolith_eggs' then
        -- Naturally occurring eggs wedged in rock crevices — ancient bio-ship crash survivors
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if cok and Creatures.spawn then
            for i = 1, (art.sporeCount or 3) do
                Creatures.spawn('xenolith_spore', pos.x + math.random(-3, 3), pos.y + math.random(-3, 3), pos.depth or 0)
            end
        end
        local iok, Items = pcall(require, 'src.world.items')
        if iok and Items.spawn then
            Items.spawn(pos.x, pos.y, 'xenolith_egg', art.eggCount or 1)
        end
        local alOk, Alerts = pcall(require, 'src.ui.alerts')
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', 'The growths crack open. Eggs — dark, ridged, warm to the touch. Spores scatter from the crevice.')
        end
        ECS.destroy(entityId)
        return true, 'xenolith_eggs'

    elseif art.type == 'mammona_rig' then
        -- Abandoned Mammona oil rig — fuel and materials, maybe spores
        local iok, Items = pcall(require, 'src.world.items')
        if iok and Items.spawn then
            Items.spawn(pos.x, pos.y, art.lootItem or 'fuel', math.random(art.lootMin or 20, art.lootMax or 40))
            Items.spawn(pos.x + 1, pos.y, 'steel', math.random(5, 15))
        end
        if art.hasXenolith then
            local cok, Creatures = pcall(require, 'src.creatures.creatures')
            if cok and Creatures.spawn then
                for i = 1, math.random(2, 4) do
                    Creatures.spawn('xenolith_spore', pos.x + math.random(-2, 2), pos.y + math.random(-2, 2), pos.depth or 0)
                end
            end
            local alOk, Alerts = pcall(require, 'src.ui.alerts')
            if alOk and Alerts.send then
                Alerts.send('THREAT', 'Spore clusters in the lower deck. The rig crew never stood a chance.')
            end
        else
            local alOk, Alerts = pcall(require, 'src.ui.alerts')
            if alOk and Alerts.send then
                Alerts.send('DISCOVERY', 'Mammona rig stripped clean. Fuel and scrap remain.')
            end
        end
        ECS.destroy(entityId)
        return true, 'mammona_rig'

    elseif art.type == 'mammona_lab' then
        -- Sunken BioVault lab — always has xenolith material
        local iok, Items = pcall(require, 'src.world.items')
        if iok and Items.spawn then
            Items.spawn(pos.x, pos.y, 'xenolith_egg', art.eggCount or 1)
            Items.spawn(pos.x, pos.y + 1, 'circuit', math.random(5, 12))
            Items.spawn(pos.x + 1, pos.y, 'components', math.random(8, 15))
        end
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if cok and Creatures.spawn then
            for i = 1, (art.sporeCount or 3) do
                Creatures.spawn('xenolith_spore', pos.x + math.random(-3, 3), pos.y + math.random(-3, 3), pos.depth or 0)
            end
            -- 30% chance a larva hatched already
            if math.random() < 0.3 then
                Creatures.spawn('xenolith_drone', pos.x + 2, pos.y, pos.depth or 0)
            end
        end
        local alOk, Alerts = pcall(require, 'src.ui.alerts')
        if alOk and Alerts.send then
            Alerts.send('THREAT', 'BioVault lab breached. Project Chrysalis was real. Eggs and spores everywhere.')
        end
        ECS.destroy(entityId)
        return true, 'mammona_lab'

    elseif art.type == 'crashed_ship' then
        if art.repairStage == 0 then
            -- First activation: assess damage
            art.repairStage = 1
            art.activated = false  -- keep interactable
            local alOk, Alerts = pcall(require, 'src.ui.alerts')
            if alOk and Alerts.send then
                Alerts.send('DISCOVERY', 'Survey vessel found! Hull repair needed: 20 steel, 10 components.')
            end
        elseif art.repairStage == 1 then
            -- Hull repair
            if GameState.resources.steel >= 20 and GameState.resources.components >= 10 then
                GameState.resources.steel = GameState.resources.steel - 20
                GameState.resources.components = GameState.resources.components - 10
                art.repairStage = 2
                art.activated = false
                local alOk, Alerts = pcall(require, 'src.ui.alerts')
                if alOk and Alerts.send then
                    Alerts.send('DISCOVERY', 'Hull repaired! Engine repair needed: 15 circuits, 10 fuel.')
                end
            end
        elseif art.repairStage == 2 then
            -- Engine repair
            if GameState.resources.circuit >= 15 and GameState.resources.fuel >= 10 then
                GameState.resources.circuit = GameState.resources.circuit - 15
                GameState.resources.fuel = GameState.resources.fuel - 10
                art.repairStage = 3
                art.activated = false
                local alOk, Alerts = pcall(require, 'src.ui.alerts')
                if alOk and Alerts.send then
                    Alerts.send('DISCOVERY', 'Engine repaired! Life support repair needed: 10 pipes, 5 insulation.')
                end
            end
        elseif art.repairStage == 3 then
            -- Life support repair
            if GameState.resources.pipe >= 10 and GameState.resources.insulation >= 5 then
                GameState.resources.pipe = GameState.resources.pipe - 10
                GameState.resources.insulation = GameState.resources.insulation - 5
                art.repairStage = 4
                art.activated = true
                -- Ship is now flyable! Create the ship entity group
                local smOk, ShipManager = pcall(require, 'src.space.ship_manager')
                if smOk then
                    ShipManager.createShip(art.shipTier, art.shipPrebuilt)
                end
                local alOk, Alerts = pcall(require, 'src.ui.alerts')
                if alOk and Alerts.send then
                    Alerts.send('DISCOVERY', 'Survey vessel fully repaired! Scout ship ready for launch.')
                end
            end
        end
        return  -- don't destroy the entity until fully repaired
    end

    return false
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function MapSecrets.getRecords()
    return secretRecords
end

function MapSecrets.getUndiscovered()
    local result = {}
    for _, rec in ipairs(secretRecords) do
        if ECS.isAlive(rec.id) then
            local art = ECS.get(rec.id, 'artifact')
            if art and not art.activated then
                result[#result + 1] = rec
            end
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function MapSecrets.getState()
    return { records = secretRecords }
end

function MapSecrets.loadState(saved)
    if not saved then return end
    secretRecords = saved.records or {}
end

return MapSecrets
