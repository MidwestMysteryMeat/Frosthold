-- mock_love.lua — Minimal Love2D API mock for headless testing
-- Stubs out love.graphics, love.timer, love.filesystem, love.audio, etc.
-- so game modules can be required without a real Love2D runtime.

love = love or {}

-- love.graphics stubs
love.graphics = love.graphics or {}
function love.graphics.setDefaultFilter() end
function love.graphics.setLineStyle() end
function love.graphics.setColor() end
function love.graphics.rectangle() end
function love.graphics.circle() end
function love.graphics.line() end
function love.graphics.print() end
function love.graphics.setFont() end
function love.graphics.setNewFont() end
function love.graphics.setLineWidth() end
function love.graphics.setCanvas() end
function love.graphics.clear() end
function love.graphics.getDimensions() return 1280, 720 end
function love.graphics.getWidth() return 1280 end
function love.graphics.getHeight() return 720 end
function love.graphics.newFont(size)
    return {
        getWidth = function(self, text) return #(text or '') * math.max(5, math.floor((size or 12) * 0.6)) end,
        getHeight = function(self) return size or 12 end,
    }
end
function love.graphics.getFont()
    return {
        getWidth = function(self, text) return #text * 7 end,
        getHeight = function(self) return 14 end,
    }
end
function love.graphics.newCanvas(w, h)
    return {
        setFilter = function() end,
        getWidth = function() return w or 150 end,
        getHeight = function() return h or 150 end,
    }
end

-- love.timer stubs
love.timer = love.timer or {}
function love.timer.getTime() return os.clock() end
function love.timer.getFPS() return 60 end

-- love.mouse stubs
love.mouse = love.mouse or {}
function love.mouse.getPosition() return 640, 360 end
function love.mouse.isDown() return false end

-- love.keyboard stubs
love.keyboard = love.keyboard or {}
function love.keyboard.isDown() return false end

-- love.filesystem stubs
love.filesystem = love.filesystem or {}
local _fs_data = {}
function love.filesystem.write(path, data)
    _fs_data[path] = data
    return true
end
function love.filesystem.read(path)
    return _fs_data[path], _fs_data[path] and nil or 'File not found'
end
function love.filesystem.getInfo(path)
    if _fs_data[path] then return { type = 'file', size = #_fs_data[path] } end
    return nil
end
function love.filesystem.createDirectory()
    return true
end

-- love.audio stubs
love.audio = love.audio or {}
function love.audio.newSource()
    return {
        play = function() end,
        stop = function() end,
        isPlaying = function() return false end,
        setVolume = function() end,
        setLooping = function() end,
        clone = function(self) return self end,
    }
end

-- love.math stubs (perlin noise + random)
love.math = love.math or {}
function love.math.noise(x, y)
    -- Simple deterministic pseudo-noise for testing
    local n = math.sin(x * 12.9898 + (y or 0) * 78.233) * 43758.5453
    return n - math.floor(n)
end
function love.math.random(a, b)
    if a and b then return math.random(a, b) end
    if a then return math.random(a) end
    return math.random()
end

return true
