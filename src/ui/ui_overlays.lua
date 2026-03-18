-- ui_overlays.lua — Event log, task queue, hotkey help overlay panels

local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')

local Overlays = {}

-- Toggle states
local showEventLog = false
local showTaskQueue = false
local showHotkeyHelp = false

-- Shared screen dimensions (set from coordinator)
local screenW, screenH = 1280, 720

function Overlays.resize(w, h)
    screenW = w
    screenH = h
end

function Overlays.init()
    showEventLog = false
    showTaskQueue = false
    showHotkeyHelp = false
end

function Overlays.toggleEventLog()
    showEventLog = not showEventLog
end

function Overlays.toggleTaskQueue()
    showTaskQueue = not showTaskQueue
end

function Overlays.toggleHotkeyHelp()
    showHotkeyHelp = not showHotkeyHelp
end

---------------------------------------------------------------------------
-- Hotkey help overlay
---------------------------------------------------------------------------

function Overlays.drawHotkeyHelp()
    if not showHotkeyHelp then return end

    local panelW = 320
    local panelH = 560
    local px = math.floor(screenW / 2 - panelW / 2)
    local py = math.floor(screenH / 2 - panelH / 2)

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.08, 0.95)
    love.graphics.rectangle('fill', px, py, panelW, panelH, 6, 6)
    love.graphics.setColor(0.35, 0.4, 0.5, 0.8)
    love.graphics.rectangle('line', px, py, panelW, panelH, 6, 6)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Keyboard Shortcuts', px + 10, py + 8)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print('[/] to close', px + panelW - 100, py + 8)

    local bindings = {
        { 'Space',  'Pause / Unpause' },
        { '1/2/3',  'Game speed' },
        { ',/.',    'Decrease / Increase speed' },
        { 'B',      'Toggle build menu' },
        { 'R',      'Rotate building / Draft toggle' },
        { 'M',      'Mine designation tool' },
        { 'D',      'Deconstruct tool' },
        { 'Z',      'Stockpile zone tool' },
        { 'X',      'Dumping zone tool' },
        { 'Y',      'Allowed area tool' },
        { 'F',      'Forage designation' },
        { 'N',      'Cycle colonist selection' },
        { 'Q',      'Goals / quests' },
        { 'J',      'Task queue' },
        { 'O',      'Doctrine panel' },
        { 'L',      'Toggle event log' },
        { '/',      'Toggle this help' },
        { 'F2',     'Thermal overlay' },
        { 'F3',     'Pollution overlay' },
        { 'F4',     'Power overlay' },
        { 'F6',     'Gas overlay' },
        { 'F7',     'Logistics overlay' },
        { 'F8',     'Containment overlay' },
        { 'F12',    'Debug overlay' },
        { 'F5',     'Quick save' },
        { 'F9',     'Quick load' },
        { '[ / ]',  'View deeper / shallower layer' },
        { 'Shift+S','Dig stairs down tool' },
        { 'Shift+W','Dig stairs up tool' },
        { 'Shift+C','Dig channel tool' },
        { 'Shift+R','Carve ramp tool' },
        { 'Shift+H','Dig shaft tool' },
        { 'Escape', 'Cancel / Pause menu' },
        { 'Shift+Click', 'Add to selection' },
        { 'RMB',    'Context menu / Force tasks' },
        { 'MMB',    'Pan camera' },
        { 'Scroll', 'Zoom in/out' },
    }

    local lineY = py + 30
    for _, bind in ipairs(bindings) do
        if lineY > py + panelH - 10 then break end
        love.graphics.setColor(0.7, 0.8, 0.9)
        love.graphics.print(bind[1], px + 14, lineY)
        love.graphics.setColor(0.55, 0.55, 0.55)
        love.graphics.print(bind[2], px + 120, lineY)
        lineY = lineY + 16
    end
end

---------------------------------------------------------------------------
-- Event log panel
---------------------------------------------------------------------------

