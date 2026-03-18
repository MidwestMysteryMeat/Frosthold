-- weather.lua — Weather system
-- Drives ambient temperature, wind chill, visibility, and storm events.
-- Ticks each sim step. The storyteller can force weather transitions.

local GameState = require('src.game_state')
local Tuning    = require('src.sim.tuning')

local Weather = {}

-- Weather types with their modifiers
local TYPES = {
    clear = {
        name       = 'Clear',
        tempMod    = 0,        -- added to base temp
        windChill  = 0,
        visibility = 1.0,      -- 1.0 = full, 0.0 = blind
        snowRate   = 0,        -- snow accumulation per second
        minDuration = 120,     -- seconds at 1x speed
        maxDuration = 600,
        solarPenalty = 0,      -- no solar reduction
    },
    overcast = {
        name       = 'Overcast',
        tempMod    = -5,
        windChill  = -3,
        visibility = 0.85,
        snowRate   = 0.01,
        minDuration = 60,
        maxDuration = 300,
        rain         = true,   -- light precipitation suppresses fire
        solarPenalty = 0.5,    -- clouds block 50% of sunlight
    },
    snowfall = {
        name       = 'Snowfall',
        tempMod    = -10,
        windChill  = -5,
        visibility = 0.6,
        snowRate   = 0.05,
        minDuration = 60,
        maxDuration = 240,
        snow         = true,   -- snow suppresses fire
        solarPenalty = 0.7,    -- heavy clouds
    },
    blizzard = {
        name       = 'Blizzard',
        tempMod    = -25,
        windChill  = -15,
        visibility = 0.2,
        snowRate   = 0.15,
        minDuration = 30,
        maxDuration = 120,
        snow         = true,
        lightning    = true,   -- electrical storms during blizzards
        solarPenalty = 0.95,   -- near-total cloud cover
    },
    whiteout = {
        name       = 'Whiteout',
        tempMod    = -35,
        windChill  = -25,
        visibility = 0.05,
        snowRate   = 0.3,
        minDuration = 20,
        maxDuration = 60,
        snow         = true,
        lightning    = true,   -- severe electrical activity
        solarPenalty = 1.0,    -- complete cloud cover
    },
    warm_front = {
        name       = 'Warm Front',
        tempMod    = 15,
        windChill  = 0,
        visibility = 0.9,
        snowRate   = 0,
        minDuration = 40,
        maxDuration = 180,
        rain         = true,   -- warm front brings rain
        solarPenalty = 0.3,    -- partial clouds
    },
    aurora = {
        name       = 'Aurora',
        tempMod    = -5,
        windChill  = 0,
        visibility = 0.95,
        snowRate   = 0,
        minDuration = 60,
        maxDuration = 300,
        moraleBuff = 0.2,  -- per second
        solarPenalty = 0,
    },
    blood_rain = {
        name       = 'Blood Rain',
        tempMod    = 5,
        windChill  = -2,
        visibility = 0.55,
        snowRate   = 0.08,  -- particle spawn rate (reuses snow particles, colored red)
        minDuration = 60,
        maxDuration = 180,
        rain         = true,
        floods       = true,  -- injects water into outdoor tiles
        solarPenalty = 0.8,
    },
    -- Desert weather (Rhea-2)
    sandstorm = {
        name       = 'Sandstorm',
        tempMod    = 10,
        windChill  = 5,
        visibility = 0.1,
        snowRate   = 0.25,   -- reused for sand particles
        minDuration = 30,
        maxDuration = 120,
        solarPenalty = 0.9,
    },
    heat_wave = {
        name       = 'Heat Wave',
        tempMod    = 20,
        windChill  = 0,
        visibility = 0.85,
        snowRate   = 0,
        minDuration = 120,
        maxDuration = 480,
        solarPenalty = 0,
    },
    dust_devil = {
        name       = 'Dust Devil',
        tempMod    = 5,
        windChill  = 3,
        visibility = 0.6,
        snowRate   = 0.08,
        minDuration = 20,
        maxDuration = 80,
        solarPenalty = 0.2,
    },
    -- Acid weather (Morvos)
    acid_storm = {
        name       = 'Acid Storm',
        tempMod    = -5,
        windChill  = -3,
        visibility = 0.15,
        snowRate   = 0.2,
        minDuration = 30,
        maxDuration = 120,
        rain       = true,
        solarPenalty = 0.85,
    },
    corrosive_fog = {
        name       = 'Corrosive Fog',
        tempMod    = 0,
        windChill  = 0,
        visibility = 0.25,
        snowRate   = 0.03,
        minDuration = 60,
        maxDuration = 240,
        solarPenalty = 0.6,
    },
    toxic_haze = {
        name       = 'Toxic Haze',
        tempMod    = 3,
        windChill  = 0,
        visibility = 0.5,
        snowRate   = 0.01,
        minDuration = 60,
        maxDuration = 300,
        solarPenalty = 0.4,
    },
    spore_cloud = {
        name       = 'Spore Cloud',
        tempMod    = 2,
        windChill  = 0,
        visibility = 0.4,
        snowRate   = 0.1,
        minDuration = 40,
        maxDuration = 180,
        solarPenalty = 0.5,
    },
    -- Ocean weather (Nerthus-9)
    heavy_rain = {
        name       = 'Heavy Rain',
        tempMod    = -3,
        windChill  = -5,
        visibility = 0.35,
        snowRate   = 0.15,
        minDuration = 40,
        maxDuration = 180,
        rain       = true,
        floods     = true,
        solarPenalty = 0.7,
    },
    hurricane = {
        name       = 'Hurricane',
        tempMod    = -8,
        windChill  = -20,
        visibility = 0.08,
        snowRate   = 0.3,
        minDuration = 20,
        maxDuration = 80,
        rain       = true,
        floods     = true,
        lightning  = true,
        solarPenalty = 0.95,
    },
    storm = {
        name       = 'Storm',
        tempMod    = -5,
        windChill  = -10,
        visibility = 0.3,
        snowRate   = 0.12,
        minDuration = 30,
        maxDuration = 120,
        rain       = true,
        lightning  = true,
        solarPenalty = 0.75,
    },
    -- Temperate weather (Paxtera Prime, Gaia A^1x)
    rain = {
        name       = 'Rain',
        tempMod    = -2,
        windChill  = -2,
        visibility = 0.7,
        snowRate   = 0.06,
        minDuration = 40,
        maxDuration = 200,
        rain       = true,
        solarPenalty = 0.4,
    },
    -- Nemaea weather (dead world)
    solar_flare = {
        name       = 'Solar Flare',
        tempMod    = 40,
        windChill  = 0,
        visibility = 0.7,
        snowRate   = 0,
        minDuration = 20,
        maxDuration = 90,
        solarPenalty = 0,
    },
    meteor_shower = {
        name       = 'Meteor Shower',
        tempMod    = -10,
        windChill  = -5,
        visibility = 0.5,
        snowRate   = 0.08,
        minDuration = 30,
        maxDuration = 120,
        lightning  = true,
        solarPenalty = 0.3,
    },
    radiation_burst = {
        name       = 'Radiation Burst',
        tempMod    = 5,
        windChill  = 0,
        visibility = 0.8,
        snowRate   = 0,
        minDuration = 15,
        maxDuration = 60,
        solarPenalty = 0.1,
    },
    -- Gaia A^1x weather
    spore_fall = {
        name       = 'Spore Fall',
        tempMod    = -3,
        windChill  = 0,
        visibility = 0.35,
        snowRate   = 0.15,
        minDuration = 40,
        maxDuration = 180,
        rain       = true,
        solarPenalty = 0.6,
    },
}

