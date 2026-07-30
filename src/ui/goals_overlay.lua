-- goals_overlay.lua -- Compact victory goals overlay panel
-- Shows the 4 endgame victory paths with research/building/charge progress.
-- Toggle with I key.

local Layout = require('src.ui.ui_layout')

local GoalsOverlay = {}

local visible = false
local scrollY = 0

-- Lazy-loaded dependencies
local _Goals, _goalsLoaded

local function loadGoals()
    if _goalsLoaded then return _Goals end
    _goalsLoaded = true
    local ok, mod = pcall(require, 'src.colony.goals')
    _Goals = ok and mod or nil
    return _Goals
end

-- Fonts (created lazily)
local fontTitle, fontBody, fontSmall
local function getFonts()
    if not fontTitle then
        fontTitle = love.graphics.newFont(16)
        fontBody  = love.graphics.newFont(12)
        fontSmall = love.graphics.newFont(10)
    end
    return fontTitle, fontBody, fontSmall
end

-- Colors
local C = {
    bg          = { 0.03, 0.04, 0.07, 0.94 },
    border      = { 0.25, 0.35, 0.5, 0.8 },
    header      = { 0.7, 0.82, 1.0 },
    title       = { 0.85, 0.9, 1.0 },
    desc        = { 0.55, 0.58, 0.65 },
    stepDone    = { 0.35, 0.75, 0.4 },
    stepPending = { 0.5, 0.5, 0.55 },
    stepActive  = { 0.9, 0.8, 0.3 },
    barBg       = { 0.12, 0.14, 0.18 },
    barFill     = { 0.3, 0.55, 0.85 },
    barComplete = { 0.35, 0.75, 0.4 },
    cardBg      = { 0.06, 0.07, 0.1, 0.7 },
    cardBorder  = { 0.18, 0.22, 0.32, 0.6 },
    complete    = { 0.4, 0.85, 0.45 },
    dim         = { 0.4, 0.42, 0.48 },
}

---------------------------------------------------------------------------
-- Toggle / visibility
---------------------------------------------------------------------------

function GoalsOverlay.toggle()
    visible = not visible
    scrollY = 0
end

function GoalsOverlay.isVisible()
    return visible
end

---------------------------------------------------------------------------
-- Drawing helpers
---------------------------------------------------------------------------

local function drawProgressBar(x, y, w, h, progress, complete)
    local r = math.min(h / 2, 3)
    love.graphics.setColor(C.barBg)
    love.graphics.rectangle('fill', x, y, w, h, r, r)

    if progress > 0 then
        local fillW = math.max(1, math.floor(w * math.min(1, progress)))
        love.graphics.setColor(complete and C.barComplete or C.barFill)
        love.graphics.rectangle('fill', x, y, fillW, h, r, r)
    end

    love.graphics.setColor(C.cardBorder)
    love.graphics.rectangle('line', x, y, w, h, r, r)
end

local function drawCheckmark(x, y, size)
    love.graphics.setColor(C.stepDone)
    love.graphics.setLineWidth(2)
    love.graphics.line(
        x, y + size * 0.5,
        x + size * 0.35, y + size * 0.8,
        x + size, y + size * 0.15
    )
    love.graphics.setLineWidth(1)
end

