-- taming.lua — Creature taming, husbandry, and processing
-- Colonists tame wounded creatures. Tamed animals serve colony roles:
-- guard (fights), hauler (carries), livestock (produces resources).
-- Pens are zones that house tamed animals. Animals eat from colony food.

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

local Taming = {}

---------------------------------------------------------------------------
-- Tameable species definitions
-- wildness: 0.0 (easy) to 1.0 (impossible). Skill check = wildness * 20.
-- role: primary colony role when tamed.
-- yield: periodic resource production for livestock.
---------------------------------------------------------------------------

local TAMEABLE = {
    -- Small — easy tames, mostly livestock or pest control
    frost_hare = {
        wildness     = 0.15,
        minSkill     = 1,
        role         = 'livestock',
        yield        = { resource = 'raw_hide', amount = 1, interval = 120 },
        foodDrain    = 0.02,
        trainable    = { 'follow' },
    },
    ice_fox = {
        wildness     = 0.30,
        minSkill     = 2,
        role         = 'hauler',
        yield        = { resource = 'raw_hide', amount = 1, interval = 180 },
        foodDrain    = 0.04,
        trainable    = { 'follow', 'hunt_vermin' },
    },
    snow_grouse = {
        wildness     = 0.10,
        minSkill     = 1,
        role         = 'livestock',
        yield        = { resource = 'food', amount = 1, interval = 90 },
        foodDrain    = 0.01,
        trainable    = {},
    },

    -- Medium — moderate difficulty, useful roles
    tundra_wolf = {
        wildness     = 0.55,
        minSkill     = 4,
        role         = 'guard',
        yield        = nil,  -- guards don't produce resources
        foodDrain    = 0.08,
        trainable    = { 'follow', 'guard', 'attack' },
        combatDamage = 10,
        combatHP     = 50,
    },
    dire_wolf = {
        wildness     = 0.65,
        minSkill     = 5,
        role         = 'guard',
        yield        = nil,
        foodDrain    = 0.10,
        trainable    = { 'follow', 'guard', 'attack', 'rescue' },
        combatDamage = 16,
        combatHP     = 75,
    },
    mammoth = {
        wildness     = 0.50,
        minSkill     = 4,
        role         = 'livestock',
        yield        = { resource = 'raw_hide', amount = 3, interval = 200 },
        foodDrain    = 0.15,
        trainable    = { 'follow', 'haul' },
        haulCapacity = 30,  -- item carry capacity
    },
    sabertooth = {
        wildness     = 0.70,
        minSkill     = 6,
        role         = 'guard',
        yield        = nil,
        foodDrain    = 0.10,
        trainable    = { 'follow', 'guard', 'attack' },
        combatDamage = 20,
        combatHP     = 90,
    },

    -- Large — hard tames, high reward
    glacier_bear = {
        wildness     = 0.80,
        minSkill     = 7,
        role         = 'guard',
        yield        = nil,
        foodDrain    = 0.12,
        trainable    = { 'follow', 'guard', 'attack', 'rescue' },
        combatDamage = 22,
        combatHP     = 100,
    },
    snow_ape = {
        wildness     = 0.85,
        minSkill     = 8,
        role         = 'hauler',
        yield        = { resource = 'raw_hide', amount = 2, interval = 150 },
        foodDrain    = 0.14,
        trainable    = { 'follow', 'haul' },
        haulCapacity = 50,
    },

    -- Eldritch livestock — tamed for growing into living resource nodes.
    -- These start as small creatures and grow into sessile resource producers.
    -- Yield is nil here because EldritchNodes.step() handles their production.
    gore_shoat = {
        wildness     = 0.35,
        minSkill     = 2,
        role         = 'eldritch_livestock',
        yield        = nil,  -- handled by eldritch_growth component
        foodDrain    = 0.06,
        trainable    = {},
        eldritchType = 'flesh',
    },
    weeping_calf = {
        wildness     = 0.30,
        minSkill     = 2,
        role         = 'eldritch_livestock',
        yield        = nil,
        foodDrain    = 0.05,
        trainable    = {},
        eldritchType = 'ichor',
    },
    husk_pup = {
        wildness     = 0.40,
        minSkill     = 3,
        role         = 'eldritch_livestock',
        yield        = nil,
        foodDrain    = 0.06,
        trainable    = { 'follow' },
        eldritchType = 'chitin',
    },
    void_minnow = {
        wildness     = 0.60,
        minSkill     = 6,
        role         = 'eldritch_livestock',
        yield        = nil,
        foodDrain    = 0.08,
        trainable    = {},
        eldritchType = 'void',
    },
    pit_wyrm = {
        wildness     = 0.50,
        minSkill     = 4,
        role         = 'eldritch_livestock',
        yield        = nil,
        foodDrain    = 0.07,
        trainable    = {},
        eldritchType = 'serpent',
    },

    -- Spore-grown eldritch livestock
    bile_mold = {
        wildness     = 0.30,
        minSkill     = 2,
        role         = 'eldritch_livestock',
        yield        = nil,
        foodDrain    = 0.04,
        trainable    = {},
        eldritchType = 'bile',
    },
    thorn_polyp = {
        wildness     = 0.35,
        minSkill     = 2,
        role         = 'eldritch_livestock',
        yield        = nil,
        foodDrain    = 0.05,
        trainable    = {},
        eldritchType = 'thorn',
    },
    nerve_cluster = {
        wildness     = 0.55,
        minSkill     = 4,
        role         = 'eldritch_livestock',
        yield        = nil,
        foodDrain    = 0.06,
        trainable    = {},
        eldritchType = 'nerve',
    },
    rot_bloom = {
        wildness     = 0.25,
        minSkill     = 2,
        role         = 'eldritch_livestock',
        yield        = nil,
        foodDrain    = 0.05,
        trainable    = {},
        eldritchType = 'rot',
    },
}

