-- NOTE: audio is NOT in the repo — assets/audio/ is owner-licensed packs
-- excluded from version control (see assets/ASSETS_PLACEHOLDER.md).
-- The loader below must tolerate missing files: a fresh clone runs silent.
-- sound.lua -- Sound manager
-- Loads, plays, and mixes sounds by category.
-- Supports positional audio (volume attenuation by camera distance).
-- Paths default to .ogg, but the loader falls back to .wav so placeholder
-- shipped assets can coexist with later higher-quality replacements.

local Camera    = require('src.render.camera')
local GameState = require('src.game_state')

local Sound = {}

---------------------------------------------------------------------------
-- Categories and volume
---------------------------------------------------------------------------

local CATEGORIES = { 'ambient', 'ui', 'creature', 'weather', 'work' }

local masterVolume = 0.8
local categoryVolume = {
    ambient  = 0.5,
    ui       = 0.7,
    creature = 0.6,
    weather  = 0.7,
    work     = 0.5,
}

---------------------------------------------------------------------------
-- Sound definitions (path placeholders)
---------------------------------------------------------------------------

local SOUNDS = {
    -- Ambient
    wind_loop       = { path = 'assets/audio/ambient/wind_loop.ogg',       category = 'ambient', looping = true },

    -- Weather
    blizzard_howl   = { path = 'assets/audio/weather/blizzard_howl.ogg',   category = 'weather', looping = true },
    snow_crunch     = { path = 'assets/audio/weather/snow_crunch.ogg',     category = 'weather', looping = false },

    -- UI
    click           = { path = 'assets/audio/ui/click.ogg',               category = 'ui', looping = false },
    build_place     = { path = 'assets/audio/ui/build_place.ogg',         category = 'ui', looping = false },
    task_complete   = { path = 'assets/audio/ui/task_complete.ogg',       category = 'ui', looping = false },
    alert           = { path = 'assets/audio/ui/alert.ogg',               category = 'ui', looping = false },
    alert_minor     = { path = 'assets/audio/ui/alert_minor.ogg',         category = 'ui', looping = false },
    alert_major     = { path = 'assets/audio/ui/alert_major.ogg',         category = 'ui', looping = false },
    alert_critical  = { path = 'assets/audio/ui/alert_critical.ogg',      category = 'ui', looping = false },

    -- Creature
    wolf_howl       = { path = 'assets/audio/creature/wolf_howl.ogg',     category = 'creature', looping = false },
    bear_roar       = { path = 'assets/audio/creature/bear_roar.ogg',     category = 'creature', looping = false },
    titan_stomp     = { path = 'assets/audio/creature/titan_stomp.ogg',   category = 'creature', looping = false },

    -- Work
    pickaxe_hit     = { path = 'assets/audio/work/pickaxe_hit.ogg',       category = 'work', looping = false },
    hammer          = { path = 'assets/audio/work/hammer.ogg',            category = 'work', looping = false },
    saw             = { path = 'assets/audio/work/saw.ogg',               category = 'work', looping = false },
}

---------------------------------------------------------------------------
-- Loaded sources (lazy-load)
---------------------------------------------------------------------------

local loaded  = {}    -- { [soundId] = love.audio.Source or false }
local playing = {}    -- { [soundId] = love.audio.Source } for active loops

local function resolvePath(path)
    local info = love.filesystem.getInfo(path)
    if info then return path end
    if path:sub(-4) == '.ogg' then
        local wavPath = path:sub(1, -5) .. '.wav'
        if love.filesystem.getInfo(wavPath) then
            return wavPath
        end
    end
    return nil
end

local function tryLoad(soundId)
    if loaded[soundId] ~= nil then return loaded[soundId] end
    local def = SOUNDS[soundId]
    if not def then
        loaded[soundId] = false
        return false
    end
    local ok, source = pcall(function()
        local resolvedPath = resolvePath(def.path)
        if not resolvedPath then return nil end
        local s = love.audio.newSource(resolvedPath, def.looping and 'stream' or 'static')
        s:setLooping(def.looping or false)
        return s
    end)
    if ok and source then
        loaded[soundId] = source
        return source
    end
    loaded[soundId] = false
    return false
