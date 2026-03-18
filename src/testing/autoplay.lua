-- FROSTHOLD — Autoplay Bot
-- src/testing/autoplay.lua
-- State machine that plays the game automatically for smoke testing.
-- Activated via --autoplay launch flag. Catches crashes via the error handler.

local Autoplay = {}

local GameState = require('src.game_state')

-- Bot state
local botState = 'idle'     -- idle, starting, playing, done
local tickTimer = 0
local actionQueue = {}
local logLines = {}
local dayTarget = 30        -- run for 30 in-game days by default
local lastDay = 0
local startRealTime = 0

---------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------

local function log(msg)
    local entry = string.format('[Autoplay Day %d] %s', GameState.day or 0, msg)
    logLines[#logLines + 1] = entry
    print(entry)
end

function Autoplay.getLog()
    return table.concat(logLines, '\n')
end

---------------------------------------------------------------------------
-- Actions the bot can take
---------------------------------------------------------------------------

local function tryPlaceBuilding(defId, x, y)
    local ok, Building = pcall(require, 'src.building.building')
    if not ok or not Building.tryPlace then return false end
    local success, msg = Building.tryPlace(defId, x, y, nil, false, 0)
    if success then
        log('Placed ' .. defId .. ' at ' .. x .. ',' .. y)
    else
        log('Failed to place ' .. defId .. ': ' .. (msg or '?'))
    end
    return success
end

local function tryDesignateMine(x, y)
    local ok, Jobs = pcall(require, 'src.colonist.jobs')
    if not ok or not Jobs.designateMine then return end
    Jobs.designateMine(x, y, 0)
    log('Designated mine at ' .. x .. ',' .. y)
end

local function giveStartingResources()
    -- Ensure we have enough resources for basic building
    local resources = {
        wood = 200, stone = 100, metal = 50,
        components = 10, food = 100, fuel = 50,
    }
    for name, amount in pairs(resources) do
        if (GameState.resources[name] or 0) < amount then
            GameState.addResource(name, amount - (GameState.resources[name] or 0))
        end
    end
    log('Topped up starting resources')
end

local function buildShelter()
    local cx, cy = GameState.startX or 64, GameState.startY or 64

    -- Build a 5x5 wood shelter near spawn
    -- Walls around perimeter, door on south side
    local sx, sy = cx - 2, cy - 4

    -- Top wall row
    for dx = 0, 4 do
        tryPlaceBuilding('wall_wood', sx + dx, sy)
    end
    -- Side walls
    for dy = 1, 3 do
        tryPlaceBuilding('wall_wood', sx, sy + dy)
        tryPlaceBuilding('wall_wood', sx + 4, sy + dy)
    end
    -- Bottom wall with door
    tryPlaceBuilding('wall_wood', sx, sy + 4)
    tryPlaceBuilding('wall_wood', sx + 1, sy + 4)
    tryPlaceBuilding('door', sx + 2, sy + 4)
    tryPlaceBuilding('wall_wood', sx + 3, sy + 4)
    tryPlaceBuilding('wall_wood', sx + 4, sy + 4)

    -- Floor inside
    for dy = 1, 3 do
        for dx = 1, 3 do
            tryPlaceBuilding('floor_wood', sx + dx, sy + dy)
        end
    end

    -- Campfire inside
    tryPlaceBuilding('campfire', sx + 2, sy + 2)

    log('Built shelter at ' .. sx .. ',' .. sy)
end

local function designateMiningArea()
    local cx, cy = GameState.startX or 64, GameState.startY or 64
    -- Mine a 3x3 area east of spawn
    for dx = 5, 7 do
        for dy = -1, 1 do
            tryDesignateMine(cx + dx, cy + dy)
        end
    end
end

local function setMaxSpeed()
    GameState.speed = 3
    GameState.paused = false
    log('Set speed to 3x')
end

local function checkColonyStatus()
    local ok, ECS = pcall(require, 'src.ecs.ecs')
    if not ok then return end

    local alive = ECS.countWith('colonist') or 0
    local creatures = ECS.countWith('creature') or 0

    local res = GameState.resources or {}
    log(string.format(
        'Status: %d colonists, %d creatures, food=%d wood=%d metal=%d day=%d hour=%.1f',
        alive, creatures,
        res.food or 0, res.wood or 0, res.metal or 0,
        GameState.day or 0, GameState.hour or 0
    ))

    if alive <= 0 and (GameState.day or 0) > 1 then
        log('ALL COLONISTS DEAD — colony failed on day ' .. (GameState.day or 0))
        botState = 'done'
    end
end

---------------------------------------------------------------------------
-- Phase Actions — queued and executed over time
---------------------------------------------------------------------------

local phases = {
    {
        name = 'setup',
        actions = {
            { delay = 0.5, fn = giveStartingResources },
            { delay = 1.0, fn = buildShelter },
            { delay = 2.0, fn = designateMiningArea },
            { delay = 3.0, fn = setMaxSpeed },
        },
    },
}

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Autoplay.init(opts)
    opts = opts or {}
    dayTarget = opts.days or 30
    botState = 'waiting_for_game'
    startRealTime = love.timer.getTime()
    log('Autoplay bot initialized — target: ' .. dayTarget .. ' days')
end

function Autoplay.step(dt)
    if botState == 'done' or botState == 'idle' then return end

    -- Wait for game to be in playing phase
    if botState == 'waiting_for_game' then
        if GameState.phase == 'playing' then
            botState = 'setup'
            tickTimer = 0
            -- Queue setup actions
            actionQueue = {}
            for _, action in ipairs(phases[1].actions) do
                actionQueue[#actionQueue + 1] = {
                    time = action.delay,
                    fn = action.fn,
                    done = false,
                }
            end
            log('Game started — beginning autoplay')
        end
        return
    end

    tickTimer = tickTimer + dt

    -- Execute queued actions
    if botState == 'setup' then
        local allDone = true
        for _, action in ipairs(actionQueue) do
            if not action.done and tickTimer >= action.time then
                local ok, err = pcall(action.fn)
                if not ok then
                    log('Action error: ' .. tostring(err))
                end
                action.done = true
            end
            if not action.done then allDone = false end
        end
        if allDone then
            botState = 'playing'
            log('Setup complete — monitoring colony')
        end
        return
    end

    -- Playing: monitor colony status every in-game day
    if botState == 'playing' then
        local currentDay = GameState.day or 0
        if currentDay > lastDay then
            lastDay = currentDay
            checkColonyStatus()

            if currentDay >= dayTarget then
                local elapsed = love.timer.getTime() - startRealTime
                log(string.format(
                    'TARGET REACHED — survived %d days in %.1f seconds real-time',
                    currentDay, elapsed
                ))
                botState = 'done'
                -- Write results to file
                local resultsPath = love.filesystem.getSaveDirectory() .. '/autoplay_results.txt'
                local f = io.open(resultsPath, 'w')
                if f then
                    f:write(Autoplay.getLog())
                    f:close()
                    log('Results written to ' .. resultsPath)
                end
            end
        end
    end
end

function Autoplay.isActive()
    return botState ~= 'idle'
end

function Autoplay.isDone()
    return botState == 'done'
end

function Autoplay.draw()
    if not Autoplay.isActive() then return end

    -- Small overlay showing bot status
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 4, 20, 300, 50, 4)
    love.graphics.setColor(0.2, 1, 0.4)
    love.graphics.print(string.format(
        'AUTOPLAY [%s] Day %d/%d',
        botState, GameState.day or 0, dayTarget
    ), 10, 26)

    local ok, ECS = pcall(require, 'src.ecs.ecs')
    if ok then
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(string.format(
            'Colonists: %d  Food: %d',
            ECS.countWith('colonist') or 0,
            (GameState.resources or {}).food or 0
        ), 10, 46)
    end
end

return Autoplay
