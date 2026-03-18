-- start_menu.lua — Scenario picker screen
-- Two-panel layout: scrollable scenario list (left) + full description (right).
-- Part of the sequential new-game flow: planet_select → scenario → difficulty → ...

local GameState  = require('src.game_state')
local Difficulty = require('src.ui.difficulty')

local StartMenu = {}

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local HEADER_H     = 100   -- title + subtitle area
local BOTTOM_BAR_H = 64    -- back / next button bar
local PANEL_GAP    = 16    -- gap between left and right panels
local PANEL_PAD    = 20    -- inner padding for both panels
local LIST_ROW_H   = 56    -- height of each scenario row in the list
local LIST_ROW_GAP = 6     -- vertical gap between list rows
local BTN_W        = 140
local BTN_H        = 40
local CORNER_R     = 6     -- rectangle corner radius

-- Fonts (created on init)
local titleFont
local headerFont
local bodyFont
local smallFont

-- State
local selected = {
    scenario = 'crashlanded',
}

local scrollOffset = 0  -- pixels scrolled in the list panel
local maxScroll    = 0  -- computed each draw

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function StartMenu.init()
    titleFont  = love.graphics.newFont(28)
    headerFont = love.graphics.newFont(16)
    bodyFont   = love.graphics.newFont(12)
    smallFont  = love.graphics.newFont(10)
    scrollOffset = 0

    -- Ensure selected scenario is valid for the current planet
    if not Difficulty.SCENARIOS[selected.scenario] then
        selected.scenario = Difficulty.SCENARIO_ORDER[1] or 'crashlanded'
    end
end

--- Refresh scenario list for the selected planet. Called when entering setup from planet_select.
function StartMenu.refreshForPlanet(planetId)
    Difficulty.setPlanetScenarios(planetId)
    if not Difficulty.SCENARIOS[selected.scenario] then
        selected.scenario = Difficulty.SCENARIO_ORDER[1] or 'crashlanded'
    end
    scrollOffset = 0
end

---------------------------------------------------------------------------
-- Hit testing
---------------------------------------------------------------------------

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

---------------------------------------------------------------------------
-- Compute layout positions based on screen size
---------------------------------------------------------------------------

local function getLayout()
    local sw, sh = love.graphics.getDimensions()

    local contentY = HEADER_H
    local contentH = sh - HEADER_H - BOTTOM_BAR_H

    -- Left panel: 38% of width
    local leftW  = math.floor(sw * 0.38)
    local leftX  = math.floor(sw * 0.04)

    -- Right panel: fills remaining width (up to right edge with matching margin)
    local rightX = leftX + leftW + PANEL_GAP
    local rightW = sw - rightX - math.floor(sw * 0.04)

    return {
        sw = sw, sh = sh,
        contentY = contentY,
        contentH = contentH,
        leftX = leftX, leftW = leftW,
        rightX = rightX, rightW = rightW,
        -- Bottom bar
        barY = sh - BOTTOM_BAR_H,
        -- Back button (left side of bar)
        backX = leftX,
        backY = sh - BOTTOM_BAR_H + math.floor((BOTTOM_BAR_H - BTN_H) / 2),
        -- Next button (right side of bar)
        nextX = sw - math.floor(sw * 0.04) - BTN_W,
        nextY = sh - BOTTOM_BAR_H + math.floor((BOTTOM_BAR_H - BTN_H) / 2),
    }
end

---------------------------------------------------------------------------
-- Draw helpers
---------------------------------------------------------------------------

local function drawPanel(x, y, w, h)
    love.graphics.setColor(0.06, 0.08, 0.13, 0.92)
    love.graphics.rectangle('fill', x, y, w, h, CORNER_R)
    love.graphics.setColor(0.22, 0.3, 0.45, 0.7)
    love.graphics.rectangle('line', x, y, w, h, CORNER_R)
end

