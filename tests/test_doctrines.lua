local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Colony: Doctrines')

local function freshDoctrines()
    H.resetGameState()
    package.loaded['src.colony.doctrines'] = nil
    local GS = require('src.game_state')
    GS.phase = 'playing'
    return require('src.colony.doctrines')
end

T.test('doctrines gain points from hopeful days', function()
    local Doctrines = freshDoctrines()
    Doctrines.init()

    local GS = require('src.game_state')
    GS.day = 1
    Doctrines.step(0.05)
    T.eq(Doctrines.getPoints(), 1, 'one point earned on day 1')

    GS.day = 3
    Doctrines.step(0.05)
    T.eq(Doctrines.getPoints(), 3, 'points catch up across skipped days')
end)

T.test('unlock commits to one path and blocks others', function()
    local Doctrines = freshDoctrines()
    Doctrines.init()

    local GS = require('src.game_state')
    GS.day = 3
    Doctrines.step(0.05)

    local ok = Doctrines.unlock('order')
    T.ok(ok, 'first tier unlock succeeds')
    T.eq(Doctrines.getChosenPath(), 'order', 'path committed after first unlock')
    T.eq(Doctrines.getTier('order'), 1, 'order tier 1 unlocked')

    local ok2 = Doctrines.unlock('communion')
    T.eq(ok2, false, 'different tier-1 path is blocked after commitment')
end)

T.test('state round-trips through save helpers', function()
    local Doctrines = freshDoctrines()
    Doctrines.init()

    local GS = require('src.game_state')
    GS.day = 3
    Doctrines.step(0.05)
    Doctrines.unlock('solidarity')

    local state = Doctrines.getState()
    T.notnil(state.chosenPath, 'state includes chosen path')

    Doctrines.loadState({})
    T.isnil(Doctrines.getChosenPath(), 'empty load clears chosen path')

    Doctrines.loadState(state)
    T.eq(Doctrines.getChosenPath(), 'solidarity', 'chosen path restored')
    T.eq(Doctrines.getTier('solidarity'), 1, 'tier restored')
end)
