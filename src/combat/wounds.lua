-- wounds.lua -- Wound and medical treatment system
-- Wound types: cut (bleeds), burn (pain+infection risk), frostbite (progressive cold),
-- fracture (immobilizes part).
-- Treatment stages: untreated -> bandaged -> medicated -> healed.
-- Medical task: colonist with medical skill tends wounds via jobs system.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Jobs      = require('src.colonist.jobs')
local Body      = require('src.combat.body')

local Wounds = {}

-- Lazy-loaded modules (avoid pcall in hot-path wound treatment system)
local _AddictionMod
local function lazyLoadWounds()
    if _AddictionMod ~= nil then return end
    local ok
    ok, _AddictionMod = pcall(require, 'src.colonist.addiction')
    if not ok then _AddictionMod = false end
end

---------------------------------------------------------------------------
-- Wound type definitions
---------------------------------------------------------------------------

local WOUND_TYPES = {
    cut = {
        name        = 'Cut',
        bleedRate   = 0.5,   -- HP/tick while untreated
        painFactor  = 0.3,
        infectionChance = 0.05,
    },
    burn = {
        name        = 'Burn',
        bleedRate   = 0,
        painFactor  = 0.6,
        infectionChance = 0.15,
    },
    frostbite = {
        name        = 'Frostbite',
        bleedRate   = 0,
        painFactor  = 0.4,
        infectionChance = 0.1,
        progressive = true, -- worsens while warmth need stays low
    },
    fracture = {
        name        = 'Fracture',
        bleedRate   = 0,
        painFactor  = 0.8,
        infectionChance = 0.02,
        immobilizes = true,
    },
}

Wounds.TYPES = WOUND_TYPES

-- Treatment stages, in order of progression
local TREATMENT_STAGES = { 'untreated', 'bandaged', 'medicated', 'healed' }
local STAGE_INDEX = {}
for i, s in ipairs(TREATMENT_STAGES) do STAGE_INDEX[s] = i end

---------------------------------------------------------------------------
-- Apply a wound to an entity's body part
---------------------------------------------------------------------------

function Wounds.apply(entityId, partName, woundType, severity)
    local wounds = ECS.get(entityId, 'wounds')
    if not wounds then
        wounds = { list = {} }
        ECS.set(entityId, 'wounds', wounds)
    end

    local def = WOUND_TYPES[woundType]
    if not def then return end

    severity = severity or 1.0

    wounds.list[#wounds.list + 1] = {
        part      = partName,
        type      = woundType,
        severity  = severity,       -- 0.0-1.0, scales bleed/pain
        treatment = 'untreated',
        infected  = false,
        healTimer = 0,
        age       = 0,             -- seconds since wound was inflicted
    }

    -- Also damage the body part HP
    local partDmg = math.floor(severity * 10)
    if partDmg > 0 then
        Body.damagePart(entityId, partName, partDmg)
    end
end

---------------------------------------------------------------------------
-- Treat a wound (advance treatment stage)
---------------------------------------------------------------------------

