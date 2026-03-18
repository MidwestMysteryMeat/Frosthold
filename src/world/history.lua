-- history.lua -- Fixed Erebus canon with procedural failed-colony archaeology
-- The truth of Erebus is stable across runs: a living world, a buried precursor
-- civilization, and Mammona's cover-up. Variation comes from failed outposts,
-- recoverable ruins, and local survivor rumors rather than randomizing canon.

local GameState = require('src.game_state')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

local History = {}

local HISTORY_VERSION = 2
local PRECURSOR_FALL_YEARS = 12000

---------------------------------------------------------------------------
-- Canon records
---------------------------------------------------------------------------

local CANON_CIVILIZATION = {
    id         = 'erebus_precursors',
    name       = 'The Precursors',
    era        = 'subsurface',
    specialty  = 'biosymbiotic construction and thermal core refinement',
    desc       = 'Unknown beings who nested inside Erebus and built with its living tissue.',
}

local CANON_CATACLYSM = {
    id    = 'erebus_shift',
    name  = 'The Crushing Shift',
    desc  = 'Erebus stirred in its sleep and crushed the civilization living inside it.',
}

local CANON_TIMELINE = {
    { year = 2530, text = 'After the Fortuna incident, Mammona expanded a classified anomalous biosphere program.' },
    { year = 2583, text = 'Long-range scans of Erebus returned mineral wealth, missing survey packets, and telemetry Mammona never shared with UTC.' },
    { year = 2586, text = 'A Mammona survey camp on Erebus went dark. The loss was filed as weather damage.' },
    { year = 2588, text = 'Additional scouting teams disappeared. Their wreckage remained on the surface; their contracts did not.' },
    { year = 2589, text = 'Mammona Logistics prefiled extraction quotas for Erebus before a stable colony existed.' },
    { year = 2590, text = 'Your crew arrived under orders that implied you were first. The ice says otherwise.' },
}

local RUIN_TYPES = {
    { id = 'failed_survey_site',  name = 'Failed Survey Site', loot = 'components',   lootRange = { 3, 8 } },
    { id = 'frozen_supply_cache', name = 'Frozen Supply Cache', loot = 'fuel',        lootRange = { 6, 14 } },
    { id = 'relay_bunker',        name = 'Relay Bunker',        loot = 'components',  lootRange = { 2, 6 } },
    { id = 'precursor_archive',   name = 'Precursor Archive',   loot = 'components',  lootRange = { 4, 9 } },
    { id = 'membrane_vault',      name = 'Membrane Vault',      loot = 'thermalCores', lootRange = { 2, 5 } },
    { id = 'signal_shrine',       name = 'Signal Shrine',       loot = 'circuit',     lootRange = { 2, 5 } },
    { id = 'thermal_repository',  name = 'Thermal Repository',  loot = 'thermalCores', lootRange = { 3, 7 } },
}

local RELIC_NAMES = {
    'Dormancy Key', 'Signal Lattice', 'Thermal Seed', 'Cipher Spine',
    'Stasis Coil', 'Archive Spindle', 'Membrane Lens', 'Core Cradle',
}

---------------------------------------------------------------------------
-- Procedural flavor tables
---------------------------------------------------------------------------

local OUTPOST_PREFIXES = {
    'Mammona Site', 'Survey Camp', 'Relay Post', 'Hab Cluster',
    'Supply Node', 'Transit Camp', 'Thermal Station',
}

local OUTPOST_SUFFIXES = {
    'Aster', 'Kestrel', 'Ledger', 'Needle', 'Coldwater',
    'Blackglass', 'Northfall', 'Pilgrim', 'Slate', 'Cairn',
}

local CAUSES_OF_FALL = {
    'went dark after its heaters failed during a whiteout',
    'was stripped for parts after Mammona stopped answering supply requests',
    'was abandoned when a shaft team cut into living tissue below the permafrost',
    'froze after the air scrubbers iced solid and the backup fuel never arrived',
    'fell apart when HERMES rerouted its supply drop and never explained why',
    'was overrun after thermal output drew too many predators at once',
    'stopped transmitting after survivors reported voices in the static',
    'collapsed during an underground shift that chewed through the support columns',
}