local function drawEmptyBox(x, y, size)
    love.graphics.setColor(C.stepPending)
    love.graphics.rectangle('line', x, y + 1, size - 2, size - 2, 2, 2)
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function GoalsOverlay.draw()
    if not visible then return end

    local Goals = loadGoals()
    if not Goals then return end

    local goals = Goals.getAll()
    if not goals or #goals == 0 then return end

    local fTitle, fBody, fSmall = getFonts()
    local sw, sh = love.graphics.getDimensions()

    -- Panel dimensions: centered, compact
    local panelW = math.min(420, sw - 40)
    local panelH = math.min(sh - 80, 560)
    local panelX = math.floor((sw - panelW) / 2)
    local panelY = math.floor((sh - panelH) / 2)

    -- Background
    love.graphics.setColor(C.bg)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH, 6, 6)
    love.graphics.setColor(C.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', panelX, panelY, panelW, panelH, 6, 6)

    -- Header
    local headerH = 36
    love.graphics.setFont(fTitle)
    love.graphics.setColor(C.header)
    local headerText = 'VICTORY PATHS'
    local htW = fTitle:getWidth(headerText)
    love.graphics.print(headerText, panelX + math.floor((panelW - htW) / 2), panelY + 10)

    -- Separator line
    love.graphics.setColor(C.border)
    love.graphics.line(panelX + 12, panelY + headerH, panelX + panelW - 12, panelY + headerH)

    -- Hotkey hint
    love.graphics.setFont(fSmall)
    love.graphics.setColor(C.dim)
    love.graphics.print('I to close', panelX + panelW - fSmall:getWidth('I to close') - 10, panelY + 14)

    -- Content area with scissor clipping
    local contentX = panelX + 10
    local contentY = panelY + headerH + 6
    local contentW = panelW - 20
    local contentH = panelH - headerH - 16

    love.graphics.setScissor(contentX, contentY, contentW, contentH)

    local curY = contentY - scrollY
    local cardPad = 8
    local cardInner = 8

    for gi, goal in ipairs(goals) do
        local cardX = contentX
        local cardW = contentW

        -- Measure card height
        love.graphics.setFont(fBody)
        local stepH = fBody:getHeight() + 4
        local stepsHeight = #goal.steps * stepH
        local cardH = cardInner + fTitle:getHeight() + 4 + fBody:getHeight() + 6
                     + stepsHeight + 8 + 10 + cardInner

        -- Card background
        love.graphics.setColor(C.cardBg)
        love.graphics.rectangle('fill', cardX, curY, cardW, cardH, 4, 4)
        love.graphics.setColor(C.cardBorder)
        love.graphics.rectangle('line', cardX, curY, cardW, cardH, 4, 4)

        local innerX = cardX + cardInner
        local innerW = cardW - cardInner * 2
        local ly = curY + cardInner

        -- Goal title
        love.graphics.setFont(fTitle)
        love.graphics.setColor(C.title)
        love.graphics.print(goal.title, innerX, ly)

        -- Overall progress fraction on the right
        local fracText = string.format('%d/%d', goal.completedSteps, goal.totalSteps)
        local fracW = fSmall:getWidth(fracText)
        love.graphics.setFont(fSmall)
        local allDone = goal.completedSteps == goal.totalSteps
        love.graphics.setColor(allDone and C.complete or C.dim)
        love.graphics.print(fracText, innerX + innerW - fracW, ly + 3)

        ly = ly + fTitle:getHeight() + 4

        -- Status line
        love.graphics.setFont(fSmall)
        love.graphics.setColor(allDone and C.complete or C.stepActive)
        love.graphics.print(goal.status, innerX, ly)
        ly = ly + fBody:getHeight() + 6

        -- Steps
        love.graphics.setFont(fBody)
        local checkSize = 10
        for si, step in ipairs(goal.steps) do
            local stepY = ly + (si - 1) * stepH

            -- Checkbox / checkmark
            if step.done then
                drawCheckmark(innerX, stepY + 1, checkSize)
            else
                drawEmptyBox(innerX, stepY + 1, checkSize)
            end

            -- Step label. The percentage is laid out first so the label's
            -- width budget excludes it: a full-width label used to be drawn
            -- straight under the right-aligned percentage on the same line.
            local pctText = nil
            local pctW = 0
            if not step.done and step.progress > 0 then
                pctText = string.format('%d%%', math.floor(step.progress * 100 + 0.5))
                pctW = fSmall:getWidth(pctText) + Layout.MIN_GAP
            end

            local labelX = innerX + checkSize + 6
            local maxLabelW = innerW - checkSize - 6 - pctW

            if step.done then
                love.graphics.setColor(C.stepDone)
            elseif step.progress > 0 then
                love.graphics.setColor(C.stepActive)
            else
                love.graphics.setColor(C.stepPending)
            end
            -- One line per step: the card height assumes exactly stepH per step,
            -- so a wrapped label would have overrun into the next card.
            love.graphics.print(Layout.truncate(step.label, maxLabelW, fBody), labelX, stepY)

            if pctText then
                love.graphics.setFont(fSmall)
                love.graphics.setColor(C.stepActive)
                love.graphics.print(pctText, innerX + innerW - fSmall:getWidth(pctText), stepY + 1)
                love.graphics.setFont(fBody)
            end
        end

        ly = ly + stepsHeight + 8

        -- Overall progress bar
        drawProgressBar(innerX, ly, innerW, 8, goal.progress, allDone)

        curY = curY + cardH + cardPad
    end

    love.graphics.setScissor()

    -- Track total content height for scroll clamping
    local totalContentH = curY + scrollY - contentY
    local maxScroll = math.max(0, totalContentH - contentH)
    if scrollY > maxScroll then scrollY = maxScroll end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function GoalsOverlay.keypressed(key)
    if not visible then return false end
    if key == 'i' or key == 'escape' then
        GoalsOverlay.toggle()
        return true
    end
    return true -- consume all keys while open
end

function GoalsOverlay.mousepressed(x, y, button)
    if not visible then return false end
    return true -- consume clicks while open
end

function GoalsOverlay.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return GoalsOverlay
