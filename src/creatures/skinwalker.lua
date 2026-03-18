-- skinwalker.lua — Skinwalker event system
-- A predatory entity that mimics colonist voices/signals to lure individuals
-- outside the base, then attacks. Triggered by storyteller as a rare event.
-- Detection: anomaly_sensitive colonists resist the lure.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Creatures = require('src.creatures.creatures')

local Skinwalker = {}

---------------------------------------------------------------------------
-- Active skinwalker hunts
-- { [huntId] = { entityId, targetId, phase, timer, lureX, lureY } }
---------------------------------------------------------------------------

local activeHunts = {}
local nextHuntId = 1

-- Phases: 'calling' -> 'luring' -> 'attacking' -> done
local CALL_DURATION   = 30   -- seconds of eerie calls before selecting a victim
local LURE_TIMEOUT    = 60   -- seconds for victim to reach lure point
local ATTACK_SPECIES  = { 'stalker', 'alpha_stalker', 'fleshwalker' }

---------------------------------------------------------------------------
-- Start a skinwalker event (called by storyteller or manually)
---------------------------------------------------------------------------

function Skinwalker.startHunt()
    -- Find map edge position for the skinwalker
    local mapW = GameState.mapWidth
    local mapH = GameState.mapHeight
    local wok, World = pcall(require, 'src.world.tilemap')
    if not wok then return nil end

    -- Pick a random edge
    local edge = math.random(4)
    local sx, sy
    if edge == 1 then     -- top
        sx = math.random(10, mapW - 10); sy = 2
    elseif edge == 2 then -- bottom
        sx = math.random(10, mapW - 10); sy = mapH - 3
    elseif edge == 3 then -- left
        sx = 2; sy = math.random(10, mapH - 10)
    else                  -- right
        sx = mapW - 3; sy = math.random(10, mapH - 10)
    end

    -- Spawn the skinwalker creature (hidden until it attacks)
    local species = ATTACK_SPECIES[math.random(#ATTACK_SPECIES)]
    local entityId = Creatures.spawn(species, sx, sy)
    if not entityId then return nil end

    -- Mark as skinwalker (hidden from normal creature AI initially)
    local cr = ECS.get(entityId, 'creature')
    if cr then
        cr._skinwalker = true
        cr._passive = true  -- won't attack normally until lure phase ends
    end

    -- Choose a lure point partway between skinwalker and colony center
    local cx, cy = GameState.startX, GameState.startY
    local lureX = math.floor(sx + (cx - sx) * 0.6)
    local lureY = math.floor(sy + (cy - sy) * 0.6)

    local huntId = nextHuntId
    nextHuntId = nextHuntId + 1

    activeHunts[huntId] = {
        entityId = entityId,
        targetId = nil,      -- selected during 'calling' phase
        phase    = 'calling',
        timer    = CALL_DURATION,
        lureX    = lureX,
        lureY    = lureY,
        species  = species,
    }

    -- Log the event
    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.logEvent then
        Storyteller.logEvent('skinwalker_calls', { x = sx, y = sy })
    end

    return huntId
end

---------------------------------------------------------------------------
-- Select a lure victim — colonists with anomaly_sensitive trait resist
---------------------------------------------------------------------------

local function selectVictim(hunt)
    local candidates = {}
    for id, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.state ~= 'downed' then
            -- Check anomaly_sensitive trait: immune to lure
            local immune = false
            if col.traits then
                for _, t in ipairs(col.traits) do
                    if t.id == 'anomaly_sensitive' then
                        immune = true
                        break
                    end
                end
            end
            if not immune then
                candidates[#candidates + 1] = { id = id, pos = comps.pos }
            end
        end
    end
    if #candidates == 0 then return nil end

    -- Pick the most isolated colonist (furthest from colony center)
    local cx, cy = GameState.startX, GameState.startY
    local best, bestDist = nil, 0
    for _, c in ipairs(candidates) do
        local dist = math.abs(c.pos.x - cx) + math.abs(c.pos.y - cy)
        if dist > bestDist then
            best = c.id
            bestDist = dist
        end
    end
    return best
end

---------------------------------------------------------------------------
-- Step — process active hunts
---------------------------------------------------------------------------

function Skinwalker.step(dt)
    local toRemove = {}
    for huntId, hunt in pairs(activeHunts) do
        -- Check if skinwalker entity still alive
        if not ECS.isAlive(hunt.entityId) then
            toRemove[#toRemove + 1] = huntId
            goto nextHunt
        end

        hunt.timer = hunt.timer - dt

        if hunt.phase == 'calling' then
            -- Eerie calls phase: audio/visual cue, then pick victim
            if hunt.timer <= 0 then
                local victim = selectVictim(hunt)
                if victim then
                    hunt.targetId = victim
                    hunt.phase = 'luring'
                    hunt.timer = LURE_TIMEOUT

                    -- Force victim to walk toward lure point
                    local col = ECS.get(victim, 'colonist')
                    if col then
                        col.state = 'moving'
                        col.task = nil
                    end
                    local pos = ECS.get(victim, 'pos')
                    if pos then
                        pos.targetX = hunt.lureX
                        pos.targetY = hunt.lureY
                    end

                    -- Morale penalty: unease
                    local needs = ECS.get(victim, 'needs')
                    if needs then
                        needs.morale = math.max(0, needs.morale - 15)
                    end
                else
                    -- No valid targets, cancel hunt
                    local cr = ECS.get(hunt.entityId, 'creature')
                    if cr then cr._passive = false end
                    toRemove[#toRemove + 1] = huntId
                end
            end

        elseif hunt.phase == 'luring' then
            -- Wait for victim to approach lure point (or timeout)
            if hunt.targetId and ECS.isAlive(hunt.targetId) then
                local vPos = ECS.get(hunt.targetId, 'pos')
                if vPos then
                    local dx = vPos.x - hunt.lureX
                    local dy = vPos.y - hunt.lureY
                    local dist = math.abs(dx) + math.abs(dy)
                    if dist <= 5 then
                        -- Close enough: attack
                        hunt.phase = 'attacking'
                        hunt.timer = 0
                    end
                end
            end

            if hunt.timer <= 0 then
                -- Timeout: skinwalker goes hostile anyway
                hunt.phase = 'attacking'
                hunt.timer = 0
            end

        elseif hunt.phase == 'attacking' then
            -- Reveal skinwalker: remove passive flag, target the victim
            local cr = ECS.get(hunt.entityId, 'creature')
            if cr then
                cr._passive = false
                cr._skinwalker = false
                if hunt.targetId and ECS.isAlive(hunt.targetId) then
                    cr.target = hunt.targetId
                end
            end

            -- Hope penalty
            local hok, Hope = pcall(require, 'src.colony.hope')
            if hok then Hope.addHope(-10, 'skinwalker attack') end

            toRemove[#toRemove + 1] = huntId
        end

        ::nextHunt::
    end

    for _, huntId in ipairs(toRemove) do
        activeHunts[huntId] = nil
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Skinwalker.hasActiveHunt()
    return next(activeHunts) ~= nil
end

function Skinwalker.getActiveHunts()
    return activeHunts
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Skinwalker.getState()
    return {
        activeHunts = activeHunts,
        nextHuntId  = nextHuntId,
    }
end

function Skinwalker.loadState(saved)
    if not saved then return end
    activeHunts = saved.activeHunts or {}
    nextHuntId  = saved.nextHuntId or 1
end

return Skinwalker
