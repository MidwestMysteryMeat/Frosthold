-- colony_legacy.lua — Colony legacy system
-- When a colony falls (all colonists die), its stats are saved as a legacy record.
-- Legacy colonies appear as overworld ruins in future playthroughs.
-- Players can send expeditions to fallen colony sites for unique loot.

local GameState = require('src.game_state')

local Legacy = {}

local LEGACY_FILE = 'frosthold_legacies.dat'

---------------------------------------------------------------------------
-- Legacy record structure
---------------------------------------------------------------------------

-- Each legacy is:
-- {
--   colonyName    = string,
--   daysSurvived  = number,
--   peakPopulation = number,
--   causeOfDeath  = string,
--   wealth        = number,
--   raidsSurvived = number,
--   bossesKilled  = number,
--   timestamp     = number,   (os.time)
--   resources     = { ... },  (snapshot of resources at death)
--   x, y          = numbers,  (overworld position for ruin placement)
-- }

---------------------------------------------------------------------------
-- Load existing legacies from disk
---------------------------------------------------------------------------

local legacies = {}

function Legacy.loadLegacies()
    local ok, data = pcall(function()
        local content = love.filesystem.read(LEGACY_FILE)
        if not content then return nil end
        local fn = loadstring('return ' .. content)
        if fn then
            setfenv(fn, {})
            return fn()
        end
        return nil
    end)

    if ok and data and type(data) == 'table' then
        legacies = data
    else
        legacies = {}
    end
    return legacies
end

---------------------------------------------------------------------------
-- Save legacies to disk
---------------------------------------------------------------------------

local function serializeTable(t, indent)
    indent = indent or ''
    local nextIndent = indent .. '  '
    local parts = { '{\n' }
    for k, v in pairs(t) do
        local keyStr
        if type(k) == 'number' then
            keyStr = '[' .. k .. ']'
        else
            keyStr = '["' .. tostring(k) .. '"]'
        end

        local valStr
        if type(v) == 'table' then
            valStr = serializeTable(v, nextIndent)
        elseif type(v) == 'string' then
            valStr = string.format('%q', v)
        elseif type(v) == 'boolean' then
            valStr = v and 'true' or 'false'
        elseif type(v) == 'number' then
            if v ~= v then valStr = '0'           -- NaN guard
            elseif v == math.huge then valStr = '999999'
            elseif v == -math.huge then valStr = '-999999'
            else valStr = tostring(v)
            end
        else
            valStr = tostring(v)
        end

        parts[#parts + 1] = nextIndent .. keyStr .. ' = ' .. valStr .. ',\n'
    end
    parts[#parts + 1] = indent .. '}'
    return table.concat(parts)
end

function Legacy.saveLegacies()
    local str = serializeTable(legacies)
    love.filesystem.write(LEGACY_FILE, str)
end

---------------------------------------------------------------------------
-- Record a fallen colony
---------------------------------------------------------------------------

function Legacy.recordFallenColony(causeOfDeath)
    local ECS = require('src.ecs.ecs')

    -- Count peak population from current alive + dead
    local peakPop = 0
    local bossesKilled = 0
    for id, comps in ECS.query('colonist') do
        peakPop = peakPop + 1
        local col = comps.colonist
        if col.kills and col.kills > 0 then
            bossesKilled = bossesKilled + (col.bossKills or 0)
        end
    end

    -- Snapshot resources (top 10 by value)
    local resSnapshot = {}
    local resCount = 0
    for res, amount in pairs(GameState.resources or {}) do
        if amount > 0 and resCount < 10 then
            resSnapshot[res] = amount
            resCount = resCount + 1
        end
    end

    local record = {
        colonyName     = GameState.colonyName or 'Unnamed Colony',
        daysSurvived   = GameState.day or 0,
        peakPopulation = peakPop,
        causeOfDeath   = causeOfDeath or 'unknown',
        wealth         = GameState.getColonyWealth and GameState.getColonyWealth() or 0,
        raidsSurvived  = GameState.raidsSurvived or 0,
        bossesKilled   = bossesKilled,
        timestamp      = os.time(),
        resources      = resSnapshot,
        x              = GameState.startX or math.random(30, 100),
        y              = GameState.startY or math.random(30, 100),
    }

    legacies[#legacies + 1] = record

    -- Keep at most 20 legacies
    while #legacies > 20 do
        table.remove(legacies, 1)
    end

    Legacy.saveLegacies()
    return record
end

---------------------------------------------------------------------------
-- Query legacies for overworld ruin placement
---------------------------------------------------------------------------

function Legacy.getLegacies()
    return legacies
end

function Legacy.getLegacyCount()
    return #legacies
end

-- Get legacies formatted as overworld expedition destinations
function Legacy.getLegacyDestinations()
    local dests = {}
    for i, leg in ipairs(legacies) do
        dests[#dests + 1] = {
            id          = 'legacy_ruin_' .. i,
            name        = 'Ruins of ' .. leg.colonyName,
            desc        = string.format(
                'Former colony. Survived %d days, population peaked at %d. Fell to %s.',
                leg.daysSurvived, leg.peakPopulation, leg.causeOfDeath),
            risk        = math.min(5, math.floor(leg.daysSurvived / 20) + 1),
            minParty    = 1,
            duration    = 90 + leg.daysSurvived,
            x           = leg.x,
            y           = leg.y,
            resources   = leg.resources,
            daysFallen  = leg.daysSurvived,
        }
    end
    return dests
end

-- Get loot table for a legacy ruin expedition
function Legacy.getLegacyLoot(legacyIndex)
    local leg = legacies[legacyIndex]
    if not leg then return {} end

    local loot = {}

    -- Salvage a fraction of the fallen colony's resources
    for res, amount in pairs(leg.resources or {}) do
        local salvage = math.floor(amount * 0.15)
        if salvage > 0 then
            loot[#loot + 1] = { resource = res, amount = salvage }
        end
    end

    -- Bonus: longer-lived colonies have better salvage
    if leg.daysSurvived > 30 then
        loot[#loot + 1] = { resource = 'components', amount = math.floor(leg.daysSurvived / 10) }
    end
    if leg.daysSurvived > 60 then
        loot[#loot + 1] = { resource = 'thermalCores', amount = math.floor(leg.daysSurvived / 20) }
    end

    return loot
end

---------------------------------------------------------------------------
-- Init (load from disk on game start)
---------------------------------------------------------------------------

function Legacy.init()
    Legacy.loadLegacies()
end

return Legacy
