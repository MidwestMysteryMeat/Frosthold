-- skills.lua — Colonist skill progression with exponential XP curve
-- Ported from MMOLite's account-skills.js: floor(80 * n^1.7) per level.
-- Skills are 1-20 (extended from original 1-10 cap).
-- XP is earned by completing tasks, combat, crafting, etc.
-- Passion: 2 levels (interested 1.5x, passionate 2x XP).
-- Rust: unused skills get -20% effectiveness, clears after a few uses.

local ECS = require('src.ecs.ecs')

local Skills = {}

local MAX_LEVEL = 20
local RUST_THRESHOLD = 1200  -- sim seconds (~1 min real time) before a skill rusts
local RUST_CLEAR_USES = 3    -- successful uses to clear rust

-- XP required to reach level n (from level n-1)
-- Formula: floor(80 * n^1.7)
local XP_TABLE = {}
for n = 1, MAX_LEVEL + 1 do
    XP_TABLE[n] = math.floor(80 * n ^ 1.7)
end

Skills.XP_TABLE = XP_TABLE

-- XP awarded per task type
local TASK_XP = {
    mine     = { skill = 'mining',   xp = 15 },
    build    = { skill = 'building', xp = 20 },
    cook     = { skill = 'cooking',  xp = 12 },
    hunt     = { skill = 'hunting',  xp = 25 },
    research = { skill = 'research', xp = 18 },
    medical  = { skill = 'medical',  xp = 22 },
    harvest  = { skill = 'cooking',  xp = 10 },
    forage    = { skill = 'cooking',  xp = 8 },
    terraform = { skill = 'mining',   xp = 12 },
    revive    = { skill = 'medical',  xp = 15 },
}

Skills.TASK_XP = TASK_XP

---------------------------------------------------------------------------
-- Ensure colonist has skillXp table
---------------------------------------------------------------------------

local function ensureXp(col)
    if not col.skillXp then
        col.skillXp = {}
    end
    return col.skillXp
end

---------------------------------------------------------------------------
-- Get XP threshold for next level
---------------------------------------------------------------------------

function Skills.xpForLevel(level)
    if level >= MAX_LEVEL then return math.huge end
    return XP_TABLE[level + 1] or math.huge
end

---------------------------------------------------------------------------
-- Passion system
---------------------------------------------------------------------------

-- Passion levels: 0 = none, 1 = interested (1.5x XP), 2 = passionate (2x XP)
local PASSION_XP_MULT = { [0] = 1.0, [1] = 1.5, [2] = 2.0 }

Skills.PASSION_NONE       = 0
Skills.PASSION_INTERESTED = 1
Skills.PASSION_PASSIONATE = 2

--- Get passion level for a colonist's skill
function Skills.getPassion(entityId, skillName)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col.passions then return 0 end
    return col.passions[skillName] or 0
end

--- Set passion level for a colonist's skill
function Skills.setPassion(entityId, skillName, level)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    if not col.passions then col.passions = {} end
    col.passions[skillName] = math.max(0, math.min(2, level or 0))
end