function Wounds.treat(wound, medicalSkill)
    local current = STAGE_INDEX[wound.treatment] or 1
    if current >= #TREATMENT_STAGES then return false end

    -- Higher medical skill = chance to skip a stage
    local advance = 1
    if medicalSkill >= 8 and current == 1 then
        -- Skilled doctor can go straight to medicated from untreated
        advance = 2
    end

    local nextIdx = math.min(current + advance, #TREATMENT_STAGES)
    wound.treatment = TREATMENT_STAGES[nextIdx]
    return true
end

---------------------------------------------------------------------------
-- Remove healed wounds from the list
---------------------------------------------------------------------------

local function pruneHealed(wounds)
    local i = 1
    while i <= #wounds.list do
        if wounds.list[i].treatment == 'healed' then
            table.remove(wounds.list, i)
        else
            i = i + 1
        end
    end
end

---------------------------------------------------------------------------
-- Get total pain level for an entity (0.0 - 1.0 scale)
---------------------------------------------------------------------------

function Wounds.getPain(entityId)
    local wounds = ECS.get(entityId, 'wounds')
    if not wounds then return 0 end

    local total = 0
    for _, w in ipairs(wounds.list) do
        if w.treatment ~= 'healed' then
            local def = WOUND_TYPES[w.type]
            if def then
                local factor = def.painFactor * w.severity
                -- Treatment reduces pain
                if w.treatment == 'bandaged' then factor = factor * 0.6 end
                if w.treatment == 'medicated' then factor = factor * 0.3 end
                total = total + factor
            end
        end
    end
    return math.min(1.0, total)
end

---------------------------------------------------------------------------
-- Check if entity has any untreated wounds (for medical task creation)
---------------------------------------------------------------------------

function Wounds.hasUntreatedWounds(entityId)
    local wounds = ECS.get(entityId, 'wounds')
    if not wounds then return false end

    for _, w in ipairs(wounds.list) do
        if w.treatment == 'untreated' or w.treatment == 'bandaged' then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Count wounds by treatment stage
---------------------------------------------------------------------------

function Wounds.count(entityId)
    local wounds = ECS.get(entityId, 'wounds')
    if not wounds then return 0 end
    local n = 0
    for _, w in ipairs(wounds.list) do
        if w.treatment ~= 'healed' then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Create a medical task for a wounded entity
---------------------------------------------------------------------------

function Wounds.requestMedicalTask(entityId)
    local pos = ECS.get(entityId, 'pos')
    if not pos then return nil end
    return Jobs.createTask('medical', pos.x, pos.y, { patientId = entityId })
end

---------------------------------------------------------------------------
-- ECS system: wound tick (bleed, infection, frostbite progression, healing)
---------------------------------------------------------------------------

local function woundTickSystem(dt, id, comps)
    local col    = comps.colonist
    local wounds = comps.wounds
    local needs  = comps.needs

    if col.state == 'dead' then return end
    if #wounds.list == 0 then return end

    local bleedTotal = 0

    for _, w in ipairs(wounds.list) do
        if w.treatment == 'healed' then goto continue end

        local def = WOUND_TYPES[w.type]
        if not def then goto continue end

        w.age = w.age + dt

        -- Bleeding (cuts only while untreated)
        if def.bleedRate > 0 and w.treatment == 'untreated' then
            bleedTotal = bleedTotal + def.bleedRate * w.severity * dt
        end

        -- Frostbite progression: worsens when warmth need is critically low
        if def.progressive and needs and needs.warmth < 10 then
            w.severity = math.min(1.0, w.severity + 0.01 * dt)
            -- Also damage the part further
            Body.damagePart(id, w.part, 0.2 * dt)
        end

        -- Infection roll (once per wound, checked after 30 seconds)
        if not w.infected and not w.infectionRolled and w.treatment == 'untreated' and w.age > 30 then
            w.infectionRolled = true
            if math.random() < def.infectionChance then
                w.infected = true
                -- Trigger infection status effect
                local sfxOk, StatusFx = pcall(require, 'src.sim.status_effects')
                if sfxOk and StatusFx.apply then StatusFx.apply(id, 'infection') end
            end
        end

        -- Infected wounds drain health slowly
        if w.infected and w.treatment ~= 'medicated' then
            local _wdpOk2, _WDP2 = pcall(require, 'src.ui.debug_panel')
            if not (_wdpOk2 and _WDP2.godMode) then
                col.health = col.health - 0.1 * w.severity * dt
            end
        end

        -- Natural healing progress (only if bandaged or medicated)
        if w.treatment == 'bandaged' then
            w.healTimer = w.healTimer + 0.3 * dt
        elseif w.treatment == 'medicated' then
            w.healTimer = w.healTimer + 1.0 * dt
            -- Medicated also clears infection
            w.infected = false
        end

        -- Heal threshold: medicated wounds heal after accumulating enough time
        if w.healTimer >= 30 then
            w.treatment = 'healed'
        end

        ::continue::
    end

    -- Apply bleed damage to colonist health
    local wdpOk, WDP = pcall(require, 'src.ui.debug_panel')
    if bleedTotal > 0 and not (wdpOk and WDP.godMode) then
        col.health = math.max(0, col.health - bleedTotal)
        if col.health <= 0 and col.state ~= 'dead' then
            local cOk, ColMod = pcall(require, 'src.colonist.colonist')
            if cOk then ColMod.kill(id) end
            return
        end
    end

    -- Pain affects morale (reduced by active painReducing drugs)
    local pain = Wounds.getPain(id)
    if pain > 0 and needs then
        local painMult = 1.0
        local addOk, AddictionMod = pcall(require, 'src.colonist.addiction')
        if addOk and AddictionMod.getPainReduceMult then
            painMult = AddictionMod.getPainReduceMult(id)
        end
        -- Masochist: pain gives morale instead of draining it
        local isMasochist = false
        if col.traits then
            for _, t in ipairs(col.traits) do
                if t.opinionMod == 'likes_pain' then isMasochist = true; break end
            end
        end
        if isMasochist then
            needs.morale = math.min(100, needs.morale + pain * painMult * 0.05 * dt)
        else
            needs.morale = math.max(0, needs.morale - pain * painMult * 0.1 * dt)
        end

        -- Trait painThreshold: wimp collapses at low pain (0.3 = 30% pain)
        if col.traits then
            for _, t in ipairs(col.traits) do
                if t.painThreshold and pain >= t.painThreshold then
                    -- Incapacitate: drop to 1 HP and trigger mental break state
                    if col.state ~= 'mental_break' and col.state ~= 'dead' then
                        col.health = math.max(1, col.health)
                        col.state = 'mental_break'
                        col._mentalBreak = {
                            type = 'pain_collapse',
                            timer = 30 + math.random(30),
                            maxTime = 60,
                            penalty = 10,
                        }
                    end
                    break
                end
            end
        end
    end

    -- Prune fully healed wounds
    pruneHealed(wounds)
end

---------------------------------------------------------------------------
-- ECS system: frostbite application (when warmth need stays critical)
---------------------------------------------------------------------------

-- Frostbite timers are now stored in needs component for persistence
-- local frostbiteTimers = {} -- DEPRECATED: moved to needs._frostbiteTimer

local function frostbiteCheckSystem(dt, id, comps)
    local needs = comps.needs
    local col   = comps.colonist

    if col.state == 'dead' then
        needs._frostbiteTimer = nil
        return
    end

    if needs.warmth < 10 then
        needs._frostbiteTimer = (needs._frostbiteTimer or 0) + dt
        -- Base: 5 minutes of critical cold before frostbite
        local frostbiteThreshold = 300
        -- Starting colony bonus: first hour of real-time, triple the threshold
        if GameState.colonyRealTime and GameState.colonyRealTime < 3600 then
            frostbiteThreshold = frostbiteThreshold * 3
        end
        lazyLoadWounds()
        if _AddictionMod and _AddictionMod.getColdResist then
            local resist = _AddictionMod.getColdResist(id)
            if resist > 0 then
                frostbiteThreshold = frostbiteThreshold * (1 + resist * 2)
            end
        end
        -- Cryo stabilizer exclusive reward: +50% frostbite threshold
        if GameState.exclusiveBuffs and GameState.exclusiveBuffs.cryo_stabilizer then
            frostbiteThreshold = frostbiteThreshold * 1.5
        end
        -- Apply frostbite after threshold seconds of critical cold
        if needs._frostbiteTimer >= frostbiteThreshold then
            needs._frostbiteTimer = 0
            -- Pick an extremity (hands/feet first)
            local extremities = { 'left_arm', 'right_arm', 'left_leg', 'right_leg' }
            local target = extremities[math.random(#extremities)]
            -- Only apply if part isn't already destroyed
            if not Body.isPartDestroyed(id, target) then
                Wounds.apply(id, target, 'frostbite', 0.3 + math.random() * 0.4)
            end
        end
    else
        needs._frostbiteTimer = nil
    end
end

---------------------------------------------------------------------------
-- ECS system: auto-create medical tasks for wounded colonists
---------------------------------------------------------------------------

local function medicalTaskSystem(dt, id, comps)
    -- Throttle: only check every 100 sim ticks (~5 seconds at 20Hz)
    if GameState.simTick % 100 ~= 0 then return end

    local col = comps.colonist
    if col.state == 'dead' then return end

    if Wounds.hasUntreatedWounds(id) then
        -- Check if there's already a medical task for this entity
        local pos = ECS.get(id, 'pos')
        if not pos then return end
        local allTasks = Jobs.getAllTasks()
        for _, task in pairs(allTasks) do
            if task.type == 'medical' and task.data.patientId == id then
                return -- already has a task
            end
        end
        Wounds.requestMedicalTask(id)
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Wounds.registerSystems()
    ECS.addSystem('wound_tick', { 'colonist', 'wounds', 'needs' }, woundTickSystem, 11)
    ECS.addSystem('frostbite_check', { 'colonist', 'needs' }, frostbiteCheckSystem, 12)
    ECS.addSystem('medical_task_check', { 'colonist', 'wounds' }, medicalTaskSystem, 50)
end

Wounds.registerSystems()

---------------------------------------------------------------------------
-- Cleanup: frostbite timers are now stored in needs component
-- This function is kept for API compatibility but is now a no-op
---------------------------------------------------------------------------

function Wounds.onEntityRemoved(entityId)
    -- Frostbite timers now stored in needs._frostbiteTimer
    -- They are cleaned up automatically when the entity is destroyed
end

return Wounds
