-- laws.lua — Irreversible law escalation system (Frostpunk-style)
-- Three tracks: Labor, Sustenance, Order.
-- Each track has 4 tiers of escalating severity.
-- Laws are PERMANENT once enacted — they cannot be repealed.
-- Final-tier laws cross moral event horizons.

local GameState = require('src.game_state')
local Hope      = require('src.colony.hope')

local Laws = {}

---------------------------------------------------------------------------
-- Law tree definitions
---------------------------------------------------------------------------

local LAW_TREES = {
    labor = {
        name = 'Labor Laws',
        laws = {
            {
                id = 'overtime',
                name = 'Mandatory Overtime',
                desc = 'Work shifts extended by 4 hours. Morale drains 15% faster.',
                tier = 1,
                effects = { workHoursAdd = 4, moraleDrainMult = 1.15 },
                hopeChange = -3, discontentChange = 8,
            },
            {
                id = 'double_shifts',
                name = 'Double Shifts',
                desc = 'Colonists work 18-hour days. Rest recovery halved.',
                tier = 2,
                effects = { workHoursAdd = 8, restRecoveryMult = 0.5, moraleDrainMult = 1.30 },
                hopeChange = -5, discontentChange = 15,
            },
            {
                id = 'forced_labor',
                name = 'All Hands Working',
                desc = 'No exceptions. Even wounded colonists must contribute. +40% work output.',
                tier = 3,
                effects = { workSpeedMult = 1.40, noExemptions = true, moraleDrainMult = 1.50 },
                hopeChange = -8, discontentChange = 25,
            },
            {
                id = 'penal_battalions',
                name = 'Penal Battalions',
                desc = 'Dissenting colonists forced to the front lines. No mental breaks, ever. Morale locked at 20.',
                tier = 4,
                effects = { blockMentalBreak = true, moraleLock = 20, combatBuff = 0.30 },
                hopeChange = -15, discontentChange = 40,
                crossesMoralLine = true,
            },
        },
    },
    sustenance = {
        name = 'Sustenance Laws',
        laws = {
            {
                id = 'food_rationing',
                name = 'Food Rationing',
                desc = 'Meals reduced to bare minimum. Food drain -40%. Morale -10%.',
                tier = 1,
                effects = { foodDrainMult = 0.60, moraleDrainMult = 1.10 },
                hopeChange = -2, discontentChange = 5,
            },
            {
                id = 'nutrient_paste',
                name = 'Nutrient Paste Only',
                desc = 'All food converted to grey paste. -50% food drain. No food morale bonuses.',
                tier = 2,
                effects = { foodDrainMult = 0.50, noFoodMorale = true, moraleDrainMult = 1.25 },
                hopeChange = -5, discontentChange = 12,
            },
            {
                id = 'triage_feeding',
                name = 'Triage Feeding',
                desc = 'Healthy workers fed first. Wounded and sick get leftovers.',
                tier = 3,
                effects = { foodDrainMult = 0.40, woundedFoodPenalty = 0.5 },
                hopeChange = -10, discontentChange = 20,
            },
            {
                id = 'cannibalism',
                name = 'Emergency Protein',
                desc = 'Dead colonists are... processed. +20 food per death. Massive morale impact.',
                tier = 4,
                effects = { foodPerDeath = 20, moraleDrainMult = 2.0, discontentPerDeath = -5 },
                hopeChange = -20, discontentChange = 50,
                crossesMoralLine = true,
            },
        },
    },
    order = {
        name = 'Order Laws',
        laws = {
            {
                id = 'curfew',
                name = 'Curfew',
                desc = 'No colonist movement after dark. Reduces prison breaks by 50%.',
                tier = 1,
                effects = { curfew = true, prisonBreakMult = 0.5 },
                hopeChange = -2, discontentChange = 5,
            },
            {
                id = 'propaganda',
                name = 'Propaganda',
                desc = 'Mandatory colony speeches. +10 hope, +5 discontent. Social manipulation.',
                tier = 2,
                effects = { hopeBonusPerDay = 2, discontentBonusPerDay = 1 },
                hopeChange = 10, discontentChange = 5,
            },
            {
                id = 'secret_police',
                name = 'Informants',
                desc = 'Colonists spy on each other. Social fights eliminated. Trust destroyed.',
                tier = 3,
                effects = { noSocialFights = true, socialBondRate = 0.3 },
                hopeChange = -8, discontentChange = 20,
            },
            {
                id = 'absolute_authority',
                name = 'Absolute Authority',
                desc = 'Your word is law. Discontent cannot exceed 60. Hope cannot fall below 10. Colony is broken.',
                tier = 4,
                effects = { discontentCap = 60, hopeFloor = 10, moraleLock = 25 },
                hopeChange = 0, discontentChange = 0,
                crossesMoralLine = true,
            },
        },
    },
}

Laws.LAW_TREES = LAW_TREES

---------------------------------------------------------------------------
-- State — enacted laws are permanent
---------------------------------------------------------------------------

local enacted = {}  -- { [lawId] = true }

function Laws.init()
    enacted = {}
