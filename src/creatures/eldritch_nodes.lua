-- eldritch_nodes.lua — Eldritch livestock growth and resource production
-- Eldritch creatures (flesh_grub, ichor_polyp, chitin_scarab, void_maw, plus
-- spore variants: bile_mold, thorn_polyp, nerve_cluster, rot_bloom) are
-- living animals that can be captured, hatched from eggs, or grown from spores.
-- When tamed and fed, they grow through 5 stages. At stage 3+ they become
-- sessile (stop moving) and function as living resource nodes — still alive,
-- still eating, but too large and rooted to relocate.
-- At stage 5 ("Ancient") they are grotesque, pulsing masses that continuously
-- produce resources into an outputBuf that inserters pull from (Factorio-style).
-- Risk of mutation if not properly contained with an anomaly-sensitive colonist nearby.
--
-- Each creature rolls a procedural resource profile at tame time.
-- Some creatures produce 1 resource; lucky ones produce many.
-- What it's fed, bond level, and care quality influence output variety.

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
local _StorageNet
local function getStorageNet()
    if _StorageNet == nil then
        local ok, mod = pcall(require, 'src.logistics.storage_network')
        _StorageNet = ok and mod or false
    end
    return _StorageNet or nil
end

local EldritchNodes = {}

---------------------------------------------------------------------------
-- Growth stages
-- Stage 1-2: mobile creature, small, no resource output.
-- Stage 3 "Juvenile": sessile, begins producing. Mutation risk starts.
-- Stage 4 "Mature": full production, significant mutation risk.
-- Stage 5 "Ancient": maximum production, highest risk, grotesque size.
---------------------------------------------------------------------------

local STAGES = {
    [1] = { name = 'Larva',     yieldMult = 0.0,  mutationRisk = 0.00, size = 0.3,  speed = 1.0, growthNeeded = 40,  sessile = false },
    [2] = { name = 'Whelp',     yieldMult = 0.0,  mutationRisk = 0.00, size = 0.5,  speed = 0.6, growthNeeded = 100, sessile = false },
    [3] = { name = 'Juvenile',  yieldMult = 0.4,  mutationRisk = 0.02, size = 1.0,  speed = 0.0, growthNeeded = 200, sessile = true },
    [4] = { name = 'Mature',    yieldMult = 1.0,  mutationRisk = 0.04, size = 1.8,  speed = 0.0, growthNeeded = 400, sessile = true },
    [5] = { name = 'Ancient',   yieldMult = 1.5,  mutationRisk = 0.06, size = 3.0,  speed = 0.0, growthNeeded = nil, sessile = true },
}

EldritchNodes.STAGES = STAGES

---------------------------------------------------------------------------
-- Eldritch type definitions
-- Egg types: flesh, ichor, chitin, void
-- Spore types: bile, thorn, nerve, rot
---------------------------------------------------------------------------

