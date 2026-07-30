-- test_panel_manager.lua — panel exclusivity and input focus.
--
-- The bug this guards against: two full-screen panels open at once, with the
-- one drawn underneath consuming every click because it happened to sit earlier
-- in main.lua's dispatch chain. That is what made the faction panel's gift and
-- trade-route buttons look dead.

local T = require('tests.test_framework')

T.suite('UI: Panel manager')

local PM = require('src.ui.panel_manager')

--- A stand-in panel with the API shape the real ones expose.
--- `api` picks which visibility accessor it offers, because the real panels
--- disagree: isVisible, isOpen (quest/debug) or isActive (expedition view).
local function stubPanel(api)
    local p = { visible = false, keys = {}, clicks = 0, wheels = 0, draws = 0 }
    function p.toggle() p.visible = not p.visible end
    function p.draw() p.draws = p.draws + 1 end
    function p.keypressed(key) p.keys[#p.keys + 1] = key; return true end
    function p.mousepressed() p.clicks = p.clicks + 1; return true end
    function p.wheelmoved() p.wheels = p.wheels + 1; return true end
    if api == 'isOpen' then
        function p.isOpen() return p.visible end
    elseif api == 'isActive' then
        function p.isActive() return p.visible end
    else
        function p.isVisible() return p.visible end
    end
    return p
end

local function freshPair()
    local a = stubPanel('isVisible')
    local b = stubPanel('isVisible')
    PM.injectForTest('test_a', a)
    PM.injectForTest('test_b', b)
    -- Nothing else may be open, or exclusivity assertions would be ambiguous.
    PM.closeAll()
    return a, b
end

---------------------------------------------------------------------------
-- Exclusivity
---------------------------------------------------------------------------

T.test('opening a panel makes it visible and focused', function()
    local a = freshPair()
    T.ok(PM.open('test_a'), 'open reported success')
    T.ok(a.visible, 'the panel is on screen')
    T.eq(PM.top(), 'test_a', 'it is the focused panel')
    T.ok(PM.anyOpen(), 'anyOpen sees it')
    PM.closeAll()
end)

T.test('opening a second panel closes the first', function()
    local a, b = freshPair()
    PM.open('test_a')
    PM.open('test_b')
    T.ok(not a.visible, 'the first panel was closed, not stacked under')
    T.ok(b.visible, 'the second panel is open')
    T.eq(PM.top(), 'test_b', 'focus moved to the second panel')
    T.eq(#PM.openIds(), 1, 'exactly one panel is open')
    PM.closeAll()
end)

T.test('toggle opens then closes the same panel', function()
    local a = freshPair()
    PM.toggle('test_a')
    T.ok(a.visible, 'first toggle opened it')
    PM.toggle('test_a')
    T.ok(not a.visible, 'second toggle closed it')
    T.eq(PM.top(), nil, 'nothing is focused')
    T.ok(not PM.anyOpen(), 'anyOpen is false again')
end)

T.test('closeTop closes the focused panel and reports it did', function()
    local a = freshPair()
    T.ok(not PM.closeTop(), 'nothing open means nothing to close')
    PM.open('test_a')
    T.ok(PM.closeTop(), 'closeTop handled the open panel')
    T.ok(not a.visible, 'the panel closed')
    T.ok(not PM.closeTop(), 'a second closeTop is a no-op')
end)

T.test('a panel that closes itself is dropped from the stack', function()
    local a = freshPair()
    PM.open('test_a')
    a.visible = false            -- e.g. the roster closing itself on a row click
    T.eq(PM.top(), nil, 'the stale entry was pruned')
    T.ok(not PM.anyOpen(), 'anyOpen agrees')
end)

T.test('a panel opened outside the manager is adopted and given focus', function()
    local a, b = freshPair()
    PM.open('test_a')
    b.visible = true             -- e.g. ShipyardPanel.open from a context menu
    T.eq(PM.top(), 'test_b', 'the adopted panel takes focus')
    PM.closeAll()
end)

T.test('unknown panel ids are refused rather than erroring', function()
    T.ok(not PM.open('no_such_panel'), 'open fails cleanly')
    T.ok(not PM.isOpen('no_such_panel'), 'isOpen is false')
    T.ok(not PM.isRegistered('no_such_panel'), 'and it is not registered')
end)

---------------------------------------------------------------------------
-- Visibility accessor variants
---------------------------------------------------------------------------

T.test('isOpen-style panels are tracked', function()
    local p = stubPanel('isOpen')
    PM.injectForTest('test_isopen', p)
    PM.closeAll()
    PM.open('test_isopen')
    T.eq(PM.top(), 'test_isopen', 'quest/debug style panels are recognised')
    PM.closeAll()
    T.ok(not p.visible, 'and can be closed')
end)

T.test('isActive-style panels are tracked', function()
    local p = stubPanel('isActive')
    PM.injectForTest('test_isactive', p)
    PM.closeAll()
    PM.open('test_isactive')
    T.eq(PM.top(), 'test_isactive', 'expedition-view style panels are recognised')
    PM.closeAll()
    T.ok(not p.visible, 'and can be closed')
end)

---------------------------------------------------------------------------
-- Input focus
---------------------------------------------------------------------------

T.test('only the focused panel receives keys', function()
    local a, b = freshPair()
    PM.open('test_a')
    PM.open('test_b')
    PM.keypressed('escape')
    T.eq(#a.keys, 0, 'the closed panel got nothing')
    T.eq(b.keys[1], 'escape', 'the focused panel got the key')
    PM.closeAll()
end)

T.test('only the focused panel receives clicks and scroll', function()
    local a, b = freshPair()
    PM.open('test_a')
    b.visible = true             -- adopted, so it is drawn and focused on top
    PM.mousepressed(10, 10, 1)
    PM.wheelmoved(0, -1)
    T.eq(a.clicks, 0, 'the panel underneath got no click')
    T.eq(b.clicks, 1, 'the topmost panel got the click')
    T.eq(b.wheels, 1, 'and the scroll')
    PM.closeAll()
end)

T.test('an open panel consumes input even when its handler declines it', function()
    local a = freshPair()
    a.mousepressed = function() return false end
    PM.open('test_a')
    T.ok(PM.mousepressed(10, 10, 1),
        'the click is still consumed, so it cannot clear the world selection')
    PM.closeAll()
end)

T.test('input is not consumed when no panel is open', function()
    freshPair()
    T.ok(not PM.mousepressed(10, 10, 1), 'clicks reach the world')
    T.ok(not PM.keypressed('b'), 'keys reach the game')
    T.ok(not PM.wheelmoved(0, 1), 'scroll reaches the camera zoom')
end)

---------------------------------------------------------------------------
-- Draw order
---------------------------------------------------------------------------

T.test('draw only touches open panels', function()
    local a, b = freshPair()
    PM.open('test_a')
    PM.draw()
    T.eq(a.draws, 1, 'the open panel drew')
    T.eq(b.draws, 0, 'the closed panel did not')
    PM.closeAll()
end)

T.test('every real panel in the registry resolves and answers isVisible', function()
    for _, spec in ipairs(PM.PANELS) do
        if not spec.path:find('^test:') then
            local mod = PM.moduleFor(spec.id)
            T.ok(mod ~= nil, spec.id .. ' resolves to a module')
            T.ok(mod.toggle ~= nil, spec.id .. ' exposes toggle()')
            T.ok(mod.isVisible or mod.isOpen or mod.isActive,
                spec.id .. ' exposes a visibility accessor the manager understands')
            T.ok(mod.draw ~= nil, spec.id .. ' exposes draw()')
        end
    end
end)
