-- ui_layout.lua — shared layout primitives for panels.
--
-- Every panel used to hand-place its text at magic pixel offsets, which is how
-- labels ended up overlapping their values ("Trades:fuel, metal") and how
-- buttons ended up narrower than the words printed inside them. The helpers
-- here measure text with the live font instead of guessing, so a row either
-- fits or is deliberately ellipsised.
--
-- Nothing in this module touches game state. It is pure layout plus draw calls,
-- which also makes the measurement half testable without a real Love2D window.

local Layout = {}

---------------------------------------------------------------------------
-- Constants panels share so they line up with each other
---------------------------------------------------------------------------

Layout.ELLIPSIS = '...'
Layout.MIN_GAP = 8           -- smallest allowed space between a label and its value
Layout.FIELD_GAP = 14        -- space between inline fields on one line
Layout.ROW_PAD = 10          -- inset from a card/panel edge to its content
Layout.BTN_PAD_X = 10        -- horizontal padding inside an auto-sized button
Layout.BTN_H = 22            -- default button height
Layout.BOTTOM_RESERVE = 36   -- bottom_toolbar.lua BAR_HEIGHT; panels keep clear of it

---------------------------------------------------------------------------
-- Measurement
---------------------------------------------------------------------------

local function activeFont(font)
    if font then return font end
    if love and love.graphics and love.graphics.getFont then
        return love.graphics.getFont()
    end
    return nil
end

---------------------------------------------------------------------------
-- UTF-8 safety
--
-- Panel text is not ASCII: crop temperatures carry '°C', em dashes appear in
-- footers, and ids come straight from data files. Slicing such a string at a
-- byte index can land inside a multi-byte sequence, and Love's
-- font:getWidth raises "UTF-8 decoding error: Not enough space" on the result —
-- a hard crash from a draw call, not a cosmetic glitch.
--
-- Boundary walking is implemented here rather than through Love's `utf8`
-- module (`require('utf8')`) on purpose: that module does not exist under the
-- LuaJIT runner the test suite uses, and one implementation exercised by the
-- tests is safer than a second, untested path taken only in-game.
---------------------------------------------------------------------------

local function isContinuation(b)
    return b ~= nil and b >= 0x80 and b < 0xC0
end

--- Byte length of the UTF-8 sequence starting at byte `i`, or nil when the
--- bytes there are not a well-formed sequence.
local function seqLen(text, i)
    local b = text:byte(i)
    if not b then return nil end
    local size
    if b < 0x80 then
        return 1
    elseif b >= 0xC2 and b <= 0xDF then
        size = 2
    elseif b >= 0xE0 and b <= 0xEF then
        size = 3
    elseif b >= 0xF0 and b <= 0xF4 then
        size = 4
    else
        return nil   -- continuation byte or overlong/invalid lead byte
    end
    if i + size - 1 > #text then return nil end
    for k = 1, size - 1 do
        if not isContinuation(text:byte(i + k)) then return nil end
    end
    return size
end

--- True when every byte of `text` belongs to a well-formed sequence.
--- Allocation-free, so it is safe to call from a draw loop.
function Layout.isValidUtf8(text)
    text = tostring(text or '')
    local i, n = 1, #text
    while i <= n do
        local size = seqLen(text, i)
        if not size then return false end
        i = i + size
    end
    return true
end

--- A form of `text` that is always safe to measure and print. Malformed bytes
--- become '?' rather than propagating into font:getWidth, because a label must
--- never be able to crash a frame no matter where its bytes came from.
function Layout.safeText(text)
    text = tostring(text == nil and '' or text)
    if not text:find('[\128-\255]') then return text end   -- pure ASCII fast path
    if Layout.isValidUtf8(text) then return text end
    return (text:gsub('[\128-\255]', '?'))
end

--- Width of `text` in pixels under `font` (defaults to the active font).
function Layout.textWidth(text, font)
    text = Layout.safeText(text)
    local f = activeFont(font)
    if not f then return #text * 8 end
    return f:getWidth(text)
end

function Layout.textHeight(font)
    local f = activeFont(font)
    if not f then return 16 end
    return f:getHeight()
end

--- Largest byte length <= n that ends on a codepoint boundary. `text` must
--- already be valid UTF-8 (callers run it through safeText first).
local function snapDown(text, n)
    if n <= 0 then return 0 end
    if n >= #text then return #text end
    while n > 0 and isContinuation(text:byte(n + 1)) do
        n = n - 1
    end
    return n
end

--- Byte length of the prefix one codepoint longer than `n`, capped at #text.
local function growOne(text, n)
    local m = n + 1
    local len = #text
    if m > len then return len end
    while m < len and isContinuation(text:byte(m + 1)) do m = m + 1 end
    return m
