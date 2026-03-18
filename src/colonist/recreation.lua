-- recreation.lua -- Joy need and recreation building system
-- Colonists have a joy need (0-100) that decays slowly and recovers at recreation
-- buildings during free time. Low joy drags morale down.
-- ECS system: colonists near rec buildings with capacity get joy recovery.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Recreation = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local JOY_DECAY_RATE   = 0.015  -- per-tick decay when not recreating
local JOY_CRITICAL     = 20     -- below this, morale penalty kicks in
local MORALE_PENALTY   = -0.04  -- morale drain per tick when joy < critical
local SEEK_RANGE       = 20     -- max tiles to search for a rec building
local SEEK_CHANCE      = 0.02   -- per-tick chance to seek rec building during free time

---------------------------------------------------------------------------
-- Joy need management
---------------------------------------------------------------------------

--- Decay joy for all colonists. Called from step().
local function decayJoy(dt)
    -- Doctrine modifier: Order path increases joy decay
    local dok, Doc = pcall(require, 'src.colony.doctrines')
    local joyDecayMult = (dok and Doc.getJoyDecayMult and Doc.getJoyDecayMult()) or 1.0

    for id, comps in ECS.query('colonist', 'needs') do
        local needs = comps.needs
        if needs.joy == nil then needs.joy = 50 end  -- backwards compat
        -- Don't decay while sleeping or actively recreating
        if comps.colonist.state ~= 'sleeping' and comps.colonist.state ~= 'recreating' then
            needs.joy = math.max(0, needs.joy - JOY_DECAY_RATE * joyDecayMult * dt)
        end
        -- Low joy morale penalty
        if needs.joy < JOY_CRITICAL then
            needs.morale = math.max(0, needs.morale + MORALE_PENALTY * dt)
        end
    end
end

---------------------------------------------------------------------------
-- Recreation building usage
---------------------------------------------------------------------------

--- Apply joy recovery for colonists currently at a recreation building.
--- Communion doctrine boosts joy recovery from rec buildings.
local function applyJoyRecovery(dt)
    for recId, recComps in ECS.query('recreation', 'pos') do
        local rec = recComps.recreation
        local rpos = recComps.pos

        -- Clean stale users (dead, moved away, sleeping, working)
        for userId in pairs(rec.users) do
            local upos = ECS.get(userId, 'pos')
            local ucol = ECS.get(userId, 'colonist')
            local evict = false
            if not upos or not ucol or ucol.state == 'dead' then
                evict = true
            elseif ucol.state ~= 'recreating' and ucol.state ~= 'wandering' and ucol.state ~= 'idle' then
                -- No longer in free-time states (sleeping, working, etc.)
                evict = true
            else
                -- Check distance (must be within 2 tiles)
                local dx = math.abs(upos.x - rpos.x)
                local dy = math.abs(upos.y - rpos.y)
                if dx > 2 or dy > 2 then evict = true end
            end
            if evict then
                rec.users[userId] = nil
                rec.userCount = math.max(0, rec.userCount - 1)
                -- Clear colonist rec target
                if ucol then ucol._recTarget = nil end
            end
        end

        -- Recount (safety)
        local count = 0
        for _ in pairs(rec.users) do count = count + 1 end
        rec.userCount = count

        -- Apply joy to current users (with doctrine bonus)
        local dok2, Doc2 = pcall(require, 'src.colony.doctrines')
        local recJoyMult = (dok2 and Doc2.getRecJoyMult and Doc2.getRecJoyMult()) or 1.0

        for userId in pairs(rec.users) do
            local needs = ECS.get(userId, 'needs')
            if needs then
                needs.joy = math.min(100, (needs.joy or 50) + rec.joyRate * recJoyMult * dt)
            end
        end
    end
end

--- Find nearest recreation building with capacity for a colonist.
--- Returns recEntityId and position, or nil.
function Recreation.findNearest(colId)
    local cpos = ECS.get(colId, 'pos')
    if not cpos then return nil end

    local bestId, bestDist = nil, math.huge
    local bestPos = nil

    for recId, recComps in ECS.query('recreation', 'pos') do
        local rec = recComps.recreation
        local rpos = recComps.pos

        -- Skip if at capacity
        if rec.userCount >= rec.capacity then goto nextRec end
        -- Skip different depth
        if (rpos.depth or 0) ~= (cpos.depth or 0) then goto nextRec end

        local dx = cpos.x - rpos.x
        local dy = cpos.y - rpos.y
        local dist = math.abs(dx) + math.abs(dy)
        if dist < bestDist and dist <= SEEK_RANGE then
            bestId = recId
            bestDist = dist
            bestPos = rpos
        end

        ::nextRec::
    end

    return bestId, bestPos
end

--- Register a colonist as using a recreation building.
function Recreation.startUsing(colId, recId)
    local rec = ECS.get(recId, 'recreation')
    if not rec then return false end
    if rec.userCount >= rec.capacity then return false end
    rec.users[colId] = true
    rec.userCount = rec.userCount + 1
    return true
end

--- Unregister a colonist from a recreation building.
function Recreation.stopUsing(colId, recId)
    local rec = ECS.get(recId, 'recreation')
    if not rec then return end
    if rec.users[colId] then
        rec.users[colId] = nil
        rec.userCount = math.max(0, rec.userCount - 1)
    end
end

---------------------------------------------------------------------------
-- Step (called from main.lua each sim tick)
---------------------------------------------------------------------------

function Recreation.step(dt)
    if GameState.phase ~= 'playing' then return end
    decayJoy(dt)
    applyJoyRecovery(dt)
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

--- Get joy morale modifier for the comfort score.
--- Returns a value to add to morale delta (negative when joy is low).
function Recreation.getJoyMoraleMod(colId)
    local needs = ECS.get(colId, 'needs')
    if not needs or needs.joy == nil then return 0 end
    if needs.joy < JOY_CRITICAL then
        return (needs.joy - JOY_CRITICAL) * 0.05  -- up to -1.0 at joy=0
    elseif needs.joy > 70 then
        return (needs.joy - 70) * 0.02  -- small bonus when joyful
    end
    return 0
end

--- Get seek chance for work_ai to use.
function Recreation.getSeekChance()
    return SEEK_CHANCE
end

return Recreation
