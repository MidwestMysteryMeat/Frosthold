-- difficulty_select.lua — Difficulty + AI Director selection screen
-- Two-section layout: left = difficulty presets + custom tuning sliders,
-- right = AI Director selection with description. Step 2 of 4 in the new-game flow.

local GameState  = require('src.game_state')
local Difficulty = require('src.ui.difficulty')

local DifficultySelect = {}

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local HEADER_H     = 100
local BOTTOM_BAR_H = 64
local PANEL_GAP    = 16
local PANEL_PAD    = 18
local LIST_ROW_H   = 46
local LIST_ROW_GAP = 6
local BTN_W        = 140
local BTN_H        = 40
local CORNER_R     = 6

local SLIDER_H       = 8
local SLIDER_THUMB_R = 7
local SLIDER_ROW_H   = 36   -- label line + track, total row height

-- Estimated font pixel heights used for hit-testing geometry (no font object needed).
local SMALL_H = 12

-- Slider axis definitions (order matters — must match draw order)
local AXES = {
    { key = 'raid',      label = 'Raid Pressure',     min = 0.5, max = 2.0 },
    { key = 'weather',   label = 'Weather Harshness',  min = 0.5, max = 1.5 },
    { key = 'disease',   label = 'Disease Pressure',   min = 0.5, max = 1.5 },
    { key = 'resources', label = 'Resource Yield',     min = 0.5, max = 2.0 },
}

-- Tick marks shown on every slider
local SNAP_VALUES = { 0.5, 0.75, 1.0, 1.25, 1.5, 2.0 }

-- Fonts (created on init)
local titleFont
local headerFont
local bodyFont
local smallFont

---------------------------------------------------------------------------
-- Module state
---------------------------------------------------------------------------

local selected = {
    difficulty = 'normal',
    director   = 'chronicler',
    safetyNet  = true,
    raid       = 1.0,
    weather    = 1.0,
    disease    = 1.0,
    resources  = 1.0,
    baseTemp   = -40,
}

-- Slider drag state: set on mousedown, cleared on mouseup
local dragging = nil  -- { axisIdx, trackX, trackW, min, max }

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function DifficultySelect.init(scenario)
    titleFont  = love.graphics.newFont(28)
    headerFont = love.graphics.newFont(16)
    bodyFont   = love.graphics.newFont(12)
    smallFont  = love.graphics.newFont(10)

    dragging = nil

    -- Default to Normal preset
    local preset = Difficulty.PRESETS['normal']
    selected.difficulty = 'normal'
    selected.director   = preset.storyteller or 'chronicler'
    selected.raid       = preset.creatures   or 1.0
    selected.weather    = preset.weather     or 1.0
    selected.disease    = preset.disease     or 1.0
    selected.resources  = preset.resources   or 1.0
    selected.baseTemp   = preset.baseTemp    or -40
    selected.safetyNet  = true
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function valueToNorm(val, minV, maxV)
    return math.max(0, math.min(1, (val - minV) / (maxV - minV)))
end

local function normToValue(norm, minV, maxV)
    return minV + norm * (maxV - minV)
end

-- Snap val to nearest SNAP_VALUES entry if within 0.06.
local function snapToNearest(val, minV, maxV)
    local best, bestDist = val, math.huge
    for _, sv in ipairs(SNAP_VALUES) do
        if sv >= minV and sv <= maxV then
            local d = math.abs(val - sv)
            if d < bestDist then
                bestDist = d
                best = sv
            end
        end
    end
    return (bestDist < 0.06) and best or val
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
-- Layout
---------------------------------------------------------------------------

local function getLayout()
    local sw, sh = love.graphics.getDimensions()

    local contentY = HEADER_H
    local contentH = sh - HEADER_H - BOTTOM_BAR_H

    local baseX = math.floor(sw * 0.04)
    local totalW = sw - math.floor(sw * 0.08)

    local leftW  = math.floor(totalW * 0.50)
    local rightX = baseX + leftW + PANEL_GAP
    local rightW = sw - rightX - math.floor(sw * 0.04)

    return {
        sw       = sw,       sh       = sh,
        contentY = contentY, contentH = contentH,
        baseX    = baseX,    leftW    = leftW,
        rightX   = rightX,   rightW   = rightW,
        barY     = sh - BOTTOM_BAR_H,
        backX    = baseX,
        backY    = sh - BOTTOM_BAR_H + math.floor((BOTTOM_BAR_H - BTN_H) / 2),
        nextX    = sw - math.floor(sw * 0.04) - BTN_W,
        nextY    = sh - BOTTOM_BAR_H + math.floor((BOTTOM_BAR_H - BTN_H) / 2),
    }