Taming.TAMEABLE = TAMEABLE

---------------------------------------------------------------------------
-- Training abilities
---------------------------------------------------------------------------

local TRAINING = {
    follow      = { name = 'Follow',      xpNeeded = 50,  desc = 'Follows assigned colonist' },
    guard       = { name = 'Guard',        xpNeeded = 120, desc = 'Guards an area, attacks hostiles' },
    attack      = { name = 'Attack',       xpNeeded = 200, desc = 'Attacks designated targets' },
    haul        = { name = 'Haul',         xpNeeded = 100, desc = 'Carries items to stockpiles' },
    hunt_vermin = { name = 'Hunt Vermin',  xpNeeded = 80,  desc = 'Kills pests in food storage' },
    rescue      = { name = 'Rescue',       xpNeeded = 250, desc = 'Drags downed colonists to safety' },
}

Taming.TRAINING = TRAINING

---------------------------------------------------------------------------
-- Taming attempt
-- Requires: creature at < 30% HP, colonist with hunting skill >= minSkill.
-- Roll: skill * 5 >= wildness * 100 (with randomness).
---------------------------------------------------------------------------

function Taming.canTame(creatureId)
    local cr = ECS.get(creatureId, 'creature')
    if not cr then return false, 'Not a creature' end
    if ECS.has(creatureId, 'tamed') then return false, 'Already tamed' end

    local def = TAMEABLE[cr.species]
    if not def then return false, 'This species cannot be tamed' end

    -- Must be wounded (< 30% HP)
    if cr.health > cr.maxHealth * 0.3 then
        return false, 'Creature must be wounded first (< 30% HP)'
    end

    return true, nil
end

function Taming.attemptTame(creatureId, colonistId)
    local ok, err = Taming.canTame(creatureId)
    if not ok then return false, err end

    local cr = ECS.get(creatureId, 'creature')
    local def = TAMEABLE[cr.species]

    -- Skill check
    local skill = 0
    local sOk, Skills = pcall(require, 'src.colonist.skills')
    if sOk then
        skill = Skills.getEffectiveLevel(colonistId, 'hunting') or 0
    end

    if skill < def.minSkill then
        return false, 'Hunting skill too low (need ' .. def.minSkill .. ')'
    end

    -- Occultist trait bonus (+10% success for eldritch-adjacent creatures)
    local traitBonus = 0
    local col = ECS.get(colonistId, 'colonist')
    if col and col.traits then
        for _, t in ipairs(col.traits) do
            if t.id == 'animal_friend' then traitBonus = traitBonus + 15 end
        end
    end

    -- Roll: (skill * 5 + traitBonus + random(0,20)) vs (wildness * 100)
    local roll = skill * 5 + traitBonus + math.random(0, 20)
    local threshold = def.wildness * 100

    if roll < threshold then
        -- Failed tame — creature may become enraged
        cr.hostile = true
        cr.aggroRange = 15
        cr.state = 'chase'
        cr.target = colonistId
        return false, 'Taming failed! The creature is enraged.'
    end

    -- Success: apply tamed component
    Taming.applyTame(creatureId, colonistId)

    -- XP for tamer
    if sOk then Skills.addXp(colonistId, 'hunting', 15 + def.wildness * 30) end

    return true, 'Taming successful!'