-- Transition weights: from → { to = weight, ... }
local TRANSITIONS = {
    clear     = { clear = 3, overcast = 4, snowfall = 1, aurora = 1 },
    overcast  = { clear = 2, overcast = 2, snowfall = 4, blizzard = 1 },
    snowfall  = { overcast = 3, snowfall = 2, blizzard = 2, clear = 1 },
    blizzard  = { blizzard = 1, snowfall = 3, whiteout = 1, overcast = 2 },
    whiteout  = { blizzard = 4, snowfall = 2 },
    warm_front= { clear = 4, overcast = 2 },
    aurora    = { clear = 4, overcast = 1 },
    blood_rain = { overcast = 3, clear = 2 },
    -- Desert transitions
    sandstorm  = { sandstorm = 1, dust_devil = 2, clear = 2, heat_wave = 1 },
    heat_wave  = { heat_wave = 2, clear = 3, dust_devil = 1 },
    dust_devil = { clear = 3, dust_devil = 1, sandstorm = 1 },
    -- Acid transitions
    acid_storm    = { acid_storm = 1, corrosive_fog = 3, toxic_haze = 1, clear = 1 },
    corrosive_fog = { corrosive_fog = 1, toxic_haze = 2, clear = 2, acid_storm = 1 },
    toxic_haze    = { toxic_haze = 1, clear = 3, spore_cloud = 1 },
    spore_cloud   = { spore_cloud = 1, clear = 2, toxic_haze = 1 },
    -- Ocean transitions
    heavy_rain = { heavy_rain = 1, storm = 2, hurricane = 1, overcast = 2, clear = 1 },
    hurricane  = { storm = 3, heavy_rain = 2 },
    storm      = { storm = 1, heavy_rain = 2, overcast = 2, clear = 1 },
    -- Temperate transitions
    rain       = { rain = 1, overcast = 2, clear = 3 },
    -- Nemaea transitions
    solar_flare    = { clear = 4, radiation_burst = 1 },
    meteor_shower  = { clear = 3, meteor_shower = 1 },
    radiation_burst = { clear = 3, radiation_burst = 1 },
    -- Gaia transitions
    spore_fall = { spore_fall = 1, overcast = 2, clear = 2 },
}

