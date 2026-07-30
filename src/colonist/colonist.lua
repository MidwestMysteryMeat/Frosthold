-- colonist.lua — Colonist spawning, AI behavior, needs
-- Colonists are ECS entities with: pos, colonist, needs, inventory, pathfinding

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Pathfind  = require('src.util.pathfind')
local Occupancy = require('src.util.occupancy')
local Adlib     = require('src.util.adlib')
local Schedule  = require('src.colonist.schedule')
local Jobs      = require('src.colonist.jobs')

local Colonist = {}

-- Lazy-loaded modules for movement system (avoid pcall in hot path)
local _BodyMod, _EquipMod, _StatusFx, _FilthMod, _TileSnowMod, _TileFluidsMod, _TileGasMod
local function lazyLoadMovement()
    if _BodyMod ~= nil then return end  -- nil means not loaded, false means failed
    local ok
    ok, _BodyMod = pcall(require, 'src.combat.body')
    if not ok then _BodyMod = false end
    ok, _EquipMod = pcall(require, 'src.colonist.equipment')
    if not ok then _EquipMod = false end
    ok, _StatusFx = pcall(require, 'src.sim.status_effects')
    if not ok then _StatusFx = false end
    ok, _FilthMod = pcall(require, 'src.sim.filth')
    if not ok then _FilthMod = false end
    ok, _TileSnowMod = pcall(require, 'src.sim.tile_snow')
    if not ok then _TileSnowMod = false end
    ok, _TileFluidsMod = pcall(require, 'src.sim.tile_fluids')
    if not ok then _TileFluidsMod = false end
    ok, _TileGasMod = pcall(require, 'src.sim.tile_gas')
    if not ok then _TileGasMod = false end
end

-- Lazy-loaded modules for needs decay system
local _DebugPanel, _RoomsMod, _Policies, _Laws, _Atmosphere, _Disease, _Lighting, _HopeMod, _SkillsMod
local function lazyLoadNeeds()
    if _DebugPanel ~= nil then return end
    local ok
    ok, _DebugPanel = pcall(require, 'src.ui.debug_panel')
    if not ok then _DebugPanel = false end
    ok, _RoomsMod = pcall(require, 'src.world.rooms')
    if not ok then _RoomsMod = false end
    ok, _Policies = pcall(require, 'src.colony.policies')
    if not ok then _Policies = false end
    ok, _Laws = pcall(require, 'src.colony.laws')
    if not ok then _Laws = false end
    ok, _Atmosphere = pcall(require, 'src.sim.atmosphere')
    if not ok then _Atmosphere = false end
    ok, _Disease = pcall(require, 'src.sim.disease')
    if not ok then _Disease = false end
    ok, _Lighting = pcall(require, 'src.sim.lighting')
    if not ok then _Lighting = false end
    ok, _HopeMod = pcall(require, 'src.colony.hope')
    if not ok then _HopeMod = false end
    ok, _SkillsMod = pcall(require, 'src.colonist.skills')
    if not ok then _SkillsMod = false end
end

local SKILLS = { 'mining', 'building', 'cooking', 'hunting', 'research', 'medical' }

