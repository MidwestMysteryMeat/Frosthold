-- lighting.lua — Per-tile light level simulation
-- Light sources (torch, lamp, campfire) illuminate nearby tiles.
-- Outdoor tiles are lit during daytime. Darkness applies work speed
-- and morale penalties to colonists.

local GameState = require('src.game_state')

local Lighting = {}

local world         -- reference to tilemap module
local lightData = {} -- flat array: light level (0-1) per tile index

-- Registered light sources: { [key] = { x, y, radius, intensity } }
local lightSources = {}

-- Light source presets
Lighting.PRESETS = {
    torch    = { radius = 4, intensity = 0.8 },
    lamp     = { radius = 6, intensity = 1.0 },
    campfire = { radius = 5, intensity = 0.9 },
}

-- Penalty thresholds
local WORK_SPEED_THRESHOLD = 0.3   -- below this: -20% work speed
local MORALE_THRESHOLD     = 0.2   -- below this: -5 morale per tick cycle

local function tileKey(x, y) return y * 10000 + x end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Lighting.init(tilemap)
    world = tilemap
    lightData = {}
    lightSources = {}

    local w, h = world.width(), world.height()
    for i = 1, w * h do
        lightData[i] = 0
    end
end

---------------------------------------------------------------------------
-- Light source management
---------------------------------------------------------------------------

function Lighting.addLight(x, y, preset)
    local def = Lighting.PRESETS[preset]
    if not def then return end
    local k = tileKey(x, y)
    lightSources[k] = { x = x, y = y, radius = def.radius, intensity = def.intensity }
end

function Lighting.addLightCustom(x, y, radius, intensity)
    local k = tileKey(x, y)
    lightSources[k] = { x = x, y = y, radius = radius, intensity = intensity }
end

function Lighting.removeLight(x, y)
    lightSources[tileKey(x, y)] = nil
end

---------------------------------------------------------------------------
-- Step — recalculate light map each sim tick
---------------------------------------------------------------------------

-- Compute sunlight intensity (0-1) factoring time of day and weather
function Lighting.getSunlightFactor()
    local h = GameState.hour

    -- Read sunrise/sunset from current season (planet-aware)
    local rise, set = 6, 20
    local sok, Seasons = pcall(require, 'src.world.seasons')
    if sok and Seasons.getDaylight then
        local dl = Seasons.getDaylight()
        rise = dl.rise or 6
        set  = dl.set or 20
    end

    -- Nemaea eclipse season: rise==0, set==0 means total darkness
    if rise == 0 and set == 0 then return 0 end

    -- Rhea-2 / twin suns: longer daylight windows use same ramp math
    local dawnStart = rise
    local dawnEnd   = rise + 2
    local duskStart = set - 2
    local duskEnd   = set

    local sun = 0
    if h >= dawnEnd and h <= duskStart then
        sun = 1.0
    elseif h >= dawnStart and h < dawnEnd then
        sun = (h - dawnStart) / (dawnEnd - dawnStart)
    elseif h > duskStart and h < duskEnd then
        sun = (duskEnd - h) / (duskEnd - duskStart)
    end

    -- Weather penalty
    local wok, Weather = pcall(require, 'src.weather.weather')
    if wok then
        local _, wdef = Weather.getCurrent()
        if wdef and wdef.solarPenalty then
            sun = sun * (1 - wdef.solarPenalty)
        end
    end
    return sun
end

function Lighting.step(dt)
    local w, h = world.width(), world.height()
    local sunlight = Lighting.getSunlightFactor()

    -- Reset all tiles
    for i = 1, w * h do
        lightData[i] = 0
    end

    -- Outdoor daylight: tiles in room 0 get sunlight (continuous, not binary)
    local rData = world.rawRoomData()
    if sunlight > 0 then
        for i = 1, w * h do
            if rData[i] == 0 then
                lightData[i] = sunlight
            end
        end
    end

    -- Apply each light source with radial falloff (squared distance to avoid sqrt)
    local sqrt = math.sqrt
    for _, src in pairs(lightSources) do
        local r = src.radius
        local r2 = r * r
        local invR = 1.0 / r
        local sx, sy = src.x, src.y
        local intensity = src.intensity
        local minX = math.max(0, sx - r)
        local maxX = math.min(w - 1, sx + r)
        local minY = math.max(0, sy - r)
        local maxY = math.min(h - 1, sy + r)

        for ty = minY, maxY do
            for tx = minX, maxX do
                local dx = tx - sx
                local dy = ty - sy
                local distSq = dx * dx + dy * dy
                if distSq <= r2 then
                    local falloff = 1.0 - sqrt(distSq) * invR
                    local idx = ty * w + tx + 1
                    lightData[idx] = math.min(1.0, lightData[idx] + intensity * falloff * falloff)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Lighting.getLightAt(x, y)
    if not world.inBounds(x, y) then return 0 end
    local idx = world.rawIndex(x, y)
    return lightData[idx] or 0
end

function Lighting.rawLightData()
    return lightData
end

-- Returns work speed multiplier (1.0 = normal, 0.8 = darkness penalty)
function Lighting.getWorkSpeedMod(x, y)
    local light = Lighting.getLightAt(x, y)
    if light < WORK_SPEED_THRESHOLD then
        return 0.8
    end
    return 1.0
end

-- Returns morale delta per tick from lighting at a tile
function Lighting.getMoralePenalty(x, y)
    local light = Lighting.getLightAt(x, y)
    if light < MORALE_THRESHOLD then
        return -5
    end
    return 0
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Lighting.getState()
    return {
        lightSources = lightSources,
    }
end

function Lighting.loadState(saved)
    if not saved then return end
    lightSources = saved.lightSources or {}
end

return Lighting