end

--- Longest prefix of `text` that fits in `maxW`, with no ellipsis added.
--- Always cuts on a codepoint boundary.
local function fitPrefix(text, maxW, font)
    local len = #text
    if len == 0 then return '' end
    local total = Layout.textWidth(text, font)
    if total <= maxW then return text end
    if maxW <= 0 then return '' end

    -- Proportional first guess keeps the number of font measurements small for
    -- the long strings this runs over every frame, then correct in whichever
    -- direction the guess landed on. Every candidate is snapped to a boundary.
    local n = snapDown(text, math.floor(len * maxW / total))
    while n > 0 and Layout.textWidth(text:sub(1, n), font) > maxW do
        n = snapDown(text, n - 1)
    end
    while n < len do
        local m = growOne(text, n)
        if m == n or Layout.textWidth(text:sub(1, m), font) > maxW then break end
        n = m
    end
    return text:sub(1, n)
end

--- Remove the last CHARACTER (not byte) from `text`. Backspace handlers used
--- `text:sub(1, -2)`, which lops one byte off a multi-byte character and leaves
--- a string the font cannot measure at all.
function Layout.dropLastChar(text)
    text = tostring(text == nil and '' or text)
    if text == '' then return '' end
    local n = #text - 1
    while n > 0 and isContinuation(text:byte(n + 1)) do
        n = n - 1
    end
    return text:sub(1, n)
end

--- Shorten `text` to at most `maxW` pixels, ending in an ellipsis when it had
--- to be cut. Returns the original string untouched when it already fits, so
--- callers can pass everything through this without cost to short labels.
function Layout.truncate(text, maxW, font)
    -- Sanitised once here, so every slice below is guaranteed to be operating on
    -- well-formed UTF-8 and every cut lands on a character boundary.
    text = Layout.safeText(text)
    maxW = maxW or 0
    if maxW <= 0 then return '' end
    if Layout.textWidth(text, font) <= maxW then return text end

    local ellW = Layout.textWidth(Layout.ELLIPSIS, font)
    if ellW > maxW then
        -- Too narrow for even "...": show whatever characters do fit rather
        -- than an empty cell, so the row still reads as populated.
        return fitPrefix(text, maxW, font)
    end
    local kept = fitPrefix(text, maxW - ellW, font)
    if kept == '' then return Layout.ELLIPSIS end
    return kept .. Layout.ELLIPSIS
end

--- True when `text` fits in `maxW` without truncation.
function Layout.fits(text, maxW, font)
    return Layout.textWidth(text, font) <= (maxW or 0)
end

---------------------------------------------------------------------------
-- Label / value rows
---------------------------------------------------------------------------

--- Label text shortened so it cannot reach a value column starting at
--- `valueX`. Pure math, no drawing — this is the piece worth asserting on.
function Layout.fitLabel(label, labelX, valueX, font, minGap)
    local budget = (valueX - labelX) - (minGap or Layout.MIN_GAP)
    return Layout.truncate(label, budget, font)
end

--- Draw a two-column row: label at `x`, value starting at the fixed column
--- `valueX`. The label is ellipsised rather than allowed to run into the
--- value, and the value is ellipsised at `opts.maxValueW` when given.
--- Returns the y a following row should use.
function Layout.labelValue(label, value, x, y, valueX, opts)
    opts = opts or {}
    local font = opts.font
    local lc = opts.labelColor or { 0.55, 0.55, 0.58 }
    local vc = opts.valueColor or { 0.85, 0.85, 0.85 }

    love.graphics.setColor(lc)
    love.graphics.print(Layout.fitLabel(label, x, valueX, font, opts.minGap), x, y)

    local shown = tostring(value == nil and '' or value)
    if opts.maxValueW then
        shown = Layout.truncate(shown, opts.maxValueW, font)
    end
    love.graphics.setColor(vc)
    love.graphics.print(shown, valueX, y)

    return y + (opts.rowH or (Layout.textHeight(font) + 2))
end