end

---------------------------------------------------------------------------
-- Apply tamed state to a creature
---------------------------------------------------------------------------

function Taming.applyTame(creatureId, tamerId)
    local cr = ECS.get(creatureId, 'creature')
    if not cr then return end

    local def = TAMEABLE[cr.species]
    if not def then return end

    -- Switch creature behavior
    cr.hostile = false
    cr.aggroRange = 0
    cr.fleeRange = 0
    cr.state = 'idle'
    cr.target = nil

    -- Heal to 50% on successful tame
    cr.health = math.max(cr.health, cr.maxHealth * 0.5)

    -- Set tamed component
    ECS.set(creatureId, 'tamed', {
        species      = cr.species,
        tamer        = tamerId,
        role         = def.role,
        bondLevel    = 1,       -- 1-10
        bondXp       = 0,
        hunger       = 100,     -- 0-100 (0 = starving)
        foodDrain    = def.foodDrain,
        yieldTimer   = 0,
        training     = {},      -- { [abilityId] = xp }
        trained      = {},      -- { [abilityId] = true }
        assignedTo   = nil,     -- zone or colonist entity
    })

    -- Eldritch livestock: attach growth component
    if def.eldritchType then
        local enOk, EN = pcall(require, 'src.creatures.eldritch_nodes')
        if enOk then EN.onTamed(creatureId) end
    end

    -- Log event
    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk then
        Storyteller.logEvent('CREATURE TAMED',
            cr.name .. ' has been tamed and joins the colony.')
    end
end

---------------------------------------------------------------------------
-- Tamed creature update — hunger, yields, bond XP
---------------------------------------------------------------------------

local tamedTimer = 0
local TAMED_TICK = 1.0  -- 1 second intervals

-- Track active tame task IDs to avoid duplicates
local activeTameTasks = {}  -- { [creatureId] = taskId }

local tameJobTimer = 0
local TAME_JOB_TICK = 5.0  -- check every 5 seconds

local function createTameJobs(dt)
    tameJobTimer = tameJobTimer + dt
    if tameJobTimer < TAME_JOB_TICK then return end
    tameJobTimer = 0

    local jOk, Jobs = pcall(require, 'src.colonist.jobs')
    if not jOk then return end

    -- Clean stale entries
    for cid, taskId in pairs(activeTameTasks) do
        local task = Jobs.getTask(taskId)
        if not task or task.complete then
            activeTameTasks[cid] = nil
        end
    end

    -- Scan for wounded tameable creatures
    for id, comps in ECS.query('creature', 'pos') do
        if activeTameTasks[id] then goto skip end
        if ECS.has(id, 'tamed') then goto skip end
        local cr = comps.creature
        if not cr or (cr.health or 0) <= 0 then goto skip end
        local def = TAMEABLE[cr.species]
        if not def then goto skip end
        -- Must be wounded enough to tame (< 30% HP)
        if cr.health > (cr.maxHealth or 100) * 0.3 then goto skip end

        local pos = comps.pos
        local taskId = Jobs.createTask('tame', pos.x, pos.y, {
            creatureId = id,
            depth = pos.depth or 0,
        })
        if taskId then
            activeTameTasks[id] = taskId
        end
        ::skip::
    end
end

