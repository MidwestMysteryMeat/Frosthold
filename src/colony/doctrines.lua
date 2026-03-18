-- doctrines.lua -- Doctrine tree system (Order / Communion / Solidarity)
-- Three mutually exclusive paths, each with 3 tiers of passive effects.
-- Doctrine points earned 1/day when hope >= 50. Tiers cost 1/2/3 points.
-- Choosing any tier 1 locks out the other two paths permanently.
-- Effects queried by other systems via accessor functions.

local GameState = require('src.game_state')

local Doctrines = {}

---------------------------------------------------------------------------
-- Definitions
---------------------------------------------------------------------------

local PATHS = {
    order = {
        id = 'order',
        name = 'Order',
        desc = 'Discipline and productivity at the cost of personal freedom.',
        tiers = {
            {
                id = 'iron_schedule',
                name = 'Iron Schedule',
                desc = 'Work speed +10%. Free time reduced to 2 hours.',
                cost = 1,
                effects = { workSpeedMult = 1.10, freeTimeHours = 2 },
            },
            {
                id = 'drill_regimen',
                name = 'Drill Regimen',
                desc = 'Mining and building speed +15%. Joy decays 20% faster.',
                cost = 2,
                effects = { miningSpeedMult = 1.15, joyDecayMult = 1.20 },
            },
            {
                id = 'chain_of_command',
                name = 'Chain of Command',
                desc = 'Critical jobs auto-prioritized. Mental breaks suppressed above morale 15.',
                cost = 3,
                effects = { autoPrioritize = true, mentalBreakThreshold = 15 },
            },
        },
    },
    communion = {
        id = 'communion',
        name = 'Communion',
        desc = 'Community bonds and shared purpose sustain morale.',
        tiers = {
            {
                id = 'shared_hearth',
                name = 'Shared Hearth',
                desc = 'Recreation gives +30% joy. Food drain +10%.',
                cost = 1,
                effects = { recJoyMult = 1.30, foodDrainMult = 1.10 },
            },
            {
                id = 'memorial_rites',
                name = 'Memorial Rites',
                desc = 'Death morale penalty halved. Memorial buildings give 2x beauty.',
                cost = 2,
                effects = { deathMoraleMult = 0.5, memorialBeautyMult = 2.0 },
            },
            {
                id = 'common_purpose',
                name = 'Common Purpose',
                desc = 'Hope decays 50% slower. Policy discontent reduced 30%.',
                cost = 3,
                effects = { hopeDecayMult = 0.5, policyDiscontentMult = 0.7 },
            },
        },
    },
    solidarity = {
        id = 'solidarity',
        name = 'Solidarity',
        desc = 'Collective survival through shared burden and mutual aid.',
        tiers = {
            {
                id = 'fair_rations',
                name = 'Fair Rations',
                desc = 'Food need equalizes across colonists. Hauling speed +15%.',
                cost = 1,
                effects = { foodEqualize = true, haulingSpeedMult = 1.15 },
            },
            {
                id = 'night_watch',
                name = 'Night Watch',
                desc = 'Night shift workers get +10 morale instead of penalty.',
                cost = 2,
                effects = { nightMoraleBonus = 10 },
            },
            {
                id = 'stand_together',
                name = 'Stand Together',
                desc = 'Colonists within 3 tiles of allies take 15% less damage.',
                cost = 3,
                effects = { proximityDamageReduction = 0.15, proximityRange = 3 },
            },
        },
    },
}

local PATH_ORDER = { 'order', 'communion', 'solidarity' }

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local chosenPath    = nil    -- 'order' | 'communion' | 'solidarity' | nil
local unlockedTiers = {}     -- { [pathId] = maxTierUnlocked (1-3) }
local doctrinePoints = 0     -- accumulated points
local lastPointDay   = 0     -- last day a point was earned

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Doctrines.init()
    chosenPath = nil
    unlockedTiers = {}
    doctrinePoints = 0
    lastPointDay = 0
end

---------------------------------------------------------------------------
-- Step (called from main.lua each sim tick)
---------------------------------------------------------------------------

function Doctrines.step(dt)
    if GameState.phase ~= 'playing' then return end

    -- Earn 1 doctrine point per day when hope >= 50
    local ok, Hope = pcall(require, 'src.colony.hope')
    local hope = ok and Hope.getHope and Hope.getHope() or 50

    if hope >= 50 and GameState.day > lastPointDay then
        local gained = GameState.day - lastPointDay
        doctrinePoints = doctrinePoints + gained
        lastPointDay = GameState.day
    end
end

---------------------------------------------------------------------------
-- Unlock
---------------------------------------------------------------------------

