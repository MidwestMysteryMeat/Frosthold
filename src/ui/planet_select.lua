-- planet_select.lua — Planet selection screen
-- Horizontal card layout showing all 7 planets. Each card: name, subtitle,
-- colored illustration area, 2-line desc, difficulty badge.
-- Clicking a planet stores it and transitions to the configure phase.

local GameState  = require('src.game_state')
local PlanetDefs = require('src.world.planet_defs')

local PlanetHistory = require('src.ui.planet_history')

local PlanetSelect = {}

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local CARD_W       = 150
local CARD_H       = 260
local CARD_GAP     = 12
local CARD_RADIUS  = 8
local HEADER_Y     = 20
local ILLUST_H     = 80   -- colored illustration area height
local BADGE_H      = 18

-- Fonts (created on init)
local titleFont
local headerFont
local bodyFont
local smallFont

-- State
local selectedPlanet = 'erebus'
local hoveredPlanet  = nil

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function PlanetSelect.init()
    titleFont  = love.graphics.newFont(28)
    headerFont = love.graphics.newFont(14)
    bodyFont   = love.graphics.newFont(11)
    smallFont  = love.graphics.newFont(9)
    selectedPlanet = GameState.planet or 'erebus'
    -- Pre-select the failed planet when redeploying after a run ends
    if GameState._redeployment and GameState.planet then
        selectedPlanet = GameState.planet
    end
end

---------------------------------------------------------------------------
-- Hit testing
---------------------------------------------------------------------------

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

---------------------------------------------------------------------------
-- Compute layout
---------------------------------------------------------------------------

local function getLayout()
    local sw, sh = love.graphics.getDimensions()
    local count = #PlanetDefs.PLANET_ORDER
    local totalW = count * CARD_W + (count - 1) * CARD_GAP
    local baseX = math.floor((sw - totalW) / 2)
    local baseY = math.floor((sh - CARD_H) / 2) - 10

    return {
        sw = sw, sh = sh,
        baseX = baseX,
        baseY = baseY,
        totalW = totalW,
    }
end

---------------------------------------------------------------------------
-- Draw a single planet card
---------------------------------------------------------------------------

