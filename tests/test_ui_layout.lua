-- test_ui_layout.lua — layout maths and panel focus rules.
--
-- Covers the three defects the UI overhaul targeted: text running into other
-- text, buttons narrower than their own labels, and two full-screen panels open
-- at the same time fighting over the same clicks.

local T = require('tests.test_framework')

T.suite('UI: Layout helpers')

local Layout = require('src.ui.ui_layout')

-- 7px per character, matching tests/mock_love.lua's default font.
local font = { getWidth = function(_, text) return #text * 7 end,
               getHeight = function() return 14 end }

---------------------------------------------------------------------------
-- Truncation
---------------------------------------------------------------------------

T.test('truncate leaves text that already fits untouched', function()
    T.eq(Layout.truncate('Trades:', 200, font), 'Trades:', 'short label unchanged')
end)

T.test('truncate ellipsizes and never exceeds the budget', function()
    local long = 'fuel, metal, steel, components, thermalCores'
    local out = Layout.truncate(long, 70, font)
    T.ok(out ~= long, 'long text was shortened')
    T.eq(out:sub(-3), '...', 'ends in an ellipsis')
    T.ok(font:getWidth(out) <= 70, 'result fits the budget')
end)

T.test('truncate degrades to bare characters when the ellipsis will not fit', function()
    -- 14px holds two characters; '...' alone is 21px.
    local out = Layout.truncate('thermalCores', 14, font)
    T.eq(out, 'th', 'shows the characters that fit')
    T.ok(font:getWidth(out) <= 14, 'still inside the budget')
end)

T.test('truncate returns empty for a non-positive budget', function()
    T.eq(Layout.truncate('anything', 0, font), '', 'zero width yields nothing')
    T.eq(Layout.truncate('anything', -20, font), '', 'negative width yields nothing')
end)

T.test('truncate handles nil text', function()
    T.eq(Layout.truncate(nil, 100, font), '', 'nil becomes an empty string')
end)

T.test('truncate handles the empty string', function()
    T.eq(Layout.truncate('', 100, font), '', 'empty in, empty out')
    T.eq(Layout.truncate('', 0, font), '', 'empty at zero width too')
end)

---------------------------------------------------------------------------
-- UTF-8 safety
--
-- Slicing by byte index used to split multi-byte characters, and Love's
-- font:getWidth raises "UTF-8 decoding error: Not enough space" on the result:
-- the research panel crashed the game on a real description string.
---------------------------------------------------------------------------

local DEGREE = 'Temp: -40 to 10\194\176C (ideal 0-5)'   -- °
local ACCENT = 'Cr\195\168me br\195\187l\195\169e ration'  -- Crème brûlée
local EMOJI  = 'loot \240\159\148\165 cache'               -- 4-byte codepoint

T.test('isValidUtf8 accepts ASCII and well-formed multi-byte text', function()
    T.ok(Layout.isValidUtf8('plain ascii'), 'ascii is valid')
    T.ok(Layout.isValidUtf8(DEGREE), 'a 2-byte degree sign is valid')
    T.ok(Layout.isValidUtf8(EMOJI), 'a 4-byte codepoint is valid')
    T.ok(Layout.isValidUtf8(''), 'empty is valid')
end)

T.test('isValidUtf8 rejects a split sequence and a lone continuation byte', function()
    T.ok(not Layout.isValidUtf8('Temp \194'), 'a truncated 2-byte sequence is invalid')
    T.ok(not Layout.isValidUtf8('\176C'), 'a lone continuation byte is invalid')
    T.ok(not Layout.isValidUtf8('\240\159\148'), 'a truncated 4-byte sequence is invalid')
end)

T.test('safeText replaces malformed bytes instead of passing them to the font', function()
    T.eq(Layout.safeText('ok'), 'ok', 'valid text is returned unchanged')
    T.eq(Layout.safeText(DEGREE), DEGREE, 'valid multi-byte text is returned unchanged')
    local fixed = Layout.safeText('Temp \194')
    T.ok(Layout.isValidUtf8(fixed), 'the result is always measurable')
    T.eq(fixed, 'Temp ?', 'the malformed byte became a question mark')
end)

