-- perks.lua — Cornerstone perks (Against the Storm style)
-- At colony founding and research milestones, player chooses from
-- randomized perks that modify core systems. Each run plays differently.

local GameState = require('src.game_state')

local Perks = {}

---------------------------------------------------------------------------
-- Perk definitions
---------------------------------------------------------------------------

local PERK_DEFS = {
    -- Thermal perks
    permafrost_mastery = {
        id   = 'permafrost_mastery',
        name = 'Permafrost Mastery',
        desc = 'Ice walls provide +50% insulation.',
        category = 'thermal',
        effects = { wallInsulationMult = 1.5 },
    },
    cold_blooded = {
        id   = 'cold_blooded',
        name = 'Cold-Blooded Efficiency',
        desc = 'Colonists work 20% faster below -10°C but morale decays 2x faster in cold.',
        category = 'thermal',
        effects = { coldWorkBonus = 0.20, coldMoralePenalty = 2.0 },
    },
    volcanic_affinity = {
        id   = 'volcanic_affinity',
        name = 'Volcanic Affinity',
        desc = 'Lava vents produce 50% more heat. Generators use 20% less fuel.',
        category = 'thermal',
        effects = { lavaHeatMult = 1.5, fuelUseMult = 0.80 },
    },

    -- Resource perks
    scavenger_instinct = {
        id   = 'scavenger_instinct',
        name = 'Scavenger Instinct',
        desc = 'Expeditions find 50% more loot but take 25% longer.',
        category = 'exploration',
        effects = { expeditionLootMult = 1.5, expeditionTimeMult = 1.25 },
    },
    deep_veins = {
        id   = 'deep_veins',
        name = 'Deep Veins',
        desc = 'Mining yields +1 ore per action. Deep strata sometimes expose thermal seams.',
        category = 'resource',
        effects = { miningBonusOre = 1, thermalCoreChance = 0.10 },
    },
    efficient_smelting = {
        id   = 'efficient_smelting',
        name = 'Efficient Smelting',
        desc = 'Smelting recipes produce +50% output.',
        category = 'production',
        effects = { smeltingOutputMult = 1.5 },
    },

    -- Colony perks
    natural_leaders = {
        id   = 'natural_leaders',
        name = 'Natural Leaders',
        desc = 'Colonists gain skills 25% faster. Morale floor raised to 15.',
        category = 'colony',
        effects = { skillGainMult = 1.25, moraleFloor = 15 },
    },
    hardy_stock = {
        id   = 'hardy_stock',
        name = 'Hardy Stock',
        desc = 'All colonists start with +20 max HP. Cold resistance +10%.',
        category = 'colony',
        effects = { maxHpBonus = 20, coldResistBonus = 0.10 },
    },
    rapid_recovery = {
        id   = 'rapid_recovery',
        name = 'Rapid Recovery',
        desc = 'Wound healing speed doubled. Disease immunity builds 30% faster.',
        category = 'medical',
        effects = { healSpeedMult = 2.0, immunityGainMult = 1.30 },
    },

    -- Combat perks
    fortified_walls = {
        id   = 'fortified_walls',
        name = 'Fortified Walls',
        desc = 'Stone and metal walls have +50% HP. Raids arrive 20% slower.',
        category = 'combat',
        effects = { wallHpMult = 1.5, raidIntervalMult = 1.20 },
    },
    guerrilla_tactics = {
        id   = 'guerrilla_tactics',
        name = 'Guerrilla Tactics',
        desc = 'Colonists deal +25% damage but take +15% more damage.',
        category = 'combat',
        effects = { damageDealMult = 1.25, damageTakeMult = 1.15 },
    },
    beast_whisperer = {
        id   = 'beast_whisperer',
        name = 'Beast Whisperer',
        desc = 'Passive creatures never aggro. Hunting yields +50% meat.',
        category = 'combat',
        effects = { passiveNoAggro = true, huntMeatMult = 1.5 },
    },

    -- Production perks
    master_crafters = {
        id   = 'master_crafters',
        name = 'Master Crafters',
        desc = 'All crafting 30% faster. Artifacts have +20% stat bonuses.',
        category = 'production',
        effects = { craftSpeedMult = 1.30, artifactBonusMult = 1.20 },
    },
    agricultural_expert = {
        id   = 'agricultural_expert',
        name = 'Agricultural Expert',
        desc = 'Crops grow 40% faster. Harvest yields +2 per crop.',
        category = 'production',
        effects = { cropGrowthMult = 1.40, harvestBonusFlat = 2 },
    },

    -- Exploration perks
    cartographer = {
        id   = 'cartographer',
        name = 'Cartographer',
        desc = 'Expedition success chance +15%. Discovered sites yield map data.',
        category = 'exploration',
        effects = { expeditionSuccessBonus = 0.15 },
    },
    vehicle_expert = {
        id   = 'vehicle_expert',
        name = 'Vehicle Expert (Legacy)',
        desc = 'Archived cut-scope perk retained only for compatibility with older saves.',
        category = 'exploration',
        effects = { vehicleCostMult = 0.70, vehicleSpeedMult = 1.20 },
        archived = true,
    },
}

