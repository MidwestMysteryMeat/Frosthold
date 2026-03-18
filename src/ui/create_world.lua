-- create_world.lua — Create World / world-gen settings screen
-- Step 3 of 4 in the new-game flow.
-- Left column: world seed + map size.  Right column: active factions.

local GameState  = require('src.game_state')
local Difficulty = require('src.ui.difficulty')

local CreateWorld = {}

---------------------------------------------------------------------------
-- Layout constants (mirrors difficulty_select.lua conventions)
---------------------------------------------------------------------------

local HEADER_H     = 100
local BOTTOM_BAR_H = 64
local PANEL_GAP    = 16
local PANEL_PAD    = 18
local BTN_W        = 140
local BTN_H        = 40
local CORNER_R     = 6

local SMALL_H      = 12   -- estimated smallFont pixel height for hit-test geometry

-- Faction list row
local FACTION_ROW_H   = 40
local FACTION_ROW_GAP = 4

-- Fonts (initialised in init)
local titleFont
local headerFont
local bodyFont
local smallFont

---------------------------------------------------------------------------
-- Module state
---------------------------------------------------------------------------

local seedText          = ''
local seedFocused       = true
local mapSizeIdx        = 1        -- index into Difficulty.MAP_SIZES
local activeFactions    = {}       -- array of faction id strings (ordered)
local factionScrollOffset = 0      -- pixels scrolled in faction list

-- Dropdown state: shows factions not yet in activeFactions
local dropdownOpen      = false
local dropdownItems     = {}       -- array of { id, name } sorted by name
local dropdownScrollOff = 0

---------------------------------------------------------------------------
-- Seed hash
---------------------------------------------------------------------------

