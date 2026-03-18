local root = arg and arg[0] and (arg[0]:match('(.-)tools[/\\]') or './') or './'
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path

if not love then
    pcall(require, 'tests.mock_love')
end

local GameState = require('src.game_state')
local Weather = require('src.weather.weather')
local World = require('src.world.tilemap')
local Ordnance = require('src.combat.ordnance')

local function runWeatherDistribution(harshness, steps, dt, seed)
    math.randomseed(seed or 101)
    GameState.init()
    GameState.weatherHarshness = harshness
    Weather.init()

    local counts, severe = {}, 0
    for _ = 1, steps do
        Weather.step(dt)
        local name = Weather.getCurrent()
        counts[name] = (counts[name] or 0) + 1
        if name == 'snowfall' or name == 'blizzard' or name == 'whiteout' then
            severe = severe + 1
        end
    end

    print(string.format('weather harshness %.2f | severe %.1f%%', harshness, severe * 100 / steps))
    local items = {}
    for k, v in pairs(counts) do
        items[#items + 1] = { name = k, count = v }
    end
    table.sort(items, function(a, b)
        if a.count == b.count then return a.name < b.name end
        return a.count > b.count
    end)
    for _, item in ipairs(items) do
        print(string.format('  %-10s %d', item.name, item.count))
    end
end

local function measureHazardLifetime(kind, weatherType)
    GameState.init()
    World.init(20, 20)
    Ordnance.init()
    Weather.init()
    Weather.force(weatherType, 999)

    if kind == 'napalm' then
        Ordnance.spawnNapalmField(10, 10, 0, 0, 20, 1.0)
    elseif kind == 'bio' then
        Ordnance.spawnBioCloud(10, 10, 0, 0, 20, 'ice_plague', 0.5)
    elseif kind == 'fallout' then
        Ordnance.spawnFalloutField(10, 10, 0, 0, 20, 0.1)
    end

    local steps = 0
    while true do
        steps = steps + 1
        Weather.step(0.5)
        Ordnance.step(0.5)
        local store = (kind == 'napalm' and Ordnance.getNapalmZones())
            or (kind == 'bio' and Ordnance.getCloudZones())
            or Ordnance.getFalloutZones()
        if next(store) == nil or steps > 200 then
            break
        end
    end

    print(string.format('%-7s in %-9s %.1fs', kind, weatherType, steps * 0.5))
end

for _, harshness in ipairs({ 1.0, 1.25, 1.5 }) do
    runWeatherDistribution(harshness, 400, 30, 101)
end

for _, weatherType in ipairs({ 'clear', 'overcast', 'snowfall', 'blizzard', 'whiteout' }) do
    measureHazardLifetime('napalm', weatherType)
    measureHazardLifetime('bio', weatherType)
    measureHazardLifetime('fallout', weatherType)
end
