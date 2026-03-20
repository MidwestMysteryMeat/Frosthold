-- mrp.lua — Meta-Run Points campaign persistence layer
-- Stores cross-run meta-progression: MRP currency, permanent unlocks,
-- planet deployment history, and nemesis roster.
-- Saved to frosthold_campaign.dat, separate from colony saves.

local MRP = {}

local CAMPAIGN_FILE = 'frosthold_campaign.dat'

-- Tier thresholds based on lifetime MRP earned
local TIER_THRESHOLDS = { 100, 250, 500, 1000 }

-- Nemesis roster cap per planet
local NEMESIS_CAP = 3

---------------------------------------------------------------------------
-- Internal state
---------------------------------------------------------------------------

local _balance   = 0
local _lifetime  = 0
local _unlocks   = {}     -- set: unlockId -> true
local _planets   = {}     -- map: planetId -> { deployments={}, nemeses={} }

---------------------------------------------------------------------------
-- Simple serializer (produces "return {...}" — same format as Helpers.serialize)
-- Used as fallback when save_helpers.lua is not available (headless tests).
---------------------------------------------------------------------------

local function simpleSerialize(v, indent)
    indent = indent or ''
    local t = type(v)
    if t == 'nil' then
        return 'nil'
    elseif t == 'boolean' then
        return v and 'true' or 'false'
    elseif t == 'number' then
        if v ~= v then return '0' end          -- NaN guard
        if v == math.huge then return '1/0' end
        if v == -math.huge then return '-1/0' end
        return tostring(v)
    elseif t == 'string' then
        return string.format('%q', v)
    elseif t == 'table' then
        local nextIndent = indent .. '  '
        local parts = {}
        local n = #v
        for i = 1, n do
            parts[#parts + 1] = nextIndent .. simpleSerialize(v[i], nextIndent)
        end
        for k, val in pairs(v) do
            local skip = type(k) == 'number' and k >= 1 and k <= n and math.floor(k) == k
            if not skip then
                local kStr
                if type(k) == 'string' and k:match('^[%a_][%w_]*$') then
                    kStr = k
                else
                    kStr = '[' .. simpleSerialize(k, nextIndent) .. ']'
                end
                parts[#parts + 1] = nextIndent .. kStr .. ' = ' .. simpleSerialize(val, nextIndent)
            end
        end
        if #parts == 0 then return '{}' end
        return '{\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. '}'
    end
    return 'nil'
end

-- Returns the serialised string with the leading "return " prefix
local function serialize(tbl)
    return 'return ' .. simpleSerialize(tbl, '')
end

-- Try to use the project's canonical Helpers.serialize (requires Love2D at load time)
local _helpersOk, _Helpers = pcall(require, 'src.persistence.save_helpers')
local function serializeData(tbl)
    if _helpersOk and _Helpers and _Helpers.serialize then
        return _Helpers.serialize(tbl)
    end
    return serialize(tbl)
end

---------------------------------------------------------------------------
-- File I/O helpers (love.filesystem when available, io.open fallback)
---------------------------------------------------------------------------

local function writeFile(path, data)
    if love and love.filesystem and love.filesystem.write then
        return love.filesystem.write(path, data)
    end
    -- Headless / test fallback
    local fh, err = io.open(path, 'wb')
    if not fh then return nil, err end
    fh:write(data)
    fh:close()
    return true
end

local function readFile(path)
    if love and love.filesystem and love.filesystem.read then
        local data, errMsg = love.filesystem.read(path)
        return data, errMsg
    end
    -- Headless / test fallback
    local fh = io.open(path, 'rb')
    if not fh then return nil, 'file not found' end
    local data = fh:read('*a')
    fh:close()
    return data
end

---------------------------------------------------------------------------
-- Planet record helper
---------------------------------------------------------------------------

local function ensurePlanet(planetId)
    if not _planets[planetId] then
        _planets[planetId] = { deployments = {}, nemeses = {} }
    end
    return _planets[planetId]
end

---------------------------------------------------------------------------
-- State Management
---------------------------------------------------------------------------

function MRP.reset()
    _balance  = 0
    _lifetime = 0
    _unlocks  = {}
    _planets  = {}
end

function MRP.getBalance()
    return _balance
end

function MRP.getLifetime()
    return _lifetime
end

function MRP.getUnlocks()
    local list = {}
    for id in pairs(_unlocks) do
        list[#list + 1] = id
    end
    return list
end

function MRP.hasUnlock(unlockId)
    return _unlocks[unlockId] == true
end

-- Tier 0..4 based on lifetime MRP.
-- Tier advances once lifetime reaches each threshold in TIER_THRESHOLDS.
function MRP.getTier()
    for i = #TIER_THRESHOLDS, 1, -1 do
        if _lifetime >= TIER_THRESHOLDS[i] then
            return i
        end
    end
    return 0
end

---------------------------------------------------------------------------
-- Economy
---------------------------------------------------------------------------

function MRP.earn(amount)
    if type(amount) ~= 'number' or amount < 0 then return end
    _balance  = _balance  + amount
    _lifetime = _lifetime + amount
end

-- Returns true on success, false if insufficient balance
function MRP.spend(amount)
    if type(amount) ~= 'number' or amount < 0 then return false end
    if _balance < amount then return false end
    _balance = _balance - amount
    return true
end

-- Deduct cost and record the unlock.
-- Returns false if already owned or can't afford.
function MRP.purchaseUnlock(unlockId, cost)
    if _unlocks[unlockId] then return false end
    if not MRP.spend(cost) then return false end
    _unlocks[unlockId] = true
    return true
end

---------------------------------------------------------------------------
-- Planet History
---------------------------------------------------------------------------

function MRP.addPlanetDeployment(planetId, record)
    local planet = ensurePlanet(planetId)
    planet.deployments[#planet.deployments + 1] = record
end

function MRP.getPlanetHistory(planetId)
    local planet = _planets[planetId]
    if not planet then return {} end
    return planet.deployments
end

function MRP.getDeploymentCount(planetId)
    local planet = _planets[planetId]
    if not planet then return 0 end
    return #planet.deployments
end

---------------------------------------------------------------------------
-- Nemesis Roster
---------------------------------------------------------------------------

-- Add a nemesis to the planet roster.  Caps at NEMESIS_CAP; removes oldest (FIFO).
function MRP.addNemesis(planetId, nemesis)
    local planet = ensurePlanet(planetId)
    planet.nemeses[#planet.nemeses + 1] = nemesis
    while #planet.nemeses > NEMESIS_CAP do
        table.remove(planet.nemeses, 1)
    end
end

function MRP.getNemeses(planetId)
    local planet = _planets[planetId]
    if not planet then return {} end
    return planet.nemeses
end

---------------------------------------------------------------------------
-- MRP Calculation
---------------------------------------------------------------------------

-- stats table fields (all optional, default 0/false):
--   daysSurvived, raidsSurvived, researchCompleted, colonistsLost,
--   buildingsConstructed, bossDamaged, bossDefeated, milestonesCompleted,
--   firstDeployment (boolean)
function MRP.calculateRunMRP(stats)
    stats = stats or {}
    local s = stats

    local total = 0
    total = total + (s.daysSurvived        or 0) * 1
    total = total + (s.raidsSurvived       or 0) * 5
    total = total + (s.researchCompleted   or 0) * 3
    total = total + (s.colonistsLost       or 0) * 2
    total = total + (s.buildingsConstructed or 0) * 1
    total = total + (s.bossDamaged         or 0) * 25
    total = total + (s.bossDefeated        or 0) * 50
    total = total + (s.milestonesCompleted or 0) * 40

    if s.firstDeployment == true then
        total = total + 10
    end

    return total
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function MRP.save()
    -- Build a plain serialisable snapshot
    local unlockList = {}
    for id in pairs(_unlocks) do
        unlockList[#unlockList + 1] = id
    end

    local planetData = {}
    for planetId, data in pairs(_planets) do
        planetData[planetId] = {
            deployments = data.deployments,
            nemeses     = data.nemeses,
        }
    end

    local snapshot = {
        version  = 1,
        balance  = _balance,
        lifetime = _lifetime,
        unlocks  = unlockList,
        planets  = planetData,
    }

    local str = serializeData(snapshot)
    local ok, err = writeFile(CAMPAIGN_FILE, str)
    if not ok then
        return false, err
    end
    return true
end

function MRP.load()
    local str, err = readFile(CAMPAIGN_FILE)
    if not str then
        -- No campaign file yet — start fresh
        MRP.reset()
        return false, err
    end

    -- The serialised file begins with "return " (produced by serializeData).
    -- Use loadstring directly — do NOT prepend another "return ".
    local fn, loadErr = loadstring(str)
    if not fn then
        MRP.reset()
        return false, loadErr
    end

    local ok, data = pcall(fn)
    if not ok or type(data) ~= 'table' then
        MRP.reset()
        return false, data
    end

    _balance  = data.balance  or 0
    _lifetime = data.lifetime or 0

    _unlocks = {}
    for _, id in ipairs(data.unlocks or {}) do
        _unlocks[id] = true
    end

    _planets = {}
    for planetId, pdata in pairs(data.planets or {}) do
        _planets[planetId] = {
            deployments = pdata.deployments or {},
            nemeses     = pdata.nemeses     or {},
        }
    end

    return true
end

---------------------------------------------------------------------------

return MRP