-- State
local current       = 'clear'
local timeRemaining = 300
local transitionAlpha = 1.0  -- 0→1 blend from previous to current
local prevType      = 'clear'
local windAngle     = 0      -- radians, for particle direction
local windSpeed     = 0      -- 0-1 normalized

-- Particle state for visual snow/wind
local particles     = {}
local MAX_PARTICLES = 400

-- Lightning flash state
local lightningAlpha = 0
local lightningTimer = 0
local function wtune(key, fallback)
    return Tuning.get('weather.' .. key, fallback)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

-- Blood rain easter egg state
local bloodRainFired = false

-- Rain flooding state
local rainFloodTimer = 0
local RAIN_FLOOD_INTERVAL = 3        -- seconds between flood pulses (normal rain)
local BLOOD_RAIN_FLOOD_INTERVAL = 1  -- seconds between flood pulses (blood rain — heavy)

function Weather.init()
    -- Apply planet-specific weather type/transition overrides (merge, not replace)
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok and Planet.getWeatherTypes then
        local pw = Planet.getWeatherTypes()
        if pw then
            if pw.types then
                for k, v in pairs(pw.types) do
                    TYPES[k] = v
                end
            end
            if pw.transitions then
                for k, v in pairs(pw.transitions) do
                    TRANSITIONS[k] = v
                end
            end
        end
    end

    current = 'clear'
    timeRemaining = 200 + math.random(200)
    transitionAlpha = 1.0
    prevType = 'clear'
    windAngle = math.random() * math.pi * 2
    windSpeed = 0.1
    particles = {}
    lightningAlpha = 0
    bloodRainFired = false
    rainFloodTimer = 0
    local minInterval = wtune('lightning_interval_min', 8)
    local maxInterval = wtune('lightning_interval_max', 25)
    lightningTimer = minInterval + math.random() * math.max(0, maxInterval - minInterval)
end

-- Check if any living colonist has "Fischbach" as their last name
local function hasFischbachColonist()
    local eok, ECS = pcall(require, 'src.ecs.ecs')
    if not eok then return false end
    for _, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' and comps.colonist.name then
            if comps.colonist.name:match('%s[Ff]ischbach$') then
                return true
            end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Weighted random pick from transition table
---------------------------------------------------------------------------

local isSevereType
local isCalmType
local getWeatherHarshness
local getScaledDuration
local getEffectiveTempMod
local getEffectiveWindChill
local applyHarshnessBias

applyHarshnessBias = function(typeName, weight, harshness)
    local delta = (harshness or 1.0) - 1.0
    if delta > 0 then
        if isSevereType(typeName) then
            weight = weight * (1 + delta * wtune('severe_bias_per_harshness', 0.9))
        elseif isCalmType(typeName) then
            weight = weight / (1 + delta * wtune('calm_suppression_per_harshness', 0.55))
        end
    elseif delta < 0 then
        local calmDelta = -delta
        if isSevereType(typeName) then
            weight = weight / (1 + calmDelta * wtune('severe_suppression_per_harshness', 1.0))
        elseif isCalmType(typeName) then
            weight = weight * (1 + calmDelta * wtune('calm_bias_per_harshness', 0.8))
        end
    end
    return weight
end