local function drawCard(x, y, def, isSelected, isHovered)
    local locked = def.locked

    -- Card background
    if isSelected then
        love.graphics.setColor(0.12, 0.2, 0.35, 0.95)
    elseif isHovered and not locked then
        love.graphics.setColor(0.1, 0.14, 0.24, 0.9)
    else
        love.graphics.setColor(0.06, 0.08, 0.14, 0.85)
    end
    love.graphics.rectangle('fill', x, y, CARD_W, CARD_H, CARD_RADIUS)

    -- Border
    if isSelected then
        love.graphics.setColor(def.color[1], def.color[2], def.color[3], 1.0)
    elseif isHovered and not locked then
        love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.6)
    else
        love.graphics.setColor(0.25, 0.3, 0.4, 0.5)
    end
    love.graphics.rectangle('line', x, y, CARD_W, CARD_H, CARD_RADIUS)

    -- Illustration area (colored rectangle with planet color)
    local illX = x + 8
    local illY = y + 8
    local illW = CARD_W - 16
    local alpha = locked and 0.25 or 0.5
    love.graphics.setColor(def.color[1], def.color[2], def.color[3], alpha)
    love.graphics.rectangle('fill', illX, illY, illW, ILLUST_H, 4)

    -- Planet initial (large letter in illustration area)
    love.graphics.setFont(titleFont)
    local initial = def.name:sub(1, 1)
    local iw = titleFont:getWidth(initial)
    local ih = titleFont:getHeight()
    love.graphics.setColor(1, 1, 1, locked and 0.3 or 0.7)
    love.graphics.print(initial, illX + math.floor((illW - iw) / 2), illY + math.floor((ILLUST_H - ih) / 2))

    -- Difficulty badge
    local badgeY = illY + ILLUST_H + 6
    local badgeColor = {0.3, 0.35, 0.45, 0.7}
    if def.difficultyLabel == 'Standard' then badgeColor = {0.2, 0.4, 0.3, 0.7}
    elseif def.difficultyLabel == 'Hard' then badgeColor = {0.5, 0.35, 0.15, 0.7}
    elseif def.difficultyLabel == 'Very Hard' then badgeColor = {0.55, 0.2, 0.15, 0.7}
    elseif def.difficultyLabel == 'Extreme' then badgeColor = {0.6, 0.1, 0.1, 0.7}
    elseif def.difficultyLabel == 'Medium' then badgeColor = {0.35, 0.35, 0.2, 0.7}
    elseif def.difficultyLabel == 'Narrative' then badgeColor = {0.2, 0.35, 0.45, 0.7}
    end
    love.graphics.setColor(badgeColor)
    love.graphics.rectangle('fill', illX, badgeY, illW, BADGE_H, 3)
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.9, 0.9, 0.9, locked and 0.4 or 0.9)
    local bl = def.difficultyLabel
    local bw = smallFont:getWidth(bl)
    love.graphics.print(bl, illX + math.floor((illW - bw) / 2), badgeY + 3)

    -- Planet name
    local nameY = badgeY + BADGE_H + 8
    love.graphics.setFont(headerFont)
    love.graphics.setColor(1, 1, 1, locked and 0.4 or 1.0)
    local nw = headerFont:getWidth(def.name)
    love.graphics.print(def.name, x + math.floor((CARD_W - nw) / 2), nameY)

    -- Subtitle
    local subY = nameY + headerFont:getHeight() + 2
    love.graphics.setFont(smallFont)
    love.graphics.setColor(def.color[1], def.color[2], def.color[3], locked and 0.3 or 0.7)
    local sw2 = smallFont:getWidth(def.subtitle)
    love.graphics.print(def.subtitle, x + math.floor((CARD_W - sw2) / 2), subY)

    -- Description (2 lines)
    local descY = subY + smallFont:getHeight() + 6
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.55, 0.6, 0.7, locked and 0.3 or 0.8)
    love.graphics.printf(def.desc, x + 8, descY, CARD_W - 16, 'center')

    -- Deployment badge and scar overlay
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if mok then
        local deployCount = MRP.getDeploymentCount(def.id)
        if deployCount > 0 then
            -- Scar overlay: progressively darker/redder with more deployments
            local scarAlpha = math.min(deployCount * 0.08, 0.4)
            love.graphics.setColor(0.6, 0.1, 0.1, scarAlpha)
            love.graphics.rectangle('fill', x, y, CARD_W, CARD_H, CARD_RADIUS)

            -- Deployment badge
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.9, 0.7, 0.2, 0.9)
            love.graphics.print('Deployment ' .. (deployCount + 1), x + 4, y + CARD_H - 18)
        end
    end

    -- "Coming Soon" overlay for locked planets
    if locked then
        love.graphics.setColor(0.04, 0.06, 0.1, 0.6)
        love.graphics.rectangle('fill', x, y, CARD_W, CARD_H, CARD_RADIUS)
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.6, 0.65, 0.75, 0.8)
        local cs = 'Coming Soon'
        local csw = bodyFont:getWidth(cs)
        love.graphics.print(cs, x + math.floor((CARD_W - csw) / 2), y + math.floor(CARD_H / 2) - 6)
    end
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function PlanetSelect.draw()
    local L = getLayout()

    -- Background
    love.graphics.clear(0.03, 0.04, 0.08)
    love.graphics.setColor(0.05, 0.07, 0.12, 0.5)
    love.graphics.rectangle('fill', 0, 0, L.sw, L.sh)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.7, 0.85, 1.0)
    local title = 'FROSTHOLD'
    local tw = titleFont:getWidth(title)
    love.graphics.print(title, math.floor((L.sw - tw) / 2), HEADER_Y)

    -- Subtitle
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.4, 0.5, 0.6)
    local sub = 'Choose Your World'
    local stw = bodyFont:getWidth(sub)
    love.graphics.print(sub, math.floor((L.sw - stw) / 2), HEADER_Y + titleFont:getHeight() + 4)

    -- Planet cards
    local mx, my = love.mouse.getPosition()
    hoveredPlanet = nil

    for i, planetId in ipairs(PlanetDefs.PLANET_ORDER) do
        local def = PlanetDefs.get(planetId)
        local cx = L.baseX + (i - 1) * (CARD_W + CARD_GAP)
        local cy = L.baseY
        local isSel = (selectedPlanet == planetId)
        local isHov = pointInRect(mx, my, cx, cy, CARD_W, CARD_H)
        if isHov then hoveredPlanet = planetId end
        drawCard(cx, cy, def, isSel, isHov)
    end

    -- Selected planet expanded description at bottom
    local selDef = PlanetDefs.get(selectedPlanet)
    if selDef then
        local descY = L.baseY + CARD_H + 20
        love.graphics.setFont(headerFont)
        love.graphics.setColor(selDef.color[1], selDef.color[2], selDef.color[3])
        local sn = selDef.name .. '  —  ' .. selDef.subtitle
        local snw = headerFont:getWidth(sn)
        love.graphics.print(sn, math.floor((L.sw - snw) / 2), descY)

        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.6, 0.65, 0.75)
        love.graphics.printf(selDef.desc, math.floor(L.sw / 2 - 300), descY + 22, 600, 'center')
    end

    -- Continue button
    local btnW = 220
    local btnH = 44
    local btnX = math.floor((L.sw - btnW) / 2)
    local btnY = L.sh - btnH - 30
    local btnHov = pointInRect(mx, my, btnX, btnY, btnW, btnH)

    local canProceed = not (PlanetDefs.get(selectedPlanet) or {}).locked
    if canProceed then
        if btnHov then
            love.graphics.setColor(0.2, 0.4, 0.7, 0.95)
        else
            love.graphics.setColor(0.12, 0.25, 0.5, 0.9)
        end
    else
        love.graphics.setColor(0.15, 0.15, 0.2, 0.6)
    end
    love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 6)
    love.graphics.setColor(canProceed and {0.4, 0.6, 0.9} or {0.25, 0.25, 0.35})
    love.graphics.rectangle('line', btnX, btnY, btnW, btnH, 6)

    love.graphics.setFont(headerFont)
    love.graphics.setColor(canProceed and {1, 1, 1} or {0.4, 0.4, 0.5})
    local btnText = 'CONFIGURE DEPLOYMENT'
    local btw = headerFont:getWidth(btnText)
    love.graphics.print(btnText,
        btnX + math.floor((btnW - btw) / 2),
        btnY + math.floor((btnH - headerFont:getHeight()) / 2))

    -- Keyboard hint
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.35, 0.4, 0.5)
    local hint = 'Arrow keys to browse  /  Enter to confirm'
    local hw = smallFont:getWidth(hint)
    love.graphics.print(hint, math.floor((L.sw - hw) / 2), btnY + btnH + 8)

    -- Deployment history hint (only when selected planet has past runs)
    local hmok, HMRP = pcall(require, 'src.sim.mrp')
    if hmok then
        local hdepCount = HMRP.getDeploymentCount(selectedPlanet)
        if hdepCount > 0 then
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.75, 0.6, 0.2, 0.85)
            local hhint = '[H] Deployment History'
            local hhw = smallFont:getWidth(hhint)
            love.graphics.print(hhint, math.floor((L.sw - hhw) / 2), btnY + btnH + 22)
        end
    end

    -- History panel drawn on top
    PlanetHistory.draw()
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function PlanetSelect.mousepressed(x, y, button)
    if button ~= 1 then return end

    local L = getLayout()

    -- Check card clicks
    for i, planetId in ipairs(PlanetDefs.PLANET_ORDER) do
        local cx = L.baseX + (i - 1) * (CARD_W + CARD_GAP)
        local cy = L.baseY
        if pointInRect(x, y, cx, cy, CARD_W, CARD_H) then
            local def = PlanetDefs.get(planetId)
            if not def.locked then
                selectedPlanet = planetId
            end
            return
        end
    end

    -- Check continue button
    local btnW = 220
    local btnH = 44
    local btnX = math.floor((L.sw - btnW) / 2)
    local btnY = L.sh - btnH - 30
    if pointInRect(x, y, btnX, btnY, btnW, btnH) then
        PlanetSelect.confirm()
        return
    end
