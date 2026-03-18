-- mental_breaks.lua -- Trait-specific mental breaks + minor stress reactions
-- Registered as an ECS system. Handles break selection, duration, and resolution.
-- Also handles minor stress reactions at morale < 30.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local polOk, Policies = pcall(require, 'src.colony.policies')
local sok_snd, Sound  = pcall(require, 'src.audio.sound')

local MentalBreaks = {}

---------------------------------------------------------------------------
-- Break type definitions
---------------------------------------------------------------------------

local BREAK_TYPES = {
    pyromaniac = {
        id       = 'pyromaniac',
        name     = 'Fire Starting',
        trait    = 'pyromaniac',
        duration = { 30, 90 },
        moralePenalty = 10,
        start = function(id, col, pos)
            -- Ignite a random nearby walkable floor tile
            local World = require('src.world.tilemap')
            local Tiles = require('src.world.tiles')
            local pd = pos.depth or 0
            local targets = {}
            for dy = -3, 3 do
                for dx = -3, 3 do
                    local tx, ty = pos.x + dx, pos.y + dy
                    if World.inBounds(tx, ty) then
                        local tile = World.getTile(tx, ty, pd)
                        if tile == Tiles.FLOOR_WOOD or tile == Tiles.FLOOR_STONE then
                            targets[#targets + 1] = { x = tx, y = ty }
                        end
                    end
                end
            end
            if #targets > 0 then
                local pick = targets[math.random(#targets)]
                local fok, FireMod = pcall(require, 'src.sim.fire')
                if fok then FireMod.ignite(pick.x, pick.y, pd) end
            end
        end,
        tick = function(dt, id, col, pos, breakState)
            -- Periodically start more fires
            breakState._fireTimer = (breakState._fireTimer or 0) + dt
            if breakState._fireTimer >= 10 then
                breakState._fireTimer = 0
                local World = require('src.world.tilemap')
                local Tiles = require('src.world.tiles')
                local pd = pos.depth or 0
                for dy = -3, 3 do
                    for dx = -3, 3 do
                        local tx, ty = pos.x + dx, pos.y + dy
                        if World.inBounds(tx, ty) then
                            local tile = World.getTile(tx, ty, pd)
                            if (tile == Tiles.FLOOR_WOOD or tile == Tiles.FLOOR_STONE)
                                and math.random() < 0.15 then
                                local fok, FireMod = pcall(require, 'src.sim.fire')
                                if fok then FireMod.ignite(tx, ty, pd) end
                                return
                            end
                        end
                    end
                end
            end
        end,
    },
    coward = {
        id       = 'coward',
        name     = 'Panic Flight',
        trait    = 'coward',
        duration = { 30, 60 },
        moralePenalty = 5,
        start = function(id, col, pos)
            -- Path to map edge
            local World    = require('src.world.tilemap')
            local Pathfind = require('src.util.pathfind')
            local w, h = World.width(), World.height()
            -- Pick nearest edge
            local edgeX, edgeY
            local dLeft   = pos.x
            local dRight  = w - 1 - pos.x
            local dTop    = pos.y
            local dBottom = h - 1 - pos.y
            local minD = math.min(dLeft, dRight, dTop, dBottom)
            if minD == dLeft then
                edgeX, edgeY = 1, pos.y
            elseif minD == dRight then
                edgeX, edgeY = w - 2, pos.y
            elseif minD == dTop then
                edgeX, edgeY = pos.x, 1
            else
                edgeX, edgeY = pos.x, h - 2
            end
            -- Clamp and find walkable
            edgeX = math.max(1, math.min(w - 2, edgeX))
            edgeY = math.max(1, math.min(h - 2, edgeY))
            local pd = pos.depth or 0
            if World.isWalkable(edgeX, edgeY, pd) then
                local path = ECS.get(id, 'path')
                if path then
                    local route = Pathfind.find(pos.x, pos.y, edgeX, edgeY, World, id, pd, pd)
                    if route then
                        path.nodes = route
                        path.index = 1
                        path.moveTimer = 0
                    end
                end
            end
        end,
        tick = function() end,
    },
    glutton = {
        id       = 'glutton',
        name     = 'Binge Eating',
        trait    = 'glutton',
        duration = { 30, 60 },
        moralePenalty = 8,
        start = function() end,
        tick = function(dt, id, col, pos, breakState)
            -- Consume food at 5x rate
            breakState._eatTimer = (breakState._eatTimer or 0) + dt
            if breakState._eatTimer >= 1 then
                breakState._eatTimer = 0
                -- 5 units per second vs normal ~0.01/tick
                if GameState.resources.food >= 5 then
                    GameState.resources.food = GameState.resources.food - 5
                    local needs = ECS.get(id, 'needs')
                    if needs then
                        needs.food = math.min(100, needs.food + 10)
                    end
                end
            end
        end,
    },
    berserk = {
        id       = 'berserk',
        name     = 'Berserk Rage',
        trait    = nil,  -- any colonist can go berserk as fallback
        duration = { 30, 120 },
        moralePenalty = 15,
        start = function() end,
        tick = function(dt, id, col, pos, breakState)
            -- Attack nearest entity (colonist or creature) periodically
            breakState._atkTimer = (breakState._atkTimer or 0) + dt
            if breakState._atkTimer < 2 then return end
            breakState._atkTimer = 0

            local bestId, bestDist = nil, math.huge
            -- Check colonists
            for cid, ccomps in ECS.query('pos', 'colonist') do
                if cid ~= id then
                    local cp = ccomps.pos
                    local dx, dy = cp.x - pos.x, cp.y - pos.y
                    local d = dx * dx + dy * dy
                    if d < bestDist then
                        bestDist = d
                        bestId = cid
                    end
                end
            end
            -- Check creatures
            for cid, ccomps in ECS.query('pos', 'creature') do
                local cp = ccomps.pos
                local dx, dy = cp.x - pos.x, cp.y - pos.y
                local d = dx * dx + dy * dy
                if d < bestDist then
                    bestDist = d
                    bestId = cid
                end
            end

            if bestId and bestDist <= 4 then -- within 2 tiles
                -- Deal damage
                local targetCol = ECS.get(bestId, 'colonist')
                if targetCol then
                    targetCol.health = targetCol.health - 8
                    if targetCol.health <= 0 and targetCol.state ~= 'dead' then
                        local cOk, ColMod = pcall(require, 'src.colonist.colonist')
                        if cOk then ColMod.kill(bestId) end
                    end
                else
                    local targetCr = ECS.get(bestId, 'creature')
                    if targetCr then
                        targetCr.health = targetCr.health - 8
                        if targetCr.health <= 0 then
                            local Creatures = require('src.creatures.creatures')
                            Creatures.kill(bestId)
                        end
                    end
                end
            else
                -- Wander toward nearest entity
                if bestId then
                    local tPos = ECS.get(bestId, 'pos')
                    if tPos then
                        local World    = require('src.world.tilemap')
                        local Pathfind = require('src.util.pathfind')
                        local path = ECS.get(id, 'path')
                        if path and not path.nodes then
                            local pd = pos.depth or 0
                            local route = Pathfind.find(pos.x, pos.y, tPos.x, tPos.y, World, id, pd, tPos.depth or 0)
                            if route then
                                local trimmed = {}
                                for i = 1, math.min(4, #route) do trimmed[i] = route[i] end
                                path.nodes = trimmed
                                path.index = 1
                                path.moveTimer = 0
                            end
                        end
                    end
                end
            end
        end,
    },
    ruin_drawn = {
        id       = 'ruin_drawn',
        name     = 'Drawn to the Ruins',
        trait    = 'anomaly_sensitive',
        duration = { 30, 90 },
        moralePenalty = 12,
        start = function(id, col, pos)
            -- Walk toward nearest eldritch node if one exists
            local enOk, EldritchNodes = pcall(require, 'src.creatures.eldritch_nodes')
            if not enOk then return end
            local nearest, bestDist = nil, math.huge
            for nid, ncomps in ECS.query('pos', 'eldritch_growth') do
                local np = ncomps.pos
                local dx, dy = np.x - pos.x, np.y - pos.y
                local d = dx * dx + dy * dy
                if d < bestDist then
                    bestDist = d
                    nearest = np
                end
            end
            if nearest then
                local World    = require('src.world.tilemap')
                local Pathfind = require('src.util.pathfind')
                local path = ECS.get(id, 'path')
                if path then
                    local pd = pos.depth or 0
                    local route = Pathfind.find(pos.x, pos.y, nearest.x, nearest.y, World, id, pd, nearest.depth or 0)
                    if route then
                        path.nodes = route
                        path.index = 1
                        path.moveTimer = 0
                    end
                end
            end
        end,
        tick = function() end,
    },
    signal_listener = {
        id       = 'signal_listener',
        name     = 'Listening to Signals',
        trait    = 'void_touched',
        duration = { 45, 120 },
        moralePenalty = 10,
        start = function(id, col, pos)
            -- Stop moving, stand still
            local path = ECS.get(id, 'path')
            if path then
                path.nodes = nil
                path.index = 1
            end
        end,
        tick = function(dt, id, col, pos, breakState)
            -- Periodically drain morale of nearby colonists (unsettling behavior)
            breakState._pulseTimer = (breakState._pulseTimer or 0) + dt
            if breakState._pulseTimer >= 5 then
                breakState._pulseTimer = 0
                for cid, ccomps in ECS.query('pos', 'needs') do
                    if cid ~= id then
                        local cp = ccomps.pos
                        local dx, dy = cp.x - pos.x, cp.y - pos.y
                        if dx * dx + dy * dy <= 25 then -- within 5 tiles
                            ccomps.needs.morale = math.max(0, ccomps.needs.morale - 2)
                        end
                    end
                end
            end
        end,
    },
    quarantine_panic = {
        id       = 'quarantine_panic',
        name     = 'Quarantine Panic',
        trait    = 'dreamer',
        duration = { 30, 60 },
        moralePenalty = 8,
        start = function(id, col, pos)
            -- Path to map edge (similar to coward panic flight)
            local World    = require('src.world.tilemap')
            local Pathfind = require('src.util.pathfind')
            local w, h = World.width(), World.height()
            local edgeX, edgeY
            local dLeft   = pos.x
            local dRight  = w - 1 - pos.x
            local dTop    = pos.y
            local dBottom = h - 1 - pos.y
            local minD = math.min(dLeft, dRight, dTop, dBottom)
            if minD == dLeft then
                edgeX, edgeY = 1, pos.y
            elseif minD == dRight then
                edgeX, edgeY = w - 2, pos.y
            elseif minD == dTop then
                edgeX, edgeY = pos.x, 1
            else
                edgeX, edgeY = pos.x, h - 2
            end
            edgeX = math.max(1, math.min(w - 2, edgeX))
            edgeY = math.max(1, math.min(h - 2, edgeY))
            local pd = pos.depth or 0
            if World.isWalkable(edgeX, edgeY, pd) then
                local path = ECS.get(id, 'path')
                if path then
                    local route = Pathfind.find(pos.x, pos.y, edgeX, edgeY, World, id, pd, pd)
                    if route then
                        path.nodes = route
                        path.index = 1
                        path.moveTimer = 0
                    end
                end
            end
        end,
        tick = function() end,
    },
}

-- Map trait IDs to break types for quick lookup
local TRAIT_TO_BREAK = {}
for breakId, def in pairs(BREAK_TYPES) do
    if def.trait then
        TRAIT_TO_BREAK[def.trait] = breakId
    end
end

---------------------------------------------------------------------------
-- Minor stress reactions (morale < 30, less severe than full breaks)
---------------------------------------------------------------------------

local STRESS_REACTIONS = {
    complaining = {
        name     = 'Complaining',
        duration = 10,
        apply = function(id, col, needs)
            -- Text bubble handled by renderer checking col._stressReaction
            col._stressReaction = { type = 'complaining', timer = 10 }
        end,
    },
    slacking = {
        name     = 'Slacking Off',
        duration = 30,
        apply = function(id, col, needs)
            col._stressReaction = { type = 'slacking', timer = 30, workSpeedMult = 0.5 }
        end,
    },
    crying = {
        name     = 'Crying',
        duration = 15,
        apply = function(id, col, needs)
            col._stressReaction = { type = 'crying', timer = 15 }
            -- Stand still: clear path
            local path = ECS.get(id, 'path')
            if path then
                path.nodes = nil
                path.index = 1
            end
        end,
    },
}

local STRESS_KEYS = { 'complaining', 'slacking', 'crying' }

---------------------------------------------------------------------------
-- Pick a break type based on colonist traits
---------------------------------------------------------------------------

local function pickBreakType(col)
    -- Check traits for specific break types
    if col.traits then
        local candidates = {}
        for _, t in ipairs(col.traits) do
            if TRAIT_TO_BREAK[t.id] then
                candidates[#candidates + 1] = TRAIT_TO_BREAK[t.id]
            end
        end
        if #candidates > 0 then
            return BREAK_TYPES[candidates[math.random(#candidates)]]
        end
    end
    -- Fallback: berserk
    return BREAK_TYPES.berserk
end

---------------------------------------------------------------------------
-- ECS system: mental break management
---------------------------------------------------------------------------

local function mentalBreakSystem(dt, id, comps)
    local col   = comps.colonist
    local pos   = comps.pos
    local needs = comps.needs

    if col.state == 'dead' then return end

    -----------------------------------------------------------------------
    -- Active mental break
    -----------------------------------------------------------------------
    if col.state == 'mental_break' then
        if not col._mentalBreak then
            -- Martial law blocks mental breaks
            if polOk and Policies.isMentalBreakBlocked and Policies.isMentalBreakBlocked() then
                col.state = 'idle'
                col.sanity = 30
                return
            end

            -- Start a new break
            local breakType = pickBreakType(col)
            local duration = math.random(breakType.duration[1], breakType.duration[2])
            col._mentalBreak = {
                type     = breakType.id,
                timer    = duration,
                maxTime  = duration,
                penalty  = breakType.moralePenalty,
            }
            breakType.start(id, col, pos)
            if sok_snd then Sound.play('alert', pos.x, pos.y) end
        end

        -- Tick the break
        local mb = col._mentalBreak
        mb.timer = mb.timer - dt
        local breakDef = BREAK_TYPES[mb.type]
        if breakDef and breakDef.tick then
            breakDef.tick(dt, id, col, pos, mb)
        end

        -- Break ends
        if mb.timer <= 0 then
            col.sanity = 30
            needs.morale = math.max(0, needs.morale - mb.penalty)
            -- Scar trait: mental break recovery
            local scarOk, ScarTraits = pcall(require, 'src.colonist.scar_traits')
            if scarOk then ScarTraits.onMentalBreakRecovery(id) end
            -- Notify storyteller
            local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if stOk and Storyteller.logEvent then
                Storyteller.logEvent('mental_break_end', (col.name or 'A colonist') .. ' has recovered from a mental break.')
            end
            col._mentalBreak = nil
            col.state = 'idle'
        end
        return
    end

    -----------------------------------------------------------------------
    -- Stress reactions: morale < 30, not already breaking/reacting
    -----------------------------------------------------------------------
    if col._stressReaction then
        col._stressReaction.timer = col._stressReaction.timer - dt
        if col._stressReaction.timer <= 0 then
            col._stressReaction = nil
        end
        return
    end

    if needs.morale < 30 and col.state ~= 'mental_break' then
        -- 0.1% chance per tick
        if math.random() < 0.001 then
            local key = STRESS_KEYS[math.random(#STRESS_KEYS)]
            local reaction = STRESS_REACTIONS[key]
            reaction.apply(id, col, needs)
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function MentalBreaks.registerSystems()
    ECS.addSystem('mental_breaks', { 'colonist', 'pos', 'needs' }, mentalBreakSystem, 12)
end

MentalBreaks.registerSystems()

---------------------------------------------------------------------------
-- Queries for other systems
---------------------------------------------------------------------------

function MentalBreaks.getBreakTypes()
    return BREAK_TYPES
end

function MentalBreaks.getStressReaction(colonistId)
    local col = ECS.get(colonistId, 'colonist')
    return col and col._stressReaction
end

function MentalBreaks.getWorkSpeedMult(colonistId)
    local col = ECS.get(colonistId, 'colonist')
    if col and col._stressReaction and col._stressReaction.workSpeedMult then
        return col._stressReaction.workSpeedMult
    end
    return 1.0
end

return MentalBreaks
