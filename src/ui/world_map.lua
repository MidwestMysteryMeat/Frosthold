-- world_map.lua — Hex-based world map / landing zone selection screen
-- Player picks a hex on the planet surface to determine landing zone.
-- Selected hex influences map generation (biome, resources, threat).

local GameState = require('src.game_state')
local HexGrid   = require('src.world.hex_grid')

local WorldMap = {}

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local HEX_SIZE    = 38   -- hex radius in pixels
local INFO_W      = 220  -- right-side info panel width
local BUTTON_W    = 220
local BUTTON_H    = 44
local BACK_W      = 100
local BACK_H      = 32

-- Fonts
local titleFont
local headerFont
local bodyFont
local smallFont

-- State
local hexGridData  = nil   -- generated hex grid
local selectedQ    = 0
local selectedR    = 0
local hoveredQ     = nil
local hoveredR     = nil
local gridCenterX  = 0     -- pixel offset for grid center on screen
local gridCenterY  = 0

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function WorldMap.init()
    titleFont  = love.graphics.newFont(28)
    headerFont = love.graphics.newFont(14)
    bodyFont   = love.graphics.newFont(11)
    smallFont  = love.graphics.newFont(9)
end

--- Regenerate hex grid for current planet. Called when entering world_map phase.
function WorldMap.generateForPlanet(planetId)
    local seed = love.math.random(1, 999999)
    hexGridData = HexGrid.generate(planetId or 'erebus', seed)
    selectedQ = 0
    selectedR = 0
    hoveredQ = nil
    hoveredR = nil
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function getLayout()
    local sw, sh = love.graphics.getDimensions()
    gridCenterX = math.floor((sw - INFO_W) / 2)
    gridCenterY = math.floor(sh / 2) - 10
    return {
        sw = sw, sh = sh,
        infoX = sw - INFO_W - 20,
        infoY = 80,
        btnX = math.floor((sw - BUTTON_W) / 2),
        btnY = sh - BUTTON_H - 30,
        backX = 20,
        backY = sh - BACK_H - 30,
    }
end

local function getHexScreenPos(q, r)
    local px, py = HexGrid.hexToPixel(q, r, HEX_SIZE)
    return gridCenterX + px, gridCenterY + py
end

local function getHexAtMouse(mx, my)
    local lx = mx - gridCenterX
    local ly = my - gridCenterY
    local q, r = HexGrid.pixelToHex(lx, ly, HEX_SIZE)
    local key = HexGrid.hexKey(q, r)
    if hexGridData and hexGridData.hexes[key] then
        return q, r
    end
    return nil, nil
end

---------------------------------------------------------------------------
-- Resource/threat display helpers
---------------------------------------------------------------------------

local RESOURCE_COLORS = {
    sparse = {0.6, 0.5, 0.4},
    normal = {0.7, 0.75, 0.8},
    rich   = {0.4, 0.8, 0.4},
}

