-- quest.lua -- Quest system lifecycle
-- Manages quest lifecycle: accept, track, complete, reward, abandon.
-- Quest generation is in quest_gen.lua. This file handles the board,
-- active quest tracking, event hooks, threat raids, failure consequences,
-- chain progression, and save/load.

local ECS        = require('src.ecs.ecs')
local GameState  = require('src.game_state')
local Objectives = require('src.quest.quest_objectives')
local QuestGen   = require('src.quest.quest_gen')
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

local Quest = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local availableQuests = {}   -- quests on the board, not yet accepted
local activeQuests    = {}   -- accepted, being tracked
local completedQuests = {}   -- finished (for history/reward log)
local nextQuestId     = 1
local boardTimer      = 0    -- timer for refreshing board quests
local MAX_BOARD       = 4    -- max quests on the board at once
local MAX_ACTIVE      = 3    -- max concurrently accepted quests
local REFRESH_INTERVAL = 300 -- seconds between board refreshes (5 min)
local BOARD_TTL       = 5    -- default days before an unclaimed quest expires

---------------------------------------------------------------------------
-- Quest record construction
---------------------------------------------------------------------------

local function makeQuestRecord(raw)
    local q = {
        id              = nextQuestId,
        title           = raw.title,
        desc            = raw.desc,
        type            = raw.type,
        objectives      = raw.objectives or {},
        reward          = raw.reward or {},
        timeLimit       = raw.timeLimit or 0,
        state           = 'available',
        acceptedDay     = 0,
        completedDay    = 0,
        offeredDay      = GameState.day,
        -- Difficulty and display
        difficulty      = raw.difficulty or 1.0,
        stars           = raw.stars or 2,
        -- Faction association
        factionId       = raw.factionId,
        factionName     = raw.factionName,
        -- Threat-attached quest info
        threatInfo      = raw.threatInfo,
        -- Quest chain tracking
        chainId         = raw.chainId,
        chainStep       = raw.chainStep,
        chainTotal      = raw.chainTotal,
        -- Exclusive reward
        exclusiveReward = raw.exclusiveReward,
        -- Colonist-specific quest
        colonistId      = raw.colonistId,
        -- Per-quest board TTL override
        boardTTL        = raw.boardTTL,
    }
    nextQuestId = nextQuestId + 1
    return q
end

---------------------------------------------------------------------------
-- Failure consequences
---------------------------------------------------------------------------

local function applyFailureConsequences(q)
    -- Faction rep penalty
    if q.factionId then
        local fok, Factions = pcall(require, 'src.colony.factions')
        if fok then Factions.modifyRep(q.factionId, -5) end
    end

    -- Hope loss, discontent rise
    local hok, HopeMod = pcall(require, 'src.colony.hope')
    if hok then HopeMod.applyDelta(-3, 2) end

    -- Threat quests: raid comes anyway with no reward
    if q.threatInfo and not q.threatInfo.raidFired then
        q.threatInfo.raidFired = true
        local rok, Raids = pcall(require, 'src.sim.raids')
        if rok and not Raids.isRaidActive() then
            Raids.startRaid(Raids.pickRaidType())
        end
    end

    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok then Storyteller.logEvent('Quest Failed', q.title) end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Quest.init()
    availableQuests = {}
    activeQuests    = {}
    completedQuests = {}
    nextQuestId     = 1
    boardTimer      = 0
end

