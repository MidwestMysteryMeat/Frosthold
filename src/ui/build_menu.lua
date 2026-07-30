-- build_menu.lua — Build menu panel for placing buildings
-- Categorized building list. Click to select, place on map with left-click.
-- Auto-categorizes buildings from their def fields with manual overrides.

local GameState = require('src.game_state')
local Layout = require('src.ui.ui_layout')
local Building  = require('src.building.building')
local rok, Research = pcall(require, 'src.research.research')
local sok_snd, Sound = pcall(require, 'src.audio.sound')
local function playClick() if sok_snd then Sound.play('click') end end

local BuildMenu = {}

---------------------------------------------------------------------------
-- Category definitions (display order)
---------------------------------------------------------------------------

local CATEGORIES = {
    { id = 'structure',   name = 'Structure' },
    { id = 'heating',     name = 'Heating' },
    { id = 'power',       name = 'Power' },
    { id = 'lighting',    name = 'Lighting' },
    { id = 'atmosphere',  name = 'Air' },
    { id = 'production',  name = 'Production' },
    { id = 'colony',      name = 'Colony' },
    { id = 'logistics',   name = 'Logistics' },
    { id = 'logic',       name = 'Logic' },
    { id = 'defense',     name = 'Defense' },
}

---------------------------------------------------------------------------
-- Manual category overrides for buildings that can't be auto-detected
---------------------------------------------------------------------------

local CATEGORY_OVERRIDE = {
    -- Heating (no genType, distinct from power generators)
    campfire    = 'heating',
    heater      = 'heating',
    greenhouse  = 'heating',
    steam_hub   = 'heating',
    -- Colony infrastructure
    bed             = 'colony',
    memorial        = 'colony',
    farm_plot       = 'colony',
    cloning_vat     = 'colony',
    radio_beacon    = 'colony',
    sos_beacon      = 'colony',
    data_terminal   = 'production',
    quest_board     = 'colony',
    expedition_table = 'colony',
    cryo_pod        = 'colony',
    scrubber        = 'colony',
    deep_drill      = 'colony',
    containment_cell = 'colony',
    anomaly_locker  = 'colony',
    -- Defense (no turretType/trapType/coverValue)
    watchtower       = 'defense',
    shield_generator = 'defense',
}

local function getCategory(id, def)
    if CATEGORY_OVERRIDE[id] then return CATEGORY_OVERRIDE[id] end
    if def.turretType then return 'defense' end
    if def.trapType then return 'defense' end
    if def.coverValue then return 'defense' end
    if def.genType then return 'power' end
    if def.machineType then return 'production' end
    if def.ventType then return 'atmosphere' end
    if def.lightPreset then return 'lighting' end
    if def.pipeType or def.tankType or def.processorType then return 'logistics' end
    if def.circuitType then return 'logic' end
    local es = def.entitySpawn
    if es == 'inserter' or es == 'conveyor' or es == 'splitter' then return 'logistics' end
    if def.tile then return 'structure' end
    return 'colony'
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local activeCategory = 'structure'
local scrollOffset = 0
local hoveredId = nil
local categoryCache = nil  -- { [catId] = { {id=, def=}, ... } }
local searchTerm = ''
local searchFocused = false

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local PANEL_H = 210
local TAB_H   = 26
local CARD_W  = 138
local CARD_H  = 50
local CARD_GAP = 3
local INFO_H  = 24
local PAD     = 8
local SEARCH_H = 24

---------------------------------------------------------------------------
-- Build the category cache from Building.defs
---------------------------------------------------------------------------

local function isBuildingAvailable(id)
    if not rok then return true end
    return Research.isBuildingAvailable(id)
end

local function getLockedResearchName(id)
    if not rok then return nil end
    return Research.getBuildingResearchName(id)
end

local function buildCache()
    categoryCache = {}
    for _, cat in ipairs(CATEGORIES) do
        categoryCache[cat.id] = {}
    end
    for id, def in pairs(Building.defs) do
        if not def.hidden then
            local cat = getCategory(id, def)
            if categoryCache[cat] then
                local available = isBuildingAvailable(id)
                local lockedBy = not available and getLockedResearchName(id) or nil
                categoryCache[cat][#categoryCache[cat] + 1] = {
                    id = id, def = def, locked = not available, lockedBy = lockedBy,
                }
            end
        end
    end
    -- Sort: unlocked first (alphabetical), then locked (alphabetical)
    for _, list in pairs(categoryCache) do
        table.sort(list, function(a, b)
            if a.locked ~= b.locked then return not a.locked end
            return (a.def.name or a.id) < (b.def.name or b.id)
        end)
    end
end

