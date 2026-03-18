-- seasons.lua — Season cycle system
-- 4 seasons with temperature curves, weather bias, and gameplay modifiers.
-- On this frozen planet, seasons are variations of cold:
--   Deep Winter (-60C), Late Winter (-45C), Thaw (-15C), Freeze (-30C)
-- Each season lasts SEASON_LENGTH game-days (default 15).

local GameState = require('src.game_state')

local Seasons = {}

---------------------------------------------------------------------------
-- Season definitions
---------------------------------------------------------------------------

local SEASON_LENGTH = 15  -- game-days per season

local SEASONS = {
    deep_winter = {
        name       = 'Deep Winter',
        order      = 1,
        baseTemp   = -60,
        -- Temperature oscillates within season (day 1 = entry, midpoint = peak)
        tempRange  = 8,       -- +/- from baseTemp across the season
        daylight   = { rise = 9, set = 15 },  -- short days
        forageBonus = -0.5,   -- 50% less forage
        growthMult  = 0.3,    -- crops grow very slowly
        raidMult    = 0.6,    -- fewer raids (too cold for attackers too)
        weatherBias = {       -- weight multipliers for weather transitions
            blizzard = 2.0,
            whiteout = 2.0,
            warm_front = 0.2,
            aurora = 1.5,
        },
        desc = 'The coldest stretch. Blizzards are frequent, daylight is scarce.',
    },
    late_winter = {
        name       = 'Late Winter',
        order      = 2,
        baseTemp   = -45,
        tempRange  = 10,
        daylight   = { rise = 7, set = 17 },
        forageBonus = -0.2,
        growthMult  = 0.6,
        raidMult    = 0.8,
        weatherBias = {
            blizzard = 1.2,
            warm_front = 0.5,
        },
        desc = 'The cold eases slightly. Days grow longer. Creatures stir.',
    },
    thaw = {
        name       = 'Thaw',
        order      = 3,
        baseTemp   = -15,
        tempRange  = 12,
        daylight   = { rise = 5, set = 21 },  -- long days
        forageBonus = 0.5,    -- 50% more forage
        growthMult  = 1.5,    -- best growing season
        raidMult    = 1.3,    -- raids increase (warmer = easier travel)
        weatherBias = {
            warm_front = 3.0,
            blizzard = 0.3,
            whiteout = 0.1,
            clear = 1.5,
        },
        meltwater = true,     -- chance of meltwater flood events
        desc = 'The warmest it gets. Meltwater flows, foraging peaks, but so do raids.',
    },
    freeze = {
        name       = 'Freeze',
        order      = 4,
        baseTemp   = -30,
        tempRange  = 10,
        daylight   = { rise = 7, set = 18 },
        forageBonus = 0.0,
        growthMult  = 0.8,
        raidMult    = 1.0,
        weatherBias = {
            snowfall = 1.5,
            blizzard = 0.8,
        },
        desc = 'Temperatures drop again. Time to stockpile before deep winter.',
    },
}

-- Ordered season keys for cycling
local SEASON_ORDER = { 'deep_winter', 'late_winter', 'thaw', 'freeze' }

Seasons.SEASONS = SEASONS
Seasons.SEASON_ORDER = SEASON_ORDER
Seasons.SEASON_LENGTH = SEASON_LENGTH

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local currentSeason = 'deep_winter'
local seasonDay     = 1         -- day within current season (1 to SEASON_LENGTH)
local lastGameDay   = 1         -- last game day we processed
local yearCount     = 1         -- how many full cycles completed
local initialized   = false

---------------------------------------------------------------------------
-- Init — called at game start
---------------------------------------------------------------------------

function Seasons.init()
    -- Check for planet-specific season overrides
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then
        local ps = Planet.getSeasons()
        if ps then
            if ps.defs then
                for k, v in pairs(ps.defs) do SEASONS[k] = v end
            end
            if ps.order then SEASON_ORDER = ps.order end
            if ps.length then SEASON_LENGTH = ps.length end
            if ps.startSeason then
                currentSeason = ps.startSeason
            else
                currentSeason = SEASON_ORDER[1] or 'late_winter'
            end
        else
            currentSeason = 'late_winter'
        end
    else
        currentSeason = 'late_winter'   -- start in Late Winter so new colonies can establish
    end
    seasonDay     = 1
    lastGameDay   = GameState.day
    yearCount     = 1
    initialized   = true
    Seasons.SEASONS = SEASONS
    Seasons.SEASON_ORDER = SEASON_ORDER
    Seasons.SEASON_LENGTH = SEASON_LENGTH
    Seasons._applySeasonTemp()
