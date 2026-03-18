-- quest_objectives.lua — Objective types and completion checks
-- Each objective type defines: create(params) -> obj, check(obj) -> bool, desc(obj) -> string

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Objectives = {}

---------------------------------------------------------------------------
-- Objective type registry
---------------------------------------------------------------------------

local TYPES = {}

-- Kill N creatures of a given species (or any creature)
TYPES.kill = {
    create = function(params)
        return {
            type     = 'kill',
            species  = params.species,  -- nil = any creature
            target   = params.count or 1,
            current  = 0,
            done     = false,
        }
    end,
    check = function(obj)
        return obj.current >= obj.target
    end,
    desc = function(obj)
        local name = obj.species or 'creature'
        return string.format('Kill %d %s (%d/%d)', obj.target, name, obj.current, obj.target)
    end,
}

-- Gather N of a resource
TYPES.gather = {
    create = function(params)
        return {
            type     = 'gather',
            resource = params.resource,
            target   = params.count or 10,
            current  = 0,
            done     = false,
        }
    end,
    check = function(obj)
        return obj.current >= obj.target
    end,
    desc = function(obj)
        return string.format('Gather %d %s (%d/%d)', obj.target, obj.resource, obj.current, obj.target)
    end,
}

-- Build a specific building
TYPES.build = {
    create = function(params)
        return {
            type     = 'build',
            buildId  = params.buildId,
            target   = params.count or 1,
            current  = 0,
            done     = false,
        }
    end,
    check = function(obj)
        return obj.current >= obj.target
    end,
    desc = function(obj)
        return string.format('Build %d %s (%d/%d)', obj.target, obj.buildId, obj.current, obj.target)
    end,
}

-- Survive for N days
TYPES.survive = {
    create = function(params)
        return {
            type     = 'survive',
            days     = params.days or 5,
            startDay = GameState.day,
            done     = false,
        }
    end,
    check = function(obj)
        return (GameState.day - obj.startDay) >= obj.days
    end,
    desc = function(obj)
        local elapsed = GameState.day - obj.startDay
        return string.format('Survive %d days (%d/%d)', obj.days, math.min(elapsed, obj.days), obj.days)
    end,
}

-- Send an expedition to a destination
TYPES.expedition = {
    create = function(params)
        return {
            type   = 'expedition',
            destId = params.destId, -- nil = any destination
            done   = false,
        }
    end,
    check = function(obj)
        return obj.done
    end,
    desc = function(obj)
        if obj.destId then
            return string.format('Complete an expedition to %s', obj.destId)
        end
        return 'Complete an expedition'
    end,
}

-- Reach a population count
TYPES.population = {
    create = function(params)
        return {
            type   = 'population',
            target = params.count or 5,
            done   = false,
        }
    end,
    check = function(obj)
        local count = ECS.countWith('colonist')
        return count >= obj.target
    end,
    desc = function(obj)
        local count = ECS.countWith('colonist')
        return string.format('Reach %d colonists (%d/%d)', obj.target, math.min(count, obj.target), obj.target)
    end,
}

-- Defend against a raid (triggered when raid resolves)
TYPES.defend = {
    create = function(params)
        return {
            type    = 'defend',
            target  = params.count or 1,
            current = 0,
            done    = false,
        }
    end,
    check = function(obj)
        return obj.current >= obj.target
    end,
    desc = function(obj)
        return string.format('Survive %d raid(s) (%d/%d)', obj.target, obj.current, obj.target)
    end,
}

-- Research a specific tech
TYPES.research = {
    create = function(params)
        return {
            type   = 'research',
            techId = params.techId,
            done   = false,
        }
    end,
    check = function(obj)
        return obj.done
    end,
    desc = function(obj)
        return string.format('Research: %s', obj.techId)
    end,
}

-- Deliver N of a resource (checks current holdings, consumed on quest completion)
TYPES.deliver = {
    volatile = true,  -- re-check every tick; resources can be spent
    create = function(params)
        return {
            type     = 'deliver',
            resource = params.resource,
            target   = params.count or 10,
            done     = false,
        }
    end,
    check = function(obj)
        return (GameState.resources[obj.resource] or 0) >= obj.target
    end,
    desc = function(obj)
        local current = math.min(GameState.resources[obj.resource] or 0, obj.target)
        return string.format('Deliver %d %s (%d/%d)', obj.target, obj.resource, current, obj.target)
    end,
}

local function containmentStat(statKey)
    local cok, Containment = pcall(require, 'src.sim.containment')
    if not cok or not Containment.getStats then return 0 end
    local stats = Containment.getStats() or {}
    return stats[statKey] or 0
end

local function makeContainmentObjective(objType, statKey, label)
    TYPES[objType] = {
        volatile = true,
        create = function(params)
            return {
                type = objType,
                target = params.count or 1,
                baseline = containmentStat(statKey),
                label = label,
                done = false,
            }
        end,
        check = function(obj)
            return math.max(0, containmentStat(statKey) - (obj.baseline or 0)) >= (obj.target or 1)
        end,
        desc = function(obj)
            local current = math.max(0, containmentStat(statKey) - (obj.baseline or 0))
            return string.format('%s (%d/%d)', obj.label or label, math.min(current, obj.target), obj.target)
        end,
    }
end

makeContainmentObjective('recover_subject', 'recovered', 'Recover anomaly subjects')
makeContainmentObjective('study_subject', 'studied', 'Complete containment studies')
makeContainmentObjective('purge_subject', 'purged', 'Purge unstable subjects')
makeContainmentObjective('admit_subject', 'admitted', 'Stabilize and admit survivors')
makeContainmentObjective('transfer_subject', 'transferred', 'Transfer intact subjects')

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Objectives.create(objType, params)
    local def = TYPES[objType]
    if not def then return nil end
    return def.create(params or {})
end

function Objectives.check(obj)
    if not obj or not TYPES[obj.type] then return false end
    local typeDef = TYPES[obj.type]
    -- Volatile objectives (deliver) must re-check every tick
    if typeDef.volatile then
        local result = typeDef.check(obj)
        obj.done = result
        return result
    end
    if obj.done then return true end
    local result = typeDef.check(obj)
    if result then obj.done = true end
    return result
end

function Objectives.describe(obj)
    if not obj or not TYPES[obj.type] then return '???' end
    return TYPES[obj.type].desc(obj)
end

function Objectives.getTypes()
    local out = {}
    for k in pairs(TYPES) do out[#out + 1] = k end
    return out
end

return Objectives
