-- minimap.lua -- Corner overlay minimap
-- 150x150 pixel minimap in bottom-right corner.
-- Shows terrain, entity dots, building markers, camera viewport.
-- Toggle with Tab. Redraws every 30 frames for efficiency.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Camera    = require('src.render.camera')
local Tiles     = require('src.world.tiles')

local Minimap = {}

local SIZE       = 150  -- pixel dimensions of minimap
local MARGIN     = 10   -- margin from screen edge
local REDRAW_INTERVAL = 30  -- frames between canvas redraws

local visible   = true
local canvas     = nil
local frameCount = 0
local needsRedraw = true

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Minimap.init()
    canvas = love.graphics.newCanvas(SIZE, SIZE)
    canvas:setFilter('nearest', 'nearest')
    needsRedraw = true
    visible = true
    frameCount = 0
end

---------------------------------------------------------------------------
-- Toggle
---------------------------------------------------------------------------

function Minimap.toggle()
    visible = not visible
end

function Minimap.isVisible()
    return visible
end

function Minimap.keypressed(key)
    if key == 'tab' then
        Minimap.toggle()
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Update (call each frame from main update)
---------------------------------------------------------------------------

function Minimap.update()
    if not visible then return end
    frameCount = frameCount + 1
    if frameCount >= REDRAW_INTERVAL then
        frameCount = 0
        needsRedraw = true
    end
end

---------------------------------------------------------------------------
-- Render minimap to canvas
---------------------------------------------------------------------------

local function renderCanvas()
    local World = require('src.world.tilemap')
    local mapW = World.width()
    local mapH = World.height()
    if mapW == 0 or mapH == 0 then return end

    local scaleX = SIZE / mapW
    local scaleY = SIZE / mapH

    -- Fog of war support
    local fogEnabled = GameState.fogOfWar
    local vok, Vis = false, nil
    if fogEnabled then
        vok, Vis = pcall(require, 'src.sim.visibility')
    end

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)

    -- Draw terrain
    local tData = World.rawTileData()
    for y = 0, mapH - 1 do
        for x = 0, mapW - 1 do
            -- Skip unexplored tiles (stay black)
            if fogEnabled and vok and not Vis.isExplored(x, y) then
                goto nextMinimapTile
            end
            local idx = y * mapW + x + 1
            local tile = tData[idx]
            local props = Tiles.get(tile)
            local c = props.color
            -- Dim explored-but-not-visible tiles
            if fogEnabled and vok and not Vis.isVisible(x, y) then
                love.graphics.setColor(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 1)
            else
                love.graphics.setColor(c[1], c[2], c[3], 1)
            end
            local px = x * scaleX
            local py = y * scaleY
            love.graphics.rectangle('fill', px, py, math.max(1, scaleX), math.max(1, scaleY))
            ::nextMinimapTile::
        end
    end

    -- Building markers: white dots
    -- Buildings modify tiles (walls, floors), so they already show in terrain.
    -- Additionally mark heat sources (placed buildings with active heat).
    local Building = require('src.building.building')
    local allBuildings = Building.getAll()
    love.graphics.setColor(1, 1, 1, 0.9)
    for _, info in pairs(allBuildings) do
        local px = info.x * scaleX
        local py = info.y * scaleY
        love.graphics.rectangle('fill', px, py, math.max(2, scaleX), math.max(2, scaleY))
    end

    -- Entity dots
    -- Colonists: blue
    for id, comps in ECS.query('pos', 'colonist') do
        local pos = comps.pos
        love.graphics.setColor(0.2, 0.4, 1, 1)
        love.graphics.rectangle('fill', pos.x * scaleX - 1, pos.y * scaleY - 1, 3, 3)
    end

    -- Creatures (only show if tile is currently visible)
    for id, comps in ECS.query('pos', 'creature') do
        local pos = comps.pos
        if not fogEnabled or not vok or Vis.isVisible(pos.x, pos.y) then
            local cr = comps.creature
            if cr.hostile then
                love.graphics.setColor(1, 0.2, 0.2, 1)
            else
                love.graphics.setColor(0.2, 0.8, 0.3, 1)
            end
            love.graphics.rectangle('fill', pos.x * scaleX - 1, pos.y * scaleY - 1, 2, 2)
        end
    end

    -- Fire markers (bright orange pulsing dots, only if visible)
    local fok, Fire = pcall(require, 'src.sim.fire')
    if fok then
        local fires = Fire.getActiveFires()
        local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 5)
        love.graphics.setColor(1, 0.4, 0.1, pulse)
        for _, fire in pairs(fires) do
            if not fogEnabled or not vok or Vis.isVisible(fire.x, fire.y) then
                love.graphics.rectangle('fill', fire.x * scaleX - 1, fire.y * scaleY - 1, 3, 3)
            end
        end
    end

    love.graphics.setCanvas()
