-- settings_panel.lua -- Audio, display, and gameplay settings screen
-- Accessed from the pause menu. Persists settings to disk via love.filesystem.
-- Layout: left tab column (~150px) + right content area.

local GameState = require('src.game_state')

local Settings = {}

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local PANEL_W     = 620
local PANEL_H     = 480
local MARGIN      = 20
local SECTION_GAP = 14
local ROW_H       = 22
local SLIDER_H    = 12
local SLIDER_W    = 200
local BACK_BTN_W  = 120
local BACK_BTN_H  = 28

-- Tab column
local TAB_COL_W   = 140
local TAB_H       = 32
local TAB_PAD_X   = 10

-- Content area (right of tab column)
local CONTENT_X_OFFSET = TAB_COL_W + 16   -- px from panel left
local CONTENT_LABEL_X   = 8               -- label offset inside content area
local CONTENT_CTRL_X    = 160             -- control offset inside content area

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local TABS = {
    { id = 'general',   label = 'General'   },
    { id = 'graphics',  label = 'Graphics'  },
    { id = 'audio',     label = 'Audio'     },
    { id = 'gameplay',  label = 'Gameplay'  },
    { id = 'controls',  label = 'Controls'  },
    { id = 'dev',       label = 'Dev'       },
}

-- Active tab resets to 'general' whenever the panel is opened (no persistent memory).
local activeTab = 'general'

---------------------------------------------------------------------------
-- Resolution presets
---------------------------------------------------------------------------

local RESOLUTIONS = {
    { w = 960,  h = 540,  label = '960 x 540' },
    { w = 1024, h = 576,  label = '1024 x 576' },
    { w = 1280, h = 720,  label = '1280 x 720' },
    { w = 1366, h = 768,  label = '1366 x 768' },
    { w = 1600, h = 900,  label = '1600 x 900' },
    { w = 1920, h = 1080, label = '1920 x 1080' },
    { w = 2560, h = 1440, label = '2560 x 1440' },
    { w = 3840, h = 2160, label = '3840 x 2160' },
}

---------------------------------------------------------------------------
-- Shared screen dimensions
---------------------------------------------------------------------------

local screenW, screenH = 1280, 720

function Settings.resize(w, h)
    screenW = w
    screenH = h
end

---------------------------------------------------------------------------
-- Settings state (loaded from disk or defaults)
---------------------------------------------------------------------------

local state = {
    masterVolume  = 0.8,
    ambientVolume = 0.5,
    uiVolume      = 0.7,
    creatureVolume = 0.6,
    weatherVolume = 0.7,
    workVolume    = 0.5,
    fullscreen    = false,
    resolutionIdx = 3,  -- 1280x720
    vsync         = true,
    colorblindMode = 0,  -- 0=off, 1=protanopia, 2=deuteranopia, 3=tritanopia
    autoPauseOnRaid        = true,
    autoPauseOnDeath       = true,
    autoPauseOnMentalBreak = false,
    autoPauseOnMeltdown    = true,
    fogOfWar               = false,
    edgeScroll             = true,
    zoomSensitivity        = 3,  -- 1=slow .. 5=fast (placeholder display)
    debugOverlay           = false,
    verboseLogging         = false,
}

---------------------------------------------------------------------------
-- Colorblind mode labels and shader
---------------------------------------------------------------------------

local CB_MODES = {
    { label = 'Off' },
    { label = 'Protanopia (Red-weak)' },
    { label = 'Deuteranopia (Green-weak)' },
    { label = 'Tritanopia (Blue-weak)' },
}

-- Daltonization correction shader — applies color-space transformation
local cbShader = nil
local cbCanvas = nil

