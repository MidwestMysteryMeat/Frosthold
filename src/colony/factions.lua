-- factions.lua — Faction diplomacy system (Kenshi/Caves of Qud style)
-- Multiple surviving groups on the planet with reputation, trade modifiers,
-- and faction-sourced raids when hostile.

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

local Factions = {}

---------------------------------------------------------------------------
-- Faction definitions
---------------------------------------------------------------------------

local FACTION_DEFS = {
    mammona_logistics = {
        id          = 'mammona_logistics',
        name        = 'Mammona Logistics',
        desc        = 'Mammona\'s supply chain arm. Controls drops, enforces quotas.',
        tradeGoods  = { 'fuel', 'thermalCores', 'coal' },
        priceMult   = 0.85,
        hostileMult = 1.20,
        raidSpecies = { 'mammona_enforcer', 'mammona_heavy' },
        giftPreference = 'fuel',
        corePriceMult = 1.2,  -- standard corporate value on thermal cores
    },
    mastema_ops = {
        id          = 'mastema_ops',
        name        = 'MasTema Incorporated',
        desc        = 'Mammona\'s black operations subsidiary. Asset recovery and wetwork.',
        tradeGoods  = { 'metal', 'components', 'steel' },
        priceMult   = 0.75,
        hostileMult = 1.40,
        raidSpecies = { 'mastema_operative', 'mastema_sniper', 'mastema_breacher' },
        giftPreference = 'thermalCores',
        corePriceMult = 1.5,  -- black ops prize cores for weapon R&D
    },
    scavenger_crews = {
        id          = 'scavenger_crews',
        name        = 'Scavenger Crews',
        desc        = 'Survivors of prior colony attempts. Salvage what Mammona left behind.',
        tradeGoods  = { 'food', 'hide', 'wood' },
        priceMult   = 0.80,
        hostileMult = 1.30,
        raidSpecies = { 'scav_militia', 'scav_scrapper', 'scav_sharpshooter' },
        giftPreference = 'food',
        corePriceMult = 0.8,  -- limited use for low-tech groups
    },
    ruin_delvers = {
        id          = 'ruin_delvers',
        name        = 'Ruin Delvers',
        desc        = 'Explorers who map precursor sites beneath the ice. Trade data and artifacts.',
        tradeGoods  = { 'thermalCores', 'components' },
        priceMult   = 0.70,
        hostileMult = 1.50,
        raidSpecies = {},
        giftPreference = 'components',
        researchBonus = 0.10,
        anomalyBonus   = true,  -- unlocks anomaly events when allied
        corePriceMult = 1.8,  -- core experts, highest valuation
    },
    rim_runners = {
        id          = 'rim_runners',
        name        = 'Rim Runners',
        desc        = 'Independent traders with no corporate ties. Go where the credits are.',
        tradeGoods  = { 'components', 'circuit' },
        priceMult   = 0.90,
        hostileMult = 1.15,
        raidSpecies = {},
        giftPreference = 'components',
        researchBonus = 0.15,
        corePriceMult = 1.0,  -- neutral market rate
    },
    black_maw = {
        id          = 'black_maw',
        name        = 'Black Maw',
        desc        = 'Pirate militia from the Edge of Oblivion. Control freight corridors by force.',
        tradeGoods  = { 'fuel', 'metal', 'steel' },
        priceMult   = 0.70,
        hostileMult = 1.50,
        raidSpecies = { 'maw_raider', 'maw_breacher', 'maw_heavy' },
        giftPreference = 'fuel',
        corePriceMult = 1.3,  -- pirates know the value
    },
    void_serpents = {
        id          = 'void_serpents',
        name        = 'Void Serpents',
        desc        = 'Pirate intelligence operatives. Trade in information and stolen goods.',
        tradeGoods  = { 'components', 'circuit' },
        priceMult   = 0.75,
        hostileMult = 1.35,
        raidSpecies = { 'serpent_infiltrator', 'serpent_saboteur' },
        giftPreference = 'thermalCores',
        researchBonus = 0.10,
        corePriceMult = 1.4,  -- intel on core sources
    },
    rust_reavers = {
        id          = 'rust_reavers',
        name        = 'Rust Reavers',
        desc        = 'Scavenger-engineers from the Edge of Oblivion. Strip anything for parts.',
        tradeGoods  = { 'metal', 'components', 'steel' },
        priceMult   = 0.80,
        hostileMult = 1.25,
        raidSpecies = { 'reaver_scrapper', 'reaver_welder' },
        giftPreference = 'metal',
        corePriceMult = 0.9,  -- care more about raw materials than cores
    },
    zenith_syndicate = {
        id          = 'zenith_syndicate',
        name        = 'Zenith Syndicate',
        desc        = 'Crime syndicate that expanded from Rhea-2. Extortion and resource seizure.',
        tradeGoods  = { 'food', 'fuel' },
        priceMult   = 0.65,
        hostileMult = 1.45,
        raidSpecies = { 'zenith_thug', 'zenith_gunner', 'zenith_enforcer' },
        giftPreference = 'thermalCores',
        corePriceMult = 1.6,  -- fence stolen cores at premium
    },
    solar_nomads = {
        id          = 'solar_nomads',
        name        = 'Solar Nomads',
        desc        = 'Wandering traders from Rhea-2. Travel light, trade fair, never stay long.',
        tradeGoods  = { 'food', 'hide', 'fuel' },
        priceMult   = 0.85,
        hostileMult = 1.10,
        raidSpecies = {},
        giftPreference = 'food',
        corePriceMult = 1.1,  -- modest valuation
    },
    sons_of_pale_moon = {
        id          = 'sons_of_pale_moon',
        name        = 'Sons of the Pale Moon',
        desc        = 'Cult from Rhea-2. Followed the signal to Erebus. Obsessed with what sleeps below.',
        tradeGoods  = { 'thermalCores' },
        priceMult   = 0.60,
        hostileMult = 1.60,
        raidSpecies = { 'pale_moon_zealot', 'pale_moon_priest' },
        giftPreference = 'thermalCores',
        anomalyBonus   = true,  -- cult faction, unlocks anomaly events
        corePriceMult = 2.0,   -- cores have religious significance
    },
}