end

-- Returns the Y coordinate where the slider area starts inside the left panel.
-- Replicates the draw-time ry accumulation using fixed/estimated heights so
-- both draw and hit-test code stay in sync without sharing mutable state.
local function getSliderAreaTopY(L)
    local ry = L.contentY + PANEL_PAD
    ry = ry + SMALL_H + 6                                              -- "DIFFICULTY PRESET" label
    ry = ry + #Difficulty.PRESET_ORDER * (LIST_ROW_H + LIST_ROW_GAP)  -- preset rows
    ry = ry + 10 + 8                                                   -- spacing + divider
    ry = ry + SMALL_H + 8                                              -- "CUSTOM TUNING" label
    return ry
end

-- Returns (trackX, trackY, trackW, trackH, minV, maxV) for one slider axis.
local function getSliderFullGeometry(L, axisIdx)
    local areaY  = getSliderAreaTopY(L)
    local trackX = L.baseX + PANEL_PAD
    local trackW = L.leftW - PANEL_PAD * 2
    local axis   = AXES[axisIdx]
    local rowY   = areaY + (axisIdx - 1) * (SLIDER_ROW_H + 6)
    local trackY = rowY + SLIDER_ROW_H - SLIDER_H - 4
    return trackX, trackY, trackW, SLIDER_H, axis.min, axis.max
end

---------------------------------------------------------------------------
-- Preset / director application
---------------------------------------------------------------------------

local function applyPreset(pid)
    local p = Difficulty.PRESETS[pid]
    if not p then return end
    selected.difficulty = pid
    selected.director   = p.storyteller or selected.director
    selected.raid       = p.creatures   or 1.0
    selected.weather    = p.weather     or 1.0
    selected.disease    = p.disease     or 1.0
    selected.resources  = p.resources   or 1.0
    selected.baseTemp   = p.baseTemp    or -40
end

-- After manually moving a slider, check if values still match any preset.
local function syncPresetFromSliders()
    for _, pid in ipairs(Difficulty.PRESET_ORDER) do
        local p = Difficulty.PRESETS[pid]
        if math.abs(selected.raid      - (p.creatures or 1.0)) < 0.01 and
           math.abs(selected.weather   - (p.weather   or 1.0)) < 0.01 and
           math.abs(selected.disease   - (p.disease   or 1.0)) < 0.01 and
           math.abs(selected.resources - (p.resources or 1.0)) < 0.01 and
           selected.baseTemp == p.baseTemp then
            selected.difficulty = pid
            selected.director   = p.storyteller
            return
        end
    end
    selected.difficulty = 'custom'
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

---------------------------------------------------------------------------
-- Draw: left panel (presets + custom sliders + safety net)
---------------------------------------------------------------------------

