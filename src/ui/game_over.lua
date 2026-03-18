-- game_over.lua - Endgame detection and result screen
-- Four endgame outcomes (player-initiated), one defeat condition, endless mode.
--
-- DEFEAT: all colonists dead.
-- OUTCOME 1: Mammona Claim - transmission array charged and final wave survived.
-- OUTCOME 2: Exodus - launch pad shuttle launched with colonists aboard.
-- OUTCOME 3: Seal the Deep - sealing apparatus activated at a precursor site.
-- OUTCOME 4: Mammona Extraction - extraction beacon activated after the boss falls.
-- ENDLESS: after any outcome, SPACE continues. Or set GameState.endlessMode = true
--          at game start to disable endgame checks entirely.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local GameOver = {}

local state = 'playing'  -- 'playing' | 'defeat' | 'victory' | 'rescue'
local victoryType = nil   -- 'mammona_signal' | 'exodus' | 'seal_deep' | 'mammona_extraction'
local reason = ''
local checkTimer = 0
local CHECK_INTERVAL = 2.0

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

    -- DEFEAT: all colonists dead
    local aliveCount = 0
    for id, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' then
            aliveCount = aliveCount + 1
        end
    end

    if aliveCount == 0 then
        -- Mammona Safety Net: one-time rescue drop instead of defeat
        if GameState.mammonaSafetyNet and not GameState._safetyNetUsed then
            GameState._safetyNetUsed = true
            GameState.paused = true

            -- Find two safe spawn points near colony center
            local sx, sy = GameState.startX, GameState.startY
            local sx2, sy2 = sx, sy
            local wok, World = pcall(require, 'src.world.tilemap')
            if wok then
                local found1 = false
                for r = 0, 12 do
                    if found1 then break end
                    for dy = -r, r do
                        if found1 then break end
                        for dx = -r, r do
                            if (math.abs(dx) == r or math.abs(dy) == r)
                                and World.inBounds(sx + dx, sy + dy)
                                and World.isWalkable(sx + dx, sy + dy, 0) then
                                sx, sy = sx + dx, sy + dy
                                found1 = true
                                break
                            end
                        end
                    end
                end
                -- Find a second walkable tile adjacent to the first
                sx2, sy2 = sx, sy
                if found1 then
                    local offsets = { {1,0}, {-1,0}, {0,1}, {0,-1} }
                    for _, off in ipairs(offsets) do
                        local tx, ty = sx + off[1], sy + off[2]
                        if World.inBounds(tx, ty) and World.isWalkable(tx, ty, 0) then
                            sx2, sy2 = tx, ty
                            break
                        end
                    end
                end
            end

            -- Spawn 2 low-skill rescue colonists
            local cok, ColMod = pcall(require, 'src.colonist.colonist')
            if cok then
                ColMod.spawn(sx, sy, 0)
                ColMod.spawn(sx2, sy2, 0)
            end

            -- Notify player
            local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if stOk and Storyteller.logEvent then
                Storyteller.logEvent('rescue',
                    'Mammona Mining detected total crew loss. Emergency reinforcements deployed. Further failure will result in site declassification.')
            end

            -- Switch to rescue state briefly, then resume
            state = 'rescue'
            reason = 'Mammona detected total crew loss. Emergency drop inbound.'
            return
        end

        state = 'defeat'
        reason = string.format('All colonists have perished on day %d.', GameState.day)
        GameState.paused = true

        -- Record fallen colony for legacy system
        local lok, Legacy = pcall(require, 'src.sim.colony_legacy')
        if lok and Legacy.recordFallenColony then
            Legacy.recordFallenColony('all colonists dead')
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

    if state == 'rescue' then
        -- Mammona rescue overlay
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.print('MAMMONA EMERGENCY DROP', midX - 110, midY - 60)

        love.graphics.setColor(0.7, 0.65, 0.5)
        love.graphics.print(reason, midX - 200, midY - 20)

        love.graphics.setColor(0.6, 0.55, 0.4)
        love.graphics.print('Two replacement operatives have been deployed to the colony site.', midX - 230, midY + 10)

        love.graphics.setColor(0.5, 0.4, 0.3)
        love.graphics.print('Further losses will result in site declassification. Mammona will deem this', midX - 260, midY + 40)
        love.graphics.print('planet unprofitable and authorize orbital sterilization. No further aid will come.', midX - 270, midY + 56)

        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('Press SPACE to continue.', midX - 80, midY + 80)
        return
    end

    if state == 'defeat' then
        -- Defeat title
        love.graphics.setColor(0.8, 0.2, 0.2)
        if GameState._safetyNetUsed then
            love.graphics.print('SITE DECLASSIFIED', midX - 75, midY - 80)
        else
            love.graphics.print('COLONY LOST', midX - 50, midY - 80)
        end

        -- Reason
        love.graphics.setColor(0.7, 0.5, 0.5)
        love.graphics.print(reason, midX - 150, midY - 40)

        if GameState._safetyNetUsed then
            love.graphics.setColor(0.5, 0.35, 0.3)
            love.graphics.print('Mammona has deemed this planet unprofitable. Orbital sterilization authorized.', midX - 260, midY - 18)
        end

        -- Stats
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print(string.format('Days survived: %d', GameState.day), midX - 60, midY + 6)
        love.graphics.print(string.format('Raids survived: %d', GameState.raidsSurvived or 0), midX - 60, midY + 26)

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
    end

    -- Continue / load hint
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print('Press SPACE to continue playing (endless mode), or F9 to load a save.', midX - 240, midY + 110)
end

---------------------------------------------------------------------------
-- Input - allow dismissing the game over screen to keep playing (endless)
---------------------------------------------------------------------------

function GameOver.keypressed(key)
    if state == 'playing' then return false end
    if state == 'rescue' and key == 'space' then
        state = 'playing'
        GameState.paused = false
        return true
    end
    if key == 'space' then
        state = 'playing'
        victoryType = nil
        GameState.paused = false
        GameState.endlessMode = true
        return true
    end
    return false  -- let F9 (load) pass through
end

return GameOver
