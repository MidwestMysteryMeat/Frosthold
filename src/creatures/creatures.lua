-- creatures.lua — Species spawning, death/loot
-- Species data in src/creatures/species_defs.lua
-- AI behavior in src/ai/creature_ai.lua

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

local Creatures = {}

---------------------------------------------------------------------------
-- Species definitions (data in species_defs.lua)
---------------------------------------------------------------------------

local SPECIES = require('src.creatures.species_defs')

Creatures.SPECIES = SPECIES

---------------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------------

function Creatures.spawn(speciesId, x, y, depth)
    local sp = SPECIES[speciesId]
    if not sp then return nil end

    local id = ECS.spawn()

    ECS.set(id, 'pos', {
        x = x, y = y,
        prevX = x, prevY = y,
        homeX = x, homeY = y,  -- leash anchor
        depth = depth or 0,
    })

    ECS.set(id, 'creature', {
        species   = speciesId,
        name      = sp.name,
        tier      = sp.tier,
        health    = sp.health,
        maxHealth = sp.health,
        damage    = sp.damage,
        speed     = sp.speed,
        hostile   = sp.hostile,
        thermalCore = sp.thermalCore,
        meat      = sp.meat,
        color     = sp.color,
        size      = sp.size,
        state     = 'idle',       -- idle, wander, flee, chase, attack, dead
        target    = nil,          -- entity ID being chased/attacked
        aggroRange = sp.aggroRange or 0,
        leashRange = sp.leashRange or 0,
        fleeRange  = sp.fleeRange or 0,
        attackCooldown = 0,
        facing    = math.random() * math.pi * 2,  -- vision cone direction (radians)
    })

    ECS.set(id, 'path', {
        nodes = nil,
        index = 1,
        moveTimer = 0,
    })

    return id
end