function Weather.getTransitionWeights(from)
    local weights = TRANSITIONS[from]
    if not weights then return { clear = 1 } end

    local harshness = getWeatherHarshness()
    local sok, Seasons = pcall(require, 'src.world.seasons')
    local biased = {}
    for typ, w in pairs(weights) do
        local bias = 1.0
        if sok then bias = Seasons.getWeatherBias(typ) end
        local adjusted = w * bias
        adjusted = applyHarshnessBias(typ, adjusted, harshness)
        biased[typ] = adjusted
    end
    return biased
end

local function pickNext(from)
    local biased = Weather.getTransitionWeights(from)

    local total = 0
    for _, w in pairs(biased) do total = total + w end
    local roll = math.random() * total
    for typ, w in pairs(biased) do
        roll = roll - w
        if roll <= 0 then return typ end
    end
    return 'clear'
end

---------------------------------------------------------------------------
-- Helpers (declared before use)
---------------------------------------------------------------------------

local function lerp(a, b, t)
    return a + (b - a) * math.max(0, math.min(1, t))
end

-- Simple HSL→RGB for aurora colors
isSevereType = function(typeName)
    return typeName == 'snowfall' or typeName == 'blizzard' or typeName == 'whiteout'
end

isCalmType = function(typeName)
    return typeName == 'clear' or typeName == 'warm_front' or typeName == 'aurora'
end

getWeatherHarshness = function()
    local harshness = GameState.weatherHarshness or 1.0
    local aok, Anomaly = pcall(require, 'src.sim.anomaly')
    if aok and Anomaly.getWeatherMult then
        harshness = harshness * Anomaly.getWeatherMult()
    end
    return math.max(wtune('harshness_min', 0.5), math.min(wtune('harshness_max', 2.0), harshness))
end

getScaledDuration = function(typeName, def)
    local harshness = getWeatherHarshness()
    local minDuration = def.minDuration
    local maxDuration = def.maxDuration
    if isSevereType(typeName) then
        minDuration = minDuration * harshness
        maxDuration = maxDuration * harshness
    elseif isCalmType(typeName) then
        minDuration = minDuration / harshness
        maxDuration = maxDuration / harshness
    end
    minDuration = math.max(5, math.floor(minDuration + 0.5))
    maxDuration = math.max(minDuration, math.floor(maxDuration + 0.5))
    return minDuration + math.random(math.max(1, maxDuration - minDuration))
end

getEffectiveTempMod = function(typeName, def)
    local tempMod = def.tempMod or 0
    local harshness = getWeatherHarshness()
    if tempMod < 0 then
        return tempMod * harshness
    elseif tempMod > 0 then
        local comfort = math.max(0.5, math.min(1.5, 2 - harshness))
        return tempMod * comfort
    end
    return 0
end

getEffectiveWindChill = function(def)
    local windChill = def.windChill or 0
    if windChill == 0 then return 0 end
    return windChill * getWeatherHarshness()
end

local function hslToRgb(h, s, l)
    if s == 0 then return l, l, l end
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return hue2rgb(p, q, h + 1/3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1/3)
end

---------------------------------------------------------------------------
-- Force a specific weather (used by storyteller)
---------------------------------------------------------------------------