local function hashSeed(str)
    if str == '' then return nil end
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 999999
    end
    return hash + 1
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Collect all FACTION_DEFS ids sorted by name, excluding any already active.
local function buildDropdownItems()
    local ok, Factions = pcall(require, 'src.colony.factions')
    if not ok or not Factions or not Factions.FACTION_DEFS then
        dropdownItems = {}
        return
    end
    local defs = Factions.FACTION_DEFS
    -- Build a set of active ids for fast lookup
    local activeSet = {}
    for _, fid in ipairs(activeFactions) do
        activeSet[fid] = true
    end
    local items = {}
    for fid, def in pairs(defs) do
        if not activeSet[fid] then
            items[#items + 1] = { id = fid, name = def.name }
        end
    end
    table.sort(items, function(a, b) return a.name < b.name end)
    dropdownItems = items
    dropdownScrollOff = 0
end

-- Wrap text to fit within maxWidth pixels.
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

    local baseX  = math.floor(sw * 0.04)
    local totalW = sw - math.floor(sw * 0.08)

    local leftW  = math.floor(totalW * 0.45)
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

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function CreateWorld.init()
    titleFont  = love.graphics.newFont(28)
    headerFont = love.graphics.newFont(16)
    bodyFont   = love.graphics.newFont(12)
    smallFont  = love.graphics.newFont(10)

    -- Random seed
    seedText = tostring(love.math.random(100000, 999999))
    seedFocused = true
    mapSizeIdx  = 1
    factionScrollOffset = 0
    dropdownOpen = false

    -- Populate activeFactions: all faction ids, mammona_logistics first
    local ok, Factions = pcall(require, 'src.colony.factions')
    activeFactions = {}
    if ok and Factions and Factions.FACTION_DEFS then
        -- mammona first so it's always at top and non-removable
        if Factions.FACTION_DEFS['mammona_logistics'] then
            activeFactions[#activeFactions + 1] = 'mammona_logistics'
        end
        local others = {}
        for fid in pairs(Factions.FACTION_DEFS) do
            if fid ~= 'mammona_logistics' then
                others[#others + 1] = fid
            end
        end
        table.sort(others)
        for _, fid in ipairs(others) do
            activeFactions[#activeFactions + 1] = fid
        end
    end
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

local function drawButton(x, y, w, h, label, isHovered, isPrimary, isDisabled)
    if isDisabled then
        love.graphics.setColor(0.05, 0.07, 0.10, 0.6)
        love.graphics.rectangle('fill', x, y, w, h, CORNER_R)
        love.graphics.setColor(0.18, 0.22, 0.30, 0.5)
        love.graphics.rectangle('line', x, y, w, h, CORNER_R)
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.35, 0.38, 0.44, 0.7)
        local tw = bodyFont:getWidth(label)
        local th = bodyFont:getHeight()
        love.graphics.print(label, x + math.floor((w - tw) / 2), y + math.floor((h - th) / 2))
        return
    end

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

-- Returns geometry for seed input field: (x, y, w, h)
local function getSeedFieldGeom(L)
    local rx   = L.baseX + PANEL_PAD
    local rw   = L.leftW - PANEL_PAD * 2
    local ry   = L.contentY + PANEL_PAD
    ry = ry + SMALL_H + 6   -- "WORLD SEED" label
    ry = ry + SMALL_H + 4   -- "Seed:" label
    local fieldH = 28
    -- Field takes most of the row width, leaving room for Randomize button
    local randW = 100
    local fieldW = rw - randW - 8
    return rx, ry, fieldW, fieldH, rx + fieldW + 8, ry, randW, fieldH
end

-- Returns geometry for the map size button area base Y
local function getMapSizeAreaY(L)
    local ry = L.contentY + PANEL_PAD
    ry = ry + SMALL_H + 6   -- "WORLD SEED" label
    ry = ry + SMALL_H + 4   -- "Seed:" label
    ry = ry + 28 + 14        -- field height + gap
    ry = ry + SMALL_H + 6   -- "Map Size:" label
    return ry
end

---------------------------------------------------------------------------
-- Draw: left panel
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
    -- World Seed section header
    ---------------------------------------------------------------------------
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.48, 0.62, 0.82)
    love.graphics.print('WORLD SEED', rx, ry)
    ry = ry + smallFont:getHeight() + 6

    -- "Seed:" row label
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.65, 0.72, 0.85)
    love.graphics.print('Seed:', rx, ry)
    ry = ry + smallFont:getHeight() + 4

    -- Seed text field + Randomize button
    local fieldH = 28
    local randW  = 100
    local fieldW = rw - randW - 8
    local fieldX, fieldY = rx, ry
    local randX, randY   = rx + fieldW + 8, ry

    -- Field background
    if seedFocused then
        love.graphics.setColor(0.10, 0.15, 0.25, 0.98)
    else
        love.graphics.setColor(0.07, 0.09, 0.14, 0.90)
    end
    love.graphics.rectangle('fill', fieldX, fieldY, fieldW, fieldH, 4)

    if seedFocused then
        love.graphics.setColor(0.45, 0.68, 1.0)
    else
        love.graphics.setColor(0.25, 0.35, 0.52)
    end
    love.graphics.rectangle('line', fieldX, fieldY, fieldW, fieldH, 4)

    -- Seed text
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(1, 1, 1)
    local textX = fieldX + 8
    local textY = fieldY + math.floor((fieldH - bodyFont:getHeight()) / 2)
    love.graphics.print(seedText, textX, textY)

    -- Blinking cursor
    if seedFocused then
        local elapsed  = love.timer.getTime()
        local blinkOn  = (elapsed % 1.0) < 0.5
        if blinkOn then
            local cursorX = textX + bodyFont:getWidth(seedText)
            love.graphics.setColor(0.85, 0.92, 1.0)
            love.graphics.line(cursorX + 1, textY + 2, cursorX + 1, textY + bodyFont:getHeight() - 2)
        end
    end

    -- Randomize button
    local randHov = pointInRect(mx, my, randX, randY, randW, fieldH)
    drawButton(randX, randY, randW, fieldH, 'Randomize', randHov, false)

    ry = ry + fieldH + 14

    ---------------------------------------------------------------------------
    -- Map Size section
    ---------------------------------------------------------------------------
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.48, 0.62, 0.82)
    love.graphics.print('MAP SIZE', rx, ry)
    ry = ry + smallFont:getHeight() + 6

    local mapBtnW   = math.floor((rw - 8) / 3)  -- 3 buttons, 4px gaps between
    local mapBtnH   = BTN_H
    for i, size in ipairs(Difficulty.MAP_SIZES) do
        local bx   = rx + (i - 1) * (mapBtnW + 4)
        local by   = ry
        local isSel = (i == mapSizeIdx)
        local isHov = pointInRect(mx, my, bx, by, mapBtnW, mapBtnH)
        local label = Difficulty.MAP_SIZE_NAMES[size] or tostring(size)

        if isSel then
            love.graphics.setColor(0.14, 0.24, 0.42, 0.95)
            love.graphics.rectangle('fill', bx, by, mapBtnW, mapBtnH, CORNER_R)
            love.graphics.setColor(0.45, 0.68, 1.0)
            love.graphics.rectangle('line', bx, by, mapBtnW, mapBtnH, CORNER_R)
            love.graphics.setFont(bodyFont)
            love.graphics.setColor(1, 1, 1)
        elseif isHov then
            love.graphics.setColor(0.10, 0.14, 0.22, 0.75)
            love.graphics.rectangle('fill', bx, by, mapBtnW, mapBtnH, CORNER_R)
            love.graphics.setColor(0.30, 0.40, 0.58, 0.8)
            love.graphics.rectangle('line', bx, by, mapBtnW, mapBtnH, CORNER_R)
            love.graphics.setFont(bodyFont)
            love.graphics.setColor(0.85, 0.90, 0.98)
        else
            love.graphics.setColor(0.07, 0.09, 0.14, 0.80)
            love.graphics.rectangle('fill', bx, by, mapBtnW, mapBtnH, CORNER_R)
            love.graphics.setColor(0.22, 0.30, 0.44)
            love.graphics.rectangle('line', bx, by, mapBtnW, mapBtnH, CORNER_R)
            love.graphics.setFont(bodyFont)
            love.graphics.setColor(0.55, 0.62, 0.72)
        end

        local tw = bodyFont:getWidth(label)
        local th = bodyFont:getHeight()
        love.graphics.print(label, bx + math.floor((mapBtnW - tw) / 2), by + math.floor((mapBtnH - th) / 2))
    end

    ry = ry + mapBtnH + 20

    ---------------------------------------------------------------------------
    -- Seed info (show the numeric value so player knows it will be hashed)
    ---------------------------------------------------------------------------
    love.graphics.setFont(smallFont)
    local hashVal = hashSeed(seedText)
    if hashVal then
        love.graphics.setColor(0.38, 0.48, 0.62)
        love.graphics.print(string.format('Numeric hash: %d', hashVal), rx, ry)
    else
        love.graphics.setColor(0.35, 0.40, 0.50)
        love.graphics.print('Enter a seed above (random will be used if blank)', rx, ry)
    end