local ELDRITCH_TYPES = {
    -- Egg-based
    flesh = {
        name          = 'Flesh',
        desc          = 'A bloated, rooting mass. Snuffles and squeals as it grows.',
        baseYield     = 3,
        yieldInterval = 60,
        feedResource  = 'corpse_creature',
        color         = { 0.6, 0.15, 0.1 },
        egg           = 'flesh_egg',
        species       = 'gore_shoat',
        sizeScale     = 1.0,
    },
    ichor = {
        name          = 'Ichor',
        desc          = 'Leaks viscous fluid that burns like fuel. Constant output.',
        baseYield     = 2,
        yieldInterval = 90,
        feedResource  = 'raw_meat',
        color         = { 0.2, 0.05, 0.3 },
        egg           = 'ichor_egg',
        species       = 'weeping_calf',
        sizeScale     = 1.0,
    },
    chitin = {
        name          = 'Chitin',
        desc          = 'Grows chitin plates over its body as it matures.',
        baseYield     = 2,
        yieldInterval = 80,
        feedResource  = 'corpse_creature',
        color         = { 0.4, 0.35, 0.25 },
        egg           = 'chitin_egg',
        species       = 'husk_pup',
        sizeScale     = 1.0,
    },
    void = {
        name          = 'Land Whale',
        desc          = 'Starts fist-sized. Fills entire rooms when mature. Prized for oil, meat, and hide.',
        baseYield     = 4,
        yieldInterval = 120,
        feedResource  = 'corpse_human',
        color         = { 0.05, 0.0, 0.1 },
        egg           = 'void_egg',
        species       = 'void_minnow',
        sizeScale     = 3.0,
        guaranteedOutputs = { 'fuel', 'raw_meat', 'raw_hide', 'raw_fat', 'eldritch_ichor' },
    },
    serpent = {
        name          = 'Serpent',
        desc          = 'Small worm. Grows large enough to fill rooms when fed.',
        baseYield     = 2,
        yieldInterval = 70,
        feedResource  = 'raw_meat',
        color         = { 0.3, 0.1, 0.15 },
        egg           = 'wyrm_egg',
        species       = 'pit_wyrm',
        sizeScale     = 2.5,
        guaranteedOutputs = { 'raw_fat', 'raw_meat', 'raw_hide', 'caustic_liquid', 'serpent_venom' },
    },
    -- Spore-based
    bile = {
        name          = 'Bile',
        desc          = 'A fermenting mass that secretes corrosive bile.',
        baseYield     = 2,
        yieldInterval = 75,
        feedResource  = 'raw_meat',
        color         = { 0.3, 0.4, 0.05 },
        spore         = 'spore_bile',
        species       = 'bile_mold',
    },
    thorn = {
        name          = 'Thorn',
        desc          = 'Grows rigid barbed plates in layered formations.',
        baseYield     = 2,
        yieldInterval = 85,
        feedResource  = 'raw_stone',
        color         = { 0.35, 0.25, 0.2 },
        spore         = 'spore_thorn',
        species       = 'thorn_polyp',
    },
    nerve = {
        name          = 'Nerve',
        desc          = 'Exposed neural tissue. Feeds on corpses. Hard to look at.',
        baseYield     = 1,
        yieldInterval = 120,
        feedResource  = 'corpse_human',
        color         = { 0.15, 0.05, 0.2 },
        spore         = 'spore_nerve',
        species       = 'nerve_cluster',
    },
    rot = {
        name          = 'Rot',
        desc          = 'Decomposing mass that regrows as fast as it rots. Produces raw meat.',
        baseYield     = 3,
        yieldInterval = 50,
        feedResource  = 'corpse_creature',
        color         = { 0.25, 0.15, 0.1 },
        spore         = 'spore_rot',
        species       = 'rot_bloom',
    },
}

EldritchNodes.ELDRITCH_TYPES = ELDRITCH_TYPES

---------------------------------------------------------------------------
-- Procedural resource pool
-- Any eldritch creature can produce from this pool. Each creature rolls
-- a subset at tame time, weighted by its eldritchType.
-- typeWeight: higher = more likely for that type to roll this output.
---------------------------------------------------------------------------

local RESOURCE_POOL = {
    { itemId = 'raw_meat',       baseYield = 3, typeWeight = { flesh=50, ichor=10, chitin=15, void=5,  serpent=35, bile=15, thorn=10, nerve=5,  rot=40 } },
    { itemId = 'raw_hide',       baseYield = 2, typeWeight = { flesh=20, ichor=5,  chitin=30, void=5,  serpent=25, bile=5,  thorn=25, nerve=5,  rot=10 } },
    { itemId = 'raw_fur',        baseYield = 2, typeWeight = { flesh=15, ichor=3,  chitin=5,  void=3,  serpent=5,  bile=3,  thorn=5,  nerve=3,  rot=10 } },
    { itemId = 'eldritch_ichor', baseYield = 2, typeWeight = { flesh=10, ichor=50, chitin=10, void=15, serpent=15, bile=40, thorn=5,  nerve=20, rot=10 } },
    { itemId = 'raw_fat',        baseYield = 2, typeWeight = { flesh=30, ichor=20, chitin=5,  void=5,  serpent=20, bile=25, thorn=3,  nerve=5,  rot=20 } },
    { itemId = 'chitin_plate',   baseYield = 1, typeWeight = { flesh=5,  ichor=5,  chitin=50, void=10, serpent=15, bile=5,  thorn=40, nerve=5,  rot=5  } },
    { itemId = 'organ_heart',    baseYield = 1, typeWeight = { flesh=15, ichor=5,  chitin=5,  void=10, serpent=10, bile=5,  thorn=3,  nerve=15, rot=5  } },
    { itemId = 'organ_liver',    baseYield = 1, typeWeight = { flesh=10, ichor=10, chitin=5,  void=5,  serpent=10, bile=10, thorn=3,  nerve=5,  rot=5  } },
    { itemId = 'thermal_core',   baseYield = 1, typeWeight = { flesh=5,  ichor=10, chitin=5,  void=40, serpent=5,  bile=5,  thorn=5,  nerve=30, rot=3  } },
    { itemId = 'void_crystal',   baseYield = 1, typeWeight = { flesh=2,  ichor=5,  chitin=3,  void=30, serpent=3,  bile=3,  thorn=3,  nerve=20, rot=2  } },
    { itemId = 'metal_ingot',    baseYield = 1, typeWeight = { flesh=3,  ichor=5,  chitin=20, void=15, serpent=8,  bile=3,  thorn=15, nerve=5,  rot=3  } },
    { itemId = 'caustic_liquid', baseYield = 2, typeWeight = { flesh=3,  ichor=15, chitin=3,  void=5,  serpent=40, bile=30, thorn=3,  nerve=10, rot=15 } },
    { itemId = 'serpent_venom',  baseYield = 1, typeWeight = { flesh=2,  ichor=5,  chitin=3,  void=5,  serpent=50, bile=5,  thorn=3,  nerve=10, rot=3  } },
    { itemId = 'fuel',           baseYield = 2, typeWeight = { flesh=5,  ichor=10, chitin=3,  void=50, serpent=5,  bile=10, thorn=3,  nerve=3,  rot=5  } },
}