function Weather.force(typeName, duration)
    if not TYPES[typeName] then return end
    prevType = current
    current = typeName
    local def = TYPES[typeName]
    timeRemaining = duration or getScaledDuration(typeName, def)
    transitionAlpha = 0
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Weather.step(dt)
    -- Transition blend
    if transitionAlpha < 1 then
        transitionAlpha = math.min(1, transitionAlpha + dt * wtune('transition_rate', 0.1))
    end

    -- Countdown
    timeRemaining = timeRemaining - dt
    if timeRemaining <= 0 then
        prevType = current
        current = pickNext(current)

        -- Easter egg: first rain event becomes blood rain if a Fischbach colonist exists
        if not bloodRainFired and TYPES[current] and TYPES[current].rain then
            if hasFischbachColonist() then
                current = 'blood_rain'
                bloodRainFired = true
            end
        end

        -- Scar trait: surviving a whiteout
        if prevType == 'whiteout' then
            local scarOk, ScarTraits = pcall(require, 'src.colonist.scar_traits')
            if scarOk then
                local ecsOk, ECS2 = pcall(require, 'src.ecs.ecs')
                if ecsOk then
                    for id, comps in ECS2.query('colonist') do
                        if comps.colonist.state ~= 'dead' then
                            ScarTraits.onWhiteoutSurvived(id)
                        end
                    end
                end
            end
        end
        local def = TYPES[current]
        timeRemaining = getScaledDuration(current, def)
        transitionAlpha = 0
    end

    -- Apply modifiers to GameState
    local def = TYPES[current]
    local prevDef = TYPES[prevType]
    local a = transitionAlpha

    local prevTempMod = getEffectiveTempMod(prevType, prevDef)
    local tempMod = getEffectiveTempMod(current, def)
    local prevWindChill = getEffectiveWindChill(prevDef)
    local windChill = getEffectiveWindChill(def)

    GameState.globalTemp = GameState.baseTemp + lerp(prevTempMod, tempMod, a)
    GameState.windChill  = lerp(prevWindChill, windChill, a)

    -- Wind drift
    windAngle = windAngle + (math.random() - 0.5) * wtune('wind_angle_drift', 0.3) * dt
    local targetWind = math.abs(windChill) / 30
    windSpeed = windSpeed + (targetWind - windSpeed) * wtune('wind_speed_response', 0.05) * dt

    -- Aurora morale buff
    if current == 'aurora' and def.moraleBuff then
        local ECS = require('src.ecs.ecs')
        for id, comps in ECS.query('needs') do
            comps.needs.morale = math.min(100, comps.needs.morale + def.moraleBuff * dt)
        end
    end

    -- Rain flooding — prolonged rain adds water to outdoor surface tiles
    if def.rain then
        local interval = (current == 'blood_rain') and BLOOD_RAIN_FLOOD_INTERVAL or RAIN_FLOOD_INTERVAL
        rainFloodTimer = rainFloodTimer + dt
        if rainFloodTimer >= interval then
            rainFloodTimer = rainFloodTimer - interval
            local wOk, World = pcall(require, 'src.world.tilemap')
            if wOk then
                local fOk, TileFluids = pcall(require, 'src.sim.tile_fluids')
                if fOk then
                    local mw = World.width()
                    local mh = World.height()
                    local tileData = World.rawTileData(0)
                    local roomData = World.rawRoomData(0)
                    if tileData and roomData then
                        local Tiles = require('src.world.tiles')
                        local waterAmount = (current == 'blood_rain') and 2 or 1
                        -- Sample a subset of outdoor tiles per pulse to avoid perf spikes
                        local size = mw * mh
                        local samples = math.min(size, (current == 'blood_rain') and 120 or 40)
                        for _ = 1, samples do
                            local idx = math.random(1, size)
                            local tile = tileData[idx]
                            local rid = roomData[idx] or 0
                            if rid == 0 and not Tiles.isSolid(tile) then
                                local tx = (idx - 1) % mw
                                local ty = math.floor((idx - 1) / mw)
                                TileFluids.addWater(tx, ty, waterAmount, 0)
                            end
                        end
                    end
                end
            end
        end
    else
        rainFloodTimer = 0
    end
end

---------------------------------------------------------------------------
-- Particle update (called in love.update, not sim tick)
---------------------------------------------------------------------------