Factions.FACTION_DEFS = FACTION_DEFS

---------------------------------------------------------------------------
-- Corporate group linkage
-- Factions in the same group share reputation changes at a reduced rate.
-- MasTema is Mammona's subsidiary — hostility toward one affects the other.
---------------------------------------------------------------------------

local CORPORATE_GROUPS = {
    mammona = { 'mammona_logistics', 'mastema_ops' },
}

-- Reverse lookup: factionId -> list of sibling factionIds
local GROUP_SIBLINGS = {}
for _, members in pairs(CORPORATE_GROUPS) do
    for _, fid in ipairs(members) do
        GROUP_SIBLINGS[fid] = members
    end
end

---------------------------------------------------------------------------
-- Reputation state (-100 to 100)
-- < -50: hostile, -50 to -10: unfriendly, -10 to 10: neutral,
-- 10 to 50: friendly, > 50: allied
---------------------------------------------------------------------------

local reputation = {}  -- { [factionId] = number }

local REP_THRESHOLDS = {
    hostile    = -50,
    unfriendly = -10,
    neutral    = 10,
    friendly   = 50,
    allied     = 100,
}

function Factions.init(whitelist)
    -- Build lookup for whitelist filtering (nil whitelist = include all)
    local allowed = nil
    if whitelist then
        allowed = {}
        for _, fid in ipairs(whitelist) do
            allowed[fid] = true
        end
    end

    reputation = {}
    for factionId in pairs(FACTION_DEFS) do
        if not allowed or allowed[factionId] then
            reputation[factionId] = 0  -- start neutral
        end
    end
    -- Player is a Mammona Mining subsidiary — start friendly with parent corp
    if reputation.mammona_logistics ~= nil then
        reputation.mammona_logistics = 20
    end
    if reputation.mastema_ops ~= nil then
        reputation.mastema_ops = 20
    end
end

---------------------------------------------------------------------------
-- Reputation management
---------------------------------------------------------------------------

function Factions.getRep(factionId)
    return reputation[factionId] or 0
end

