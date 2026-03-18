-- test_weather.lua — Weather system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')
local GameState = require('src.game_state')

T.suite('Weather')

local Weather = require('src.weather.weather')

T.test('TYPES table has all expected weather types', function()
    local types = Weather.getTypes()
    local expected = { 'clear', 'overcast', 'snowfall', 'blizzard', 'whiteout', 'warm_front', 'aurora' }
    for _, key in ipairs(expected) do
        T.notnil(types[key], 'missing weather type: ' .. key)
    end
end)

T.test('each weather type has required fields', function()
    local types = Weather.getTypes()
    local requiredFields = { 'name', 'tempMod', 'windChill', 'visibility', 'snowRate', 'minDuration', 'maxDuration' }
    for key, def in pairs(types) do
        for _, field in ipairs(requiredFields) do
            T.notnil(def[field], key .. ' missing field: ' .. field)
        end
    end
end)

T.test('visibility values are between 0 and 1', function()
    local types = Weather.getTypes()
    for key, def in pairs(types) do
        T.gte(def.visibility, 0, key .. ' visibility >= 0')
        T.ok(def.visibility <= 1, key .. ' visibility <= 1')
    end
end)

T.test('minDuration is less than or equal to maxDuration', function()
    local types = Weather.getTypes()
    for key, def in pairs(types) do
        T.ok(def.minDuration <= def.maxDuration, key .. ' minDuration <= maxDuration')
    end
end)

T.test('init sets state to clear', function()
    Weather.init()
    local typeName, def = Weather.getCurrent()
    T.eq(typeName, 'clear', 'initial weather is clear')
    T.eq(def.name, 'Clear', 'definition name matches')
end)

T.test('force changes current weather', function()
    Weather.init()
    Weather.force('blizzard')
    local typeName, def = Weather.getCurrent()
    T.eq(typeName, 'blizzard', 'weather changed to blizzard')
    T.eq(def.name, 'Blizzard', 'definition name matches')
end)

T.test('force with invalid type is ignored', function()
    Weather.init()
    Weather.force('nonexistent_weather')
    local typeName = Weather.getCurrent()
    T.eq(typeName, 'clear', 'weather unchanged after invalid force')
end)

T.test('getCurrent returns type name and definition', function()
    Weather.init()
    local typeName, def = Weather.getCurrent()
    T.eq(type(typeName), 'string', 'type name is string')
    T.eq(type(def), 'table', 'definition is table')
    T.notnil(def.name, 'definition has name')
    T.notnil(def.tempMod, 'definition has tempMod')
end)

T.test('getVisibility returns a number between 0 and 1', function()
    Weather.init()
    local vis = Weather.getVisibility()
    T.eq(type(vis), 'number', 'visibility is a number')
    T.gte(vis, 0, 'visibility >= 0')
    T.ok(vis <= 1, 'visibility <= 1')
end)

T.test('getVisibility reflects forced weather', function()
    Weather.init()
    Weather.force('whiteout')
    -- After force, transitionAlpha starts at 0 so visibility blends from clear (1.0).
    -- The whiteout target is 0.05. Mid-transition the value will be between them.
    local vis = Weather.getVisibility()
    T.ok(vis <= 1.0, 'visibility at most 1.0')
    T.gte(vis, 0, 'visibility non-negative')
end)

T.test('transition weights respect harshness without eliminating calm outcomes', function()
    H.resetAll()
    Weather.init()

    GameState.weatherHarshness = 1.0
    local base = Weather.getTransitionWeights('overcast')

    GameState.weatherHarshness = 1.5
    local harsh = Weather.getTransitionWeights('overcast')

    GameState.weatherHarshness = 0.75
    local calm = Weather.getTransitionWeights('overcast')

    T.gt(harsh.snowfall, base.snowfall, 'harsh weather boosts severe transition weight')
    T.lt(harsh.clear, base.clear, 'harsh weather suppresses calm transition weight')
    T.gt(calm.clear, base.clear, 'calmer settings favor clear weather')
    T.lt(calm.snowfall, base.snowfall, 'calmer settings suppress severe weather')
    T.gt(harsh.clear, 0, 'clear weather remains possible under harsh conditions')
end)

T.test('hazard decay multipliers respond to weather and stay surface-only', function()
    H.resetAll()
    Weather.init()
    Weather.force('whiteout', 999)
    Weather.setWind(0, 1)

    local napalmSurface = Weather.getHazardDecayMult('napalm', 0)
    local cloudSurface = Weather.getHazardDecayMult('cloud', 0)
    local falloutSurface = Weather.getHazardDecayMult('fallout', 0)
    local underground = Weather.getHazardDecayMult('napalm', 1)

    T.gt(napalmSurface, 1.0, 'storms accelerate surface napalm decay')
    T.gt(cloudSurface, 1.0, 'storms accelerate surface cloud decay')
    T.gt(falloutSurface, 1.0, 'storms accelerate surface fallout decay')
    T.eq(underground, 1.0, 'underground hazards ignore surface weather')
end)
