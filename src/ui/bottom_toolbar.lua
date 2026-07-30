-- bottom_toolbar.lua — RimWorld-style bottom toolbar
-- Persistent row of category buttons at screen bottom.
-- Click to open submenu above. Click submenu item to open panel.
-- Replaces memorizing 20+ hotkeys with 1-2 clicks.

local GameState = require('src.game_state')

local Toolbar = {}

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local BAR_HEIGHT = 36
local BUTTON_W   = 90
local BUTTON_GAP = 2
local SUBMENU_ITEM_H = 28
local SUBMENU_W  = 140

---------------------------------------------------------------------------
-- Category definitions
---------------------------------------------------------------------------

local COLONY_ITEMS = {
    { id = 'research',  label = 'Research',  key = 'R', panel = 'ResearchPanel' },
    { id = 'policy',    label = 'Policy',    key = 'P', panel = 'PolicyPanel' },
    { id = 'doctrine',  label = 'Doctrine',  key = 'O', panel = 'DoctrinePanel' },
    { id = 'laws',      label = 'Laws',      key = 'L', panel = 'LawsPanel' },
    { id = 'factions',  label = 'Factions',  key = 'Shift+F', panel = 'FactionPanel' },
}

local WORK_ITEMS = {
    { id = 'farm',      label = 'Farm',      key = 'G', panel = 'FarmPanel' },
    { id = 'trade',     label = 'Trade',     key = 'T', panel = 'TradePanel' },
    { id = 'equip',     label = 'Equipment', key = 'V', panel = 'EquipPanel' },
    { id = 'taming',    label = 'Taming',    key = 'Y', panel = 'TamingPanel' },
}

local COMBAT_ITEMS = {
    { id = 'medical',   label = 'Medical',   key = 'H', panel = 'MedPanel' },
    { id = 'colony',    label = 'Roster',    key = 'C', panel = 'ColonyPanel' },
}

local INFO_ITEMS = {
    { id = 'quests',    label = 'Quests',    key = 'Q', panel = 'QuestPanel' },
    { id = 'goals',     label = 'Goals',     key = 'I', panel = 'GoalsOverlay' },
    { id = 'expedition', label = 'Expedition', key = 'E', panel = 'ExpView' },
}

local SPACE_ITEMS = {
    { id = 'starmap',   label = 'Star Map',  key = 'M', panel = 'StarMap' },
    { id = 'contracts', label = 'Contracts', key = 'K', panel = 'ContractsPanel' },
}

local TOOLS_ITEMS = {
    { id = 'build',     label = 'Build',     key = 'B', action = 'toggle_build' },
    { id = 'mine',      label = 'Mine',      key = 'M', action = 'toggle_mine' },
    { id = 'zone',      label = 'Stockpile', key = 'Z', action = 'toggle_zone' },
    { id = 'dump',      label = 'Dump Zone', key = 'X', action = 'toggle_dump' },
    { id = 'decon',     label = 'Deconstruct', key = 'D', action = 'toggle_decon' },
    { id = 'forage',    label = 'Forage',    key = 'F', action = 'toggle_forage' },
}

local OVERLAY_ITEMS = {
    { id = 'thermal',   label = 'Thermal',   key = 'F2', action = 'overlay_thermal' },
    { id = 'pollution', label = 'Pollution',  key = 'F3', action = 'overlay_pollution' },
    { id = 'power',     label = 'Power',      key = 'F4', action = 'overlay_power' },
    { id = 'gas',       label = 'Gas',        key = 'F6', action = 'overlay_gas' },
    { id = 'logistics', label = 'Logistics',  key = 'F7', action = 'overlay_logistics' },
    { id = 'contain',   label = 'Containment', key = 'F8', action = 'overlay_containment' },
}