-- Populate the quest board with new quests
function Quest.refreshBoard()
    -- Remove stale available quests (per-quest TTL)
    local keep = {}
    for _, q in ipairs(availableQuests) do
        local age = GameState.day - (q.offeredDay or 0)
        local ttl = q.boardTTL or BOARD_TTL
        if age < ttl then
            keep[#keep + 1] = q
        end
    end
    availableQuests = keep

    local boardCap = MAX_BOARD
    local hok, Hermes = pcall(require, 'src.sim.hermes')
    if hok and Hermes.getQuestBoardCap then
        boardCap = Hermes.getQuestBoardCap(MAX_BOARD)
    end

    while #availableQuests > boardCap do
        table.remove(availableQuests)
    end

    -- Fill up to current board cap
    local needed = boardCap - #availableQuests
    for _ = 1, needed do
        local raw = QuestGen.generate()
        if raw then
            local q = makeQuestRecord(raw)
            availableQuests[#availableQuests + 1] = q
            -- Notify player of new quest
            local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if sok then Storyteller.logEvent('New Quest', q.title) end
        end
    end
end

-- Accept a quest from the board
function Quest.accept(questId)
    if #activeQuests >= MAX_ACTIVE then
        return false, 'Too many active quests'
    end

    local foundIdx = nil
    for i, q in ipairs(availableQuests) do
        if q.id == questId then
            foundIdx = i
            break
        end
    end
    if not foundIdx then return false, 'Quest not found on board' end

    local q = availableQuests[foundIdx]
    q.state = 'active'
    q.acceptedDay = GameState.day
    activeQuests[#activeQuests + 1] = q
    table.remove(availableQuests, foundIdx)

    -- Threat-attached: schedule a raid
    if q.threatInfo then
        q.threatInfo.raidScheduledDay = GameState.day + (q.threatInfo.raidDelay or 1)
        q.threatInfo.raidFired = false
    end

    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok then Storyteller.logEvent('Quest Accepted', q.title) end
    return true
end

-- Abandon an active quest
function Quest.abandon(questId)
    local foundIdx = nil
    for i, q in ipairs(activeQuests) do
        if q.id == questId then
            foundIdx = i
            break
        end
    end
    if not foundIdx then return false end

    local q = activeQuests[foundIdx]
    q.state = 'failed'
    applyFailureConsequences(q)
    completedQuests[#completedQuests + 1] = q
    table.remove(activeQuests, foundIdx)
    return true
end

-- Complete a quest and grant rewards
local function completeQuest(q)
    q.state = 'completed'
    q.completedDay = GameState.day

    local r = q.reward

    -- Thermal cores
    if r.thermalCores then
        local Items = getItems()
        if Items then Items.spawn(GameState.startX, GameState.startY, 'thermalCores', r.thermalCores, nil, 0)
        else GameState.addResource('thermalCores', r.thermalCores) end
    end

    -- Bonus resource drop
    if r.resources then
        local drops = { 'wood', 'metal', 'food', 'fuel', 'components' }
        local res = drops[math.random(#drops)]
        local amt = 5 + math.random(10)
        local Items = getItems()
        if Items then Items.spawn(GameState.startX, GameState.startY, res, amt, nil, 0)
        else GameState.addResource(res, amt) end
    end

    -- Spawn a new colonist
    if r.colonist then
        local cok, Colonist = pcall(require, 'src.colonist.colonist')
        local wok, World    = pcall(require, 'src.world.tilemap')
        if cok and wok then
            local cx = GameState.startX + math.random(-3, 3)
            local cy = GameState.startY + math.random(-3, 3)
            if World.isWalkable(cx, cy, 0) then
                Colonist.spawn(cx, cy)
            end
        end
    end

    -- Grant research progress
    if r.knowledge then
        local rok, Research = pcall(require, 'src.research.research')
        if rok and Research.addPoints then
            Research.addPoints(50 + math.random(100))
        end
    end

    -- Faction reputation reward
    if r.factionId and r.factionRep then
        local fok, Factions = pcall(require, 'src.colony.factions')
        if fok then
            Factions.modifyRep(r.factionId, r.factionRep)
        end
    elseif r.reputation then
        -- Legacy fallback for non-faction rep rewards
        local reputationCores = math.floor(r.reputation * 0.3)
        local Items = getItems()
        if Items then Items.spawn(GameState.startX, GameState.startY, 'thermalCores', reputationCores, nil, 0)
        else GameState.addResource('thermalCores', reputationCores) end
    end

    -- Consume delivered resources
    for _, obj in ipairs(q.objectives) do
        if obj.type == 'deliver' then
            local SNet = getStorageNet()
            if SNet then SNet.withdraw(obj.resource, obj.target, GameState.startX, GameState.startY)
            else GameState.spendResource(obj.resource, obj.target) end
        end
    end

    -- Exclusive reward: apply gameplay effect + bonus thermal cores
    if q.exclusiveReward then
        local er = q.exclusiveReward
        local erCores = er.thermalCores or 10
        local Items = getItems()
        if Items then Items.spawn(GameState.startX, GameState.startY, 'thermalCores', erCores, nil, 0)
        else GameState.addResource('thermalCores', erCores) end

        -- Track earned exclusive buffs on GameState for other systems to check
        if not GameState.exclusiveBuffs then GameState.exclusiveBuffs = {} end
        GameState.exclusiveBuffs[er.id] = true

        -- Grant item if the reward spawns equipment
        if er.grantItem then
            local iok, ItemsMod = pcall(require, 'src.world.items')
            if iok and ItemsMod.spawn then
                ItemsMod.spawn(GameState.startX, GameState.startY, er.grantItem, 1)
            end
        end

        -- Precursor core: add 50W passive power
        if er.id == 'precursor_core' then
            local pok, PowerMod = pcall(require, 'src.sim.power')
            if pok and PowerMod.addPassiveWatts then
                PowerMod.addPassiveWatts(50)
            end
        end

        local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if sok then Storyteller.logEvent('Exclusive Reward', er.name) end
    end

    -- Hope boost on quest completion
    local hok, HopeMod = pcall(require, 'src.colony.hope')
    if hok then HopeMod.applyDelta(3, -1) end

    completedQuests[#completedQuests + 1] = q

    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok then Storyteller.logEvent('Quest Complete', q.title) end

    -- Chain: generate next step
    if q.chainId and q.chainStep and q.chainTotal and q.chainStep < q.chainTotal then
        local nextRaw = QuestGen.generateChainStep(q.chainId, q.chainStep + 1, q.chainTotal, q.difficulty)
        if nextRaw then
            local nextQ = makeQuestRecord(nextRaw)
            availableQuests[#availableQuests + 1] = nextQ
            if sok then Storyteller.logEvent('Chain Quest', 'Next step: ' .. nextQ.title) end
        end
    end
end

---------------------------------------------------------------------------
-- Event hooks (called by other systems)
---------------------------------------------------------------------------

function Quest.onCreatureKilled(species)
    for _, q in ipairs(activeQuests) do
        for _, obj in ipairs(q.objectives) do
            if obj.type == 'kill' and not obj.done then
                if not obj.species or obj.species == species then
                    obj.current = obj.current + 1
                end
            end
        end
    end
end

function Quest.onResourceGathered(resource, amount)
    for _, q in ipairs(activeQuests) do
        for _, obj in ipairs(q.objectives) do
            if obj.type == 'gather' and not obj.done and obj.resource == resource then
                obj.current = obj.current + (amount or 1)
            end
        end
    end
end

function Quest.onBuildingPlaced(buildId)
    for _, q in ipairs(activeQuests) do
        for _, obj in ipairs(q.objectives) do
            if obj.type == 'build' and not obj.done and obj.buildId == buildId then
                obj.current = obj.current + 1
            end
        end
    end
end

function Quest.onRaidSurvived()
    for _, q in ipairs(activeQuests) do
        for _, obj in ipairs(q.objectives) do
            if obj.type == 'defend' and not obj.done then
                obj.current = obj.current + 1
            end
        end
    end
end

function Quest.onExpeditionComplete(destId)
    for _, q in ipairs(activeQuests) do
        for _, obj in ipairs(q.objectives) do
            if obj.type == 'expedition' and not obj.done then
                if not obj.destId or obj.destId == destId then
                    obj.done = true
                end
            end
        end
    end
end

function Quest.onResearchComplete(techId)
    for _, q in ipairs(activeQuests) do
        for _, obj in ipairs(q.objectives) do
            if obj.type == 'research' and not obj.done and obj.techId == techId then
                obj.done = true
            end
        end
    end
end

---------------------------------------------------------------------------
-- Step -- called each sim tick
---------------------------------------------------------------------------

function Quest.step(dt)
    -- Board refresh timer
    boardTimer = boardTimer + dt
    if boardTimer >= REFRESH_INTERVAL then
        boardTimer = boardTimer - REFRESH_INTERVAL
        Quest.refreshBoard()
    end

    -- Initial population if board is empty
    if #availableQuests == 0 and #activeQuests == 0 then
        Quest.refreshBoard()
    end

    -- Check active quests for completion / expiry / threat raids
    local toRemove = {}
    for i, q in ipairs(activeQuests) do
        -- Trigger scheduled threat raids
        if q.threatInfo and q.threatInfo.raidScheduledDay and not q.threatInfo.raidFired then
            if GameState.day >= q.threatInfo.raidScheduledDay then
                q.threatInfo.raidFired = true
                local rok, Raids = pcall(require, 'src.sim.raids')
                if rok and not Raids.isRaidActive() then
                    Raids.startRaid(Raids.pickRaidType())
                end
            end
        end

        -- Expiry warning (2 days remaining)
        if q.timeLimit > 0 and not q._expiryWarned then
            local remaining = q.timeLimit - (GameState.day - q.acceptedDay)
            if remaining <= 2 and remaining > 0 then
                q._expiryWarned = true
                local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
                if sok then Storyteller.logEvent('Quest Warning', q.title .. ' expires soon!') end
            end
        end

        -- Check time limit
        if q.timeLimit > 0 then
            local elapsed = GameState.day - q.acceptedDay
            if elapsed > q.timeLimit then
                q.state = 'expired'
                applyFailureConsequences(q)
                completedQuests[#completedQuests + 1] = q
                toRemove[#toRemove + 1] = i
                goto continue
            end
        end

        -- Check all objectives
        local allDone = true
        for _, obj in ipairs(q.objectives) do
            if not Objectives.check(obj) then
                allDone = false
                break
            end
        end

        if allDone then
            completeQuest(q)
            toRemove[#toRemove + 1] = i
        end

        ::continue::
    end

    -- Remove completed/expired from active list (reverse order)
    for i = #toRemove, 1, -1 do
        table.remove(activeQuests, toRemove[i])
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Quest.getAvailable()
    return availableQuests
end

function Quest.getActive()
    return activeQuests
end

function Quest.getCompleted()
    return completedQuests
end

function Quest.getActiveCount()
    return #activeQuests
end

function Quest.getById(questId)
    for _, q in ipairs(availableQuests) do
        if q.id == questId then return q end
    end
    for _, q in ipairs(activeQuests) do
        if q.id == questId then return q end
    end
    for _, q in ipairs(completedQuests) do
        if q.id == questId then return q end
    end
    return nil
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Quest.getState()
    return {
        availableQuests = availableQuests,
        activeQuests    = activeQuests,
        completedQuests = completedQuests,
        nextQuestId     = nextQuestId,
        boardTimer      = boardTimer,
    }
end

function Quest.loadState(saved)
    if not saved then return end
    availableQuests = saved.availableQuests or {}
    activeQuests    = saved.activeQuests or {}
    completedQuests = saved.completedQuests or {}
    nextQuestId     = saved.nextQuestId or 1
    boardTimer      = saved.boardTimer or 0
end

return Quest