T.test('truncate never splits a 2-byte character', function()
    -- Cut budgets are swept across the whole string so every possible boundary,
    -- including the two bytes of the degree sign, is exercised.
    for w = 1, 60 do
        local out = Layout.truncate(DEGREE, w, font)
        T.ok(Layout.isValidUtf8(out), 'valid UTF-8 at budget ' .. w .. ': ' .. out)
        T.ok(font:getWidth(out) <= w, 'fits budget ' .. w)
    end
end)

T.test('truncate never splits accented characters', function()
    for w = 1, 60 do
        local out = Layout.truncate(ACCENT, w, font)
        T.ok(Layout.isValidUtf8(out), 'valid UTF-8 at budget ' .. w)
    end
end)

T.test('truncate never splits a 4-byte character', function()
    for w = 1, 40 do
        local out = Layout.truncate(EMOJI, w, font)
        T.ok(Layout.isValidUtf8(out), 'valid UTF-8 at budget ' .. w)
    end
end)

T.test('truncate cuts exactly at a multi-byte boundary when the budget lands mid-character', function()
    -- 'a' + degree sign (2 bytes) = 3 bytes = 21px under the 7px/byte stub.
    -- A 14px budget can hold 'a' and the first byte of the sign, so a byte-index
    -- cut would emit invalid UTF-8; the boundary walk must stop after 'a'.
    local out = Layout.truncate('a\194\176bcd', 14, font)
    T.ok(Layout.isValidUtf8(out), 'result is valid UTF-8')
    T.eq(out, 'a', 'stopped before the multi-byte character rather than inside it')
end)

T.test('truncate survives malformed input rather than erroring', function()
    local out = Layout.truncate('bad \194 bytes here', 30, font)
    T.ok(Layout.isValidUtf8(out), 'malformed input still yields drawable text')
end)

T.test('a budget under the ellipsis width returns valid characters, not an error', function()
    local ellW = font:getWidth(Layout.ELLIPSIS)
    local out = Layout.truncate(DEGREE, ellW - 1, font)
    T.ok(Layout.isValidUtf8(out), 'still valid UTF-8')
    T.ok(font:getWidth(out) <= ellW - 1, 'still inside the budget')
    T.ok(out:sub(-3) ~= Layout.ELLIPSIS, 'no ellipsis is appended when it would not fit')
end)

T.test('fitLabel and buttonLabel are UTF-8 safe too', function()
    for w = 4, 40, 2 do
        T.ok(Layout.isValidUtf8(Layout.fitLabel(DEGREE, 0, w, font)),
            'fitLabel valid at ' .. w)
        T.ok(Layout.isValidUtf8(Layout.buttonLabel(EMOJI, w, { font = font })),
            'buttonLabel valid at ' .. w)
    end
end)

---------------------------------------------------------------------------
-- Label / value columns — the "Trades:fuel, metal" defect
---------------------------------------------------------------------------

T.test('fitLabel keeps a gap between the label and the value column', function()
    -- 'Trades:' is 49px. The faction card printed it at x+10 with the value at
    -- x+58, leaving -1px of gap; the two strings touched.
    local label = Layout.fitLabel('Trades:', 10, 58, font)
    T.ok(font:getWidth(label) <= 58 - 10 - Layout.MIN_GAP,
        'label is cut short of the value column')
end)

T.test('fitLabel leaves a label alone when the column is wide enough', function()
    T.eq(Layout.fitLabel('Prefers:', 10, 120, font), 'Prefers:', 'roomy column keeps the label')
end)

T.test('fitLabel respects an explicit minimum gap', function()
    local label = Layout.fitLabel('Prefers:', 0, 60, font, 20)
    T.ok(font:getWidth(label) <= 40, 'wider gap shortens the label further')
end)

---------------------------------------------------------------------------
-- Buttons that fit their labels — the "Gift 5 therma[lCores]" defect
---------------------------------------------------------------------------