--- Generate random passions for a new colonist (1-3 passions)
function Skills.generatePassions(col)
    if not col.passions then col.passions = {} end
    local allSkills = { 'mining', 'building', 'cooking', 'hunting', 'research', 'medical' }

    -- 1-2 interested, 0-1 passionate
    local passionCount = 1 + math.random(2) -- 2-3 total passions
    local shuffled = {}
    for _, s in ipairs(allSkills) do shuffled[#shuffled + 1] = s end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    for i = 1, math.min(passionCount, #shuffled) do
        if i == 1 and math.random() < 0.35 then
            col.passions[shuffled[i]] = 2 -- passionate
        else
            col.passions[shuffled[i]] = 1 -- interested
        end
    end
end

--- Get the XP multiplier from passion
function Skills.getPassionMult(entityId, skillName)
    local passion = Skills.getPassion(entityId, skillName)
    return PASSION_XP_MULT[passion] or 1.0
end

---------------------------------------------------------------------------
-- Skill rust system
---------------------------------------------------------------------------

--- Mark a skill as recently used (resets rust timer, clears rust)
function Skills.markUsed(entityId, skillName)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    if not col.skillTimers then col.skillTimers = {} end
    col.skillTimers[skillName] = 0

    -- Clear rust after enough uses
    if col.skillRust and col.skillRust[skillName] then
        if not col.rustUses then col.rustUses = {} end
        col.rustUses[skillName] = (col.rustUses[skillName] or 0) + 1
        if col.rustUses[skillName] >= RUST_CLEAR_USES then
            col.skillRust[skillName] = nil
            col.rustUses[skillName] = nil
        end
    end
end

--- Check if a skill is rusty
function Skills.isRusty(entityId, skillName)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col.skillRust then return false end
    return col.skillRust[skillName] == true
end

--- Get rust effectiveness penalty (1.0 = no penalty, 0.8 = rusty)
function Skills.getRustMult(entityId, skillName)
    if Skills.isRusty(entityId, skillName) then return 0.80 end
    return 1.0
end

--- Tick rust timers (call from ECS system or step)
function Skills.tickRust(entityId, dt)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col.skills then return end
    if col.state == 'dead' then return end
    if not col.skillTimers then col.skillTimers = {} end
    if not col.skillRust then col.skillRust = {} end

    for skillName in pairs(col.skills) do
        col.skillTimers[skillName] = (col.skillTimers[skillName] or 0) + dt
        if col.skillTimers[skillName] >= RUST_THRESHOLD and not col.skillRust[skillName] then
            col.skillRust[skillName] = true
        end
    end
end

---------------------------------------------------------------------------
-- Award XP to a colonist's skill, returns true if leveled up
---------------------------------------------------------------------------

function Skills.addXp(entityId, skillName, amount)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col.skills then return false end

    local currentLevel = col.skills[skillName] or 1
    if currentLevel >= MAX_LEVEL then return false end

    -- Apply passion multiplier
    local passionMult = Skills.getPassionMult(entityId, skillName)
    amount = math.floor(amount * passionMult + 0.5)

    -- Apply trait xpMod (fast_learner +15%, slow_learner -15%)
    if col.traits then
        local xpMod = 0
        for _, t in ipairs(col.traits) do
            if t.xpMod then xpMod = xpMod + t.xpMod end
        end
        if xpMod ~= 0 then
            amount = math.max(1, math.floor(amount * (1 + xpMod) + 0.5))
        end
    end

    local xp = ensureXp(col)
    xp[skillName] = (xp[skillName] or 0) + amount

    -- Mark skill as used (resets rust timer)
    Skills.markUsed(entityId, skillName)

    local threshold = Skills.xpForLevel(currentLevel)
    if xp[skillName] >= threshold then
        xp[skillName] = xp[skillName] - threshold
        col.skills[skillName] = currentLevel + 1
        return true
    end

    return false
end

---------------------------------------------------------------------------
-- Award XP for completing a task
---------------------------------------------------------------------------

function Skills.onTaskComplete(entityId, taskType)
    local entry = TASK_XP[taskType]
    if not entry then return false end

    local col = ECS.get(entityId, 'colonist')
    if not col then return false end

    -- Scale XP by current skill level (diminishing returns for easy tasks)
    local skillLevel = col.skills and col.skills[entry.skill] or 1
    local scaledXp = math.max(1, math.floor(entry.xp * (1 + skillLevel * 0.05)))

    return Skills.addXp(entityId, entry.skill, scaledXp)
end

---------------------------------------------------------------------------
-- Award combat XP (hunting skill)
---------------------------------------------------------------------------

function Skills.onCombatHit(entityId, damage)
    local xpGain = math.max(1, math.floor(damage * 0.5))
    Skills.addXp(entityId, 'hunting', xpGain)
end

---------------------------------------------------------------------------
-- Query: progress toward next level (0.0 to 1.0)
---------------------------------------------------------------------------

function Skills.getProgress(entityId, skillName)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col.skills then return 0 end

    local level = col.skills[skillName] or 1
    if level >= MAX_LEVEL then return 1.0 end

    local xp = ensureXp(col)
    local current = xp[skillName] or 0
    local threshold = Skills.xpForLevel(level)
    if threshold <= 0 then return 1.0 end

    return math.min(1.0, current / threshold)
end

---------------------------------------------------------------------------
-- Mastery specializations — unlocked at skill level 10+
-- Each skill has 2-3 branches. Colonists pick one per skill.
---------------------------------------------------------------------------

local MASTERIES = {
    mining = {
        { id = 'deep_miner',     name = 'Deep Miner',     level = 10, desc = 'Bonus ore from deep mining',   effect = { bonusOre = 1 } },
        { id = 'demolisher',     name = 'Demolisher',      level = 10, desc = 'Faster wall destruction',      effect = { mineMult = 1.3 } },
        { id = 'geologist',      name = 'Geologist',       level = 15, desc = 'Can expose thermal seams while mining below the surface', effect = { coreChance = 0.1 } },
    },
    building = {
        { id = 'architect',      name = 'Architect',       level = 10, desc = 'Buildings cost less material',  effect = { costMult = 0.85 } },
        { id = 'speed_builder',  name = 'Speed Builder',   level = 10, desc = 'Builds 30% faster',            effect = { buildMult = 1.3 } },
        { id = 'master_smith',   name = 'Master Smith',    level = 15, desc = 'Craft quality always excellent',effect = { qualityLock = 'excellent' } },
    },
    cooking = {
        { id = 'chef',           name = 'Chef',            level = 10, desc = '+15 morale from meals',        effect = { mealMorale = 15 } },
        { id = 'preservist',     name = 'Preservist',      level = 10, desc = 'Food spoils 50% slower',       effect = { spoilMult = 0.5 } },
        { id = 'herbalist',      name = 'Herbalist',       level = 15, desc = 'Double forage yield',          effect = { forageMult = 2.0 } },
    },
    hunting = {
        { id = 'sharpshooter',   name = 'Sharpshooter',    level = 10, desc = '+20% ranged accuracy',         effect = { accuracyBonus = 0.2 } },
        { id = 'berserker_mastery', name = 'Berserker',    level = 10, desc = '+25% melee damage',            effect = { meleeMult = 1.25 } },
        { id = 'big_game_hunter',name = 'Big Game Hunter', level = 15, desc = 'Double loot from megafauna',   effect = { megaLoot = 2.0 } },
    },
    research = {
        { id = 'scholar',        name = 'Scholar',         level = 10, desc = 'Research 25% faster',          effect = { researchMult = 1.25 } },
        { id = 'innovator',      name = 'Innovator',       level = 10, desc = 'Chance to skip research tier',  effect = { skipChance = 0.1 } },
        { id = 'polymath',       name = 'Polymath',        level = 15, desc = 'All other skills +2',          effect = { allSkillBonus = 2 } },
    },
    medical = {
        { id = 'surgeon',        name = 'Surgeon',         level = 10, desc = 'Can restore destroyed limbs',   effect = { canRestore = true } },
        { id = 'pharmacist',     name = 'Pharmacist',      level = 10, desc = 'Drug effects last 50% longer', effect = { drugDuration = 1.5 } },
        { id = 'plague_doctor',  name = 'Plague Doctor',   level = 15, desc = 'Immune to disease',            effect = { diseaseImmune = true } },
    },
}

Skills.MASTERIES = MASTERIES

function Skills.getAvailableMasteries(entityId, skillName)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col.skills then return {} end

    local level = col.skills[skillName] or 1
    local entries = MASTERIES[skillName]
    if not entries then return {} end

    local unlocked = col.masteries or {}
    local available = {}
    for _, m in ipairs(entries) do
        if level >= m.level and not unlocked[m.id] then
            available[#available + 1] = m
        end
    end
    return available
end

function Skills.unlockMastery(entityId, masteryId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return false end

    for skillName, entries in pairs(MASTERIES) do
        for _, m in ipairs(entries) do
            if m.id == masteryId then
                local level = col.skills and col.skills[skillName] or 0
                if level >= m.level then
                    if not col.masteries then col.masteries = {} end
                    col.masteries[masteryId] = m.effect
                    return true
                end
            end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Effective skill level (accounts for polymath mastery: +2 all skills)
---------------------------------------------------------------------------

function Skills.getEffectiveLevel(entityId, skillName)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col.skills then return 1 end
    local base = col.skills[skillName] or 1
    if col.masteries and col.masteries.polymath then
        local eff = col.masteries.polymath
        if eff.allSkillBonus then
            base = math.min(MAX_LEVEL, base + eff.allSkillBonus)
        end
    end
    -- Rust penalty: effective level reduced by 20% (floored, min 1)
    if Skills.isRusty(entityId, skillName) then
        base = math.max(1, math.floor(base * 0.8))
    end
    return base
end

function Skills.hasMastery(entityId, masteryId)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col.masteries then return false end
    return col.masteries[masteryId] ~= nil
end

function Skills.getMasteryEffect(entityId, masteryId)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col.masteries then return nil end
    return col.masteries[masteryId]
end

return Skills