local function drawLeftPanel(L, mx, my)
    local px = L.baseX
    local py = L.contentY
    local pw = L.leftW
    local ph = L.contentH

    drawPanel(px, py, pw, ph)

    local rx = px + PANEL_PAD
    local rw = pw - PANEL_PAD * 2
    local ry = py + PANEL_PAD

    ---------------------------------------------------------------------------
    -- Difficulty presets
    ---------------------------------------------------------------------------
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.48, 0.62, 0.82)
    love.graphics.print('DIFFICULTY PRESET', rx, ry)
    ry = ry + smallFont:getHeight() + 6

    for _, pid in ipairs(Difficulty.PRESET_ORDER) do
        local pdef  = Difficulty.PRESETS[pid]
        local isSel = (selected.difficulty == pid)
        local isHov = pointInRect(mx, my, rx, ry, rw, LIST_ROW_H)
            and pointInRect(mx, my, px, py, pw, ph)

        if isSel then
            love.graphics.setColor(0.14, 0.24, 0.42, 0.95)
            love.graphics.rectangle('fill', rx, ry, rw, LIST_ROW_H, 4)
            love.graphics.setColor(0.38, 0.65, 1.0)
            love.graphics.rectangle('line', rx, ry, rw, LIST_ROW_H, 4)
        elseif isHov then
            love.graphics.setColor(0.10, 0.14, 0.22, 0.75)
            love.graphics.rectangle('fill', rx, ry, rw, LIST_ROW_H, 4)
            love.graphics.setColor(0.28, 0.38, 0.52, 0.7)
            love.graphics.rectangle('line', rx, ry, rw, LIST_ROW_H, 4)
        end

        -- Preset name
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(isSel and {1, 1, 1} or (isHov and {0.88, 0.92, 0.98} or {0.7, 0.75, 0.82}))
        love.graphics.print(pdef.name, rx + 10, ry + 6)

        -- Temperature badge (right-aligned)
        local badgeText = string.format('%d C', pdef.baseTemp)
        love.graphics.setFont(smallFont)
        local btw = smallFont:getWidth(badgeText)
        love.graphics.setColor(isSel and {0.55, 0.78, 1.0} or {0.38, 0.48, 0.62})
        love.graphics.print(badgeText, rx + rw - btw - 8, ry + 6)

        -- Short description (truncated to fit)
        love.graphics.setFont(smallFont)
        love.graphics.setColor(isSel and {0.62, 0.72, 0.86} or {0.44, 0.5, 0.58})
        local shortDesc = pdef.desc:match('^(.-)%.') or pdef.desc
        while #shortDesc > 4 and smallFont:getWidth(shortDesc .. '...') > rw - 20 do
            shortDesc = shortDesc:sub(1, -2)
        end
        if pdef.desc:match('^(.-)%.') and smallFont:getWidth(pdef.desc:match('^(.-)%.') or '') > rw - 20 then
            shortDesc = shortDesc .. '...'
        end
        love.graphics.print(shortDesc, rx + 10, ry + 26)

        ry = ry + LIST_ROW_H + LIST_ROW_GAP
    end

    ry = ry + 10

    -- Divider
    love.graphics.setColor(0.2, 0.28, 0.42, 0.5)
    love.graphics.line(rx, ry, rx + rw, ry)
    ry = ry + 8

    ---------------------------------------------------------------------------
    -- Custom tuning sliders
    ---------------------------------------------------------------------------
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.48, 0.62, 0.82)
    love.graphics.print('CUSTOM TUNING', rx, ry)
    ry = ry + smallFont:getHeight() + 8

    -- sliderAreaY must equal getSliderAreaTopY(L) — both computed the same way.
    for i, axis in ipairs(AXES) do
        local trackX, trackY, trackW, trackH, minV, maxV = getSliderFullGeometry(L, i)
        local val    = selected[axis.key]
        local norm   = valueToNorm(val, minV, maxV)
        local thumbX = trackX + math.floor(norm * trackW)

        local rowLabelY = trackY - smallFont:getHeight() - 2

        -- Axis label (left)
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.65, 0.72, 0.85)
        love.graphics.print(axis.label, rx, rowLabelY)

        -- Current value (right)
        local valLabel = string.format('x%.2f', val)
        local vlw = smallFont:getWidth(valLabel)
        love.graphics.setColor(0.85, 0.88, 0.95)
        love.graphics.print(valLabel, rx + rw - vlw, rowLabelY)

        -- Track background
        love.graphics.setColor(0.1, 0.14, 0.22)
        love.graphics.rectangle('fill', trackX, trackY, trackW, trackH, 2)

        -- Filled portion
        love.graphics.setColor(0.2, 0.38, 0.65)
        love.graphics.rectangle('fill', trackX, trackY, math.floor(norm * trackW), trackH, 2)

        -- Snap tick marks
        for _, sv in ipairs(SNAP_VALUES) do
            if sv >= minV and sv <= maxV then
                local tn = valueToNorm(sv, minV, maxV)
                local tx = trackX + math.floor(tn * trackW)
                love.graphics.setColor(0.35, 0.45, 0.6, 0.6)
                love.graphics.rectangle('fill', tx - 1, trackY - 2, 2, trackH + 4)
            end
        end

        -- Thumb
        local isDragging = dragging and dragging.axisIdx == i
        local thumbHov   = pointInRect(mx, my, thumbX - SLIDER_THUMB_R,
                               trackY - SLIDER_THUMB_R, SLIDER_THUMB_R * 2, trackH + SLIDER_THUMB_R * 2)
        if isDragging then
            love.graphics.setColor(0.7, 0.85, 1.0)
        elseif thumbHov then
            love.graphics.setColor(0.6, 0.78, 1.0)
        else
            love.graphics.setColor(0.45, 0.65, 0.9)
        end
        love.graphics.circle('fill', thumbX, trackY + math.floor(trackH / 2), SLIDER_THUMB_R)
        love.graphics.setColor(0.25, 0.4, 0.65)
        love.graphics.circle('line', thumbX, trackY + math.floor(trackH / 2), SLIDER_THUMB_R)
    end

    ---------------------------------------------------------------------------
    -- Safety Net toggle (pinned to bottom of panel)
    ---------------------------------------------------------------------------
    local toggleY   = py + ph - PANEL_PAD - SMALL_H - 8
    local boxSize   = 14
    local toggleHov = pointInRect(mx, my, rx - 4, toggleY - 4, rw + 8, SMALL_H + 12)

    if toggleHov then
        love.graphics.setColor(0.10, 0.14, 0.22, 0.75)
        love.graphics.rectangle('fill', rx - 4, toggleY - 4, rw + 8, SMALL_H + 12, 3)
    end

    love.graphics.setColor(selected.safetyNet and {0.2, 0.42, 0.72} or {0.12, 0.18, 0.28})
    love.graphics.rectangle('fill', rx, toggleY, boxSize, boxSize, 2)
    love.graphics.setColor(selected.safetyNet and {0.55, 0.78, 1.0} or {0.3, 0.4, 0.55})
    love.graphics.rectangle('line', rx, toggleY, boxSize, boxSize, 2)

    if selected.safetyNet then
        -- Draw a simple checkmark via lines
        love.graphics.setColor(0.85, 0.95, 1.0)
        love.graphics.setLineWidth(2)
        love.graphics.line(rx + 3, toggleY + 7, rx + 6, toggleY + 10, rx + 11, toggleY + 3)
        love.graphics.setLineWidth(1)
    end

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.68, 0.75, 0.88)
    love.graphics.print('Safety Net  (Mammona rescue if all colonists die)',
        rx + boxSize + 8, toggleY + 1)
