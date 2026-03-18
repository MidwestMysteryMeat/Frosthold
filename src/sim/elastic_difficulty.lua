-- elastic_difficulty.lua — Adaptive difficulty system (ported from MMOLite)
-- Tracks colony stress via EMA smoothing, classifies into tension bands,
-- and provides modifiers that scale raids, spawns, and events.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tuning    = require('src.sim.tuning')

local Elastic = {}

---------------------------------------------------------------------------
-- Tension bands — each defines modifiers for game systems
---------------------------------------------------------------------------

local BANDS = {
    { id = 'bored',       lo = 0.00, hi = 0.10, reinforcementRate = 1.5, aggressionMod = 1.3, eventSpeedMod = 1.4, lootMod = 1.15 },
    { id = 'coasting',    lo = 0.10, hi = 0.25, reinforcementRate = 1.2, aggressionMod = 1.1, eventSpeedMod = 1.15, lootMod = 1.05 },
    { id = 'engaged',     lo = 0.25, hi = 0.50, reinforcementRate = 1.0, aggressionMod = 1.0, eventSpeedMod = 1.0,  lootMod = 1.0 },
    { id = 'pressured',   lo = 0.50, hi = 0.70, reinforcementRate = 0.7, aggressionMod = 0.9, eventSpeedMod = 0.8,  lootMod = 1.0 },
    { id = 'overwhelmed', lo = 0.70, hi = 1.01, reinforcementRate = 0.4, aggressionMod = 0.7, eventSpeedMod = 0.5,  lootMod = 1.10 },
}

local function etune(key, fallback)
    return Tuning.get('elastic.' .. key, fallback)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local state = {
    rawStress      = 0,
    smoothedStress = 0.25,  -- start at "engaged"
    history        = {},
    trend          = 'stable',
    bandId         = 'engaged',
    bandIndex      = 3,

    -- Tracking inputs (reset each tick)
    recentDeaths      = 0,
    recentDamageTaken = 0,
    peakDamage        = 0,

    tickTimer = 0,
}

---------------------------------------------------------------------------
-- Stress calculation — weighted factors
---------------------------------------------------------------------------

local function computeStress()
    local colonistCount = ECS.countWith('colonist')
    if colonistCount == 0 then return 0.5 end

    -- Factor 1: colony health ratio (40% weight)
    local totalHp, totalMaxHp = 0, 0
    for id, comps in ECS.query('colonist', 'needs') do
        local col = comps.colonist
        if col.state ~= 'dead' then
            totalHp    = totalHp + (col.health or 100)
            totalMaxHp = totalMaxHp + (col.maxHealth or 100)
        end
    end
    local hpRatio = 1 - (totalMaxHp > 0 and totalHp / totalMaxHp or 1)

    -- Factor 2: recent damage pressure (35% weight)
    -- Decays each tick; represents combat intensity
    local damageFactor = math.min(1, state.recentDamageTaken / math.max(1, totalMaxHp * 0.5))

    -- Factor 3: death count (25% weight, normalized to 5 max)
    local deathFactor = math.min(1, state.recentDeaths / 5)

    -- Factor 4: food security (bonus modifier)
    local foodPenalty = 0
    local food = GameState.resources.food or 0
    if food < 10 then foodPenalty = etune('food_low_penalty', 0.1) end

    -- Factor 5: active raid pressure
    local raidPenalty = 0
    local rok, Raids = pcall(require, 'src.sim.raids')
    if rok and Raids.isRaidActive and Raids.isRaidActive() then
        raidPenalty = etune('active_raid_penalty', 0.15)
    end

    local stress = 0.40 * hpRatio + 0.35 * damageFactor + 0.25 * deathFactor + foodPenalty + raidPenalty
    return math.max(0, math.min(1, stress))
end

---------------------------------------------------------------------------
-- Trend detection — compare recent half vs older half of history
---------------------------------------------------------------------------

