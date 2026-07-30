-- ui_shots.lua — dev-only panel screenshot pass.
--
-- Boots a colony, opens each major panel in turn and captures a PNG of it, then
-- quits. Used to eyeball panel layout (overlap, clipped labels, run-together
-- text) without clicking through the game by hand.
--
--   F:\LOVE\lovec.exe . --uishots
--
-- Images land in the Love save directory (printed on exit); tools/collect_uishots.ps1
-- copies them to the gitignored _uishots\ folder in the repo.

local GameState    = require('src.game_state')
local PanelManager = require('src.ui.panel_manager')

local UIShots = {}

-- Order is the order the shots are numbered in.
local SHOTS = {
    { id = nil,          name = 'hud' },        -- no panel: baseline HUD + toolbar
    { id = 'colony',     name = 'colony' },
    { id = 'factions',   name = 'factions' },
    { id = 'factions',   name = 'factions_gift', clickGift = true },
    { id = 'trade',      name = 'trade' },
    { id = 'research',   name = 'research' },
    { id = 'policy',     name = 'policy' },
    { id = 'doctrine',   name = 'doctrine' },
    { id = 'laws',       name = 'laws' },
    { id = 'farm',       name = 'farm' },
    { id = 'equip',      name = 'equip' },
    { id = 'medical',    name = 'medical' },
    { id = 'quests',     name = 'quests' },
    { id = 'goals',      name = 'goals' },
    { id = 'taming',     name = 'taming' },
    { id = 'expedition', name = 'expedition' },
    { id = 'debug',      name = 'debug' },
}

local WARMUP_FRAMES = 120   -- let worldgen finish and a few sim ticks land
local SETTLE_FRAMES = 4     -- frames a panel is left open before capturing
local FLUSH_FRAMES  = 3     -- frames to let the capture write out

local phase = 'warmup'
local frames = 0
local index = 0
local captured = {}

function UIShots.isActive()
    return phase ~= 'done'
end

function UIShots.getCaptured()
    return captured
end

local function fileName(i, name)
    return string.format('uishot_%02d_%s.png', i, name)
end

--- Advance the capture state machine. Call once per love.update.
function UIShots.step()
    if phase == 'done' then return end
    frames = frames + 1

    if phase == 'warmup' then
        if GameState.phase ~= 'playing' then return end
        if frames < WARMUP_FRAMES then return end
        phase = 'open'
        frames = 0
        return
    end

    if phase == 'open' then
        index = index + 1
        local shot = SHOTS[index]
        if not shot then
            phase = 'done'
            print('[UIShots] captured ' .. #captured .. ' panel screenshots')
            for _, f in ipairs(captured) do print('[UIShots]   ' .. f) end
            if love.filesystem and love.filesystem.getSaveDirectory then
                print('[UIShots] save directory: ' .. love.filesystem.getSaveDirectory())
            end
            love.event.quit(0)
            return
        end

        PanelManager.closeAll()
        if shot.id then
            if not PanelManager.open(shot.id) then
                -- A panel that refuses to open (nothing to show) is skipped
                -- rather than captured as an empty frame.
                print('[UIShots] skipped ' .. shot.name .. ' (would not open)')
                phase = 'open'
                frames = 0
                return
            end
        end
        phase = 'settle'
        frames = 0
        return
    end

    if phase == 'settle' then
        if frames < SETTLE_FRAMES then return end
        local shot = SHOTS[index]

        -- Prove the gift action end to end: click the first enabled gift button
        -- and capture the frame that shows the resulting toast. A click that
        -- silently did nothing, or a toast drawn behind the panel, both show up
        -- here as a missing message.
        if shot.clickGift and not shot._clicked then
            shot._clicked = true
            local fp = PanelManager.moduleFor('factions')
            local zones = fp and fp.getHitZones and fp.getHitZones() or {}
            for _, zone in ipairs(zones) do
                if zone.action == 'gift' then
                    local GS = require('src.game_state')
                    local before = GS.resources[zone.data.resource] or 0
                    love.mousepressed(zone.x + 4, zone.y + 4, 1)
                    local after = GS.resources[zone.data.resource] or 0
                    print(string.format('[UIShots] clicked gift %s: %d -> %d',
                        tostring(zone.data.resource), before, after))
                    break
                end
            end
            frames = 0
            return
        end
        local name = fileName(index, shot.name)
        love.graphics.captureScreenshot(name)
        captured[#captured + 1] = name
        print('[UIShots] captured ' .. name)
        phase = 'flush'
        frames = 0
        return
    end

    if phase == 'flush' then
        if frames < FLUSH_FRAMES then return end
        phase = 'open'
        frames = 0
    end
end

return UIShots
