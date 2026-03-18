-- Parse launch flags before conf runs
AUTOPLAY = false
AUTOPLAY_DAYS = 30
for i, v in ipairs(arg or {}) do
    if v == '--autoplay' then AUTOPLAY = true end
    if v == '--days' and arg[i + 1] then AUTOPLAY_DAYS = tonumber(arg[i + 1]) or 30 end
end

function love.conf(t)
    t.identity = "frosthold"
    t.version  = "11.4"
    t.console  = true

    t.window.title  = "FROSTHOLD"
    t.window.width  = 1920
    t.window.height = 1080
    t.window.fullscreen = true
    t.window.fullscreentype = "desktop"
    t.window.resizable = true
    t.window.minwidth  = 960
    t.window.minheight = 540
    t.window.vsync = 1

    t.modules.joystick = false
    t.modules.physics  = false
    t.modules.video    = false
end
