-- test_schedule.lua — Schedule system tests

local T = require('tests.test_framework')

T.suite('Schedule')

T.test('default schedule has 24 entries', function()
    local Schedule = require('src.colonist.schedule')
    local s = Schedule.default()
    local count = 0
    for h = 0, 23 do
        T.notnil(s[h], 'hour ' .. h .. ' assigned')
        count = count + 1
    end
    T.eq(count, 24)
end)

T.test('default schedule: midnight is sleep', function()
    local Schedule = require('src.colonist.schedule')
    local s = Schedule.default()
    T.eq(s[0], 'sleep', 'midnight is sleep')
    T.eq(s[3], 'sleep', '3am is sleep')
    T.eq(s[22], 'sleep', '10pm is sleep')
end)

T.test('default schedule: work hours', function()
    local Schedule = require('src.colonist.schedule')
    local s = Schedule.default()
    T.eq(s[7], 'work', '7am is work')
    T.eq(s[10], 'work', '10am is work')
    T.eq(s[15], 'work', '3pm is work')
end)

T.test('default schedule: eat times', function()
    local Schedule = require('src.colonist.schedule')
    local s = Schedule.default()
    T.eq(s[6], 'eat', '6am is eat')
    T.eq(s[12], 'eat', 'noon is eat')
    T.eq(s[18], 'eat', '6pm is eat')
end)

T.test('default schedule: free time', function()
    local Schedule = require('src.colonist.schedule')
    local s = Schedule.default()
    T.eq(s[19], 'free', '7pm is free')
    T.eq(s[20], 'free', '8pm is free')
    T.eq(s[21], 'free', '9pm is free')
end)

T.test('night shift schedule has sleep during day', function()
    local Schedule = require('src.colonist.schedule')
    local s = Schedule.nightShift()
    T.eq(s[10], 'sleep', '10am is sleep on night shift')
    T.eq(s[12], 'sleep', 'noon is sleep on night shift')
end)

T.test('getCurrentBlock reads GameState.hour', function()
    local Schedule = require('src.colonist.schedule')
    local GS = require('src.game_state')
    local s = Schedule.default()

    GS.hour = 7.5
    T.eq(Schedule.getCurrentBlock(s), 'work', '7:30 is work')

    GS.hour = 0.0
    T.eq(Schedule.getCurrentBlock(s), 'sleep', 'midnight is sleep')

    GS.hour = 12.0
    T.eq(Schedule.getCurrentBlock(s), 'eat', 'noon is eat')
end)