local CB_SHADER_CODE = [[
extern int mode;   // 0=off, 1=protanopia, 2=deuteranopia, 3=tritanopia

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec4 c = Texel(tex, uv) * color;
    if (mode == 0) return c;

    // Convert to LMS color space, apply simulation, convert back
    mat3 rgb2lms = mat3(
        0.31399022, 0.15537241, 0.01775239,
        0.63951294, 0.75789446, 0.10944209,
        0.04649755, 0.08670142, 0.87256922
    );
    mat3 lms2rgb = mat3(
        5.47221206, -1.1252419,  0.02980165,
       -4.6419601,   2.29317094,-0.19318073,
        0.16963708, -0.1678952,  1.16364756
    );

    mat3 sim;
    if (mode == 1) {
        // Protanopia
        sim = mat3(
            0.0, 0.0, 0.0,
            1.05118294, 1.0, 0.0,
           -0.05116099, 0.0, 1.0
        );
    } else if (mode == 2) {
        // Deuteranopia
        sim = mat3(
            1.0, 0.9513092, 0.0,
            0.0, 0.0, 0.0,
            0.0, 0.04866992, 1.0
        );
    } else {
        // Tritanopia
        sim = mat3(
            1.0, 0.0, -0.86744736,
            0.0, 1.0, 1.86727089,
            0.0, 0.0, 0.0
        );
    }

    vec3 lms = rgb2lms * c.rgb;
    vec3 simLms = sim * lms;
    vec3 simRgb = lms2rgb * simLms;

    // Daltonize: shift lost info into visible channels
    vec3 err = c.rgb - simRgb;
    float errR = err.r;
    float errG = err.g;
    float errB = err.b;
    vec3 correction = vec3(0.0);
    correction.r = 0.0;
    correction.g = 0.7 * errR + 1.0 * errG;
    correction.b = 0.7 * errR + errB;

    vec3 result = clamp(c.rgb + correction, 0.0, 1.0);
    return vec4(result, c.a);
}
]]

-- Active slider drag: { key, sliderX, sliderW } or nil
local dragging = nil

---------------------------------------------------------------------------
-- Persistence: save/load settings to love.filesystem
---------------------------------------------------------------------------

local SETTINGS_FILE = 'settings.dat'