end

---------------------------------------------------------------------------
-- Draw (call from UI.draw, after camera detach)
---------------------------------------------------------------------------

function Minimap.draw()
    if not visible then return end
    if not canvas then return end

    local World = require('src.world.tilemap')
    local mapW = World.width()
    local mapH = World.height()
    if mapW == 0 or mapH == 0 then return end

    -- Redraw canvas if stale
    if needsRedraw then
        renderCanvas()
        needsRedraw = false
    end

    local sw, sh = love.graphics.getDimensions()
    local dx = sw - SIZE - MARGIN
    local dy = sh - SIZE - MARGIN

    -- Background border
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', dx - 2, dy - 2, SIZE + 4, SIZE + 4)

    -- Draw cached canvas
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.draw(canvas, dx, dy)

    -- Camera viewport rectangle
    local camX = Camera.getX()
    local camY = Camera.getY()
    local zoom = Camera.getZoom()
    local tileSize = World.tileSize()

    local scaleX = SIZE / mapW
    local scaleY = SIZE / mapH

    -- Viewport in tile coords
    local vx1 = camX / tileSize
    local vy1 = camY / tileSize
    local vx2 = vx1 + sw / (zoom * tileSize)
    local vy2 = vy1 + sh / (zoom * tileSize)

    -- Clamp
    vx1 = math.max(0, vx1)
    vy1 = math.max(0, vy1)
    vx2 = math.min(mapW, vx2)
    vy2 = math.min(mapH, vy2)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line',
        dx + vx1 * scaleX,
        dy + vy1 * scaleY,
        (vx2 - vx1) * scaleX,
        (vy2 - vy1) * scaleY
    )

    -- Compact legend row below minimap
    local ly = dy + SIZE + 4
    local lx = dx
    local legendItems = {
        { {0.2, 0.4, 1}, 'Col' },
        { {1, 0.2, 0.2}, 'Hos' },
        { {0.2, 0.8, 0.3}, 'Ani' },
        { {1, 1, 1}, 'Bld' },
        { {1, 0.4, 0.1}, 'Fire' },
    }
    for _, item in ipairs(legendItems) do
        love.graphics.setColor(item[1][1], item[1][2], item[1][3], 0.9)
        love.graphics.rectangle('fill', lx, ly, 5, 5)
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
        love.graphics.print(item[2], lx + 7, ly - 2)
        lx = lx + 32
    end
end

---------------------------------------------------------------------------
-- Click to navigate: returns true if click was inside minimap
---------------------------------------------------------------------------

function Minimap.mousepressed(mx, my, button)
    if not visible or button ~= 1 then return false end

    local sw, sh = love.graphics.getDimensions()
    local dx = sw - SIZE - MARGIN
    local dy = sh - SIZE - MARGIN

    -- Check if click is inside minimap bounds
    if mx < dx or mx > dx + SIZE or my < dy or my > dy + SIZE then
        return false
    end

    local World = require('src.world.tilemap')
    local mapW = World.width()
    local mapH = World.height()
    if mapW == 0 or mapH == 0 then return true end

    -- Convert minimap pixel to tile coordinate
    local tileX = math.floor((mx - dx) / SIZE * mapW)
    local tileY = math.floor((my - dy) / SIZE * mapH)

    Camera.centerOn(tileX, tileY)
    return true
end

return Minimap