-- Spawn a pack of creatures around a point
function Creatures.spawnPack(speciesId, cx, cy, count, depth)
    local ids = {}
    local World = require('src.world.tilemap')
    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + math.random() * 0.5
        local dist = 2 + math.random(3)
        local tx = cx + math.floor(math.cos(angle) * dist)
        local ty = cy + math.floor(math.sin(angle) * dist)
        if World.inBounds(tx, ty) and World.isWalkable(tx, ty, depth) then
            ids[#ids + 1] = Creatures.spawn(speciesId, tx, ty, depth)
        end
    end
    return ids
end

---------------------------------------------------------------------------
-- Natural spawning — called periodically by storyteller or on timer
---------------------------------------------------------------------------

local spawnCooldown = 0
local SPAWN_INTERVAL = 30  -- seconds between spawn checks

function Creatures.tryNaturalSpawn(dt)
    spawnCooldown = spawnCooldown - dt
    if spawnCooldown > 0 then return end
    -- Difficulty: creature aggression scales spawn frequency
    local aggression = GameState.creatureAggression or 1.0
    -- Elastic difficulty: reinforcement rate modulates spawn frequency
    local eOk, Elastic = pcall(require, 'src.sim.elastic_difficulty')
    local reinforcement = (eOk and Elastic.getReinforcementRate()) or 1.0
    spawnCooldown = SPAWN_INTERVAL / (aggression * reinforcement)

    -- Cap total creatures
    local total = ECS.countWith('creature')
    if total >= 30 then return end

    local World = require('src.world.tilemap')
    local w, h = World.width(), World.height()

    -- Pick a random edge-ish position
    local side = math.random(4)
    local x, y
    if side == 1 then     x = math.random(5, 15);          y = math.random(5, h - 5)
    elseif side == 2 then x = math.random(w - 15, w - 5);  y = math.random(5, h - 5)
    elseif side == 3 then x = math.random(5, w - 5);       y = math.random(5, 15)
    else                  x = math.random(5, w - 5);       y = math.random(h - 15, h - 5)
    end

    if not World.isWalkable(x, y, 0) then return end

    -- Weight species by day (harder creatures appear later)
    local day = GameState.day
    local roll = math.random()

    -- Planet creature pool filter (nil = allow all)
    local planetPools
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then planetPools = Planet.getCreaturePools() end
    local function filterPool(pool)
        if not planetPools then return pool end
        local allowed = {}
        for _, sp in ipairs(pool) do
            for _, pp in ipairs(planetPools) do
                if sp == pp then allowed[#allowed + 1] = sp; break end
            end
        end
        return #allowed > 0 and allowed or pool  -- fallback to full pool if filter empties it
    end

    local small  = filterPool({ 'frost_hare', 'ice_fox', 'snow_grouse', 'cinder_mite', 'heat_skipper' })
    local med    = filterPool({ 'tundra_wolf', 'glacier_bear', 'ice_stalker', 'char_hound' })
    local medAdv = filterPool({ 'ice_brute', 'snow_ape', 'stalker', 'shade', 'dire_wolf', 'mammoth', 'sabertooth', 'bore_beetle', 'razorjaw', 'spine_lurker' })
    local mega   = filterPool({ 'frost_titan', 'thermal_wurm', 'glacial_leviathan', 'ancient_brute', 'alpha_stalker', 'mountain_titan', 'ice_colossus', 'storm_titan', 'hive_matron', 'gorge_worm', 'iron_carapace' })
    local eldr   = filterPool({ 'the_hungering', 'the_pale_thing', 'that_which_sleeps', 'fleshwalker', 'the_thermophage' })

    -- Planet-aware depth spawning
    local currentPlanet = pok and Planet.getId() or 'erebus'
    local planetPoolSet = nil
    if planetPools then
        planetPoolSet = {}
        for _, pp in ipairs(planetPools) do planetPoolSet[pp] = true end
    end

    -- Species that spawn underground on specific planets
    local UNDERGROUND_SPECIES = {
        -- Rhea-2: desert burrowers flee the heat into tunnels
        rhea_2 = { sand_wurm = true, dune_stalker = true, sun_scorpion = true },
        -- Nemaea: automatons patrol all depths
        nemaea = { patrol_automaton = true, enforcer_unit = true, hunter_killer = true,
                   siege_automaton = true, titan_automaton = true },
        -- Gaia A^1x: corruption creatures live deep (depth 3+)
        gaia_a1x = { husk_crawler = true, bone_beetle = true, rot_wasp = true,
                     brood_mother = true, the_emergence = true, baldrungen_tendril = true },
    }
    local undergroundSet = UNDERGROUND_SPECIES[currentPlanet]

    local function pickSpawnDepth(sp)
        -- Nerthus-9: aquatic species may spawn at depth 1-3
        if currentPlanet == 'nerthus_9' and planetPoolSet and planetPoolSet[sp] then
            local depthRoll = math.random()
            if depthRoll < 0.40 then return math.random(1, 2)
            elseif depthRoll < 0.50 then return 3 end

        -- Other planets: species in the underground set spawn at depth
        elseif undergroundSet and undergroundSet[sp] then
            local depthRoll = math.random()
            if currentPlanet == 'gaia_a1x' then
                -- Corruption creatures only at depth 3+
                if depthRoll < 0.3 then return math.random(3, 5) end
            elseif currentPlanet == 'rhea_2' then
                -- Desert burrowers: 30% chance at depth 1-2
                if depthRoll < 0.3 then return math.random(1, 2) end
            elseif currentPlanet == 'nemaea' then
                -- Automatons patrol everywhere: 25% chance at depth 1-3
                if depthRoll < 0.25 then return math.random(1, 3) end
            end
        end
        return 0
    end

    local function spawnFromPool(pool)
        local sp = pool[math.random(#pool)]

        -- Pick spawn depth based on planet and species
        local depth = pickSpawnDepth(sp)
        if depth > 0 then
            if not World.hasLayer(depth) or not World.isWalkable(x, y, depth) then
                depth = 0  -- fall back to surface
            end
        end

        if SPECIES[sp].packSize then
            local ps = SPECIES[sp].packSize
            local count = math.random(ps[1], ps[2])
            Creatures.spawnPack(sp, x, y, count, depth)
        else
            Creatures.spawn(sp, x, y, depth)
        end
    end

    if day < 5 then
        spawnFromPool(small)
    elseif day < 12 then
        if roll < 0.6 then spawnFromPool(small) else spawnFromPool(med) end
    elseif day < 25 then
        if roll < 0.25 then
            spawnFromPool(small)
        elseif roll < 0.65 then
            spawnFromPool(med)
        elseif roll < 0.90 then
            spawnFromPool(medAdv)
        else
            spawnFromPool(mega)
        end
    elseif day < 45 then
        if roll < 0.15 then
            spawnFromPool(small)
        elseif roll < 0.40 then
            spawnFromPool(med)
        elseif roll < 0.65 then
            spawnFromPool(medAdv)
        elseif roll < 0.90 then
            spawnFromPool(mega)
        else
            local combined = {}
            for _, s in ipairs(mega) do combined[#combined + 1] = s end
            spawnFromPool(combined)
        end
    else
        if roll < 0.10 then
            spawnFromPool(small)
        elseif roll < 0.30 then
            spawnFromPool(med)
        elseif roll < 0.50 then
            spawnFromPool(medAdv)
        elseif roll < 0.80 then
            spawnFromPool(mega)
        elseif roll < 0.95 then
            spawnFromPool(eldr)
        else
            spawnFromPool(mega)
        end
    end
end

---------------------------------------------------------------------------
-- Kill creature → drop resources
---------------------------------------------------------------------------

function Creatures.kill(id)
    local cr = ECS.get(id, 'creature')
    if not cr then return end

    cr.state = 'dead'

    -- Notify raid system before entity is destroyed
    local rok, Raids = pcall(require, 'src.sim.raids')
    if rok and Raids.onCreatureDeath then
        Raids.onCreatureDeath(id)
    end

    -- Notify quest system
    local qok, QuestMod = pcall(require, 'src.quest.quest')
    if qok and QuestMod.onCreatureKilled then
        QuestMod.onCreatureKilled(cr.species)
    end

    -- Drop loot at death location (scaled by elastic difficulty loot modifier)
    local pos = ECS.get(id, 'pos')
    if pos then
        local lootMod = 1.0
        local elOk, ElasticL = pcall(require, 'src.sim.elastic_difficulty')
        if elOk then lootMod = ElasticL.getLootMod() end

        -- Big game hunter mastery: double loot from megafauna (check all living colonists)
        if cr.tier == 'megafauna' then
            local skOk, SKills = pcall(require, 'src.colonist.skills')
            if skOk then
                for cid in ECS.query('colonist') do
                    if SKills.hasMastery(cid, 'big_game_hunter') then
                        local eff = SKills.getMasteryEffect(cid, 'big_game_hunter')
                        if eff and eff.megaLoot then lootMod = lootMod * eff.megaLoot end
                        break
                    end
                end
            end
        end

        -- Explicit encounter loot comes from raid/special drop tables.
        local Items = getItems()
        local sp = SPECIES[cr.species]
        if sp and sp.loot then
            for res, amt in pairs(sp.loot) do
                local dropAmt = math.floor(amt * lootMod + 0.5)
                if Items then Items.spawn(pos.x, pos.y, res, dropAmt, nil, pos.depth or 0)
                else GameState.addResource(res, dropAmt) end
            end
        elseif cr.drops then
            if cr.drops.thermalCore and cr.drops.thermalCore > 0 then
                local coreAmt = math.floor(cr.drops.thermalCore * lootMod + 0.5)
                if Items then Items.spawn(pos.x, pos.y, 'thermalCores', coreAmt, nil, pos.depth or 0)
                else GameState.addResource('thermalCores', coreAmt) end
            end

            if (cr.drops.meat and cr.drops.meat > 0) or (cr.meat and cr.meat > 0) then
                local corpseCount = math.max(1, math.floor(lootMod + 0.5))
                GameState.resources.corpse_creature = (GameState.resources.corpse_creature or 0) + corpseCount
            end
        else
            -- Standard fauna leaves a corpse to butcher; thermal cores come from
            -- explicit deep/ruin salvage, not routine wildlife kills.
            if cr.meat and cr.meat > 0 then
                local corpseCount = math.max(1, math.floor(lootMod + 0.5))
                GameState.resources.corpse_creature = (GameState.resources.corpse_creature or 0) + corpseCount
            end
        end
    end

    -- Nemaea automaton drops: mechanical creatures may contain prisoners/corpses
    do
        local spDef = SPECIES[cr.species]
        if pos and spDef and spDef.mechanical then
            local pok, Planet = pcall(require, 'src.world.planet')
            if pok and Planet.getId() == 'nemaea' then
                -- Loot modifier (re-query; scoped to outer block above)
                local autoLootMod = 1.0
                local aelOk, AElastic = pcall(require, 'src.sim.elastic_difficulty')
                if aelOk then autoLootMod = AElastic.getLootMod() end

                -- Always drop components (2-4) and metal (1-3)
                local compDrop = math.floor(math.random(2, 4) * autoLootMod + 0.5)
                local metalDrop = math.floor(math.random(1, 3) * autoLootMod + 0.5)
                local AItems = getItems()
                if AItems then
                    AItems.spawn(pos.x, pos.y, 'components', compDrop, nil, pos.depth or 0)
                    AItems.spawn(pos.x, pos.y, 'metal', metalDrop, nil, pos.depth or 0)
                else
                    GameState.addResource('components', compDrop)
                    GameState.addResource('metal', metalDrop)
                end

                -- 40% chance: spawn a prisoner (person trapped inside the automaton)
                local prisonerRoll = math.random()
                if prisonerRoll < 0.40 then
                    local recOk, Recruitment = pcall(require, 'src.colonist.recruitment')
                    if recOk and Recruitment.tryCapture then
                        -- Tag entity temporarily so tryCapture sees it as a raid kill
                        if not ECS.get(id, 'raid_tag') then
                            ECS.set(id, 'raid_tag', { raidType = 'automaton', factionId = nil })
                        end
                        Recruitment.tryCapture(id)
                    end
                elseif prisonerRoll < 0.70 then
                    -- 30% chance: spawn a human corpse (dead occupant)
                    GameState.resources.corpse_human = (GameState.resources.corpse_human or 0) + 1
                end
            end
        end
    end

    -- Phase 5: notify hunting system for hide drops
    local hok, Hunting = pcall(require, 'src.combat.hunting')
    if hok then Hunting.onCreatureKilled(id) end

    -- Eldritch creature: chance to drop node spore
    local enOk, EldritchNodes = pcall(require, 'src.creatures.eldritch_nodes')
    if enOk then EldritchNodes.onEldritchCreatureKilled(id) end

    -- Notify visitor system (hostile scout kill → raid delay)
    local vok, VisitorsMod = pcall(require, 'src.trade.visitors')
    if vok and VisitorsMod.onScoutKilled then
        VisitorsMod.onScoutKilled(id)
    end

    -- Notify storyteller
    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk and Storyteller.logEvent then
        local name = cr.name or cr.species or 'A creature'
        Storyteller.logEvent('creature_killed', name .. ' was killed.')
    end

    ECS.destroy(id)
end

---------------------------------------------------------------------------
-- Combat — colonist attacks creature
---------------------------------------------------------------------------

function Creatures.damageCreature(creatureId, amount, attackerId)
    local cr = ECS.get(creatureId, 'creature')
    if not cr or cr.state == 'dead' then return end

    -- Armor reduction: creature-level override (rivals), else species default
    local armor = cr.armorReduction
    if not armor then
        local sp = SPECIES[cr.species]
        armor = sp and sp.armorReduction
    end
    if armor then
        amount = math.max(1, amount - armor)
    end

    cr.health = cr.health - amount
    if cr.health <= 0 then
        -- Rival cheat-death check: rival may crawl away instead of dying
        local rivalComp = ECS.get(creatureId, 'rival')
        if rivalComp then
            local rok, RivalsMod = pcall(require, 'src.sim.rivals')
            if rok and RivalsMod.onRivalDeath(creatureId, attackerId) then
                -- Rival cheated death: force flee with 1 HP
                cr.health = 1
                cr.state = 'flee'
                cr.fleeRange = 999
                cr.hostile = false
                local pos = ECS.get(creatureId, 'pos')
                if pos then
                    local wok, World = pcall(require, 'src.world.tilemap')
                    if wok then
                        local w, h = World.width(), World.height()
                        if pos.x < w / 2 then pos.homeX = 0 else pos.homeX = w - 1 end
                        if pos.y < h / 2 then pos.homeY = 0 else pos.homeY = h - 1 end
                    end
                end
                return false  -- not killed
            end
        end

        -- Scar trait: megafauna/megabeast kill
        if attackerId and (cr.isMegabeast or cr.tier == 'megafauna') then
            local scarOk, ScarTraits = pcall(require, 'src.colonist.scar_traits')
            if scarOk then ScarTraits.onMegafaunaKill(attackerId) end
        end
        -- Bloodlust trait: +5 morale on kill
        if attackerId then
            local aCol = ECS.get(attackerId, 'colonist')
            if aCol and aCol.traits then
                for _, t in ipairs(aCol.traits) do
                    if t.id == 'bloodlust' then
                        local aN = ECS.get(attackerId, 'needs')
                        if aN then aN.morale = math.min(100, aN.morale + 5) end
                        break
                    end
                end
            end
        end
        Creatures.kill(creatureId)
        return true  -- killed
    end
    return false
end

---------------------------------------------------------------------------
-- AI system (split to src/ai/creature_ai.lua)
---------------------------------------------------------------------------

function Creatures.registerSystems()
    local ok, CreatureAI = pcall(require, 'src.ai.creature_ai')
    if ok and CreatureAI.registerSystems then
        CreatureAI.registerSystems()
    end
end

Creatures.registerSystems()

function Creatures.getSpeciesDefs()
    return SPECIES
end

return Creatures
