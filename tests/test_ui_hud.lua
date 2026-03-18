local T = require('tests.test_framework')

T.suite('UI: HUD')

local HUD = require('src.ui.ui_hud')

T.test('truncate helper leaves short text untouched', function()
    local font = {
        getWidth = function(_, text) return #text * 7 end,
    }
    local text = HUD._truncateTextForWidth('Short', 80, font)
    T.eq(text, 'Short', 'short text is unchanged')
end)

T.test('truncate helper ellipsizes long text to fit width', function()
    local font = {
        getWidth = function(_, text) return #text * 7 end,
    }
    local text = HUD._truncateTextForWidth('This status string is far too long to fit', 84, font)
    T.ok(text:sub(-3) == '...', 'ellipsis appended to long text')
    T.ok(font:getWidth(text) <= 84, 'truncated text fits width budget')
end)
