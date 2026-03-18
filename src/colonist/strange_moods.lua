-- strange_moods.lua — Dwarf Fortress-style creative trances
-- A colonist enters a "Frost Trance," claims a workshop, demands specific
-- materials. Supply them → legendary artifact. Fail → mental break or death.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Hope      = require('src.colony.hope')
local _StorageNet
local function getStorageNet()
    if _StorageNet == nil then
        local ok, mod = pcall(require, 'src.logistics.storage_network')
        _StorageNet = ok and mod or false
    end
    return _StorageNet or nil
end

local StrangeMoods = {}

---------------------------------------------------------------------------
-- Artifact templates — procedural combinations
---------------------------------------------------------------------------

local ARTIFACT_PREFIXES = {
    'Winter', 'Frost', 'Glacial', 'Polar', 'Crystal', 'Iron',
    'Obsidian', 'Midnight', 'Aurora', 'Storm', 'Void', 'Ember',
}

local ARTIFACT_SUFFIXES = {
    'heart', 'bane', 'song', 'edge', 'crown', 'ward',
    'fang', 'eye', 'breath', 'fury', 'tear', 'shard',
}

local ARTIFACT_TYPES = {
    weapon = {
        name = 'Weapon',
        bonuses = { combatMod = { 0.15, 0.30 } },
        machine = 'forge',
    },
    armor = {
        name = 'Armor',
        bonuses = { coldResist = { 0.10, 0.25 }, combatMod = { 0.05, 0.15 } },
        machine = 'workbench',
    },
    tool = {
        name = 'Tool',
        bonuses = { workSpeed = { 0.15, 0.30 }, craftMod = { 0.10, 0.20 } },
        machine = 'workbench',
    },
    decoration = {
        name = 'Masterwork',
        bonuses = { beauty = { 10, 25 }, moraleMod = { 0.05, 0.15 } },
        machine = 'workbench',
    },
    heater = {
        name = 'Thermal Device',
        bonuses = { heatOutput = { 50, 120 } },
        machine = 'forge',
    },
}

