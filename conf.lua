-- Parse launch flags before conf runs
AUTOPLAY = false
AUTOPLAY_DAYS = 30
SIMULATION_TEST = false
SIMULATION_SCENARIO = 'survival'
-- nil = seed from the clock (normal play). `--seed N` pins the RNG so an
-- acceptance run can be replayed exactly, and so a batch of runs launched in
-- the same wall-clock second still explores different worlds.
RUN_SEED = nil
-- Dev-only: boot a colony, screenshot every major panel, quit. See
-- src/testing/ui_shots.lua.
UI_SHOTS = false

for i, v in ipairs(arg or {}) do
    if v == '--autoplay' then AUTOPLAY = true end
    if v == '--days' and arg[i + 1] then AUTOPLAY_DAYS = tonumber(arg[i + 1]) or 30 end
    if v == '--simulation' then SIMULATION_TEST = true end
    if v == '--scenario' and arg[i + 1] then SIMULATION_SCENARIO = arg[i + 1] end
    if v == '--seed' and arg[i + 1] then RUN_SEED = tonumber(arg[i + 1]) end
    if v == '--uishots' then UI_SHOTS = true end
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

    -- Acceptance/simulation runs are headless in spirit: a small unsynced
    -- window lets several seeds run side by side without fighting over the
    -- display or being throttled to the monitor refresh rate.
    if SIMULATION_TEST or AUTOPLAY then
        t.window.fullscreen = false
        t.window.width  = 640
        t.window.height = 360
        t.window.vsync  = 0
    end

    -- Panel screenshots are taken at the documented default window size, so the
    -- images show the layout a normal player sees.
    if UI_SHOTS then
        t.window.fullscreen = false
        t.window.width  = 1280
        t.window.height = 720
        t.window.vsync  = 0
    end

    t.modules.joystick = false
    t.modules.physics  = false
    t.modules.video    = false
end