--- Attempt to unlock the next tier of a path.
--- Returns true on success, false + reason on failure.
function Doctrines.unlock(pathId)
    local pathDef = PATHS[pathId]
    if not pathDef then return false, 'Unknown path' end

    local currentTier = unlockedTiers[pathId] or 0
    local nextTier = currentTier + 1

    if nextTier > #pathDef.tiers then
        return false, 'Path fully unlocked'
    end

    -- Check path exclusivity
    if nextTier == 1 and chosenPath and chosenPath ~= pathId then
        return false, 'Already committed to ' .. PATHS[chosenPath].name
    end

    local tierDef = pathDef.tiers[nextTier]
    if doctrinePoints < tierDef.cost then
        return false, 'Need ' .. tierDef.cost .. ' doctrine points (have ' .. doctrinePoints .. ')'
    end

    -- Commit
    doctrinePoints = doctrinePoints - tierDef.cost
    unlockedTiers[pathId] = nextTier
    if nextTier == 1 then
        chosenPath = pathId
    end

    return true
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Doctrines.getChosenPath()
    return chosenPath
end

function Doctrines.getPoints()
    return doctrinePoints
end

function Doctrines.getTier(pathId)
    return unlockedTiers[pathId] or 0
end

--- Check if a specific effect is active and return its value.
--- Scans from highest unlocked tier downward so higher tiers can override.
function Doctrines.getEffect(effectName)
    if not chosenPath then return nil end
    local pathDef = PATHS[chosenPath]
    if not pathDef then return nil end
    local maxTier = unlockedTiers[chosenPath] or 0
    for i = maxTier, 1, -1 do
        local val = pathDef.tiers[i].effects[effectName]
        if val ~= nil then return val end
    end
    return nil
end

--- Get all paths data for UI.
function Doctrines.getAllPaths()
    local result = {}
    for _, pid in ipairs(PATH_ORDER) do
        local p = PATHS[pid]
        result[#result + 1] = {
            id = p.id,
            name = p.name,
            desc = p.desc,
            tiers = p.tiers,
            currentTier = unlockedTiers[pid] or 0,
            locked = chosenPath ~= nil and chosenPath ~= pid,
        }
    end
    return result
end

function Doctrines.getPathOrder()
    return PATH_ORDER
end

---------------------------------------------------------------------------
-- Effect accessors (called by other systems)
---------------------------------------------------------------------------

function Doctrines.getWorkSpeedMult()
    return Doctrines.getEffect('workSpeedMult') or 1.0
end

function Doctrines.getMiningSpeedMult()
    return Doctrines.getEffect('miningSpeedMult') or 1.0
end

function Doctrines.getJoyDecayMult()
    return Doctrines.getEffect('joyDecayMult') or 1.0
end

function Doctrines.getRecJoyMult()
    return Doctrines.getEffect('recJoyMult') or 1.0
end

function Doctrines.getFoodDrainMult()
    return Doctrines.getEffect('foodDrainMult') or 1.0
end

function Doctrines.getHaulingSpeedMult()
    return Doctrines.getEffect('haulingSpeedMult') or 1.0
end

function Doctrines.getHopeDecayMult()
    return Doctrines.getEffect('hopeDecayMult') or 1.0
end

function Doctrines.getPolicyDiscontentMult()
    return Doctrines.getEffect('policyDiscontentMult') or 1.0
end

function Doctrines.getDeathMoraleMult()
    return Doctrines.getEffect('deathMoraleMult') or 1.0
end

function Doctrines.getNightMoraleBonus()
    return Doctrines.getEffect('nightMoraleBonus') or 0
end

function Doctrines.getProximityDamageReduction()
    return Doctrines.getEffect('proximityDamageReduction') or 0
end

function Doctrines.getProximityRange()
    return Doctrines.getEffect('proximityRange') or 0
end

function Doctrines.getMentalBreakThreshold()
    return Doctrines.getEffect('mentalBreakThreshold') or 0
end

function Doctrines.shouldAutoPrioritize()
    return Doctrines.getEffect('autoPrioritize') or false
end

function Doctrines.shouldEqualizeFood()
    return Doctrines.getEffect('foodEqualize') or false
end

function Doctrines.getFreeTimeHours()
    return Doctrines.getEffect('freeTimeHours')
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Doctrines.getState()
    return {
        chosenPath     = chosenPath,
        unlockedTiers  = unlockedTiers,
        doctrinePoints = doctrinePoints,
        lastPointDay   = lastPointDay,
    }
end

function Doctrines.loadState(saved)
    if not saved then return end
    chosenPath = saved.chosenPath
    -- Validate chosenPath against known paths (guard corrupt/migrated saves)
    if chosenPath and not PATHS[chosenPath] then
        chosenPath = nil
    end
    unlockedTiers  = saved.unlockedTiers or {}
    doctrinePoints = saved.doctrinePoints or 0
    lastPointDay   = saved.lastPointDay or 0
end

return Doctrines