function Factions.modifyRep(factionId, delta)
    if not FACTION_DEFS[factionId] then return end
    reputation[factionId] = math.max(-100, math.min(100,
        (reputation[factionId] or 0) + delta))

    -- Propagate to corporate group siblings at 50% rate
    local siblings = GROUP_SIBLINGS[factionId]
    if siblings then
        for _, sibId in ipairs(siblings) do
            if sibId ~= factionId then
                local cur = reputation[sibId] or 0
                reputation[sibId] = math.max(-100, math.min(100,
                    cur + delta * 0.5))
            end
        end
    end
end

function Factions.getStanding(factionId)
    local rep = reputation[factionId] or 0
    if rep <= REP_THRESHOLDS.hostile then return 'hostile' end
    if rep <= REP_THRESHOLDS.unfriendly then return 'unfriendly' end
    if rep <= REP_THRESHOLDS.neutral then return 'neutral' end
    if rep <= REP_THRESHOLDS.friendly then return 'friendly' end
    return 'allied'
end

function Factions.isHostile(factionId)
    return Factions.getStanding(factionId) == 'hostile'
end

function Factions.isAllied(factionId)
    return Factions.getStanding(factionId) == 'allied'
end

--- Check if the player is aligned (neutral or better) with a faction or any
--- member of its corporate group. Used by raids to block attacks from allies.
function Factions.isGroupAligned(factionId)
    local siblings = GROUP_SIBLINGS[factionId]
    if not siblings then
        return (reputation[factionId] or 0) >= 0
    end
    for _, sibId in ipairs(siblings) do
        if (reputation[sibId] or 0) >= 0 then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Trade price modifier based on reputation
---------------------------------------------------------------------------

function Factions.getTradeMult(factionId)
    local def = FACTION_DEFS[factionId]
    if not def then return 1.0 end

    local standing = Factions.getStanding(factionId)
    if standing == 'hostile' then return def.hostileMult end
    if standing == 'allied' or standing == 'friendly' then return def.priceMult end
    return 1.0
end

---------------------------------------------------------------------------
-- Thermal core price multiplier (faction-specific valuation)
---------------------------------------------------------------------------

function Factions.getCorePriceMult(factionId)
    local def = FACTION_DEFS[factionId]
    if not def then return 1.0 end
    -- corePriceMult already encodes faction-specific valuation; don't double-apply trade mult
    return def.corePriceMult or 1.0
end

---------------------------------------------------------------------------
-- Gift resources to a faction (warmth sharing / tribute)
---------------------------------------------------------------------------

function Factions.sendGift(factionId, resourceName, amount)
    local def = FACTION_DEFS[factionId]
    if not def then return false, 'Unknown faction' end

    if (GameState.resources[resourceName] or 0) < amount then
        return false, 'Not enough ' .. resourceName
    end

    local SNet = getStorageNet()
    if SNet then SNet.withdraw(resourceName, amount, GameState.startX, GameState.startY)
    else GameState.spendResource(resourceName, amount) end

    -- Rep gain: preferred gifts worth more
    local repGain = amount * 0.5
    if resourceName == def.giftPreference then
        repGain = repGain * 2
    end
    Factions.modifyRep(factionId, repGain)

    return true, repGain
end

---------------------------------------------------------------------------
-- Faction events
---------------------------------------------------------------------------

-- Prisoner capture from a faction damages relations
function Factions.onPrisonerCaptured(factionId)
    if not factionId then return end
    Factions.modifyRep(factionId, -15)
end

-- Trading with a faction improves relations slightly
function Factions.onTradeCompleted(factionId)
    if not factionId then return end
    Factions.modifyRep(factionId, 2)
end

-- Killing a faction's proxy raiders damages relations
function Factions.onFactionCreatureKilled(factionId)
    if not factionId then return end
    Factions.modifyRep(factionId, -3)
end

-- Helping a faction (quest completion, rescue their people)
function Factions.onQuestCompleted(factionId)
    if not factionId then return end
    Factions.modifyRep(factionId, 10)
end