end

---------------------------------------------------------------------------
-- Draw: right panel (AI Director selection + description + summary)
---------------------------------------------------------------------------

local function drawRightPanel(L, mx, my)
    local px = L.rightX
    local py = L.contentY
    local pw = L.rightW
    local ph = L.contentH

    drawPanel(px, py, pw, ph)

    local rx = px + PANEL_PAD
    local rw = pw - PANEL_PAD * 2
    local ry = py + PANEL_PAD

    -- Section header
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.48, 0.62, 0.82)
    love.graphics.print('AI DIRECTOR', rx, ry)
    ry = ry + smallFont:getHeight() + 6

    for _, did in ipairs(Difficulty.DIRECTOR_ORDER) do
        local ddef  = Difficulty.DIRECTORS[did]
        local isSel = (selected.director == did)
        local isHov = pointInRect(mx, my, rx, ry, rw, LIST_ROW_H)
            and pointInRect(mx, my, px, py, pw, ph)

        if isSel then
            love.graphics.setColor(0.14, 0.24, 0.42, 0.95)
            love.graphics.rectangle('fill', rx, ry, rw, LIST_ROW_H, 4)
            love.graphics.setColor(0.38, 0.65, 1.0)
            love.graphics.rectangle('line', rx, ry, rw, LIST_ROW_H, 4)
        elseif isHov then
            love.graphics.setColor(0.10, 0.14, 0.22, 0.75)
            love.graphics.rectangle('fill', rx, ry, rw, LIST_ROW_H, 4)
            love.graphics.setColor(0.28, 0.38, 0.52, 0.7)
            love.graphics.rectangle('line', rx, ry, rw, LIST_ROW_H, 4)
        end

        -- Director name
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(isSel and {1, 1, 1} or (isHov and {0.88, 0.92, 0.98} or {0.7, 0.75, 0.82}))
        love.graphics.print(ddef.name, rx + 10, ry + 6)

        -- Description (truncated)
        love.graphics.setFont(smallFont)
        love.graphics.setColor(isSel and {0.62, 0.72, 0.86} or {0.44, 0.5, 0.58})
        local shortDesc = ddef.desc
        while #shortDesc > 4 and smallFont:getWidth(shortDesc .. '...') > rw - 20 do
            shortDesc = shortDesc:sub(1, -2)
        end
        love.graphics.print(shortDesc, rx + 10, ry + 26)

        ry = ry + LIST_ROW_H + LIST_ROW_GAP
    end

    ry = ry + 10

    -- Divider
    love.graphics.setColor(0.2, 0.28, 0.42, 0.5)
    love.graphics.line(rx, ry, rx + rw, ry)
    ry = ry + 12

    -- Expanded description of selected director
    local selDef = Difficulty.DIRECTORS[selected.director]
    if selDef then
        love.graphics.setFont(headerFont)
        love.graphics.setColor(0.78, 0.88, 1.0)
        love.graphics.print(selDef.name, rx, ry)
        ry = ry + headerFont:getHeight() + 8

        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.6, 0.68, 0.82)
        local descLines = wrapText(selDef.desc, rw, bodyFont)
        for _, ln in ipairs(descLines) do
            love.graphics.print(ln, rx, ry)
            ry = ry + bodyFont:getHeight() + 2
        end
        ry = ry + 14

        -- Current settings summary
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.42, 0.52, 0.68)
        love.graphics.print('CURRENT SETTINGS', rx, ry)
        ry = ry + smallFont:getHeight() + 6

        local preset      = Difficulty.PRESETS[selected.difficulty]
        local presetLabel = preset and preset.name or 'Custom'
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.58, 0.68, 0.82)
        love.graphics.print(string.format('Preset:    %s', presetLabel),    rx, ry)  ry = ry + smallFont:getHeight() + 3
        love.graphics.print(string.format('Base temp: %d C', selected.baseTemp), rx, ry)  ry = ry + smallFont:getHeight() + 3
        love.graphics.print(string.format('Raids:     x%.2f', selected.raid),      rx, ry)  ry = ry + smallFont:getHeight() + 3
        love.graphics.print(string.format('Weather:   x%.2f', selected.weather),   rx, ry)  ry = ry + smallFont:getHeight() + 3
        love.graphics.print(string.format('Disease:   x%.2f', selected.disease),   rx, ry)  ry = ry + smallFont:getHeight() + 3
        love.graphics.print(string.format('Resources: x%.2f', selected.resources), rx, ry)
    end