--- Draw several coloured fields on one line, each separated by a real gap.
--- `fields` is a list of { text = string, color = {r,g,b[,a]} }. Fields that
--- would spill past `opts.maxX` are dropped, and the last one that partly
--- fits is ellipsised, so a line never runs off its panel.
--- Returns the x cursor after the final field drawn.
function Layout.drawInline(x, y, fields, opts)
    opts = opts or {}
    local font = opts.font
    local gap = opts.gap or Layout.FIELD_GAP
    local maxX = opts.maxX
    local cursor = x

    for i, field in ipairs(fields) do
        local text = tostring(field.text == nil and '' or field.text)
        if text ~= '' then
            if maxX then
                local remaining = maxX - cursor
                if remaining <= 0 then break end
                text = Layout.truncate(text, remaining, font)
                if text == '' then break end
            end
            love.graphics.setColor(field.color or opts.color or { 0.8, 0.8, 0.8 })
            love.graphics.print(text, cursor, y)
            cursor = cursor + Layout.textWidth(text, font) + gap
        end
        if maxX and cursor >= maxX then
            if i < #fields then break end
        end
    end

    return cursor
end

---------------------------------------------------------------------------
-- Buttons that fit their label
---------------------------------------------------------------------------

--- Width a button needs to hold `label` at the current font.
--- `opts.minW` / `opts.maxW` clamp the result; when the label cannot fit in
--- `maxW` the caller is expected to draw the ellipsised form from
--- `Layout.buttonLabel`.
function Layout.buttonWidth(label, opts)
    opts = opts or {}
    local pad = opts.padX or Layout.BTN_PAD_X
    local w = Layout.textWidth(label, opts.font) + pad * 2
    if opts.minW and w < opts.minW then w = opts.minW end
    if opts.maxW and w > opts.maxW then w = opts.maxW end
    return math.floor(w + 0.5)
end

--- The text a button of width `w` can actually show.
function Layout.buttonLabel(label, w, opts)
    opts = opts or {}
    local pad = opts.padX or Layout.BTN_PAD_X
    return Layout.truncate(label, w - pad * 2, opts.font)
end

