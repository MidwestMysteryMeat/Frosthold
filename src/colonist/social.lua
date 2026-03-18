-- social.lua -- Colonist social relationships: opinion matrix, friends, rivals
-- Registered as an ECS system. Opinion builds from proximity and shared work.
-- Friends give morale buff when nearby. Rivals give morale penalty + fight chance.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Social = {}

-- Module-level require cache (avoids pcall in tick-rate loops)
local Jobs = nil
do
    local ok, mod = pcall(require, 'src.colonist.jobs')
    if ok then Jobs = mod end
end

---------------------------------------------------------------------------
-- Opinion matrix: opinions[idA][idB] = score (-100 to +100)
-- Symmetric: opinions[a][b] == opinions[b][a]
---------------------------------------------------------------------------

local opinions = {}

-- Grieving entries: { [colonistId] = { [deadName] = { morale = -20, endsDay = N } } }
local grieving = {}
local bonds = {}  -- { [colonistId] = { partnerId, stage, sinceDay, sinceHour } }

local FRIEND_THRESHOLD =  50
local RIVAL_THRESHOLD  = -30

local PROXIMITY_RANGE = 3  -- tiles
local PROXIMITY_GAIN  = 0.01
local SHARED_WORK_GAIN = 0.05

local FRIEND_MORALE_BUFF  = 5
local RIVAL_MORALE_PENALTY = -3
local DEATH_MORALE_PENALTY = -20
local DEATH_GRIEF_DAYS     = 2
local PARTNER_MORALE_BUFF = {
    dating = 8,
    lovers = 12,
}
local PARTNER_DEATH_MORALE_PENALTY = -35
local PARTNER_DEATH_GRIEF_DAYS     = 4

local ROMANCE_START_THRESHOLD   = 70
local ROMANCE_LOVER_THRESHOLD   = 85
local ROMANCE_BREAKUP_THRESHOLD = 25
local ROMANCE_START_CHANCE      = 0.0003
local ROMANCE_UPGRADE_CHANCE    = 0.0002

local FIGHT_CHANCE_PER_TICK = 0.0002  -- when rivals are adjacent
local TRAIT_OPINION_RATE = 0.005     -- opinion drift rate per second from trait interactions
local logSocialEvent

---------------------------------------------------------------------------
-- Trait-based opinion modifiers
-- Returns per-second opinion drift that colonist A feels toward colonist B.
---------------------------------------------------------------------------

local function hasTrait(col, traitId)
    if not col.traits then return false end
    for _, t in ipairs(col.traits) do
        if t.id == traitId then return true end
    end
    return false
end

local function getTraitOpinionDrift(colA, colB)
    local drift = 0
    if not colA.traits then return 0 end
    for _, t in ipairs(colA.traits) do
        local mod = t.opinionMod
        if mod then
            -- A's reactions to B based on A's traits
            if mod == 'hates_mess' and hasTrait(colB, 'clumsy') then
                drift = drift - TRAIT_OPINION_RATE
            end
            if mod == 'kind_words' then
                drift = drift + TRAIT_OPINION_RATE * 0.5  -- kind to everyone
            end
            if mod == 'annoyed_by_people' then
                drift = drift - TRAIT_OPINION_RATE * 0.3  -- dislikes proximity
            end
            if mod == 'envious' then
                -- Jealous of colonists with higher total skills
                if colB.skills and colA.skills then
                    local sumA, sumB = 0, 0
                    for sk, v in pairs(colA.skills) do sumA = sumA + v end
                    for sk, v in pairs(colB.skills) do sumB = sumB + v end
                    if sumB > sumA + 5 then
                        drift = drift - TRAIT_OPINION_RATE
                    end
                end
            end
            if mod == 'hates_bionics' and hasTrait(colB, 'transhumanist') then
                drift = drift - TRAIT_OPINION_RATE
            end
            if mod == 'wants_bionics' and hasTrait(colB, 'body_purist') then
                drift = drift - TRAIT_OPINION_RATE
            end
            if mod == 'likes_simple' then
                -- Ascetic: kindred spirits with other ascetics, dislikes gourmands
                if hasTrait(colB, 'ascetic') then
                    drift = drift + TRAIT_OPINION_RATE * 0.5
                end
                if hasTrait(colB, 'gourmand') then
                    drift = drift - TRAIT_OPINION_RATE * 0.3
                end
            end
            if mod == 'hates_raw_food' and hasTrait(colB, 'ascetic') then
                drift = drift - TRAIT_OPINION_RATE * 0.3  -- no appreciation for food
            end
        end
    end

    -- B's traits that passively affect A's opinion of B
    if colB.traits then
        for _, t in ipairs(colB.traits) do
            local mod = t.opinionMod
            if mod == 'ugly_face' then
                drift = drift - TRAIT_OPINION_RATE * 0.5
            elseif mod == 'annoying' then
                drift = drift - TRAIT_OPINION_RATE * 0.5
            elseif mod == 'likes_human_meat' and not hasTrait(colA, 'cannibal') then
                drift = drift - TRAIT_OPINION_RATE * 0.3
            elseif mod == 'enjoys_kills' and hasTrait(colA, 'pacifist') then
                drift = drift - TRAIT_OPINION_RATE  -- pacifists dislike bloodlust
            end
        end
    end

    return drift
