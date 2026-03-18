-- expeditions.lua — Off-map expedition system
-- Send 1-3 colonists to overworld destinations. They leave the map,
-- return after a duration, and resolve with success/partial/failure
-- based on risk, party composition, equipment, and skills.
-- Max 2 concurrent expeditions.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Overworld = require('src.exploration.overworld')
local ExpMap    = require('src.exploration.expedition_map')

local Expeditions = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local activeExpeditions = {} -- list of expedition records
local MAX_CONCURRENT   = 2
local nextExpId        = 1

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Compute average skill level for a group of colonist entity IDs.
-- Returns the average of each colonist's best skill.
local function partySkillAvg(memberIds)
    local total = 0
    local count = 0
    for _, id in ipairs(memberIds) do
        local col = ECS.get(id, 'colonist')
        if col and col.skills then
            local best = 0
            for _, v in pairs(col.skills) do
                if v > best then best = v end
            end
            total = total + best
            count = count + 1
        end
    end
    if count == 0 then return 1 end
    return total / count
end

-- Compute average hunting skill (primary combat stat for expeditions).
local function partyHuntingAvg(memberIds)
    local total = 0
    local count = 0
    for _, id in ipairs(memberIds) do
        local col = ECS.get(id, 'colonist')
        if col and col.skills then
            total = total + (col.skills.hunting or 1)
            count = count + 1
        end
    end
    if count == 0 then return 1 end
    return total / count
end

-- Check if a colonist has equipment that reduces risk.
-- Returns a flat risk reduction bonus (0.0 to 0.3 per colonist).
local function equipmentBonus(id)
    local equip = ECS.get(id, 'equipment')
    if not equip then return 0 end

    local bonus = 0
    if equip.weapon then bonus = bonus + 0.08 end
    if equip.armor  then bonus = bonus + 0.06 end

    -- Clothing system outer slot provides suit bonus
    local clothing = ECS.get(id, 'clothing')
    if clothing and clothing.outer then
        local outerId = clothing.outer.id or clothing.outer.itemId
        if outerId == 'exosuit'      then bonus = bonus + 0.12 end
        if outerId == 'thermal_suit' then bonus = bonus + 0.06 end
        if outerId == 'space_suit'   then bonus = bonus + 0.08 end
        if outerId == 'diving_suit'  then bonus = bonus + 0.06 end
    end

    return bonus
end

-- Total party equipment risk reduction.
local function partyEquipBonus(memberIds)
    local total = 0
    for _, id in ipairs(memberIds) do
        total = total + equipmentBonus(id)
    end
    return total
end

-- Cold resistance trait bonus (reduces failure chance on cold destinations).
local function partyColdResist(memberIds)
    local total = 0
    for _, id in ipairs(memberIds) do
        local col = ECS.get(id, 'colonist')
        if col and col.traits then
            for _, t in ipairs(col.traits) do
                if t.coldResist then total = total + t.coldResist end
            end
        end
        local clothing = ECS.get(id, 'clothing')
        if clothing and clothing.outer and clothing.outer.coldResist then
            total = total + clothing.outer.coldResist
        end
    end
    return total
end

---------------------------------------------------------------------------
-- Outcome resolution
---------------------------------------------------------------------------

