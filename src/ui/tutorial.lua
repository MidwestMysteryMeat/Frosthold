-- tutorial.lua -- Guided first-play tutorial
-- Step-based system: each step has a trigger condition and display text.
-- Semi-transparent tooltip overlay with arrow pointing at relevant area.
-- Skippable with Escape. Only shows on first play (no save file exists).
-- Completion tracked in save data via GameState.tutorialDone.

local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')

local Tutorial = {}

---------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------

local STEPS = {
    {
        id      = 'welcome',
        text    = 'Welcome to Erebus. Mammona dropped your crew here to build, extract, and stay alive.',
        trigger = function() return true end,  -- immediate
        anchor  = { x = 0.5, y = 0.3 },       -- screen fraction for tooltip
        arrow   = nil,                         -- no arrow for welcome
    },
    {
        id      = 'select',
        text    = 'Select colonists by left-clicking or dragging a box over them.',
        trigger = function()
            -- Advance once the player has selected at least one entity
            local count = 0
            for _ in pairs(GameState.selectedEntities) do count = count + 1 end
            return count > 0
        end,
        anchor  = { x = 0.5, y = 0.5 },
        arrow   = 'down',
    },
    {
        id      = 'move',
        text    = 'Right-click on the ground to move your colonists.',
        trigger = function()
            -- Advance once any colonist has a non-nil path
            for id, comps in ECS.query('path', 'colonist') do
                if comps.path.nodes then return true end
            end
            return false
        end,
        anchor  = { x = 0.5, y = 0.5 },
        arrow   = 'down',
    },
    {
        id      = 'build',
        text    = 'Press B to open build mode. Place a campfire to keep warm.',
        trigger = function()
            return GameState.buildMode == true
        end,
        anchor  = { x = 0.3, y = 0.8 },
        arrow   = 'left',
    },
    {
        id      = 'heat_online',
        text    = 'Good. Keep at least one heat source burning so the first night does not cripple the crew.',
        trigger = function()
            for _, comps in ECS.query('building_ref') do
                local bid = comps.building_ref.defId
                if bid == 'campfire' or bid == 'heater' or bid == 'fire_pit' or bid == 'deep_fire_pit' then
                    return true
                end
            end
            return false
        end,
        anchor  = { x = 0.36, y = 0.78 },
        arrow   = 'left',
    },
    {
        id      = 'generator',
        text    = 'Build a generator early. Power unlocks heaters, pumps, lights, and your first real shelter.',
        trigger = function()
            return ECS.countWith('generator') > 0
        end,
        anchor  = { x = 0.36, y = 0.78 },
        arrow   = 'left',
    },
    {
        id      = 'shelter',
        text    = 'Box in a room with walls and a door. Heat matters much more once you have enclosed shelter.',
        trigger = function()
            local walls, doors = 0, 0
            for _, comps in ECS.query('building_ref') do
                local bid = comps.building_ref.defId or ''
                if bid:find('wall') then walls = walls + 1 end
                if bid:find('door') then doors = doors + 1 end
            end
            return walls >= 6 and doors >= 1
        end,
        anchor  = { x = 0.34, y = 0.78 },
        arrow   = 'left',
    },
    {
        id      = 'mine',
        text    = 'Press M to designate mining areas. Mine rock for stone.',
        trigger = function()
            return GameState.selectedTool == 'mine'
        end,
        anchor  = { x = 0.3, y = 0.8 },
        arrow   = 'left',
    },
    {
        id      = 'stockpile',
        text    = 'Press Z to create a stockpile zone for storing resources.',
        trigger = function()
            return GameState.selectedTool == 'zone_stockpile'
        end,
        anchor  = { x = 0.3, y = 0.8 },
        arrow   = 'left',
    },
    {
        id      = 'work_tab',
        text    = 'Open a colonist and check the Work tab. Bad priorities create idle crews and untreated injuries.',
        trigger = function()
            local ok, Selection = pcall(require, 'src.ui.ui_selection')
            return ok and Selection.getSelectedTab and Selection.getSelectedTab() == 'work'
        end,
        anchor  = { x = 0.5, y = 0.92 },
        arrow   = 'up',
    },
    {
        id      = 'goals',
        text    = 'Press Q any time to review colony goals, active quests, and the four long-term victory paths.',
        trigger = function()
            local ok, QuestPanel = pcall(require, 'src.quest.quest_panel')
            return ok and QuestPanel.isOpen and QuestPanel.isOpen()
        end,
        anchor  = { x = 0.82, y = 0.12 },
        arrow   = 'up',
    },
    {
        id      = 'speed',
        text    = 'Press 1, 2, or 3 to change game speed. Space to pause.',
        trigger = function()
            return GameState.speed ~= 1 or GameState.paused
        end,
        anchor  = { x = 0.8, y = 0.05 },
        arrow   = 'up',
    },
    {
        id      = 'cold_snap',
        text    = 'Cold snaps will crash warmth fast. Watch the temperature trend and keep fuel, heat, and shelter ahead of the weather.',
        trigger = function()
            local ok, Weather = pcall(require, 'src.weather.weather')
            if ok and Weather.getCurrent then
                local current = Weather.getCurrent()
                if current == 'snowfall' or current == 'blizzard' or current == 'whiteout' then
                    return true
                end
            end
            return GameState.globalTemp <= (GameState.baseTemp or -40) - 8
        end,
        anchor  = { x = 0.78, y = 0.05 },
        arrow   = 'up',
    },
    {
        id      = 'survive',
        text    = 'You have the basics: heat, power, shelter, priorities, and a plan. Now keep the colony alive long enough to choose its ending.',
        trigger = function()
            return GameState.simTick > 1200
        end,
        anchor  = { x = 0.5, y = 0.3 },
        arrow   = nil,
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local currentStep = 1
local active      = false
local dismissed   = false  -- player pressed escape to skip
local showTimer   = 0      -- delay before showing next step (smooth transition)
local SHOW_DELAY  = 0.5    -- seconds

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Tutorial.init()
    local Save = require('src.persistence.save')
    -- Only show tutorial on first play
    if Save.exists() or GameState.tutorialDone then
        active = false
        dismissed = true
    else
        active = true
        dismissed = false
        currentStep = 1
        showTimer = SHOW_DELAY
    end
end

---------------------------------------------------------------------------
-- Update (call each frame)
---------------------------------------------------------------------------

function Tutorial.update(dt)
    if not active or dismissed then return end

    showTimer = showTimer - dt
    if showTimer > 0 then return end

    local step = STEPS[currentStep]
    if not step then
        -- All steps complete
        Tutorial.complete()
        return
    end

    -- Check trigger for current step
    local ok, result = pcall(step.trigger)
    if ok and result then
        currentStep = currentStep + 1
        showTimer = SHOW_DELAY
        -- Check if we're done
        if currentStep > #STEPS then
            Tutorial.complete()
        end
    end
end

function Tutorial.complete()
    active = false
    GameState.tutorialDone = true
end

---------------------------------------------------------------------------
-- Draw (call from UI.draw)
---------------------------------------------------------------------------

local function drawArrow(x, y, direction)
    local sz = 8
    love.graphics.setColor(1, 1, 1, 0.9)
    if direction == 'down' then
        love.graphics.polygon('fill', x, y + sz, x - sz, y - sz, x + sz, y - sz)
    elseif direction == 'up' then
        love.graphics.polygon('fill', x, y - sz, x - sz, y + sz, x + sz, y + sz)
    elseif direction == 'left' then
        love.graphics.polygon('fill', x - sz, y, x + sz, y - sz, x + sz, y + sz)
    elseif direction == 'right' then
        love.graphics.polygon('fill', x + sz, y, x - sz, y - sz, x - sz, y + sz)
    end
end

function Tutorial.draw()
    if not active or dismissed then return end
    if showTimer > 0 then return end

    local step = STEPS[currentStep]
    if not step then return end

    local sw, sh = love.graphics.getDimensions()
    local font = love.graphics.getFont()

    local text = step.text
    local textW = font:getWidth(text)
    local textH = font:getHeight()

    local padX = 16
    local padY = 10
    local boxW = textW + padX * 2
    local boxH = textH + padY * 2 + 16  -- extra for hint text

    -- Position based on anchor
    local ax = step.anchor.x * sw
    local ay = step.anchor.y * sh

    -- Center box on anchor
    local bx = math.max(4, math.min(sw - boxW - 4, ax - boxW / 2))
    local by = math.max(4, math.min(sh - boxH - 4, ay - boxH / 2))

    -- Semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', bx, by, boxW, boxH, 6, 6)
    love.graphics.setColor(0.3, 0.6, 0.9, 0.8)
    love.graphics.rectangle('line', bx, by, boxW, boxH, 6, 6)

    -- Main text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(text, bx + padX, by + padY)

    -- Hint text
    love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
    local hint = string.format('(%d/%d) Press Escape to skip tutorial', currentStep, #STEPS)
    love.graphics.print(hint, bx + padX, by + padY + textH + 4)

    -- Arrow
    if step.arrow then
        local arrowX, arrowY = bx + boxW / 2, by + boxH / 2
        if step.arrow == 'down' then
            arrowY = by + boxH + 2
        elseif step.arrow == 'up' then
            arrowY = by - 2
        elseif step.arrow == 'left' then
            arrowX = bx - 2
        elseif step.arrow == 'right' then
            arrowX = bx + boxW + 2
        end
        drawArrow(arrowX, arrowY, step.arrow)
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function Tutorial.keypressed(key)
    if not active or dismissed then return false end
    if key == 'escape' then
        Tutorial.complete()
        dismissed = true
        return true  -- consume the escape
    end
    return false
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Tutorial.toggle()
    if active and not dismissed then
        dismissed = true
    else
        active = true
        dismissed = false
    end
end

function Tutorial.isActive()
    return active and not dismissed
end

function Tutorial.getCurrentStep()
    if not active or dismissed then return nil end
    return STEPS[currentStep]
end

return Tutorial