function Overlays.drawEventLog()
    if not showEventLog then return end

    local panelW = 360
    local panelH = 340
    local px = screenW - panelW - 10
    local py = 120

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.08, 0.92)
    love.graphics.rectangle('fill', px, py, panelW, panelH, 6, 6)
    love.graphics.setColor(0.3, 0.35, 0.45, 0.8)
    love.graphics.rectangle('line', px, py, panelW, panelH, 6, 6)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Event Log', px + 10, py + 6)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print('[L]', px + panelW - 30, py + 6)

    -- Gather events from storyteller + hope log, merge by day/hour
    local entries = {}

    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk then
        for _, ev in ipairs(Storyteller.getLog()) do
            entries[#entries + 1] = {
                day = ev.day, hour = ev.hour or 0,
                msg = ev.message,
                color = {0.8, 0.85, 0.9},
            }
        end
    end

    local hOk, Hope = pcall(require, 'src.colony.hope')
    if hOk then
        for _, ev in ipairs(Hope.getLog()) do
            entries[#entries + 1] = {
                day = ev.day, hour = ev.hour or 0,
                msg = ev.msg,
                color = {0.7, 0.75, 0.6},
            }
        end
    end

    -- Sort newest first
    table.sort(entries, function(a, b)
        if a.day ~= b.day then return a.day > b.day end
        return a.hour > b.hour
    end)

    -- Draw entries
    local lineY = py + 26
    local maxEntries = math.floor((panelH - 30) / 16)
    for i = 1, math.min(#entries, maxEntries) do
        local ev = entries[i]
        local timeStr = string.format('D%d %02d:00', ev.day, math.floor(ev.hour))
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print(timeStr, px + 8, lineY)

        love.graphics.setColor(ev.color[1], ev.color[2], ev.color[3])
        local msgText = ev.msg or ''
        -- Truncate long messages
        local font = love.graphics.getFont()
        local maxMsgW = panelW - 90
        if font:getWidth(msgText) > maxMsgW then
            while font:getWidth(msgText .. '...') > maxMsgW and #msgText > 1 do
                msgText = msgText:sub(1, -2)
            end
            msgText = msgText .. '...'
        end
        love.graphics.print(msgText, px + 78, lineY)
        lineY = lineY + 16
    end

    if #entries == 0 then
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('No events yet.', px + 10, lineY)
    end
end

---------------------------------------------------------------------------
-- Task queue panel (J key toggle)
---------------------------------------------------------------------------

function Overlays.drawTaskQueue()
    if not showTaskQueue then return end

    local jOk, Jobs = pcall(require, 'src.colonist.jobs')
    if not jOk then return end

    local allTasks = Jobs.getAllTasks()
    if not allTasks then return end

    -- Group tasks by type
    local groups = {}  -- { [type] = { total, claimed, unclaimed } }
    for _, task in pairs(allTasks) do
        if not task.complete then
            local t = task.type
            if not groups[t] then groups[t] = { total = 0, claimed = 0 } end
            groups[t].total = groups[t].total + 1
            if task.claimed then groups[t].claimed = groups[t].claimed + 1 end
        end
    end

    -- Sort by count descending
    local sorted = {}
    for t, g in pairs(groups) do
        sorted[#sorted + 1] = { type = t, total = g.total, claimed = g.claimed }
    end
    table.sort(sorted, function(a, b) return a.total > b.total end)

    local panelW = 280
    local lineH = 18
    local panelH = math.max(60, 32 + #sorted * lineH)
    local px = 10
    local py = 120

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.08, 0.92)
    love.graphics.rectangle('fill', px, py, panelW, panelH, 6, 6)
    love.graphics.setColor(0.3, 0.35, 0.45, 0.8)
    love.graphics.rectangle('line', px, py, panelW, panelH, 6, 6)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Task Queue', px + 10, py + 6)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print('[J]', px + panelW - 30, py + 6)

    -- Column headers
    local lineY = py + 26
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print('Type', px + 10, lineY)
    love.graphics.print('Pending', px + 130, lineY)
    love.graphics.print('Active', px + 200, lineY)
    lineY = lineY + lineH

    -- Rows
    for _, row in ipairs(sorted) do
        local unclaimed = row.total - row.claimed
        love.graphics.setColor(0.8, 0.85, 0.9)
        love.graphics.print(row.type, px + 10, lineY)
        love.graphics.setColor(unclaimed > 0 and {0.9, 0.7, 0.3} or {0.4, 0.4, 0.4})
        love.graphics.print(tostring(unclaimed), px + 130, lineY)
        love.graphics.setColor(0.4, 0.8, 0.5)
        love.graphics.print(tostring(row.claimed), px + 200, lineY)
        lineY = lineY + lineH
    end

    if #sorted == 0 then
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('No pending tasks.', px + 10, lineY)
    end
end

return Overlays