local THREAT_COLORS = {
    low     = {0.4, 0.7, 0.4},
    medium  = {0.8, 0.75, 0.3},
    high    = {0.9, 0.5, 0.2},
    extreme = {0.9, 0.2, 0.2},
}

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function WorldMap.draw()
    if not hexGridData then return end

    local L = getLayout()
    local mx, my = love.mouse.getPosition()

    -- Background
    love.graphics.clear(0.03, 0.04, 0.08)
    love.graphics.setColor(0.05, 0.07, 0.12, 0.5)
    love.graphics.rectangle('fill', 0, 0, L.sw, L.sh)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.7, 0.85, 1.0)
    local pok, PlanetDefs = pcall(require, 'src.world.planet_defs')
    local planetName = 'Unknown'
    if pok then
        local pdef = PlanetDefs.get(GameState.planet or 'erebus')
        if pdef then planetName = pdef.name end
    end
    local title = planetName
    local tw = titleFont:getWidth(title)
    love.graphics.print(title, math.floor((L.sw - INFO_W) / 2 - tw / 2), 14)

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.4, 0.5, 0.6)
    local sub = 'SELECT LANDING ZONE'
    local stw = bodyFont:getWidth(sub)
    love.graphics.print(sub, math.floor((L.sw - INFO_W) / 2 - stw / 2), 48)

    -- Update hover
    hoveredQ, hoveredR = getHexAtMouse(mx, my)

    -- Draw hexes
    for key, hex in pairs(hexGridData.hexes) do
        local cx, cy = getHexScreenPos(hex.q, hex.r)
        local corners = HexGrid.hexCorners(cx, cy, HEX_SIZE - 2)

        local isSelected = (hex.q == selectedQ and hex.r == selectedR)
        local isHovered = (hoveredQ == hex.q and hoveredR == hex.r)

        -- Fill color from biome
        local bc = hex.biomeColor or {0.5, 0.5, 0.5}
        local alpha = 0.7
        if isSelected then alpha = 0.95
        elseif isHovered then alpha = 0.85 end
        love.graphics.setColor(bc[1], bc[2], bc[3], alpha)

        -- Draw filled hex polygon
        love.graphics.polygon('fill', corners)

        -- Border
        if isSelected then
            love.graphics.setColor(1, 0.9, 0.3, 1)
            love.graphics.setLineWidth(3)
        elseif isHovered then
            love.graphics.setColor(0.8, 0.85, 0.9, 0.8)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.2, 0.25, 0.35, 0.6)
            love.graphics.setLineWidth(1)
        end
        love.graphics.polygon('line', corners)
        love.graphics.setLineWidth(1)

        -- Biome label (first letter)
        love.graphics.setFont(smallFont)
        local label = (hex.biomeName or '?'):sub(1, 1)
        love.graphics.setColor(1, 1, 1, 0.6)
        local lw = smallFont:getWidth(label)
        love.graphics.print(label, cx - lw / 2, cy - smallFont:getHeight() / 2)

        -- Resource indicator dot
        local rc = RESOURCE_COLORS[hex.resources] or {0.5, 0.5, 0.5}
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.9)
        love.graphics.circle('fill', cx, cy + HEX_SIZE * 0.45, 3)

        -- Threat indicator (small triangle for high/extreme)
        if hex.threat == 'high' or hex.threat == 'extreme' then
            local tc = THREAT_COLORS[hex.threat]
            love.graphics.setColor(tc[1], tc[2], tc[3], 0.8)
            local tx = cx
            local ty = cy - HEX_SIZE * 0.45
            love.graphics.polygon('fill', tx, ty - 4, tx - 3, ty + 2, tx + 3, ty + 2)
        end
    end

    -- Info panel (right side)
    local infoHex = nil
    if hoveredQ then
        infoHex = hexGridData.hexes[HexGrid.hexKey(hoveredQ, hoveredR)]
    end
    if not infoHex then
        infoHex = hexGridData.hexes[HexGrid.hexKey(selectedQ, selectedR)]
    end

    love.graphics.setColor(0.06, 0.08, 0.12, 0.9)
    love.graphics.rectangle('fill', L.infoX, L.infoY, INFO_W, 200, 6)
    love.graphics.setColor(0.2, 0.25, 0.35, 0.6)
    love.graphics.rectangle('line', L.infoX, L.infoY, INFO_W, 200, 6)

    if infoHex then
        local iy = L.infoY + 10
        local ix = L.infoX + 12

        -- Biome name
        love.graphics.setFont(headerFont)
        local bc2 = infoHex.biomeColor or {0.7, 0.7, 0.7}
        love.graphics.setColor(bc2[1], bc2[2], bc2[3])
        love.graphics.print(infoHex.biomeName or 'Unknown', ix, iy)
        iy = iy + 22

        love.graphics.setFont(bodyFont)

        -- Temperature
        love.graphics.setColor(0.6, 0.7, 0.8)
        local tempStr = string.format('Temperature: %+d C', infoHex.tempMod)
        love.graphics.print(tempStr, ix, iy)
        iy = iy + 18

        -- Elevation
        love.graphics.setColor(0.6, 0.7, 0.8)
        local elevStr = string.format('Elevation: %.0f%%', infoHex.elevation * 100)
        love.graphics.print(elevStr, ix, iy)
        iy = iy + 18

        -- Resources
        local rc2 = RESOURCE_COLORS[infoHex.resources] or {0.7, 0.7, 0.7}
        love.graphics.setColor(rc2[1], rc2[2], rc2[3])
        love.graphics.print('Resources: ' .. (infoHex.resources or 'normal'), ix, iy)
        iy = iy + 18

        -- Threat
        local tc2 = THREAT_COLORS[infoHex.threat] or {0.7, 0.7, 0.7}
        love.graphics.setColor(tc2[1], tc2[2], tc2[3])
        love.graphics.print('Threat: ' .. (infoHex.threat or 'medium'), ix, iy)
        iy = iy + 18

        -- Coordinates
        love.graphics.setColor(0.4, 0.45, 0.55)
        love.graphics.setFont(smallFont)
        love.graphics.print(string.format('Sector (%d, %d)', infoHex.q, infoHex.r), ix, iy)
    else
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.4, 0.45, 0.55)
        love.graphics.print('Hover a hex for details', L.infoX + 12, L.infoY + 10)
    end

    -- Legend (below info panel)
    local legY = L.infoY + 210
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.5, 0.55, 0.65)
    love.graphics.print('RESOURCES', L.infoX + 12, legY)
    legY = legY + 14
    for _, rk in ipairs({'sparse', 'normal', 'rich'}) do
        local c = RESOURCE_COLORS[rk]
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.circle('fill', L.infoX + 18, legY + 5, 4)
        love.graphics.setColor(0.6, 0.65, 0.7)
        love.graphics.print(rk, L.infoX + 28, legY)
        legY = legY + 13
    end
    legY = legY + 6
    love.graphics.setColor(0.5, 0.55, 0.65)
    love.graphics.print('THREAT', L.infoX + 12, legY)
    legY = legY + 14
    for _, tk in ipairs({'low', 'medium', 'high', 'extreme'}) do
        local c = THREAT_COLORS[tk]
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.rectangle('fill', L.infoX + 14, legY + 1, 8, 8, 1)
        love.graphics.setColor(0.6, 0.65, 0.7)
        love.graphics.print(tk, L.infoX + 28, legY)
        legY = legY + 13
    end

    -- Confirm button
    local btnHov = pointInRect(mx, my, L.btnX, L.btnY, BUTTON_W, BUTTON_H)
    if btnHov then
        love.graphics.setColor(0.2, 0.4, 0.7, 0.95)
    else
        love.graphics.setColor(0.12, 0.25, 0.5, 0.9)
    end
    love.graphics.rectangle('fill', L.btnX, L.btnY, BUTTON_W, BUTTON_H, 6)
    love.graphics.setColor(0.4, 0.6, 0.9)
    love.graphics.rectangle('line', L.btnX, L.btnY, BUTTON_W, BUTTON_H, 6)
    love.graphics.setFont(headerFont)
    love.graphics.setColor(1, 1, 1)
    local btnText = 'CONFIRM LANDING ZONE'
    local btw = headerFont:getWidth(btnText)
    love.graphics.print(btnText,
        L.btnX + math.floor((BUTTON_W - btw) / 2),
        L.btnY + math.floor((BUTTON_H - headerFont:getHeight()) / 2))

    -- Back button
    local backHov = pointInRect(mx, my, L.backX, L.backY, BACK_W, BACK_H)
    love.graphics.setColor(backHov and {0.18, 0.18, 0.25, 0.9} or {0.1, 0.1, 0.15, 0.8})
    love.graphics.rectangle('fill', L.backX, L.backY, BACK_W, BACK_H, 4)
    love.graphics.setColor(0.35, 0.4, 0.5)
    love.graphics.rectangle('line', L.backX, L.backY, BACK_W, BACK_H, 4)
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.7, 0.75, 0.8)
    local backText = 'BACK'
    local bkw = bodyFont:getWidth(backText)
    love.graphics.print(backText,
        L.backX + math.floor((BACK_W - bkw) / 2),
        L.backY + math.floor((BACK_H - bodyFont:getHeight()) / 2))

    -- Hint
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.35, 0.4, 0.5)
    local hint = 'Click hex to select  /  Enter to confirm  /  Escape to go back'
    local hw = smallFont:getWidth(hint)
    love.graphics.print(hint, math.floor((L.sw - hw) / 2), L.btnY + BUTTON_H + 8)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function WorldMap.mousepressed(x, y, button)
    if button ~= 1 then return end
    if not hexGridData then return end

    local L = getLayout()

    -- Check hex click
    local q, r = getHexAtMouse(x, y)
    if q then
        selectedQ = q
        selectedR = r
        return
    end

    -- Confirm button
    if pointInRect(x, y, L.btnX, L.btnY, BUTTON_W, BUTTON_H) then
        WorldMap.confirm()
        return
    end

    -- Back button
    if pointInRect(x, y, L.backX, L.backY, BACK_W, BACK_H) then
        GameState.phase = 'requisition_picks'
        return
    end
