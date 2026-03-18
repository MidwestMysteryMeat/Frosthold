-- item_decay.lua — Environmental item decay system
-- Damages ground-item entities based on tile conditions: extreme temperature,
-- active weather events (blizzard/storm), adjacent fire, and radiation.
-- Items inside storage buildings are slot data, not ECS entities — they are
-- inherently protected and never processed here.
-- Items with immune = true in their item_defs entry skip all checks.
-- Runs every DECAY_INTERVAL game-seconds to avoid per-tick cost.

local ECS      = require('src.ecs.ecs')
local ItemDefs = require('src.world.item_defs')

local ItemDecay = {}

---------------------------------------------------------------------------
-- Timing
---------------------------------------------------------------------------

local DECAY_INTERVAL = 30  -- game-seconds between decay passes

-- Damage rates are defined per game-hour.
-- 1 game-hour = 3600 game-seconds (game time runs at real-time 1:1 at 1x speed).
-- Each check covers DECAY_INTERVAL seconds → dtHours = DECAY_INTERVAL / 3600.
-- Example at 0.5/hr: 0.5 * (30/3600) = 0.00417 per check.
-- 100 durability / 0.5 per hour = 200 hours to destroy in baseline extreme cold.
local SECONDS_PER_HOUR = 3600

local timer = 0

---------------------------------------------------------------------------
-- Category vulnerability tables
---------------------------------------------------------------------------

-- Organic: damaged by extreme cold, extreme heat, blizzard, fire, radiation
local ORGANIC = {
    food_raw     = true,
    food_cooked  = true,
    drug         = true,
    hide         = true,
    corpse       = true,
    organ        = true,
    medicine     = true,
    eldritch     = true,
}

-- Wood: damaged by extreme cold, extreme heat, blizzard, fire
local WOOD = {
    raw_wood = true,
    plank    = true,
}

-- Cloth: damaged by extreme cold, blizzard, fire, radiation
-- 'component' covers cloth/insulation; 'clothing' covers apparel items
local CLOTH = {
    component = true,
    clothing  = true,
}

-- Liquid: damaged by extreme cold
local LIQUID = {
    liquid = true,
    fuel   = true,
}

-- Electronics: damaged by extreme heat
local ELECTRONIC = {
    component = true,
}

---------------------------------------------------------------------------
-- Utility: check whether a tile is sheltered from weather events
-- A tile is sheltered when it belongs to a room (room ID > 0) OR when it
-- is underground (depth > 0). Room ID 0 = outdoor/unroofed surface tile.
---------------------------------------------------------------------------

local function isSheltered(x, y, depth)
    if (depth or 0) > 0 then return true end
    local wok, World = pcall(require, 'src.world.tilemap')
    if not wok then return false end
    local roomId = World.getRoom and World.getRoom(x, y, 0) or 0
    return roomId ~= 0
end

---------------------------------------------------------------------------
-- Utility: check for fire on or adjacent to a tile
---------------------------------------------------------------------------

local function hasAdjacentFire(x, y, depth)
    local fok, Fire = pcall(require, 'src.sim.fire')
    if not fok then return false end
    if Fire.isOnFire(x, y, depth) then return true end
    local DIRS = { {1,0}, {-1,0}, {0,1}, {0,-1} }
    for _, d in ipairs(DIRS) do
        if Fire.isOnFire(x + d[1], y + d[2], depth) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Utility: get tile temperature (fallback: global outdoor temp)
---------------------------------------------------------------------------

local function getTileTemp(x, y, depth)
    local wok, World = pcall(require, 'src.world.tilemap')
    if wok and World.getTemp then
        return World.getTemp(x, y, depth or 0)
    end
    local gsok, GS = pcall(require, 'src.game_state')
    if gsok and GS.getEffectiveTemp then
        return GS.getEffectiveTemp()
    end
    return 0
end

---------------------------------------------------------------------------
-- Utility: check whether a severe weather event (blizzard / storm) is active
---------------------------------------------------------------------------