end

function Laws.resetForNewGame()
    enacted = {}
end

---------------------------------------------------------------------------
-- Enact a law (irreversible)
---------------------------------------------------------------------------

function Laws.canEnact(treeId, lawId)
    if enacted[lawId] then return false, 'Already enacted' end

    local tree = LAW_TREES[treeId]
    if not tree then return false, 'Unknown law tree' end

    -- Find the law and check tier prerequisites
    for i, law in ipairs(tree.laws) do
        if law.id == lawId then
            -- Must have enacted all previous tiers in this tree
            if i > 1 then
                local prevLaw = tree.laws[i - 1]
                if not enacted[prevLaw.id] then
                    return false, 'Must enact ' .. prevLaw.name .. ' first'
                end
            end
            return true
        end
    end

    return false, 'Law not found in tree'
end

function Laws.enact(treeId, lawId)
    local ok, err = Laws.canEnact(treeId, lawId)
    if not ok then return false, err end

    enacted[lawId] = true

    -- Find the law definition for hope/discontent impact
    local tree = LAW_TREES[treeId]
    for _, law in ipairs(tree.laws) do
        if law.id == lawId then
            Hope.applyDelta(law.hopeChange or 0, law.discontentChange or 0)

            local Storyteller = require('src.storyteller.storyteller')
            local prefix = law.crossesMoralLine and 'MORAL EVENT: ' or 'Law Enacted: '
            Storyteller.logEvent(prefix .. law.name,
                law.name .. ' has been enacted. ' .. law.desc)
            break
        end
    end

    return true
end

function Laws.isEnacted(lawId)
    return enacted[lawId] == true
end

---------------------------------------------------------------------------
-- Computed effect accessors (read by other systems)
---------------------------------------------------------------------------

local function getLawEffect(effectName, defaultVal)
    for treeId, tree in pairs(LAW_TREES) do
        for _, law in ipairs(tree.laws) do
            if enacted[law.id] and law.effects[effectName] then
                return law.effects[effectName]
            end
        end
    end
    return defaultVal
end

local function sumLawEffect(effectName)
    local total = 0
    for treeId, tree in pairs(LAW_TREES) do
        for _, law in ipairs(tree.laws) do
            if enacted[law.id] and law.effects[effectName] then
                total = total + law.effects[effectName]
            end
        end
    end
    return total
end

local function multLawEffect(effectName)
    local mult = 1.0
    for treeId, tree in pairs(LAW_TREES) do
        for _, law in ipairs(tree.laws) do
            if enacted[law.id] and law.effects[effectName] then
                mult = mult * law.effects[effectName]
            end
        end
    end
    return mult
end

function Laws.getWorkSpeedMult()
    return multLawEffect('workSpeedMult')
end

function Laws.getFoodDrainMult()
    return multLawEffect('foodDrainMult')
end

function Laws.getMoraleDrainMult()
    return multLawEffect('moraleDrainMult')
end

function Laws.getRestRecoveryMult()
    return multLawEffect('restRecoveryMult')
end

function Laws.isMentalBreakBlocked()
    return getLawEffect('blockMentalBreak', false)
end

function Laws.getMoraleLock()
    return getLawEffect('moraleLock', nil)
end

function Laws.getDiscontentCap()
    return getLawEffect('discontentCap', nil)
end

function Laws.getHopeFloor()
    return getLawEffect('hopeFloor', nil)
end

function Laws.getPrisonBreakMult()
    return multLawEffect('prisonBreakMult')
end

function Laws.isCurfew()
    return getLawEffect('curfew', false)
end

function Laws.getWorkHoursAdd()
    return sumLawEffect('workHoursAdd')
end

function Laws.getFoodPerDeath()
    return getLawEffect('foodPerDeath', 0)
end

function Laws.hasCrossedMoralLine()
    for treeId, tree in pairs(LAW_TREES) do
        for _, law in ipairs(tree.laws) do
            if enacted[law.id] and law.crossesMoralLine then
                return true
            end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Queries for UI
---------------------------------------------------------------------------

function Laws.getTreeState(treeId)
    local tree = LAW_TREES[treeId]
    if not tree then return nil end

    local result = {
        name = tree.name,
        laws = {},
    }

    for _, law in ipairs(tree.laws) do
        result.laws[#result.laws + 1] = {
            id       = law.id,
            name     = law.name,
            desc     = law.desc,
            tier     = law.tier,
            enacted  = enacted[law.id] == true,
            canEnact = Laws.canEnact(treeId, law.id),
            crossesMoralLine = law.crossesMoralLine,
        }
    end

    return result
end

function Laws.getAllTrees()
    local result = {}
    for treeId in pairs(LAW_TREES) do
        result[#result + 1] = Laws.getTreeState(treeId)
    end
    return result
end

function Laws.getEnacted()
    local result = {}
    for lawId in pairs(enacted) do
        result[#result + 1] = lawId
    end
    return result
end

-- Serialization support
function Laws.getState()
    return enacted
end

function Laws.restoreState(state)
    enacted = state or {}
end

return Laws
