-- ui_menus.lua — Pause menu, controls screen, settings, save/load slots, menu stack, save toast

local GameState    = require('src.game_state')
local SaveMenu     = require('src.ui.save_menu')
local SettingsPanel = require('src.ui.settings_panel')

local Menus = {}

-- Menu stack
local menuStack = {}

-- Pause menu button hit zones (rebuilt each frame)
local pauseMenuBtns = {}

-- Save toast notification
local saveToast = nil  -- { text, time }

-- Shared screen dimensions (set from coordinator)
local screenW, screenH = 1280, 720

function Menus.resize(w, h)
    screenW = w
    screenH = h
    SaveMenu.resize(w, h)
    SettingsPanel.resize(w, h)
end

function Menus.init()
    menuStack = {}
    pauseMenuBtns = {}
    saveToast = nil
end

function Menus.openMenu(name)
    menuStack[#menuStack + 1] = name
end

function Menus.closeMenu()
    menuStack[#menuStack] = nil
end

function Menus.isMenuOpen()
    return #menuStack > 0
end

function Menus.getMenuStackLen()
    return #menuStack
end

function Menus.showSaveToast(text)
    saveToast = { text = text, time = love.timer.getTime() }
end

function Menus.getPauseMenuBtns() return pauseMenuBtns end

---------------------------------------------------------------------------
-- Draw save toast (can be drawn outside menu context too)
---------------------------------------------------------------------------

function Menus.drawSaveToast()
    if not saveToast then return end
    if #menuStack > 0 then return end  -- drawn inside drawMenu when menu is open
    local age = love.timer.getTime() - saveToast.time
    if age < 3 then
        local alpha = age < 0.3 and (age / 0.3) or (age > 2 and (3 - age) or 1)
        local font = love.graphics.getFont()
        local tw = font:getWidth(saveToast.text)
        local tx = screenW / 2 - tw / 2
        -- Opaque, with a border: the toast is drawn on top of whatever panel
        -- triggered it, and at 0.7 alpha the panel's content read straight
        -- through the message.
        love.graphics.setColor(0.04, 0.05, 0.07, 0.96 * alpha)
        love.graphics.rectangle('fill', tx - 12, 120, tw + 24, 26, 4, 4)
        love.graphics.setColor(0.3, 0.9, 0.4, 0.7 * alpha)
        love.graphics.rectangle('line', tx - 12, 120, tw + 24, 26, 4, 4)
        love.graphics.setColor(0.3, 0.9, 0.4, alpha)
        love.graphics.print(saveToast.text, tx, 124)
    else
        saveToast = nil
    end
end

---------------------------------------------------------------------------
-- Draw menu (pause / controls)
---------------------------------------------------------------------------

function Menus.drawMenu()
    if #menuStack == 0 then return end
    local name = menuStack[#menuStack]

    if name == 'pause' then
        pauseMenuBtns = {}

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)

        -- Title
        love.graphics.setColor(0.9, 0.85, 0.7)
        local font = love.graphics.getFont()
        local title = 'PAUSED'
        love.graphics.print(title, screenW / 2 - font:getWidth(title) / 2, screenH / 2 - 100)

        -- Colony info
        love.graphics.setColor(0.6, 0.6, 0.6)
        local info = string.format('%s - Day %d', GameState.colonyName, GameState.day)
        love.graphics.print(info, screenW / 2 - font:getWidth(info) / 2, screenH / 2 - 78)

        -- Buttons
        local buttons = {
            { label = 'Resume',    action = 'resume' },
            { label = 'Save Game', action = 'save' },
            { label = 'Load Game', action = 'load' },
            { label = 'Settings',  action = 'settings' },
            { label = 'Controls',  action = 'controls' },
            { label = 'Quit',      action = 'quit' },
        }
        local btnW, btnH = 160, 32
        local btnX = screenW / 2 - btnW / 2
        local btnY = screenH / 2 - 40
        local mouseX, mouseY = love.mouse.getPosition()

        for i, btn in ipairs(buttons) do
            local by = btnY + (i - 1) * (btnH + 8)
            local hovered = mouseX >= btnX and mouseX <= btnX + btnW
                        and mouseY >= by and mouseY <= by + btnH

            pauseMenuBtns[#pauseMenuBtns + 1] = {
                x = btnX, y = by, w = btnW, h = btnH, action = btn.action,
            }

            if hovered then
                love.graphics.setColor(0.25, 0.3, 0.4)
            else
                love.graphics.setColor(0.15, 0.15, 0.2)
            end
            love.graphics.rectangle('fill', btnX, by, btnW, btnH, 4, 4)
            love.graphics.setColor(0.4, 0.5, 0.6)
            love.graphics.rectangle('line', btnX, by, btnW, btnH, 4, 4)

            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.print(btn.label,
                btnX + btnW / 2 - font:getWidth(btn.label) / 2, by + 8)
        end

        -- Keybinding hints
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('F5 Quick Save  |  F9 Quick Load  |  ESC Resume', screenW / 2 - 150, btnY + #buttons * (btnH + 8) + 16)

    elseif name == 'save_slots' or name == 'load_slots' then
        SaveMenu.draw()

    elseif name == 'settings' then
        SettingsPanel.draw()

    elseif name == 'controls' then
        pauseMenuBtns = {}

        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)

        local font = love.graphics.getFont()
        local panelW = 540
        local panelH = 560
        local px = math.floor(screenW / 2 - panelW / 2)
        local py = math.floor(screenH / 2 - panelH / 2)

        -- Panel background
        love.graphics.setColor(0.06, 0.06, 0.09, 0.98)
        love.graphics.rectangle('fill', px, py, panelW, panelH, 6, 6)
        love.graphics.setColor(0.35, 0.4, 0.5, 0.8)
        love.graphics.rectangle('line', px, py, panelW, panelH, 6, 6)

        -- Title
        love.graphics.setColor(1, 1, 1)
        love.graphics.print('Controls Reference', px + panelW / 2 - font:getWidth('Controls Reference') / 2, py + 10)

        local sections = {
            { title = 'Camera', items = {
                { 'MMB Drag',     'Pan camera' },
                { 'Scroll',       'Zoom in/out' },
            }},
            { title = 'Game Speed', items = {
                { 'Space',        'Pause / Unpause' },
                { '1 / 2 / 3',   'Set speed (1x / 2x / 3x)' },
                { ', / .',        'Decrease / Increase speed' },
                { 'Escape',       'Pause menu' },
            }},
            { title = 'Selection', items = {
                { 'LMB Drag',     'Select colonists in area' },
                { 'Shift+Click',  'Add to selection' },
                { 'N',            'Cycle through colonists' },
                { 'RMB',          'Context menu / Move selected' },
            }},
            { title = 'Tools', items = {
                { 'B',            'Build menu' },
                { 'M',            'Mine designation' },
                { 'D',            'Deconstruct tool' },
                { 'Z',            'Stockpile zone' },
                { 'X',            'Dumping zone' },
                { 'Y',            'Allowed area zone' },
                { 'F',            'Forage designation' },
                { 'R',            'Rotate building / Toggle draft' },
            }},
            { title = 'Panels', items = {
                { 'L',            'Event log' },
                { 'Q',            'Goals / quests' },
                { 'J',            'Task queue' },
                { 'O',            'Doctrine panel' },
                { '/',            'Hotkey help overlay' },
                { 'F2',           'Thermal overlay' },
                { 'F3',           'Pollution overlay' },
                { 'F4',           'Power overlay' },
                { 'F6',           'Gas overlay' },
                { 'F7',           'Logistics overlay' },
                { 'F8',           'Containment overlay' },
                { 'F12',          'Debug overlay' },
            }},
            { title = 'Save / Load', items = {
                { 'F5',           'Quick save' },
                { 'F9',           'Quick load' },
            }},
            { title = 'Draft Mode', items = {
                { 'R',            'Toggle draft (single colonist selected)' },
                { 'RMB (drafted)', 'Move to tile / Attack creature' },
            }},
            { title = 'Context Menu (RMB)', items = {
                { 'On Colonist',  'Medical, treatment options' },
                { 'On Creature',  'Hunt / Force attack' },
                { 'On Building',  'Inspect, repair, deconstruct' },
                { 'On Item',      'Haul / Force eat / Force haul' },
                { 'On Rock/Tree', 'Force mine / Force chop' },
            }},
        }

        local lineY = py + 34

        for si, section in ipairs(sections) do
            -- Section title
            love.graphics.setColor(0.7, 0.85, 1)
            love.graphics.print(section.title, px + 14, lineY)
            lineY = lineY + 16

            for _, item in ipairs(section.items) do
                love.graphics.setColor(0.9, 0.8, 0.5)
                love.graphics.print(item[1], px + 24, lineY)
                love.graphics.setColor(0.6, 0.6, 0.6)
                love.graphics.print(item[2], px + 170, lineY)
                lineY = lineY + 14
            end

            lineY = lineY + 4
        end

        -- Back button
        local backBtnW, backBtnH = 120, 28
        local backBtnX = screenW / 2 - backBtnW / 2
        local backBtnY = py + panelH - 40
        local mouseX, mouseY = love.mouse.getPosition()
        local backHovered = mouseX >= backBtnX and mouseX <= backBtnX + backBtnW
                        and mouseY >= backBtnY and mouseY <= backBtnY + backBtnH

        pauseMenuBtns[#pauseMenuBtns + 1] = {
            x = backBtnX, y = backBtnY, w = backBtnW, h = backBtnH, action = 'back',
        }

        love.graphics.setColor(backHovered and 0.25 or 0.15, backHovered and 0.3 or 0.15, backHovered and 0.4 or 0.2)
        love.graphics.rectangle('fill', backBtnX, backBtnY, backBtnW, backBtnH, 4)
        love.graphics.setColor(0.4, 0.5, 0.6)
        love.graphics.rectangle('line', backBtnX, backBtnY, backBtnW, backBtnH, 4)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print('Back', backBtnX + backBtnW / 2 - font:getWidth('Back') / 2, backBtnY + 7)
    end

    -- Save/load toast (visible even when menu is open)
    if saveToast then
        local age = love.timer.getTime() - saveToast.time
        if age < 3 then
            local alpha = age < 0.3 and (age / 0.3) or (age > 2 and (3 - age) or 1)
            local font = love.graphics.getFont()
            local tw = font:getWidth(saveToast.text)
            local tx = screenW / 2 - tw / 2
            love.graphics.setColor(0, 0, 0, 0.7 * alpha)
            love.graphics.rectangle('fill', tx - 12, 120, tw + 24, 26, 4, 4)
            love.graphics.setColor(0.3, 0.9, 0.4, alpha)
            love.graphics.print(saveToast.text, tx, 124)
        else
            saveToast = nil
        end
    end
end

---------------------------------------------------------------------------
-- Input: pause menu button clicks
---------------------------------------------------------------------------

local function hitTest(mx, my, rect)
    return mx >= rect.x and mx <= rect.x + rect.w
       and my >= rect.y and my <= rect.y + rect.h
end

function Menus.mousepressed(x, y, button, playClick)
    if #menuStack == 0 then return false end

    local top = menuStack[#menuStack]

    -- Settings panel handles its own input
    if top == 'settings' then
        SettingsPanel.mousepressed(x, y, button, function() Menus.closeMenu() end)
        return true
    end

    -- Save/load slot panels handle their own input
    if top == 'save_slots' or top == 'load_slots' then
        playClick()
        SaveMenu.mousepressed(x, y, button,
            function() Menus.closeMenu() end,
            function(msg) Menus.showSaveToast(msg) end,
            function(slotId)
                -- Load callback: load the slot, then close entire menu stack
                local sok, Save = pcall(require, 'src.persistence.save')
                if sok then Save.loadSlot(slotId) end
                menuStack = {}  -- clear entire stack (load_slots + pause)
                GameState.paused = false
                Menus.showSaveToast('Game Loaded')
            end)
        return true
    end

    if button == 1 then
        for _, btn in ipairs(pauseMenuBtns) do
            if hitTest(x, y, btn) then
                playClick()
                if btn.action == 'back' then
                    Menus.closeMenu()
                elseif btn.action == 'resume' then
                    Menus.closeMenu()
                    GameState.paused = false
                elseif btn.action == 'save' then
                    SaveMenu.open('save')
                    Menus.openMenu('save_slots')
                elseif btn.action == 'load' then
                    SaveMenu.open('load')
                    Menus.openMenu('load_slots')
                elseif btn.action == 'settings' then
                    SettingsPanel.init()
                    SettingsPanel.open()
                    Menus.openMenu('settings')
                elseif btn.action == 'controls' then
                    Menus.openMenu('controls')
                elseif btn.action == 'quit' then
                    love.event.quit()
                end
                return true
            end
        end
    end
    return true  -- consume all clicks when menu is open
end

function Menus.keypressed(key)
    if #menuStack == 0 then return false end
    local top = menuStack[#menuStack]
    if top == 'settings' then
        return SettingsPanel.keypressed(key, function() Menus.closeMenu() end)
    end
    if top == 'save_slots' or top == 'load_slots' then
        return SaveMenu.keypressed(key,
            function() Menus.closeMenu() end,
            function(msg) Menus.showSaveToast(msg) end)
    end
    return false
end

function Menus.textinput(text)
    if #menuStack == 0 then return false end
    local top = menuStack[#menuStack]
    if top == 'save_slots' or top == 'load_slots' then
        return SaveMenu.textinput(text)
    end
    return false
end

function Menus.wheelmoved(x, y)
    if #menuStack == 0 then return false end
    local top = menuStack[#menuStack]
    if top == 'settings' then
        return true  -- consume scroll when settings open
    end
    if top == 'save_slots' or top == 'load_slots' then
        return SaveMenu.wheelmoved(x, y)
    end
    return false
end

function Menus.mousemoved(x, y)
    if #menuStack == 0 then return false end
    local top = menuStack[#menuStack]
    if top == 'settings' then
        SettingsPanel.mousemoved(x, y)
        return true
    end
    return false
end

function Menus.mousereleased(x, y, button)
    if #menuStack == 0 then return false end
    local top = menuStack[#menuStack]
    if top == 'settings' then
        SettingsPanel.mousereleased(x, y, button)
        return true
    end
    return false
end

return Menus