local function serializeSettings()
    local lines = {}
    for k, v in pairs(state) do
        if type(v) == 'boolean' then
            lines[#lines + 1] = k .. '=' .. (v and 'true' or 'false')
        elseif type(v) == 'number' then
            lines[#lines + 1] = k .. '=' .. tostring(v)
        end
    end
    return table.concat(lines, '\n')
end

local function deserializeSettings(data)
    if not data or data == '' then return end
    for line in data:gmatch('[^\n]+') do
        local k, v = line:match('^(%w+)=(.+)$')
        if k and v and state[k] ~= nil then
            if v == 'true' then
                state[k] = true
            elseif v == 'false' then
                state[k] = false
            else
                local num = tonumber(v)
                if num then state[k] = num end
            end
        end
    end
end

function Settings.save()
    local data = serializeSettings()
    local ok, err = pcall(love.filesystem.write, SETTINGS_FILE, data)
    if not ok then
        -- Silently fail; settings are non-critical
    end
end

function Settings.load()
    local ok, data = pcall(love.filesystem.read, SETTINGS_FILE)
    if ok and data then
        deserializeSettings(data)
    end
end

---------------------------------------------------------------------------
-- Apply current settings to game systems
---------------------------------------------------------------------------

local function applyAudio()
    local sok, Sound = pcall(require, 'src.audio.sound')
    if not sok then return end
    Sound.setMasterVolume(state.masterVolume)
    Sound.setCategoryVolume('ambient',  state.ambientVolume)
    Sound.setCategoryVolume('ui',       state.uiVolume)
    Sound.setCategoryVolume('creature', state.creatureVolume)
    Sound.setCategoryVolume('weather',  state.weatherVolume)
    Sound.setCategoryVolume('work',     state.workVolume)
end

local function applyAutoPause()
    if not GameState.autoPause then return end
    GameState.autoPause.onRaid        = state.autoPauseOnRaid
    GameState.autoPause.onDeath       = state.autoPauseOnDeath
    GameState.autoPause.onMentalBreak = state.autoPauseOnMentalBreak
    GameState.autoPause.onMeltdown    = state.autoPauseOnMeltdown
end

local function applyDisplay()
    local res = RESOLUTIONS[state.resolutionIdx]
    if not res then return end
    local flags = {
        fullscreen     = state.fullscreen,
        fullscreentype = 'desktop',
        resizable      = true,
        minwidth       = 960,
        minheight      = 540,
        vsync          = state.vsync and 1 or 0,
    }
    love.window.setMode(res.w, res.h, flags)
    -- Notify Camera and UI of resize (love.resize callback handles this)
end

local function applyDev()
    GameState.showDebug = state.debugOverlay
end

function Settings.applyAll()
    applyAudio()
    applyAutoPause()
    applyDev()
end

---------------------------------------------------------------------------
-- Init: load settings from disk and apply
---------------------------------------------------------------------------

function Settings.init()
    Settings.load()

    -- Sync resolution index to actual window size
    local curW, curH = love.graphics.getDimensions()
    for i, res in ipairs(RESOLUTIONS) do
        if res.w == curW and res.h == curH then
            state.resolutionIdx = i
            break
        end
    end

    -- Detect current fullscreen state
    local fs = love.window.getFullscreen()
    state.fullscreen = fs

    -- Sync auto-pause from GameState (in case save loaded different values)
    if GameState.autoPause then
        state.autoPauseOnRaid        = GameState.autoPause.onRaid
        state.autoPauseOnDeath       = GameState.autoPause.onDeath
        state.autoPauseOnMentalBreak = GameState.autoPause.onMentalBreak
        state.autoPauseOnMeltdown    = GameState.autoPause.onMeltdown
    end

    -- Sync debug overlay from GameState
    state.debugOverlay = GameState.showDebug or false

    Settings.applyAll()
end

-- Reset active tab to General each time the panel is opened.
function Settings.open()
    activeTab = 'general'
    -- Re-sync debug toggle so it reflects live state
    state.debugOverlay = GameState.showDebug or false
end

---------------------------------------------------------------------------
-- Hit testing
---------------------------------------------------------------------------

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

---------------------------------------------------------------------------
-- Draw helpers
---------------------------------------------------------------------------

local function drawSectionHeader(x, y, text, contentW)
    love.graphics.setColor(0.7, 0.85, 1.0)
    love.graphics.print(text, x, y)
    love.graphics.setColor(0.3, 0.4, 0.55, 0.6)
    love.graphics.line(x, y + 16, x + (contentW or 200), y + 16)
end

local function drawSlider(x, y, w, value, label, hovered)
    -- Label
    love.graphics.setColor(0.8, 0.82, 0.85)
    love.graphics.print(label, x - CONTENT_CTRL_X + CONTENT_LABEL_X, y)

    -- Track background
    love.graphics.setColor(0.12, 0.14, 0.2)
    love.graphics.rectangle('fill', x, y + 3, w, SLIDER_H, 3)

    -- Filled portion
    local fillW = math.max(0, math.min(w, w * value))
    love.graphics.setColor(0.25, 0.55, 0.8)
    love.graphics.rectangle('fill', x, y + 3, fillW, SLIDER_H, 3)

    -- Track border
    love.graphics.setColor(hovered and {0.5, 0.65, 0.85} or {0.3, 0.38, 0.5})
    love.graphics.rectangle('line', x, y + 3, w, SLIDER_H, 3)

    -- Handle
    local handleX = x + fillW - 4
    handleX = math.max(x, math.min(x + w - 8, handleX))
    love.graphics.setColor(0.85, 0.9, 1.0)
    love.graphics.rectangle('fill', handleX, y + 1, 8, SLIDER_H + 4, 2)

    -- Value text
    love.graphics.setColor(0.65, 0.7, 0.75)
    local pctText = string.format('%d%%', math.floor(value * 100 + 0.5))
    love.graphics.print(pctText, x + w + 8, y)
end

local function drawToggle(x, y, label, enabled, hovered)
    love.graphics.setColor(0.8, 0.82, 0.85)
    love.graphics.print(label, x - CONTENT_CTRL_X + CONTENT_LABEL_X, y)

    local boxX = x
    local boxW, boxH = 36, 16
    if enabled then
        love.graphics.setColor(0.2, 0.55, 0.35, 0.9)
    else
        love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
    end
    love.graphics.rectangle('fill', boxX, y + 1, boxW, boxH, 3)
    love.graphics.setColor(hovered and {0.5, 0.65, 0.8} or {0.3, 0.38, 0.5})
    love.graphics.rectangle('line', boxX, y + 1, boxW, boxH, 3)

    -- Knob
    local knobX = enabled and (boxX + boxW - 16) or boxX + 2
    love.graphics.setColor(0.85, 0.9, 1.0)
    love.graphics.rectangle('fill', knobX, y + 3, 14, 12, 2)

    -- Status text
    love.graphics.setColor(0.55, 0.6, 0.65)
    love.graphics.print(enabled and 'ON' or 'OFF', boxX + boxW + 8, y)
end

local function drawSelector(x, y, label, valueText, hovered)
    love.graphics.setColor(0.8, 0.82, 0.85)
    love.graphics.print(label, x - CONTENT_CTRL_X + CONTENT_LABEL_X, y)

    local selW = SLIDER_W + 40
    local selH = 18
    love.graphics.setColor(hovered and {0.18, 0.22, 0.32} or {0.12, 0.14, 0.2})
    love.graphics.rectangle('fill', x, y, selW, selH, 3)
    love.graphics.setColor(hovered and {0.5, 0.65, 0.85} or {0.3, 0.38, 0.5})
    love.graphics.rectangle('line', x, y, selW, selH, 3)

    -- Arrows
    love.graphics.setColor(0.7, 0.75, 0.85)
    love.graphics.print('<', x + 6, y)
    love.graphics.print('>', x + selW - 14, y)

    -- Value centered
    local font = love.graphics.getFont()
    local tw = font:getWidth(valueText)
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.print(valueText, x + math.floor((selW - tw) / 2), y)
end

local function drawInfoRow(x, y, label, value)
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.print(label, x + CONTENT_LABEL_X, y)
    love.graphics.setColor(0.85, 0.9, 0.95)
    love.graphics.print(value, x + CONTENT_CTRL_X, y)
end

local function drawPlaceholderRow(x, y, label, valueText)
    love.graphics.setColor(0.8, 0.82, 0.85)
    love.graphics.print(label, x + CONTENT_LABEL_X, y)
    love.graphics.setColor(0.45, 0.5, 0.6)
    love.graphics.print(valueText, x + CONTENT_CTRL_X, y)
end

---------------------------------------------------------------------------
-- Per-tab row builders
-- Each builder returns a list of interactive rows and the final y position.
---------------------------------------------------------------------------

local rows = {}  -- rebuilt each draw call

local function buildGeneralRows(cx, cy)
    -- cx = content-area left x, cy = content-area top y
    local y = cy
    local contentW = PANEL_W - CONTENT_X_OFFSET - MARGIN

    rows[#rows + 1] = { type = 'header', y = y, text = 'GENERAL', x = cx, w = contentW }
    y = y + SECTION_GAP + 6

    -- Save folder
    local saveDir = 'frosthold'
    local ok, dir = pcall(love.filesystem.getSaveDirectory)
    if ok and dir then saveDir = dir end
    drawInfoRow = drawInfoRow  -- ensure closure is clean
    rows[#rows + 1] = { type = 'info', y = y, label = 'Save folder', value = saveDir }
    y = y + ROW_H + 2

    -- Version (read from GameState or hardcoded)
    local version = GameState.version or '0.1.0'
    rows[#rows + 1] = { type = 'info', y = y, label = 'Version', value = version }
    y = y + ROW_H + 2

    -- Engine
    local loveVer = table.concat({ love.getVersion() }, '.')
    rows[#rows + 1] = { type = 'info', y = y, label = 'Engine', value = 'Love2D ' .. loveVer }
    y = y + ROW_H + 2

    return y
end

local function buildGraphicsRows(cx, cy)
    local y = cy
    local contentW = PANEL_W - CONTENT_X_OFFSET - MARGIN

    rows[#rows + 1] = { type = 'header', y = y, text = 'GRAPHICS', x = cx, w = contentW }
    y = y + SECTION_GAP + 6

    rows[#rows + 1] = { type = 'selector', key = 'resolutionIdx', label = 'Resolution', y = y }
    y = y + ROW_H + 4

    rows[#rows + 1] = { type = 'toggle', key = 'fullscreen', label = 'Fullscreen', y = y }
    y = y + ROW_H + 4

    rows[#rows + 1] = { type = 'toggle', key = 'vsync', label = 'V-Sync', y = y }
    y = y + ROW_H + 4

    return y
end

local function buildAudioRows(cx, cy)
    local y = cy
    local contentW = PANEL_W - CONTENT_X_OFFSET - MARGIN

    rows[#rows + 1] = { type = 'header', y = y, text = 'AUDIO', x = cx, w = contentW }
    y = y + SECTION_GAP + 6

    local sliders = {
        { key = 'masterVolume',   label = 'Master Volume' },
        { key = 'ambientVolume',  label = 'Ambient' },
        { key = 'uiVolume',       label = 'UI / SFX' },
        { key = 'creatureVolume', label = 'Creature' },
        { key = 'weatherVolume',  label = 'Weather' },
        { key = 'workVolume',     label = 'Work' },
    }
    for _, s in ipairs(sliders) do
        rows[#rows + 1] = { type = 'slider', key = s.key, label = s.label, y = y }
        y = y + ROW_H + 4
    end

    return y
end

local function buildGameplayRows(cx, cy)
    local y = cy
    local contentW = PANEL_W - CONTENT_X_OFFSET - MARGIN

    rows[#rows + 1] = { type = 'header', y = y, text = 'AUTO-PAUSE', x = cx, w = contentW }
    y = y + SECTION_GAP + 6

    local pauseToggles = {
        { key = 'autoPauseOnRaid',        label = 'On Raid' },
        { key = 'autoPauseOnDeath',       label = 'On Death' },
        { key = 'autoPauseOnMentalBreak', label = 'On Mental Break' },
        { key = 'autoPauseOnMeltdown',    label = 'On Meltdown' },
    }
    for _, t in ipairs(pauseToggles) do
        rows[#rows + 1] = { type = 'toggle', key = t.key, label = t.label, y = y }
        y = y + ROW_H + 4
    end

    y = y + SECTION_GAP

    rows[#rows + 1] = { type = 'header', y = y, text = 'DISPLAY', x = cx, w = contentW }
    y = y + SECTION_GAP + 6

    rows[#rows + 1] = { type = 'selector', key = 'colorblindMode', label = 'Colorblind Mode', y = y }
    y = y + ROW_H + 4

    rows[#rows + 1] = { type = 'toggle', key = 'fogOfWar', label = 'Fog of War', y = y }
    y = y + ROW_H + 4

    return y
end

local function buildControlsRows(cx, cy)
    local y = cy
    local contentW = PANEL_W - CONTENT_X_OFFSET - MARGIN

    rows[#rows + 1] = { type = 'header', y = y, text = 'CONTROLS', x = cx, w = contentW }
    y = y + SECTION_GAP + 6

    rows[#rows + 1] = { type = 'toggle', key = 'edgeScroll', label = 'Edge Scroll', y = y }
    y = y + ROW_H + 4

    -- Zoom sensitivity: display-only placeholder (numeric 1-5 selector)
    rows[#rows + 1] = { type = 'selector', key = 'zoomSensitivity', label = 'Zoom Sensitivity', y = y }
    y = y + ROW_H + 4

    y = y + SECTION_GAP

    rows[#rows + 1] = { type = 'header', y = y, text = 'HOTKEYS', x = cx, w = contentW }
    y = y + SECTION_GAP + 6

    rows[#rows + 1] = { type = 'placeholder', y = y, label = 'Move camera', value = 'WASD / Arrow keys' }
    y = y + ROW_H + 2
    rows[#rows + 1] = { type = 'placeholder', y = y, label = 'Select colonist', value = 'Left click' }
    y = y + ROW_H + 2
    rows[#rows + 1] = { type = 'placeholder', y = y, label = 'Draft / Undraft', value = 'R' }
    y = y + ROW_H + 2
    rows[#rows + 1] = { type = 'placeholder', y = y, label = 'Build menu', value = 'B' }
    y = y + ROW_H + 2
    rows[#rows + 1] = { type = 'placeholder', y = y, label = 'Pause / Unpause', value = 'Space' }
    y = y + ROW_H + 2

    return y
end

local function buildDevRows(cx, cy)
    local y = cy
    local contentW = PANEL_W - CONTENT_X_OFFSET - MARGIN

    rows[#rows + 1] = { type = 'header', y = y, text = 'DEV TOOLS', x = cx, w = contentW }
    y = y + SECTION_GAP + 6

    rows[#rows + 1] = { type = 'toggle', key = 'debugOverlay', label = 'Debug Overlay (F4)', y = y }
    y = y + ROW_H + 4

    rows[#rows + 1] = { type = 'toggle', key = 'verboseLogging', label = 'Verbose Logging', y = y }
    y = y + ROW_H + 4

    y = y + SECTION_GAP

    rows[#rows + 1] = { type = 'header', y = y, text = 'BUILD INFO', x = cx, w = contentW }
    y = y + SECTION_GAP + 6

    rows[#rows + 1] = { type = 'info', y = y, label = 'Platform', value = love.system.getOS() }
    y = y + ROW_H + 2

    local jitStatus = type(jit) == 'table' and ('LuaJIT ' .. (jit.version or '?')) or 'Lua 5.1'
    rows[#rows + 1] = { type = 'info', y = y, label = 'Runtime', value = jitStatus }
    y = y + ROW_H + 2

    return y
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function Settings.draw()
    local font = love.graphics.getFont()
    local px = math.floor(screenW / 2 - PANEL_W / 2)
    local py = math.floor(screenH / 2 - PANEL_H / 2)
    local panelH = PANEL_H

    -- Background overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', 0, 0, screenW, screenH)

    -- Panel background
    love.graphics.setColor(0.06, 0.06, 0.09, 0.98)
    love.graphics.rectangle('fill', px, py, PANEL_W, panelH, 6, 6)
    love.graphics.setColor(0.35, 0.4, 0.5, 0.8)
    love.graphics.rectangle('line', px, py, PANEL_W, panelH, 6, 6)

    -- Title bar
    love.graphics.setColor(0.08, 0.08, 0.12, 1)
    love.graphics.rectangle('fill', px, py, PANEL_W, 32, 6, 6)
    love.graphics.rectangle('fill', px, py + 16, PANEL_W, 16)  -- flatten bottom of rounded title bar
    love.graphics.setColor(1, 1, 1)
    local title = 'Settings'
    love.graphics.print(title, px + PANEL_W / 2 - font:getWidth(title) / 2, py + 8)

    -- Divider between title and body
    love.graphics.setColor(0.3, 0.35, 0.45, 0.8)
    love.graphics.line(px + 1, py + 32, px + PANEL_W - 1, py + 32)

    -- Tab column background
    love.graphics.setColor(0.04, 0.04, 0.07, 1)
    love.graphics.rectangle('fill', px + 1, py + 33, TAB_COL_W - 1, panelH - 34)

    -- Divider between tab column and content area
    love.graphics.setColor(0.25, 0.3, 0.4, 0.7)
    love.graphics.line(px + TAB_COL_W, py + 33, px + TAB_COL_W, py + panelH - BACK_BTN_H - 20)

    -- Draw tabs
    local mouseX, mouseY = love.mouse.getPosition()
    local tabY = py + 40
    for _, tab in ipairs(TABS) do
        local isActive = (tab.id == activeTab)
        local tabX = px + 4
        local tabW = TAB_COL_W - 8
        local hov = pointInRect(mouseX, mouseY, tabX, tabY, tabW, TAB_H)

        if isActive then
            love.graphics.setColor(0.12, 0.15, 0.22, 1)
            love.graphics.rectangle('fill', tabX, tabY, tabW, TAB_H, 3)
            -- Gold left accent bar
            love.graphics.setColor(0.85, 0.72, 0.28, 1)
            love.graphics.rectangle('fill', tabX, tabY + 2, 3, TAB_H - 4, 2)
            love.graphics.setColor(0.95, 0.92, 0.7)
        elseif hov then
            love.graphics.setColor(0.09, 0.1, 0.15, 0.9)
            love.graphics.rectangle('fill', tabX, tabY, tabW, TAB_H, 3)
            love.graphics.setColor(0.8, 0.82, 0.85)
        else
            love.graphics.setColor(0.58, 0.62, 0.68)
        end

        love.graphics.print(tab.label, tabX + TAB_PAD_X, tabY + math.floor((TAB_H - 14) / 2))
        tabY = tabY + TAB_H + 2
    end

    -- Store tab rects for hit testing (rebuilt each frame)
    Settings._tabRects = {}
    local ty2 = py + 40
    for _, tab in ipairs(TABS) do
        Settings._tabRects[tab.id] = { x = px + 4, y = ty2, w = TAB_COL_W - 8, h = TAB_H }
        ty2 = ty2 + TAB_H + 2
    end

    -- Content area
    local contentX = px + CONTENT_X_OFFSET
    local contentCtrlX = contentX + CONTENT_CTRL_X
    local contentY = py + 40
    local contentMaxY = py + panelH - BACK_BTN_H - 24

    -- Clip to content area (scissor)
    love.graphics.setScissor(contentX - 4, contentY - 4,
        PANEL_W - CONTENT_X_OFFSET - MARGIN + 8, contentMaxY - contentY + 8)

    -- Build row list for active tab
    rows = {}
    if activeTab == 'general' then
        buildGeneralRows(contentX, contentY)
    elseif activeTab == 'graphics' then
        buildGraphicsRows(contentX, contentY)
    elseif activeTab == 'audio' then
        buildAudioRows(contentX, contentY)
    elseif activeTab == 'gameplay' then
        buildGameplayRows(contentX, contentY)
    elseif activeTab == 'controls' then
        buildControlsRows(contentX, contentY)
    elseif activeTab == 'dev' then
        buildDevRows(contentX, contentY)
    end

    -- Render rows
    for _, row in ipairs(rows) do
        if row.y > contentMaxY then break end  -- clip overflow

        if row.type == 'header' then
            local hw = row.w or (PANEL_W - CONTENT_X_OFFSET - MARGIN)
            drawSectionHeader(row.x or contentX, row.y, row.text, hw)

        elseif row.type == 'slider' then
            local hovered = pointInRect(mouseX, mouseY, contentCtrlX, row.y, SLIDER_W, ROW_H)
            drawSlider(contentCtrlX, row.y, SLIDER_W, state[row.key], row.label, hovered)

        elseif row.type == 'toggle' then
            local hovered = pointInRect(mouseX, mouseY, contentCtrlX, row.y, 80, ROW_H)
            drawToggle(contentCtrlX, row.y, row.label, state[row.key], hovered)

        elseif row.type == 'selector' then
            local valueText
            if row.key == 'resolutionIdx' then
                local res = RESOLUTIONS[state.resolutionIdx] or RESOLUTIONS[3]
                valueText = res.label
            elseif row.key == 'colorblindMode' then
                valueText = CB_MODES[(state.colorblindMode or 0) + 1].label
            elseif row.key == 'zoomSensitivity' then
                valueText = tostring(state.zoomSensitivity or 3) .. ' / 5'
            else
                valueText = tostring(state[row.key] or '?')
            end
            local hovered = pointInRect(mouseX, mouseY, contentCtrlX, row.y, SLIDER_W + 40, ROW_H)
            drawSelector(contentCtrlX, row.y, row.label, valueText, hovered)

        elseif row.type == 'info' then
            drawInfoRow(contentX, row.y, row.label, row.value)

        elseif row.type == 'placeholder' then
            drawPlaceholderRow(contentX, row.y, row.label, row.value)
        end
    end

    love.graphics.setScissor()

    -- Back button
    local backBtnX = math.floor(screenW / 2 - BACK_BTN_W / 2)
    local backBtnY = py + panelH - BACK_BTN_H - 12
    local backHov = pointInRect(mouseX, mouseY, backBtnX, backBtnY, BACK_BTN_W, BACK_BTN_H)

    love.graphics.setColor(backHov and 0.25 or 0.15, backHov and 0.3 or 0.15, backHov and 0.4 or 0.2)
    love.graphics.rectangle('fill', backBtnX, backBtnY, BACK_BTN_W, BACK_BTN_H, 4)
    love.graphics.setColor(0.4, 0.5, 0.6)
    love.graphics.rectangle('line', backBtnX, backBtnY, BACK_BTN_W, BACK_BTN_H, 4)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print('Back', backBtnX + BACK_BTN_W / 2 - font:getWidth('Back') / 2, backBtnY + 7)

    -- Store back button rect for hit testing
    Settings._backBtn = { x = backBtnX, y = backBtnY, w = BACK_BTN_W, h = BACK_BTN_H }
end

---------------------------------------------------------------------------
-- Slider drag handling
---------------------------------------------------------------------------

local function sliderValueFromMouse(mouseX, sliderX, sliderW)
    local rel = (mouseX - sliderX) / sliderW
    return math.max(0, math.min(1, rel))
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function Settings.mousepressed(x, y, button, closeCallback)
    if button ~= 1 then return true end

    -- Back button
    if Settings._backBtn and pointInRect(x, y, Settings._backBtn.x, Settings._backBtn.y,
            Settings._backBtn.w, Settings._backBtn.h) then
        Settings.applyAll()
        Settings.save()
        if closeCallback then closeCallback() end
        return true
    end

    -- Tab click
    if Settings._tabRects then
        for _, tab in ipairs(TABS) do
            local r = Settings._tabRects[tab.id]
            if r and pointInRect(x, y, r.x, r.y, r.w, r.h) then
                activeTab = tab.id
                return true
            end
        end
    end

    -- Compute content-area control x for hit tests
    local px = math.floor(screenW / 2 - PANEL_W / 2)
    local contentX = px + CONTENT_X_OFFSET
    local contentCtrlX = contentX + CONTENT_CTRL_X

    -- Check interactive rows
    for _, row in ipairs(rows) do
        if row.type == 'slider' then
            if pointInRect(x, y, contentCtrlX, row.y, SLIDER_W, ROW_H) then
                state[row.key] = sliderValueFromMouse(x, contentCtrlX, SLIDER_W)
                dragging = { key = row.key, sliderX = contentCtrlX, sliderW = SLIDER_W }
                applyAudio()
                return true
            end

        elseif row.type == 'toggle' then
            if pointInRect(x, y, contentCtrlX, row.y, 80, ROW_H) then
                state[row.key] = not state[row.key]
                if row.key == 'fullscreen' or row.key == 'vsync' then
                    applyDisplay()
                elseif row.key == 'debugOverlay' then
                    applyDev()
                end
                applyAutoPause()
                return true
            end

        elseif row.type == 'selector' then
            local selW = SLIDER_W + 40
            if pointInRect(x, y, contentCtrlX, row.y, selW, ROW_H) then
                if row.key == 'resolutionIdx' then
                    if x < contentCtrlX + 30 then
                        state.resolutionIdx = state.resolutionIdx - 1
                        if state.resolutionIdx < 1 then state.resolutionIdx = #RESOLUTIONS end
                    else
                        state.resolutionIdx = state.resolutionIdx + 1
                        if state.resolutionIdx > #RESOLUTIONS then state.resolutionIdx = 1 end
                    end
                    applyDisplay()
                elseif row.key == 'colorblindMode' then
                    local maxMode = #CB_MODES - 1
                    if x < contentCtrlX + 30 then
                        state.colorblindMode = state.colorblindMode - 1
                        if state.colorblindMode < 0 then state.colorblindMode = maxMode end
                    else
                        state.colorblindMode = state.colorblindMode + 1
                        if state.colorblindMode > maxMode then state.colorblindMode = 0 end
                    end
                elseif row.key == 'zoomSensitivity' then
                    if x < contentCtrlX + 30 then
                        state.zoomSensitivity = math.max(1, (state.zoomSensitivity or 3) - 1)
                    else
                        state.zoomSensitivity = math.min(5, (state.zoomSensitivity or 3) + 1)
                    end
                end
                return true
            end
        end
    end

    return true  -- consume click
end

function Settings.mousemoved(x, y)
    if not dragging then return end
    state[dragging.key] = sliderValueFromMouse(x, dragging.sliderX, dragging.sliderW)
    applyAudio()
end

function Settings.mousereleased(x, y, button)
    if button == 1 and dragging then
        dragging = nil
    end
end

function Settings.keypressed(key, closeCallback)
    if key == 'escape' then
        Settings.applyAll()
        Settings.save()
        if closeCallback then closeCallback() end
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Colorblind mode rendering helpers
---------------------------------------------------------------------------

--- Call before drawing the frame to redirect to a canvas (if colorblind mode is active).
function Settings.beginColorblindPass()
    if (state.colorblindMode or 0) == 0 then return end
    if not cbShader then
        local ok, shader = pcall(love.graphics.newShader, CB_SHADER_CODE)
        if not ok then return end
        cbShader = shader
    end
    local sw, sh = love.graphics.getDimensions()
    if not cbCanvas or cbCanvas:getWidth() ~= sw or cbCanvas:getHeight() ~= sh then
        cbCanvas = love.graphics.newCanvas(sw, sh)
    end
    love.graphics.setCanvas(cbCanvas)
    love.graphics.clear(0, 0, 0, 1)
end

--- Call after drawing the frame to apply the colorblind shader and present.
function Settings.endColorblindPass()
    if (state.colorblindMode or 0) == 0 then return end
    if not cbShader or not cbCanvas then return end
    love.graphics.setCanvas()
    cbShader:send('mode', state.colorblindMode)
    love.graphics.setShader(cbShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cbCanvas, 0, 0)
    love.graphics.setShader()
end

--- Returns current colorblind mode index (0=off).
function Settings.getColorblindMode()
    return state.colorblindMode or 0
end

return Settings