-- Releasing a prisoner earns goodwill (partial offset to capture's -15)
function Factions.onPrisonerReleased(factionId)
    if not factionId then return end
    Factions.modifyRep(factionId, 12)
end

-- Executing a faction member is a serious diplomatic act
function Factions.onPrisonerExecuted(factionId)
    if not factionId then return end
    Factions.modifyRep(factionId, -10)
end

-- Butchering is the worst dark action — largest rep hit
function Factions.onPrisonerButchered(factionId)
    if not factionId then return end
    Factions.modifyRep(factionId, -20)
end

-- Prisoner escape: faction relieved their person got out
function Factions.onPrisonerEscaped(factionId)
    if not factionId then return end
    Factions.modifyRep(factionId, 5)
end

---------------------------------------------------------------------------
-- Allied faction bonuses
---------------------------------------------------------------------------

function Factions.getResearchBonus()
    local bonus = 0
    for factionId, def in pairs(FACTION_DEFS) do
        if def.researchBonus and Factions.isAllied(factionId) then
            bonus = bonus + def.researchBonus
        end
    end
    return bonus
end

-- During raids, allied factions may send reinforcements
function Factions.getAlliedReinforcements()
    local count = 0
    for factionId in pairs(FACTION_DEFS) do
        if Factions.isAllied(factionId) then
            count = count + 1  -- each ally sends 1-2 fighters
        end
    end
    return count
end

---------------------------------------------------------------------------
-- Pick a faction to source a raid from (hostile factions only)
---------------------------------------------------------------------------

function Factions.pickHostileFaction()
    local hostile = {}
    for factionId, def in pairs(FACTION_DEFS) do
        if Factions.isHostile(factionId) and #def.raidSpecies > 0 then
            hostile[#hostile + 1] = factionId
        end
    end
    if #hostile == 0 then return nil end
    return hostile[math.random(#hostile)]
end

---------------------------------------------------------------------------
-- Pick a merchant type based on faction standing
---------------------------------------------------------------------------

function Factions.getAvailableMerchantFactions()
    local available = {}
    for factionId, def in pairs(FACTION_DEFS) do
        local standing = Factions.getStanding(factionId)
        if standing ~= 'hostile' then
            available[#available + 1] = {
                factionId = factionId,
                name      = def.name,
                goods     = def.tradeGoods,
                priceMult = Factions.getTradeMult(factionId),
            }
        end
    end
    return available
end

---------------------------------------------------------------------------
-- Natural reputation drift — hostile factions slowly become neutral
---------------------------------------------------------------------------

local driftTimer = 0
local DRIFT_INTERVAL = 300  -- every 5 game-minutes

function Factions.step(dt)
    driftTimer = driftTimer + dt
    if driftTimer < DRIFT_INTERVAL then return end
    driftTimer = 0

    for factionId in pairs(FACTION_DEFS) do
        local rep = reputation[factionId] or 0
        local isCorp = GROUP_SIBLINGS[factionId] ~= nil

        if isCorp then
            -- Mammona corporate group: quota pressure
            -- Rep decays toward -15 (unfriendly) without active tribute/trade.
            -- ~30 game-days from friendly (+20) to unfriendly (-10).
            -- Player must send cores or trade to maintain corporate standing.
            if rep > -15 then
                reputation[factionId] = math.max(-15, rep - 0.2)
            elseif rep < -15 then
                -- If deeply hostile, still drift toward -15 (not fully neutral)
                reputation[factionId] = math.min(-15, rep + 0.5)
            end
        else
            if rep < 0 then
                -- Hostile factions slowly drift toward neutral
                reputation[factionId] = math.min(0, rep + 1)
            elseif rep > 15 then
                -- Positive rep decays slowly but floors at 15 (above neutral)
                reputation[factionId] = math.max(15, rep - 0.5)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

function Factions.getState()
    return reputation
end

function Factions.restoreState(state)
    reputation = state or {}
    -- Ensure all factions exist
    for factionId in pairs(FACTION_DEFS) do
        if not reputation[factionId] then
            reputation[factionId] = 0
        end
    end
end

---------------------------------------------------------------------------
-- Queries for UI
---------------------------------------------------------------------------

function Factions.getAll()
    local result = {}
    for factionId, def in pairs(FACTION_DEFS) do
        -- Skip factions that were excluded by whitelist on init
        if reputation[factionId] ~= nil then
            result[#result + 1] = {
                id       = factionId,
                name     = def.name,
                desc     = def.desc,
                rep      = reputation[factionId],
                standing = Factions.getStanding(factionId),
            }
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

return Factions