local function getCategories()
    local cats = {
        { id = 'tools',    label = 'Orders',   items = TOOLS_ITEMS,   color = {0.7, 0.8, 0.6} },
        { id = 'colony',   label = 'Colony',   items = COLONY_ITEMS,  color = {0.6, 0.75, 0.9} },
        { id = 'work',     label = 'Work',     items = WORK_ITEMS,    color = {0.9, 0.8, 0.5} },
        { id = 'combat',   label = 'People',   items = COMBAT_ITEMS,  color = {0.9, 0.5, 0.5} },
        { id = 'info',     label = 'Info',     items = INFO_ITEMS,    color = {0.7, 0.7, 0.9} },
        { id = 'overlays', label = 'Overlays', items = OVERLAY_ITEMS, color = {0.6, 0.8, 0.7} },
    }
    -- Add space category only when in space
    if GameState.activeMap == 'space' then
        table.insert(cats, 5, { id = 'space', label = 'Space', items = SPACE_ITEMS, color = {0.5, 0.6, 1.0} })
    end
    return cats
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local openCategory = nil  -- currently open submenu category id, or nil
local hitZones = {}       -- rebuilt every frame

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function Toolbar.draw()
    if GameState.phase ~= 'playing' then return end

    local sw, sh = love.graphics.getDimensions()
    local categories = getCategories()
    local totalW = #categories * (BUTTON_W + BUTTON_GAP) - BUTTON_GAP
    local startX = math.floor((sw - totalW) / 2)
    local barY = sh - BAR_HEIGHT

    hitZones = {}

    -- Bar background
    love.graphics.setColor(0.04, 0.05, 0.08, 0.92)
    love.graphics.rectangle('fill', 0, barY, sw, BAR_HEIGHT)
    love.graphics.setColor(0.2, 0.25, 0.35, 0.6)
    love.graphics.line(0, barY, sw, barY)

    -- Category buttons
    for i, cat in ipairs(categories) do
        local bx = startX + (i - 1) * (BUTTON_W + BUTTON_GAP)
        local by = barY + 3
        local bw = BUTTON_W
        local bh = BAR_HEIGHT - 6

        local isOpen = openCategory == cat.id
        local cr, cg, cb = cat.color[1], cat.color[2], cat.color[3]

        -- Button background
        if isOpen then
            love.graphics.setColor(cr * 0.3, cg * 0.3, cb * 0.3, 0.95)
        else
            love.graphics.setColor(0.1, 0.11, 0.14, 0.9)
        end
        love.graphics.rectangle('fill', bx, by, bw, bh, 3)

        -- Button border
        love.graphics.setColor(cr * 0.6, cg * 0.6, cb * 0.6, isOpen and 0.9 or 0.4)
        love.graphics.rectangle('line', bx, by, bw, bh, 3)

        -- Button label
        love.graphics.setColor(cr, cg, cb, isOpen and 1.0 or 0.7)
        local font = love.graphics.getFont()
        local tw = font:getWidth(cat.label)
        love.graphics.print(cat.label, bx + math.floor((bw - tw) / 2), by + 4)

        -- Hit zone
        hitZones[#hitZones + 1] = {
            x = bx, y = by, w = bw, h = bh,
            type = 'category', categoryId = cat.id,
        }

        -- Submenu (if this category is open)
        if isOpen then
            local items = cat.items
            local smH = #items * SUBMENU_ITEM_H + 6
            local smX = bx
            local smY = barY - smH - 2

            -- Submenu background
            love.graphics.setColor(0.06, 0.07, 0.1, 0.95)
            love.graphics.rectangle('fill', smX, smY, SUBMENU_W, smH, 4)
            love.graphics.setColor(cr * 0.4, cg * 0.4, cb * 0.4, 0.7)
            love.graphics.rectangle('line', smX, smY, SUBMENU_W, smH, 4)

            for j, item in ipairs(items) do
                local iy = smY + 3 + (j - 1) * SUBMENU_ITEM_H

                -- Item background on hover (approximate — no hover state, just draw clean)
                love.graphics.setColor(0.08, 0.09, 0.12, 0.8)
                love.graphics.rectangle('fill', smX + 2, iy, SUBMENU_W - 4, SUBMENU_ITEM_H - 2, 2)

                -- Item label
                love.graphics.setColor(0.85, 0.85, 0.85)
                love.graphics.print(item.label, smX + 8, iy + 5)

                -- Shortcut key hint (right-aligned, dim)
                love.graphics.setColor(0.45, 0.45, 0.45)
                local keyW = font:getWidth(item.key)
                love.graphics.print(item.key, smX + SUBMENU_W - keyW - 10, iy + 5)

                -- Hit zone for submenu item
                hitZones[#hitZones + 1] = {
                    x = smX + 2, y = iy, w = SUBMENU_W - 4, h = SUBMENU_ITEM_H - 2,
                    type = 'item', item = item,
                }
            end
        end
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function Toolbar.mousepressed(x, y, button)
    if GameState.phase ~= 'playing' then return false end
    if button ~= 1 then return false end

    -- Check submenu items first (they're on top)
    for i = #hitZones, 1, -1 do
        local zone = hitZones[i]
        if x >= zone.x and x <= zone.x + zone.w
           and y >= zone.y and y <= zone.y + zone.h then

            if zone.type == 'item' then
                local item = zone.item
                openCategory = nil

                if item.panel then
                    Toolbar.openPanel(item.panel)
                elseif item.action then
                    Toolbar.executeAction(item.action)
                end
                return true

            elseif zone.type == 'category' then
                if openCategory == zone.categoryId then
                    openCategory = nil  -- toggle off
                else
                    openCategory = zone.categoryId
                end
                return true
            end
        end
    end

    -- Click outside toolbar closes submenu
    local sw, sh = love.graphics.getDimensions()
    if openCategory and y < sh - BAR_HEIGHT - 10 then
        openCategory = nil
        return false  -- let click pass through to game
    end

    return false
end

---------------------------------------------------------------------------
-- Panel opener (finds the panel module and toggles it)
---------------------------------------------------------------------------

-- Toolbar entries name panels the way main.lua's locals did; the panel manager
-- keys them by short id.
local PANEL_IDS = {
    ResearchPanel  = 'research',
    PolicyPanel    = 'policy',
    DoctrinePanel  = 'doctrine',
    LawsPanel      = 'laws',
    FactionPanel   = 'factions',
    FarmPanel      = 'farm',
    TradePanel     = 'trade',
    EquipPanel     = 'equip',
    TamingPanel    = 'taming',
    MedPanel       = 'medical',
    ColonyPanel    = 'colony',
    QuestPanel     = 'quests',
    GoalsOverlay   = 'goals',
    ExpView        = 'expedition',
    StarMap        = 'starmap',
    ContractsPanel = 'contracts',
}

--- Open a panel from a toolbar entry. Routed through the panel manager so
--- picking a second entry replaces the open panel instead of drawing another
--- full-screen panel over the top of it.
function Toolbar.openPanel(panelName)
    local id = PANEL_IDS[panelName]
    if not id then return false end
    local ok, PanelManager = pcall(require, 'src.ui.panel_manager')
    if not ok then return false end
    return PanelManager.toggle(id)
end

---------------------------------------------------------------------------
-- Action executor (for tools and overlays)
---------------------------------------------------------------------------

function Toolbar.executeAction(actionId)
    local BuildMenu = require('src.ui.build_menu')

    if actionId == 'toggle_build' then
        GameState.buildMode = not GameState.buildMode
        if GameState.buildMode then
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.selectedTool = 'build'
        else
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.selectedTool = nil
            GameState.buildGhost = nil
        end

    elseif actionId == 'toggle_mine' then
        GameState.buildMode = false
        GameState.buildGhost = nil
        GameState.selectedTool = GameState.selectedTool == 'mine' and nil or 'mine'

    elseif actionId == 'toggle_zone' then
        GameState.buildMode = false
        GameState.buildGhost = nil
        GameState.selectedTool = GameState.selectedTool == 'zone_stockpile' and nil or 'zone_stockpile'

    elseif actionId == 'toggle_dump' then
        GameState.buildMode = false
        GameState.buildGhost = nil
        GameState.selectedTool = GameState.selectedTool == 'zone_dumping' and nil or 'zone_dumping'

    elseif actionId == 'toggle_decon' then
        GameState.buildMode = false
        GameState.buildGhost = nil
        GameState.selectedTool = GameState.selectedTool == 'deconstruct' and nil or 'deconstruct'

    elseif actionId == 'toggle_forage' then
        GameState.buildMode = false
        GameState.buildGhost = nil
        GameState.selectedTool = GameState.selectedTool == 'forage' and nil or 'forage'

    elseif actionId:find('^overlay_') then
        local rok, Renderer = pcall(require, 'src.render.renderer')
        if rok then
            if actionId == 'overlay_thermal' and Renderer.toggleThermalOverlay then
                Renderer.toggleThermalOverlay()
            elseif actionId == 'overlay_pollution' and Renderer.togglePollutionOverlay then
                Renderer.togglePollutionOverlay()
            elseif actionId == 'overlay_power' and Renderer.togglePowerOverlay then
                Renderer.togglePowerOverlay()
            elseif actionId == 'overlay_gas' and Renderer.toggleAtmosphereOverlay then
                Renderer.toggleAtmosphereOverlay()
            elseif actionId == 'overlay_logistics' and Renderer.toggleLogisticsOverlay then
                Renderer.toggleLogisticsOverlay()
            elseif actionId == 'overlay_containment' and Renderer.toggleContainmentOverlay then
                Renderer.toggleContainmentOverlay()
            end
        end
    end
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function Toolbar.isSubmenuOpen()
    return openCategory ~= nil
end

function Toolbar.close()
    openCategory = nil
end

return Toolbar