local function drawButton(x, y, w, h, label, isHovered, isPrimary)
    if isPrimary then
        love.graphics.setColor(isHovered and {0.2, 0.42, 0.72, 0.98} or {0.12, 0.26, 0.52, 0.92})
        love.graphics.rectangle('fill', x, y, w, h, CORNER_R)
        love.graphics.setColor(isHovered and {0.55, 0.75, 1.0} or {0.35, 0.58, 0.9})
        love.graphics.rectangle('line', x, y, w, h, CORNER_R)
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(isHovered and {0.12, 0.16, 0.24, 0.85} or {0.07, 0.09, 0.14, 0.85})
        love.graphics.rectangle('fill', x, y, w, h, CORNER_R)
        love.graphics.setColor(isHovered and {0.4, 0.5, 0.65} or {0.25, 0.33, 0.48})
        love.graphics.rectangle('line', x, y, w, h, CORNER_R)
        love.graphics.setColor(isHovered and {0.85, 0.88, 0.95} or {0.6, 0.65, 0.72})
    end
    love.graphics.setFont(bodyFont)
    local tw = bodyFont:getWidth(label)
    local th = bodyFont:getHeight()
    love.graphics.print(label, x + math.floor((w - tw) / 2), y + math.floor((h - th) / 2))
end

