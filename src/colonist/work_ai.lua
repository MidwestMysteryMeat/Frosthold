-- work_ai.lua — Colonist work AI system
-- Replaces idle wander. Checks schedule → finds task → paths → executes.
-- Handles eat/sleep blocks, work priority tasks, and idle fallback.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Jobs      = require('src.colonist.jobs')
local Schedule  = require('src.colonist.schedule')
local Pathfind  = require('src.util.pathfind')
local Occupancy = require('src.util.occupancy')
local World     = require('src.world.tilemap')
local Tiles     = require('src.world.tiles')
local Zones     = require('src.world.zones')
local Beds      = require('src.building.beds')
local Items     = require('src.world.items')
local ItemDefs  = require('src.world.item_defs')

local WorkAI = {}

---------------------------------------------------------------------------
-- Survival AI tuning
---------------------------------------------------------------------------

-- Hunger/thirst urgent enough to interrupt any schedule block AND to outrank
-- warming up at a fire. Was 15 (food only), which meant a colonist queued at
-- a bonfire through the eat block simply starved next to the food pile.
local URGENT_FOOD   = 35
local URGENT_WATER  = 35

-- Cold emergency trigger is staggered per colonist inside this band so the
-- whole colony does not abandon work on the same tick. Release is shared so
-- everyone actually resumes work once warm (hysteresis).
local COLD_TRIGGER_MIN = 35
local COLD_TRIGGER_MAX = 45
local COLD_RELEASE     = 70

-- A fixed warmth threshold is not enough on its own: warmth drains at
-- (10 - tileTemp) * 0.005 per second, so at -60C a colonist loses 0.35/s and
-- only has ~115 seconds of life left at warmth 40 — not enough to walk back to
-- a fire from across the map. The trigger therefore also fires on TIME TO
-- FREEZE, which retreats early in extreme cold and stays relaxed in a mild
-- chill. Staggered per colonist for the same reason as the warmth band.
local COLD_LEAD_MIN = 150  -- seconds of warmth left before heading for a fire
local COLD_LEAD_MAX = 210

-- Two temperatures matter, and conflating them was killing colonists.
--   WARM_TILE_TEMP    the preferred target: comfortably inside a fire's zone,
--                     warmth climbs fast, no risk of parking on a tile that
--                     merely breaks even.
--   WARM_RECOVER_TEMP the temperature at which colonist.lua actually STARTS
--                     restoring warmth (> 10C). A campfire's outdoor falloff
--                     ring is a band of 10-15C tiles, and in deep cold that
--                     band is all that is left — the >15C core shrinks to the
--                     fire tile itself. The old search accepted only >15C, so
--                     a colonist stood 20 tiles from a 12C tile that would
--                     have saved it and froze instead.
local WARM_TILE_TEMP    = 15
local WARM_RECOVER_TEMP = 10.5
-- Last resort: settle for any reachable tile at least this much warmer.
local WARM_FALLBACK_GAIN = 6
-- How many A* attempts each fallback tier may spend. One attempt was not
-- enough: the single warmest tile is usually the one another colonist is
-- already huddling on, and Pathfind refuses an occupied goal.
local WARM_PATH_TRIES = 8
-- Emergency routes get a bigger node budget and ignore the deep-snow
-- surcharge. During a blizzard every outdoor tile carries that surcharge,
-- which flattens the Manhattan heuristic and degenerates A* into Dijkstra, so
-- the default 3000-node budget could not reach a fire 25 tiles away.
local WARM_PATH_OPTS = { maxNodes = 20000, ignoreSnowCost = true }

-- Deterministic per-entity stagger (no RNG: survives save/load)
local function coldTriggerWarmth(id, col)
    if not col._coldTrigger then
        col._coldTrigger = COLD_TRIGGER_MIN
            + (id % (COLD_TRIGGER_MAX - COLD_TRIGGER_MIN + 1))
        col._coldLead = COLD_LEAD_MIN
            + (id % (COLD_LEAD_MAX - COLD_LEAD_MIN + 1))
    end
    return col._coldTrigger
end

--- Should this colonist drop everything and head for warmth?
--- Returns the effective threshold too, so hysteresis can stay above it.
local function needsWarmth(id, col, warmth, tileTemp)
    local base = coldTriggerWarmth(id, col)
    if warmth < base then return true, base end
    -- Time-to-freeze at the current tile
    if tileTemp < 10 then
        local drain = (10 - tileTemp) * 0.005
        if drain > 0 and (warmth / drain) < (col._coldLead or COLD_LEAD_MIN) then
            return true, math.max(base, warmth)
        end
    end
    return false, base
end

---------------------------------------------------------------------------
-- Cold trace (dev diagnostic, `--coldtrace`)
---------------------------------------------------------------------------
-- Freezing deaths are hard to read from a corpse: the [SimDeath] line says
-- "warmth 0, no wounds" but not why nobody walked to a fire. This prints the
-- decision trail — who went cold, where, what the warmth search returned.
local function ctrace(fmt, ...)
    if not _G.COLD_TRACE then return end
    print(string.format('[Cold] d%d %05.2f ' .. fmt, GameState.day or 0,
        GameState.hour or 0, ...))
end

local function ctraceOn()
    return _G.COLD_TRACE == true
end

local OptionalModules = {}

local function getOptionalModule(path)
    local mod = OptionalModules[path]
    if mod ~= nil then
        return mod or nil
    end
    local ok, loaded = pcall(require, path)
    OptionalModules[path] = ok and loaded or false
    return OptionalModules[path] or nil
end

-- Lazy-loaded modules for work speed / skill lookups (avoid pcall in hot path)
local _Skills, _Policies, _Addiction, _MentalBreaks, _Laws, _StatusFx, _Lighting, _Rec
local function lazyLoadWorkMods()
    if _Skills ~= nil then return end
    _Skills = getOptionalModule('src.colonist.skills') or false
    _Policies = getOptionalModule('src.colony.policies') or false
    _Addiction = getOptionalModule('src.colonist.addiction') or false
    _MentalBreaks = getOptionalModule('src.colonist.mental_breaks') or false
    _Laws = getOptionalModule('src.colony.laws') or false
    _StatusFx = getOptionalModule('src.sim.status_effects') or false
    _Lighting = getOptionalModule('src.sim.lighting') or false
    _Rec = getOptionalModule('src.colonist.recreation') or false
end

-- Skill XP progression
local function awardTaskXp(entityId, taskType)
    lazyLoadWorkMods()
    if _Skills then _Skills.onTaskComplete(entityId, taskType) end
end

-- Read skill level with polymath mastery bonus
local function effectiveSkill(entityId, skillName)
    lazyLoadWorkMods()
    if _Skills then return _Skills.getEffectiveLevel(entityId, skillName) end
    local col = ECS.get(entityId, 'colonist')
    return col and col.skills and col.skills[skillName] or 1
end

---------------------------------------------------------------------------
-- Task execution handlers (what happens when colonist arrives at task)
---------------------------------------------------------------------------

-- Compute combined work speed multiplier from policies, addictions, and stress
local function getWorkSpeedMods(id)
    lazyLoadWorkMods()
    local mult = 1.0
    if _Policies then mult = mult * _Policies.getWorkSpeedMult() end
    -- Doctrine work speed bonus (Order path)
    local Doctrines = getOptionalModule('src.colony.doctrines')
    if Doctrines and Doctrines.getWorkSpeedMult then mult = mult * Doctrines.getWorkSpeedMult() end
    if _Addiction then mult = mult * _Addiction.getWorkSpeedMult(id) end
    if _MentalBreaks then mult = mult * _MentalBreaks.getWorkSpeedMult(id) end
    -- Laws work speed multiplier (all_hands_working etc.)
    if _Laws then mult = mult * _Laws.getWorkSpeedMult() end
    -- Status effects (frostbite, exhaustion, infection)
    if _StatusFx then mult = mult * _StatusFx.getWorkSpeedMult(id) end
    -- Darkness penalty (below 0.3 light = 20% slower)
    local pos = ECS.get(id, 'pos')
    if pos and _Lighting then
        mult = mult * _Lighting.getWorkSpeedMod(pos.x, pos.y)
    end
    -- Trait workSpeed modifier (hardworking +15%, lazy -20%)
    local col = ECS.get(id, 'colonist')
    if col and col.traits then
        for _, t in ipairs(col.traits) do
            if t.workSpeed then mult = mult * (1 + t.workSpeed) end
            if t.id == 'night_owl' then
                mult = mult * (GameState.isDaytime() and 0.90 or 1.15)
            end
        end
    end
    return mult
end

local function getRestrictedPathOpts(pos)
    local depth = pos.depth or 0
    if Zones.hasRestrictedZones(depth) and Zones.isTileAllowed(pos.x, pos.y, depth) then
        return {
            allowTile = function(x, y, tileDepth)
                return Zones.isTileAllowed(x, y, tileDepth or 0)
            end,
        }
    end
    return nil
end

local function isTaskAllowed(task)
    if not task then return true end
    local taskDepth = task.depth or 0
    if not Zones.isTileAllowed(task.x, task.y, taskDepth) then
        return false
    end
    if task.data and task.data.toX and task.data.toY then
        return Zones.isTileAllowed(task.data.toX, task.data.toY, task.data.toDepth or taskDepth)
    end
    return true
end

