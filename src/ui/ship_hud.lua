-- ship_hud.lua — Compact ship status overlay for space map
-- Bottom-left HUD showing fuel, hull, velocity, heading, stealth, credits, docking.

local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')

local ShipHUD = {}

-- Lazy-loaded dependencies (pcall for safety)
local _ShipDefs, _Stealth, _Docking
local _modsLoaded = false

local function lazyLoadMods()
    if _modsLoaded then return end
    _modsLoaded = true
    local ok
    ok, _ShipDefs = pcall(require, 'src.space.ship_defs')
    if not ok then _ShipDefs = false end
    ok, _Stealth = pcall(require, 'src.space.stealth')
    if not ok then _Stealth = false end
    ok, _Docking = pcall(require, 'src.space.station_docking')
    if not ok then _Docking = false end
end

-- Fonts (created lazily to avoid issues before love.load)
local fontMain, fontSmall
local function getFonts()
    if not fontMain then
        fontMain  = love.graphics.newFont(13)
        fontSmall = love.graphics.newFont(10)
    end
    return fontMain, fontSmall
end

-- Layout constants
local PANEL_MARGIN = 10
local PANEL_PAD    = 8
local PANEL_W      = 200
local BAR_H        = 10
local BAR_W        = 130
local LINE_H       = 20
local CORNER_R     = 4

-- 8-direction compass from heading degrees
local COMPASS_DIRS = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }

local function headingToCompass(heading)
    if not heading then return 'N' end
    local deg = heading % 360
    local idx = math.floor((deg + 22.5) / 45) % 8
    return COMPASS_DIRS[idx + 1]
end

-- Draw a horizontal bar with background track and colored fill
local function drawBar(x, y, w, h, fraction, fgR, fgG, fgB)
    love.graphics.setColor(0.12, 0.12, 0.15, 1)
    love.graphics.rectangle('fill', x, y, w, h, 2)
    local fill = math.max(0, math.min(1, fraction))
    if fill > 0 then
        love.graphics.setColor(fgR, fgG, fgB, 1)
        love.graphics.rectangle('fill', x, y, w * fill, h, 2)
    end
end

-- Draw colored text at position
local function drawLabel(text, x, y, font, r, g, b)
    love.graphics.setFont(font)
    love.graphics.setColor(r or 0.85, g or 0.87, b or 0.9, 1)
    love.graphics.print(text, x, y)
end

-- Find the player's ship component (excludes NPC ships)
local function getPlayerShip()
    for id, comps in ECS.query('ship', 'pos') do
        if not ECS.has(id, 'npc_ship') then return comps.ship end
    end
    for id, comps in ECS.query('ship') do
        if not ECS.has(id, 'npc_ship') then return comps.ship end
    end
    return nil
end

---------------------------------------------------------------------------
-- Main draw — only renders when activeMap == 'space'
---------------------------------------------------------------------------

function ShipHUD.draw()
    if GameState.activeMap ~= 'space' then return end

    lazyLoadMods()
    local fMain, fSmall = getFonts()

    local ship = getPlayerShip()
    if not ship then return end

    -- Read ship data
    local fuel     = ship.fuel or 0
    local hullHP   = ship.hullHP or 0
    local velocity = ship.velocity or 0
    local heading  = ship.heading or 0
    local tier     = ship.tier or 'scout'

    local maxFuel = 100
    if _ShipDefs and _ShipDefs.getTier then
        local tierDef = _ShipDefs.getTier(tier)
        if tierDef then maxFuel = tierDef.fuelCapacity or 100 end
    end

    local fuelPct = maxFuel > 0 and (fuel / maxFuel) or 0
    local hullPct = hullHP / 100

    local stealthActive = _Stealth and _Stealth.isStealthActive and _Stealth.isStealthActive()
    local signature     = _Stealth and _Stealth.getSignature and _Stealth.getSignature() or 0
    local isDocked      = _Docking and _Docking.isDocked and _Docking.isDocked()
    local dockedStation = isDocked and _Docking.getDockedStation and _Docking.getDockedStation()

    -- Dynamic panel height
    local lines = 5  -- fuel, hull, velocity, heading, credits
    if stealthActive then lines = lines + 1 end
    if isDocked then lines = lines + 1 end
    local panelH = PANEL_PAD * 2 + lines * LINE_H + 4

    local screenH = love.graphics.getHeight()
    local px = PANEL_MARGIN
    local py = screenH - panelH - PANEL_MARGIN

    love.graphics.push()
    love.graphics.origin()

    -- Panel background
    love.graphics.setColor(0.03, 0.04, 0.07, 0.85)
    love.graphics.rectangle('fill', px, py, PANEL_W, panelH, CORNER_R)
    love.graphics.setColor(0.2, 0.25, 0.35, 0.6)
    love.graphics.rectangle('line', px, py, PANEL_W, panelH, CORNER_R)

    local cx = px + PANEL_PAD
    local cy = py + PANEL_PAD
    local labelEnd = cx + PANEL_W - PANEL_PAD * 2

    -- Fuel gauge
    local fuelStr = string.format('%d%%', math.floor(fuelPct * 100))
    drawLabel('FUEL', cx, cy, fSmall, 0.5, 0.7, 0.9)
    drawLabel(fuelStr, labelEnd - fSmall:getWidth(fuelStr), cy, fSmall, 0.5, 0.7, 0.9)
    local fR, fG, fB = 0.3, 0.7, 0.9
    if fuelPct < 0.25 then fR, fG, fB = 0.9, 0.3, 0.2 end
    drawBar(cx, cy + 12, BAR_W, BAR_H, fuelPct, fR, fG, fB)
    cy = cy + LINE_H

    -- Hull HP
    local hullStr = string.format('%d%%', math.floor(hullPct * 100))
    drawLabel('HULL', cx, cy, fSmall, 0.5, 0.9, 0.5)
    drawLabel(hullStr, labelEnd - fSmall:getWidth(hullStr), cy, fSmall, 0.5, 0.9, 0.5)
    local hR, hG, hB = 0.3, 0.85, 0.4
    if hullPct < 0.3 then hR, hG, hB = 0.9, 0.3, 0.2 end
    drawBar(cx, cy + 12, BAR_W, BAR_H, hullPct, hR, hG, hB)
    cy = cy + LINE_H

    -- Velocity
    drawLabel('VEL  ' .. string.format('%.1f', velocity), cx, cy, fMain, 0.85, 0.87, 0.9)
    cy = cy + LINE_H

    -- Heading compass
    local compass = headingToCompass(heading)
    drawLabel('HDG  ' .. string.format('%s (%d)', compass, math.floor(heading % 360)),
              cx, cy, fMain, 0.85, 0.87, 0.9)
    cy = cy + LINE_H

    -- Stealth status (conditional)
    if stealthActive then
        drawLabel('STEALTH ON', cx, cy, fMain, 0.4, 0.9, 0.95)
        drawLabel(string.format('SIG %d', signature), cx + 90, cy, fSmall, 0.4, 0.75, 0.8)
        cy = cy + LINE_H
    end

    -- Credits
    drawLabel(string.format('%d CR', GameState.credits or 0), cx, cy, fMain, 0.9, 0.85, 0.5)
    cy = cy + LINE_H

    -- Docked station (conditional)
    if isDocked and dockedStation then
        drawLabel('DOCKED: ' .. (dockedStation.name or 'Unknown Station'), cx, cy, fSmall, 0.7, 0.9, 0.7)
    end

    love.graphics.pop()
end

return ShipHUD