-- Wrap text into lines that fit within maxWidth.
local function wrapText(text, maxWidth, font)
    local lines = {}
    local words = {}
    for word in text:gmatch('%S+') do words[#words + 1] = word end
    local line = ''
    for _, word in ipairs(words) do
        local test = line == '' and word or (line .. ' ' .. word)
        if font:getWidth(test) <= maxWidth then
            line = test
        else
            if line ~= '' then lines[#lines + 1] = line end
            line = word
        end
    end
    if line ~= '' then lines[#lines + 1] = line end
    return lines
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function StartMenu.draw()
    local L   = getLayout()
    local mx, my = love.mouse.getPosition()

    -- Background
    love.graphics.clear(0.04, 0.06, 0.1)
    love.graphics.setColor(0.06, 0.08, 0.14, 0.5)
    love.graphics.rectangle('fill', 0, 0, L.sw, L.sh)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.7, 0.85, 1.0)
    local title = 'FROSTHOLD'
    local tw = titleFont:getWidth(title)
    love.graphics.print(title, math.floor((L.sw - tw) / 2), 18)

    -- Subtitle
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.4, 0.5, 0.6)
    local pok, PlanetDefs = pcall(require, 'src.world.planet_defs')
    local planetName = 'Erebus'
    if pok then
        local pdef = PlanetDefs.get(GameState.planet or 'erebus')
        if pdef then planetName = pdef.name end
    end
    local sub = 'Mammona Corporation  //  ' .. planetName .. ' Deployment'
    local stw = smallFont:getWidth(sub)
    love.graphics.print(sub, math.floor((L.sw - stw) / 2), 54)

    -- Screen label
    love.graphics.setFont(headerFont)
    love.graphics.setColor(0.5, 0.6, 0.75)
    local screenLabel = 'SELECT SCENARIO'
    local slw = headerFont:getWidth(screenLabel)
    love.graphics.print(screenLabel, math.floor((L.sw - slw) / 2), 72)

    ---------------------------------------------------------------------------
    -- Left panel: scrollable scenario list
    ---------------------------------------------------------------------------
    local listInnerH = #Difficulty.SCENARIO_ORDER * (LIST_ROW_H + LIST_ROW_GAP) - LIST_ROW_GAP
    maxScroll = math.max(0, listInnerH - (L.contentH - PANEL_PAD * 2))

    drawPanel(L.leftX, L.contentY, L.leftW, L.contentH)

    -- Scissor to clip list rows inside panel
    love.graphics.setScissor(L.leftX, L.contentY, L.leftW, L.contentH)

    local rowX = L.leftX + PANEL_PAD
    local rowW = L.leftW - PANEL_PAD * 2
    local rowBaseY = L.contentY + PANEL_PAD - scrollOffset

    for _, sid in ipairs(Difficulty.SCENARIO_ORDER) do
        local def   = Difficulty.SCENARIOS[sid]
        local rowY  = rowBaseY
        local isSel = (selected.scenario == sid)
        local isHov = pointInRect(mx, my, rowX, rowY, rowW, LIST_ROW_H)
            and pointInRect(mx, my, L.leftX, L.contentY, L.leftW, L.contentH)

        -- Row background
        if isSel then
            love.graphics.setColor(0.14, 0.24, 0.42, 0.95)
            love.graphics.rectangle('fill', rowX, rowY, rowW, LIST_ROW_H, 4)
            love.graphics.setColor(0.38, 0.65, 1.0)
            love.graphics.rectangle('line', rowX, rowY, rowW, LIST_ROW_H, 4)
        elseif isHov then
            love.graphics.setColor(0.10, 0.14, 0.22, 0.75)
            love.graphics.rectangle('fill', rowX, rowY, rowW, LIST_ROW_H, 4)
            love.graphics.setColor(0.28, 0.38, 0.52, 0.7)
            love.graphics.rectangle('line', rowX, rowY, rowW, LIST_ROW_H, 4)
        end

        -- Scenario name
        local nameLabel = def.name
        if sid == 'naked_brutality' then nameLabel = nameLabel .. '  [!]' end
        if sid == 'frozen_siege'    then nameLabel = nameLabel .. '  [!!]' end

        love.graphics.setFont(bodyFont)
        love.graphics.setColor(isSel and {1, 1, 1} or (isHov and {0.88, 0.92, 0.98} or {0.7, 0.75, 0.82}))
        love.graphics.print(nameLabel, rowX + 10, rowY + 8)

        -- Short description (one clipped line)
        love.graphics.setFont(smallFont)
        love.graphics.setColor(isSel and {0.62, 0.72, 0.86} or {0.44, 0.5, 0.58})
        local shortDesc = def.desc:match('^(.-)%.') or def.desc
        if smallFont:getWidth(shortDesc) > rowW - 20 then
            -- Truncate to fit
            while #shortDesc > 4 and smallFont:getWidth(shortDesc .. '…') > rowW - 20 do
                shortDesc = shortDesc:sub(1, -2)
            end
            shortDesc = shortDesc .. '…'
        end
        love.graphics.print(shortDesc, rowX + 10, rowY + 28)

        -- Colonist count badge (right-aligned)
        local badgeText = string.format('%d col.', def.colonists)
        local btw2 = smallFont:getWidth(badgeText)
        love.graphics.setColor(isSel and {0.45, 0.65, 0.95} or {0.35, 0.42, 0.55})
        love.graphics.print(badgeText, rowX + rowW - btw2 - 10, rowY + 8)

        rowBaseY = rowBaseY + LIST_ROW_H + LIST_ROW_GAP
    end

    love.graphics.setScissor()

    -- Scroll indicator (thin bar on right edge of panel)
    if maxScroll > 0 then
        local trackH   = L.contentH - PANEL_PAD * 2
        local thumbH   = math.max(20, trackH * (L.contentH / (listInnerH + PANEL_PAD * 2)))
        local thumbY   = L.contentY + PANEL_PAD + (scrollOffset / maxScroll) * (trackH - thumbH)
        love.graphics.setColor(0.28, 0.38, 0.55, 0.6)
        love.graphics.rectangle('fill', L.leftX + L.leftW - 6, thumbY, 4, thumbH, 2)
    end

    ---------------------------------------------------------------------------
    -- Right panel: full scenario description
    ---------------------------------------------------------------------------
    drawPanel(L.rightX, L.contentY, L.rightW, L.contentH)

    local scenDef = Difficulty.SCENARIOS[selected.scenario]
    if scenDef then
        local rx = L.rightX + PANEL_PAD
        local rw = L.rightW - PANEL_PAD * 2
        local ry = L.contentY + PANEL_PAD

        -- Scenario name (large)
        love.graphics.setFont(headerFont)
        love.graphics.setColor(0.85, 0.92, 1.0)
        love.graphics.print(scenDef.name, rx, ry)
        ry = ry + headerFont:getHeight() + 6

        -- Accent line
        love.graphics.setColor(0.3, 0.48, 0.72, 0.7)
        love.graphics.line(rx, ry, rx + rw, ry)
        ry = ry + 12

        -- Flavor text (wrapped)
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.65, 0.72, 0.82)
        local descLines = wrapText(scenDef.desc, rw, bodyFont)
        for _, ln in ipairs(descLines) do
            love.graphics.print(ln, rx, ry)
            ry = ry + bodyFont:getHeight() + 2
        end
        ry = ry + 16

        -- "Start with:" section header
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.48, 0.62, 0.82)
        love.graphics.print('START WITH:', rx, ry)
        ry = ry + smallFont:getHeight() + 6

        -- Colonist count
        love.graphics.setColor(0.72, 0.8, 0.9)
        love.graphics.print(string.format('Colonists: %d', scenDef.colonists), rx, ry)
        ry = ry + smallFont:getHeight() + 4

        -- Skill modifiers
        if scenDef.skillBoost then
            love.graphics.setColor(0.6, 0.85, 0.65)
            love.graphics.print(string.format('Skill boost: +%d to all colonists', scenDef.skillBoost), rx, ry)
            ry = ry + smallFont:getHeight() + 4
        end
        if scenDef.capSkills then
            love.graphics.setColor(0.85, 0.75, 0.5)
            love.graphics.print(string.format('Skills capped at level %d', scenDef.capSkills), rx, ry)
            ry = ry + smallFont:getHeight() + 4
        end

        -- Starting resources summary
        if scenDef.resources then
            local res = scenDef.resources
            local resItems = {}
            if (res.wood        or 0) > 0 then resItems[#resItems+1] = res.wood       .. ' wood'           end
            if (res.stone       or 0) > 0 then resItems[#resItems+1] = res.stone      .. ' stone'          end
            if (res.metal       or 0) > 0 then resItems[#resItems+1] = res.metal      .. ' metal'          end
            if (res.food        or 0) > 0 then resItems[#resItems+1] = res.food       .. ' food'           end
            if (res.fuel        or 0) > 0 then resItems[#resItems+1] = res.fuel       .. ' fuel'           end
            if (res.components  or 0) > 0 then resItems[#resItems+1] = res.components .. ' components'     end
            if (res.thermalCores or 0) > 0 then resItems[#resItems+1] = res.thermalCores .. ' thermal cores' end
            if (res.hide        or 0) > 0 then resItems[#resItems+1] = res.hide       .. ' hide'           end

            if #resItems > 0 then
                love.graphics.setColor(0.55, 0.7, 0.88)
                local resText = table.concat(resItems, ', ')
                local resLines = wrapText('Resources: ' .. resText, rw, smallFont)
                for _, ln in ipairs(resLines) do
                    love.graphics.print(ln, rx, ry)
                    ry = ry + smallFont:getHeight() + 2
                end
                ry = ry + 4
            end
        end

        -- Special flags
        if scenDef.immediateRaid then
            love.graphics.setColor(0.9, 0.45, 0.35)
            love.graphics.print('Warning: immediate raid on landing', rx, ry)
            ry = ry + smallFont:getHeight() + 4
        end
        if scenDef.wounded and scenDef.wounded > 0 then
            love.graphics.setColor(0.85, 0.6, 0.35)
            love.graphics.print(string.format('%d colonist(s) start wounded', scenDef.wounded), rx, ry)
            ry = ry + smallFont:getHeight() + 4  -- luacheck: ignore
        end
    end

    ---------------------------------------------------------------------------
    -- Bottom bar: Back | step indicator | Next
    ---------------------------------------------------------------------------
    love.graphics.setColor(0.04, 0.055, 0.09, 0.95)
    love.graphics.rectangle('fill', 0, L.barY, L.sw, BOTTOM_BAR_H)
    love.graphics.setColor(0.2, 0.28, 0.42, 0.6)
    love.graphics.line(0, L.barY, L.sw, L.barY)

    -- Back button
    local backHov = pointInRect(mx, my, L.backX, L.backY, BTN_W, BTN_H)
    drawButton(L.backX, L.backY, BTN_W, BTN_H, '< Back', backHov, false)

    -- Step indicator
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.38, 0.46, 0.58)
    local stepText = 'Step 1 of 4 — Scenario'
    local stepW    = smallFont:getWidth(stepText)
    love.graphics.print(stepText, math.floor((L.sw - stepW) / 2), L.barY + math.floor((BOTTOM_BAR_H - smallFont:getHeight()) / 2))

    -- Next button
    local nextHov = pointInRect(mx, my, L.nextX, L.nextY, BTN_W, BTN_H)
    drawButton(L.nextX, L.nextY, BTN_W, BTN_H, 'Next >', nextHov, true)

    -- Keyboard hint
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.3, 0.36, 0.45)
    local hint = 'ENTER to continue  •  ESC to go back'
    local hw   = smallFont:getWidth(hint)
    love.graphics.print(hint, math.floor((L.sw - hw) / 2), L.barY + BOTTOM_BAR_H - smallFont:getHeight() - 4)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function StartMenu.mousepressed(x, y, button)
    if button ~= 1 then return end

    local L = getLayout()

    -- Back button
    if pointInRect(x, y, L.backX, L.backY, BTN_W, BTN_H) then
        GameState.phase = 'planet_select'
        return
    end

    -- Next button
    if pointInRect(x, y, L.nextX, L.nextY, BTN_W, BTN_H) then
        StartMenu.next()
        return
    end

    -- Scenario list clicks (within left panel bounds)
    if pointInRect(x, y, L.leftX, L.contentY, L.leftW, L.contentH) then
        local rowX    = L.leftX + PANEL_PAD
        local rowW    = L.leftW - PANEL_PAD * 2
        local rowBaseY = L.contentY + PANEL_PAD - scrollOffset
        for _, sid in ipairs(Difficulty.SCENARIO_ORDER) do
            if pointInRect(x, y, rowX, rowBaseY, rowW, LIST_ROW_H) then
                selected.scenario = sid
                return
            end
            rowBaseY = rowBaseY + LIST_ROW_H + LIST_ROW_GAP
        end
    end
end

function StartMenu.wheelmoved(x, y)
    scrollOffset = scrollOffset - y * 30
    scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
end

function StartMenu.keypressed(key)
    if key == 'escape' then
        GameState.phase = 'planet_select'
        return
    end

    if key == 'return' or key == 'kpenter' then
        StartMenu.next()
        return
    end

    -- Arrow key navigation through scenario list
    if key == 'up' or key == 'down' then
        local order = Difficulty.SCENARIO_ORDER
        local currentIdx = 1
        for i, sid in ipairs(order) do
            if sid == selected.scenario then
                currentIdx = i
                break
            end
        end
        if key == 'up' then
            currentIdx = math.max(1, currentIdx - 1)
        else
            currentIdx = math.min(#order, currentIdx + 1)
        end
        selected.scenario = order[currentIdx]
    end
end

---------------------------------------------------------------------------
-- Advance to difficulty selection
---------------------------------------------------------------------------

function StartMenu.next()
    GameState.scenario = selected.scenario
    local DifficultySelect = require('src.ui.difficulty_select')
    DifficultySelect.init(selected.scenario)
    GameState.phase = 'difficulty'
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function StartMenu.getSelected()
    return selected
end

return StartMenu