end

---------------------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------------------

local function ensurePair(a, b)
    if not opinions[a] then opinions[a] = {} end
    if not opinions[b] then opinions[b] = {} end
    if opinions[a][b] == nil then
        opinions[a][b] = 0
        opinions[b][a] = 0
    end
end

local function setOpinion(a, b, val)
    val = math.max(-100, math.min(100, val))
    if not opinions[a] then opinions[a] = {} end
    if not opinions[b] then opinions[b] = {} end
    opinions[a][b] = val
    opinions[b][a] = val
end

local function getOpinion(a, b)
    if opinions[a] and opinions[a][b] then
        return opinions[a][b]
    end
    return 0
end

local function distSq(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return dx * dx + dy * dy
end

local function getColonistName(id)
    local col = ECS.get(id, 'colonist')
    return col and (col.name or 'Unknown') or 'Unknown'
end

local function recordColonistEvent(colonistId, text, eventType)
    local ok, ColonistInfo = pcall(require, 'src.ui.colonist_info')
    if ok and ColonistInfo.logEvent then
        ColonistInfo.logEvent(colonistId, text, eventType)
    end
end

local function getBond(id)
    local bond = bonds[id]
    if not bond then return nil end
    if not bond.partnerId or not bonds[bond.partnerId] then
        bonds[id] = nil
        return nil
    end
    return bond
end

local function clearBondPair(a, b, reason)
    local bond = bonds[a]
    if not bond or bond.partnerId ~= b then return false end

    bonds[a] = nil
    if bonds[b] and bonds[b].partnerId == a then
        bonds[b] = nil
    end

    if reason == 'breakup' then
        ensurePair(a, b)
        setOpinion(a, b, getOpinion(a, b) - 15)

        local nameA = getColonistName(a)
        local nameB = getColonistName(b)
        logSocialEvent(string.format('%s and %s broke up.', nameA, nameB))
        recordColonistEvent(a, 'Broke up with ' .. nameB, 'loss')
        recordColonistEvent(b, 'Broke up with ' .. nameA, 'loss')
    end

    return true
end

local function setBondPair(a, b, stage)
    stage = (stage == 'lovers') and 'lovers' or 'dating'
    if a == b or not ECS.isAlive(a) or not ECS.isAlive(b) then return false end

    local bondA = bonds[a]
    if bondA and bondA.partnerId ~= b then
        clearBondPair(a, bondA.partnerId, 'superseded')
    end
    local bondB = bonds[b]
    if bondB and bondB.partnerId ~= a then
        clearBondPair(b, bondB.partnerId, 'superseded')
    end

    ensurePair(a, b)
    local prevStage = bonds[a] and bonds[a].partnerId == b and bonds[a].stage or nil
    local sinceDay = GameState.day
    local sinceHour = GameState.hour
    if prevStage and bonds[a] then
        sinceDay = bonds[a].sinceDay or sinceDay
        sinceHour = bonds[a].sinceHour or sinceHour
    end

    bonds[a] = { partnerId = b, stage = stage, sinceDay = sinceDay, sinceHour = sinceHour }
    bonds[b] = { partnerId = a, stage = stage, sinceDay = sinceDay, sinceHour = sinceHour }

    local nameA = getColonistName(a)
    local nameB = getColonistName(b)
    if stage == 'dating' and prevStage ~= 'dating' and prevStage ~= 'lovers' then
        logSocialEvent(string.format('%s and %s started seeing each other.', nameA, nameB))
        recordColonistEvent(a, 'Started dating ' .. nameB, 'positive')
        recordColonistEvent(b, 'Started dating ' .. nameA, 'positive')
    elseif stage == 'lovers' and prevStage ~= 'lovers' then
        logSocialEvent(string.format('%s and %s became lovers.', nameA, nameB))
        recordColonistEvent(a, 'Became lovers with ' .. nameB, 'positive')
        recordColonistEvent(b, 'Became lovers with ' .. nameA, 'positive')
    end

    return true
end

local function tryRomanceProgression(idA, idB, colA, colB, opinion)
    if idA > idB then return end
    if (colA.age or 0) < 18 or (colB.age or 0) < 18 then return end

    local bondA = getBond(idA)
    local bondB = getBond(idB)
    local paired = bondA and bondA.partnerId == idB and bondB and bondB.partnerId == idA

    if paired then
        if opinion <= ROMANCE_BREAKUP_THRESHOLD then
            clearBondPair(idA, idB, 'breakup')
            return
        end
        if bondA.stage == 'dating' and opinion >= ROMANCE_LOVER_THRESHOLD and math.random() < ROMANCE_UPGRADE_CHANCE then
            setBondPair(idA, idB, 'lovers')
        end
        return
    end

    if bondA or bondB then return end
    if opinion >= ROMANCE_START_THRESHOLD and math.random() < ROMANCE_START_CHANCE then
        setBondPair(idA, idB, 'dating')
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Social.getOpinion(a, b)
    return getOpinion(a, b)
end

function Social.setOpinion(a, b, val)
    setOpinion(a, b, val)
end

function Social.adjustOpinion(a, b, delta)
    ensurePair(a, b)
    setOpinion(a, b, getOpinion(a, b) + delta)
end

function Social.getBond(entityId)
    return getBond(entityId)
end

function Social.getRelationshipStatus(a, b)
    local bond = getBond(a)
    if bond and bond.partnerId == b then
        return bond.stage
    end
    return nil
end

function Social.setBond(a, b, stage)
    return setBondPair(a, b, stage)
end

function Social.clearBond(entityId, reason)
    local bond = getBond(entityId)
    if not bond then return false end
    return clearBondPair(entityId, bond.partnerId, reason)
end

function Social.isFriend(a, b)
    return getOpinion(a, b) >= FRIEND_THRESHOLD
end

function Social.isRival(a, b)
    return getOpinion(a, b) <= RIVAL_THRESHOLD
end

-- Called when a colonist dies, to apply grief to friends
function Social.onColonistDeath(deadId)
    local deadCol = ECS.get(deadId, 'colonist')
    local deadName = deadCol and deadCol.name or 'Unknown'

    local partnerBond = getBond(deadId)
    if partnerBond and ECS.isAlive(partnerBond.partnerId) then
        local partnerId = partnerBond.partnerId
        if not grieving[partnerId] then grieving[partnerId] = {} end
        grieving[partnerId]['partner:' .. deadName] = {
            morale = PARTNER_DEATH_MORALE_PENALTY,
            endsDay = GameState.day + GameState.hour / 24 + PARTNER_DEATH_GRIEF_DAYS,
        }
        local partnerName = getColonistName(partnerId)
        logSocialEvent(string.format('%s lost %s.', partnerName, deadName))
        recordColonistEvent(partnerId, deadName .. ' died.', 'loss')
        clearBondPair(deadId, partnerId, 'death')
    end

    local myOpinions = opinions[deadId]
    if myOpinions then
        for otherId, score in pairs(myOpinions) do
            if score >= FRIEND_THRESHOLD and ECS.isAlive(otherId) then
                -- Apply grief
                if not grieving[otherId] then grieving[otherId] = {} end
                grieving[otherId][deadName] = {
                    morale = DEATH_MORALE_PENALTY,
                    endsDay = GameState.day + GameState.hour / 24 + DEATH_GRIEF_DAYS,
                }
            end
        end
    end

    -- Clean up opinion data for dead entity
    opinions[deadId] = nil
    for _, tbl in pairs(opinions) do
        tbl[deadId] = nil
    end

    -- Clean up grieving entry for the dead colonist (they can't grieve anymore)
    grieving[deadId] = nil
end

-- Get all relationship data for a colonist (for UI)
function Social.getRelationships(entityId)
    local result = {}
    local myOpinions = opinions[entityId]
    if not myOpinions then return result end
    for otherId, score in pairs(myOpinions) do
        if ECS.isAlive(otherId) then
            local otherCol = ECS.get(otherId, 'colonist')
            local label = 'neutral'
            local bond = getBond(entityId)
            if bond and bond.partnerId == otherId then
                label = bond.stage == 'lovers' and 'lover' or 'dating'
            elseif score >= FRIEND_THRESHOLD then
                label = 'friend'
            elseif score <= RIVAL_THRESHOLD then
                label = 'rival'
            end
            result[#result + 1] = {
                id = otherId,
                name = otherCol and otherCol.name or '?',
                opinion = score,
                label = label,
            }
        end
    end
    table.sort(result, function(a, b) return a.opinion > b.opinion end)
    return result
end

---------------------------------------------------------------------------
-- Colonist position cache (rebuilt once per tick, avoids O(n²) ECS queries)
---------------------------------------------------------------------------

local colonistCache = {}   -- { {id, pos, col, needs}, ... }
local cacheTickId   = -1   -- GameState.simTick when cache was last built

local function rebuildCache()
    local tick = GameState.simTick or 0
    if tick == cacheTickId then return end
    cacheTickId = tick
    colonistCache = {}
    for id, comps in ECS.query('colonist', 'pos', 'needs') do
        if comps.colonist.state ~= 'dead' then
            colonistCache[#colonistCache + 1] = {
                id    = id,
                pos   = comps.pos,
                col   = comps.colonist,
                needs = comps.needs,
            }
        end
    end
end

---------------------------------------------------------------------------
-- Discrete social events (insults, compliments, bonding moments)
-- Fire occasionally when colonists are in proximity, produce visible logs.
---------------------------------------------------------------------------

local SOCIAL_EVENT_COOLDOWN = 30  -- seconds between events per colonist pair
local socialEventTimers = {}      -- { ["idA:idB"] = cooldownRemaining }

-- Social event log (readable by UI)
local socialLog = {}
local MAX_SOCIAL_LOG = 20

logSocialEvent = function(msg)
    socialLog[#socialLog + 1] = {
        msg  = msg,
        day  = GameState.day,
        hour = GameState.hour,
    }
    while #socialLog > MAX_SOCIAL_LOG do
        table.remove(socialLog, 1)
    end
end

function Social.getSocialLog()
    return socialLog
end

local SOCIAL_EVENTS = {
    -- Positive events (require opinion >= 0)
    { id = 'compliment',  minOpinion = 0,   chance = 0.003, delta = 4,
      msg = '%s complimented %s.' },
    { id = 'shared_joke', minOpinion = 20,  chance = 0.002, delta = 5,
      msg = '%s and %s shared a laugh.' },
    { id = 'deep_talk',   minOpinion = 40,  chance = 0.001, delta = 6,
      msg = '%s and %s had a meaningful conversation.' },
    -- Negative events (require opinion <= 0)
    { id = 'insult',      maxOpinion = 0,   chance = 0.003, delta = -4,
      msg = '%s insulted %s.' },
    { id = 'argument',    maxOpinion = -15, chance = 0.002, delta = -5,
      msg = '%s and %s got into an argument.' },
    { id = 'snide_remark', maxOpinion = -5, chance = 0.004, delta = -3,
      msg = '%s made a snide remark about %s.' },
}

local function tryDiscreteEvent(idA, idB, colA, colB, opinion, dt)
    -- Pair key (always use smaller ID first for symmetry)
    local lo, hi = math.min(idA, idB), math.max(idA, idB)
    local key = lo .. ':' .. hi

    -- Tick cooldown
    if socialEventTimers[key] then
        socialEventTimers[key] = socialEventTimers[key] - dt
        if socialEventTimers[key] > 0 then return end
        socialEventTimers[key] = nil
    end

    for _, evt in ipairs(SOCIAL_EVENTS) do
        local eligible = true
        if evt.minOpinion and opinion < evt.minOpinion then eligible = false end
        if evt.maxOpinion and opinion > evt.maxOpinion then eligible = false end
        if eligible and math.random() < evt.chance then
            Social.adjustOpinion(idA, idB, evt.delta)
            -- Morale nudge for the affected party
            local needsB = ECS.get(idB, 'needs')
            if needsB then
                needsB.morale = math.max(0, math.min(100, needsB.morale + evt.delta * 0.5))
            end
            local nameA = colA.name or '?'
            local nameB = colB.name or '?'
            logSocialEvent(string.format(evt.msg, nameA, nameB))
            socialEventTimers[key] = SOCIAL_EVENT_COOLDOWN
            return  -- one event per tick per pair
        end
    end
end

---------------------------------------------------------------------------
-- ECS system
---------------------------------------------------------------------------

local function socialSystem(dt, id, comps)
    local col   = comps.colonist
    local pos   = comps.pos
    local needs = comps.needs

    if col.state == 'dead' then return end

    -- Rebuild colonist cache once per tick (first colonist to run does it)
    rebuildCache()

    -- Iterate cached colonists instead of re-querying ECS
    local friendNearby = false
    local rivalNearby  = false
    local partnerNearbyStage = nil

    for _, other in ipairs(colonistCache) do
        local otherId = other.id
        if otherId ~= id then
            local oPos = other.pos
            local oCol = other.col
            local dSq = distSq(pos.x, pos.y, oPos.x, oPos.y)

            if dSq <= PROXIMITY_RANGE * PROXIMITY_RANGE then
                local dist = math.sqrt(dSq)
                ensurePair(id, otherId)

                -- Proximity gain + trait-based opinion drift
                local socialScale = 1.0
                if col.traits then
                    for _, t in ipairs(col.traits) do
                        if t.socialMod then socialScale = socialScale + t.socialMod end
                    end
                end
                local traitDrift = getTraitOpinionDrift(col, oCol)
                Social.adjustOpinion(id, otherId, (PROXIMITY_GAIN * socialScale + traitDrift) * dt)

                -- Shared work bonus (using module-level Jobs ref)
                if col.state == 'working' and oCol.state == 'working' then
                    if col.task and oCol.task and Jobs then
                        local myTask = Jobs.getTask(col.task.taskId)
                        local theirTask = Jobs.getTask(oCol.task.taskId)
                        if myTask and theirTask and myTask.type == theirTask.type then
                            Social.adjustOpinion(id, otherId, SHARED_WORK_GAIN * dt)
                        end
                    end
                end

                -- Morale effects from relationships
                local opinion = getOpinion(id, otherId)
                local bond = getBond(id)
                if bond and bond.partnerId == otherId then
                    partnerNearbyStage = bond.stage
                end

                if opinion >= FRIEND_THRESHOLD then
                    friendNearby = true
                elseif opinion <= RIVAL_THRESHOLD then
                    rivalNearby = true
                    -- Chance of social fight when adjacent
                    if dist < 1.5 and math.random() < FIGHT_CHANCE_PER_TICK then
                        col.health = math.max(1, col.health - 3)
                        oCol.health = math.max(1, oCol.health - 3)
                        needs.morale = math.max(0, needs.morale - 5)
                        local oNeeds = other.needs
                        if oNeeds then
                            oNeeds.morale = math.max(0, oNeeds.morale - 5)
                        end
                        Social.adjustOpinion(id, otherId, -3)
                        logSocialEvent(string.format('%s and %s got into a fight.',
                            col.name or '?', oCol.name or '?'))
                    end
                end

                -- Discrete social events (insults, compliments, bonding)
                tryDiscreteEvent(id, otherId, col, oCol, opinion, dt)
                tryRomanceProgression(id, otherId, col, oCol, opinion)
            end
        end
    end

    -- Apply friend/rival morale modifiers (gentle per-tick application)
    if friendNearby then
        needs.morale = math.min(100, needs.morale + FRIEND_MORALE_BUFF * 0.01 * dt)
    end
    if rivalNearby then
        needs.morale = math.max(0, needs.morale + RIVAL_MORALE_PENALTY * 0.01 * dt)
    end
    if partnerNearbyStage and PARTNER_MORALE_BUFF[partnerNearbyStage] then
        needs.morale = math.min(100, needs.morale + PARTNER_MORALE_BUFF[partnerNearbyStage] * 0.01 * dt)
    end

    -- Grief from dead friends
    if grieving[id] then
        local currentDay = GameState.day + GameState.hour / 24
        local activeGrief = false
        for deadName, grief in pairs(grieving[id]) do
            local endTime = grief.endsDay + (grief.endsHour or 0) / 24
            if currentDay >= endTime then
                grieving[id][deadName] = nil
            else
                activeGrief = true
                needs.morale = math.max(0, needs.morale + grief.morale * 0.002 * dt)
            end
        end
        if not activeGrief then
            grieving[id] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Social.registerSystems()
    ECS.addSystem('social', { 'colonist', 'pos', 'needs' }, socialSystem, 14)
end

Social.registerSystems()

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Social.getState()
    return {
        opinions = opinions,
        grieving = grieving,
        bonds = bonds,
        socialLog = socialLog,
    }
end

function Social.loadState(saved)
    if not saved then return end
    opinions = saved.opinions or {}
    grieving = saved.grieving or {}
    bonds = saved.bonds or {}
    socialLog = saved.socialLog or {}
    socialEventTimers = {}  -- cooldowns reset on load (harmless)
end

return Social