T.test('buttonWidth sizes to the label plus padding', function()
    local label = 'Gift 5 thermalCores'
    local w = Layout.buttonWidth(label, { font = font })
    T.eq(w, #label * 7 + Layout.BTN_PAD_X * 2, 'width is label plus both paddings')
    T.ok(Layout.buttonLabel(label, w, { font = font }) == label,
        'a button of that width shows the whole label')
end)

T.test('buttonWidth honours a minimum', function()
    T.eq(Layout.buttonWidth('OK', { font = font, minW = 90 }), 90, 'clamped up to minW')
end)

T.test('a fixed 90px button clips its label, an auto-sized one does not', function()
    local label = 'Gift 5 thermalCores'
    T.ok(Layout.buttonLabel(label, 90, { font = font }) ~= label,
        'the old fixed 90px button could not show the label')
    local w = Layout.buttonWidth(label, { font = font })
    T.eq(Layout.buttonLabel(label, w, { font = font }), label,
        'the measured width shows it in full')
end)

T.test('buttonLabel ellipsizes rather than hard-clipping when maxW binds', function()
    local label = 'Gift 5 thermalCores'
    local w = Layout.buttonWidth(label, { font = font, maxW = 100 })
    T.eq(w, 100, 'width clamped to maxW')
    local shown = Layout.buttonLabel(label, w, { font = font })
    T.eq(shown:sub(-3), '...', 'label is ellipsized, not silently cut')
    T.ok(font:getWidth(shown) <= w - Layout.BTN_PAD_X * 2, 'shown label fits the padding box')
end)

T.test('a rect carries the padding it was sized with', function()
    -- The policy panel sized its ON/OFF chip with padX=6 while drawButton
    -- re-measured the label against the default padX=10, so a chip wide enough
    -- for 'OFF' displayed '...' instead.
    local rect = Layout.buttonRect('OFF', 30, 10, { font = font, padX = 6 })
    T.eq(rect.padX, 6, 'the rect remembers its padding')
    T.eq(Layout.buttonLabel('OFF', rect.w, { font = font, padX = rect.padX }), 'OFF',
        'the label fits when the same padding is used to measure it')
    T.ok(Layout.buttonLabel('OFF', rect.w, { font = font }) ~= 'OFF',
        'and would not fit under the default padding, which is the trap')
end)

T.test('buttonRectRight pins the right edge and grows leftwards', function()
    local rect = Layout.buttonRectRight('Establish', 600, 40, { font = font })
    T.eq(rect.x + rect.w, 600, 'right edge lands on the requested x')
    T.ok(rect.x < 600, 'the button occupies space to the left of it')
end)

T.test('hit tests the rect a button was actually drawn at', function()
    local rect = Layout.buttonRectRight('Cancel', 300, 100, { font = font, h = 20 })
    T.ok(Layout.hit(rect.x + 1, 105, rect), 'inside the rect hits')
    T.ok(not Layout.hit(rect.x - 5, 105, rect), 'left of the rect misses')
    T.ok(not Layout.hit(rect.x + 1, 130, rect), 'below the rect misses')
    T.ok(not Layout.hit(1, 1, nil), 'a nil rect never hits')
end)

---------------------------------------------------------------------------
-- Scroll bounds
---------------------------------------------------------------------------

T.test('clampScroll pins to zero when content fits', function()
    local y, maxScroll = Layout.clampScroll(400, 100, 300)
    T.eq(y, 0, 'no scroll when everything fits')
    T.eq(maxScroll, 0, 'no scroll range')
end)

T.test('clampScroll stops at the end of the content', function()
    local y, maxScroll = Layout.clampScroll(9999, 800, 300)
    T.eq(maxScroll, 500, 'range is content minus viewport')
    T.eq(y, 500, 'scrolling past the end is clamped')
end)

T.test('clampScroll refuses negative offsets', function()
    T.eq((Layout.clampScroll(-40, 800, 300)), 0, 'negative scroll clamps to zero')
end)

---------------------------------------------------------------------------
-- Nested clipping
---------------------------------------------------------------------------

T.test('pushClip intersects with the enclosing clip', function()
    Layout.resetClip()
    Layout.pushClip(0, 0, 500, 500)
    local inner = Layout.pushClip(100, 400, 500, 500)
    T.eq(inner.x, 100, 'inner left edge kept')
    T.eq(inner.y, 400, 'inner top edge kept')
    T.eq(inner.w, 400, 'width clipped to the outer rect')
    T.eq(inner.h, 100, 'height clipped to the outer rect')
    Layout.popClip()
    Layout.popClip()
    T.eq(Layout.clipDepth(), 0, 'stack unwound')
end)

T.test('popClip restores the enclosing rect rather than clearing it', function()
    Layout.resetClip()
    Layout.pushClip(10, 20, 300, 200)
    Layout.pushClip(15, 25, 50, 50)
    Layout.popClip()
    local x, y, w, h = love.graphics.getScissor()
    T.eq(x, 10, 'outer x restored')
    T.eq(y, 20, 'outer y restored')
    T.eq(w, 300, 'outer w restored')
    T.eq(h, 200, 'outer h restored')
    Layout.popClip()
    T.eq(love.graphics.getScissor(), nil, 'fully unwound clears the scissor')
end)

T.test('a fully disjoint clip collapses to zero rather than going negative', function()
    -- expedition_view could compute a negative scissor height, which errors in
    -- Love2D and crashed the game outright.
    Layout.resetClip()
    Layout.pushClip(0, 0, 100, 100)
    local inner = Layout.pushClip(500, 500, 100, 100)
    T.eq(inner.w, 0, 'width floors at zero')
    T.eq(inner.h, 0, 'height floors at zero')
    Layout.resetClip()
end)

T.test('resetClip unwinds a stack left behind by an aborted draw', function()
    Layout.pushClip(0, 0, 10, 10)
    Layout.pushClip(0, 0, 10, 10)
    Layout.resetClip()
    T.eq(Layout.clipDepth(), 0, 'stack emptied')
    T.eq(love.graphics.getScissor(), nil, 'scissor cleared')
end)

---------------------------------------------------------------------------
-- Panel frames
---------------------------------------------------------------------------

T.test('panelFrame keeps the content clear of the bottom toolbar', function()
    local f = Layout.panelFrame(1280, 720)
    T.eq(f.panel.h, 720 - Layout.BOTTOM_RESERVE, 'panel stops above the toolbar')
    T.ok(f.footer.y + f.footer.h <= 720 - Layout.BOTTOM_RESERVE,
        'footer text cannot land under the toolbar')
end)

T.test('panelFrame content sits between the header and the footer', function()
    local f = Layout.panelFrame(1280, 720, { w = 680, h = 620 })
    T.eq(f.content.y, f.panel.y + f.header.h, 'content starts below the header')
    T.eq(f.content.y + f.content.h, f.footer.y, 'content ends where the footer starts')
    T.eq(f.panel.w, 680, 'requested width honoured')
end)

T.test('panelFrame clamps a request larger than the screen', function()
    local f = Layout.panelFrame(600, 400, { w = 2000, h = 2000, margin = 30 })
    T.ok(f.panel.w <= 600, 'width fits the screen')
    T.ok(f.panel.y + f.panel.h <= 400, 'height fits the screen')
end)

---------------------------------------------------------------------------
-- Inline field rows — the "Trade: 100%Core value: 1x" defect
---------------------------------------------------------------------------

T.test('drawInline advances the cursor past every field it drew', function()
    local endX = Layout.drawInline(0, 0, {
        { text = 'Rep: 20' },
        { text = 'Trade: 100%' },
    }, { font = font, gap = 10 })
    local expected = #'Rep: 20' * 7 + 10 + #'Trade: 100%' * 7 + 10
    T.eq(endX, expected, 'fields are separated by a real gap, never concatenated')
end)

T.test('drawInline stops at maxX instead of running off the panel', function()
    local endX = Layout.drawInline(0, 0, {
        { text = 'Rep: 20' },
        { text = 'Trade: 100%' },
        { text = 'Core value: 1.2x' },
        { text = '+10% research (allied)' },
    }, { font = font, gap = 10, maxX = 120 })
    T.ok(endX <= 120 + 10, 'cursor never runs far past the limit')
end)

T.test('drawInline skips empty fields without leaving a gap', function()
    local endX = Layout.drawInline(0, 0, {
        { text = '' },
        { text = 'Rep: 20' },
    }, { font = font, gap = 10 })
    T.eq(endX, #'Rep: 20' * 7 + 10, 'the empty field contributed nothing')
end)