local MATERIAL_DEMANDS = {
    { item = 'metal',      min = 3,  max = 8 },
    { item = 'wood',       min = 5,  max = 15 },
    { item = 'stone',      min = 5,  max = 12 },
    { item = 'components', min = 1,  max = 4 },
    { item = 'hide',       min = 2,  max = 6 },
    { item = 'thermalCores', min = 1, max = 3 },
    { item = 'fuel',       min = 3,  max = 8 },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local activeMood = nil  -- { entityId, type, demands, timer, phase, artifactName }
local MOOD_TIMEOUT = 120  -- seconds before failure if demands unmet
local CRAFTING_TIME = 30  -- seconds to craft once demands are met
local MOOD_CHANCE_PER_DAY = 0.03  -- 3% chance per day per colonist
local moodCheckTimer = 0
local MOOD_CHECK_INTERVAL = 60  -- check once per game-minute

---------------------------------------------------------------------------
-- Procedural generation
---------------------------------------------------------------------------

local function generateArtifactName(artType)
    -- Use Adlib procedural naming if available
    local aok, Adlib = pcall(require, 'src.util.adlib')
    if aok and Adlib.artifactName then
        return Adlib.artifactName(artType or 'weapon')
    end
    -- Fallback: local prefix+suffix
    local prefix = ARTIFACT_PREFIXES[math.random(#ARTIFACT_PREFIXES)]
    local suffix = ARTIFACT_SUFFIXES[math.random(#ARTIFACT_SUFFIXES)]
    return prefix .. suffix
end

local function pickArtifactType()
    local types = {}
    for k in pairs(ARTIFACT_TYPES) do types[#types + 1] = k end
    return types[math.random(#types)]
end

local function rollDemands()
    -- Pick 2-3 random materials
    local count = 2 + math.random(0, 1)
    local demands = {}
    local used = {}
    for i = 1, count do
        local pick
        repeat
            pick = MATERIAL_DEMANDS[math.random(#MATERIAL_DEMANDS)]
        until not used[pick.item]
        used[pick.item] = true
        demands[#demands + 1] = {
            item = pick.item,
            amount = math.random(pick.min, pick.max),
            fulfilled = false,
        }
    end
    return demands
end

local function rollBonuses(artType)
    local template = ARTIFACT_TYPES[artType]
    if not template then return {} end
    local bonuses = {}
    for stat, range in pairs(template.bonuses) do
        bonuses[stat] = range[1] + math.random() * (range[2] - range[1])
        bonuses[stat] = math.floor(bonuses[stat] * 100 + 0.5) / 100
    end
    return bonuses
end

---------------------------------------------------------------------------
-- Mood lifecycle
---------------------------------------------------------------------------

local function startMood(entityId)
    if activeMood then return false end

    local col = ECS.get(entityId, 'colonist')
    if not col then return false end

    local artType = pickArtifactType()
    local artName = generateArtifactName(artType)
    local demands = rollDemands()

    activeMood = {
        entityId     = entityId,
        colonistName = col.name,
        type         = artType,
        typeDef      = ARTIFACT_TYPES[artType],
        artifactName = artName,
        demands      = demands,
        timer        = MOOD_TIMEOUT,
        craftTimer   = 0,
        phase        = 'demanding', -- 'demanding', 'crafting', 'done', 'failed'
        bonuses      = rollBonuses(artType),
    }

    col.state = 'strange_mood'
    col.task = nil

    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    local demandStr = {}
    for _, d in ipairs(demands) do
        demandStr[#demandStr + 1] = d.amount .. ' ' .. d.item
    end
    if stOk then
        Storyteller.logEvent('Frost Trance',
            col.name .. ' has entered a Frost Trance! They demand: ' ..
            table.concat(demandStr, ', '))
    end

    return true
end

local function checkDemandsMet()
    if not activeMood then return false end
    for _, d in ipairs(activeMood.demands) do
        if (GameState.resources[d.item] or 0) < d.amount then
            return false
        end
    end
    return true
end

local function consumeDemands()
    if not activeMood then return end
    local SNet = getStorageNet()
    for _, d in ipairs(activeMood.demands) do
        if SNet then SNet.withdraw(d.item, d.amount, GameState.startX, GameState.startY)
        else GameState.spendResource(d.item, d.amount) end
        d.fulfilled = true
    end
end

local function createArtifact()
    if not activeMood then return end

    local artId = ECS.spawn()
    ECS.set(artId, 'artifact', {
        name     = activeMood.artifactName,
        type     = activeMood.type,
        typeName = activeMood.typeDef.name,
        creator  = activeMood.colonistName,
        day      = GameState.day,
        bonuses  = activeMood.bonuses,
    })

    -- Place near colony center as a decoration with massive beauty
    ECS.set(artId, 'pos', {
        x = GameState.startX + math.random(-2, 2),
        y = GameState.startY + math.random(-2, 2),
    })

    local beauty = activeMood.bonuses.beauty or 15
    ECS.set(artId, 'decoration', {
        type   = 'artifact',
        beauty = beauty,
        name   = activeMood.artifactName,
    })

    Hope.applyDelta(10, -5)

    local stOk2, Storyteller2 = pcall(require, 'src.storyteller.storyteller')
    if stOk2 then
        Storyteller2.logEvent('Artifact Created',
            activeMood.colonistName .. ' created "' .. activeMood.artifactName ..
            '", a legendary ' .. activeMood.typeDef.name .. '!')
    end
end

local function failMood()
    if not activeMood then return end

    local entityId = activeMood.entityId
    local col = ECS.get(entityId, 'colonist')
    if col then
        -- Mental break from failed trance
        col.state = 'mental_break'
        col.sanity = 0
        col.health = math.max(5, col.health - 30)
    end

    Hope.applyDelta(-5, 5)

    local stOk3, Storyteller3 = pcall(require, 'src.storyteller.storyteller')
    if stOk3 then
        Storyteller3.logEvent('Trance Failed',
            (activeMood.colonistName or 'A colonist') ..
            '\'s Frost Trance failed. Mental break triggered.')
    end

    activeMood = nil
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function StrangeMoods.step(dt)
    -- Check for new mood triggers periodically
    moodCheckTimer = moodCheckTimer + dt
    if moodCheckTimer >= MOOD_CHECK_INTERVAL and not activeMood then
        moodCheckTimer = 0

        -- Roll for each colonist
        local candidates = {}
        for id, comps in ECS.query('colonist', 'needs') do
            local col = comps.colonist
            if col.state ~= 'dead' and col.state ~= 'away_expedition'
               and col.state ~= 'mental_break' and col.state ~= 'strange_mood' then
                -- Higher skill colonists more likely to get moods
                local maxSkill = 0
                if col.skills then
                    for _, v in pairs(col.skills) do
                        if v > maxSkill then maxSkill = v end
                    end
                end
                local chance = MOOD_CHANCE_PER_DAY * (1 + maxSkill * 0.1)
                if math.random() < chance * (MOOD_CHECK_INTERVAL / 1440) then
                    candidates[#candidates + 1] = id
                end
            end
        end

        if #candidates > 0 then
            startMood(candidates[math.random(#candidates)])
        end
    end

    -- Tick active mood
    if not activeMood then return end
    if not ECS.isAlive(activeMood.entityId) then
        activeMood = nil
        return
    end

    if activeMood.phase == 'demanding' then
        activeMood.timer = activeMood.timer - dt
        if activeMood.timer <= 0 then
            failMood()
            return
        end

        -- Auto-consume when resources available
        if checkDemandsMet() then
            consumeDemands()
            activeMood.phase = 'crafting'
            activeMood.craftTimer = CRAFTING_TIME
        end

    elseif activeMood.phase == 'crafting' then
        activeMood.craftTimer = activeMood.craftTimer - dt
        if activeMood.craftTimer <= 0 then
            createArtifact()
            -- Restore colonist
            local col = ECS.get(activeMood.entityId, 'colonist')
            if col then
                col.state = 'idle'
                -- Skill boost from the creative experience
                if col.skills then
                    for skill, val in pairs(col.skills) do
                        col.skills[skill] = math.min(10, val + 1)
                    end
                end
            end
            activeMood.phase = 'done'
            activeMood = nil
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function StrangeMoods.getActiveMood()
    return activeMood
end

function StrangeMoods.isActive()
    return activeMood ~= nil
end

function StrangeMoods.restoreActiveMood(saved)
    activeMood = saved
end

function StrangeMoods.init()
    activeMood = nil
    moodCheckTimer = 0
end

return StrangeMoods
