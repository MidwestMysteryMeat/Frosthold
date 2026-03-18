-- camera.lua — Pan/zoom camera with smooth follow and edge scrolling

local GameState = require('src.game_state')

local Camera = {}

local x, y = 0, 0          -- world position (top-left)
local zoom = 1.0
local targetZoom = 1.0      -- smooth zoom target
local minZoom, maxZoom = 0.25, 4.0
local screenW, screenH = 1280, 720
-- edge scrolling removed
local panSpeed = 600
local dragStart = nil       -- {mx, my, cx, cy} for middle-click drag

-- Screen shake state
local shakeIntensity = 0
local shakeDecay     = 5    -- intensity units per second
local shakeOffsetX   = 0
local shakeOffsetY   = 0

function Camera.init()
    x = GameState.camX - screenW / 2
    y = GameState.camY - screenH / 2
    zoom = 1.0
    targetZoom = 1.0
    shakeIntensity = 0
    shakeOffsetX = 0
    shakeOffsetY = 0
end

function Camera.update(dt)
    local speed = panSpeed / zoom * dt

    -- WASD panning (when not in build mode text input, skip when Shift held for terraform shortcuts)
    local shiftHeld = love.keyboard.isDown('lshift', 'rshift')
    if not shiftHeld then
        if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
            y = y - speed
        end
        if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
            y = y + speed
        end
        if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
            x = x - speed
        end
        if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
            x = x + speed
        end
    else
        if love.keyboard.isDown('up') then y = y - speed end
        if love.keyboard.isDown('down') then y = y + speed end
        if love.keyboard.isDown('left') then x = x - speed end
        if love.keyboard.isDown('right') then x = x + speed end
    end

    -- Middle mouse drag
    if dragStart then
        local dmx, dmy = love.mouse.getPosition()
        x = dragStart.cx - (dmx - dragStart.mx) / zoom
        y = dragStart.cy - (dmy - dragStart.my) / zoom
    end

    -- Smooth zoom interpolation
    if math.abs(zoom - targetZoom) > 0.001 then
        zoom = zoom + (targetZoom - zoom) * math.min(1, 12 * dt)
    else
        zoom = targetZoom
    end

    -- Clamp to world bounds
    local World = require('src.world.tilemap')
    local worldPx = World.width() * World.tileSize()
    local worldPy = World.height() * World.tileSize()
    x = math.max(-screenW / zoom * 0.5, math.min(x, worldPx - screenW / zoom * 0.5))
    y = math.max(-screenH / zoom * 0.5, math.min(y, worldPy - screenH / zoom * 0.5))

    -- Screen shake decay
    if shakeIntensity > 0 then
        shakeIntensity = math.max(0, shakeIntensity - shakeDecay * dt)
        shakeOffsetX = (math.random() * 2 - 1) * shakeIntensity
        shakeOffsetY = (math.random() * 2 - 1) * shakeIntensity
    else
        shakeOffsetX = 0
        shakeOffsetY = 0
    end

    GameState.camX = x
    GameState.camY = y
    GameState.camZoom = zoom
end

function Camera.attach()
    love.graphics.push()
    love.graphics.scale(zoom, zoom)
    love.graphics.translate(-x + shakeOffsetX / zoom, -y + shakeOffsetY / zoom)
end

function Camera.detach()
    love.graphics.pop()
end

function Camera.zoom(direction)
    local mx, my = love.mouse.getPosition()
    -- World position under cursor before zoom (use targetZoom for consistency)
    local wx = x + mx / targetZoom
    local wy = y + my / targetZoom

    local factor = direction > 0 and 1.15 or (1 / 1.15)
    targetZoom = math.max(minZoom, math.min(maxZoom, targetZoom * factor))

    -- Adjust position so cursor stays over same world point
    x = wx - mx / targetZoom
    y = wy - my / targetZoom
end

function Camera.resize(w, h)
    screenW = w
    screenH = h
end

function Camera.screenToWorld(sx, sy)
    return x + sx / zoom, y + sy / zoom
end

function Camera.worldToScreen(wx, wy)
    return (wx - x) * zoom, (wy - y) * zoom
end

function Camera.screenToTile(sx, sy)
    local World = require('src.world.tilemap')
    local wx, wy = Camera.screenToWorld(sx, sy)
    return math.floor(wx / World.tileSize()), math.floor(wy / World.tileSize())
end

function Camera.getX() return x end
function Camera.getY() return y end
function Camera.getZoom() return zoom end
function Camera.getScreenSize() return screenW, screenH end

function Camera.startDrag(mx, my)
    dragStart = { mx = mx, my = my, cx = x, cy = y }
end

function Camera.stopDrag()
    dragStart = nil
end

function Camera.isDragging()
    return dragStart ~= nil
end

-- Trigger screen shake (intensity 1-20 typical)
function Camera.shake(intensity)
    shakeIntensity = math.max(shakeIntensity, intensity or 5)
end

-- Center camera on a world tile position
function Camera.centerOn(tileX, tileY)
    local World = require('src.world.tilemap')
    local ts = World.tileSize()
    x = tileX * ts + ts / 2 - screenW / (2 * zoom)
    y = tileY * ts + ts / 2 - screenH / (2 * zoom)
end

return Camera
