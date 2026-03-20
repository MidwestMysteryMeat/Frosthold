-- game_over.lua - Endgame detection and result screen
-- Four endgame outcomes (player-initiated), one defeat condition.
--
-- DEFEAT: all colonists dead.
-- OUTCOME 1: Mammona Claim - transmission array charged and final wave survived.
-- OUTCOME 2: Exodus - launch pad shuttle launched with colonists aboard.
-- OUTCOME 3: Seal the Deep - sealing apparatus activated at a precursor site.
-- OUTCOME 4: Mammona Extraction - extraction beacon activated after the boss falls.
-- After any outcome, press R to redeploy to planet select.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local GameOver = {}

local state = 'playing'  -- 'playing' | 'defeat' | 'victory'
local victoryType = nil   -- 'mammona_signal' | 'exodus' | 'seal_deep' | 'mammona_extraction'
local reason = ''
local checkTimer = 0
local CHECK_INTERVAL = 2.0
local lastRecord = nil
local mrpEarned = 0

---------------------------------------------------------------------------
-- Outcome definitions (for the result screen)
---------------------------------------------------------------------------

local VICTORY_TITLES = {
    mammona_signal     = 'CORPORATE CLAIM SECURED',
    exodus             = 'ESCAPE ACHIEVED',
    seal_deep          = 'THE DEEP IS SEALED',
    mammona_extraction = 'MAMMONA EXTRACTION',
}

local VICTORY_COLORS = {
    mammona_signal     = { 0.9, 0.7, 0.2 },
    exodus             = { 0.3, 0.8, 0.3 },
    seal_deep          = { 0.4, 0.6, 0.9 },
    mammona_extraction = { 1.0, 0.85, 0.3 },
}

---------------------------------------------------------------------------
-- Reset (on new game or load)
---------------------------------------------------------------------------

function GameOver.reset()
    state = 'playing'
    victoryType = nil
    reason = ''
    checkTimer = 0
    lastRecord = nil
    mrpEarned = 0
end

function GameOver.getState()
    return state
end

function GameOver.isGameOver()
    return state ~= 'playing'
end

---------------------------------------------------------------------------
-- Trigger an endgame outcome from external systems
---------------------------------------------------------------------------

function GameOver.triggerVictory(vType, vReason)
    if state ~= 'playing' then return end
    state = 'victory'
    victoryType = vType
    reason = vReason or ''
    GameState.paused = true

    -- Award MRP for victory
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if mok then
        local rok, Research = pcall(require, 'src.research.research')
        local researchCount = 0
        if rok and Research.getCompletedList then
            researchCount = #Research.getCompletedList()
        end
        local firstDeploy = MRP.getDeploymentCount(GameState.planet or 'erebus') <= 1
        local stats = {
            daysSurvived = GameState.day or 0,
            raidsSurvived = GameState.raidsSurvived or 0,
            researchCompleted = researchCount,
            colonistsLost = 0,
            buildingsConstructed = GameState.buildingsConstructed or 0,
            bossDamaged = 0,
            bossDefeated = 0,
            milestonesCompleted = 1,
            firstDeployment = firstDeploy,
        }
        mrpEarned = MRP.calculateRunMRP(stats)
        MRP.earn(mrpEarned)
        MRP.save()
    end
end

---------------------------------------------------------------------------
-- Step - periodic check for defeat condition only
-- Endgame outcomes are triggered externally by the endgame building systems.
---------------------------------------------------------------------------

function GameOver.step(dt)
    if state ~= 'playing' then return end

    checkTimer = checkTimer + dt
    if checkTimer < CHECK_INTERVAL then return end
    checkTimer = 0

    -- Don't check on day 1 (grace period)
    if GameState.day <= 1 then return end

    -- Check if an active SOS beacon might save the colony
    local sosActive = false
    for sid, scomps in ECS.query('sos_beacon') do
        if scomps.sos_beacon.active and scomps.sos_beacon.powered
            and not scomps.sos_beacon.fired then
            sosActive = true
            break
        end
    end
    if sosActive then return end  -- Defer defeat check while beacon active

    -- DEFEAT: all colonists dead
    local aliveCount = 0
    for id, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' then
            aliveCount = aliveCount + 1
        end
    end

    if aliveCount == 0 then
        state = 'defeat'
        reason = string.format('All colonists have perished on day %d.', GameState.day)
        GameState.paused = true

        -- Record legacy
        local lok, Legacy = pcall(require, 'src.sim.colony_legacy')
        if lok and Legacy.recordFallenColony then
            lastRecord = Legacy.recordFallenColony('all colonists dead')
        end

        -- Calculate and award MRP
        local mok, MRP = pcall(require, 'src.sim.mrp')
        if mok then
            local rok, Research = pcall(require, 'src.research.research')
            local researchCount = 0
            if rok and Research.getCompletedList then
                researchCount = #Research.getCompletedList()
            end

            local firstDeploy = MRP.getDeploymentCount(GameState.planet or 'erebus') <= 1
            local stats = {
                daysSurvived = GameState.day or 0,
                raidsSurvived = GameState.raidsSurvived or 0,
                researchCompleted = researchCount,
                colonistsLost = lastRecord and lastRecord.peakPopulation or 0,
                buildingsConstructed = GameState.buildingsConstructed or 0,
                bossDamaged = 0,
                bossDefeated = 0,
                milestonesCompleted = 0,
                firstDeployment = firstDeploy,
            }
            mrpEarned = MRP.calculateRunMRP(stats)
            MRP.earn(mrpEarned)
            if lastRecord then lastRecord.mrpEarned = mrpEarned end
            MRP.save()
        end
    end