local SURVIVOR_CELL_TEMPLATES = {
    {
        prefix       = 'Scavenger holdout',
        specialties  = { 'salvaging', 'strip-mining', 'barter runs' },
        dispositions = { 'wary', 'neutral', 'friendly' },
    },
    {
        prefix       = 'Mammona deserter cell',
        specialties  = { 'repair work', 'smuggling', 'black-market logistics' },
        dispositions = { 'reclusive', 'wary', 'neutral' },
    },
    {
        prefix       = 'Rim runner relay',
        specialties  = { 'courier work', 'surveying', 'quiet trade' },
        dispositions = { 'friendly', 'neutral', 'wary' },
    },
    {
        prefix       = 'Solar Nomad caravan',
        specialties  = { 'food trade', 'weather scouting', 'salvage exchange' },
        dispositions = { 'friendly', 'neutral', 'reclusive' },
    },
    {
        prefix       = 'Pale Moon pilgrim knot',
        specialties  = { 'artifact retrieval', 'ritual scouting', 'thermal core trade' },
        dispositions = { 'reclusive', 'wary', 'hostile' },
    },
    {
        prefix       = 'Black Maw scav line',
        specialties  = { 'raiding', 'salvage theft', 'fuel running' },
        dispositions = { 'hostile', 'wary', 'neutral' },
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local worldHistory = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function pickRandom(list)
    return list[math.random(#list)]
end

local function cloneRecord(src)
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

local function cloneList(list)
    local out = {}
    for i, entry in ipairs(list) do
        if type(entry) == 'table' then
            out[i] = cloneRecord(entry)
        else
            out[i] = entry
        end
    end
    return out
end

local function generateOutpostName()
    return pickRandom(OUTPOST_PREFIXES) .. ' ' .. pickRandom(OUTPOST_SUFFIXES)
end

local function generateRuins()
    local ruins = {}
    local count = 4 + math.random(2)

    for i = 1, count do
        local def = pickRandom(RUIN_TYPES)
        ruins[#ruins + 1] = {
            id         = def.id .. '_' .. i,
            type       = def.id,
            name       = def.name,
            loot       = def.loot,
            lootMin    = def.lootRange[1],
            lootMax    = def.lootRange[2],
            discovered = false,
            explored   = false,
            mapX       = nil,
            mapY       = nil,
        }
    end

    return ruins
end

local function generateOutposts()
    local outposts = {}
    local used = {}

    for _ = 1, math.random(3, 6) do
        local name = generateOutpostName()
        local attempts = 0
        while used[name] and attempts < 10 do
            name = generateOutpostName()
            attempts = attempts + 1
        end
        used[name] = true

        outposts[#outposts + 1] = {
            name     = name,
            yearsAgo = math.random(2, 28),
            cause    = pickRandom(CAUSES_OF_FALL),
        }
    end

    return outposts
end

local function generateMicroFactions()
    local cells = {}
    local used = {}

    for _ = 1, math.random(2, 4) do
        local template = pickRandom(SURVIVOR_CELL_TEMPLATES)
        local name = template.prefix .. ' ' .. pickRandom(OUTPOST_SUFFIXES)
        local attempts = 0
        while used[name] and attempts < 10 do
            name = template.prefix .. ' ' .. pickRandom(OUTPOST_SUFFIXES)
            attempts = attempts + 1
        end
        used[name] = true

        cells[#cells + 1] = {
            name        = name,
            size        = math.random(4, 24),
            disposition = pickRandom(template.dispositions),
            specialty   = pickRandom(template.specialties),
            active      = math.random() > 0.3,
        }
    end

    return cells
end

local function normalizeRuins(existing)
    if not existing or #existing == 0 then
        return generateRuins()
    end

    local normalized = {}
    for i, ruin in ipairs(existing) do
        normalized[#normalized + 1] = {
            id         = ruin.id or ('legacy_ruin_' .. i),
            type       = ruin.type or 'legacy',
            name       = ruin.name or 'Uncatalogued Ruin',
            loot       = ruin.loot or 'components',
            lootMin    = ruin.lootMin or ruin.minLoot or 1,
            lootMax    = ruin.lootMax or ruin.maxLoot or 3,
            discovered = ruin.discovered == true,
            explored   = ruin.explored == true,
            mapX       = ruin.mapX,
            mapY       = ruin.mapY,
        }
    end
    return normalized
end

local function normalizeOutposts(existing)
    if not existing or #existing == 0 then
        return generateOutposts()
    end

    local normalized = {}
    for i, outpost in ipairs(existing) do
        normalized[#normalized + 1] = {
            name     = outpost.name or ('Unknown Outpost ' .. i),
            yearsAgo = outpost.yearsAgo or math.random(2, 28),
            cause    = outpost.cause or pickRandom(CAUSES_OF_FALL),
        }
    end
    return normalized
end

local function normalizeMicroFactions(existing)
    if not existing or #existing == 0 then
        return generateMicroFactions()
    end

    local normalized = {}
    for i, cell in ipairs(existing) do
        normalized[#normalized + 1] = {
            name        = cell.name or ('Unknown Cell ' .. i),
            size        = cell.size or math.random(4, 24),
            disposition = cell.disposition or 'wary',
            specialty   = cell.specialty or 'salvaging',
            active      = cell.active ~= false,
        }
    end
    return normalized
end

local function normalizeRelics(existing)
    if not existing then return {} end

    local normalized = {}
    for i, relic in ipairs(existing) do
        if type(relic) == 'table' then
            normalized[#normalized + 1] = {
                name = relic.name or ('Recovered Relic ' .. i),
                from = relic.from or 'Unknown site',
                day  = relic.day or GameState.day,
            }
        end
    end
    return normalized
end

local function normalizeHistory(state)
    return {
        version       = HISTORY_VERSION,
        civilization  = cloneRecord(CANON_CIVILIZATION),
        cataclysm     = cloneRecord(CANON_CATACLYSM),
        timeline      = cloneList(CANON_TIMELINE),
        ruins         = normalizeRuins(state and state.ruins),
        relicsFound   = normalizeRelics(state and state.relicsFound),
        yearsAgo      = PRECURSOR_FALL_YEARS,
        outposts      = normalizeOutposts(state and state.outposts),
        microFactions = normalizeMicroFactions(state and state.microFactions),
    }
end

---------------------------------------------------------------------------
-- Generation / init
---------------------------------------------------------------------------

function History.generate()
    worldHistory = normalizeHistory(nil)
    return worldHistory
end

function History.init()
    worldHistory = normalizeHistory(worldHistory)
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function History.getHistory()
    return worldHistory
end

function History.getCivilization()
    return worldHistory and worldHistory.civilization
end

function History.getCataclysm()
    return worldHistory and worldHistory.cataclysm
end

function History.getTimeline()
    return worldHistory and worldHistory.timeline or {}
end

function History.getRuins()
    return worldHistory and worldHistory.ruins or {}
end

function History.getUndiscoveredRuins()
    if not worldHistory then return {} end
    local result = {}
    for _, ruin in ipairs(worldHistory.ruins) do
        if not ruin.discovered then
            result[#result + 1] = ruin
        end
    end
    return result
end

function History.getRelicsFound()
    return worldHistory and worldHistory.relicsFound or {}
end

function History.getOutposts()
    return worldHistory and worldHistory.outposts or {}
end

function History.getMicroFactions()
    return worldHistory and worldHistory.microFactions or {}
end

function History.getActiveMicroFactions()
    if not worldHistory or not worldHistory.microFactions then return {} end
    local result = {}
    for _, cell in ipairs(worldHistory.microFactions) do
        if cell.active then
            result[#result + 1] = cell
        end
    end
    return result
end

function History.getSummary()
    if not worldHistory then return 'No history generated.' end
    return 'Erebus is a living world. Long before Mammona arrived, a precursor civilization nested inside it and refined thermal cores from its internal structures. Around '
        .. tostring(PRECURSOR_FALL_YEARS)
        .. ' years ago, the world shifted and crushed them. The ruins on Erebus are the scars of that event, and Mammona knew enough to lie about sending the first crew.'
end

function History.getRandomFact()
    if not worldHistory then return nil end

    local roll = math.random(3)
    if roll == 1 and worldHistory.outposts and #worldHistory.outposts > 0 then
        local outpost = pickRandom(worldHistory.outposts)
        return outpost.name .. ' ' .. outpost.cause .. ' about ' .. outpost.yearsAgo .. ' years ago.'
    end

    if roll == 2 and worldHistory.timeline and #worldHistory.timeline > 0 then
        local event = pickRandom(worldHistory.timeline)
        return tostring(event.year) .. ': ' .. event.text
    end

    if worldHistory.microFactions and #worldHistory.microFactions > 0 then
        local cell = pickRandom(worldHistory.microFactions)
        if cell.active then
            return cell.name .. ' (' .. cell.size .. ' people) is still active nearby, mostly focused on ' .. cell.specialty .. '.'
        end
        return cell.name .. ' collapsed after trying to survive on ' .. cell.specialty .. '.'
    end

    return nil
end

function History.getRandomOutpostName()
    if not worldHistory or not worldHistory.outposts or #worldHistory.outposts == 0 then
        return 'an old outpost'
    end
    return pickRandom(worldHistory.outposts).name
end

---------------------------------------------------------------------------
-- Ruin lifecycle
---------------------------------------------------------------------------

function History.discoverRuin(ruinId)
    if not worldHistory then return false end
    for _, ruin in ipairs(worldHistory.ruins) do
        if ruin.id == ruinId then
            ruin.discovered = true
            return true
        end
    end
    return false
end

function History.exploreRuin(ruinId)
    if not worldHistory then return nil end

    for _, ruin in ipairs(worldHistory.ruins) do
        if ruin.id == ruinId and ruin.discovered and not ruin.explored then
            ruin.explored = true
            local amount = math.random(ruin.lootMin, ruin.lootMax)
            local Items = getItems()
            if Items then Items.spawn(GameState.startX, GameState.startY, ruin.loot, amount, nil, 0)
            else GameState.addResource(ruin.loot, amount) end

            local relic = nil
            if math.random() < 0.3 then
                relic = RELIC_NAMES[math.random(#RELIC_NAMES)]
                worldHistory.relicsFound[#worldHistory.relicsFound + 1] = {
                    name = relic,
                    from = ruin.name,
                    day  = GameState.day,
                }
            end

            return { loot = ruin.loot, amount = amount, relic = relic }
        end
    end

    return nil
end

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

function History.getState()
    return worldHistory
end

function History.restoreState(state)
    worldHistory = normalizeHistory(state)
end

return History
