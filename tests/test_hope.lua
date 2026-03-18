-- test_hope.lua -- Colony hope/discontent system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Colony: Hope')

T.test('getHope and getDiscontent return default values', function()
    H.resetAll()
    -- Force-reload to reset module-level state
    package.loaded['src.colony.hope'] = nil
    local Hope = require('src.colony.hope')
    T.eq(Hope.getHope(), 50, 'default hope is 50')
    T.eq(Hope.getDiscontent(), 20, 'default discontent is 20')
    T.eq(Hope.isRevoltActive(), false, 'no revolt by default')
end)

T.test('onColonistDeath lowers hope and raises discontent', function()
    H.resetAll()
    package.loaded['src.colony.hope'] = nil
    local Hope = require('src.colony.hope')
    local hopeBefore = Hope.getHope()
    local dcBefore = Hope.getDiscontent()

    Hope.onColonistDeath('TestColonist')

    T.eq(Hope.getHope(), hopeBefore - 15, 'hope decreased by 15')
    T.eq(Hope.getDiscontent(), dcBefore + 10, 'discontent increased by 10')
end)

T.test('onBuildingCompleted raises hope and lowers discontent', function()
    H.resetAll()
    package.loaded['src.colony.hope'] = nil
    local Hope = require('src.colony.hope')
    local hopeBefore = Hope.getHope()
    local dcBefore = Hope.getDiscontent()

    Hope.onBuildingCompleted('Workshop')

    T.eq(Hope.getHope(), hopeBefore + 3, 'hope increased by 3')
    T.eq(Hope.getDiscontent(), dcBefore - 1, 'discontent decreased by 1')
end)

T.test('applyDelta clamps values to 0-100 range', function()
    H.resetAll()
    package.loaded['src.colony.hope'] = nil
    local Hope = require('src.colony.hope')

    Hope.applyDelta(200, nil)
    T.eq(Hope.getHope(), 100, 'hope clamped at 100')

    Hope.applyDelta(-500, nil)
    T.eq(Hope.getHope(), 0, 'hope clamped at 0')

    Hope.applyDelta(nil, 200)
    T.eq(Hope.getDiscontent(), 100, 'discontent clamped at 100')

    Hope.applyDelta(nil, -500)
    T.eq(Hope.getDiscontent(), 0, 'discontent clamped at 0')
end)

T.test('onMemorialBuilt adds to memorials list and boosts hope', function()
    H.resetAll()
    package.loaded['src.colony.hope'] = nil
    local Hope = require('src.colony.hope')
    local hopeBefore = Hope.getHope()

    Hope.onMemorialBuilt('FallenHero')

    T.eq(Hope.getHope(), hopeBefore + 10, 'hope boosted by memorial')
    local memorials = Hope.getMemorials()
    T.eq(#memorials, 1, 'one memorial recorded')
    T.eq(memorials[1].name, 'FallenHero')
end)

T.test('isRevoltActive stays false when discontent is moderate', function()
    H.resetAll()
    package.loaded['src.colony.hope'] = nil
    local Hope = require('src.colony.hope')

    -- Discontent starts at 20, well below 80 threshold
    T.eq(Hope.isRevoltActive(), false, 'no revolt at default discontent')

    -- Push discontent up but not enough to trigger revolt without sustained duration
    Hope.applyDelta(nil, 65)
    T.eq(Hope.getDiscontent(), 85, 'discontent is 85')
    T.eq(Hope.isRevoltActive(), false, 'revolt not instant, needs sustained duration')
end)

T.test('getLog grows with events and caps at MAX_LOG', function()
    H.resetAll()
    package.loaded['src.colony.hope'] = nil
    local Hope = require('src.colony.hope')

    T.eq(#Hope.getLog(), 0, 'log empty at start')

    -- Generate enough events to exceed the 12-entry cap
    for i = 1, 15 do
        Hope.onBuildingCompleted('Building ' .. i)
    end

    local log = Hope.getLog()
    T.ok(#log <= 12, 'log capped at 12 entries')
    T.gt(#log, 0, 'log has entries')
end)

T.test('onWandererJoined and onSupplyFound shift meters correctly', function()
    H.resetAll()
    package.loaded['src.colony.hope'] = nil
    local Hope = require('src.colony.hope')
    local hopeBefore = Hope.getHope()
    local dcBefore = Hope.getDiscontent()

    Hope.onWandererJoined()
    T.eq(Hope.getHope(), hopeBefore + 5, 'wanderer boosts hope by 5')
    T.eq(Hope.getDiscontent(), dcBefore - 2, 'wanderer lowers discontent by 2')

    local hopeAfterWanderer = Hope.getHope()
    Hope.onSupplyFound()
    T.eq(Hope.getHope(), hopeAfterWanderer + 3, 'supply boosts hope by 3')
end)