function Taming.step(dt)
    createTameJobs(dt)

    tamedTimer = tamedTimer + dt
    if tamedTimer < TAMED_TICK then return end
    tamedTimer = 0

    for id, comps in ECS.query('creature', 'tamed') do
        local cr    = comps.creature
        local tamed = comps.tamed
        if cr.state == 'dead' then goto continue end

        local def = TAMEABLE[tamed.species]
        if not def then goto continue end

        -- Hunger drain
        tamed.hunger = tamed.hunger - tamed.foodDrain * TAMED_TICK
        if tamed.hunger < 50 then
            -- Try to eat from colony food
            if (GameState.resources.food or 0) >= 1 then
                local tPos = comps.pos
                local SNet = getStorageNet()
                if SNet then SNet.withdraw('food', 1, tPos and tPos.x or GameState.startX, tPos and tPos.y or GameState.startY)
                else GameState.spendResource('food', 1) end
                tamed.hunger = math.min(100, tamed.hunger + 30)
            end
        end

        -- Starvation damage
        if tamed.hunger <= 0 then
            tamed.hunger = 0
            cr.health = cr.health - 1  -- slow starvation
            if cr.health <= 0 then
                local cOk, Creatures = pcall(require, 'src.creatures.creatures')
                if cOk then Creatures.kill(id) end
                goto continue
            end
        end

        -- Bond XP (passive, slow)
        tamed.bondXp = tamed.bondXp + 0.1
        local bondThreshold = tamed.bondLevel * 20
        if tamed.bondXp >= bondThreshold and tamed.bondLevel < 10 then
            tamed.bondLevel = tamed.bondLevel + 1
            tamed.bondXp = 0
        end

        -- Resource yield (livestock only)
        if def.yield and tamed.hunger > 20 then
            tamed.yieldTimer = tamed.yieldTimer + TAMED_TICK
            -- Bond level reduces interval
            local effectiveInterval = def.yield.interval * (1 - tamed.bondLevel * 0.05)
            if tamed.yieldTimer >= effectiveInterval then
                tamed.yieldTimer = 0
                local amount = def.yield.amount
                -- High bond yields more
                if tamed.bondLevel >= 5 then amount = amount + 1 end
                if tamed.bondLevel >= 9 then amount = amount + 1 end
                local yPos = comps.pos
                local Items = getItems()
                if Items then Items.spawn(yPos and yPos.x or GameState.startX, yPos and yPos.y or GameState.startY, def.yield.resource, amount, nil, (yPos and yPos.depth) or 0)
                else GameState.addResource(def.yield.resource, amount) end
            end
        end

        ::continue::
    end
end

---------------------------------------------------------------------------
-- Training
---------------------------------------------------------------------------

function Taming.train(creatureId, abilityId, trainerId)
    local tamed = ECS.get(creatureId, 'tamed')
    if not tamed then return false, 'Not tamed' end

    local def = TAMEABLE[tamed.species]
    if not def then return false, 'Unknown species' end

    -- Check if ability is available for this species
    local available = false
    for _, ab in ipairs(def.trainable) do
        if ab == abilityId then available = true; break end
    end
    if not available then return false, 'This species cannot learn ' .. abilityId end

    if tamed.trained[abilityId] then return false, 'Already trained' end

    local tDef = TRAINING[abilityId]
    if not tDef then return false, 'Unknown ability' end

    -- Add training XP
    local xpGain = 5
    local sOk, Skills = pcall(require, 'src.colonist.skills')
    if sOk then
        local skill = Skills.getEffectiveLevel(trainerId, 'hunting') or 1
        xpGain = xpGain + skill * 2
    end

    tamed.training[abilityId] = (tamed.training[abilityId] or 0) + xpGain

    if tamed.training[abilityId] >= tDef.xpNeeded then
        tamed.trained[abilityId] = true
        tamed.bondXp = tamed.bondXp + 5  -- training builds bond
        return true, 'Trained: ' .. tDef.name
    end

    return true, string.format('%s: %d/%d XP',
        tDef.name, tamed.training[abilityId], tDef.xpNeeded)
end

---------------------------------------------------------------------------
-- Pen zone management
-- Tamed animals in pen zones are contained. Outside pens, they follow tamer.
---------------------------------------------------------------------------

function Taming.assignToPen(creatureId, zoneId)
    local tamed = ECS.get(creatureId, 'tamed')
    if not tamed then return false end
    tamed.assignedTo = zoneId
    return true
end

function Taming.unassign(creatureId)
    local tamed = ECS.get(creatureId, 'tamed')
    if not tamed then return false end
    tamed.assignedTo = nil
    return true
end

---------------------------------------------------------------------------
-- Slaughter a tamed animal (produces corpse for butchering)
---------------------------------------------------------------------------