-- Calculate success probability.
-- Base 0.6, modified by risk, party size, skills, equipment.
-- Returns { successChance, partialChance, failChance } summing to 1.
local function calcOutcomeChances(expedition)
    local dest = Overworld.getDestination(expedition.destId)
    if not dest then return { success = 0.5, partial = 0.3, failure = 0.2 } end

    local risk     = dest.risk
    local members  = expedition.memberIds
    local partyN   = #members

    -- Base chance starts at 70% and drops with risk
    local base = 0.70 - risk * 0.08

    -- Party size bonus: +5% per member beyond minimum
    local sizeBonus = math.max(0, (partyN - dest.minParty)) * 0.05

    -- Skill bonus: avg hunting / 20 (max +0.5 at skill 10)
    local skillBonus = partyHuntingAvg(members) / 20

    -- Equipment bonus
    local equipBonus = partyEquipBonus(members)

    -- Cold resistance helps a bit
    local coldBonus = math.min(0.1, partyColdResist(members) * 0.1)

    -- Perk: expedition success bonus (cartographer)
    local perkBonus = 0
    local pok, Perks = pcall(require, 'src.colony.perks')
    if pok then
        perkBonus = Perks.getSumEffect('expeditionSuccessBonus')
    end

    local successChance = math.min(0.95, math.max(0.1, base + sizeBonus + skillBonus + equipBonus + coldBonus + perkBonus))

    -- Partial is 60% of remaining probability, failure is 40% of remaining
    local remaining = 1 - successChance
    local partialChance = remaining * 0.6
    local failChance    = remaining * 0.4

    return {
        success = successChance,
        partial = partialChance,
        failure = failChance,
    }
end

