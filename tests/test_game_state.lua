-- test_game_state.lua — GameState singleton tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('GameState')

T.test('init sets defaults', function()
    H.resetGameState()
    local GS = require('src.game_state')
    T.eq(GS.day, 1)
    T.eq(GS.hour, 6.0)
    T.eq(GS.simTick, 0)
    T.eq(GS.speed, 1)
    T.eq(GS.paused, false)
end)

T.test('tickClock advances hour', function()
    H.resetGameState()
    local GS = require('src.game_state')
    local oldHour = GS.hour
    GS.tickClock()
    T.gt(GS.hour, oldHour, 'hour increased')
end)

T.test('tickClock wraps day at 24h', function()
    H.resetGameState()
    local GS = require('src.game_state')
    GS.hour = 23.9999
    GS.speed = 100  -- fast speed so tick crosses 24h
    GS.tickClock()
    T.lt(GS.hour, 24, 'hour wrapped')
    T.eq(GS.day, 2, 'day incremented')
    GS.speed = 1
end)

T.test('isDaytime returns correct values', function()
    local GS = require('src.game_state')
    GS.hour = 12
    T.eq(GS.isDaytime(), true, 'noon is daytime')
    GS.hour = 3
    T.eq(GS.isDaytime(), false, '3am is nighttime')
    GS.hour = 6
    T.eq(GS.isDaytime(), true, '6am is daytime')
    GS.hour = 20
    T.eq(GS.isDaytime(), false, '8pm is nighttime')
end)

T.test('addResource increases correctly', function()
    H.resetGameState()
    local GS = require('src.game_state')
    local before = GS.resources.wood
    GS.addResource('wood', 10)
    T.eq(GS.resources.wood, before + 10)
end)

T.test('spendResource deducts and returns true', function()
    H.resetGameState()
    local GS = require('src.game_state')
    GS.resources.stone = 30
    local ok = GS.spendResource('stone', 10)
    T.eq(ok, true, 'spend succeeded')
    T.eq(GS.resources.stone, 20, 'stone deducted')
end)

T.test('spendResource fails when insufficient', function()
    H.resetGameState()
    local GS = require('src.game_state')
    GS.resources.metal = 5
    local ok = GS.spendResource('metal', 10)
    T.eq(ok, false, 'spend failed')
    T.eq(GS.resources.metal, 5, 'metal unchanged')
end)

T.test('getEffectiveTemp combines global and windchill', function()
    local GS = require('src.game_state')
    GS.globalTemp = -40
    GS.windChill = -10
    T.eq(GS.getEffectiveTemp(), -50)
end)