EldritchNodes.RESOURCE_POOL = RESOURCE_POOL

-- Max items per slot in a node's output buffer (backpressure)
local OUTPUT_BUF_MAX = 20

---------------------------------------------------------------------------
-- Roll a procedural resource profile for a creature.
-- Returns { { itemId, yield, interval, timer }, ... }
-- Luck distribution: most get 1-2 outputs, rare ones get many.
---------------------------------------------------------------------------

local function rollResourceProfile(eldritchType)
    local profile = {}
    local def = ELDRITCH_TYPES[eldritchType]
    if not def then return profile end

    -- Track what's already in the profile (for guaranteed + random dedup)
    local inProfile = {}

    -- Guaranteed outputs — always included for this type
    if def.guaranteedOutputs then
        for _, itemId in ipairs(def.guaranteedOutputs) do
            -- Find base yield from pool
            local baseYield = 2
            for _, entry in ipairs(RESOURCE_POOL) do
                if entry.itemId == itemId then
                    baseYield = entry.baseYield
                    break
                end
            end
            local yieldMult = 0.8 + math.random() * 0.4
            profile[#profile + 1] = {
                itemId   = itemId,
                yield    = math.max(1, math.floor(baseYield * yieldMult + 0.5)),
                interval = def.yieldInterval * (0.8 + math.random() * 0.4),
                timer    = 0,
            }
            inProfile[itemId] = true
        end
    end

    -- How many additional random outputs: skewed toward fewer
    local luckRoll = math.random()
    local extraCount
    if luckRoll < 0.30 then
        extraCount = 1
    elseif luckRoll < 0.60 then
        extraCount = 2
    elseif luckRoll < 0.80 then
        extraCount = 3
    elseif luckRoll < 0.92 then
        extraCount = 4
    elseif luckRoll < 0.97 then
        extraCount = 5
    elseif luckRoll < 0.995 then
        extraCount = math.random(6, 8)
    else
        extraCount = #RESOURCE_POOL
    end

    -- Build weighted candidates (exclude already-guaranteed items)
    local candidates = {}
    for _, entry in ipairs(RESOURCE_POOL) do
        if not inProfile[entry.itemId] then
            local w = (entry.typeWeight and entry.typeWeight[eldritchType]) or 1
            candidates[#candidates + 1] = { entry = entry, weight = w }
        end
    end

    -- Weighted random selection without replacement
    for _ = 1, math.min(extraCount, #candidates) do
        local totalWeight = 0
        for _, c in ipairs(candidates) do
            totalWeight = totalWeight + c.weight
        end
        if totalWeight <= 0 then break end

        local roll = math.random() * totalWeight
        local acc = 0
        local pick
        for i, c in ipairs(candidates) do
            acc = acc + c.weight
            if roll <= acc then
                pick = i
                break
            end
        end
        if not pick then pick = #candidates end

        local chosen = candidates[pick]
        local yieldMult = 0.6 + math.random() * 0.8
        profile[#profile + 1] = {
            itemId   = chosen.entry.itemId,
            yield    = math.max(1, math.floor(chosen.entry.baseYield * yieldMult + 0.5)),
            interval = def.yieldInterval * (0.8 + math.random() * 0.4),
            timer    = 0,
        }
        table.remove(candidates, pick)
    end

    return profile
end

EldritchNodes.rollResourceProfile = rollResourceProfile

---------------------------------------------------------------------------
-- Attach eldritch_growth component to a tamed eldritch creature
-- Called automatically when an eldritch_livestock species is tamed.
-- Rolls a procedural resource profile.
---------------------------------------------------------------------------

function EldritchNodes.initGrowth(entityId, eldritchType)
    if ECS.has(entityId, 'eldritch_growth') then return end

    local def = ELDRITCH_TYPES[eldritchType]
    if not def then return end

    local profile = rollResourceProfile(eldritchType)

    ECS.set(entityId, 'eldritch_growth', {
        eldritchType    = eldritchType,
        stage           = 1,
        growth          = 0,
        fed             = 0,
        mutated         = false,
        contained       = false,
        created         = GameState.day,
        resourceProfile = profile,
    })
end

---------------------------------------------------------------------------
-- Hatch an egg — spawns the creature and auto-tames it
---------------------------------------------------------------------------

function EldritchNodes.hatchEgg(eggItem, x, y, hatcherId, depth)
    local eldritchType
    for typeId, def in pairs(ELDRITCH_TYPES) do
        if def.egg == eggItem then
            eldritchType = typeId
            break
        end
    end
    if not eldritchType then return nil, 'Not a valid eldritch egg' end

    local def = ELDRITCH_TYPES[eldritchType]

    if (GameState.resources[eggItem] or 0) < 1 then
        return nil, 'No egg available'
    end
    local SNet = getStorageNet()
    if SNet then SNet.withdraw(eggItem, 1, x, y)
    else GameState.spendResource(eggItem, 1) end

    local Creatures = require('src.creatures.creatures')
    local World = require('src.world.tilemap')

    if not World.inBounds(x, y) or not World.isWalkable(x, y, depth or 0) then
        return nil, 'Invalid location'
    end

    local id = Creatures.spawn(def.species, x, y, depth)
    if not id then return nil, 'Failed to spawn creature' end

    local Taming = require('src.creatures.taming')
    Taming.applyTame(id, hatcherId)

    EldritchNodes.initGrowth(id, eldritchType)

    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk then
        local cr = ECS.get(id, 'creature')
        Storyteller.logEvent('ELDRITCH HATCHED',
            'A ' .. (cr and cr.name or 'creature') .. ' hatched from an eldritch egg.')
    end

    return id
end

---------------------------------------------------------------------------
-- Plant a spore — spawns the creature in-place and auto-tames it
-- Spores grow best in enclosed rooms (bonus starting growth).
---------------------------------------------------------------------------

function EldritchNodes.plantSpore(sporeItem, x, y, planterId, depth)
    local eldritchType
    for typeId, def in pairs(ELDRITCH_TYPES) do
        if def.spore == sporeItem then
            eldritchType = typeId
            break
        end
    end
    if not eldritchType then return nil, 'Not a valid eldritch spore' end

    local def = ELDRITCH_TYPES[eldritchType]

    if (GameState.resources[sporeItem] or 0) < 1 then
        return nil, 'No spore available'
    end
    local SNet = getStorageNet()
    if SNet then SNet.withdraw(sporeItem, 1, x, y)
    else GameState.spendResource(sporeItem, 1) end

    local Creatures = require('src.creatures.creatures')
    local World = require('src.world.tilemap')

    if not World.inBounds(x, y) or not World.isWalkable(x, y, depth or 0) then
        return nil, 'Invalid location'
    end

    local id = Creatures.spawn(def.species, x, y, depth)
    if not id then return nil, 'Failed to spawn creature' end

    local Taming = require('src.creatures.taming')
    Taming.applyTame(id, planterId)

    EldritchNodes.initGrowth(id, eldritchType)

    -- Enclosed room bonus: spores root faster in darkness
    local roomId = World.getRoom(x, y, depth or 0)
    if roomId and roomId > 0 then
        local growth = ECS.get(id, 'eldritch_growth')
        if growth then growth.growth = growth.growth + 10 end
    end

    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk then
        Storyteller.logEvent('SPORE PLANTED',
            'A ' .. def.name .. ' spore planted. Growth started.')
    end

    return id
end

---------------------------------------------------------------------------
-- Feed — accelerates growth. Uses the creature's preferred feed resource.
---------------------------------------------------------------------------

function EldritchNodes.feed(entityId, feederId)
    local growth = ECS.get(entityId, 'eldritch_growth')
    if not growth then return false, 'Not an eldritch creature' end

    local def = ELDRITCH_TYPES[growth.eldritchType]
    if not def then return false, 'Unknown eldritch type' end

    local stage = STAGES[growth.stage]
    if not stage then return false, 'Invalid stage' end

    if growth.stage >= 5 then
        return false, 'Already fully grown'
    end

    local feedRes = def.feedResource
    if (GameState.resources[feedRes] or 0) < 1 then
        return false, 'Need ' .. feedRes
    end

    local feedPos = ECS.get(entityId, 'pos')
    local fx = feedPos and feedPos.x or GameState.startX
    local fy = feedPos and feedPos.y or GameState.startY
    local SNet = getStorageNet()
    if SNet then SNet.withdraw(feedRes, 1, fx, fy)
    else GameState.spendResource(feedRes, 1) end

    local growthGain = 10

    -- Occultist / void_touched feeder bonus
    if feederId then
        local col = ECS.get(feederId, 'colonist')
        if col and col.traits then
            for _, t in ipairs(col.traits) do
                if t.id == 'anomaly_sensitive' then growthGain = growthGain * 1.5; break end
                if t.id == 'void_touched' then growthGain = growthGain * 1.3; break end
            end
        end
    end

    -- Ruin delver alliance bonus
    local fOk, Factions = pcall(require, 'src.colony.factions')
    if fOk and Factions.isAllied('ruin_delvers') then
        growthGain = growthGain * 1.25
    end

    growth.growth = growth.growth + growthGain
    growth.fed = growth.fed + 1

    -- Feeding can unlock additional resource outputs at high bond
    local tamed = ECS.get(entityId, 'tamed')
    if tamed and tamed.bondLevel and tamed.bondLevel >= 5 and growth.resourceProfile then
        -- At bond 5+, each feeding has a small chance to unlock a new output
        if #growth.resourceProfile < #RESOURCE_POOL and math.random() < 0.08 then
            local existing = {}
            for _, res in ipairs(growth.resourceProfile) do
                existing[res.itemId] = true
            end
            -- Pick a random unlocked resource
            local candidates = {}
            for _, entry in ipairs(RESOURCE_POOL) do
                if not existing[entry.itemId] then
                    local w = (entry.typeWeight and entry.typeWeight[growth.eldritchType]) or 1
                    candidates[#candidates + 1] = { entry = entry, weight = w }
                end
            end
            if #candidates > 0 then
                local totalW = 0
                for _, c in ipairs(candidates) do totalW = totalW + c.weight end
                local roll = math.random() * totalW
                local acc = 0
                for _, c in ipairs(candidates) do
                    acc = acc + c.weight
                    if roll <= acc then
                        local yieldMult = 0.6 + math.random() * 0.8
                        growth.resourceProfile[#growth.resourceProfile + 1] = {
                            itemId   = c.entry.itemId,
                            yield    = math.max(1, math.floor(c.entry.baseYield * yieldMult + 0.5)),
                            interval = def.yieldInterval * (0.8 + math.random() * 0.4),
                            timer    = 0,
                        }
                        local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
                        if stOk then
                            local cr = ECS.get(entityId, 'creature')
                            Storyteller.logEvent('NODE OUTPUT UNLOCKED',
                                (cr and cr.name or 'An eldritch creature') ..
                                ' has begun producing ' .. c.entry.itemId .. '.')
                        end
                        break
                    end
                end
            end
        end
    end

    -- Check stage advancement
    local needed = stage.growthNeeded
    if needed and growth.growth >= needed then
        EldritchNodes.advanceStage(entityId)
    end

    return true, 'Fed. Growth: ' .. math.floor(growth.growth)
end

---------------------------------------------------------------------------
-- Stage advancement — creature physically changes.
-- At stage 3+: sessile, gets machine component with outputBuf for inserters.
---------------------------------------------------------------------------

function EldritchNodes.advanceStage(entityId)
    local growth = ECS.get(entityId, 'eldritch_growth')
    local cr = ECS.get(entityId, 'creature')
    if not growth or not cr then return end

    growth.stage = math.min(5, growth.stage + 1)
    growth.growth = 0

    -- Eldritch growth raises anomaly level
    local anOk, AnomalyMod = pcall(require, 'src.sim.anomaly')
    if anOk and AnomalyMod.onNodeGrowth then
        AnomalyMod.onNodeGrowth()
    end

    local stage = STAGES[growth.stage]
    local def = ELDRITCH_TYPES[growth.eldritchType]

    -- Update creature physical properties (sizeScale for massive species: land whale, serpent)
    local sizeScale = (def and def.sizeScale) or 1.0
    cr.size = stage.size * sizeScale
    cr.speed = stage.speed

    -- Health scales with stage (use original base HP to avoid compounding)
    growth._baseHP = growth._baseHP or cr.maxHealth
    local hpMult = 1 + (growth.stage - 1) * 0.8
    cr.maxHealth = math.floor(growth._baseHP * hpMult)
    cr.health = cr.maxHealth

    -- At stage 3+ the creature becomes sessile
    if stage.sessile then
        local path = ECS.get(entityId, 'path')
        if path then
            path.nodes = nil
            path.index = 1
            path.moveTimer = 0
        end

        -- Attach machine component so inserters can pull from outputBuf
        if not ECS.has(entityId, 'machine') then
            ECS.set(entityId, 'machine', {
                type      = 'eldritch_node',
                name      = cr.name or 'Eldritch Node',
                recipe    = nil,
                inputBuf  = {},
                outputBuf = {},
                progress  = 0,
                active    = true,
                powered   = true,
                assignee  = nil,
            })
        end
    end

    -- Update creature name to reflect growth
    if def then
        local stageNames = {
            [1] = def.name .. ' Larva',
            [2] = def.name .. ' Whelp',
            [3] = def.name .. ' Growth',
            [4] = 'Living ' .. def.name .. ' Node',
            [5] = 'Ancient ' .. def.name .. ' Node',
        }
        cr.name = stageNames[growth.stage] or cr.name
        local machine = ECS.get(entityId, 'machine')
        if machine then machine.name = cr.name end
    end

    -- Hope impact
    local hOk, Hope = pcall(require, 'src.colony.hope')
    if hOk then
        Hope.applyDelta(-1 * growth.stage, growth.stage)
    end

    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk then
        local msg = cr.name .. ' has grown to ' .. stage.name .. ' stage.'
        if stage.sessile and growth.stage == 3 then
            msg = msg .. ' It has rooted itself to the ground. It will not move again.'
        elseif growth.stage == 5 then
            msg = msg .. ' Maximum size. Producing at full capacity.'
        end
        Storyteller.logEvent('ELDRITCH GROWTH', msg)
    end
end

---------------------------------------------------------------------------
-- Step — resource yield, passive growth, mutation checks
-- Sessile creatures (stage 3+) produce into machine.outputBuf.
-- Inserters pull from outputBuf onto belts — full Factorio pipeline.
---------------------------------------------------------------------------

local nodeTimer = 0
local NODE_TICK = 2.0

function EldritchNodes.step(dt)
    nodeTimer = nodeTimer + dt
    if nodeTimer < NODE_TICK then return end
    nodeTimer = 0

    for id, comps in ECS.query('eldritch_growth', 'creature', 'pos') do
        local growth = comps.eldritch_growth
        local cr     = comps.creature
        local pos    = comps.pos

        if cr.state == 'dead' then goto continue end
        if growth.mutated then goto continue end

        local stage = STAGES[growth.stage]
        local def   = ELDRITCH_TYPES[growth.eldritchType]
        if not stage or not def then goto continue end

        -- Enforce sessile
        if stage.sessile then
            cr.speed = 0
        end

        -- Resource yield (stage 3+) — output to machine buffer
        if stage.yieldMult > 0 and growth.resourceProfile then
            -- Calculate interval modifiers
            local intervalMod = 1.0
            if growth.contained then intervalMod = 0.8 end

            local fOk, Factions = pcall(require, 'src.colony.factions')
            if fOk and Factions.isAllied('ruin_delvers') then
                intervalMod = intervalMod * 0.85
            end

            local tamed = ECS.get(id, 'tamed')
            if tamed and tamed.bondLevel then
                intervalMod = intervalMod * (1 - tamed.bondLevel * 0.03)
            end

            -- Each resource in the profile ticks its own timer
            local machine = ECS.get(id, 'machine')
            for _, res in ipairs(growth.resourceProfile) do
                res.timer = (res.timer or 0) + NODE_TICK

                local effectiveInterval = res.interval * intervalMod
                if res.timer >= effectiveInterval then
                    res.timer = 0
                    local amount = math.max(1, math.floor(res.yield * stage.yieldMult + 0.5))

                    if machine and machine.outputBuf then
                        -- Factorio-style: populate outputBuf for inserters to pull
                        local current = machine.outputBuf[res.itemId] or 0
                        if current < OUTPUT_BUF_MAX then
                            machine.outputBuf[res.itemId] = math.min(OUTPUT_BUF_MAX, current + amount)
                        end
                    else
                        -- Fallback for pre-sessile (shouldn't yield) or missing machine
                        local Items = getItems()
                        if Items then Items.spawn(pos.x, pos.y, res.itemId, amount, nil, pos.depth or 0)
                        else GameState.addResource(res.itemId, amount) end
                    end
                end
            end
        end

        -- Passive growth (very slow without feeding)
        if growth.stage < 5 then
            growth.growth = growth.growth + 0.05
            local needed = stage.growthNeeded
            if needed and growth.growth >= needed then
                EldritchNodes.advanceStage(id)
            end
        end

        -- Containment check: sealed room?
        local World = require('src.world.tilemap')
        local roomId = World.getRoom(pos.x, pos.y, pos.depth or 0)
        growth.contained = (roomId and roomId > 0)

        -- Mutation risk (stage 3+)
        if growth.stage >= 3 then
            local risk = stage.mutationRisk * NODE_TICK / 60

            -- Uncontained: double risk
            if not growth.contained then risk = risk * 2.0 end

            -- Occultist nearby: 0.3x risk
            for cid, ccomps in ECS.query('colonist', 'pos') do
                local cpos = ccomps.pos
                local dx = math.abs(pos.x - cpos.x)
                local dy = math.abs(pos.y - cpos.y)
                if dx <= 5 and dy <= 5 then
                    local col = ECS.get(cid, 'colonist')
                    if col and col.traits then
                        for _, t in ipairs(col.traits) do
                            if t.id == 'anomaly_sensitive' then
                                risk = risk * 0.3
                                break
                            end
                        end
                    end
                end
            end

            -- Ruin delver alliance: 0.5x risk
            local fOk2, Factions2 = pcall(require, 'src.colony.factions')
            if fOk2 and Factions2.isAllied('ruin_delvers') then
                risk = risk * 0.5
            end

            if math.random() < risk then
                EldritchNodes.mutate(id)
            end
        end

        ::continue::
    end
end

---------------------------------------------------------------------------
-- Mutation — the creature breaks free, spawns hostile offspring
---------------------------------------------------------------------------

function EldritchNodes.mutate(entityId)
    local growth = ECS.get(entityId, 'eldritch_growth')
    local cr     = ECS.get(entityId, 'creature')
    local pos    = ECS.get(entityId, 'pos')
    if not growth or not cr or not pos then return end

    growth.mutated = true

    -- The creature itself becomes hostile
    cr.hostile = true
    cr.aggroRange = 20
    cr.leashRange = 999
    cr.speed = 1.5
    cr.damage = 15 + growth.stage * 10
    cr.state = 'chase'

    -- Remove tamed and machine components
    ECS.remove(entityId, 'tamed')
    ECS.remove(entityId, 'machine')

    -- Spawn hostile offspring based on stage
    local Creatures = require('src.creatures.creatures')
    local World = require('src.world.tilemap')

    local spawnCount = math.max(1, growth.stage - 1)
    local spawnPool = { 'spawnling', 'skitterer', 'frost_beetle' }
    if growth.stage >= 4 then
        spawnPool = { 'spawnling', 'stalker', 'shade' }
    end
    if growth.stage >= 5 then
        spawnPool = { 'stalker', 'alpha_stalker', 'fleshwalker' }
    end

    for _ = 1, spawnCount do
        local sx = pos.x + math.random(-3, 3)
        local sy = pos.y + math.random(-3, 3)
        local pd = pos.depth or 0
        if World.inBounds(sx, sy) and World.isWalkable(sx, sy, pd) then
            Creatures.spawn(spawnPool[math.random(#spawnPool)], sx, sy, pd)
        end
    end

    -- Hope penalty
    local hOk, Hope = pcall(require, 'src.colony.hope')
    if hOk then Hope.applyDelta(-5 * growth.stage, 3 * growth.stage) end

    -- Morale drain on nearby colonists
    for cid, ccomps in ECS.query('colonist', 'needs', 'pos') do
        local dx = math.abs(pos.x - ccomps.pos.x)
        local dy = math.abs(pos.y - ccomps.pos.y)
        if dx <= 10 and dy <= 10 then
            ccomps.needs.morale = math.max(0, ccomps.needs.morale - 10)
        end
    end

    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk then
        Storyteller.logEvent('ELDRITCH MUTATION',
            (cr.name or 'The eldritch creature') .. ' has broken free! Hostile offspring spawned. Combat alert.')
    end
end

---------------------------------------------------------------------------
-- Slaughter / harvest a grown eldritch creature (stage 3+ = big payout)
---------------------------------------------------------------------------

function EldritchNodes.harvest(entityId)
    local growth = ECS.get(entityId, 'eldritch_growth')
    local cr = ECS.get(entityId, 'creature')
    if not growth or not cr then return false, 'Not an eldritch creature' end

    local def = ELDRITCH_TYPES[growth.eldritchType]
    if not def then return false, 'Unknown type' end

    if growth.stage < 3 then
        return false, 'Must be at least Juvenile stage to harvest'
    end

    -- Collect anything remaining in the output buffer
    local hPos = ECS.get(entityId, 'pos')
    local hx = hPos and hPos.x or GameState.startX
    local hy = hPos and hPos.y or GameState.startY
    local hd = (hPos and hPos.depth) or 0
    local Items = getItems()

    local machine = ECS.get(entityId, 'machine')
    if machine and machine.outputBuf then
        for itemId, count in pairs(machine.outputBuf) do
            if count > 0 then
                if Items then Items.spawn(hx, hy, itemId, count, nil, hd)
                else GameState.addResource(itemId, count) end
            end
        end
    end

    -- Big one-time payout from the profile
    local totalYield = 0
    if growth.resourceProfile then
        for _, res in ipairs(growth.resourceProfile) do
            local amount = res.yield * growth.stage * 3
            if Items then Items.spawn(hx, hy, res.itemId, amount, nil, hd)
            else GameState.addResource(res.itemId, amount) end
            totalYield = totalYield + amount
        end
    end

    -- Bonus thermal cores from mature+ nodes
    if growth.stage >= 4 then
        if Items then Items.spawn(hx, hy, 'thermalCores', growth.stage * 2, nil, hd)
        else GameState.addResource('thermalCores', growth.stage * 2) end
    end

    -- Corpse for butchering
    if (cr.meat or 0) > 0 then
        local corpseAmt = math.max(1, math.floor(growth.stage / 2))
        GameState.resources.corpse_creature =
            (GameState.resources.corpse_creature or 0) + corpseAmt
    end

    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk then
        Storyteller.logEvent('ELDRITCH HARVESTED',
            (cr.name or 'The eldritch creature') .. ' has been slaughtered. '
            .. totalYield .. ' resources recovered from its body.')
    end

    ECS.destroy(entityId)
    return true, totalYield
end

---------------------------------------------------------------------------
-- Hook: called from taming.lua when an eldritch_livestock species is tamed
---------------------------------------------------------------------------

function EldritchNodes.onTamed(entityId)
    local cr = ECS.get(entityId, 'creature')
    if not cr then return end

    local Creatures = require('src.creatures.creatures')
    local sp = Creatures.SPECIES[cr.species]
    if not sp or not sp.eldritchType then return end

    EldritchNodes.initGrowth(entityId, sp.eldritchType)
end

---------------------------------------------------------------------------
-- Egg drops from eldritch creature kills
---------------------------------------------------------------------------

function EldritchNodes.onEldritchCreatureKilled(creatureId)
    local cr = ECS.get(creatureId, 'creature')
    if not cr then return end

    -- Eldritch tier creatures: 25% chance to drop an egg
    if cr.tier == 'eldritch' then
        if math.random() < 0.25 then
            local eggs = { 'flesh_egg', 'ichor_egg', 'chitin_egg', 'wyrm_egg' }
            if cr.species == 'fleshwalker' then
                eggs[#eggs + 1] = 'void_egg'
            end
            local egg = eggs[math.random(#eggs)]
            GameState.resources[egg] = (GameState.resources[egg] or 0) + 1
        end
        -- Separate small chance for spore drops from eldritch kills
        if math.random() < 0.15 then
            local spores = { 'spore_bile', 'spore_thorn', 'spore_rot' }
            if cr.species == 'fleshwalker' or cr.species == 'the_pale_thing' then
                spores[#spores + 1] = 'spore_nerve'
            end
            local spore = spores[math.random(#spores)]
            GameState.resources[spore] = (GameState.resources[spore] or 0) + 1
        end
    end

    -- Eldritch livestock killed: small chance to drop egg/spore of same type
    if cr.tier == 'eldritch_livestock' then
        local sp = require('src.creatures.creatures').SPECIES[cr.species]
        if sp and sp.eldritchType then
            local def = ELDRITCH_TYPES[sp.eldritchType]
            if def and math.random() < 0.15 then
                local dropItem = def.egg or def.spore
                if dropItem then
                    GameState.resources[dropItem] = (GameState.resources[dropItem] or 0) + 1
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function EldritchNodes.getAll()
    local result = {}
    for id, comps in ECS.query('eldritch_growth', 'creature', 'pos') do
        local growth = comps.eldritch_growth
        local cr     = comps.creature
        local def    = ELDRITCH_TYPES[growth.eldritchType]
        local stage  = STAGES[growth.stage]
        local machine = ECS.get(id, 'machine')

        -- Summarize resource profile
        local outputs = {}
        if growth.resourceProfile then
            for _, res in ipairs(growth.resourceProfile) do
                outputs[#outputs + 1] = res.itemId
            end
        end

        result[#result + 1] = {
            id            = id,
            eldritchType  = growth.eldritchType,
            name          = cr.name,
            stage         = growth.stage,
            stageName     = stage and stage.name or '?',
            growth        = growth.growth,
            outputs       = outputs,
            outputCount   = #outputs,
            contained     = growth.contained,
            mutated       = growth.mutated,
            sessile       = stage and stage.sessile or false,
            hasMachine    = machine ~= nil,
            health        = cr.health,
            maxHP         = cr.maxHealth,
            size          = cr.size,
            x             = comps.pos.x,
            y             = comps.pos.y,
        }
    end
    return result
end

function EldritchNodes.getNodeCount()
    return ECS.countWith('eldritch_growth')
end

function EldritchNodes.getProducingCount()
    local count = 0
    for id, comps in ECS.query('eldritch_growth') do
        if comps.eldritch_growth.stage >= 3 then
            count = count + 1
        end
    end
    return count
end

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

function EldritchNodes.getState()
    return { nodeTimer = nodeTimer }
end

function EldritchNodes.restoreState(state)
    if not state then return end
    nodeTimer = state.nodeTimer or 0
end

function EldritchNodes.init()
    nodeTimer = 0
end

return EldritchNodes