local function getVisibleBuildings()
    local buildings = categoryCache and categoryCache[activeCategory] or {}
    if searchTerm == '' then
        return buildings
    end

    local filtered = {}
    local needle = searchTerm:lower()
    for _, entry in ipairs(buildings) do
        local haystack = table.concat({
            entry.id or '',
            entry.def.name or '',
            entry.def.desc or '',
        }, ' '):lower()
        if haystack:find(needle, 1, true) then
            filtered[#filtered + 1] = entry
        end
    end
    return filtered
end

---------------------------------------------------------------------------
-- Cost formatting helpers
---------------------------------------------------------------------------

local SHORT_NAMES = {
    wood = 'W', stone = 'S', metal = 'M', components = 'C',
    fuel = 'F', steel = 'St', circuit = 'Ci', thermalCores = 'TC',
    hide = 'H',
}

local function formatCost(cost)
    if not cost then return '' end
    local parts = {}
    for res, amt in pairs(cost) do
        parts[#parts + 1] = (SHORT_NAMES[res] or res) .. ':' .. amt
    end
    return table.concat(parts, ' ')
end

local function canAfford(cost)
    if not cost then return true end
    for res, amt in pairs(cost) do
        if (GameState.resources[res] or 0) < amt then return false end
    end
    return true
end

---------------------------------------------------------------------------
-- Truncate text to fit width
---------------------------------------------------------------------------

local function truncate(text, font, maxW)
    if font:getWidth(text) <= maxW then return text end
    while #text > 1 and font:getWidth(text .. '..') > maxW do
        text = text:sub(1, -2)
    end
    return text .. '..'
end

---------------------------------------------------------------------------
-- Grid layout helpers
---------------------------------------------------------------------------

local function getGridMetrics(sw)
    local gridW = sw - PAD * 2
    local cols = math.floor((gridW + CARD_GAP) / (CARD_W + CARD_GAP))
    if cols < 1 then cols = 1 end
    local gridH = PANEL_H - TAB_H - SEARCH_H - INFO_H - 18
    return gridW, gridH, cols
end

local function getMaxScroll(sw)
    local _, gridH, cols = getGridMetrics(sw)
    local buildings = getVisibleBuildings()
    local rows = math.ceil(#buildings / cols)
    local totalH = rows * (CARD_H + CARD_GAP)
    return math.max(0, totalH - gridH)
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function BuildMenu.draw()
    if not GameState.buildMode then return end
    if not categoryCache then buildCache() end

    local sw, sh = love.graphics.getDimensions()
    local panelY = sh - PANEL_H
    local font = love.graphics.getFont()

    -- Panel background
    love.graphics.setColor(0.05, 0.06, 0.08, 0.92)
    love.graphics.rectangle('fill', 0, panelY, sw, PANEL_H)
    love.graphics.setColor(0.3, 0.4, 0.5, 0.7)
    love.graphics.line(0, panelY, sw, panelY)

    -- Category tabs
    local tabY = panelY + 4
    local tabX = PAD
    for _, cat in ipairs(CATEGORIES) do
        local tw = font:getWidth(cat.name) + 16
        local isActive = (cat.id == activeCategory)

        if isActive then
            love.graphics.setColor(0.2, 0.35, 0.5, 0.9)
        else
            love.graphics.setColor(0.12, 0.14, 0.18, 0.8)
        end
        love.graphics.rectangle('fill', tabX, tabY, tw, TAB_H - 2, 3, 3)

        if isActive then
            love.graphics.setColor(0.4, 0.7, 1, 0.8)
        else
            love.graphics.setColor(0.3, 0.35, 0.4, 0.5)
        end
        love.graphics.rectangle('line', tabX, tabY, tw, TAB_H - 2, 3, 3)

        local bright = isActive and 1 or 0.55
        love.graphics.setColor(bright, bright, bright)
        love.graphics.print(cat.name, tabX + 8, tabY + 5)

        -- Store bounds for click detection
        cat._x = tabX
        cat._w = tw
        tabX = tabX + tw + 4
    end

    -- Building count badge
    local count = #getVisibleBuildings()
    love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
    love.graphics.print('(' .. count .. ')', tabX + 4, tabY + 5)

    -- Search bar
    local searchY = panelY + TAB_H + 4
    local searchW = math.min(320, sw - PAD * 2)
    local searchText = (searchTerm ~= '' and searchTerm) or 'Search buildings...'
    love.graphics.setColor(searchFocused and 0.12 or 0.08, searchFocused and 0.18 or 0.08, 0.14, 0.92)
    love.graphics.rectangle('fill', PAD, searchY, searchW, SEARCH_H, 4)
    love.graphics.setColor(searchFocused and 0.45 or 0.28, searchFocused and 0.7 or 0.35, searchFocused and 1 or 0.45, 0.75)
    love.graphics.rectangle('line', PAD, searchY, searchW, SEARCH_H, 4)
    love.graphics.setColor(searchTerm ~= '' and 0.9 or 0.45, searchTerm ~= '' and 0.92 or 0.45, searchTerm ~= '' and 0.95 or 0.45)
    love.graphics.print(searchText, PAD + 8, searchY + 4)

    -- Grid area
    local gridW, gridH, cols = getGridMetrics(sw)
    local gridY = panelY + TAB_H + SEARCH_H + 8

    love.graphics.setScissor(PAD, gridY, gridW, gridH)

    local buildings = getVisibleBuildings()
    hoveredId = nil
    local mx, my = love.mouse.getPosition()

    for i, entry in ipairs(buildings) do
        local c = (i - 1) % cols
        local r = math.floor((i - 1) / cols)
        local cx = PAD + c * (CARD_W + CARD_GAP)
        local cy = gridY + r * (CARD_H + CARD_GAP) - scrollOffset

        if cy + CARD_H >= gridY and cy <= gridY + gridH then
            local isLocked = entry.locked
            local isSelected = not isLocked and GameState.buildGhost and GameState.buildGhost.id == entry.id
            local isHovered = mx >= cx and mx <= cx + CARD_W and my >= cy and my <= cy + CARD_H
                              and my >= gridY and my <= gridY + gridH
            local affordable = not isLocked and canAfford(entry.def.cost)

            if isHovered then hoveredId = entry.id end

            -- Card background
            if isLocked then
                love.graphics.setColor(0.06, 0.06, 0.08, 0.7)
            elseif isSelected then
                love.graphics.setColor(0.15, 0.3, 0.45, 0.95)
            elseif isHovered then
                love.graphics.setColor(0.12, 0.2, 0.3, 0.9)
            else
                love.graphics.setColor(0.08, 0.1, 0.14, 0.85)
            end
            love.graphics.rectangle('fill', cx, cy, CARD_W, CARD_H, 3, 3)

            -- Border
            if isLocked then
                love.graphics.setColor(0.3, 0.2, 0.2, 0.4)
            elseif isSelected then
                love.graphics.setColor(0.4, 0.8, 1, 0.9)
            elseif not affordable then
                love.graphics.setColor(0.5, 0.2, 0.2, 0.5)
            else
                love.graphics.setColor(0.25, 0.3, 0.35, 0.5)
            end
            love.graphics.rectangle('line', cx, cy, CARD_W, CARD_H, 3, 3)

            -- Building name
            if isLocked then
                love.graphics.setColor(0.35, 0.3, 0.3)
            elseif affordable then
                love.graphics.setColor(0.9, 0.92, 0.95)
            else
                love.graphics.setColor(0.5, 0.4, 0.4)
            end
            local name = truncate(entry.def.name or entry.id, font, CARD_W - 8)
            love.graphics.print(name, cx + 4, cy + 4)

            if isLocked then
                -- Show research requirement instead of cost
                love.graphics.setColor(0.5, 0.3, 0.2, 0.8)
                local reqStr = 'Requires: ' .. (entry.lockedBy or 'Research')
                reqStr = truncate(reqStr, font, CARD_W - 8)
                love.graphics.print(reqStr, cx + 4, cy + 20)
            else
                -- Cost line
                local costStr = formatCost(entry.def.cost)
                if affordable then
                    love.graphics.setColor(0.55, 0.6, 0.5)
                else
                    love.graphics.setColor(0.5, 0.3, 0.3)
                end
                costStr = truncate(costStr, font, CARD_W - 8)
                love.graphics.print(costStr, cx + 4, cy + 20)

                -- Power draw (if any)
                if entry.def.powerDraw then
                    love.graphics.setColor(1, 0.8, 0.3, 0.6)
                    love.graphics.print(entry.def.powerDraw .. 'W', cx + 4, cy + 34)
                end
            end
        end
    end

    love.graphics.setScissor()

    -- Info bar at bottom
    local infoY = sh - INFO_H - 2
    love.graphics.setColor(0.03, 0.04, 0.06, 0.8)
    love.graphics.rectangle('fill', 0, infoY, sw, INFO_H + 2)

    if GameState.buildGhost then
        local def = Building.defs[GameState.buildGhost.id]
        if def then
            love.graphics.setColor(0.4, 0.8, 1)
            love.graphics.print('Placing: ' .. (def.name or GameState.buildGhost.id) ..
                '    Click map to place, Right-click to deselect, ESC to exit', PAD, infoY + 4)
        end
    elseif hoveredId then
        local def = Building.defs[hoveredId]
        if def then
            love.graphics.setColor(0.85, 0.87, 0.9)
            local info = def.name or hoveredId
            if def.desc then info = info .. ' — ' .. def.desc end
            info = truncate(info, font, sw - PAD * 2)
            love.graphics.print(info, PAD, infoY + 4)
        end
    else
        love.graphics.setColor(0.45, 0.45, 0.45)
        love.graphics.print('Select a building to place. B or ESC to exit build mode. Scroll to see more.', PAD, infoY + 4)
    end
end

---------------------------------------------------------------------------
-- Mouse pressed — returns true if click was consumed
---------------------------------------------------------------------------

function BuildMenu.mousepressed(x, y, button)
    if not GameState.buildMode then return false end
    if not categoryCache then buildCache() end

    local sw, sh = love.graphics.getDimensions()
    local panelY = sh - PANEL_H

    -- Not in panel area — let map handle it
    if y < panelY then return false end

    -- Consume non-left clicks in panel (don't leak to map)
    if button ~= 1 then return true end

    local font = love.graphics.getFont()

    -- Check category tabs
    local tabY = panelY + 4
    for _, cat in ipairs(CATEGORIES) do
        if cat._x and y >= tabY and y <= tabY + TAB_H
                and x >= cat._x and x <= cat._x + cat._w then
            playClick()
            activeCategory = cat.id
            scrollOffset = 0
            return true
        end
    end

    local searchY = panelY + TAB_H + 4
    local searchW = math.min(320, sw - PAD * 2)
    if x >= PAD and x <= PAD + searchW and y >= searchY and y <= searchY + SEARCH_H then
        searchFocused = true
        return true
    end
    searchFocused = false

    -- Check building cards in grid
    local gridW, gridH, cols = getGridMetrics(sw)
    local gridY = panelY + TAB_H + SEARCH_H + 8

    if y >= gridY and y <= gridY + gridH then
        local buildings = getVisibleBuildings()
        for i, entry in ipairs(buildings) do
            local c = (i - 1) % cols
            local r = math.floor((i - 1) / cols)
            local cx = PAD + c * (CARD_W + CARD_GAP)
            local cy = gridY + r * (CARD_H + CARD_GAP) - scrollOffset

            if x >= cx and x <= cx + CARD_W and y >= cy and y <= cy + CARD_H then
                if entry.locked then return true end  -- consume click but don't select
                playClick()
                GameState.buildGhost = {
                    id = entry.id,
                    w  = entry.def.w or 1,
                    h  = entry.def.h or 1,
                }
                return true
            end
        end
    end

    return true  -- consume all clicks in panel area
end

---------------------------------------------------------------------------
-- Mouse wheel — scroll the building grid
---------------------------------------------------------------------------

function BuildMenu.wheelmoved(dx, dy)
    if not GameState.buildMode then return false end

    local sw, sh = love.graphics.getDimensions()
    local panelY = sh - PANEL_H
    local _, my = love.mouse.getPosition()

    -- Only scroll when mouse is over panel
    if my < panelY then return false end

    scrollOffset = scrollOffset - dy * (CARD_H + CARD_GAP)
    local maxScroll = getMaxScroll(sw)
    scrollOffset = math.max(0, math.min(maxScroll, scrollOffset))
    return true
end

function BuildMenu.keypressed(key)
    if not GameState.buildMode or not searchFocused then return false end
    if key == 'backspace' then
        searchTerm = Layout.dropLastChar(searchTerm)
        scrollOffset = 0
        return true
    end
    if key == 'escape' then
        searchFocused = false
        return true
    end
    return true
end

function BuildMenu.textinput(text)
    if not GameState.buildMode or not searchFocused then return false end
    if text:match('%S') or text == ' ' then
        searchTerm = searchTerm .. text
        scrollOffset = 0
    end
    return true
end

function BuildMenu.isCapturingKeyboard()
    return GameState.buildMode and searchFocused
end

---------------------------------------------------------------------------
-- Panel bounds check (for external use)
---------------------------------------------------------------------------

function BuildMenu.isInPanel(x, y)
    if not GameState.buildMode then return false end
    local sh = love.graphics.getHeight()
    return y >= sh - PANEL_H
end

---------------------------------------------------------------------------
-- Reset state (called externally if needed)
---------------------------------------------------------------------------

function BuildMenu.reset()
    scrollOffset = 0
    hoveredId = nil
    categoryCache = nil
    searchTerm = ''
    searchFocused = false
end

--- Called when research is completed to refresh locked/unlocked state.
function BuildMenu.onResearchComplete()
    categoryCache = nil
end

return BuildMenu