end

---------------------------------------------------------------------------
-- Apply season base temperature to GameState
---------------------------------------------------------------------------

function Seasons._applySeasonTemp()
    if not initialized then return end
    local def = SEASONS[currentSeason]
    if not def then return end

    -- Sinusoidal temperature curve within the season
    -- Mid-season is the peak (warmest for thaw, coldest for deep_winter)
    local progress = (seasonDay - 1) / math.max(1, SEASON_LENGTH - 1)
    local curve = math.sin(progress * math.pi)  -- 0 at edges, 1 at midpoint
    local tempOffset = def.tempRange * curve
    local bias = GameState.tempBias or 0

    -- For cold seasons, midpoint is slightly warmer; for thaw, midpoint is warmest
    GameState.baseTemp = def.baseTemp + tempOffset + bias
    GameState.season   = currentSeason
end

---------------------------------------------------------------------------
-- Advance season
---------------------------------------------------------------------------

local function advanceSeason()
    local idx = 1
    for i, key in ipairs(SEASON_ORDER) do
        if key == currentSeason then idx = i; break end
    end
    idx = idx + 1
    if idx > #SEASON_ORDER then
        idx = 1
        yearCount = yearCount + 1
    end
    local prevSeason = currentSeason
    currentSeason = SEASON_ORDER[idx]
    seasonDay = 1

    -- Notify storyteller of season change
    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.onSeasonChange then
        Storyteller.onSeasonChange(prevSeason, currentSeason)
    end
end

---------------------------------------------------------------------------
-- Step — called each sim tick, tracks day changes
---------------------------------------------------------------------------

function Seasons.step(dt)
    if not initialized then return end
    local gameDay = GameState.day
    if gameDay ~= lastGameDay then
        local daysElapsed = gameDay - lastGameDay
        lastGameDay = gameDay

        for _ = 1, daysElapsed do
            seasonDay = seasonDay + 1
            if seasonDay > SEASON_LENGTH then
                advanceSeason()
            end
        end

        Seasons._applySeasonTemp()
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Seasons.getCurrent()
    return currentSeason, SEASONS[currentSeason]
end

function Seasons.getSeasonDay()
    return seasonDay
end

function Seasons.getSeasonProgress()
    return seasonDay / SEASON_LENGTH
end

function Seasons.getYear()
    return yearCount
end

function Seasons.getGrowthMult()
    local def = SEASONS[currentSeason]
    return def and def.growthMult or 1.0
end

function Seasons.getForageBonus()
    local def = SEASONS[currentSeason]
    return def and def.forageBonus or 0.0
end

function Seasons.getRaidMult()
    local def = SEASONS[currentSeason]
    return def and def.raidMult or 1.0
end

function Seasons.getWeatherBias(weatherType)
    local def = SEASONS[currentSeason]
    if not def or not def.weatherBias then return 1.0 end
    return def.weatherBias[weatherType] or 1.0
end

function Seasons.getDaylight()
    if not initialized then
        return { rise = 6, set = 20 }
    end
    local def = SEASONS[currentSeason]
    if not def or not def.daylight then
        return { rise = 6, set = 20 }
    end
    return def.daylight
end

function Seasons.isInitialized()
    return initialized
end

function Seasons.hasMeltwater()
    local def = SEASONS[currentSeason]
    return def and def.meltwater or false
end

function Seasons.getSeasonName()
    local def = SEASONS[currentSeason]
    return def and def.name or 'Unknown'
end

function Seasons.getSeasonDesc()
    local def = SEASONS[currentSeason]
    return def and def.desc or ''
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Seasons.getState()
    if not initialized then return nil end
    return {
        initialized   = true,
        currentSeason = currentSeason,
        seasonDay     = seasonDay,
        lastGameDay   = lastGameDay,
        yearCount     = yearCount,
    }
end

function Seasons.loadState(saved)
    if not saved then return end
    initialized = saved.initialized ~= false
    if not initialized then return end
    currentSeason = saved.currentSeason or 'deep_winter'
    seasonDay     = saved.seasonDay or 1
    lastGameDay   = saved.lastGameDay or GameState.day
    yearCount     = saved.yearCount or 1
    Seasons._applySeasonTemp()
end

return Seasons