local function randomSkills(traits)
    local skills = {}
    for _, s in ipairs(SKILLS) do
        skills[s] = math.random(1, 8)
    end
    -- One strong skill
    local best = SKILLS[math.random(#SKILLS)]
    skills[best] = math.max(skills[best], math.random(6, 10))

    -- Trait-based skill boosts
    if traits then
        for _, t in ipairs(traits) do
            if t.id == 'eagle_eye' then
                skills.hunting = math.min(10, skills.hunting + 2)
            elseif t.id == 'green_thumb' then
                skills.cooking = math.min(10, skills.cooking + 2)
            elseif t.id == 'former_doc' then
                skills.medical = math.min(10, skills.medical + 3)
            elseif t.id == 'tinkerer' then
                skills.building = math.min(10, skills.building + 2)
            elseif t.id == 'ex_soldier' then
                skills.hunting = math.min(10, skills.hunting + 2)
            end
        end
    end
    return skills
end

-- Resolve trait modifiers for a colonist (sum of all trait[modName] values)
local function getTraitMod(col, modName)
    local total = 0
    if col.traits then
        for _, t in ipairs(col.traits) do
            if t[modName] then total = total + t[modName] end
        end
    end
    return total
end

--- Generate passions for a new colonist
local function generatePassions(col)
    local sok, SkillsMod = pcall(require, 'src.colonist.skills')
    if sok and SkillsMod.generatePassions then
        SkillsMod.generatePassions(col)
    end
end

---------------------------------------------------------------------------
-- Kill a colonist: notify systems, spawn corpse item, destroy entity.
-- All death paths should call this instead of duplicating the logic.
---------------------------------------------------------------------------

function Colonist.kill(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col or col.state == 'dead' then return end

    -- Headless simulation triage: log the vitals snapshot at death
    if _G.SIMULATION_TEST then
        local needs = ECS.get(entityId, 'needs')
        local pos = ECS.get(entityId, 'pos')
        local woundInfo = ''
        local wc = ECS.get(entityId, 'wounds')
        if wc and wc.list then
            for _, w in ipairs(wc.list) do
                woundInfo = woundInfo .. string.format(' %s/%s/sev%.2f/age%.0f%s',
                    tostring(w.type), tostring(w.treatment), w.severity or 0,
                    w.age or 0, w.infected and '/INF' or '')
            end
        end
        -- Was this a mauling, and was the colonist even able to hit back?
        local equip = ECS.get(entityId, 'equipment')
        local weaponId = (equip and equip.weapon and equip.weapon.id) or 'none'
        local maul = 'none'
        if col._lastMauledBy then
            maul = string.format('%s/%.1f', col._lastMauledBy, col._lastMauledDmg or 0)
        end
        print(string.format('[SimDeath] %s state=%s pos=(%s,%s) warmth=%.0f food=%.0f water=%.0f suff=%s hypo=%s heat=%s rad=%s tox=%s mauledBy=%s weapon=%s wounds[%s]',
            tostring(col.name), tostring(col.state),
            pos and pos.x or '?', pos and pos.y or '?',
            needs and needs.warmth or -1, needs and needs.food or -1,
            needs and (needs.water or -1) or -1,
            tostring(col._suffocating), tostring(col._hypothermia),
            tostring(col._heatstroke), tostring(col._radiationSickness),
            tostring(col._toxicExposure),
            maul, weaponId, woundInfo))
    end

    col.state  = 'dead'
    col.health = 0
    col.task   = nil

    -- Notify colony systems
    local hopeOk, Hope = pcall(require, 'src.colony.hope')
    if hopeOk then Hope.onColonistDeath(col.name or 'Unknown') end
    -- Death toast notification
    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk and Storyteller.logEvent then
        Storyteller.logEvent('colonist_death',
            (col.name or 'A colonist') .. ' has died.')
    end
    local socOk, Social = pcall(require, 'src.colonist.social')
    if socOk then Social.onColonistDeath(entityId) end
    local edOk, Elastic = pcall(require, 'src.sim.elastic_difficulty')
    if edOk then Elastic.onColonistDeath() end
    local wOk, WoundsMod = pcall(require, 'src.combat.wounds')
    if wOk and WoundsMod.onEntityRemoved then WoundsMod.onEntityRemoved(entityId) end
    local eeOk, EasterEggsMod = pcall(require, 'src.sim.easter_eggs')
    if eeOk and EasterEggsMod.onColonistDeath then EasterEggsMod.onColonistDeath(entityId) end

    -- Auto-pause on death
    if GameState.autoPause and GameState.autoPause.onDeath then
        GameState.paused = true
    end

    -- Laws: cannibalism — human meat per death
    local lawOk, Laws = pcall(require, 'src.colony.laws')
    if lawOk then
        local foodPerDeath = Laws.getFoodPerDeath()
        if foodPerDeath > 0 then
            local deathPos = ECS.get(entityId, 'pos')
            local ciok, CItems = pcall(require, 'src.world.items')
            if ciok and deathPos then
                CItems.spawn(deathPos.x, deathPos.y, 'human_meat', foodPerDeath, 'food')
            else
                GameState.addResource('food', foodPerDeath)
            end
        end
    end

    -- Drop corpse item at death location, preserve identity for revival
    local iok, Items = pcall(require, 'src.world.items')
    if iok then
        local pos = ECS.get(entityId, 'pos')
        if pos then
            local corpseId = Items.spawn(pos.x, pos.y, 'corpse_human', 1, 'corpse')
            if corpseId then
                local corpseItem = ECS.get(corpseId, 'item')
                if corpseItem then
                    corpseItem._colonistName      = col.name
                    corpseItem._colonistBackstory  = col.backstory
                    corpseItem._colonistTraits     = col.traits
                    corpseItem._colonistSkills     = col.skills
                    corpseItem._colonistAge        = col.age
                end
            end
        end
    end

    -- Release bed if assigned
    local bok, Beds = pcall(require, 'src.building.beds')
    if bok and col._bedId and ECS.isAlive(col._bedId) then
        local bed = ECS.get(col._bedId, 'bed')
        if bed then bed.occupied = false end
    end

    -- Drop any hauled items carried by this colonist at death position
    -- Hauled items may not share colonist position (they stay at pickup point),
    -- so we check ALL hauled items and drop them at colonist's death location.
    local deathPos = ECS.get(entityId, 'pos')
    if deathPos then
        for eid, itemComp in pairs(ECS.getAll('item') or {}) do
            if itemComp.hauled then
                -- Check if this item's haul task is claimed by the dying colonist
                local isOurs = false
                if itemComp._haulTaskId then
                    local task = Jobs.getTask and Jobs.getTask(itemComp._haulTaskId)
                    if task and task.claimed == entityId then
                        isOurs = true
                    end
                end
                -- Fallback: if no task tracking, check position proximity
                if not isOurs then
                    local ipos = ECS.get(eid, 'pos')
                    if ipos and math.abs(ipos.x - deathPos.x) <= 2 and math.abs(ipos.y - deathPos.y) <= 2 then
                        isOurs = true
                    end
                end
                if isOurs then
                    itemComp.hauled = false
                    itemComp._haulTaskId = nil
                    -- Move item to death position so it's visible
                    local ipos = ECS.get(eid, 'pos')
                    if ipos then
                        ipos.x = deathPos.x
                        ipos.y = deathPos.y
                        ipos.depth = deathPos.depth or 0
                    end
                end
            end
        end
    end
    local inv = ECS.get(entityId, 'inventory')
    if inv then inv.currentWeight = 0 end

    -- Destroy colonist entity — corpse item is the physical object now
    ECS.destroy(entityId)
end

---------------------------------------------------------------------------
-- Spawn
---------------------------------------------------------------------------

function Colonist.spawnInitial(cx, cy, count)
    for i = 1, count do
        local id = ECS.spawn()
        local angle = (i / count) * math.pi * 2
        local dist = 2
        local tx = cx + math.floor(math.cos(angle) * dist)
        local ty = cy + math.floor(math.sin(angle) * dist)

        ECS.set(id, 'pos', {
            x = tx, y = ty,
            prevX = tx, prevY = ty,
            targetX = nil, targetY = nil,
            depth = 0,
        })

        local identity = Adlib.generateColonistIdentity()
        local traits = identity.traits
        local healthMod = getTraitMod({ traits = traits }, 'healthMod')
        local carryMod = getTraitMod({ traits = traits }, 'carryMod')
        local maxHp = math.floor(100 * (1 + healthMod))
        local colData = {
            name      = identity.name,
            gender    = identity.gender,
            backstory = identity.backstory,
            disabledWork = identity.disabledWork,
            traits    = traits,
            skills    = randomSkills(traits),
            skillXp   = {},
            passions  = {},
            skillRust = {},
            skillTimers = {},
            health    = maxHp,
            maxHealth = maxHp,
            sanity    = 100,
            age       = 20 + math.random(30),
            task      = nil,
            state     = 'idle',
            facing    = angle,  -- vision cone direction (radians)
        }
        generatePassions(colData)
        ECS.set(id, 'colonist', colData)

        -- MRP genetic unlocks: apply permanent campaign upgrades to each new colonist
        local mok, MRP = pcall(require, 'src.sim.mrp')
        if mok then
            if MRP.hasUnlock('cold_adapted_genome') then
                colData.hypothermiaResist = (colData.hypothermiaResist or 0) + 1
            end
            if MRP.hasUnlock('enhanced_metabolism') then
                colData.hungerRate = (colData.hungerRate or 1.0) * 0.85
            end
            if MRP.hasUnlock('neural_plasticity') then
                colData.learnRate = (colData.learnRate or 1.0) * 1.20
            end
            if MRP.hasUnlock('stress_inoculation') then
                colData.breakThreshold = (colData.breakThreshold or 20) - 5
            end
        end

        ECS.set(id, 'needs', {
            warmth       = 80,   -- 0-100 (0 = freezing to death)
            food         = 80,   -- 0-100 (0 = starving)
            water        = 80,   -- 0-100 (0 = dehydrated)
            rest         = 80,   -- 0-100 (0 = exhausted)
            morale       = 70,   -- 0-100 (0 = mental break)
            joy          = 50,   -- 0-100 (0 = joyless, morale penalty)
            heatExposure = 0,    -- 0-100, rises when hot and unprotected
            radiation    = 0,    -- 0-100, rises near radiation sources
            toxicity     = 0,    -- 0-100, rises during acid storms / toxic exposure
        })

        ECS.set(id, 'inventory', {
            items = {},
            maxWeight = math.floor(50 * (1 + carryMod)),  -- base 50 weight units
            currentWeight = 0,
        })

        ECS.set(id, 'path', {
            nodes = nil,
            index = 1,
            moveTimer = 0,
        })

        ECS.set(id, 'schedule', Schedule.default())
        ECS.set(id, 'workPriority', Jobs.defaultPriorities())

        -- Phase 5: body parts and equipment slots
        Colonist._attachCombatComponents(id)
    end
end

-- Spawn from pre-drafted colonist data (from the selection screen)
function Colonist.spawnFromDraft(cx, cy, draftedList)
    for i, draft in ipairs(draftedList) do
        local id = ECS.spawn()
        local angle = (i / #draftedList) * math.pi * 2
        local dist = 2
        local tx = cx + math.floor(math.cos(angle) * dist)
        local ty = cy + math.floor(math.sin(angle) * dist)

        ECS.set(id, 'pos', {
            x = tx, y = ty,
            prevX = tx, prevY = ty,
            targetX = nil, targetY = nil,
            depth = 0,
        })

        local draftTraits = draft.traits
        local dHealthMod = getTraitMod({ traits = draftTraits }, 'healthMod')
        local dCarryMod = getTraitMod({ traits = draftTraits }, 'carryMod')
        local dMaxHp = math.floor(100 * (1 + dHealthMod))
        local colData = {
            name      = draft.name,
            gender    = draft.gender,
            backstory = draft.backstory,
            disabledWork = draft.disabledWork,
            traits    = draftTraits,
            skills    = draft.skills,
            skillXp   = {},
            passions  = draft.passions or {},
            skillRust = {},
            skillTimers = {},
            health    = dMaxHp,
            maxHealth = dMaxHp,
            sanity    = 100,
            age       = draft.age or math.random(20, 55),
            task      = nil,
            state     = 'idle',
            facing    = angle,  -- vision cone direction (radians)
        }
        if not draft.passions then generatePassions(colData) end
        ECS.set(id, 'colonist', colData)

        -- MRP genetic unlocks: apply permanent campaign upgrades to each new colonist
        local mok, MRP = pcall(require, 'src.sim.mrp')
        if mok then
            if MRP.hasUnlock('cold_adapted_genome') then
                colData.hypothermiaResist = (colData.hypothermiaResist or 0) + 1
            end
            if MRP.hasUnlock('enhanced_metabolism') then
                colData.hungerRate = (colData.hungerRate or 1.0) * 0.85
            end
            if MRP.hasUnlock('neural_plasticity') then
                colData.learnRate = (colData.learnRate or 1.0) * 1.20
            end
            if MRP.hasUnlock('stress_inoculation') then
                colData.breakThreshold = (colData.breakThreshold or 20) - 5
            end
        end

        ECS.set(id, 'needs', {
            warmth = 80, food = 80, water = 80, rest = 80, morale = 70, joy = 50,
            heatExposure = 0, radiation = 0, toxicity = 0,
        })

        ECS.set(id, 'inventory', { items = {}, maxWeight = math.floor(50 * (1 + dCarryMod)), currentWeight = 0 })
        ECS.set(id, 'path', { nodes = nil, index = 1, moveTimer = 0 })
        ECS.set(id, 'schedule', Schedule.default())
        ECS.set(id, 'workPriority', Jobs.defaultPriorities())

        Colonist._attachCombatComponents(id)
    end
end

function Colonist.spawn(x, y, depth)
    local id = ECS.spawn()
    local identity = Adlib.generateColonistIdentity()
    ECS.set(id, 'pos', { x = x, y = y, prevX = x, prevY = y, depth = depth or 0 })
    local sTraits = identity.traits
    local sHealthMod = getTraitMod({ traits = sTraits }, 'healthMod')
    local sCarryMod = getTraitMod({ traits = sTraits }, 'carryMod')
    local sMaxHp = math.floor(100 * (1 + sHealthMod))
    local colData = {
        name = identity.name, gender = identity.gender,
        backstory = identity.backstory,
        disabledWork = identity.disabledWork,
        traits = sTraits, skills = randomSkills(sTraits),
        skillXp = {}, passions = {}, skillRust = {}, skillTimers = {},
        health = sMaxHp, maxHealth = sMaxHp, sanity = 100,
        age = math.random(20, 55),
        task = nil, state = 'idle',
        facing = math.random() * math.pi * 2,
    }
    generatePassions(colData)
    ECS.set(id, 'colonist', colData)

    -- MRP genetic unlocks: apply permanent campaign upgrades to each new colonist
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if mok then
        if MRP.hasUnlock('cold_adapted_genome') then
            colData.hypothermiaResist = (colData.hypothermiaResist or 0) + 1
        end
        if MRP.hasUnlock('enhanced_metabolism') then
            colData.hungerRate = (colData.hungerRate or 1.0) * 0.85
        end
        if MRP.hasUnlock('neural_plasticity') then
            colData.learnRate = (colData.learnRate or 1.0) * 1.20
        end
        if MRP.hasUnlock('stress_inoculation') then
            colData.breakThreshold = (colData.breakThreshold or 20) - 5
        end
    end

    ECS.set(id, 'needs', {
        warmth = 60, food = 60, water = 60, rest = 60, morale = 50, joy = 40,
        heatExposure = 0, radiation = 0, toxicity = 0,
    })
    ECS.set(id, 'inventory', { items = {}, maxWeight = math.floor(50 * (1 + sCarryMod)), currentWeight = 0 })
    ECS.set(id, 'path', { nodes = nil, index = 1, moveTimer = 0 })
    ECS.set(id, 'schedule', Schedule.default())
    ECS.set(id, 'workPriority', Jobs.defaultPriorities())

    -- Phase 5: body parts and equipment slots
    Colonist._attachCombatComponents(id)

    return id
end

-- Attach body and equipment components (safe to call before or after combat modules load)
function Colonist._attachCombatComponents(id)
    local bok, BodyMod = pcall(require, 'src.combat.body')
    if bok then BodyMod.attach(id) end
    local eok, EquipMod = pcall(require, 'src.colonist.equipment')
    if eok then EquipMod.attach(id) end
    local cok, ClothingMod = pcall(require, 'src.colonist.clothing')
    if cok then ClothingMod.attach(id) end
end

---------------------------------------------------------------------------
-- Starting loadout
---------------------------------------------------------------------------
-- The crew used to land with an empty equipment component and five empty
-- clothing slots: no weapon, no armour, no cold gear. That made the opening
-- hours unwinnable rather than hard. An unarmed colonist is forced to flee by
-- combat_ai, and every predator that dens near the landing site outruns a
-- colonist's 3.0 tiles/s (ice stalker 3.5, sabertooth and stalker 5.0), so the
-- only available option was a footrace they always lost while being bitten for
-- 18-28 damage a second.
--
-- Every drop-pod scenario already advertises "a standard loadout" in its own
-- description, so this is that loadout and nothing more: one tier-0/1 hand
-- weapon each, a bow for one crew member once there are three of them, and a
-- coat plus boots. It is deliberately weak gear — 6-10 damage melee against
-- 80-120 HP animals — so surviving day one still needs the crew to group up,
-- and it does nothing at all for the mid/late-game threats.

local STARTING_MELEE  = { 'knife', 'hatchet', 'club' }
local STARTING_RANGED = 'shortbow'   -- no ammo item required by ranged.lua

-- Outer + feet only. A full head/hands kit would push cold resistance past 60%
-- and hollow out the freezing game that the rest of the sim is built around.
local COLD_KIT = { 'parka', 'boots' }
local WARM_KIT = { 'cooling_vest', 'boots' }

--- Give one colonist their starting weapon and clothing.
--- @param id     number  colonist entity id
--- @param index  number  1-based position in the crew (varies the weapon)
--- @param crew   number  total crew size
--- @param cold   boolean landing site is freezing (parka) or not (cooling vest)
function Colonist.equipStartingGear(id, index, crew, cold)
    local eok, EquipMod = pcall(require, 'src.colonist.equipment')
    if eok then
        -- One crew member in three carries the bow: enough to soften an
        -- approaching animal, not enough to make melee gear irrelevant.
        local wanted = STARTING_MELEE[((index - 1) % #STARTING_MELEE) + 1]
        if crew >= 3 and index == crew then wanted = STARTING_RANGED end
        if not EquipMod.equipWeapon(id, wanted) then
            EquipMod.equipWeapon(id, 'knife')  -- two-handed refusal fallback
        end
    end

    local cok, ClothingMod = pcall(require, 'src.colonist.clothing')
    if cok then
        for _, itemId in ipairs(cold and COLD_KIT or WARM_KIT) do
            ClothingMod.equip(id, itemId, 'normal')
        end
    end
end

--- Kit out every colonist that has no weapon yet. Called once at worldgen,
--- after the crew is spawned. Scenarios opt out with `startingGear = false`
--- (Abandoned/naked-brutality starts are supposed to have nothing).
function Colonist.applyStartingLoadout(scenDef)
    if scenDef and scenDef.startingGear == false then return end

    -- Cold or hot landing site decides the coat. Read the actual tile so this
    -- stays correct on desert/temperate planets as well as Erebus.
    local cold = true
    local wok, World = pcall(require, 'src.world.tilemap')
    if wok and World.getTemp then
        local t = World.getTemp(GameState.startX, GameState.startY, 0)
        if t and t > 5 then cold = false end
    end

    local crew = {}
    for id, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' then crew[#crew + 1] = id end
    end
    table.sort(crew)  -- stable order so a pinned seed produces the same kit

    for i, id in ipairs(crew) do
        local equip = ECS.get(id, 'equipment')
        if not equip or not equip.weapon then
            Colonist.equipStartingGear(id, i, #crew, cold)
        end
    end
    return #crew
end

---------------------------------------------------------------------------
-- Systems (registered with ECS)
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Hypothermia stages (progressive cold damage, replaces binary death)
---------------------------------------------------------------------------

local HYPOTHERMIA = {
    { name = 'normal',     minWarmth = 60,  workMult = 1.0,  moveMult = 1.0, healthDrain = 0,   morale = 0 },
    { name = 'chilled',    minWarmth = 40,  workMult = 0.9,  moveMult = 1.0, healthDrain = 0,   morale = -1 },
    { name = 'cold',       minWarmth = 20,  workMult = 0.7,  moveMult = 0.9, healthDrain = 0,   morale = -3 },
    { name = 'hypothermic',minWarmth = 10,  workMult = 0.5,  moveMult = 0.7, healthDrain = 0.25, morale = -6 },
    { name = 'severe',     minWarmth = 0,   workMult = 0.2,  moveMult = 0.5, healthDrain = 1,   morale = -10 },
}

local function getHypothermiaTier(warmth)
    for _, tier in ipairs(HYPOTHERMIA) do
        if warmth >= tier.minWarmth then
            return tier
        end
    end
    return HYPOTHERMIA[#HYPOTHERMIA]
end

Colonist.getHypothermiaTier = getHypothermiaTier
Colonist.HYPOTHERMIA = HYPOTHERMIA

---------------------------------------------------------------------------
-- Heatstroke stages (high-temperature exposure)
---------------------------------------------------------------------------

local HEATSTROKE = {
    { name = 'normal',      maxHeat = 40,  workMult = 1.0, moveMult = 1.0, healthDrain = 0,   morale = 0 },
    { name = 'warm',        maxHeat = 60,  workMult = 0.9, moveMult = 1.0, healthDrain = 0,   morale = -1 },
    { name = 'overheated',  maxHeat = 75,  workMult = 0.7, moveMult = 0.9, healthDrain = 0,   morale = -3 },
    { name = 'heat_stroke', maxHeat = 90,  workMult = 0.5, moveMult = 0.7, healthDrain = 0.5, morale = -6 },
    { name = 'severe_heat', maxHeat = 999, workMult = 0.2, moveMult = 0.5, healthDrain = 2,   morale = -10 },
}

local function getHeatstrokeTier(heatLevel)
    for _, tier in ipairs(HEATSTROKE) do
        if heatLevel < tier.maxHeat then return tier end
    end
    return HEATSTROKE[#HEATSTROKE]
end

---------------------------------------------------------------------------
-- Radiation sickness stages
---------------------------------------------------------------------------

local RADIATION_SICKNESS = {
    { name = 'normal',        maxRad = 10,  workMult = 1.0, moveMult = 1.0, healthDrain = 0,   morale = 0 },
    { name = 'mild_exposure', maxRad = 30,  workMult = 0.9, moveMult = 1.0, healthDrain = 0,   morale = -1 },
    { name = 'rad_sickness',  maxRad = 50,  workMult = 0.7, moveMult = 0.8, healthDrain = 0.3, morale = -4 },
    { name = 'acute_rad',     maxRad = 75,  workMult = 0.4, moveMult = 0.6, healthDrain = 1.0, morale = -8 },
    { name = 'lethal_rad',    maxRad = 999, workMult = 0.1, moveMult = 0.3, healthDrain = 3.0, morale = -15 },
}

local function getRadiationTier(radLevel)
    for _, tier in ipairs(RADIATION_SICKNESS) do
        if radLevel < tier.maxRad then return tier end
    end
    return RADIATION_SICKNESS[#RADIATION_SICKNESS]
end

---------------------------------------------------------------------------
-- Toxic exposure stages
---------------------------------------------------------------------------

local TOXIC_EXPOSURE = {
    { name = 'normal',      maxTox = 10,  workMult = 1.0, moveMult = 1.0, healthDrain = 0,   morale = 0 },
    { name = 'irritation',  maxTox = 30,  workMult = 0.9, moveMult = 1.0, healthDrain = 0,   morale = -2 },
    { name = 'poisoned',    maxTox = 50,  workMult = 0.6, moveMult = 0.8, healthDrain = 0.5, morale = -5 },
    { name = 'toxic_shock', maxTox = 999, workMult = 0.3, moveMult = 0.5, healthDrain = 2.0, morale = -10 },
}

local function getToxicTier(toxLevel)
    for _, tier in ipairs(TOXIC_EXPOSURE) do
        if toxLevel < tier.maxTox then return tier end
    end
    return TOXIC_EXPOSURE[#TOXIC_EXPOSURE]
end

Colonist.HEATSTROKE          = HEATSTROKE
Colonist.RADIATION_SICKNESS  = RADIATION_SICKNESS
Colonist.TOXIC_EXPOSURE      = TOXIC_EXPOSURE
Colonist.getHeatstrokeTier   = getHeatstrokeTier
Colonist.getRadiationTier    = getRadiationTier
Colonist.getToxicTier        = getToxicTier

-- Needs decay system — runs each sim tick
local function needsDecaySystem(dt, id, comps)
    local needs = comps.needs
    local pos   = comps.pos
    local col   = comps.colonist

    -- Dead colonists don't tick — entity destroyed on death, corpse is an item
    if col.state == 'dead' then
        return
    end

    local World = require('src.world.tilemap')

    -- Trait modifiers
    local coldResist = getTraitMod(col, 'coldResist')
    local foodMod    = getTraitMod(col, 'foodMod')
    local moraleMod  = getTraitMod(col, 'moraleMod')
    local restMod    = getTraitMod(col, 'restMod')

    -- Debug panel flags
    lazyLoadNeeds()
    local _debugNoNeeds = _DebugPanel and _DebugPanel.noNeeds
    local _debugGodMode = _DebugPanel and _DebugPanel.godMode
    local _debugNoCold  = _DebugPanel and _DebugPanel.noColdDamage

    -- Arctic exoframe exclusive reward: +20% cold resistance colony-wide
    if GameState.exclusiveBuffs and GameState.exclusiveBuffs.arctic_exoframe then
        coldResist = coldResist + 0.20
    end

    -- Get clothing protection for all hazard types
    local cok, ClothingMod = pcall(require, 'src.colonist.clothing')
    local protection = cok and ClothingMod.getProtection(id) or {}
    local coldProt  = protection.cold     or 0
    local heatProt  = protection.heat     or 0
    local radProt   = protection.radiation or 0
    local toxProt   = protection.toxicity  or 0

    -- Warmth: decays based on tile temperature, reduced by cold resistance + clothing
    local posDepth = pos.depth or 0
    local tileTemp = World.getTemp(pos.x, pos.y, posDepth)
    if tileTemp < 10 and not _debugNoCold then
        -- Combine trait/suit cold resistance with clothing cold protection (0-100 -> 0-1)
        local totalColdResist = (coldResist or 0) + (coldProt / 100)
        totalColdResist = math.min(totalColdResist, 0.95)  -- cap at 95%
        local coldRate = (10 - tileTemp) * 0.005 * (1 - totalColdResist) * dt
        needs.warmth = math.max(0, needs.warmth - coldRate)
    elseif tileTemp > 10 then
        needs.warmth = math.min(100, needs.warmth + 2.0 * dt)
    end

    -- Hypothermia stage (progressive cold effects)
    local hypoTier = getHypothermiaTier(needs.warmth)
    col._hypothermia = hypoTier.name
    col._hypoWorkMult = hypoTier.workMult
    col._hypoMoveMult = hypoTier.moveMult

    -- Heatstroke (activates when tileTemp > 30; dormant on frozen Erebus)
    if needs.heatExposure == nil then needs.heatExposure = 0 end  -- backwards compat
    if tileTemp > 30 then
        local heatDemand  = (tileTemp - 30) * 1.5
        local heatDeficit = math.max(0, heatDemand - heatProt)
        needs.heatExposure = math.min(100, needs.heatExposure + heatDeficit * 0.01 * dt)
    else
        needs.heatExposure = math.max(0, needs.heatExposure - 0.5 * dt)
    end
    local heatTier = getHeatstrokeTier(needs.heatExposure)
    if heatTier.healthDrain > 0 and not _debugGodMode then
        col.health = col.health - heatTier.healthDrain * dt
    end
    col._heatstroke = heatTier.name

    -- Radiation sickness (activates via environmental triggers; dormant on Erebus)
    if needs.radiation == nil then needs.radiation = 0 end  -- backwards compat
    local radTier = getRadiationTier(needs.radiation)
    if radTier.healthDrain > 0 and not _debugGodMode then
        col.health = col.health - radTier.healthDrain * dt
    end
    col._radiationSickness = radTier.name

    -- Toxic exposure (activates during acid storms / toxic events; dormant on Erebus)
    if needs.toxicity == nil then needs.toxicity = 0 end  -- backwards compat
    local toxTier = getToxicTier(needs.toxicity)
    if toxTier.healthDrain > 0 and not _debugGodMode then
        col.health = col.health - toxTier.healthDrain * dt
    end
    col._toxicExposure = toxTier.name

    -- Room comfort: colonist's current room affects morale and rest
    local roomMorale = 0
    local roomRestMult = 1.0
    if _RoomsMod then
        local roomId = World.getRoom(pos.x, pos.y, posDepth)
        if roomId and roomId > 0 then
            roomMorale = _RoomsMod.getRoomMorale(roomId)
            roomRestMult = _RoomsMod.getRoomRestMult(roomId)
        end
    end

    -- Food: drain modified by glutton/iron_stomach traits + rationing policy + laws
    local foodPolicyMult = (_Policies and _Policies.getFoodDrainMult()) or 1.0
    local foodLawMult = (_Laws and _Laws.getFoodDrainMult()) or 1.0
    if not _debugNoNeeds then
        local foodDrain = 0.03 * (1 + foodMod) * foodPolicyMult * foodLawMult
        needs.food = math.max(0, needs.food - foodDrain * dt)
    end

    -- Water: drains slightly faster than food (dehydration is quicker than starvation)
    if needs.water == nil then needs.water = 80 end  -- backwards compat for old saves
    if not _debugNoNeeds then
        local waterDrain = 0.04 * foodPolicyMult * foodLawMult  -- rationing affects water too
        needs.water = math.max(0, needs.water - waterDrain * dt)
    end

    -- Rest: drains when awake, recovers when sleeping
    if col.state == 'sleeping' then
        -- Rest recovery boosted by warm rooms; works day or night
        local recoveryRate = 0.1 * roomRestMult
        if not GameState.isDaytime() then recoveryRate = recoveryRate + 0.05 end  -- night bonus
        needs.rest = math.min(100, needs.rest + recoveryRate * dt)
    elseif not _debugNoNeeds then
        -- Only drain rest during daytime (active hours)
        if GameState.isDaytime() then
            local restDrain = 0.02 * (1 + restMod)
            restDrain = math.max(0.005, restDrain)
            needs.rest = math.max(0, needs.rest - restDrain * dt)
        end
    end

    -- Morale: base comfort + trait modifier + policy + room comfort + hypothermia + joy
    local joyVal = needs.joy or 50
    local comfortScore = (needs.warmth + needs.food + (needs.water or 80) + needs.rest) / 4
    local moraleDelta = (comfortScore - 50) * 0.005 * dt
    moraleDelta = moraleDelta + moraleMod * 0.01 * dt
    moraleDelta = moraleDelta + roomMorale * 0.01 * dt
    moraleDelta = moraleDelta + hypoTier.morale * 0.01 * dt
    -- Joy contribution: penalty when low, small bonus when high
    if joyVal < 20 then
        moraleDelta = moraleDelta + (joyVal - 20) * 0.003 * dt
    elseif joyVal > 70 then
        moraleDelta = moraleDelta + (joyVal - 70) * 0.001 * dt
    end
    -- Policy morale drain (extended_shifts, rationing, etc.)
    local policyMoraleDrain = _Policies and _Policies.getMoraleDrainAdd() or 0
    if policyMoraleDrain > 0 then
        moraleDelta = moraleDelta - policyMoraleDrain * 0.01 * dt
    end
    -- Laws morale drain multiplier
    local lawMoraleMult = (_Laws and _Laws.getMoraleDrainMult()) or 1.0
    if lawMoraleMult > 1.0 and moraleDelta < 0 then
        moraleDelta = moraleDelta * lawMoraleMult
    end
    needs.morale = math.max(0, math.min(100, needs.morale + moraleDelta))
    -- Laws morale lock: clamp morale to locked value
    if _Laws then
        local moraleLock = _Laws.getMoraleLock()
        if moraleLock then
            needs.morale = math.max(needs.morale, moraleLock)
        end
        local hopeFloor = _Laws.getHopeFloor()
        if hopeFloor and _HopeMod and _HopeMod.getHope() < hopeFloor then
            _HopeMod.setHopeFloor(hopeFloor)
        end
    end

    -- Suffocation: O2-based effects at colonist's tile
    if _Atmosphere then
        local o2 = _Atmosphere.getTileO2(pos.x, pos.y, posDepth)

        -- Clothing outer slot with O2 supply protects against suffocation.
        -- Check both legacy suit component and new clothing system.
        local clothComp = ECS.get(id, 'clothing')
        local suitProtects = false
        if clothComp and clothComp.outer then
            local o2rem = clothComp.outer._o2Remaining or 0
            local o2max = clothComp.outer.o2MaxTank or 0
            if o2max > 0 and o2rem > 0 then
                suitProtects = true
            end
        end
        -- Legacy fallback for old saves
        if not suitProtects then
            local suitComp = ECS.get(id, 'suit')
            if suitComp and suitComp.o2Capacity and (suitComp.o2Remaining or 0) > 0 then
                suitProtects = true
            end
        end

        if suitProtects then
            -- Suit is handling O2 — no atmospheric suffocation damage
            col._suffocating = 0
            col._o2WorkDebuff = 1.0
        elseif o2 <= 0 then
            -- Vacuum exposure without suit: rapid death (2.0 HP/sec)
            -- This is faster than suit-tank-empty damage (0.5 HP/sec in suits.lua)
            if not _debugGodMode then col.health = col.health - 2.0 * dt end
            col._suffocating = 3  -- critical
        elseif o2 < 30 then
            if not _debugGodMode then col.health = col.health - 1 * dt end
            col._suffocating = 2  -- suffocating
        elseif o2 < 60 then
            col._suffocating = 1  -- low O2
        else
            col._suffocating = 0
        end
        if not suitProtects then
            if o2 < 60 then
                col._o2WorkDebuff = 0.7
            else
                col._o2WorkDebuff = 1.0
            end
        end
    end

    -- Disease work speed debuff
    if _Disease and _Disease.getWorkSpeedMult then
        col._diseaseWorkMult = _Disease.getWorkSpeedMult(id)
    else
        col._diseaseWorkMult = 1.0
    end

    -- Lighting morale penalty
    if _Lighting then
        local moralePenalty = _Lighting.getMoralePenalty(pos.x, pos.y)
        if moralePenalty < 0 then
            needs.morale = math.max(0, needs.morale + moralePenalty * 0.01 * dt)
        end
    end

    -- Hypothermia health drain (progressive, replaces binary warmth<=0 death)
    if hypoTier.healthDrain > 0 and not _debugNoCold and not _debugGodMode then
        col.health = col.health - hypoTier.healthDrain * dt
    end
    if needs.food <= 0 and not _debugGodMode then
        col.health = col.health - 0.5 * dt
    end
    if (needs.water or 80) <= 0 and not _debugGodMode then
        col.health = col.health - 0.7 * dt  -- dehydration kills faster than starvation
    end

    -- Sanity drain from low morale
    if needs.morale < 20 then
        col.sanity = math.max(0, col.sanity - 0.1 * dt)
    elseif needs.morale > 60 then
        col.sanity = math.min(100, col.sanity + 0.05 * dt)
    end

    -- Mental break at sanity threshold (trait breakThreshold shifts the trigger point)
    local breakThreshold = getTraitMod(col, 'breakThreshold')
    if col.sanity <= breakThreshold and col.state ~= 'mental_break' then
        local blocked = false
        if _Policies and _Policies.isMentalBreakBlocked() then blocked = true end
        if _Laws and _Laws.isMentalBreakBlocked() then blocked = true end
        if not blocked then
            -- Release current task before entering mental break
            local jok, LoadedJobs = pcall(require, 'src.colonist.jobs')
            if jok and col.task and LoadedJobs.unclaimTask then
                LoadedJobs.unclaimTask(col.task.taskId)
            end
            col.task = nil
            col.state = 'mental_break'
            -- Notify via storyteller toast
            local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if stOk and Storyteller.logEvent then
                Storyteller.logEvent('mental_break',
                    (col.name or 'A colonist') .. ' is having a mental break!')
            end
            -- Auto-pause on mental break
            if GameState.autoPause and GameState.autoPause.onMentalBreak then
                GameState.paused = true
            end
        end
    end

    -- Passive health recovery: while sleeping, or whenever all core needs
    -- are in good shape. Without this, health lost to cold/hunger was
    -- never regained (only hot springs healed) and colonists ratcheted
    -- toward death across successive cold snaps.
    -- Gating on "all needs > 50" meant regen never fired during the crisis it
    -- was added for: a colonist warming up at a fire at warmth 35 healed
    -- nothing, so the player saw HP fall and never recover. Regen now runs
    -- whenever the colonist is NOT actively freezing, starving or dehydrated —
    -- i.e. whenever the situation is being brought under control.
    if col.health > 0 and col.health < col.maxHealth then
        local freezing  = hypoTier.healthDrain > 0        -- warmth < 20
        local starving  = needs.food <= 0
        local dehydrated = (needs.water or 80) <= 0
        local warmingUp = tileTemp > 10                   -- gaining warmth
        if not (freezing or starving or dehydrated) then
            local rate
            if col.state == 'sleeping' then
                rate = 0.5
            elseif needs.warmth > 50 and needs.food > 50
                and (needs.water or 80) > 50 and needs.rest > 50 then
                rate = 0.2   -- all needs comfortable
            elseif warmingUp or needs.warmth > 30 then
                rate = 0.15  -- recovering: visible progress during a crisis
            end
            if rate then
                col.health = math.min(col.maxHealth, col.health + rate * dt)
            end
        end
    end

    -- Net HP trend over the last full tick cycle (ALL damage/heal sources,
    -- including bleed, suffocation, deep-cold — not just the regen above).
    -- Drives the UI recovering/declining indicator truthfully.
    do
        local prevHp = col._hpPrevTick
        if prevHp then
            local delta = col.health - prevHp
            if delta > 0.0001 then
                col._regening = true
                col._declining = false
            elseif delta < -0.0001 then
                col._regening = false
                col._declining = true
            else
                col._regening = false
                col._declining = false
            end
        end
        col._hpPrevTick = col.health
    end

    -- Tick skill rust timers
    if _SkillsMod and _SkillsMod.tickRust then
        _SkillsMod.tickRust(id, dt)
    end

    -- Clamp health — never go negative
    col.health = math.max(0, col.health)

    -- Death: use shared kill function (spawns corpse, notifies systems, destroys entity)
    if col.health <= 0 and col.state ~= 'dead' then
        Colonist.kill(id)
        return
    end

end

-- Movement system — follows pathfinding nodes
local BASE_MOVE_SPEED = 3  -- tiles per second

--- Intrinsic movement speed in tiles/second: traits, limb damage, armour
--- penalty, hypothermia and status effects. Deliberately excludes terrain and
--- carry weight, which depend on the exact tile the colonist stands on.
--- combat_ai uses this to decide whether fleeing an animal is even possible.
function Colonist.getMoveSpeed(id, col)
    col = col or ECS.get(id, 'colonist')
    if not col then return BASE_MOVE_SPEED end

    local speed = BASE_MOVE_SPEED * (1 + getTraitMod(col, 'speedMod'))
    lazyLoadMovement()
    if _BodyMod then speed = speed * _BodyMod.getMoveSpeedMultiplier(id) end
    if _EquipMod then speed = speed * (1 - _EquipMod.getSpeedPenalty(id)) end
    if col._hypoMoveMult then speed = speed * col._hypoMoveMult end
    if _StatusFx then speed = speed * _StatusFx.getMoveSpeedMult(id) end
    return speed
end

local function movementSystem(dt, id, comps)
    local pos  = comps.pos
    local path = comps.path
    local col  = comps.colonist

    if col.state == 'dead' or col.state == 'mental_break' then return end

    -- Store previous position for interpolation
    pos.prevX = pos.x
    pos.prevY = pos.y

    if not path.nodes or path.index > #path.nodes then
        return
    end

    -- Traits, limb damage, armour penalty, hypothermia and status effects
    lazyLoadMovement()
    local speed = Colonist.getMoveSpeed(id, col)
    local posDepth = pos.depth or 0
    do
        local envMult = 1.0
        if _TileSnowMod and _TileSnowMod.getMovementMult then
            envMult = envMult * _TileSnowMod.getMovementMult(pos.x, pos.y, posDepth)
        end
        if _TileFluidsMod and _TileFluidsMod.getMovementMult then
            envMult = envMult * _TileFluidsMod.getMovementMult(pos.x, pos.y, posDepth)
        end
        -- Deep snow/water on the CURRENT tile slows escape but must never
        -- pin a colonist in place: a 0x multiplier permanently trapped
        -- (and killed) anyone whose tile snowed in beneath them.
        speed = speed * math.max(0.15, envMult)
    end
    if _TileGasMod then
        if _TileGasMod.isToxic and _TileGasMod.isToxic(pos.x, pos.y, posDepth) then
            speed = speed * 0.75
        elseif _TileGasMod.isBreathable and not _TileGasMod.isBreathable(pos.x, pos.y, posDepth) then
            speed = speed * 0.9
        end
    end

    -- Carry weight penalty: up to 30% slower at max weight
    local invComp = comps.inventory
    if invComp and invComp.maxWeight and invComp.maxWeight > 0 and (invComp.currentWeight or 0) > 0 then
        local ratio = invComp.currentWeight / invComp.maxWeight
        speed = speed * (1 - 0.3 * ratio)
    end

    path.moveTimer = path.moveTimer + dt * speed
    while path.moveTimer >= 1 and path.index <= #path.nodes do
        local node = path.nodes[path.index]
        local nodeDepth = node.depth or 0
        -- Block step if tile is occupied by another entity
        if Occupancy.isOccupiedBy(node.x, node.y, id, nodeDepth) then
            -- Next tile occupied: wait up to 3 ticks for it to clear, then
            -- re-path around the blocker. (Previously the whole path was
            -- dropped immediately, so colonists crossing each other
            -- constantly abandoned their tasks.)
            path.blockedTicks = (path.blockedTicks or 0) + 1
            if path.blockedTicks <= 3 then
                path.moveTimer = 1  -- ready to step the moment it clears
                return
            end
            path.blockedTicks = 0
            path.stuckCycles = (path.stuckCycles or 0) + 1
            if path.stuckCycles < 4 then
                local dest = path.nodes[#path.nodes]
                local WorldMod = require('src.world.tilemap')
                local route = Pathfind.find(pos.x, pos.y, dest.x, dest.y,
                    WorldMod, id, pos.depth or 0, dest.depth or (pos.depth or 0))
                if route then
                    path.nodes = route
                    path.index = 1
                    path.moveTimer = 1  -- attempt the first step immediately
                else
                    -- No way around — drop the path (work AI applies backoff)
                    path.nodes = nil
                    path.index = 1
                    path.moveTimer = 0
                    path.stuckCycles = nil
                end
                return
            end
            -- A persistent blocker should release this path back to the work
            -- AI. Never overlap entities: Occupancy stores one entity per tile,
            -- so "squeezing past" would corrupt reservations for both.
            path.stuckCycles = nil
            path.nodes = nil
            path.index = 1
            path.moveTimer = 0
            return
        else
            path.blockedTicks = nil
            path.stuckCycles = nil
        end
        path.moveTimer = path.moveTimer - 1
        -- Release old tile, claim new one
        Occupancy.release(pos.x, pos.y, id, pos.depth)
        -- Update facing from movement direction
        local dx = node.x - pos.x
        local dy = node.y - pos.y
        if dx ~= 0 or dy ~= 0 then
            col.facing = math.atan2(dy, dx)
        end
        pos.x = node.x
        pos.y = node.y
        pos.depth = nodeDepth
        Occupancy.reserve(pos.x, pos.y, id, pos.depth)
        -- Track dirt/blood on the tile
        if _FilthMod then _FilthMod.onColonistStep(pos.x, pos.y, id) end
        path.index = path.index + 1
    end

    if path.nodes and path.index > #path.nodes then
        path.nodes = nil
        path.index = 1
    end
end

---------------------------------------------------------------------------
-- Register all colonist systems with ECS
---------------------------------------------------------------------------

function Colonist.registerSystems()
    ECS.addSystem('colonist_needs', { 'colonist', 'needs', 'pos' }, needsDecaySystem, 10)
    ECS.addSystem('colonist_move',  { 'pos', 'path', 'colonist', 'inventory' }, movementSystem, 20)
end

-- Auto-register on require
Colonist.registerSystems()

return Colonist