-- Roll outcome and produce results.
-- Returns { outcome = 'success'|'partial'|'failure', rewards = {}, injuries = {} }
local function resolveExpedition(expedition)
    local dest = Overworld.getDestination(expedition.destId)
    if not dest then
        return { outcome = 'failure', rewards = {}, injuries = {} }
    end

    local chances = calcOutcomeChances(expedition)
    local roll = math.random()

    local outcome
    if roll <= chances.success then
        outcome = 'success'
    elseif roll <= chances.success + chances.partial then
        outcome = 'partial'
    else
        outcome = 'failure'
    end

    local rewards = {}
    local injuries = {}

    if outcome == 'success' then
        rewards = Overworld.rollRewards(dest.rewards.success)
    elseif outcome == 'partial' then
        rewards = Overworld.rollRewards(dest.rewards.partial)
        -- Some members may take minor damage
        for _, id in ipairs(expedition.memberIds) do
            if math.random() < 0.3 then
                local dmg = 5 + math.random(15)
                injuries[#injuries + 1] = { entityId = id, damage = dmg }
            end
        end
    else
        -- Failure: no rewards, injuries to all, chance of death at high risk
        for _, id in ipairs(expedition.memberIds) do
            local dmg = 10 + math.random(25 + dest.risk * 5)
            local fatal = false
            if dest.risk >= 4 and math.random() < 0.15 then
                fatal = true
            elseif dest.risk >= 5 and math.random() < 0.25 then
                fatal = true
            end
            injuries[#injuries + 1] = { entityId = id, damage = dmg, fatal = fatal }
        end
    end

    return { outcome = outcome, rewards = rewards, injuries = injuries }
end

-- Resolve expedition using visual map results instead of probability roll.
-- Converts map.lootCollected and map.outcome into the same result format.
local function resolveFromMap(expedition)
    local map = expedition.map
    local outcome = map.outcome or 'partial'

    -- Convert collected loot into reward format
    local rewards = {}
    for _, loot in ipairs(map.lootCollected or {}) do
        rewards[#rewards + 1] = { itemId = loot.itemId, amount = loot.amount }
    end

    -- Also roll destination-specific rewards based on outcome tier
    local dest = Overworld.getDestination(expedition.destId)
    if dest and outcome ~= 'failure' then
        local tier = outcome == 'success' and 'success' or 'partial'
        if dest.rewards[tier] then
            local extra = Overworld.rollRewards(dest.rewards[tier])
            for _, r in ipairs(extra) do
                rewards[#rewards + 1] = r
            end
        end
    end

    -- Injuries from lost encounters
    local injuries = {}
    if map.encountersLost and map.encountersLost > 0 then
        for _, id in ipairs(expedition.memberIds) do
            if math.random() < 0.5 * map.encountersLost / #expedition.memberIds then
                local dmg = 5 + math.random(15 + expedition.risk * 3)
                injuries[#injuries + 1] = { entityId = id, damage = dmg }
            end
        end
    end

    -- Failure outcome: extra injuries
    if outcome == 'failure' then
        for _, id in ipairs(expedition.memberIds) do
            local dmg = 10 + math.random(20)
            local fatal = expedition.risk >= 4 and math.random() < 0.12
            injuries[#injuries + 1] = { entityId = id, damage = dmg, fatal = fatal }
        end
    end

    return { outcome = outcome, rewards = rewards, injuries = injuries }
end

local function applyContainmentFindings(expedition, result)
    local findings = Overworld.rollContainmentFinds and Overworld.rollContainmentFinds(expedition.destId, result.outcome) or {}
    if not findings or #findings == 0 then
        result.findings = {}
        return
    end

    local cok, Containment = pcall(require, 'src.sim.containment')
    if not cok or not Containment.registerFieldSubject then
        result.findings = {}
        return
    end

    local recovered = {}
    for _, entry in ipairs(findings) do
        local overrides = {}
        for k, v in pairs(entry.overrides or {}) do
            overrides[k] = v
        end
        overrides.source = overrides.source or (expedition.destName .. ' expedition')
        local subject = Containment.registerFieldSubject(entry.template, overrides)
        if subject then
            recovered[#recovered + 1] = subject
        end
    end
    result.findings = recovered

    if #recovered > 0 then
        local aok, Anomaly = pcall(require, 'src.sim.anomaly')
        if aok and Anomaly.addAnomaly then
            Anomaly.addAnomaly(1 + #recovered, 'expedition_find')
        end
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Expeditions.init()
    activeExpeditions = {}
    nextExpId = 1
end

function Expeditions.getActive()
    return activeExpeditions
end

function Expeditions.getActiveCount()
    return #activeExpeditions
end

function Expeditions.canLaunch()
    return #activeExpeditions < MAX_CONCURRENT
end

-- Validate that a launch is possible. Returns true or false, errorMsg.
function Expeditions.validateLaunch(destId, memberIds)
    if not Expeditions.canLaunch() then
        return false, 'Maximum concurrent expeditions reached'
    end

    local dest = Overworld.getDestination(destId)
    if not dest then
        return false, 'Unknown destination'
    end

    if not memberIds or #memberIds == 0 then
        return false, 'No colonists assigned'
    end

    if #memberIds > 3 then
        return false, 'Maximum party size is 3'
    end

    if #memberIds < dest.minParty then
        return false, string.format('Minimum %d colonists required', dest.minParty)
    end

    -- Verify all members are alive, present, and not already on expedition
    for _, id in ipairs(memberIds) do
        if not ECS.isAlive(id) then
            return false, 'Colonist no longer alive'
        end
        local col = ECS.get(id, 'colonist')
        if not col then
            return false, 'Invalid colonist'
        end
        if col.state == 'dead' or col.state == 'away_expedition' then
            return false, col.name .. ' is unavailable'
        end
    end

    return true
end

-- Launch an expedition. Returns expedition ID or nil, error.
function Expeditions.launch(destId, memberIds)
    local ok, err = Expeditions.validateLaunch(destId, memberIds)
    if not ok then return nil, err end

    local dest = Overworld.getDestination(destId)
    local expId = nextExpId
    nextExpId = nextExpId + 1

    local expedition = {
        id          = expId,
        destId      = destId,
        destName    = dest.name,
        memberIds   = memberIds,
        memberNames = {},
        duration    = dest.duration,
        elapsed     = 0,
        risk        = dest.risk,
        state       = 'travelling', -- travelling, returning, resolved
        result      = nil,
    }

    -- Flag each colonist as away
    for _, id in ipairs(memberIds) do
        local col = ECS.get(id, 'colonist')
        if col then
            expedition.memberNames[#expedition.memberNames + 1] = col.name
            col.state = 'away_expedition'
            col.task  = nil
        end
        -- Remove from pathfinding / movement
        local path = ECS.get(id, 'path')
        if path then
            path.nodes = nil
            path.index = 1
            path.moveTimer = 0
        end
        -- Flag entity so other systems skip it
        ECS.set(id, 'away', { expeditionId = expId })
    end

    -- Generate visual expedition map
    expedition.map = ExpMap.generate(destId, dest.risk, memberIds, expedition.memberNames)

    activeExpeditions[#activeExpeditions + 1] = expedition

    -- Log the departure
    local Storyteller = require('src.storyteller.storyteller')
    local names = table.concat(expedition.memberNames, ', ')
    Storyteller.logEvent('Expedition Launched',
        string.format('%s departed for %s.', names, dest.name))

    return expId
end

-- Apply resolved results: add resources, apply injuries, restore colonists.
local function applyResults(expedition)
    local result = expedition.result
    if not result then return end

    -- Grant rewards as colony resources
    -- Map item IDs to GameState resource keys where they overlap;
    -- otherwise treat them as Production.ITEMS drops via Items.spawn fallback.
    local RESOURCE_MAP = {
        raw_wood     = 'wood',
        raw_stone    = 'stone',
        raw_ore      = 'metal',
        raw_meat     = 'food',
        thermal_core = 'thermalCores',
        coal         = 'fuel',
        fuel_cell    = 'fuel',
    }

    local iOk, Items = pcall(require, 'src.world.items')
    for _, r in ipairs(result.rewards) do
        local resKey = RESOURCE_MAP[r.itemId]
        local cx = GameState.startX + math.random(-3, 3)
        local cy = GameState.startY + math.random(-3, 3)
        if iOk and Items and Items.spawn then
            -- All rewards spawn as physical items near colony center
            local spawnId = resKey or r.itemId
            Items.spawn(cx, cy, spawnId, r.amount, nil, 0)
        elseif resKey then
            GameState.addResource(resKey, r.amount)
        else
            -- Fallback: dump into components
            GameState.addResource('components', math.ceil(r.amount * 0.5))
        end
    end

    applyContainmentFindings(expedition, result)

    -- Apply injuries / deaths
    for _, inj in ipairs(result.injuries) do
        local id = inj.entityId
        if ECS.isAlive(id) then
            local col = ECS.get(id, 'colonist')
            if col then
                if inj.fatal then
                    ECS.remove(id, 'away')
                    local cOk, ColMod = pcall(require, 'src.colonist.colonist')
                    if cOk then ColMod.kill(id) end
                else
                    col.health = math.max(1, col.health - inj.damage)
                end
            end
        end
    end

    -- Restore surviving colonists to the map
    for _, id in ipairs(expedition.memberIds) do
        if ECS.isAlive(id) then
            local col = ECS.get(id, 'colonist')
            if col and col.state == 'away_expedition' then
                col.state = 'idle'
                col.task  = nil
            end
            ECS.remove(id, 'away')
            -- Place them back near colony center
            local pos = ECS.get(id, 'pos')
            if pos then
                pos.x = GameState.startX + math.random(-3, 3)
                pos.y = GameState.startY + math.random(-3, 3)
                pos.prevX = pos.x
                pos.prevY = pos.y
            end
        end
    end

    -- Notify quest system
    local qok, QuestMod = pcall(require, 'src.quest.quest')
    if qok and QuestMod.onExpeditionComplete then
        QuestMod.onExpeditionComplete(expedition.destId)
    end

    -- Log outcome
    local Storyteller = require('src.storyteller.storyteller')
    local names = table.concat(expedition.memberNames, ', ')
    if result.outcome == 'success' then
        Storyteller.logEvent('Expedition Success',
            string.format('%s returned from %s with a haul of supplies!',
                names, expedition.destName))
    elseif result.outcome == 'partial' then
        Storyteller.logEvent('Expedition Partial',
            string.format('%s returned from %s, battered but carrying some supplies.',
                names, expedition.destName))
    else
        local fatalCount = 0
        for _, inj in ipairs(result.injuries) do
            if inj.fatal then fatalCount = fatalCount + 1 end
        end
        if fatalCount > 0 then
            Storyteller.logEvent('Expedition Disaster',
                string.format('Expedition to %s failed. %d colonist(s) lost.',
                    expedition.destName, fatalCount))
        else
            Storyteller.logEvent('Expedition Failed',
                string.format('%s returned from %s empty-handed and wounded.',
                    names, expedition.destName))
        end
    end

    if result.findings and #result.findings > 0 then
        local labels = {}
        for _, subject in ipairs(result.findings) do
            labels[#labels + 1] = subject.label or subject.name or 'specimen'
        end
        Storyteller.logEvent('Expedition Recovery',
            string.format('%s also returned from %s with containment cargo: %s.',
                names, expedition.destName, table.concat(labels, ', ')))
    end
end

---------------------------------------------------------------------------
-- Update — called each sim tick
---------------------------------------------------------------------------

function Expeditions.step(dt)
    local resolved = {}

    for i, exp in ipairs(activeExpeditions) do
        if exp.state == 'travelling' then
            exp.elapsed = exp.elapsed + dt

            -- Advance visual map simulation
            if exp.map then
                ExpMap.step(exp.map, dt)
                -- Map completed — use its results instead of timer roll
                if exp.map.completed then
                    exp.state = 'resolved'
                    exp.result = resolveFromMap(exp)
                    applyResults(exp)
                    resolved[#resolved + 1] = i
                end
            end

            -- Fallback: timer expiry for maps that haven't completed yet
            if exp.state == 'travelling' and exp.elapsed >= exp.duration then
                if exp.map then
                    exp.map.completed = true
                    exp.map.outcome = exp.map.outcome or 'partial'
                end
                exp.state  = 'resolved'
                exp.result = exp.map and resolveFromMap(exp) or resolveExpedition(exp)
                applyResults(exp)
                resolved[#resolved + 1] = i
            end
        end
    end

    -- Remove resolved expeditions (iterate in reverse to preserve indices)
    for i = #resolved, 1, -1 do
        table.remove(activeExpeditions, resolved[i])
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

-- Get expedition by ID.
function Expeditions.getById(expId)
    for _, exp in ipairs(activeExpeditions) do
        if exp.id == expId then return exp end
    end
    return nil
end

-- Get remaining time for an expedition.
function Expeditions.getRemaining(expId)
    local exp = Expeditions.getById(expId)
    if not exp then return 0 end
    return math.max(0, exp.duration - exp.elapsed)
end

-- Get progress as 0-1 fraction.
function Expeditions.getProgress(expId)
    local exp = Expeditions.getById(expId)
    if not exp then return 1 end
    if exp.duration <= 0 then return 1 end
    return math.min(1, exp.elapsed / exp.duration)
end

-- Check if a colonist is currently on an expedition.
function Expeditions.isOnExpedition(entityId)
    return ECS.has(entityId, 'away')
end

-- Get all available (not away, not dead) colonists for expedition selection.
function Expeditions.getAvailableColonists()
    local result = {}
    for id, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.state ~= 'away_expedition' and not ECS.has(id, 'away') then
            result[#result + 1] = { id = id, name = col.name, skills = col.skills }
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Expeditions.getState()
    -- Serialize visual maps alongside expedition records
    local savedExps = {}
    for _, exp in ipairs(activeExpeditions) do
        local copy = {}
        for k, v in pairs(exp) do
            if k == 'map' then
                copy.map = ExpMap.serialize(v)
            else
                copy[k] = v
            end
        end
        savedExps[#savedExps + 1] = copy
    end
    return {
        activeExpeditions = savedExps,
        nextExpId         = nextExpId,
    }
end

function Expeditions.loadState(saved)
    if not saved then return end
    activeExpeditions = saved.activeExpeditions or {}
    nextExpId         = saved.nextExpId or 1
    -- Restore visual map proxies
    for _, exp in ipairs(activeExpeditions) do
        if exp.map then
            exp.map = ExpMap.deserialize(exp.map)
        end
    end
end

return Expeditions
