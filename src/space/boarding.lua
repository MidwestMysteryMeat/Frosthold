-- boarding.lua — Ship boarding combat system
-- Handles boarding initiation (dock alongside, breach), merging enemy
-- ship tiles onto space map, room-by-room combat using existing colonist
-- combat, and capture/surrender/repel outcomes.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Boarding = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local activeBoarding = nil
-- { attackerShipId, defenderShipId, phase, boarders, defenders, timer }
-- phase: 'approaching' | 'breaching' | 'fighting' | 'resolved'

local APPROACH_TIME  = 5   -- seconds to close distance
local BREACH_TIME    = 3   -- seconds to cut through airlock/hull

---------------------------------------------------------------------------
-- Initiate boarding
---------------------------------------------------------------------------

function Boarding.initiate(attackerShipId, defenderShipId)
    if activeBoarding then return false, 'Already boarding' end

    local attackerPos = ECS.get(attackerShipId, 'pos')
    local defenderPos = ECS.get(defenderShipId, 'pos')
    if not attackerPos or not defenderPos then return false, 'Missing positions' end

    -- Must be close enough
    local dx = defenderPos.x - attackerPos.x
    local dy = defenderPos.y - attackerPos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 5 then return false, 'Too far to board (need < 5 tiles)' end

    -- Count boarders (colonists on attacker ship)
    local boarders = {}
    for cid, comps in ECS.query('colonist', 'pos') do
        if not comps.colonist.dead then
            boarders[#boarders + 1] = cid
        end
    end

    -- Count defenders (NPC crew)
    local defenderNpc = ECS.get(defenderShipId, 'npc_ship')
    local defenderCount = defenderNpc and defenderNpc.weaponCount or 2

    activeBoarding = {
        attackerShipId = attackerShipId,
        defenderShipId = defenderShipId,
        phase = 'approaching',
        boarders = boarders,
        defenderCount = defenderCount,
        timer = APPROACH_TIME,
        casualties = { attacker = 0, defender = 0 },
    }

    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        Alerts.send('RAID INCOMING', 'Boarding action initiated! Closing distance...')
    end

    return true
end

---------------------------------------------------------------------------
-- Player ship gets boarded
---------------------------------------------------------------------------

function Boarding.getBoarded(attackerNpcId)
    if activeBoarding then return false end

    local npc = ECS.get(attackerNpcId, 'npc_ship')
    local boarderCount = npc and (npc.weaponCount + 1) or 3

    activeBoarding = {
        attackerShipId = attackerNpcId,
        defenderShipId = nil,  -- player ship
        phase = 'breaching',
        boarders = {},
        defenderCount = 0,
        boarderCount = boarderCount,
        timer = BREACH_TIME,
        playerDefending = true,
        casualties = { attacker = 0, defender = 0 },
    }

    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        local name = npc and npc.name or 'Enemy'
        Alerts.send('RAID INCOMING', name .. ' is breaching your airlock! Prepare to repel boarders!')
    end

    return true
end

---------------------------------------------------------------------------
-- Step (advance boarding phases)
---------------------------------------------------------------------------

function Boarding.step(dt)
    if not activeBoarding then return end

    activeBoarding.timer = activeBoarding.timer - dt
    if activeBoarding.timer > 0 then return end

    if activeBoarding.phase == 'approaching' then
        activeBoarding.phase = 'breaching'
        activeBoarding.timer = BREACH_TIME

        local alOk, Alerts = pcall(require, 'src.ui.alerts')
        if alOk and Alerts.send then
            Alerts.send('RAID INCOMING', 'In position! Breaching hull...')
        end

    elseif activeBoarding.phase == 'breaching' then
        activeBoarding.phase = 'fighting'
        activeBoarding.timer = 0  -- fighting is tick-based, not timer-based

        local alOk, Alerts = pcall(require, 'src.ui.alerts')
        if alOk and Alerts.send then
            Alerts.send('RAID INCOMING', 'Hull breached! Combat in progress!')
        end

    elseif activeBoarding.phase == 'fighting' then
        -- Simplified combat resolution (per-tick)
        -- Real implementation would use existing melee/ranged on merged tilemap
        local attackPower = #activeBoarding.boarders * 10
        local defendPower = activeBoarding.defenderCount * 8

        if activeBoarding.playerDefending then
            -- Player defending: count living colonists
            local livingCrew = 0
            for cid, comps in ECS.query('colonist') do
                if not comps.colonist.dead then livingCrew = livingCrew + 1 end
            end
            defendPower = livingCrew * 12  -- player colonists are better equipped

            -- Boarders take casualties
            local boarderDmg = defendPower * dt * 0.1
            activeBoarding.casualties.attacker = activeBoarding.casualties.attacker + boarderDmg
            local boarderHP = (activeBoarding.boarderCount or 3) * 50 - activeBoarding.casualties.attacker

            -- Defenders take casualties
            local attackerDmg = (activeBoarding.boarderCount or 3) * 8 * dt * 0.1
            activeBoarding.casualties.defender = activeBoarding.casualties.defender + attackerDmg

            -- Damage random crew member
            for cid, comps in ECS.query('colonist') do
                if not comps.colonist.dead and math.random() < 0.05 * dt then
                    comps.colonist.health = math.max(1, (comps.colonist.health or 100) - 5)
                    break
                end
            end

            if boarderHP <= 0 then
                Boarding.resolve('repelled')
            end
        else
            -- Player attacking NPC ship
            local defenderHP = activeBoarding.defenderCount * 50 - activeBoarding.casualties.defender
            activeBoarding.casualties.defender = activeBoarding.casualties.defender + attackPower * dt * 0.1
            activeBoarding.casualties.attacker = activeBoarding.casualties.attacker + defendPower * dt * 0.1

            if defenderHP <= 0 then
                Boarding.resolve('captured')
            end

            -- Check if attacker casualties are too high (50% = retreat)
            local attackerMaxHP = #activeBoarding.boarders * 50
            if activeBoarding.casualties.attacker > attackerMaxHP * 0.5 then
                Boarding.resolve('retreated')
            end
        end
    end
end

---------------------------------------------------------------------------
-- Resolve boarding
---------------------------------------------------------------------------

function Boarding.resolve(outcome)
    if not activeBoarding then return end

    local alOk, Alerts = pcall(require, 'src.ui.alerts')

    if outcome == 'captured' then
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', 'Enemy ship captured! Salvaging cargo and materials.')
        end
        -- Loot the captured ship
        if activeBoarding.defenderShipId and ECS.isAlive(activeBoarding.defenderShipId) then
            local pos = ECS.get(activeBoarding.defenderShipId, 'pos')
            if pos then
                local iok, Items = pcall(require, 'src.world.items')
                if iok and Items.spawn then
                    Items.spawn(math.floor(pos.x), math.floor(pos.y), 'steel', math.random(10, 30))
                    Items.spawn(math.floor(pos.x), math.floor(pos.y), 'components', math.random(5, 15))
                    Items.spawn(math.floor(pos.x), math.floor(pos.y), 'fuel', math.random(10, 30))
                end
            end
            -- Destroy captured NPC ship
            local scOk, ShipCombat = pcall(require, 'src.space.ship_combat')
            if scOk and ShipCombat.destroyShip then
                ShipCombat.destroyShip(activeBoarding.defenderShipId)
            else
                ECS.destroy(activeBoarding.defenderShipId)
            end
        end
        -- Credits reward
        GameState.credits = GameState.credits + math.random(50, 150)

    elseif outcome == 'repelled' then
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', 'Boarders repelled! Your crew held the ship.')
        end
        -- Destroy or damage the NPC attacker
        if activeBoarding.attackerShipId and ECS.isAlive(activeBoarding.attackerShipId) then
            local npc = ECS.get(activeBoarding.attackerShipId, 'npc_ship')
            if npc then npc.aiState = 'flee' end
        end

    elseif outcome == 'retreated' then
        if alOk and Alerts.send then
            Alerts.send('RAID INCOMING', 'Boarding failed! Too many casualties, retreating.')
        end

    elseif outcome == 'surrendered' then
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', 'Enemy surrenders! Taking what we can carry.')
        end
        GameState.credits = GameState.credits + math.random(30, 80)
    end

    activeBoarding = nil
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function Boarding.isActive()
    return activeBoarding ~= nil
end

function Boarding.getPhase()
    return activeBoarding and activeBoarding.phase
end

function Boarding.isPlayerDefending()
    return activeBoarding and activeBoarding.playerDefending
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Boarding.getState()
    return activeBoarding
end

function Boarding.loadState(state)
    activeBoarding = state
end

return Boarding