end

function PlanetSelect.keypressed(key)
    -- Route through history panel first — it consumes input when visible
    if PlanetHistory.keypressed(key) then return end

    if key == 'h' then
        local mok, MRP = pcall(require, 'src.sim.mrp')
        if mok and MRP.getDeploymentCount(selectedPlanet) > 0 then
            PlanetHistory.show(selectedPlanet)
        end
        return
    end

    if key == 'left' then
        local order = PlanetDefs.PLANET_ORDER
        for i, pid in ipairs(order) do
            if pid == selectedPlanet then
                for j = i - 1, 1, -1 do
                    local def = PlanetDefs.get(order[j])
                    if not def.locked then
                        selectedPlanet = order[j]
                        return
                    end
                end
                return
            end
        end
    elseif key == 'right' then
        local order = PlanetDefs.PLANET_ORDER
        for i, pid in ipairs(order) do
            if pid == selectedPlanet then
                for j = i + 1, #order do
                    local def = PlanetDefs.get(order[j])
                    if not def.locked then
                        selectedPlanet = order[j]
                        return
                    end
                end
                return
            end
        end
    elseif key == 'return' or key == 'kpenter' then
        PlanetSelect.confirm()
    end
end

function PlanetSelect.wheelmoved(x, y)
    PlanetHistory.wheelmoved(x, y)
end

function PlanetSelect.confirm()
    local def = PlanetDefs.get(selectedPlanet)
    if not def or def.locked then return end

    GameState.planet = selectedPlanet

    -- Generate world map for this planet and advance to hex selection
    local wok, WorldMap = pcall(require, 'src.ui.world_map')
    if wok and WorldMap.generateForPlanet then
        WorldMap.generateForPlanet(selectedPlanet)
    end

    GameState.phase = 'world_map'
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function PlanetSelect.getSelected()
    return selectedPlanet
end

return PlanetSelect