local function executeMine(dt, id, col, task)
    local Perks = getOptionalModule('src.colony.perks')
    local MSkills = getOptionalModule('src.colonist.skills')
    local Containment = getOptionalModule('src.sim.containment')
    local Director = getOptionalModule('src.ai.director')
    local ThermovoreSpawner = getOptionalModule('src.creatures.thermovore_spawner')
    local Megabeasts = getOptionalModule('src.creatures.megabeasts')

    -- Skill speed bonus + policy/addiction/stress modifiers (polymath-aware)
    local skillLevel = effectiveSkill(id, 'mining')
    local speed = (1 + (skillLevel - 1) * 0.12) * getWorkSpeedMods(id)

    -- Underwater mining penalty: 40% slower when mining flooded tiles
    local td0 = task.depth or 0
    if td0 > 0 then
        local wOk, WorldCheck = pcall(require, 'src.world.tilemap')
        if wOk then
            local waterLevel = WorldCheck.getWater(task.x, task.y, td0)
            if waterLevel and waterLevel > 1 then
                speed = speed * 0.6
            end
        end
    end

    -- Demolisher mastery: 30% faster mining
    if MSkills and MSkills.hasMastery(id, 'demolisher') then
        local eff = MSkills.getMasteryEffect(id, 'demolisher')
        if eff and eff.mineMult then speed = speed * eff.mineMult end
    end

    local function maybeExposeThermalSeam()
        local coreChance = 0
        if Perks then
            coreChance = coreChance + Perks.getSumEffect('thermalCoreChance')
        end
        if MSkills and MSkills.hasMastery(id, 'geologist') then
            local eff = MSkills.getMasteryEffect(id, 'geologist')
            if eff and eff.coreChance then
                coreChance = coreChance + eff.coreChance
            end
        end
        if coreChance > 0 and math.random() < coreChance then
            local cpos = ECS.get(id, 'pos')
            local cx = cpos and cpos.x or task.x
            local cy = cpos and cpos.y or task.y
            Items.spawn(cx, cy, 'thermalCores', 1, nil, task.depth or 0)
        end
    end

    local function maybeRecoverDeepSubject()
        if (task.depth or 0) <= 0 then return end
        if math.random() >= 0.05 then return end
        if not Containment or not Containment.registerFieldSubject then return end
        local templates = {
            'resonant_shard',
            'signal_idol',
            'mimic_tissue',
            'node_sample',
            'latent_survivor',
            'thrall_prisoner',
            'vessel_host',
        }
        local templateId = templates[math.random(#templates)]
        Containment.registerFieldSubject(templateId, {
            source = string.format('deep cut at depth %d', task.depth or 0),
            originX = task.x,
            originY = task.y,
            originDepth = task.depth or 0,
        })
    end

    task.progress = task.progress + dt * speed
    if task.progress >= task.def.duration then
        -- Mining generates noise (attracts nearby creatures via Director)
        if Director then Director.onNoise(task.x, task.y, 1.0) end

        -- Underground mining attracts thermovores (seismic noise)
        local td = task.depth or 0
        if td > 0 then
            if ThermovoreSpawner then ThermovoreSpawner.onNoise(task.x, task.y, td, 1.0) end
        end

        -- Mine the tile
        local pos = ECS.get(id, 'pos')
        local spawnX = pos and pos.x or task.x
        local spawnY = pos and pos.y or task.y
        local tile = World.getTile(task.x, task.y, td)
        if tile == Tiles.ROCK then
            World.setTile(task.x, task.y, Tiles.DEBRIS, td)
            -- Perk: deep_veins bonus ore
            local bonusOre = 0
            if Perks then bonusOre = Perks.getSumEffect('miningBonusOre') end
            -- Deep miner mastery: +1 bonus ore
            if MSkills and MSkills.hasMastery(id, 'deep_miner') then
                local eff = MSkills.getMasteryEffect(id, 'deep_miner')
                if eff then bonusOre = bonusOre + (eff.bonusOre or 0) end
            end
            Items.spawn(spawnX, spawnY, 'stone', 2 + math.floor(skillLevel / 3), nil, td)
            -- Chance of ore
            if math.random() < 0.2 + skillLevel * 0.03 then
                Items.spawn(spawnX, spawnY, 'metal', 1 + bonusOre, nil, td)
            end
            -- Megabeast trigger on tile mined
            if Megabeasts then Megabeasts.onTileMined() end
        elseif tile == Tiles.ICE then
            World.setTile(task.x, task.y, Tiles.SNOW, td)
            Items.spawn(spawnX, spawnY, 'water', 2, nil, td)  -- mining ice yields water
        elseif tile == Tiles.TREE then
            World.setTile(task.x, task.y, Tiles.SNOW, td)
            Items.spawn(spawnX, spawnY, 'wood', 3 + math.floor(skillLevel / 4), nil, td)
            -- Small chance of plant_fiber bonus
            if math.random() < 0.3 then
                Items.spawn(spawnX, spawnY, 'hide', 1, nil, td)  -- bark/fiber
            end
        elseif tile == Tiles.ORE_VEIN then
            World.setTile(task.x, task.y, Tiles.DEBRIS, td)
            local bonusOre = 0
            if Perks then bonusOre = Perks.getSumEffect('miningBonusOre') end
            -- Deep miner mastery: +1 bonus ore from ore veins
            if MSkills and MSkills.hasMastery(id, 'deep_miner') then
                local eff = MSkills.getMasteryEffect(id, 'deep_miner')
                if eff then bonusOre = bonusOre + (eff.bonusOre or 0) end
            end
            Items.spawn(spawnX, spawnY, 'metal', 3 + bonusOre + math.floor(skillLevel / 3), nil, td)
            Items.spawn(spawnX, spawnY, 'stone', 1, nil, td)
            -- Megabeast trigger on tile mined
            if Megabeasts then Megabeasts.onTileMined() end
        elseif tile == Tiles.DEEP_ROCK then
            World.setTile(task.x, task.y, Tiles.UNDERGROUND_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'stone', 3 + math.floor(skillLevel / 3), nil, td)
            if math.random() < 0.3 + skillLevel * 0.03 then
                Items.spawn(spawnX, spawnY, 'metal', 1, nil, td)
            end
            maybeExposeThermalSeam()
            maybeRecoverDeepSubject()
            if Megabeasts then Megabeasts.onTileMined() end
        elseif tile == Tiles.UNDERGROUND_ROCK then
            World.setTile(task.x, task.y, Tiles.UNDERGROUND_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'stone', 2 + math.floor(skillLevel / 4), nil, td)
            maybeExposeThermalSeam()
            maybeRecoverDeepSubject()
            if Megabeasts then Megabeasts.onTileMined() end
        elseif tile == Tiles.LEAD_ORE then
            local resultTile = (td > 0) and Tiles.UNDERGROUND_FLOOR or Tiles.DEBRIS
            World.setTile(task.x, task.y, resultTile, td)
            Items.spawn(spawnX, spawnY, 'lead', 3 + math.floor(skillLevel / 3), nil, td)
            Items.spawn(spawnX, spawnY, 'stone', 1, nil, td)
            if Megabeasts then Megabeasts.onTileMined() end
        elseif tile == Tiles.VOLCANIC_ROCK then
            World.setTile(task.x, task.y, Tiles.VOLCANIC_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'stone', 4 + math.floor(skillLevel / 3), nil, td)
            if Megabeasts then Megabeasts.onTileMined() end
        elseif tile == Tiles.DEAD_TREE then
            World.setTile(task.x, task.y, Tiles.ASH_GROUND, td)
            Items.spawn(spawnX, spawnY, 'wood', 1 + math.floor(skillLevel / 5), nil, td)

        -- Desert tiles (Rhea-2)
        elseif tile == Tiles.SANDSTONE then
            World.setTile(task.x, task.y, Tiles.SAND, td)
            Items.spawn(spawnX, spawnY, 'stone', 3 + math.floor(skillLevel / 3), nil, td)
            if math.random() < 0.15 then
                Items.spawn(spawnX, spawnY, 'metal', 1, nil, td)
            end
        elseif tile == Tiles.DUNE then
            World.setTile(task.x, task.y, Tiles.SAND, td)
            Items.spawn(spawnX, spawnY, 'stone', 1, nil, td)
        elseif tile == Tiles.CACTUS then
            World.setTile(task.x, task.y, Tiles.SAND, td)
            Items.spawn(spawnX, spawnY, 'food', 2, nil, td)

        -- Temperate tiles (Paxtera Prime, Gaia A^1x)
        elseif tile == Tiles.DECIDUOUS_TREE then
            World.setTile(task.x, task.y, Tiles.GRASS, td)
            Items.spawn(spawnX, spawnY, 'wood', 4 + math.floor(skillLevel / 4), nil, td)
            if math.random() < 0.25 then
                Items.spawn(spawnX, spawnY, 'food', 1, nil, td)  -- fruit
            end
        elseif tile == Tiles.BUSH then
            World.setTile(task.x, task.y, Tiles.GRASS, td)
            Items.spawn(spawnX, spawnY, 'food', 1, nil, td)

        -- Vacuum tiles (Nemaea)
        elseif tile == Tiles.METAL_DEBRIS then
            World.setTile(task.x, task.y, Tiles.REGOLITH, td)
            Items.spawn(spawnX, spawnY, 'metal', 4 + math.floor(skillLevel / 3), nil, td)
            if math.random() < 0.3 then
                Items.spawn(spawnX, spawnY, 'components', 1, nil, td)
            end
        elseif tile == Tiles.HULL_PLATE then
            World.setTile(task.x, task.y, Tiles.REGOLITH, td)
            Items.spawn(spawnX, spawnY, 'components', 2 + math.floor(skillLevel / 4), nil, td)
            Items.spawn(spawnX, spawnY, 'metal', 2, nil, td)

        -- Ocean tiles (Nerthus-9) — mined tile becomes flooded open water
        elseif tile == Tiles.CORAL then
            World.setTile(task.x, task.y, Tiles.SHALLOWS, td)
            Items.spawn(spawnX, spawnY, 'stone', 2, nil, td)
        elseif tile == Tiles.CORAL_DEPOSIT then
            World.setTile(task.x, task.y, Tiles.UNDERGROUND_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'stone', 4 + math.floor(skillLevel / 3), nil, td)
            Items.spawn(spawnX, spawnY, 'food', 1, nil, td)
        elseif tile == Tiles.MINERAL_NODULE then
            World.setTile(task.x, task.y, Tiles.UNDERGROUND_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'metal', 5 + math.floor(skillLevel / 3), nil, td)
        elseif tile == Tiles.THERMAL_MINERAL then
            World.setTile(task.x, task.y, Tiles.UNDERGROUND_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'components', 3 + math.floor(skillLevel / 4), nil, td)
            if math.random() < 0.2 then
                Items.spawn(spawnX, spawnY, 'circuit', 1, nil, td)
            end
        elseif tile == Tiles.KELP_FOREST then
            World.setTile(task.x, task.y, Tiles.SHALLOWS, td)
            Items.spawn(spawnX, spawnY, 'food', 3 + math.floor(skillLevel / 4), nil, td)
        elseif tile == Tiles.SUNKEN_WRECK then
            World.setTile(task.x, task.y, Tiles.UNDERGROUND_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'metal', 6 + math.floor(skillLevel / 3), nil, td)
            Items.spawn(spawnX, spawnY, 'components', 2, nil, td)
            -- Wrecks occasionally contain sealed cargo
            if math.random() < 0.15 then
                Items.spawn(spawnX, spawnY, 'circuit', 1, nil, td)
            end
        elseif tile == Tiles.BRINE_POCKET then
            World.setTile(task.x, task.y, Tiles.UNDERGROUND_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'fuel', 3 + math.floor(skillLevel / 4), nil, td)
            Items.spawn(spawnX, spawnY, 'water', 2, nil, td)

        -- Biological walls (Erebus biocaves, Gaia corruption)
        elseif tile == Tiles.FUNGAL_WALL then
            World.setTile(task.x, task.y, Tiles.FUNGAL_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'food', 1 + math.floor(skillLevel / 5), nil, td)
        elseif tile == Tiles.MEMBRANE_WALL then
            World.setTile(task.x, task.y, Tiles.MEMBRANE_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'hide', 2, nil, td)
            if math.random() < 0.15 then
                Items.spawn(spawnX, spawnY, 'medicinal_herb', 1, nil, td)
            end
        elseif tile == Tiles.ORGAN_WALL then
            World.setTile(task.x, task.y, Tiles.ORGAN_FLOOR, td)
            Items.spawn(spawnX, spawnY, 'hide', 3, nil, td)
            Items.spawn(spawnX, spawnY, 'raw_fat', 1, nil, td)
            -- Mining Baldrungen tissue is disturbing
            local needs = ECS.get(id, 'needs')
            if needs and needs.morale then
                needs.morale = math.max(0, needs.morale - 5)
            end
        end
        awardTaskXp(id, 'mine')
        Jobs.completeTask(task.id)
    end
end

local function executeBuild(dt, id, col, task)
    local Building = require('src.building.building')
    local skillLevel = effectiveSkill(id, 'building')
    local speed = (1 + (skillLevel - 1) * 0.1) * getWorkSpeedMods(id)
    local BSkills = getOptionalModule('src.colonist.skills')
    local DebugPanel = getOptionalModule('src.ui.debug_panel')
    local Director = getOptionalModule('src.ai.director')
    local ThermovoreSpawner = getOptionalModule('src.creatures.thermovore_spawner')
    local Hope = getOptionalModule('src.colony.hope')

    -- Speed builder mastery: builds 30% faster
    if BSkills and BSkills.hasMastery(id, 'speed_builder') then
        local eff = BSkills.getMasteryEffect(id, 'speed_builder')
        if eff and eff.buildMult then speed = speed * eff.buildMult end
    end

    -- Debug: instant build skips progress accumulation
    if DebugPanel and DebugPanel.instantBuild then
        task.progress = task.def.duration
    else
        task.progress = task.progress + dt * speed
    end
    if task.progress >= task.def.duration then
        -- Building generates noise (attracts nearby creatures via Director)
        if Director then Director.onNoise(task.x, task.y, 1.5) end

        -- Underground building attracts thermovores
        local btd = task.depth or 0
        if btd > 0 then
            if ThermovoreSpawner then ThermovoreSpawner.onNoise(task.x, task.y, btd, 1.5) end
        end

        local costAlreadyPaid = task.data and task.data.costPaid ~= nil
        local ok, err = Building.tryPlace(task.data.buildingId, task.x, task.y, id, costAlreadyPaid, task.depth)
        if ok then
            -- Resources consumed — clear costPaid so cancel won't refund
            if task.data then task.data.costPaid = nil end
            -- Notify hope system on successful build
            if Hope then
                local def = Building.defs[task.data.buildingId]
                Hope.onBuildingCompleted(def and def.name or task.data.buildingId)
            end
            awardTaskXp(id, 'build')
            Jobs.completeTask(task.id)
        else
            -- Placement failed (tile blocked) — cancel task (refunds via cancelTask)
            Jobs.cancelTask(task.id)
        end
    end
end

local function executeHaul(dt, id, col, task)
    if not task.data then task.data = {} end
    if not task.data.phase then task.data.phase = 'pickup' end

    if task.data.phase == 'pickup' then
        -- At pickup location: brief pickup time then walk to destination
        task.progress = task.progress + dt
        if task.progress >= 0.5 then
            -- Mark item as being carried
            if task.data.itemEntityId and ECS.isAlive(task.data.itemEntityId) then
                local itemEnt = ECS.get(task.data.itemEntityId, 'item')
                if itemEnt then
                    itemEnt.hauled = true
                    -- Track carry weight on the colonist's inventory
                    local inv = ECS.get(id, 'inventory')
                    if inv then
                        local w = ItemDefs.getWeight(itemEnt.itemId) * (itemEnt.amount or 1)
                        inv.currentWeight = (inv.currentWeight or 0) + w
                    end
                end
            end

            -- Redirect to delivery destination
            task.data.phase = 'delivery'
            task.progress = 0
            task.x = task.data.toX or task.x
            task.y = task.data.toY or task.y
            col.task.arrived = false
            col.state = 'hauling'

            -- Path to drop-off
            local colPos = ECS.get(id, 'pos')
            local pathComp = ECS.get(id, 'path')
            if colPos and pathComp and task.data.toX and task.data.toY then
                local World = require('src.world.tilemap')
                local Pathfind = require('src.util.pathfind')
                local route = Pathfind.find(colPos.x, colPos.y,
                    task.data.toX, task.data.toY, World, id,
                    colPos.depth or 0, task.data.toDepth or 0)
                if route then
                    pathComp.nodes = route
                    pathComp.index = 1
                    pathComp.moveTimer = 0
                else
                    -- Can't reach destination — drop item here
                    col.task.arrived = true
                    task.data.phase = 'dropoff'
                end
            else
                col.task.arrived = true
                task.data.phase = 'dropoff'
            end
        end
    else
        -- Phase 'delivery' or 'dropoff': colonist arrived at destination
        if task.data.itemEntityId and ECS.isAlive(task.data.itemEntityId) then
            local itemEnt = ECS.get(task.data.itemEntityId, 'item')
            local itemPos = ECS.get(task.data.itemEntityId, 'pos')
            local colPos = ECS.get(id, 'pos')
            if itemEnt and task.data.storageEntityId then
                -- Store in storage building slot
                local storOk, StorageMod = pcall(require, 'src.building.storage')
                if storOk then
                    StorageMod.storeInSlot(task.data.storageEntityId, task.data.storageSlotIdx,
                        itemEnt.itemId, itemEnt.amount,
                        itemEnt.quality, itemEnt.material, itemEnt.durability or 100)
                end
                ECS.destroy(task.data.itemEntityId)
            elseif itemEnt and task.data.zoneId then
                Zones.storeItem(
                    task.data.zoneId,
                    task.data.toX or task.x,
                    task.data.toY or task.y,
                    itemEnt.itemId,
                    itemEnt.amount,
                    task.data.toDepth or (colPos and colPos.depth) or 0,
                    itemEnt.quality,
                    itemEnt.material
                )
                ECS.destroy(task.data.itemEntityId)
            else
                if itemPos and colPos then
                    itemPos.x = colPos.x
                    itemPos.y = colPos.y
                    itemPos.depth = colPos.depth or 0
                end
                if itemEnt then
                    itemEnt._haulTaskId = nil
                    itemEnt.hauled = false
                end
            end
        end
        -- Clear carry weight now that item is delivered or dropped
        local inv = ECS.get(id, 'inventory')
        if inv then inv.currentWeight = 0 end
        Jobs.completeTask(task.id)
    end
end

local function executeGeneric(dt, id, col, task)
    local skillLevel = 1
    if task.def.skill then
        skillLevel = effectiveSkill(id, task.def.skill)
    end
    local speed = (1 + (skillLevel - 1) * 0.1) * getWorkSpeedMods(id)

    task.progress = task.progress + dt * speed
    if task.progress >= task.def.duration then
        awardTaskXp(id, task.type)
        Jobs.completeTask(task.id)
    end
end

local function executeMineOrLair(dt, id, col, task)
    -- Phase 5: lair destruction via mine task
    if task.data.isLair and task.data.lairId then
        local Lairs = getOptionalModule('src.creatures.lairs')
        if Lairs then
            local skillLevel = effectiveSkill(id, 'mining')
            local speed = (1 + (skillLevel - 1) * 0.12) * getWorkSpeedMods(id)
            task.progress = task.progress + dt * speed
            if task.progress >= task.def.duration then
                Lairs.damage(task.data.lairId, 200)
                Jobs.completeTask(task.id)
            end
            return
        end
    end
    executeMine(dt, id, col, task)
end

local function executeHunt(dt, id, col, task)
    local Hunting = getOptionalModule('src.combat.hunting')
    if Hunting then
        Hunting.execute(dt, id, col, task)
    else
        executeGeneric(dt, id, col, task)
    end
end

local function executeMedical(dt, id, col, task)
    local patientId = task.data.patientId
    if not patientId or not ECS.isAlive(patientId) then
        Jobs.completeTask(task.id)
        return
    end

    local Wounds = getOptionalModule('src.combat.wounds')
    if not Wounds then
        executeGeneric(dt, id, col, task)
        return
    end

    local skillLevel = effectiveSkill(id, 'medical')
    local speed = (1 + (skillLevel - 1) * 0.15) * getWorkSpeedMods(id)

    task.progress = task.progress + dt * speed
    if task.progress >= task.def.duration then
        -- Consume medicine for treatment (wounds or disease)
        local medQuality = 0
        if GameState.resources.medicine and GameState.resources.medicine >= 1 then
            GameState.spendResource('medicine', 1)
            medQuality = 2
        elseif GameState.resources.bandage and GameState.resources.bandage >= 1 then
            GameState.spendResource('bandage', 1)
            medQuality = 1
        end

        -- Treat the first untreated wound on the patient
        local wounds = ECS.get(patientId, 'wounds')
        if wounds then
            for _, w in ipairs(wounds.list) do
                if w.treatment ~= 'healed' and w.treatment ~= 'medicated' then
                    Wounds.treat(w, skillLevel)
                    break
                end
            end
        end
        -- Surgeon mastery: restore destroyed limbs after wounds treated
        local BodyMod = getOptionalModule('src.combat.body')
        if BodyMod then
            local body = ECS.get(patientId, 'body')
            if body then
                for _, pn in ipairs(BodyMod.PART_NAMES) do
                    local p = body.parts[pn]
                    if p and p.status == 'destroyed' then
                        BodyMod.healPart(patientId, pn, skillLevel * 3, id)
                    end
                end
            end
        end
        -- Treat disease if this is a disease treatment task
        if task.data.diseaseTask then
            local Disease = getOptionalModule('src.sim.disease')
            if Disease and Disease.treat then
                Disease.treat(patientId, skillLevel, medQuality)
            end
        end
        -- If more wounds remain, reset progress for next wound
        if Wounds.hasUntreatedWounds(patientId) then
            task.progress = 0
        else
            awardTaskXp(id, 'medical')
            Jobs.completeTask(task.id)
        end
    end
end

local function executeHarvest(dt, id, col, task)
    local skillLevel = effectiveSkill(id, 'cooking')
    local speed = (1 + (skillLevel - 1) * 0.1) * getWorkSpeedMods(id)
    task.progress = task.progress + dt * speed
    if task.progress >= task.def.duration then
        if task.data.cropId then
            local Agriculture = getOptionalModule('src.building.agriculture')
            if Agriculture then
                Agriculture.harvest(task.data.cropId)
            end
        end
        awardTaskXp(id, 'harvest')
        Jobs.completeTask(task.id)
    end
end

local function executeForage(dt, id, col, task)
    local skillLevel = effectiveSkill(id, 'cooking')
    local speed = (1 + (skillLevel - 1) * 0.1) * getWorkSpeedMods(id)
    task.progress = task.progress + dt * speed
    if task.progress >= task.def.duration then
        local Foraging = getOptionalModule('src.colonist.foraging')
        if Foraging then
            local itemId, amount = Foraging.attemptForage(id, task.x, task.y, task.depth or 0)
            if itemId and amount then
                -- Herbalist mastery: double forage yield
                local FSkills = getOptionalModule('src.colonist.skills')
                if FSkills and FSkills.hasMastery(id, 'herbalist') then
                    local eff = FSkills.getMasteryEffect(id, 'herbalist')
                    if eff and eff.forageMult then
                        amount = math.floor(amount * eff.forageMult + 0.5)
                    end
                end
                -- Spawn foraged items on the ground (hauled to stockpiles)
                local FItemsMod = getOptionalModule('src.world.items')
                if FItemsMod then
                    local cat = 'raw'
                    local Prod3 = getOptionalModule('src.building.production')
                    if Prod3 and Prod3.FOOD_QUALITY and Prod3.FOOD_QUALITY[itemId] then
                        cat = 'food'  -- edible raw food gets 'food' category for stockpile sorting
                    end
                    FItemsMod.spawn(task.x, task.y, itemId, amount, cat)
                else
                    -- Fallback: spawn at task location if items system unavailable
                    local FORAGE_MAP = {
                        plant_fiber = 'hide', berries = 'food', mushrooms = 'food',
                        medicinal_herb = 'components', raw_meat = 'food',
                    }
                    local resKey = FORAGE_MAP[itemId] or 'food'
                    Items.spawn(task.x, task.y, resKey, amount, nil, task.depth or 0)
                end
            end
        end
        awardTaskXp(id, 'forage')
        Jobs.completeTask(task.id)
    end
end

local function executeOperateGenerator(dt, id, col, task)
    -- Register as generator crew on first tick
    if not task.data._assigned then
        local Power = getOptionalModule('src.sim.power')
        if Power and task.data.generatorId then
            Power.assignWorker(task.data.generatorId, id)
            task.data._assigned = true
        end
    end

    -- Drain rest faster from physical labor
    local needs = ECS.get(id, 'needs')
    if needs then
        needs.rest = math.max(0, needs.rest - 0.06 * dt)
    end

    -- Never completes — continuous task
    task.progress = 0
end

local function executeMachineWork(dt, id, col, task)
    local machineId = task.data and task.data.machineEntityId
    if not machineId or not ECS.isAlive(machineId) then
        Jobs.completeTask(task.id)
        return
    end

    local machine = ECS.get(machineId, 'machine')
    if not machine then
        Jobs.completeTask(task.id)
        return
    end

    -- Set assignee on first tick
    if not task.data._assigned then
        machine.assignee = id
        task.data._assigned = true
    end

    -- Drain rest from labor
    local needs = ECS.get(id, 'needs')
    if needs then
        needs.rest = math.max(0, needs.rest - 0.04 * dt)
    end

    -- Continuous task — never completes
    task.progress = 0
end

local function executeRepair(dt, id, col, task)
    local skillLevel = effectiveSkill(id, 'building')
    local speed = (1 + (skillLevel - 1) * 0.1) * getWorkSpeedMods(id)
    task.progress = task.progress + dt * speed
    if task.progress >= (task.def.duration or 5.0) then
        awardTaskXp(id, task.type)
        -- Apply the actual repair effect
        if task.type == 'repair' and task.data and task.data.entityId then
            local Power = getOptionalModule('src.sim.power')
            if Power then Power.repairGenerator(task.data.entityId) end
        elseif task.type == 'repair_building' and task.data and task.data.entityId then
            local Deterioration = getOptionalModule('src.sim.deterioration')
            if Deterioration then Deterioration.applyRepair(task.data.entityId) end
        end
        Jobs.completeTask(task.id)
    end
end

local function executeExtinguish(dt, id, col, task)
    local speed = getWorkSpeedMods(id)
    -- Trait fireMod: pyromaniac extinguishes 50% slower (drawn to flames)
    if col.traits then
        for _, t in ipairs(col.traits) do
            if t.fireMod then speed = speed * math.max(0.3, 1 - t.fireMod) end
        end
    end
    task.progress = task.progress + dt * speed
    if task.progress >= (task.def.duration or 3.0) then
        local FireMod = getOptionalModule('src.sim.fire')
        if FireMod then FireMod.extinguish(task.x, task.y) end
        Jobs.completeTask(task.id)
    end
end

local function executeTerraform(dt, id, col, task)
    local Terraform = getOptionalModule('src.world.terraform')
    if not Terraform then Jobs.cancelTask(task.id); return end
    local opId = task.data and task.data.opId
    local op = opId and Terraform.OPS[opId]
    if not op then
        Jobs.cancelTask(task.id)
        return
    end

    local skillLevel = op.skill and effectiveSkill(id, op.skill) or 1
    local speed = (1 + (skillLevel - 1) * 0.12) * getWorkSpeedMods(id)
    local duration = op.duration or 3.0

    task.progress = task.progress + dt * speed
    if task.progress >= duration then
        if Terraform.execute(opId, task.x, task.y, task.depth) then
            if op.skill then awardTaskXp(id, 'terraform') end
        end
        Jobs.completeTask(task.id)
    end
end

local function executeClean(dt, id, col, task)
    local speed = getWorkSpeedMods(id)
    -- Trait cleanMod: neat cleans 20% faster
    if col.traits then
        for _, t in ipairs(col.traits) do
            if t.cleanMod then speed = speed * (1 + t.cleanMod) end
        end
    end
    task.progress = task.progress + dt * speed
    if task.progress >= (task.def.duration or 1.5) then
        local FilthMod = getOptionalModule('src.sim.filth')
        if FilthMod then FilthMod.cleanTile(task.x, task.y) end
        Jobs.completeTask(task.id)
    end
    local needs = ECS.get(id, 'needs')
    if needs then needs.rest = math.max(0, needs.rest - 0.02 * dt) end
end

local function executeRevive(dt, id, col, task)
    local corpseId = task.data and task.data.corpseEntityId
    if not corpseId or not ECS.isAlive(corpseId) then
        Jobs.completeTask(task.id)
        return
    end

    -- Check serum availability
    if (GameState.resources.revivify_serum or 0) < 1 then
        Jobs.cancelTask(task.id)
        return
    end

    local skillLevel = effectiveSkill(id, 'medical')
    local speed = (1 + (skillLevel - 1) * 0.15) * getWorkSpeedMods(id)

    task.progress = task.progress + dt * speed
    if task.progress >= task.def.duration then
        -- Consume serum
        if not GameState.spendResource('revivify_serum', 1) then
            Jobs.cancelTask(task.id)
            return
        end

        -- Read identity from corpse item component
        local corpseItem = ECS.get(corpseId, 'item')
        local corpsePos = ECS.get(corpseId, 'pos')
        if not corpseItem or not corpsePos then
            Jobs.completeTask(task.id)
            return
        end

        local restoredName      = corpseItem._colonistName or 'Unknown'
        local restoredBackstory = corpseItem._colonistBackstory or ''
        local restoredTraits    = corpseItem._colonistTraits or {}
        local restoredSkills    = corpseItem._colonistSkills or {}
        local restoredAge       = corpseItem._colonistAge or 30

        -- Destroy corpse
        ECS.destroy(corpseId)
        GameState.resources.corpse_human = math.max(0, (GameState.resources.corpse_human or 0) - 1)

        -- Spawn revived colonist at corpse location
        local ColMod = require('src.colonist.colonist')
        local newId = ColMod.spawn(corpsePos.x, corpsePos.y, corpsePos.depth or 0)
        if not newId then
            Jobs.completeTask(task.id)
            return
        end

        -- Restore identity
        local newCol = ECS.get(newId, 'colonist')
        if newCol then
            newCol.name      = restoredName
            newCol.backstory = restoredBackstory
            newCol.skills    = restoredSkills
            newCol.age       = restoredAge
            -- Merge original traits with revival penalty traits
            local Adlib = getOptionalModule('src.util.adlib')
            local penaltyTraits = {}
            if Adlib and Adlib.getRevivalTraits then
                penaltyTraits = Adlib.getRevivalTraits(skillLevel)
            end
            local mergedTraits = {}
            for _, t in ipairs(restoredTraits) do mergedTraits[#mergedTraits + 1] = t end
            for _, t in ipairs(penaltyTraits) do mergedTraits[#mergedTraits + 1] = t end
            newCol.traits = mergedTraits
            -- Reduced starting health and needs
            newCol.health = math.min(40 + skillLevel * 3, 70)
            newCol.sanity = 30
        end
        local newNeeds = ECS.get(newId, 'needs')
        if newNeeds then
            newNeeds.warmth = 40
            newNeeds.food   = 30
            newNeeds.water  = 30
            newNeeds.rest   = 20
            newNeeds.morale = 15
        end

        awardTaskXp(id, 'revive')
        Jobs.completeTask(task.id)
    end
end

local function executeDeconstruct(dt, id, col, task)
    local skillLevel = effectiveSkill(id, 'building')
    local speed = (1 + (skillLevel - 1) * 0.1) * getWorkSpeedMods(id)
    task.progress = task.progress + dt * speed
    if task.progress >= task.def.duration then
        awardTaskXp(id, 'build')
        local Building = getOptionalModule('src.building.building')
        if Building and task.data.entityId then
            local bpos = ECS.get(task.data.entityId, 'pos')
            if bpos then
                Building.remove(bpos.x, bpos.y, bpos.depth or 0)
            end
        end
        Jobs.completeTask(task.id)
    end
end

local function executeFish(dt, id, col, task)
    local skillLevel = effectiveSkill(id, 'hunting')
    local speed = (1 + (skillLevel - 1) * 0.1) * getWorkSpeedMods(id)
    task.progress = task.progress + dt * speed
    if task.progress >= task.def.duration then
        local WF = getOptionalModule('src.world.water_features')
        if WF then
            local itemId, amount = WF.attemptFish(id, task.x, task.y)
            if itemId and amount and amount > 0 then
                local FItemsMod = getOptionalModule('src.world.items')
                if FItemsMod then
                    FItemsMod.spawn(task.x, task.y, itemId, amount, 'food', task.depth or 0)
                end
            end
        end
        awardTaskXp(id, 'hunting')
        Jobs.completeTask(task.id)
    end
end

local function executeTame(dt, id, col, task)
    local Taming = getOptionalModule('src.creatures.taming')
    if not Taming then
        Jobs.completeTask(task.id)
        return
    end
    local creatureId = task.data and task.data.creatureId
    if not creatureId or not ECS.isAlive(creatureId) then
        Jobs.completeTask(task.id)
        return
    end
    -- Check creature is still tameable
    local canTame, err = Taming.canTame(creatureId)
    if not canTame then
        Jobs.cancelTask(task.id)
        return
    end
    -- Progress the taming attempt (hunting skill speeds it up)
    local skillLevel = effectiveSkill(id, 'hunting')
    local speed = (1 + (skillLevel - 1) * 0.1) * getWorkSpeedMods(id)
    task.progress = task.progress + dt * speed
    if task.progress >= task.def.duration then
        Taming.attemptTame(creatureId, id)
        awardTaskXp(id, 'hunting')
        Jobs.completeTask(task.id)
    end
end

local EXECUTORS = {
    mine    = executeMineOrLair,
    build   = executeBuild,
    haul    = executeHaul,
    hunt    = executeHunt,
    medical = executeMedical,
    harvest = executeHarvest,
    forage  = executeForage,
    fish    = executeFish,
    tame    = executeTame,
    operate_generator = executeOperateGenerator,
    cook     = executeMachineWork,
    operate  = executeMachineWork,
    research = executeMachineWork,
    repair          = executeRepair,
    repair_building = executeRepair,
    extinguish      = executeExtinguish,
    terraform       = executeTerraform,
    clean           = executeClean,
    revive          = executeRevive,
    deconstruct     = executeDeconstruct,
}

---------------------------------------------------------------------------
-- Main work AI system — runs each sim tick
---------------------------------------------------------------------------

local function workAISystem(dt, id, comps)
    local col  = comps.colonist
    local pos  = comps.pos
    local path = comps.path
    local sched = comps.schedule
    local prio = comps.workPriority

    col._idleReason = nil  -- clear each tick

    if col.state == 'dead' or col.state == 'mental_break' then return end

    -- Phase 5: yield to combat AI when fighting or fleeing
    if col.state == 'fighting' or col.state == 'fleeing' then return end

    -- Suffocation flee: abandon task and path to breathable tile
    if col._suffocating and col._suffocating >= 2 then
        if col.state ~= 'fleeing_o2' then
            -- Cancel current task
            if col.task then
                Jobs.cancelTask(col.task.taskId)
                col.task = nil
            end
            col.state = 'fleeing_o2'
            path.nodes = nil
        end
        -- Search is throttled: it used to run an unbounded A* per candidate
        -- tile EVERY tick (up to ~700 pathfinds per colonist per tick) when no
        -- breathable tile was reachable, which locks the whole game up.
        col._o2SearchCd = (col._o2SearchCd or 0) - dt
        if not path.nodes and col._o2SearchCd <= 0 then
            col._o2SearchCd = 1.0
            -- Find nearest walkable tile with O2 >= 60
            local Atmo = getOptionalModule('src.sim.atmosphere')
            if Atmo then
                local posDepth = pos.depth or 0
                local bestRoute = nil
                local bestO2, bestX, bestY = Atmo.getTileO2(pos.x, pos.y, posDepth), nil, nil
                local budget = 12  -- max A* attempts per search
                -- Search expanding rings up to radius 15; the first reachable
                -- breathable tile in the closest ring wins.
                for r = 1, 15 do
                    for dx = -r, r do
                        for dy = -r, r do
                            if math.abs(dx) == r or math.abs(dy) == r then
                                local tx, ty = pos.x + dx, pos.y + dy
                                if World.inBounds(tx, ty) and World.isWalkable(tx, ty, posDepth) then
                                    local tileO2 = Atmo.getTileO2(tx, ty, posDepth)
                                    if tileO2 >= 60 and budget > 0 then
                                        budget = budget - 1
                                        local route = Pathfind.find(pos.x, pos.y, tx, ty, World, id, posDepth, posDepth)
                                        if route then
                                            bestRoute = route
                                            break
                                        end
                                    elseif tileO2 > bestO2 then
                                        bestO2, bestX, bestY = tileO2, tx, ty
                                    end
                                end
                            end
                        end
                        if bestRoute then break end
                    end
                    if bestRoute then break end
                end
                -- Fallback: no fully breathable tile is reachable, so head for
                -- the best air found. Standing still in a fouled room is fatal.
                if not bestRoute and bestX then
                    bestRoute = Pathfind.find(pos.x, pos.y, bestX, bestY, World, id, posDepth, posDepth)
                end
                if bestRoute and #bestRoute > 0 then
                    path.nodes = bestRoute
                    path.index = 1
                    path.moveTimer = 0
                end
            end
        end
        return
    end
    if col.state == 'fleeing_o2' then
        col.state = 'idle'
        col._o2SearchCd = nil
    end

    -- Draft mode: player has direct control, skip all AI
    if col.drafted then
        col._idleReason = 'drafted'
        if col.task then
            Jobs.unclaimTask(col.task.taskId)
            col.task = nil
        end
        col.state = 'drafted'
        return
    end

    -- Colony-wide revolt: colonists refuse to work for 1 day
    local Hope = getOptionalModule('src.colony.hope')
    if Hope and Hope.isRevoltActive() then
        col._idleReason = 'revolt'
        if col.state ~= 'idle' and col.state ~= 'wandering' then
            col.state = 'idle'
            if col.task then Jobs.unclaimTask(col.task.taskId) end
            col.task = nil
            path.nodes = nil
        end
        return
    end

    local posDepth = pos.depth or 0
    if Zones.hasRestrictedZones(posDepth) and not Zones.isTileAllowed(pos.x, pos.y, posDepth) then
        if col.task then
            Jobs.unclaimTask(col.task.taskId)
            col.task = nil
        end
        col.state = 'returning_to_allowed'
        col._idleReason = 'allowed_area'

        if not path.nodes then
            local target = Zones.findNearestRestrictedTile(pos.x, pos.y, posDepth)
            if target then
                local route = Pathfind.find(pos.x, pos.y, target.x, target.y, World, id, posDepth, target.depth or posDepth)
                if route then
                    path.nodes = route
                    path.index = 1
                    path.moveTimer = 0
                end
            end
        end
        return
    elseif col.state == 'returning_to_allowed' and not path.nodes then
        col.state = 'idle'
    end

    ---------------------------------------------------------------------------
    -- Cold emergency: freezing colonists drop work and seek warmth.
    -- Triggers on a per-colonist warmth threshold (35-45) OR on time-to-freeze
    -- at the current tile, whichever fires first; releases at warmth 70
    -- (hysteresis, so colonists visibly RESUME WORK instead of flapping).
    -- Fallbacks that guarantee agency (colonists never stand still forever):
    --   * hunger/thirst below 35 takes precedence over warming up
    --   * three-pass target search: nearest warm tile, else warmest reachable
    --     tile, else the colony landing site
    --   * after 120 s without reaching release warmth, give up and resume
    --     work anyway (10 s re-trigger backoff)
    ---------------------------------------------------------------------------
    local coldNeeds = ECS.get(id, 'needs')
    -- Eating/drinking outranks warming up. Without this a colonist parked at a
    -- bonfire starved to death standing next to the food pile.
    --
    -- But ONLY while there is something to eat. When the last meal is gone the
    -- eat block's search comes up empty and sets _noFoodUntil; if hunger still
    -- outranked warmth at that point, the cold emergency stayed switched off and
    -- the colonist stood on one tile waiting for food that was never coming.
    -- That is how an acceptance run lost a colonist at FULL HP six tiles from a
    -- lit campfire: it froze holding out for a meal. Hunger at zero food costs
    -- 0.5 HP/s; severe hypothermia costs 1.0 HP/s. The cold is the more urgent
    -- death, so it takes priority whenever food is unobtainable.
    local foodUnavailable = col._noFoodUntil ~= nil
        and (GameState.simTick or 0) < col._noFoodUntil
    local criticallyHungry = coldNeeds and not foodUnavailable
        and (coldNeeds.food < URGENT_FOOD
            or (coldNeeds.water or 80) < URGENT_WATER)
    local coldHereTemp = World.getTemp(pos.x, pos.y, pos.depth or 0)
    local wantsWarmth, coldTrigger = false, coldTriggerWarmth(id, col)
    if coldNeeds then
        wantsWarmth, coldTrigger =
            needsWarmth(id, col, coldNeeds.warmth, coldHereTemp)
    end
    -- Release must sit above whatever triggered, or the two fight each tick.
    local coldRelease = math.max(COLD_RELEASE, coldTrigger + 15)

    if ctraceOn() and coldNeeds then
        -- Heartbeat every 10 s once a colonist is meaningfully cold, plus an
        -- immediate line the moment the emergency trips.
        if wantsWarmth and not col._ctWanted then
            col._ctWanted = true
            ctrace('TRIGGER %s(%d) pos=(%d,%d) tile=%.1f warmth=%.1f state=%s task=%s '
                .. 'distHome=%d trig=%.0f lead=%.0f',
                tostring(col.name), id, pos.x, pos.y, coldHereTemp, coldNeeds.warmth,
                tostring(col.state), col.task and tostring(col.task.type) or 'none',
                math.max(math.abs(pos.x - (GameState.startX or 0)),
                         math.abs(pos.y - (GameState.startY or 0))),
                coldTrigger, col._coldLead or 0)
        elseif not wantsWarmth then
            col._ctWanted = false
        end
        col._ctBeat = (col._ctBeat or 0) - dt
        if coldNeeds.warmth < 55 and col._ctBeat <= 0 then
            col._ctBeat = 10.0
            ctrace('beat %s(%d) pos=(%d,%d) tile=%.1f warmth=%.1f hp=%.0f state=%s '
                .. 'task=%s path=%s seek=%.0f wood=%.0f amb=%.1f',
                tostring(col.name), id, pos.x, pos.y, coldHereTemp, coldNeeds.warmth,
                col.health or -1, tostring(col.state),
                col.task and tostring(col.task.type) or 'none',
                path.nodes and (#path.nodes - (path.index or 1)) or 'nil',
                col._warmSeekTime or -1,
                (GameState.resources and GameState.resources.wood) or -1,
                GameState.getEffectiveTemp())
        end
    end

    if col.state == 'seeking_warmth' then
        col._warmSeekTime = (col._warmSeekTime or 0) + dt
        if not coldNeeds or coldNeeds.warmth >= coldRelease or criticallyHungry then
            -- Recovered (or eating matters more) — resume normal AI
            col.state = 'idle'
            col._warmSeekTime = nil
        elseif col._warmSeekTime > 120 then
            -- Not getting warm (fire went out / spot contested): resume
            -- work rather than freeze in place, retry soon
            col.state = 'idle'
            col._warmSeekTime = nil
            col._warmSearchCd = 10.0
        elseif path.nodes then
            return  -- still walking toward warmth
        else
            local hereTemp = World.getTemp(pos.x, pos.y, pos.depth or 0)
            if hereTemp > 10 then
                return  -- warm enough here: stand and recover
            end
            col.state = 'idle'  -- warmth lost (fire out?) — re-search below
        end
    end

    if wantsWarmth and not criticallyHungry and col.state ~= 'seeking_warmth' then
        col._warmSearchCd = (col._warmSearchCd or 0) - dt
        if col._warmSearchCd <= 0 then
            local wsDepth = pos.depth or 0
            local hereTemp = coldHereTemp
            if hereTemp > 10 then
                -- Current tile is already warm: stay put until recovered
                if col.task then Jobs.unclaimTask(col.task.taskId) end
                col.task = nil
                path.nodes = nil
                col.state = 'seeking_warmth'
                return
            end

            local function goWarm(route)
                if col.task then Jobs.unclaimTask(col.task.taskId) end
                col.task = nil
                col.state = 'seeking_warmth'
                col._warmSeekTime = 0
                path.nodes = route
                path.index = 1
                path.moveTimer = 0
            end

            -- One outward scan, four tiers of target, in order of preference.
            -- The scan is walked once and every tier it can serve is filled
            -- from it, so the cost is a single ring sweep plus a bounded
            -- number of A* attempts.
            local warmRoute = nil
            local recover = {}   -- tiles above WARM_RECOVER_TEMP, nearest first
            local warmest = {}   -- progressively less-cold tiles, coldest first
            local bestTemp = hereTemp
            -- Warm tiles cluster: a fire produces dozens of them, and if the
            -- colonist is walled off from all of them every A* attempt floods
            -- the whole node budget. Cap the attempts, then let the cheaper
            -- tiers take over (the scan below still records their positions).
            local warmTries = WARM_PATH_TRIES
            for r = 1, 40 do
                for dx = -r, r do
                    for dy = -r, r do
                        if math.abs(dx) == r or math.abs(dy) == r then
                            local wx, wy = pos.x + dx, pos.y + dy
                            if World.inBounds(wx, wy)
                                and World.isWalkable(wx, wy, wsDepth)
                                and Zones.isTileAllowed(wx, wy, wsDepth) then
                                local t = World.getTemp(wx, wy, wsDepth)
                                if t > WARM_TILE_TEMP then
                                    if warmTries > 0 then
                                        warmTries = warmTries - 1
                                        warmRoute = Pathfind.find(pos.x, pos.y, wx, wy,
                                            World, id, wsDepth, wsDepth, WARM_PATH_OPTS)
                                        if warmRoute then break end
                                    elseif #recover < WARM_PATH_TRIES * 2 then
                                        -- Out of tier-1 attempts: keep it as a
                                        -- tier-2 candidate rather than lose it.
                                        recover[#recover + 1] = { wx, wy, t }
                                    end
                                elseif t > WARM_RECOVER_TEMP then
                                    if #recover < WARM_PATH_TRIES * 2 then
                                        recover[#recover + 1] = { wx, wy, t }
                                    end
                                elseif t > bestTemp then
                                    bestTemp = t
                                    warmest[#warmest + 1] = { wx, wy, t }
                                    if #warmest > WARM_PATH_TRIES * 2 then
                                        table.remove(warmest, 1)
                                    end
                                end
                            end
                        end
                    end
                    if warmRoute then break end
                end
                if warmRoute then break end
            end

            -- Tier 1: nearest reachable genuinely warm tile.
            if warmRoute then
                ctrace('tier1 OK %s(%d) route=%d', tostring(col.name), id, #warmRoute)
                goWarm(warmRoute)
                return
            end

            --- Try a list of candidate tiles, nearest first, and take the first
            --- one we can actually reach. Bounded so a stranded colonist cannot
            --- spend the frame pathfinding.
            local function tryCandidates(list, tier, reverse)
                local tries = WARM_PATH_TRIES
                local first, last, step = 1, #list, 1
                if reverse then first, last, step = #list, 1, -1 end
                for i = first, last, step do
                    if tries <= 0 then break end
                    tries = tries - 1
                    local c = list[i]
                    local route = Pathfind.find(pos.x, pos.y, c[1], c[2],
                        World, id, wsDepth, wsDepth, WARM_PATH_OPTS)
                    if route and #route > 0 then
                        ctrace('%s OK %s(%d) -> (%d,%d) %.1fC route=%d',
                            tier, tostring(col.name), id, c[1], c[2], c[3], #route)
                        goWarm(route)
                        return true
                    end
                end
                return false
            end

            -- Tier 2: any tile that actually restores warmth. colonist.lua
            -- gains warmth above 10C, so a 12C tile in a campfire's outer ring
            -- is survival even though it is not comfortable — and in a deep
            -- cold snap that ring is the only thing left.
            if tryCandidates(recover, 'tier2') then return end
            ctrace('tier2 FAIL %s(%d) here=%.1f cands=%d lastFail=%s',
                tostring(col.name), id, hereTemp, #recover,
                tostring(Pathfind.lastFail))

            -- Tier 3: the landing site. It is the one place the colony is
            -- guaranteed to have a fire, so it is worth a long walk. This used
            -- to be gated behind warmth < 30, which meant it only unlocked
            -- after hypothermia had already started draining HP and slowed the
            -- colonist below the speed needed to finish the walk. A colonist
            -- that cannot see warmth from where it stands should start walking
            -- home immediately, not once it is dying.
            if GameState.startX and GameState.startY then
                local home = {}
                for hr = 0, 3 do
                    for hdx = -hr, hr do
                        for hdy = -hr, hr do
                            if hr == 0 or math.abs(hdx) == hr or math.abs(hdy) == hr then
                                local hx, hy = GameState.startX + hdx, GameState.startY + hdy
                                if World.inBounds(hx, hy)
                                    and World.isWalkable(hx, hy, wsDepth) then
                                    home[#home + 1] = { hx, hy,
                                        World.getTemp(hx, hy, wsDepth) }
                                end
                            end
                        end
                    end
                end
                if tryCandidates(home, 'tier3') then return end
                ctrace('tier3 FAIL %s(%d) cands=%d lastFail=%s',
                    tostring(col.name), id, #home, tostring(Pathfind.lastFail))
            end

            -- Tier 4: no warmth anywhere reachable (no fire built yet, or a
            -- brutal cold snap). Head for the least-cold tile found — standing
            -- in the shallowest cold slows the spiral and keeps the colonist
            -- visibly doing something. Walked warmest-first.
            local viable = {}
            for _, c in ipairs(warmest) do
                if c[3] >= hereTemp + WARM_FALLBACK_GAIN then viable[#viable + 1] = c end
            end
            if tryCandidates(viable, 'tier4', true) then return end

            ctrace('ALL TIERS FAIL %s(%d) warmth=%.1f here=%.1f best=%.1f',
                tostring(col.name), id, coldNeeds.warmth, hereTemp, bestTemp)
            -- Nothing reachable is warmer — back off before searching again
            col._warmSearchCd = 5.0
        end
    end

    -- Get current schedule block
    local block = Schedule.getCurrentBlock(sched)

    -- Martial law policy: convert free time to work
    local Policies = getOptionalModule('src.colony.policies')
    if Policies and Policies.isNoFreeTime() and block == 'free' then
        block = 'work'
    end

    -- Player-forced tasks override the schedule. Previously the sleep/eat/
    -- free blocks unclaimed them within a tick, silently dropping the
    -- player's order. Only critical needs (starvation, freezing,
    -- suffocation) interrupt a forced task now.
    if col.task then
        local curTask = Jobs.getTask(col.task.taskId)
        if curTask and curTask.data and curTask.data.forcedFor == id then
            block = 'work'
        end
    end

    ---------------------------------------------------------------------------
    -- SLEEP block
    ---------------------------------------------------------------------------
    -- Never bed down while critically cold on a freezing tile: sleeping in
    -- place outdoors was a death sentence. The cold-emergency block above
    -- keeps retrying to reach warmth instead.
    --
    -- The warmth < 40 half of that rule was not enough on its own. A colonist
    -- caught by the sleep block 25 tiles from base has no bed to walk to, so it
    -- lay down on open ground at -50C at warmth 55 and slept off the first 15
    -- points of the drain before any guard engaged. Lying down WITHOUT A BED on
    -- a tile that is taking warmth away is now refused outright, whatever the
    -- current warmth: the colonist stays on its feet and the work/warmth AI
    -- keeps it moving. A bed in a cold room is still allowed (that is a room to
    -- heat, not an exposure death), and rest lost to a cold night is recovered
    -- the next time the colonist sleeps somewhere survivable.
    local sleepTileTemp = World.getTemp(pos.x, pos.y, pos.depth or 0)
    local hasOwnBed = col._bedId ~= nil and ECS.isAlive(col._bedId)
    -- Already asleep on bare ground (no bed) — get up if the ground turns lethal.
    local sleepingRough = col.state == 'sleeping' and not hasOwnBed
    local tooColdToSleep = block == 'sleep'
        and sleepTileTemp <= 10
        and ((coldNeeds and coldNeeds.warmth < 40) or sleepingRough)
    if block == 'sleep' and not tooColdToSleep then
        if col.state ~= 'sleeping' and col.state ~= 'going_to_bed' then
            -- Bedding down where we stand is only survivable on a tile that is
            -- not draining warmth. Work out where we are sleeping BEFORE
            -- dropping the current task: a colonist that ends up staying awake
            -- must keep its task, or it unclaims and re-claims every tick and
            -- never finishes anything.
            local canSleepRough = sleepTileTemp > 10
            local bedId, bedPos = Beds.findForColonist(id)
            local route = nil
            if bedId and bedPos then
                route = Pathfind.find(pos.x, pos.y, bedPos.x, bedPos.y, World, id,
                    pos.depth or 0, bedPos.depth or 0, getRestrictedPathOpts(pos))
            end
            if route or canSleepRough then
                if col.task then Jobs.unclaimTask(col.task.taskId) end
                col.task = nil
            end
            if route then
                Beds.assign(bedId, id)
                col.state = 'going_to_bed'
                path.nodes = route
                path.index = 1
                path.moveTimer = 0
            elseif canSleepRough then
                col.state = 'sleeping'
                path.nodes = nil
            end
        end
        if col.state ~= 'sleeping' and col.state ~= 'going_to_bed' then
            -- Awake on freezing ground with nowhere to lie down: skip the sleep
            -- block entirely and let the work/warmth AI below keep us moving.
            block = 'work'
        end
    end
    if block == 'sleep' and not tooColdToSleep then
        if col.state == 'going_to_bed' and not path.nodes then
            col.state = 'sleeping'
            if col._bedId and ECS.isAlive(col._bedId) then
                local bed = ECS.get(col._bedId, 'bed')
                if bed then bed.occupied = true end
            end
        end
        -- Rest recovery is handled solely by needsDecaySystem in colonist.lua
        return
    end

    -- Wake up if was sleeping
    if col.state == 'sleeping' or col.state == 'going_to_bed' then
        if col._bedId and ECS.isAlive(col._bedId) then
            local bed = ECS.get(col._bedId, 'bed')
            if bed then bed.occupied = false end
        end
        col._bedId = nil
        col.state = 'idle'
    end

    ---------------------------------------------------------------------------
    -- EAT block — colonists pathfind to food items, pick them up, and eat
    ---------------------------------------------------------------------------

    -- Critical hunger: interrupt any schedule block if starving
    local criticalHunger = false
    do
        local cNeeds = ECS.get(id, 'needs')
        if cNeeds and (cNeeds.food < URGENT_FOOD
            or (cNeeds.water or 80) < URGENT_WATER) then
            criticalHunger = true
        end
    end

    if block == 'eat' or criticalHunger then
        local needs = ECS.get(id, 'needs')
        if not needs then -- fall through
        else
        -- Hysteresis thresholds
        local isEatState = col.state == 'eating' or col.state == 'moving_to_food'
        local fullThreshold = isEatState and 98 or 90
        -- A recent failed food search parks the whole eat branch for a few
        -- seconds. Re-scanning the map for a meal that does not exist, every
        -- tick, is what kept the colonist standing still; falling through to
        -- work sends it hunting and foraging, which is how food gets made.
        local hungry = needs.food < fullThreshold and not foodUnavailable
        local thirsty = (needs.water or 80) < fullThreshold

        -- Water: still consumed from colony stores (piped water system)
        if thirsty and (GameState.resources.water or 0) > 0 then
            needs.water = math.min(100, (needs.water or 80) + 0.6 * dt)
            GameState.resources.water = GameState.resources.water - 0.012 * dt
        end

        if hungry then
            -- State: moving_to_food — pathfinding to a food source
            if col.state == 'moving_to_food' then
                if not path.nodes then
                    -- Path finished — check if we arrived near the food
                    local et = col._eatTarget
                    if et then
                        local dx = math.abs(pos.x - et.x)
                        local dy = math.abs(pos.y - et.y)
                        local sameDepth = (pos.depth or 0) == (et.depth or 0)
                        if dx <= 1 and dy <= 1 and sameDepth then
                            -- Arrived — consume the food item
                            local consumed = false
                            local itemId = et.itemId
                            local Prod = getOptionalModule('src.building.production')
                            local fqTable = (Prod and Prod.FOOD_QUALITY) or {}

                            -- A meal consumes ONE unit from the stack.
                            -- (Previously the whole stack was deleted for a
                            -- single unit of nutrition, so the starting drop
                            -- pod's 38 units of food fed the colony 3 meals
                            -- and everyone starved on day 2-3.)
                            if et.source == 'zone' then
                                local item = Zones.getItemAt(et.zoneId, et.x, et.y, et.depth)
                                if item and fqTable[item.itemId] then
                                    itemId = item.itemId
                                    item.amount = (item.amount or 1) - 1
                                    if item.amount <= 0 then
                                        Zones.takeItem(et.zoneId, et.x, et.y, et.depth)
                                    end
                                    consumed = true
                                end
                            elseif et.source == 'ground' then
                                if et.entityId and ECS.isAlive(et.entityId) then
                                    local gItem = ECS.get(et.entityId, 'item')
                                    if gItem and fqTable[gItem.itemId] then
                                        itemId = gItem.itemId
                                        gItem.amount = (gItem.amount or 1) - 1
                                        if gItem.amount <= 0 then
                                            ECS.destroy(et.entityId)
                                        end
                                        consumed = true
                                    end
                                end
                            end

                            if consumed then
                                local fq = fqTable[itemId]
                                needs.food = math.min(100, needs.food + (fq and fq.nutrition or 20))
                                if fq and fq.morale and fq.morale ~= 0 then
                                    local foodMorale = fq.morale
                                    if col.traits then
                                        for _, t in ipairs(col.traits) do
                                            -- Gourmand: double morale penalty from raw food
                                            if t.id == 'gourmand' and fq.quality == 'raw' then
                                                foodMorale = foodMorale * 2
                                            end
                                            -- Cannibal: no penalty from human meat
                                            if t.id == 'cannibal' and itemId == 'human_meat' then
                                                foodMorale = math.abs(foodMorale)
                                            end
                                            -- Ascetic: ignores food morale (no bonus or penalty)
                                            if t.id == 'ascetic' then
                                                foodMorale = 0
                                            end
                                        end
                                    end
                                    if foodMorale ~= 0 then
                                        needs.morale = math.max(0, math.min(100, needs.morale + foodMorale))
                                    end
                                end
                                -- Chef mastery: +15 morale on meal
                                local CSkills = getOptionalModule('src.colonist.skills')
                                if CSkills and CSkills.hasMastery(id, 'chef') then
                                    local eff = CSkills.getMasteryEffect(id, 'chef')
                                    if eff and eff.mealMorale then
                                        needs.morale = math.min(100, needs.morale + eff.mealMorale)
                                    end
                                end
                                col.state = 'eating'
                                col._eatTimer = 0
                                col._eatTarget = nil
                                -- Meal trash
                                local FilthMod = getOptionalModule('src.sim.filth')
                                if FilthMod and FilthMod.onMealTrash then FilthMod.onMealTrash(pos.x, pos.y) end
                            else
                                -- Food was taken by someone else — search again next tick
                                col._eatTarget = nil
                                col.state = 'idle'
                            end
                        else
                            -- Didn't arrive close enough — clear and retry
                            col._eatTarget = nil
                            col.state = 'idle'
                        end
                    end
                end
                return
            end

            -- State: eating — brief pause while consuming
            if col.state == 'eating' then
                col._eatTimer = (col._eatTimer or 0) + dt
                if col._eatTimer >= 2.0 then
                    col._eatTimer = nil
                    -- Still hungry? Search for more food
                    if needs.food < 90 then
                        col.state = 'idle'  -- will re-enter food search below
                    else
                        col.state = 'idle'
                        if not criticalHunger then return end  -- done eating, fall through
                    end
                end
                return
            end

            -- Not currently eating — search for food
            local ItemsMod = getOptionalModule('src.world.items')
            local Prod2 = getOptionalModule('src.building.production')
            if ItemsMod and Prod2 and ItemsMod.findNearestFood then
                local food = ItemsMod.findNearestFood(
                    pos.x,
                    pos.y,
                    pos.depth or 0,
                    Prod2.FOOD_QUALITY,
                    function(x, y, depth)
                        return Zones.isTileAllowed(x, y, depth)
                    end
                )
                if food then
                    col.state = 'moving_to_food'
                    if col.task then Jobs.unclaimTask(col.task.taskId) end
                    col.task = nil
                    col._eatTarget = food
                    local pd = pos.depth or 0
                    local fd = food.depth or 0
                    local tx, ty = food.x, food.y
                    -- If food tile isn't walkable, try adjacent
                    if not World.isWalkable(tx, ty, fd) then
                        local dirs = { {-1,0},{1,0},{0,-1},{0,1} }
                        for _, d in ipairs(dirs) do
                            local nx, ny = tx + d[1], ty + d[2]
                            if World.inBounds(nx, ny) and World.isWalkable(nx, ny, fd) then
                                tx, ty = nx, ny
                                break
                            end
                        end
                    end
                    local route = Pathfind.find(pos.x, pos.y, tx, ty, World, id, pd, fd, getRestrictedPathOpts(pos))
                    if route and #route > 0 then
                        col._noFoodUntil = nil
                        path.nodes = route
                        path.index = 1
                        path.moveTimer = 0
                        return
                    end
                    -- Found food but cannot reach it: treat as no food.
                    col.state = 'idle'
                    col._eatTarget = nil
                end
                -- Nothing edible within reach. Remember that for a few seconds
                -- and FALL THROUGH instead of returning: standing still waiting
                -- for food is how colonists froze at full health beside a fire.
                col._noFoodUntil = (GameState.simTick or 0) + 200  -- 10 s @ 20 Hz
            else
                return
            end
        end

        -- Full — clear eat state if we were eating
        if col.state == 'eating' or col.state == 'moving_to_food' then
            col.state = 'idle'
            col._eatTarget = nil
            col._eatTimer = nil
        end
        end -- needs guard
        -- If not hungry, fall through to work/free
    end

    if col.state == 'eating' or col.state == 'moving_to_food' then
        -- Leftover eating state from previous block — clear it
        col.state = 'idle'
        col._eatTarget = nil
        col._eatTimer = nil
    end

    ---------------------------------------------------------------------------
    -- FREE block — seek recreation buildings, wander, socialize
    ---------------------------------------------------------------------------
    if block == 'free' then
        col._idleReason = 'free_time'
        if col.state ~= 'idle' and col.state ~= 'wandering' and col.state ~= 'recreating' then
            col.state = 'idle'
            if col.task then Jobs.unclaimTask(col.task.taskId) end
            col.task = nil
        end

        lazyLoadWorkMods()
        local needs = ECS.get(id, 'needs')
        local joy = needs and needs.joy or 50

        -- Guard: if rec target building was demolished, clear state
        if col._recTarget then
            local rec = ECS.get(col._recTarget, 'recreation')
            if not rec then
                if _Rec then _Rec.stopUsing(id, col._recTarget) end
                col._recTarget = nil
                if col.state == 'recreating' then col.state = 'idle' end
            end
        end

        -- Seek recreation building when joy is low and not already pathing
        if not path.nodes and col.state ~= 'recreating' and joy < 70 and math.random() < 0.02 then
            if _Rec and _Rec.findNearest then
                local recId, rpos = _Rec.findNearest(id)
                if recId and rpos then
                    local World = require('src.world.tilemap')
                    local wd = pos.depth or 0
                    local tx, ty = rpos.x, rpos.y
                    if math.abs(pos.x - tx) <= 1 and math.abs(pos.y - ty) <= 1 then
                        col.state = 'recreating'
                        col._recTarget = recId
                        _Rec.startUsing(id, recId)
                    else
                        local route = Pathfind.find(pos.x, pos.y, tx, ty, World, id, wd, wd, getRestrictedPathOpts(pos))
                        if route then
                            col.state = 'wandering'
                            col._recTarget = recId
                            path.nodes = route
                            path.index = 1
                            path.moveTimer = 0
                        end
                    end
                end
            end
        end

        -- Check if arrived at rec building target
        if col._recTarget and not path.nodes and col.state ~= 'recreating' then
            local rpos = ECS.get(col._recTarget, 'pos')
            if rpos and math.abs(pos.x - rpos.x) <= 1 and math.abs(pos.y - rpos.y) <= 1 then
                col.state = 'recreating'
                if _Rec then _Rec.startUsing(id, col._recTarget) end
            else
                col._recTarget = nil
                col.state = 'idle'
            end
        end

        -- Random wander (fallback when no rec building or joy is fine)
        if not path.nodes and col.state ~= 'recreating' and math.random() < 0.008 then
            local World = require('src.world.tilemap')
            local dx = pos.x + math.random(-4, 4)
            local dy = pos.y + math.random(-4, 4)
            local wd = pos.depth or 0
            if World.inBounds(dx, dy) and World.isWalkable(dx, dy, wd)
                and Zones.isTileAllowed(dx, dy, wd) and not Occupancy.isOccupiedBy(dx, dy, id, wd) then
                local route = Pathfind.find(pos.x, pos.y, dx, dy, World, id, wd, wd, getRestrictedPathOpts(pos))
                if route then
                    col.state = 'wandering'
                    path.nodes = route
                    path.index = 1
                    path.moveTimer = 0
                end
            end
        end

        -- Morale recovery during free time
        if needs then
            needs.morale = math.min(100, needs.morale + 0.03 * dt)
        end
        return
    end

    ---------------------------------------------------------------------------
    -- WORK block — find and execute tasks
    ---------------------------------------------------------------------------

    -- Already working a task?
    if col.task then
        local task = Jobs.getTask(col.task.taskId)
        if not task or task.complete then
            col.task = nil
            col.state = 'idle'
        elseif not isTaskAllowed(task) then
            Jobs.unclaimTask(col.task.taskId)
            col.task = nil
            col.state = 'idle'
        elseif col.task.arrived then
            -- At the task location — execute
            col.state = 'working'
            -- Face toward work target
            local tdx = task.x - pos.x
            local tdy = task.y - pos.y
            if tdx ~= 0 or tdy ~= 0 then
                col.facing = math.atan2(tdy, tdx)
            end
            local executor = EXECUTORS[task.type] or executeGeneric
            executor(dt, id, col, task)
            return
        else
            -- Still pathing to task — wait for movement system.
            -- An EMPTY node list counts as "no path": Pathfind.find returns {}
            -- when the mover is already standing on the goal, and `{}` is
            -- truthy in Lua, so the colonist sat waiting forever for a
            -- movement that had nothing to do. This is how self-treatment
            -- deadlocked: a wounded colonist claimed its own medical task,
            -- got an empty path to its own tile, and stalled — holding the
            -- claim so no one else could tend it either.
            if not path.nodes or #path.nodes == 0 then
                -- Path failed or arrived
                local dx = math.abs(pos.x - task.x)
                local dy = math.abs(pos.y - task.y)
                local sameDepth = (pos.depth or 0) == (task.depth or 0)
                if dx <= 1 and dy <= 1 and sameDepth then
                    col.task.arrived = true
                else
                    -- Can't reach task — unclaim, and back off from this
                    -- task for 10 s so we don't livelock retrying it
                    task._noPathUntil = task._noPathUntil or {}
                    task._noPathUntil[id] = GameState.simTick + 200  -- 10 s @ 20 Hz
                    Jobs.unclaimTask(task.id)
                    col.task = nil
                    col.state = 'idle'
                end
            end
            return
        end
    end

    -- Find a new task
    local task = Jobs.findBestTask(id)
    if task then
        if Jobs.claimTask(task.id, id) then
            col.task = { taskId = task.id, arrived = false }
            col.state = 'moving_to_task'

            -- Path to task location (adjacent tile if task tile is solid)
            local World = require('src.world.tilemap')
            local tx, ty = task.x, task.y
            local taskDepth = task.depth or 0
            local posDepth = pos.depth or 0

            -- Path to an adjacent tile when the task tile itself cannot be
            -- stood on: either it is solid (mining a rock) or another entity
            -- already occupies it. The occupancy case matters for tasks that
            -- target a PERSON: a medical task is created on the patient's own
            -- tile, and Pathfind refuses an occupied goal, so every doctor
            -- failed to path, backed off, retried, and no wound was ever
            -- treated — colonists bled out or died of infection beside an
            -- idle doctor.
            if not World.isWalkable(tx, ty, taskDepth)
                or Occupancy.isOccupiedBy(tx, ty, id, taskDepth) then
                local dirs = { {-1,0},{1,0},{0,-1},{0,1} }
                local best, bestDist = nil, math.huge
                for _, d in ipairs(dirs) do
                    local nx, ny = tx + d[1], ty + d[2]
                    if World.inBounds(nx, ny) and World.isWalkable(nx, ny, taskDepth)
                        and not Occupancy.isOccupiedBy(nx, ny, id, taskDepth) then
                        local dist = math.abs(nx - pos.x) + math.abs(ny - pos.y)
                        if dist < bestDist then
                            bestDist = dist
                            best = { x = nx, y = ny }
                        end
                    end
                end
                -- Already standing next to the target (or on it): no walk needed
                if math.abs(pos.x - tx) + math.abs(pos.y - ty) <= 1
                    and posDepth == taskDepth then
                    best = nil
                    tx, ty = pos.x, pos.y
                elseif best then
                    tx, ty = best.x, best.y
                end
            end

            local route = Pathfind.find(pos.x, pos.y, tx, ty, World, id, posDepth, taskDepth, getRestrictedPathOpts(pos))
            if route and #route > 0 then
                path.nodes = route
                path.index = 1
                path.moveTimer = 0
            elseif route then
                -- Already standing on the target tile: nothing to walk
                path.nodes = nil
                col.task.arrived = true
            else
                -- Can't path — unclaim, and back off from this task for
                -- 10 s. findBestTask always returns the nearest task, so
                -- without a backoff an unreachable task was re-picked
                -- every tick forever, idling the colonist.
                task._noPathUntil = task._noPathUntil or {}
                task._noPathUntil[id] = GameState.simTick + 200  -- 10 s @ 20 Hz
                Jobs.unclaimTask(task.id)
                col.task = nil
                col.state = 'idle'
                col._idleReason = 'no_path'
            end
        end
        return
    end

    -- No tasks available — idle wander (stay on same depth)
    col._idleReason = 'no_tasks'
    if col.state ~= 'idle' then col.state = 'idle' end
    if not path.nodes and math.random() < 0.005 then
        local World = require('src.world.tilemap')
        local posDepth = pos.depth or 0
        local dx = pos.x + math.random(-5, 5)
        local dy = pos.y + math.random(-5, 5)
        if World.inBounds(dx, dy) and World.isWalkable(dx, dy, posDepth)
            and Zones.isTileAllowed(dx, dy, posDepth)
            and not Occupancy.isOccupiedBy(dx, dy, id, posDepth) then
            local route = Pathfind.find(pos.x, pos.y, dx, dy, World, id, posDepth, posDepth, getRestrictedPathOpts(pos))
            if route then
                path.nodes = route
                path.index = 1
                path.moveTimer = 0
            end
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function WorkAI.registerSystems()
    ECS.addSystem('work_ai', { 'colonist', 'pos', 'path', 'schedule', 'workPriority' }, workAISystem, 28)
end

WorkAI.registerSystems()

return WorkAI