end

---------------------------------------------------------------------------
-- Draw: right panel (factions)
---------------------------------------------------------------------------

-- Faction list scroll area bounds
local FACTION_LIST_PAD_TOP  = 40  -- below "FACTIONS" header
local FACTION_LIST_PAD_BOT  = 52  -- above "Add..." button

local function getFactionListBounds(L)
    local px   = L.rightX
    local py   = L.contentY
    local pw   = L.rightW
    local ph   = L.contentH
    local listX = px + PANEL_PAD
    local listY = py + PANEL_PAD + FACTION_LIST_PAD_TOP
    local listW = pw - PANEL_PAD * 2
    local listH = ph - PANEL_PAD - FACTION_LIST_PAD_TOP - FACTION_LIST_PAD_BOT
    return listX, listY, listW, listH
end

-- Returns the pixel height of the full faction list content
local function factionListContentH()
    return #activeFactions * (FACTION_ROW_H + FACTION_ROW_GAP)
end

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
    love.graphics.print('FACTIONS', rx, ry)
    ry = ry + smallFont:getHeight() + 6

    -- Faction count hint
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.36, 0.44, 0.56)
    love.graphics.print(string.format('%d active  (min 2)', #activeFactions), rx, ry)
    ry = ry + smallFont:getHeight() + 6

    ---------------------------------------------------------------------------
    -- Scrollable faction list
    ---------------------------------------------------------------------------
    local listX, listY, listW, listH = getFactionListBounds(L)

    -- Clamp scroll
    local contentH = factionListContentH()
    local maxScroll = math.max(0, contentH - listH)
    factionScrollOffset = math.max(0, math.min(factionScrollOffset, maxScroll))

    -- Scissor to list area
    love.graphics.setScissor(listX, listY, listW, listH)

    local deleteW = 26
    local nameW   = listW - deleteW - 6

    for i, fid in ipairs(activeFactions) do
        local rowY = listY + (i - 1) * (FACTION_ROW_H + FACTION_ROW_GAP) - factionScrollOffset

        -- Only draw if row is visible
        if rowY + FACTION_ROW_H >= listY and rowY <= listY + listH then
            local isHov      = pointInRect(mx, my, listX, rowY, nameW, FACTION_ROW_H)
            local isMammona  = (fid == 'mammona_logistics')
            local canDelete  = not isMammona and (#activeFactions > 2)

            -- Row background
            if isHov then
                love.graphics.setColor(0.10, 0.14, 0.22, 0.75)
                love.graphics.rectangle('fill', listX, rowY, listW, FACTION_ROW_H, 3)
                love.graphics.setColor(0.28, 0.38, 0.52, 0.5)
                love.graphics.rectangle('line', listX, rowY, listW, FACTION_ROW_H, 3)
            end

            -- Faction name
            local ok, Factions = pcall(require, 'src.colony.factions')
            local displayName = fid
            if ok and Factions and Factions.FACTION_DEFS and Factions.FACTION_DEFS[fid] then
                displayName = Factions.FACTION_DEFS[fid].name
            end

            love.graphics.setFont(bodyFont)
            if isMammona then
                love.graphics.setColor(0.75, 0.85, 0.65)
            else
                love.graphics.setColor(0.78, 0.84, 0.92)
            end
            love.graphics.print(displayName, listX + 8,
                rowY + math.floor((FACTION_ROW_H - bodyFont:getHeight()) / 2))

            -- Locked badge for Mammona
            if isMammona then
                love.graphics.setFont(smallFont)
                love.graphics.setColor(0.45, 0.55, 0.42)
                love.graphics.print('(required)', listX + nameW - smallFont:getWidth('(required)') - 4,
                    rowY + math.floor((FACTION_ROW_H - smallFont:getHeight()) / 2))
            end

            -- Delete button
            local delX = listX + nameW + 6
            local delY = rowY + math.floor((FACTION_ROW_H - 22) / 2)
            if isMammona then
                -- No delete button
            elseif canDelete then
                local delHov = pointInRect(mx, my, delX, delY, deleteW, 22)
                if delHov then
                    love.graphics.setColor(0.55, 0.16, 0.16, 0.90)
                else
                    love.graphics.setColor(0.22, 0.10, 0.10, 0.80)
                end
                love.graphics.rectangle('fill', delX, delY, deleteW, 22, 3)
                love.graphics.setColor(delHov and {0.9, 0.4, 0.4} or {0.60, 0.28, 0.28})
                love.graphics.rectangle('line', delX, delY, deleteW, 22, 3)
                love.graphics.setFont(bodyFont)
                love.graphics.setColor(delHov and {1, 0.7, 0.7} or {0.75, 0.45, 0.45})
                local xLabel = 'x'
                local xlw = bodyFont:getWidth(xLabel)
                local xlh = bodyFont:getHeight()
                love.graphics.print(xLabel, delX + math.floor((deleteW - xlw) / 2),
                    delY + math.floor((22 - xlh) / 2))
            else
                -- Disabled delete (grey, at minimum)
                love.graphics.setColor(0.10, 0.10, 0.12, 0.50)
                love.graphics.rectangle('fill', delX, delY, deleteW, 22, 3)
                love.graphics.setColor(0.18, 0.20, 0.24, 0.40)
                love.graphics.rectangle('line', delX, delY, deleteW, 22, 3)
                love.graphics.setFont(bodyFont)
                love.graphics.setColor(0.30, 0.32, 0.36, 0.5)
                local xLabel = 'x'
                local xlw = bodyFont:getWidth(xLabel)
                local xlh = bodyFont:getHeight()
                love.graphics.print(xLabel, delX + math.floor((deleteW - xlw) / 2),
                    delY + math.floor((22 - xlh) / 2))
            end
        end
    end

    love.graphics.setScissor()

    ---------------------------------------------------------------------------
    -- Scroll bar (thin, right edge of list area)
    ---------------------------------------------------------------------------
    if contentH > listH then
        local sbW     = 4
        local sbX     = listX + listW - sbW - 2
        local sbTrack = listH
        local sbThumb = math.max(20, math.floor(listH * (listH / contentH)))
        local sbPos   = math.floor((factionScrollOffset / math.max(1, contentH - listH)) * (sbTrack - sbThumb))
        love.graphics.setColor(0.18, 0.25, 0.38, 0.5)
        love.graphics.rectangle('fill', sbX, listY, sbW, listH, 2)
        love.graphics.setColor(0.38, 0.52, 0.72, 0.7)
        love.graphics.rectangle('fill', sbX, listY + sbPos, sbW, sbThumb, 2)
    end

    ---------------------------------------------------------------------------
    -- "Add..." button
    ---------------------------------------------------------------------------
    local addY    = py + ph - PANEL_PAD - BTN_H
    local addHov  = pointInRect(mx, my, rx, addY, rw, BTN_H) and not dropdownOpen

    -- Only show if there are factions available to add
    local hasAvail = false
    do
        local ok2, Fac2 = pcall(require, 'src.colony.factions')
        if ok2 and Fac2 and Fac2.FACTION_DEFS then
            local activeSet = {}
            for _, fid in ipairs(activeFactions) do activeSet[fid] = true end
            for fid in pairs(Fac2.FACTION_DEFS) do
                if not activeSet[fid] then hasAvail = true; break end
            end
        end
    end

    if hasAvail then
        drawButton(rx, addY, rw, BTN_H, 'Add Faction...', addHov, false)
    else
        drawButton(rx, addY, rw, BTN_H, 'All Factions Active', false, false, true)
    end

    ---------------------------------------------------------------------------
    -- Dropdown overlay
    ---------------------------------------------------------------------------
    if dropdownOpen then
        local ddX = rx
        local ddY = addY - math.min(#dropdownItems, 6) * (FACTION_ROW_H + FACTION_ROW_GAP) - 8
        local ddW = rw
        local ddRows = math.min(#dropdownItems, 6)
        local ddH = ddRows * (FACTION_ROW_H + FACTION_ROW_GAP) + 8

        -- Clamp dropdown above button
        if ddY < py + PANEL_PAD then
            ddY = py + PANEL_PAD
        end

        love.graphics.setColor(0.07, 0.09, 0.15, 0.98)
        love.graphics.rectangle('fill', ddX, ddY, ddW, ddH, CORNER_R)
        love.graphics.setColor(0.35, 0.5, 0.72, 0.85)
        love.graphics.rectangle('line', ddX, ddY, ddW, ddH, CORNER_R)

        local itemH = FACTION_ROW_H + FACTION_ROW_GAP
        love.graphics.setScissor(ddX, ddY, ddW, ddH)
        for i, item in ipairs(dropdownItems) do
            local iy    = ddY + 4 + (i - 1) * itemH - dropdownScrollOff
            local isHov = pointInRect(mx, my, ddX, iy, ddW, FACTION_ROW_H)
            if iy + FACTION_ROW_H >= ddY and iy <= ddY + ddH then
                if isHov then
                    love.graphics.setColor(0.12, 0.20, 0.36, 0.90)
                    love.graphics.rectangle('fill', ddX + 2, iy, ddW - 4, FACTION_ROW_H, 3)
                end
                love.graphics.setFont(bodyFont)
                love.graphics.setColor(isHov and {0.9, 0.95, 1.0} or {0.65, 0.72, 0.82})
                love.graphics.print(item.name, ddX + 10,
                    iy + math.floor((FACTION_ROW_H - bodyFont:getHeight()) / 2))
            end
        end
        love.graphics.setScissor()
    end
end

---------------------------------------------------------------------------
-- Draw (public)
---------------------------------------------------------------------------

function CreateWorld.draw()
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
    local sub = 'Mammona Corporation  //  Erebus Deployment'
    local stw = smallFont:getWidth(sub)
    love.graphics.print(sub, math.floor((L.sw - stw) / 2), 54)

    -- Screen label
    love.graphics.setFont(headerFont)
    love.graphics.setColor(0.5, 0.6, 0.75)
    local screenLabel = 'CREATE WORLD'
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
    local stepText = 'Step 3 of 4 -- World'
    local stepW    = smallFont:getWidth(stepText)
    love.graphics.print(stepText,
        math.floor((L.sw - stepW) / 2),
        L.barY + math.floor((BOTTOM_BAR_H - smallFont:getHeight()) / 2))

    local nextHov = pointInRect(mx, my, L.nextX, L.nextY, BTN_W, BTN_H)
    drawButton(L.nextX, L.nextY, BTN_W, BTN_H, 'Generate >', nextHov, true)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.3, 0.36, 0.45)
    local hint = 'ENTER to generate  -  ESC to go back'
    local hw   = smallFont:getWidth(hint)
    love.graphics.print(hint,
        math.floor((L.sw - hw) / 2),
        L.barY + BOTTOM_BAR_H - smallFont:getHeight() - 4)
end

---------------------------------------------------------------------------
-- Input: textinput (appends to seed field)
---------------------------------------------------------------------------

function CreateWorld.textinput(text)
    if not seedFocused then return end
    if #seedText >= 20 then return end
    -- Only alphanumeric
    if text:match('^[%w]+$') then
        seedText = seedText .. text
    end
end

---------------------------------------------------------------------------
-- Input: keypressed
---------------------------------------------------------------------------

function CreateWorld.keypressed(key)
    if key == 'escape' then
        if dropdownOpen then
            dropdownOpen = false
        else
            CreateWorld.back()
        end
        return
    end

    if key == 'return' or key == 'kpenter' then
        if dropdownOpen then
            dropdownOpen = false
        else
            CreateWorld.generate()
        end
        return
    end

    if key == 'backspace' and seedFocused then
        if #seedText > 0 then
            seedText = seedText:sub(1, -2)
        end
        return
    end

    if key == 'tab' then
        seedFocused = not seedFocused
        return
    end
end

---------------------------------------------------------------------------
-- Input: mousepressed
---------------------------------------------------------------------------

function CreateWorld.mousepressed(x, y, button)
    if button ~= 1 then return end

    local L = getLayout()

    ---------------------------------------------------------------------------
    -- Dismiss dropdown on outside click (check before other handlers)
    ---------------------------------------------------------------------------
    if dropdownOpen then
        local px   = L.rightX
        local py   = L.contentY
        local pw   = L.rightW
        local ph   = L.contentH
        local rx   = px + PANEL_PAD
        local rw   = pw - PANEL_PAD * 2
        local addY = py + ph - PANEL_PAD - BTN_H

        local ddRows = math.min(#dropdownItems, 6)
        local ddH    = ddRows * (FACTION_ROW_H + FACTION_ROW_GAP) + 8
        local ddY    = addY - ddH - 8
        if ddY < py + PANEL_PAD then ddY = py + PANEL_PAD end
        local ddX = rx
        local ddW = rw
        local itemH = FACTION_ROW_H + FACTION_ROW_GAP

        if pointInRect(x, y, ddX, ddY, ddW, ddH) then
            -- Click inside dropdown — add faction
            for i, item in ipairs(dropdownItems) do
                local iy = ddY + 4 + (i - 1) * itemH - dropdownScrollOff
                if pointInRect(x, y, ddX, iy, ddW, FACTION_ROW_H) then
                    activeFactions[#activeFactions + 1] = item.id
                    dropdownOpen = false
                    return
                end
            end
        else
            dropdownOpen = false
        end
        return
    end

    ---------------------------------------------------------------------------
    -- Bottom bar
    ---------------------------------------------------------------------------
    if pointInRect(x, y, L.backX, L.backY, BTN_W, BTN_H) then
        CreateWorld.back()
        return
    end
    if pointInRect(x, y, L.nextX, L.nextY, BTN_W, BTN_H) then
        CreateWorld.generate()
        return
    end

    ---------------------------------------------------------------------------
    -- Left panel interactions
    ---------------------------------------------------------------------------
    if pointInRect(x, y, L.baseX, L.contentY, L.leftW, L.contentH) then
        -- Seed field / Randomize
        local fxBase = L.baseX + PANEL_PAD
        local fwBase = L.leftW - PANEL_PAD * 2
        local randW  = 100
        local fieldW = fwBase - randW - 8

        -- Y positions mirror drawLeftPanel
        local fieldY_start = L.contentY + PANEL_PAD
            + SMALL_H + 6   -- "WORLD SEED"
            + SMALL_H + 4   -- "Seed:" label
        local fieldH = 28

        local randX = fxBase + fieldW + 8

        -- Click on seed field
        if pointInRect(x, y, fxBase, fieldY_start, fieldW, fieldH) then
            seedFocused = true
            return
        end

        -- Click on Randomize
        if pointInRect(x, y, randX, fieldY_start, randW, fieldH) then
            seedText = tostring(love.math.random(100000, 999999))
            seedFocused = false
            return
        end

        -- Click elsewhere in left panel: unfocus seed
        seedFocused = false

        -- Map size buttons
        local mapBtnY = L.contentY + PANEL_PAD
            + SMALL_H + 6   -- "WORLD SEED"
            + SMALL_H + 4   -- "Seed:" label
            + fieldH + 14   -- field row
            + SMALL_H + 6   -- "MAP SIZE"
        local mapBtnW = math.floor((fwBase - 8) / 3)
        local mapBtnH = BTN_H

        for i = 1, #Difficulty.MAP_SIZES do
            local bx = fxBase + (i - 1) * (mapBtnW + 4)
            if pointInRect(x, y, bx, mapBtnY, mapBtnW, mapBtnH) then
                mapSizeIdx = i
                return
            end
        end

        return
    end

    -- Click outside left panel — unfocus seed
    seedFocused = false

    ---------------------------------------------------------------------------
    -- Right panel interactions
    ---------------------------------------------------------------------------
    if pointInRect(x, y, L.rightX, L.contentY, L.rightW, L.contentH) then
        local px   = L.rightX
        local py   = L.contentY
        local pw   = L.rightW
        local ph   = L.contentH
        local rx   = px + PANEL_PAD
        local rw   = pw - PANEL_PAD * 2
        local addY = py + ph - PANEL_PAD - BTN_H

        -- "Add..." button
        if pointInRect(x, y, rx, addY, rw, BTN_H) then
            buildDropdownItems()
            if #dropdownItems > 0 then
                dropdownOpen = true
            end
            return
        end

        -- Faction list delete buttons
        local listX, listY, listW, listH = getFactionListBounds(L)
        if pointInRect(x, y, listX, listY, listW, listH) then
            local deleteW = 26
            local nameW   = listW - deleteW - 6
            for i, fid in ipairs(activeFactions) do
                local rowY = listY + (i - 1) * (FACTION_ROW_H + FACTION_ROW_GAP) - factionScrollOffset
                if pointInRect(x, y, listX, rowY, listW, FACTION_ROW_H) then
                    local isMammona = (fid == 'mammona_logistics')
                    local canDelete = not isMammona and (#activeFactions > 2)
                    if canDelete then
                        local delX = listX + nameW + 6
                        local delY = rowY + math.floor((FACTION_ROW_H - 22) / 2)
                        if pointInRect(x, y, delX, delY, deleteW, 22) then
                            table.remove(activeFactions, i)
                            return
                        end
                    end
                    return
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Input: wheelmoved (scroll faction list or dropdown)
---------------------------------------------------------------------------

function CreateWorld.wheelmoved(dx, dy)
    local L = getLayout()

    if dropdownOpen then
        dropdownScrollOff = math.max(0, dropdownScrollOff - dy * 24)
        local maxScroll = math.max(0,
            #dropdownItems * (FACTION_ROW_H + FACTION_ROW_GAP) - math.min(#dropdownItems, 6) * (FACTION_ROW_H + FACTION_ROW_GAP))
        dropdownScrollOff = math.min(dropdownScrollOff, maxScroll)
        return
    end

    local listX, listY, listW, listH = getFactionListBounds(L)
    local mx, my = love.mouse.getPosition()
    if pointInRect(mx, my, listX, listY, listW, listH) then
        factionScrollOffset = factionScrollOffset - dy * 24
        local maxScroll = math.max(0, factionListContentH() - listH)
        factionScrollOffset = math.max(0, math.min(factionScrollOffset, maxScroll))
    end
end

---------------------------------------------------------------------------
-- Generate action
---------------------------------------------------------------------------

function CreateWorld.generate()
    if seedText == '' then
        seedText = tostring(love.math.random(100000, 999999))
    end

    GameState.worldSeed        = seedText
    GameState.worldSeedNumeric = hashSeed(seedText)

    local mapSize = Difficulty.MAP_SIZES[mapSizeIdx]
    Difficulty.setMapSize(mapSize)
    GameState.mapWidth  = mapSize
    GameState.mapHeight = mapSize

    GameState.selectedFactions = {}
    for i, fid in ipairs(activeFactions) do
        GameState.selectedFactions[i] = fid
    end

    -- Generate hex world map for landing zone selection
    local ok, WorldMap = pcall(require, 'src.ui.world_map')
    if ok and WorldMap.generateForPlanet then
        WorldMap.generateForPlanet(GameState.planet or 'erebus')
    end
    GameState.phase = 'world_map'
end

---------------------------------------------------------------------------
-- Back navigation
---------------------------------------------------------------------------

function CreateWorld.back()
    dropdownOpen = false
    GameState.phase = 'difficulty'
end

return CreateWorld
