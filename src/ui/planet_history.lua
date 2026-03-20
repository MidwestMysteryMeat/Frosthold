-- planet_history.lua — Deployment history overlay for planet select screen
-- Shows all past runs on the selected planet: colony name, days survived,
-- peak pop, raids, cause of death, and MRP earned.

local PlanetHistory = {}

local visible  = false
local planetId = nil
local scrollY  = 0

-- Fonts (lazily created on first draw)
local titleFont
local bodyFont
local smallFont

local PANEL_W     = 420
local ENTRY_H     = 84
local PADDING     = 14
local SCROLL_STEP = 40

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function PlanetHistory.show(pId)
    planetId = pId
    visible  = true
    scrollY  = 0
end

function PlanetHistory.hide()
    visible = false
end

function PlanetHistory.isVisible()
    return visible
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function PlanetHistory.draw()
    if not visible then return end

    -- Lazy font init
    if not titleFont then
        titleFont = love.graphics.newFont(15)
        bodyFont  = love.graphics.newFont(11)
        smallFont = love.graphics.newFont(9)
    end

    local mok, MRP = pcall(require, 'src.sim.mrp')
    local history = {}
    if mok then
        history = MRP.getPlanetHistory(planetId) or {}
    end

    local sw, sh = love.graphics.getDimensions()

    local entryCount  = #history
    local contentH    = entryCount > 0 and (entryCount * ENTRY_H + PADDING) or 48
    local panelH      = math.min(contentH + PADDING * 3 + 36, sh - 80)
    local panelX      = math.floor((sw - PANEL_W) / 2)
    local panelY      = math.floor((sh - panelH) / 2)

    -- Dim overlay
    love.graphics.setColor(0, 0, 0, 0.70)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Panel background
    love.graphics.setColor(0.07, 0.09, 0.14, 0.97)
    love.graphics.rectangle('fill', panelX, panelY, PANEL_W, panelH, 6)

    -- Panel border
    love.graphics.setColor(0.35, 0.45, 0.6, 0.9)
    love.graphics.rectangle('line', panelX, panelY, PANEL_W, panelH, 6)

    -- Title bar background
    love.graphics.setColor(0.1, 0.13, 0.2, 1.0)
    love.graphics.rectangle('fill', panelX, panelY, PANEL_W, 34, 6)
    love.graphics.rectangle('fill', panelX, panelY + 20, PANEL_W, 14) -- square bottom corners

    -- Title text
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.85, 0.72, 0.25, 1.0)
    local titleStr = 'DEPLOYMENT HISTORY'
    local tw = titleFont:getWidth(titleStr)
    love.graphics.print(titleStr, panelX + math.floor((PANEL_W - tw) / 2), panelY + 8)

    -- Separator line
    love.graphics.setColor(0.25, 0.35, 0.5, 0.8)
    love.graphics.line(panelX + PADDING, panelY + 34, panelX + PANEL_W - PADDING, panelY + 34)

    -- Scissor for scrollable entries
    local listX = panelX
    local listY = panelY + 36
    local listH = panelH - 36 - 24  -- leave room for hint at bottom

    love.graphics.setScissor(listX, listY, PANEL_W, listH)

    local drawY = listY + PADDING - scrollY

    if entryCount == 0 then
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.45, 0.5, 0.6)
        local noRuns = 'No deployments recorded yet.'
        local nrw = bodyFont:getWidth(noRuns)
        love.graphics.print(noRuns, panelX + math.floor((PANEL_W - nrw) / 2), listY + 14)
    else
        for idx, rec in ipairs(history) do
            local ex = panelX + PADDING
            local ey = drawY

            -- Entry background (alternating rows)
            if idx % 2 == 0 then
                love.graphics.setColor(0.09, 0.11, 0.17, 0.6)
            else
                love.graphics.setColor(0.06, 0.08, 0.13, 0.4)
            end
            love.graphics.rectangle('fill', ex - 4, ey - 2, PANEL_W - PADDING * 2 + 8, ENTRY_H - 4, 3)

            -- Deployment number header
            love.graphics.setFont(bodyFont)
            love.graphics.setColor(0.85, 0.72, 0.25, 0.9)
            local depLabel = 'Deployment #' .. idx
            love.graphics.print(depLabel, ex, ey)

            -- Colony name (next to deployment number)
            if rec.colonyName then
                love.graphics.setColor(0.85, 0.9, 1.0, 0.95)
                love.graphics.print('  —  ' .. rec.colonyName, ex + bodyFont:getWidth(depLabel), ey)
            end

            -- Row 2: days + population
            local row2Y = ey + bodyFont:getHeight() + 3
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.6, 0.7, 0.8, 0.9)
            local days = rec.daysSurvived or 0
            local pop  = rec.peakPopulation or 0
            local raids = rec.raidsSurvived or 0
            love.graphics.print(
                string.format('Days: %d   Peak pop: %d   Raids survived: %d', days, pop, raids),
                ex, row2Y)

            -- Row 3: cause of death
            local row3Y = row2Y + smallFont:getHeight() + 3
            if rec.causeOfDeath then
                love.graphics.setColor(0.85, 0.3, 0.25, 0.9)
                love.graphics.print('Ended: ' .. rec.causeOfDeath, ex, row3Y)
            else
                love.graphics.setColor(0.4, 0.7, 0.4, 0.8)
                love.graphics.print('Outcome: ongoing / unknown', ex, row3Y)
            end

            -- Row 4: MRP earned (right-aligned)
            local row4Y = row3Y + smallFont:getHeight() + 3
            if rec.mrpEarned then
                love.graphics.setColor(0.85, 0.72, 0.25, 0.9)
                local mrpStr = 'MRP earned: ' .. rec.mrpEarned
                local mrpW = smallFont:getWidth(mrpStr)
                love.graphics.print(mrpStr, panelX + PANEL_W - PADDING - mrpW, row4Y)
            end

            drawY = drawY + ENTRY_H
        end
    end

    love.graphics.setScissor()

    -- Scroll bar (if content overflows)
    local maxScroll = math.max(0, contentH - listH)
    if maxScroll > 0 then
        local barX    = panelX + PANEL_W - 8
        local barTotalH = listH
        local barH    = math.max(20, math.floor(barTotalH * listH / contentH))
        local barY    = listY + math.floor(scrollY / maxScroll * (barTotalH - barH))
        love.graphics.setColor(0.35, 0.45, 0.6, 0.6)
        love.graphics.rectangle('fill', barX, barY, 4, barH, 2)
    end

    -- Hint footer
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.35, 0.4, 0.5, 0.9)
    local hint = '[ESC] Close'
    local hw   = smallFont:getWidth(hint)
    love.graphics.print(hint, panelX + math.floor((PANEL_W - hw) / 2), panelY + panelH - 18)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function PlanetHistory.keypressed(key)
    if not visible then return false end
    if key == 'escape' then
        PlanetHistory.hide()
        return true
    end
    return false
end

function PlanetHistory.wheelmoved(x, y)
    if not visible then return false end
    scrollY = math.max(0, scrollY - y * SCROLL_STEP)
    return true
end

---------------------------------------------------------------------------

return PlanetHistory