function Weather.updateParticles(dt, camX, camY, screenW, screenH, camZoom)
    local def = TYPES[current]
    local rate = def.snowRate

    -- Lightning flash update (blizzard/whiteout only)
    if current == 'blizzard' or current == 'whiteout' then
        lightningTimer = lightningTimer - dt
        if lightningTimer <= 0 then
            lightningAlpha = 0.7 + math.random() * 0.3
            local minInterval = wtune('lightning_interval_min', 8)
            local maxInterval = wtune('lightning_interval_max', 25)
            lightningTimer = minInterval + math.random() * math.max(0, maxInterval - minInterval)
            -- Trigger screen shake for nearby lightning
            local camOk, Camera = pcall(require, 'src.render.camera')
            if camOk and Camera.shake then Camera.shake(3) end
        end
        if lightningAlpha > 0 then
            lightningAlpha = math.max(0, lightningAlpha - dt * 4)
        end
    else
        lightningAlpha = 0
    end

    -- Spawn particles
    if rate > 0 and #particles < MAX_PARTICLES then
        local toSpawn = math.ceil(rate * 60 * dt)
        for i = 1, toSpawn do
            if #particles >= MAX_PARTICLES then break end
            particles[#particles + 1] = {
                x = camX + math.random() * screenW / camZoom,
                y = camY - 10 - math.random(40),
                vx = math.cos(windAngle) * windSpeed * 80 + (math.random() - 0.5) * 20,
                vy = 30 + math.random() * 40,
                size = 1 + math.random() * 2,
                life = 3 + math.random() * 4,
                alpha = 0.4 + math.random() * 0.5,
            }
        end
    end

    -- Update existing
    local i = 1
    while i <= #particles do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 or p.y > camY + screenH / camZoom + 20 then
            particles[i] = particles[#particles]
            particles[#particles] = nil
        else
            i = i + 1
        end
    end
end

---------------------------------------------------------------------------
-- Draw weather particles (called between camera attach/detach)
---------------------------------------------------------------------------

function Weather.drawParticles()
    local def = TYPES[current]
    if def.snowRate <= 0 and #particles == 0 then return end

    -- Blizzard/whiteout: draw particles as horizontal streaks
    local isHeavy = (current == 'blizzard' or current == 'whiteout')

    local isBlood = (current == 'blood_rain')

    for _, p in ipairs(particles) do
        if isBlood then
            love.graphics.setColor(0.6, 0.05, 0.05, p.alpha)
        elseif current == 'sandstorm' or current == 'dust_devil' then
            love.graphics.setColor(0.9, 0.78, 0.5, p.alpha)
        elseif current == 'acid_storm' or current == 'corrosive_fog' or current == 'toxic_haze' then
            love.graphics.setColor(0.4, 0.8, 0.2, p.alpha)
        elseif current == 'spore_cloud' or current == 'spore_fall' then
            love.graphics.setColor(0.7, 0.9, 0.3, p.alpha)
        elseif current == 'heavy_rain' or current == 'hurricane' or current == 'storm' or current == 'rain' then
            love.graphics.setColor(0.5, 0.6, 0.8, p.alpha)
        elseif current == 'meteor_shower' then
            love.graphics.setColor(1.0, 0.6, 0.3, p.alpha)
        else
            love.graphics.setColor(0.9, 0.92, 0.95, p.alpha)
        end
        if isHeavy then
            local streak = 3 + p.size * 4
            love.graphics.rectangle('fill', p.x, p.y, streak, 1)
        elseif isBlood then
            -- Blood rain: longer vertical streaks
            love.graphics.rectangle('fill', p.x, p.y, 1, p.size * 3)
        else
            love.graphics.circle('fill', p.x, p.y, p.size)
        end
    end
end

---------------------------------------------------------------------------
-- Draw visibility overlay (screen-space, after camera detach)
---------------------------------------------------------------------------

function Weather.drawOverlay(screenW, screenH)
    local def = TYPES[current]
    local prevDef = TYPES[prevType]
    local vis = lerp(prevDef.visibility, def.visibility, transitionAlpha)

    -- Night tint (dark blue overlay outside daylight hours)
    local hour = GameState.hour or 12
    local sunRise, sunSet = 6, 20
    local sok, Seasons = pcall(require, 'src.world.seasons')
    if sok then
        local dl = Seasons.getDaylight()
        sunRise = dl.rise
        sunSet  = dl.set
    end
    local nightFactor = 0
    if hour >= sunSet then
        nightFactor = math.min(1, (hour - sunSet) / 2)
    elseif hour < sunRise then
        nightFactor = 1
    elseif hour < sunRise + 2 then
        nightFactor = math.max(0, 1 - (hour - sunRise) / 2)
    end
    if nightFactor > 0 then
        love.graphics.setColor(0.02, 0.02, 0.12, nightFactor * 0.35)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Fog / visibility overlay
    if vis < 0.99 then
        local fog = 1 - vis
        love.graphics.setColor(0.85, 0.88, 0.92, fog * 0.7)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Cold color grade for blizzard/whiteout (desaturated blue wash)
    if current == 'blizzard' or current == 'whiteout' then
        local cold = (current == 'whiteout') and 0.12 or 0.06
        cold = cold * transitionAlpha
        love.graphics.setColor(0.6, 0.7, 1.0, cold)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Warm front golden tint
    if current == 'warm_front' then
        love.graphics.setColor(1, 0.85, 0.5, 0.06 * transitionAlpha)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Blood rain crimson tint
    if current == 'blood_rain' then
        love.graphics.setColor(0.5, 0.02, 0.02, 0.12 * transitionAlpha)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    local vis_inv = 1 - vis

    -- Sandstorm overlay (orange-brown tint)
    if current == 'sandstorm' or current == 'dust_devil' then
        love.graphics.setColor(0.6, 0.4, 0.15, 0.15 * vis_inv)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Acid overlay (green tint)
    if current == 'acid_storm' or current == 'corrosive_fog' or current == 'toxic_haze' then
        love.graphics.setColor(0.2, 0.5, 0.1, 0.12 * vis_inv)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Spore overlay (yellow-green)
    if current == 'spore_cloud' or current == 'spore_fall' then
        love.graphics.setColor(0.4, 0.5, 0.1, 0.1 * vis_inv)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Ocean storm overlay (dark blue-grey)
    if current == 'hurricane' or current == 'storm' or current == 'heavy_rain' then
        love.graphics.setColor(0.1, 0.15, 0.25, 0.12 * vis_inv)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Solar flare overlay (bright orange)
    if current == 'solar_flare' then
        love.graphics.setColor(0.8, 0.4, 0.1, 0.15)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Radiation burst overlay (pale green glow)
    if current == 'radiation_burst' then
        love.graphics.setColor(0.3, 0.6, 0.2, 0.1)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Lightning flash during blizzard/whiteout
    if lightningAlpha > 0 then
        love.graphics.setColor(0.95, 0.95, 1.0, lightningAlpha)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
    end

    -- Aurora shimmer
    if current == 'aurora' then
        local t = love.timer.getTime()
        for i = 0, 4 do
            local ax = screenW * (0.1 + i * 0.2) + math.sin(t * 0.5 + i) * 60
            local ay = screenH * 0.05 + math.sin(t * 0.3 + i * 1.5) * 30
            local ah = screenH * 0.3
            local hue = (t * 0.1 + i * 0.15) % 1
            local r, g, b = hslToRgb(hue, 0.6, 0.5)
            love.graphics.setColor(r, g, b, 0.08 + 0.04 * math.sin(t + i))
            love.graphics.rectangle('fill', ax - 30, ay, 60, ah)
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Weather.getCurrent()
    return current, TYPES[current]
end

function Weather.getVisibility()
    local def = TYPES[current]
    local prevDef = TYPES[prevType]
    return lerp(prevDef.visibility, def.visibility, transitionAlpha)
end

function Weather.getWindAngle()  return windAngle end
function Weather.getWindSpeed()  return windSpeed end
function Weather.getTimeRemaining() return timeRemaining end

function Weather.setWind(angle, speed)
    if angle then windAngle = angle end
    if speed then windSpeed = speed end
end

function Weather.getTypes()
    return TYPES
end

function Weather.getHazardDecayMult(kind, depth)
    if (depth or 0) > 0 then
        return 1.0
    end

    local typeName, def = Weather.getCurrent()
    def = def or TYPES[current]
    if not def then return 1.0 end

    local mult = 1.0
    if kind == 'napalm' then
        if def.rain then mult = mult * wtune('napalm_rain_decay', 1.25) end
        if def.snow then mult = mult * wtune('napalm_snow_decay', 1.35) end
        if isSevereType(typeName) then mult = mult * wtune('napalm_severe_decay', 1.15) end
        mult = mult * (1 + (windSpeed or 0) * wtune('napalm_wind_decay', 0.18))
    elseif kind == 'cloud' then
        if def.rain then mult = mult * wtune('cloud_rain_decay', 1.08) end
        if def.snow then mult = mult * wtune('cloud_snow_decay', 1.12) end
        if isSevereType(typeName) then mult = mult * wtune('cloud_severe_decay', 1.15) end
        mult = mult * (1 + (windSpeed or 0) * wtune('cloud_wind_decay', 0.35))
    elseif kind == 'fallout' then
        if def.rain then mult = mult * wtune('fallout_rain_decay', 1.03) end
        if def.snow then mult = mult * wtune('fallout_snow_decay', 1.06) end
        if isSevereType(typeName) then mult = mult * wtune('fallout_severe_decay', 1.08) end
        mult = mult * (1 + (windSpeed or 0) * wtune('fallout_wind_decay', 0.12))
    end

    return math.max(1.0, mult)
end

-- Blood rain easter egg persistence
function Weather.getBloodRainFired() return bloodRainFired end
function Weather.setBloodRainFired(v) bloodRainFired = (v == true) end

-- Alias for debug panel
Weather.forceWeather = Weather.force

return Weather