--- Rect for a button whose RIGHT edge sits at `rightX` — the common case for
--- an action button pinned to a card's right margin.
---
--- The rect carries the padding it was sized with. drawButton reads it back, so
--- a caller that sizes with a tighter padX cannot end up with drawButton
--- re-measuring against the default and ellipsising a label that fits (which is
--- how the policy panel's ON/OFF chip rendered as "...").
function Layout.buttonRectRight(label, rightX, y, opts)
    opts = opts or {}
    local w = Layout.buttonWidth(label, opts)
    local h = opts.h or Layout.BTN_H
    return { x = math.floor(rightX - w), y = y, w = w, h = h,
             padX = opts.padX or Layout.BTN_PAD_X }
end

--- Rect for a button whose LEFT edge sits at `x`.
function Layout.buttonRect(label, x, y, opts)
    opts = opts or {}
    return { x = x, y = y, w = Layout.buttonWidth(label, opts), h = opts.h or Layout.BTN_H,
             padX = opts.padX or Layout.BTN_PAD_X }
end

--- Draw an auto-sized button. `state` picks the palette: 'normal', 'hover'
--- or 'disabled'. Returns the rect so the caller can register a hit zone
--- against exactly what was drawn.
function Layout.drawButton(label, rect, state, colors)
    colors = colors or {}
    local bg
    if state == 'disabled' then
        bg = colors.disabled or { 0.12, 0.12, 0.14, 0.9 }
    elseif state == 'hover' then
        bg = colors.hover or { 0.3, 0.45, 0.6, 1 }
    else
        bg = colors.normal or { 0.2, 0.35, 0.5, 0.9 }
    end

    love.graphics.setColor(bg)
    love.graphics.rectangle('fill', rect.x, rect.y, rect.w, rect.h, 3, 3)
    if colors.border then
        love.graphics.setColor(colors.border)
        love.graphics.rectangle('line', rect.x, rect.y, rect.w, rect.h, 3, 3)
    end

    local text = Layout.buttonLabel(label, rect.w,
        { padX = colors.padX or rect.padX, font = colors.font })
    local tw = Layout.textWidth(text, colors.font)
    local th = Layout.textHeight(colors.font)
    love.graphics.setColor(state == 'disabled'
        and (colors.disabledText or { 0.45, 0.45, 0.47 })
        or (colors.text or { 1, 1, 1 }))
    love.graphics.print(text,
        math.floor(rect.x + (rect.w - tw) / 2),
        math.floor(rect.y + (rect.h - th) / 2))

    return rect
end

function Layout.hit(mx, my, rect)
    if not rect then return false end
    return mx >= rect.x and mx <= rect.x + rect.w
       and my >= rect.y and my <= rect.y + rect.h
end

---------------------------------------------------------------------------
-- Nested clipping
--
-- love.graphics.setScissor() has no stack, so a panel that clipped its
-- content and then drew a card which also clipped would clobber the outer
-- rect on the way out. pushClip intersects with the enclosing rect and
-- popClip restores it.
---------------------------------------------------------------------------

local clipStack = {}

local function applyScissor(rect)
    if not (love and love.graphics and love.graphics.setScissor) then return end
    if rect then
        love.graphics.setScissor(rect.x, rect.y, rect.w, rect.h)
    else
        love.graphics.setScissor()
    end
end

--- Intersect `x,y,w,h` with the current clip and make it active.
--- Returns the effective rect.
function Layout.pushClip(x, y, w, h)
    local rect = { x = math.floor(x), y = math.floor(y),
                   w = math.max(0, math.floor(w)), h = math.max(0, math.floor(h)) }
    local outer = clipStack[#clipStack]
    if outer then
        local x1 = math.max(rect.x, outer.x)
        local y1 = math.max(rect.y, outer.y)
        local x2 = math.min(rect.x + rect.w, outer.x + outer.w)
        local y2 = math.min(rect.y + rect.h, outer.y + outer.h)
        rect = { x = x1, y = y1, w = math.max(0, x2 - x1), h = math.max(0, y2 - y1) }
    end
    clipStack[#clipStack + 1] = rect
    applyScissor(rect)
    return rect
end

function Layout.popClip()
    clipStack[#clipStack] = nil
    applyScissor(clipStack[#clipStack])
end

function Layout.clipDepth()
    return #clipStack
end

--- Drop any clip left behind by a draw that errored out mid-frame.
function Layout.resetClip()
    for i = #clipStack, 1, -1 do clipStack[i] = nil end
    applyScissor(nil)
end

---------------------------------------------------------------------------
-- Panel frames and scrolling
---------------------------------------------------------------------------

--- Standard rects for a panel. `opts.w` / `opts.h` request a size (clamped to
--- the screen with a margin); omitting them gives a full-screen panel. The
--- content rect already excludes the header, the footer line and the space the
--- bottom toolbar occupies, so no panel needs to know those numbers.
function Layout.panelFrame(sw, sh, opts)
    opts = opts or {}
    local margin = opts.margin or 30
    local headerH = opts.headerH or 44
    local footerH = opts.footerH or 24
    local reserve = opts.bottomReserve == nil and Layout.BOTTOM_RESERVE or opts.bottomReserve

    local w = opts.w and math.min(opts.w, sw - margin * 2) or sw
    local h = opts.h and math.min(opts.h, sh - margin * 2 - reserve) or (sh - reserve)
    local x = opts.x or math.floor((sw - w) / 2)
    local y = opts.y or (opts.h and math.floor((sh - reserve - h) / 2) or 0)

    return {
        panel  = { x = x, y = y, w = w, h = h },
        header = { x = x, y = y, w = w, h = headerH },
        content = { x = x, y = y + headerH, w = w, h = h - headerH - footerH },
        footer = { x = x, y = y + h - footerH, w = w, h = footerH },
        pad = opts.pad or 12,
    }
end

--- Clamp a scroll offset to the content that actually exists. Returns the
--- clamped offset and the maximum scroll, so a panel can tell whether a
--- scrollbar is warranted.
function Layout.clampScroll(scrollY, contentH, viewH)
    local maxScroll = math.max(0, (contentH or 0) - (viewH or 0))
    local clamped = math.max(0, math.min(scrollY or 0, maxScroll))
    return clamped, maxScroll
end

--- Thin scroll indicator down the right edge of a content rect. Drawn only
--- when there is something to scroll.
function Layout.drawScrollbar(rect, scrollY, contentH, colors)
    local _, maxScroll = Layout.clampScroll(scrollY, contentH, rect.h)
    if maxScroll <= 0 then return false end
    colors = colors or {}

    local barW = 4
    local barX = rect.x + rect.w - barW - 2
    love.graphics.setColor(colors.track or { 0.15, 0.16, 0.2, 0.7 })
    love.graphics.rectangle('fill', barX, rect.y, barW, rect.h, 2, 2)

    local thumbH = math.max(20, rect.h * (rect.h / contentH))
    local travel = rect.h - thumbH
    local thumbY = rect.y + travel * (scrollY / maxScroll)
    love.graphics.setColor(colors.thumb or { 0.4, 0.5, 0.62, 0.9 })
    love.graphics.rectangle('fill', barX, thumbY, barW, thumbH, 2, 2)
    return true
end

--- Centre `text` horizontally in `rect`, ellipsised to fit.
function Layout.printCentered(text, rect, y, font)
    local shown = Layout.truncate(text, rect.w - 8, font)
    local tw = Layout.textWidth(shown, font)
    love.graphics.print(shown, math.floor(rect.x + (rect.w - tw) / 2), y)
    return shown
end

return Layout