function Taming.slaughter(creatureId)
    local cr = ECS.get(creatureId, 'creature')
    local tamed = ECS.get(creatureId, 'tamed')
    if not cr or not tamed then return false end

    -- Produce corpse
    GameState.resources.corpse_creature =
        (GameState.resources.corpse_creature or 0) + 1

    -- Bonus hide from tamed animal (they're healthier)
    if (cr.meat or 0) > 0 then
        local slPos = ECS.get(creatureId, 'pos')
        local Items = getItems()
        if Items then Items.spawn(slPos and slPos.x or GameState.startX, slPos and slPos.y or GameState.startY, 'raw_hide', 1, nil, (slPos and slPos.depth) or 0)
        else GameState.addResource('raw_hide', 1) end
    end

    ECS.destroy(creatureId)
    return true
end

---------------------------------------------------------------------------
-- Breeding — two tamed same-species in same pen, bond >= 3
---------------------------------------------------------------------------

local breedTimer = 0
local BREED_CHECK = 60  -- seconds between breed checks

function Taming.checkBreeding(dt)
    breedTimer = breedTimer + dt
    if breedTimer < BREED_CHECK then return end
    breedTimer = 0

    -- Group tamed creatures by species + zone
    local pens = {}  -- { [species..zone] = { ids } }
    for id, comps in ECS.query('creature', 'tamed') do
        local tamed = comps.tamed
        if tamed.assignedTo and tamed.bondLevel >= 3 and tamed.hunger > 50 then
            local key = tamed.species .. ':' .. tostring(tamed.assignedTo)
            if not pens[key] then pens[key] = {} end
            pens[key][#pens[key] + 1] = id
        end
    end

    -- Breeding: need 2+ of same species in same pen
    for key, ids in pairs(pens) do
        if #ids >= 2 then
            -- 10% chance per check
            if math.random() < 0.10 and ECS.isAlive(ids[1]) then
                local species = key:match('^(.+):')
                local pos = ECS.get(ids[1], 'pos')
                if pos then
                    local cOk, Creatures = pcall(require, 'src.creatures.creatures')
                    local newId = cOk and Creatures.spawn(species, pos.x + math.random(-2, 2), pos.y + math.random(-2, 2), pos.depth)
                    if newId then
                        -- Born tamed
                        Taming.applyTame(newId, nil)
                        local newTamed = ECS.get(newId, 'tamed')
                        if newTamed then
                            newTamed.assignedTo = ids[1] and ECS.get(ids[1], 'tamed') and ECS.get(ids[1], 'tamed').assignedTo
                        end

                        local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
                        if stOk then
                            local cr = ECS.get(newId, 'creature')
                            Storyteller.logEvent('ANIMAL BORN',
                                'A new ' .. (cr and cr.name or 'creature') .. ' was born in the pen!')
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Taming.getTamedCount()
    return ECS.countWith('tamed')
end

function Taming.getAllTamed()
    local result = {}
    for id, comps in ECS.query('creature', 'tamed') do
        result[#result + 1] = {
            id       = id,
            species  = comps.tamed.species,
            name     = comps.creature.name,
            role     = comps.tamed.role,
            bond     = comps.tamed.bondLevel,
            hunger   = comps.tamed.hunger,
            health   = comps.creature.health,
            maxHP    = comps.creature.maxHealth,
            zone     = comps.tamed.assignedTo,
            trained  = comps.tamed.trained,
        }
    end
    return result
end

function Taming.isTamed(creatureId)
    return ECS.has(creatureId, 'tamed')
end

function Taming.getTameableSpecies()
    local result = {}
    for species, def in pairs(TAMEABLE) do
        result[#result + 1] = {
            species  = species,
            wildness = def.wildness,
            minSkill = def.minSkill,
            role     = def.role,
            yield    = def.yield,
        }
    end
    table.sort(result, function(a, b) return a.wildness < b.wildness end)
    return result
end

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

function Taming.getState()
    return {
        breedTimer = breedTimer,
        tamedTimer = tamedTimer,
    }
end

function Taming.restoreState(state)
    if not state then return end
    breedTimer = state.breedTimer or 0
    tamedTimer = state.tamedTimer or 0
end

function Taming.init()
    breedTimer = 0
    tamedTimer = 0
end

return Taming