local SEVERE_WEATHER = {
    blizzard   = true,
    storm      = true,
    sandstorm  = true,
    acid_storm = true,
    ice_storm  = true,
    blood_rain = true,
}

local function isSevereWeather()
    local wok, Weather = pcall(require, 'src.weather.weather')
    if not wok then return false end
    local current = Weather.getCurrent and Weather.getCurrent()
    return current ~= nil and SEVERE_WEATHER[current] == true
end

---------------------------------------------------------------------------
-- Utility: get radiation dose rate at a position
---------------------------------------------------------------------------

local function getRadiationRate(x, y, depth)
    local rok, Radiation = pcall(require, 'src.sim.radiation')
    if not rok then return 0 end
    if Radiation.getDoseRate then
        return Radiation.getDoseRate(x, y, depth or 0)
    end
    return 0
end

---------------------------------------------------------------------------
-- Core step: iterate all ground items, apply environmental damage
---------------------------------------------------------------------------

function ItemDecay.step(dt)
    timer = timer + dt
    if timer < DECAY_INTERVAL then return end
    timer = timer - DECAY_INTERVAL

    local dtHours = DECAY_INTERVAL / SECONDS_PER_HOUR

    -- Cache weather result once per pass (same for all items)
    local severeWeather = isSevereWeather()

    -- Cache alert module once per pass
    local aok, Alerts = pcall(require, 'src.ui.alerts')

    for id, comps in ECS.query('pos', 'item') do
        local item = comps.item
        local pos  = comps.pos

        -- Skip items being carried by colonists
        if item.hauled then goto continue end

        -- Skip items marked immune in their definition
        local def = ItemDefs.get(item.itemId)
        if def.immune then goto continue end

        local cat    = def.category
        local damage = 0

        local x     = pos.x
        local y     = pos.y
        local depth = pos.depth or 0

        -- Tile temperature
        local temp = getTileTemp(x, y, depth)

        -- Extreme cold (<-40 C): organics, cloth, liquids, wood
        if temp < -40 then
            if ORGANIC[cat] or CLOTH[cat] or LIQUID[cat] or WOOD[cat] then
                damage = damage + 0.5 * dtHours
            end
        end

        -- Extreme heat (>50 C): organics, wood, electronics (cloth gets no bonus here per spec)
        if temp > 50 then
            if ORGANIC[cat] or WOOD[cat] or ELECTRONIC[cat] then
                damage = damage + 0.5 * dtHours
            end
        end

        -- Severe weather (blizzard / storm): all exposed items, no immunity by material
        -- Protected if indoors (room > 0) or underground
        if severeWeather and not isSheltered(x, y, depth) then
            damage = damage + 2.0 * dtHours
        end

        -- Fire (adjacent or on same tile): wood, cloth, organics, fuel
        -- Stone, metal, and ore are unaffected by fire
        if ORGANIC[cat] or WOOD[cat] or CLOTH[cat] or LIQUID[cat] then
            if hasAdjacentFire(x, y, depth) then
                damage = damage + 10.0 * dtHours
            end
        end

        -- Radiation: organics, cloth, food
        -- Metal and stone are unaffected
        if ORGANIC[cat] or CLOTH[cat] then
            local radRate = getRadiationRate(x, y, depth)
            if radRate > 0 then
                damage = damage + 0.3 * dtHours * radRate
            end
        end

        -- Apply damage
        if damage > 0 then
            item.durability = (item.durability or 100) - damage
            if item.durability <= 0 then
                local label = item.itemId or 'unknown'
                if aok and Alerts and Alerts.add then
                    Alerts.add('Item destroyed by environment: ' .. label, 'warning')
                end
                ECS.destroy(id)
            end
        end

        ::continue::
    end
end

---------------------------------------------------------------------------
-- registerSystems — no ECS system registration needed:
-- ItemDecay.step is called directly from the main update loop.
-- This stub satisfies the save.lua convention.
---------------------------------------------------------------------------

function ItemDecay.registerSystems()
end

return ItemDecay
