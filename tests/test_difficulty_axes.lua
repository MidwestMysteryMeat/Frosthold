local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Difficulty Axes')

T.test('configure applies story mode style axes to GameState', function()
    H.resetAll()
    package.loaded['src.ui.difficulty'] = nil

    local Difficulty = require('src.ui.difficulty')
    local GameState = require('src.game_state')

    Difficulty.configure({
        preset = 'story',
        presetName = 'story',
        creatures = 0.55,
        weather = 0.65,
        disease = 0.60,
        resources = 1.60,
        storyteller = 'watcher',
        scenario = 'crashlanded',
        safetyNet = true,
    })
    Difficulty.apply()

    T.near(GameState.creatureAggression, 0.55, 0.001, 'raid pressure stored')
    T.near(GameState.weatherHarshness, 0.65, 0.001, 'weather axis stored')
    T.near(GameState.diseasePressure, 0.60, 0.001, 'disease axis stored')
    T.near(GameState.resourceScarcity, 1.60, 0.001, 'resource axis stored')
end)

T.test('weather harshness changes blizzard severity', function()
    H.resetAll()
    package.loaded['src.weather.weather'] = nil

    local GameState = require('src.game_state')
    local Weather = require('src.weather.weather')

    GameState.baseTemp = -40

    GameState.weatherHarshness = 0.5
    Weather.init()
    Weather.force('blizzard', 100)
    Weather.step(10)
    local mildTemp = GameState.globalTemp
    local mildWind = GameState.windChill

    GameState.baseTemp = -40
    GameState.weatherHarshness = 1.5
    Weather.init()
    Weather.force('blizzard', 100)
    Weather.step(10)
    local harshTemp = GameState.globalTemp
    local harshWind = GameState.windChill

    T.ok(harshTemp < mildTemp, 'harsher weather lowers temperature more')
    T.ok(math.abs(harshWind) > math.abs(mildWind), 'harsher weather increases wind chill')
end)

T.test('disease pressure scales severity growth', function()
    H.resetAll()
    package.loaded['src.sim.disease'] = nil

    local ECS = require('src.ecs.ecs')
    local GameState = require('src.game_state')
    local Disease = require('src.sim.disease')

    local mildId = H.spawnTestColonist(10, 10, { name = 'Mild' })
    GameState.diseasePressure = 0.5
    Disease.infect(mildId, 'blackrot')
    local mildDisease = ECS.get(mildId, 'disease')
    mildDisease.severity = 10
    ECS.update(1.0)
    local mildSeverity = mildDisease.severity

    H.resetAll()
    package.loaded['src.sim.disease'] = nil
    ECS = require('src.ecs.ecs')
    GameState = require('src.game_state')
    Disease = require('src.sim.disease')

    local harshId = H.spawnTestColonist(10, 10, { name = 'Harsh' })
    GameState.diseasePressure = 1.5
    Disease.infect(harshId, 'blackrot')
    local harshDisease = ECS.get(harshId, 'disease')
    harshDisease.severity = 10
    ECS.update(1.0)
    local harshSeverity = harshDisease.severity

    T.ok(harshSeverity > mildSeverity, 'higher disease pressure increases severity faster')
end)