end

function WorldMap.keypressed(key)
    if key == 'return' or key == 'kpenter' then
        WorldMap.confirm()
    elseif key == 'escape' then
        GameState.phase = 'requisition_picks'
    end
end

---------------------------------------------------------------------------
-- Confirm — store landing zone and advance to setup
---------------------------------------------------------------------------

function WorldMap.confirm()
    if not hexGridData then return end

    local key = HexGrid.hexKey(selectedQ, selectedR)
    local hex = hexGridData.hexes[key]
    if not hex then return end

    -- Store landing zone on GameState
    GameState.landingZone = {
        q = hex.q,
        r = hex.r,
        biome = hex.biome,
        biomeName = hex.biomeName,
        tempMod = hex.tempMod,
        resources = hex.resources,
        threat = hex.threat,
        elevation = hex.elevation,
        planetId = hexGridData.planetId,
        seed = hexGridData.seed,
    }

    -- Apply difficulty settings for this planet
    -- Since we skip the separate scenario/difficulty screens in the planet flow,
    -- configure defaults here. Planet determines the baseline difficulty.
    local dok, Difficulty = pcall(require, 'src.ui.difficulty')
    if dok then
        local planetId = GameState.planet or 'erebus'
        local pdok, PlanetDefs = pcall(require, 'src.world.planet_defs')
        local planetDef = pdok and PlanetDefs.get(planetId)

        -- Use first scenario for the planet as default
        local scenarios = planetDef and planetDef.scenarios
        local defaultScenario = scenarios and scenarios[1] or 'crashlanded'
        GameState.scenario = defaultScenario

        -- Apply default difficulty (normal preset) with planet scenario
        Difficulty.configure({
            preset = 'normal',
            scenario = defaultScenario,
            storyteller = 'chronicler',
            safetyNet = true,
        })
    end

    -- Apply landing zone seed to world generation
    if GameState.landingZone and GameState.landingZone.seed then
        GameState.worldSeedNumeric = GameState.landingZone.seed
    end
    GameState.landingSiteSelected = true

    -- Advance to world generation (drafting already happened before world_map)
    GameState.phase = 'starting'
end

return WorldMap
