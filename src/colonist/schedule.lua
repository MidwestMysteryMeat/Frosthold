-- schedule.lua — 24-hour scheduling system
-- Each colonist has a per-hour block assignment: work, eat, sleep, free.
-- The work AI checks the current block before assigning tasks.

local GameState = require('src.game_state')

local Schedule = {}

Schedule.BLOCKS = {
    work  = 'work',
    eat   = 'eat',
    sleep = 'sleep',
    free  = 'free',
}

-- Default schedule: sleep 22-06, eat 06/12/18, work rest of day, free evening
function Schedule.default()
    local s = {}
    for h = 0, 23 do
        if h >= 22 or h < 6 then
            s[h] = 'sleep'
        elseif h == 6 or h == 12 or h == 18 then
            s[h] = 'eat'
        elseif h >= 19 and h < 22 then
            s[h] = 'free'
        else
            s[h] = 'work'
        end
    end
    return s
end

-- Night shift schedule
function Schedule.nightShift()
    local s = {}
    for h = 0, 23 do
        if h >= 8 and h < 16 then
            s[h] = 'sleep'
        elseif h == 16 or h == 0 then
            s[h] = 'eat'
        elseif h >= 5 and h < 8 then
            s[h] = 'free'
        else
            s[h] = 'work'
        end
    end
    return s
end

-- All-work schedule (emergency)
function Schedule.allWork()
    local s = {}
    for h = 0, 23 do
        if h >= 0 and h < 5 then
            s[h] = 'sleep'
        elseif h == 5 or h == 12 then
            s[h] = 'eat'
        else
            s[h] = 'work'
        end
    end
    return s
end

-- Available preset names in order (for cycling)
Schedule.PRESETS = { 'default', 'nightShift', 'allWork' }
local PRESET_FNS = {
    default    = Schedule.default,
    nightShift = Schedule.nightShift,
    allWork    = Schedule.allWork,
}

-- Cycle a colonist's schedule to the next preset.
-- Returns the new preset name and schedule table.
function Schedule.cyclePreset(currentPreset)
    currentPreset = currentPreset or 'default'
    local nextIdx = 1
    for i, name in ipairs(Schedule.PRESETS) do
        if name == currentPreset then
            nextIdx = (i % #Schedule.PRESETS) + 1
            break
        end
    end
    local nextName = Schedule.PRESETS[nextIdx]
    return nextName, PRESET_FNS[nextName]()
end

-- Set a specific hour to a specific block for per-hour editing
function Schedule.setHourBlock(schedule, hour, block)
    hour = hour % 24
    if Schedule.BLOCKS[block] then
        schedule[hour] = block
    end
end

-- Get current block for a colonist's schedule
function Schedule.getCurrentBlock(schedule)
    local hour = math.floor(GameState.hour) % 24
    return schedule[hour] or 'work'
end

return Schedule