local function detectTrend(history)
    if #history < 4 then return 'stable' end

    local half = math.floor(#history / 2)
    local older, recent = 0, 0

    for i = 1, half do
        older = older + history[i]
    end
    for i = half + 1, #history do
        recent = recent + history[i]
    end

    older  = older / half
    recent = recent / (#history - half)

    local delta = recent - older
    local trendDelta = etune('trend_delta', 0.08)
    if delta > trendDelta then return 'rising' end
    if delta < -trendDelta then return 'falling' end
    return 'stable'
end

---------------------------------------------------------------------------
-- Find current band
---------------------------------------------------------------------------

local function findBand(stress)
    for i, band in ipairs(BANDS) do
        if stress >= band.lo and stress < band.hi then
            return band, i
        end
    end
    return BANDS[3], 3  -- default engaged
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Elastic.step(dt)
    state.tickTimer = state.tickTimer + dt
    local tickInterval = etune('tick_interval', 5.0)
    if state.tickTimer < tickInterval then return end
    state.tickTimer = 0

    -- Compute raw stress
    state.rawStress = computeStress()

    -- EMA smoothing
    local smoothingAlpha = etune('smoothing_alpha', 0.15)
    state.smoothedStress = state.smoothedStress * (1 - smoothingAlpha) + state.rawStress * smoothingAlpha

    -- Update history
    state.history[#state.history + 1] = state.smoothedStress
    local historyWindow = math.max(4, math.floor(etune('history_window', 20)))
    while #state.history > historyWindow do
        table.remove(state.history, 1)
    end

    -- Detect trend
    state.trend = detectTrend(state.history)

    -- Find band
    local band, idx = findBand(state.smoothedStress)
    state.bandId    = band.id
    state.bandIndex = idx

    -- Decay damage tracking (15% per tick)
    state.recentDamageTaken = state.recentDamageTaken * etune('damage_decay', 0.85)

    -- Decay death count slowly
    state.recentDeaths = math.max(0, state.recentDeaths - etune('death_decay', 0.05))
end

---------------------------------------------------------------------------
-- Event hooks — other systems call these to feed data
---------------------------------------------------------------------------

function Elastic.onColonistDeath()
    state.recentDeaths = state.recentDeaths + 1
end

function Elastic.onDamageTaken(amount)
    state.recentDamageTaken = state.recentDamageTaken + amount
end

---------------------------------------------------------------------------
-- Queries — other systems read these for scaling
---------------------------------------------------------------------------

function Elastic.getBandId()
    return state.bandId
end

function Elastic.getSmoothedStress()
    return state.smoothedStress
end

function Elastic.getTrend()
    return state.trend
end

-- Get the current band's modifier table
function Elastic.getModifiers()
    local band = BANDS[state.bandIndex]
    local mods = {
        reinforcementRate = band.reinforcementRate,
        aggressionMod     = band.aggressionMod,
        eventSpeedMod     = band.eventSpeedMod,
        lootMod           = band.lootMod,
    }

    -- Trend-based micro-adjustments
    if state.trend == 'rising' and state.bandId ~= 'overwhelmed' then
        mods.reinforcementRate = mods.reinforcementRate * 0.85
        mods.aggressionMod     = mods.aggressionMod * 0.95
    elseif state.trend == 'falling' and state.bandId ~= 'bored' then
        mods.reinforcementRate = mods.reinforcementRate * 1.1
        mods.aggressionMod     = mods.aggressionMod * 1.05
    end

    return mods
end

-- Convenience: get single modifier
function Elastic.getReinforcementRate()
    return Elastic.getModifiers().reinforcementRate
end

function Elastic.getAggressionMod()
    return Elastic.getModifiers().aggressionMod
end

function Elastic.getEventSpeedMod()
    return Elastic.getModifiers().eventSpeedMod
end

function Elastic.getLootMod()
    return Elastic.getModifiers().lootMod
end

---------------------------------------------------------------------------
-- Colony wellness score (0-100) — composite health metric for storyteller
-- Combines: colonist health, food security, morale, active threats
---------------------------------------------------------------------------

function Elastic.getColonyWellness()
    local colonistCount = ECS.countWith('colonist')
    if colonistCount == 0 then return 0 end

    -- Health component (0-25)
    local totalHp, totalMaxHp = 0, 0
    local totalMorale, moraleCount = 0, 0
    for id, comps in ECS.query('colonist', 'needs') do
        local col = comps.colonist
        if col.state ~= 'dead' then
            totalHp    = totalHp + (col.health or 100)
            totalMaxHp = totalMaxHp + (col.maxHealth or 100)
            totalMorale = totalMorale + (comps.needs.morale or 50)
            moraleCount = moraleCount + 1
        end
    end
    local healthScore = totalMaxHp > 0 and (totalHp / totalMaxHp) * 25 or 0

    -- Food security (0-25)
    local food = GameState.resources.food or 0
    local foodPerColonist = food / math.max(1, colonistCount)
    local foodScore = math.min(25, foodPerColonist * 2.5)

    -- Average morale (0-25)
    local avgMorale = moraleCount > 0 and totalMorale / moraleCount or 50
    local moraleScore = avgMorale * 0.25

    -- Threat inverse (0-25): low stress = high wellness
    local stressInverse = (1 - state.smoothedStress) * 25

    return math.floor(healthScore + foodScore + moraleScore + stressInverse + 0.5)
end

---------------------------------------------------------------------------
-- Save / restore
---------------------------------------------------------------------------

function Elastic.getState()
    return {
        smoothedStress    = state.smoothedStress,
        history           = state.history,
        recentDeaths      = state.recentDeaths,
        recentDamageTaken = state.recentDamageTaken,
    }
end

function Elastic.restoreState(s)
    if not s then return end
    state.smoothedStress    = s.smoothedStress or 0.25
    state.history           = s.history or {}
    state.recentDeaths      = s.recentDeaths or 0
    state.recentDamageTaken = s.recentDamageTaken or 0

    local band, idx = findBand(state.smoothedStress)
    state.bandId    = band.id
    state.bandIndex = idx
    state.trend     = detectTrend(state.history)
end

function Elastic.init()
    state.rawStress         = 0
    state.smoothedStress    = 0.25
    state.history           = {}
    state.trend             = 'stable'
    state.bandId            = 'engaged'
    state.bandIndex         = 3
    state.recentDeaths      = 0
    state.recentDamageTaken = 0
    state.tickTimer         = 0
end

return Elastic