end

---------------------------------------------------------------------------
-- Draw (public)
---------------------------------------------------------------------------

function DifficultySelect.draw()
    local L      = getLayout()
    local mx, my = love.mouse.getPosition()

    -- Background
    love.graphics.clear(0.04, 0.06, 0.1)
    love.graphics.setColor(0.06, 0.08, 0.14, 0.5)
    love.graphics.rectangle('fill', 0, 0, L.sw, L.sh)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.7, 0.85, 1.0)
    local title = 'FROSTHOLD'
    local tw    = titleFont:getWidth(title)
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
    local screenLabel = 'DIFFICULTY & AI DIRECTOR'
    local slw = headerFont:getWidth(screenLabel)
    love.graphics.print(screenLabel, math.floor((L.sw - slw) / 2), 72)

    -- Content panels
    drawLeftPanel(L, mx, my)
    drawRightPanel(L, mx, my)

    ---------------------------------------------------------------------------
    -- Bottom bar
    ---------------------------------------------------------------------------
    love.graphics.setColor(0.04, 0.055, 0.09, 0.95)
    love.graphics.rectangle('fill', 0, L.barY, L.sw, BOTTOM_BAR_H)
    love.graphics.setColor(0.2, 0.28, 0.42, 0.6)
    love.graphics.line(0, L.barY, L.sw, L.barY)

    local backHov = pointInRect(mx, my, L.backX, L.backY, BTN_W, BTN_H)
    drawButton(L.backX, L.backY, BTN_W, BTN_H, '< Back', backHov, false)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.38, 0.46, 0.58)
    local stepText = 'Step 2 of 4 -- Difficulty'
    local stepW    = smallFont:getWidth(stepText)
    love.graphics.print(stepText,
        math.floor((L.sw - stepW) / 2),
        L.barY + math.floor((BOTTOM_BAR_H - smallFont:getHeight()) / 2))

    local nextHov = pointInRect(mx, my, L.nextX, L.nextY, BTN_W, BTN_H)
    drawButton(L.nextX, L.nextY, BTN_W, BTN_H, 'Next >', nextHov, true)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.3, 0.36, 0.45)
    local hint = 'ENTER to continue  -  ESC to go back'
    local hw   = smallFont:getWidth(hint)
    love.graphics.print(hint,
        math.floor((L.sw - hw) / 2),
        L.barY + BOTTOM_BAR_H - smallFont:getHeight() - 4)
end

---------------------------------------------------------------------------
-- Input: mousepressed
---------------------------------------------------------------------------