end

---------------------------------------------------------------------------
-- Draw - full-screen overlay when game is over
---------------------------------------------------------------------------

function GameOver.draw()
    if state == 'playing' then return end

    local sw, sh = love.graphics.getDimensions()

    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    local midX = sw / 2
    local midY = sh / 2

    if state == 'defeat' then
        -- Title
        love.graphics.setColor(0.8, 0.2, 0.2)
        love.graphics.print('COLONY LOST', midX - 60, midY - 120)

        -- Reason
        love.graphics.setColor(0.7, 0.5, 0.5)
        love.graphics.print(reason, midX - 150, midY - 80)

        -- Stats
        love.graphics.setColor(0.5, 0.5, 0.5)
        local y = midY - 50
        love.graphics.print(string.format('Days survived: %d', GameState.day), midX - 100, y); y = y + 20
        love.graphics.print(string.format('Raids survived: %d', GameState.raidsSurvived or 0), midX - 100, y); y = y + 20
        love.graphics.print(string.format('Buildings constructed: %d', GameState.buildingsConstructed or 0), midX - 100, y); y = y + 20

        -- MRP earned
        y = y + 10
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.print(string.format('REQUISITION POINTS EARNED: %d', mrpEarned), midX - 140, y)

        -- Buttons
        y = y + 40
        love.graphics.setColor(0.3, 0.8, 0.3)
        love.graphics.print('[R] Mammona Redeployment Authorized', midX - 160, y)
        y = y + 25
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('[F9] Load Save', midX - 50, y)

    elseif state == 'victory' then
        -- Outcome title (color varies by type)
        local titleColor = VICTORY_COLORS[victoryType] or { 0.3, 0.8, 0.3 }
        local title = VICTORY_TITLES[victoryType] or 'OUTCOME LOCKED'
        love.graphics.setColor(titleColor)
        love.graphics.print(title, midX - 140, midY - 80)

        -- Reason
        love.graphics.setColor(0.7, 0.75, 0.7)
        love.graphics.print(reason, midX - 220, midY - 40)

        -- Stats
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print(string.format('Days survived: %d', GameState.day), midX - 60, midY + 10)

        local alive = 0
        for _, comps in ECS.query('colonist') do
            if comps.colonist.state ~= 'dead' then alive = alive + 1 end
        end
        love.graphics.print(string.format('Colonists alive: %d', alive), midX - 60, midY + 30)
        love.graphics.print(string.format('Raids survived: %d', GameState.raidsSurvived or 0), midX - 60, midY + 50)
        love.graphics.print(string.format('Colony wealth: %d', GameState.getColonyWealth()), midX - 60, midY + 70)

        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.print(string.format('REQUISITION POINTS EARNED: %d', mrpEarned), midX - 140, midY + 90)

        -- Buttons
        love.graphics.setColor(0.3, 0.8, 0.3)
        love.graphics.print('[R] Mammona Redeployment Authorized', midX - 160, midY + 130)
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('[F9] Load Save', midX - 50, midY + 155)
    end
end

---------------------------------------------------------------------------
-- Input - redeployment or load save
---------------------------------------------------------------------------

function GameOver.keypressed(key)
    if state == 'playing' then return false end

    if (state == 'defeat' or state == 'victory') and key == 'r' then
        -- Redeployment: return to planet select
        state = 'playing'
        GameState.paused = false
        GameState._redeployment = true
        return true
    end

    return false  -- let F9 (load) pass through
end

return GameOver