end

---------------------------------------------------------------------------
-- Volume helpers
---------------------------------------------------------------------------

local function effectiveVolume(category)
    return masterVolume * (categoryVolume[category] or 1)
end

-- Positional attenuation: returns 0..1 based on world distance to camera center.
-- maxDist in tiles. Sounds beyond maxDist are silent.
local function positionalFactor(worldX, worldY, maxDist)
    if not worldX or not worldY then return 1 end
    maxDist = maxDist or 40
    local World = require('src.world.tilemap')
    local ts = World.tileSize()
    local camCX = Camera.getX() + love.graphics.getWidth() / (2 * Camera.getZoom())
    local camCY = Camera.getY() + love.graphics.getHeight() / (2 * Camera.getZoom())
    local dx = worldX * ts - camCX
    local dy = worldY * ts - camCY
    local dist = math.sqrt(dx * dx + dy * dy) / ts
    if dist >= maxDist then return 0 end
    return 1 - (dist / maxDist)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Sound.init()
    loaded  = {}
    playing = {}
end

-- Play a one-shot sound. Optional worldX/worldY for positional audio.
function Sound.play(soundId, worldX, worldY)
    local source = tryLoad(soundId)
    if not source then return end
    local def = SOUNDS[soundId]
    local vol = effectiveVolume(def.category)
    if worldX and worldY then
        vol = vol * positionalFactor(worldX, worldY)
    end
    if vol <= 0.01 then return end

    -- Clone for overlapping one-shots
    local s = source:clone()
    s:setVolume(vol)
    s:play()
end

-- Start a looping sound. If already playing, adjusts volume.
function Sound.startLoop(soundId)
    local source = tryLoad(soundId)
    if not source then return end
    if playing[soundId] then return end
    local def = SOUNDS[soundId]
    local vol = effectiveVolume(def.category)
    local s = source:clone()
    s:setVolume(vol)
    s:setLooping(true)
    s:play()
    playing[soundId] = s
end

-- Stop a looping sound.
function Sound.stopLoop(soundId)
    local s = playing[soundId]
    if s then
        s:stop()
        playing[soundId] = nil
    end
end

-- Update loop volumes (call each frame). Adjusts ambient wind by weather severity.
function Sound.update(dt)
    local Weather = require('src.weather.weather')
    local _, weatherDef = Weather.getCurrent()

    -- Wind loop removed — was playing constant white noise

    -- Blizzard howl: play during blizzard/whiteout only
    local wName = Weather.getCurrent()
    if wName == 'blizzard' or wName == 'whiteout' then
        if not playing.blizzard_howl then
            Sound.startLoop('blizzard_howl')
        end
        if playing.blizzard_howl then
            local vol = effectiveVolume('weather')
            playing.blizzard_howl:setVolume(vol)
        end
    else
        if playing.blizzard_howl then
            Sound.stopLoop('blizzard_howl')
        end
    end
end

---------------------------------------------------------------------------
-- Volume controls
---------------------------------------------------------------------------

function Sound.setMasterVolume(v)
    masterVolume = math.max(0, math.min(1, v))
end

function Sound.getMasterVolume()
    return masterVolume
end

function Sound.setCategoryVolume(category, v)
    if categoryVolume[category] then
        categoryVolume[category] = math.max(0, math.min(1, v))
    end
end

function Sound.getCategoryVolume(category)
    return categoryVolume[category] or 1
end

function Sound.getCategories()
    return CATEGORIES
end

-- Stop all currently playing sounds
function Sound.stopAll()
    for sid, s in pairs(playing) do
        s:stop()
    end
    playing = {}
end

return Sound