function DifficultySelect.mousepressed(x, y, button)
    if button ~= 1 then return end

    local L = getLayout()

    -- Bottom bar buttons
    if pointInRect(x, y, L.backX, L.backY, BTN_W, BTN_H) then
        DifficultySelect.back()
        return
    end
    if pointInRect(x, y, L.nextX, L.nextY, BTN_W, BTN_H) then
        DifficultySelect.next()
        return
    end

    -- Left panel
    if pointInRect(x, y, L.baseX, L.contentY, L.leftW, L.contentH) then
        local rowX = L.baseX + PANEL_PAD
        local rowW = L.leftW - PANEL_PAD * 2
        local rowY = L.contentY + PANEL_PAD + SMALL_H + 6

        -- Preset rows
        for _, pid in ipairs(Difficulty.PRESET_ORDER) do
            if pointInRect(x, y, rowX, rowY, rowW, LIST_ROW_H) then
                applyPreset(pid)
                return
            end
            rowY = rowY + LIST_ROW_H + LIST_ROW_GAP
        end

        -- Slider tracks
        for i, axis in ipairs(AXES) do
            local trackX, trackY, trackW, trackH, minV, maxV = getSliderFullGeometry(L, i)
            local hitY = trackY - SLIDER_THUMB_R
            local hitH = trackH + SLIDER_THUMB_R * 2
            if pointInRect(x, y, trackX, hitY, trackW, hitH) then
                local norm = math.max(0, math.min(1, (x - trackX) / trackW))
                local val  = normToValue(norm, minV, maxV)
                val = snapToNearest(val, minV, maxV)
                val = math.floor(val * 100 + 0.5) / 100
                selected[axis.key] = val
                syncPresetFromSliders()
                dragging = { axisIdx = i, trackX = trackX, trackW = trackW, min = minV, max = maxV }
                return
            end
        end

        -- Safety Net toggle
        local toggleY = L.contentY + L.contentH - PANEL_PAD - SMALL_H - 8
        local toggleX = L.baseX + PANEL_PAD - 4
        local toggleW = L.leftW - PANEL_PAD * 2 + 8
        local toggleH = SMALL_H + 12
        if pointInRect(x, y, toggleX, toggleY - 4, toggleW, toggleH) then
            selected.safetyNet = not selected.safetyNet
            return
        end
    end

    -- Right panel: director rows
    if pointInRect(x, y, L.rightX, L.contentY, L.rightW, L.contentH) then
        local rowX = L.rightX + PANEL_PAD
        local rowW = L.rightW - PANEL_PAD * 2
        local rowY = L.contentY + PANEL_PAD + SMALL_H + 6

        for _, did in ipairs(Difficulty.DIRECTOR_ORDER) do
            if pointInRect(x, y, rowX, rowY, rowW, LIST_ROW_H) then
                selected.director = did
                return
            end
            rowY = rowY + LIST_ROW_H + LIST_ROW_GAP
        end
    end
end

---------------------------------------------------------------------------
-- Input: mousemoved (slider drag update)
---------------------------------------------------------------------------

function DifficultySelect.mousemoved(x, y, dx, dy)
    if not dragging then return end
    local norm = math.max(0, math.min(1, (x - dragging.trackX) / dragging.trackW))
    local val  = normToValue(norm, dragging.min, dragging.max)
    val = snapToNearest(val, dragging.min, dragging.max)
    val = math.floor(val * 100 + 0.5) / 100
    selected[AXES[dragging.axisIdx].key] = val
    syncPresetFromSliders()
end

---------------------------------------------------------------------------
-- Input: mousereleased
---------------------------------------------------------------------------

function DifficultySelect.mousereleased(x, y, button)
    if button == 1 then
        dragging = nil
    end
end

---------------------------------------------------------------------------
-- Input: keypressed
---------------------------------------------------------------------------

function DifficultySelect.keypressed(key)
    if key == 'escape' then
        DifficultySelect.back()
    elseif key == 'return' or key == 'kpenter' then
        DifficultySelect.next()
    end
end

---------------------------------------------------------------------------
-- Navigation
---------------------------------------------------------------------------

function DifficultySelect.next()
    Difficulty.configure({
        preset      = selected.difficulty,
        baseTemp    = selected.baseTemp,
        creatures   = selected.raid,
        weather     = selected.weather,
        disease     = selected.disease,
        resources   = selected.resources,
        storyteller = selected.director,
        scenario    = GameState.scenario,
        safetyNet   = selected.safetyNet,
    })
    local ok, CreateWorld = pcall(require, 'src.ui.create_world')
    if ok and CreateWorld and CreateWorld.init then
        CreateWorld.init()
    end
    GameState.phase = 'worldgen'
end

function DifficultySelect.back()
    GameState.phase = 'scenario'
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function DifficultySelect.getSelected()
    return selected
end

return DifficultySelect