Perks.PERK_DEFS = PERK_DEFS

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local activePerks = {}        -- { [perkId] = true }
local perkChoicesOffered = 0  -- how many times choices have been offered

---------------------------------------------------------------------------
-- Perk selection
---------------------------------------------------------------------------

-- Generate N random perk choices (no duplicates, no already-active)
function Perks.generateChoices(count)
    count = count or 3
    local available = {}
    for perkId, def in pairs(PERK_DEFS) do
        if not activePerks[perkId] and not def.archived then
            available[#available + 1] = def
        end
    end

    -- Shuffle and pick
    for i = #available, 2, -1 do
        local j = math.random(i)
        available[i], available[j] = available[j], available[i]
    end

    local choices = {}
    for i = 1, math.min(count, #available) do
        choices[#choices + 1] = available[i]
    end

    return choices
end

function Perks.activate(perkId)
    if not PERK_DEFS[perkId] then return false end
    if activePerks[perkId] then return false end

    activePerks[perkId] = true
    perkChoicesOffered = perkChoicesOffered + 1
    return true
end

function Perks.isActive(perkId)
    return activePerks[perkId] == true
end

function Perks.getActive()
    local result = {}
    for perkId in pairs(activePerks) do
        result[#result + 1] = PERK_DEFS[perkId]
    end
    return result
end

---------------------------------------------------------------------------
-- Effect queries (called by other systems)
---------------------------------------------------------------------------

function Perks.getEffect(effectName, default)
    for perkId in pairs(activePerks) do
        local def = PERK_DEFS[perkId]
        if def and def.effects[effectName] ~= nil then
            return def.effects[effectName]
        end
    end
    return default
end

function Perks.getMultEffect(effectName)
    local mult = 1.0
    for perkId in pairs(activePerks) do
        local def = PERK_DEFS[perkId]
        if def and def.effects[effectName] then
            mult = mult * def.effects[effectName]
        end
    end
    return mult
end

function Perks.getSumEffect(effectName)
    local total = 0
    for perkId in pairs(activePerks) do
        local def = PERK_DEFS[perkId]
        if def and def.effects[effectName] then
            total = total + def.effects[effectName]
        end
    end
    return total
end

function Perks.hasBoolEffect(effectName)
    for perkId in pairs(activePerks) do
        local def = PERK_DEFS[perkId]
        if def and def.effects[effectName] then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Milestone tracking — offer perks at research milestones
---------------------------------------------------------------------------

function Perks.shouldOfferChoice()
    local Research = require('src.research.research')
    local completed = Research.getTotalCompleted()
    -- Offer a perk every 5 completed research nodes
    local expectedOffers = math.floor(completed / 5)
    return expectedOffers > perkChoicesOffered
end

function Perks.getChoicesOffered()
    return perkChoicesOffered
end

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

function Perks.getState()
    return {
        active = activePerks,
        offered = perkChoicesOffered,
    }
end

function Perks.restoreState(state)
    if not state then return end
    activePerks = state.active or {}
    perkChoicesOffered = state.offered or 0
end

function Perks.init()
    activePerks = {}
    perkChoicesOffered = 0
end

return Perks
