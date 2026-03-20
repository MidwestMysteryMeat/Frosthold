-- main_menu.lua — Main menu screen
-- Full-screen background (image or gradient mesh), FROSTHOLD title upper-right,
-- vertical button stack right-aligned. Dispatched from main.lua in 'menu' phase.

local MainMenu = {}

local GameState = require('src.game_state')

-- Save module loaded with pcall so the menu works even if persistence breaks.
local _saveOk, Save = pcall(require, 'src.persistence.save')

-- MRP campaign persistence (roguelite meta-progression)
local _mrpOk, MRP = pcall(require, 'src.sim.mrp')

local titleFont, subtitleFont, buttonFont, versionFont
local bgImage

-- Overlay state flags — only one overlay is active at a time.
local _showLoadMenu  = false
local _showSettings  = false

-- Button definitions rebuilt each init (Continue visibility depends on saves).
local buttons = {}

local function rebuildButtons()
    buttons = {}
    if _saveOk and Save.exists and Save.exists() then
        buttons[#buttons + 1] = { label = 'Continue',  action = 'continue' }
    end
    -- Show "Continue Campaign" when a campaign file with history exists
    if _mrpOk and MRP.getLifetime and MRP.getLifetime() > 0 then
        buttons[#buttons + 1] = { label = 'Continue Campaign', action = 'continue_campaign' }
    end
    buttons[#buttons + 1] = { label = 'New Colony', action = 'new'     }
    buttons[#buttons + 1] = { label = 'Load Game',  action = 'load'    }
    buttons[#buttons + 1] = { label = 'Options',    action = 'options'  }
    buttons[#buttons + 1] = { label = 'Credits',    action = 'credits'  }
    buttons[#buttons + 1] = { label = 'Quit',       action = 'quit'     }
end

function MainMenu.init()
    titleFont    = love.graphics.newFont(48)
    subtitleFont = love.graphics.newFont(18)
    buttonFont   = love.graphics.newFont(20)
    versionFont  = love.graphics.newFont(12)

    -- Try loading the background image; fall back to a gradient mesh.
    local ok, img = pcall(love.graphics.newImage, 'assets/menu_bg.png')
    bgImage = ok and img or nil

    _showLoadMenu = false
    _showSettings = false
    rebuildButtons()
end

---------------------------------------------------------------------------
-- Layout helpers
---------------------------------------------------------------------------

local function getButtonLayout()
    local W, H = love.graphics.getDimensions()
    local btnW, btnH = 220, 44
    local gap        = 10
    local totalH     = #buttons * btnH + (#buttons - 1) * gap
    local startX     = W - btnW - 80
    local startY     = (H - totalH) / 2 + 60
    return startX, startY, btnW, btnH, gap
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function MainMenu.draw()
    local W, H = love.graphics.getDimensions()

    -- Background -------------------------------------------------------
    if bgImage then
        local sx = W / bgImage:getWidth()
        local sy = H / bgImage:getHeight()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(bgImage, 0, 0, 0, sx, sy)
    else
        -- Gradient mesh: dark blue-grey top → near-black bottom
        local mesh = love.graphics.newMesh({
            { 0, 0, 0, 0, 0.08, 0.12, 0.20, 1 },  -- top-left
            { W, 0, 1, 0, 0.08, 0.12, 0.20, 1 },  -- top-right
            { W, H, 1, 1, 0.02, 0.03, 0.05, 1 },  -- bottom-right
            { 0, H, 0, 1, 0.02, 0.03, 0.05, 1 },  -- bottom-left
        }, 'fan')
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(mesh)
    end

    -- Title ------------------------------------------------------------
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.85, 0.9, 0.95)
    local titleText = 'FROSTHOLD'
    local titleW    = titleFont:getWidth(titleText)
    love.graphics.print(titleText, W - titleW - 80, 80)

    -- Subtitle ---------------------------------------------------------
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.6, 0.65, 0.7)
    local subText = 'A colony survival sim'
    local subW    = subtitleFont:getWidth(subText)
    love.graphics.print(subText, W - subW - 80, 138)

    -- Button stack -----------------------------------------------------
    local bx, by, bw, bh, gap = getButtonLayout()
    love.graphics.setFont(buttonFont)
    local mx, my = love.mouse.getPosition()

    for i, btn in ipairs(buttons) do
        local y     = by + (i - 1) * (bh + gap)
        local hover = mx >= bx and mx <= bx + bw and my >= y and my <= y + bh

        -- Fill
        if hover then
            love.graphics.setColor(0.55, 0.42, 0.20, 0.95)
        else
            love.graphics.setColor(0.35, 0.28, 0.15, 0.85)
        end
        love.graphics.rectangle('fill', bx, y, bw, bh, 4)

        -- Border
        love.graphics.setColor(0.60, 0.50, 0.30, 0.60)
        love.graphics.rectangle('line', bx, y, bw, bh, 4)

        -- Label (centred)
        love.graphics.setColor(0.90, 0.85, 0.75)
        local tw = buttonFont:getWidth(btn.label)
        local th = buttonFont:getHeight()
        love.graphics.print(btn.label, bx + (bw - tw) / 2, y + (bh - th) / 2)
    end

    -- Version string ---------------------------------------------------
    love.graphics.setFont(versionFont)
    love.graphics.setColor(0.40, 0.40, 0.45)
    love.graphics.print('Frosthold v0.1 (dev)', 10, H - 24)

    -- Overlays (drawn last so they appear on top) ----------------------
    if _showLoadMenu then
        local ok, SaveMenu = pcall(require, 'src.ui.save_menu')
        if ok and SaveMenu then
            SaveMenu.draw()
        end
    elseif _showSettings then
        local ok, SettingsPanel = pcall(require, 'src.ui.settings_panel')
        if ok and SettingsPanel then
            SettingsPanel.draw()
        end
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function MainMenu.mousepressed(x, y, button)
    -- Route to the active overlay first.
    if _showLoadMenu then
        local ok, SaveMenu = pcall(require, 'src.ui.save_menu')
        if ok and SaveMenu then
            SaveMenu.mousepressed(x, y, button,
                -- close callback
                function() _showLoadMenu = false end,
                -- toast callback (no-op at main menu)
                function() end,
                -- load callback: slot ID chosen → trigger load
                function(slotId)
                    _showLoadMenu = false
                    GameState._pendingLoad = slotId
                    GameState.phase = 'starting'
                end)
        end
        return
    end

    if _showSettings then
        local ok, SettingsPanel = pcall(require, 'src.ui.settings_panel')
        if ok and SettingsPanel then
            SettingsPanel.mousepressed(x, y, button,
                function() _showSettings = false end)
        end
        return
    end

    if button ~= 1 then return end

    local bx, by, bw, bh, gap = getButtonLayout()
    for i, btn in ipairs(buttons) do
        local btnY = by + (i - 1) * (bh + gap)
        if x >= bx and x <= bx + bw and y >= btnY and y <= btnY + bh then
            MainMenu._doAction(btn.action)
            return
        end
    end
end

function MainMenu.mousemoved(x, y, dx, dy)
    if _showSettings then
        local sok, Settings = pcall(require, 'src.ui.settings_panel')
        if sok and Settings.mousemoved then Settings.mousemoved(x, y, dx, dy) end
    end
end

function MainMenu.mousereleased(x, y, button)
    if _showSettings then
        local sok, Settings = pcall(require, 'src.ui.settings_panel')
        if sok and Settings.mousereleased then Settings.mousereleased(x, y, button) end
    end
end

function MainMenu.keypressed(key)
    if _showLoadMenu then
        local ok, SaveMenu = pcall(require, 'src.ui.save_menu')
        if ok and SaveMenu then
            SaveMenu.keypressed(key,
                function() _showLoadMenu = false end,
                function() end)
        end
        return
    end

    if _showSettings then
        local ok, SettingsPanel = pcall(require, 'src.ui.settings_panel')
        if ok and SettingsPanel then
            SettingsPanel.keypressed(key,
                function() _showSettings = false end)
        end
        return
    end

    if key == 'return' or key == 'kpenter' then
        MainMenu._doAction('new')
    elseif key == 'escape' then
        love.event.quit()
    end
end

---------------------------------------------------------------------------
-- Action dispatch
---------------------------------------------------------------------------

function MainMenu._doAction(action)
    if action == 'new' then
        -- Reset campaign on fresh start
        if _mrpOk and MRP.reset then
            MRP.reset()
            MRP.save()
        end
        local ok, PlanetSelect = pcall(require, 'src.ui.planet_select')
        if ok and PlanetSelect then
            PlanetSelect.init()
        end
        GameState.phase = 'planet_select'

    elseif action == 'continue_campaign' then
        -- Resume existing campaign (MRP already loaded at startup)
        local ok, PlanetSelect = pcall(require, 'src.ui.planet_select')
        if ok and PlanetSelect then
            PlanetSelect.init()
        end
        GameState.phase = 'planet_select'

    elseif action == 'continue' then
        if not (_saveOk and Save.getMostRecentSave) then return end
        local slotId = Save.getMostRecentSave()
        if slotId then
            GameState._pendingLoad = slotId
            GameState.phase = 'starting'
        end

    elseif action == 'load' then
        local ok, SaveMenu = pcall(require, 'src.ui.save_menu')
        if ok and SaveMenu then
            SaveMenu.open('load')
            _showLoadMenu = true
        end

    elseif action == 'options' then
        local ok, SettingsPanel = pcall(require, 'src.ui.settings_panel')
        if ok and SettingsPanel then
            SettingsPanel.init()
            SettingsPanel.open()
            _showSettings = true
        end

    elseif action == 'credits' then
        -- Credits overlay: reserved for a future task.

    elseif action == 'quit' then
        love.event.quit()
    end
end

return MainMenu
