-- hunting.lua -- Hunting task system
-- Player designates a creature for hunting. A colonist with hunting skill
-- paths to weapon range, then attacks. Kill drops: meat + thermal cores + hide.
-- Integrates with jobs.lua task system and work_ai.lua executor pattern.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Jobs      = require('src.colonist.jobs')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end
local Pathfind  = require('src.util.pathfind')
local Equipment = require('src.colonist.equipment')
local Ranged    = require('src.combat.ranged')
local Creatures = require('src.creatures.creatures')
local Body      = require('src.combat.body')
local Wounds    = require('src.combat.wounds')

local Hunting = {}

---------------------------------------------------------------------------
-- Hide resource: added to GameState.resources if not present
---------------------------------------------------------------------------

-- Ensure hide resource exists
if GameState.resources.hide == nil then
    GameState.resources.hide = 0
end

---------------------------------------------------------------------------
-- Designate a creature for hunting (creates a hunt task)
---------------------------------------------------------------------------

function Hunting.designate(creatureId)
    if not creatureId or not ECS.isAlive(creatureId) then return nil end
    local cr  = ECS.get(creatureId, 'creature')
    local pos = ECS.get(creatureId, 'pos')
    if not cr or not pos then return nil end
    if cr.state == 'dead' then return nil end

    -- Check if already designated
    local allTasks = Jobs.getAllTasks()
    for _, task in pairs(allTasks) do
        if task.type == 'hunt' and task.data.creatureId == creatureId then
            return nil -- already designated
        end
    end

    return Jobs.createTask('hunt', pos.x, pos.y, {
        creatureId = creatureId,
    })
end

---------------------------------------------------------------------------
-- Execute hunt task (called by work_ai when colonist arrives near target)
-- This is the main tick function for an active hunting task.
---------------------------------------------------------------------------

local huntCooldowns = {} -- { [colonistId] = timer }

function Hunting.execute(dt, colonistId, col, task)
    local creatureId = task.data.creatureId
    local cr = ECS.get(creatureId, 'creature')
    local crPos = ECS.get(creatureId, 'pos')

    -- Target dead or gone: complete the task
    if not cr or cr.state == 'dead' or not ECS.isAlive(creatureId) then
        Jobs.completeTask(task.id)
        return
    end

    -- Update task position to creature's current position (it moves)
    if crPos then
        task.x = crPos.x
        task.y = crPos.y
    end

    local colPos = ECS.get(colonistId, 'pos')
    local colPath = ECS.get(colonistId, 'path')
    if not colPos then return end

    local dx = colPos.x - (crPos and crPos.x or task.x)
    local dy = colPos.y - (crPos and crPos.y or task.y)
    local distToTarget = math.sqrt(dx * dx + dy * dy)

    local weaponRange = Equipment.getWeaponRange(colonistId)
    local isRanged = Equipment.isRanged(colonistId)

    -- Tick cooldown
    huntCooldowns[colonistId] = (huntCooldowns[colonistId] or 0) - dt

    -- In range: attack
    if distToTarget <= weaponRange + 0.5 then
        if huntCooldowns[colonistId] <= 0 then
            if isRanged then
                Ranged.fire(colonistId, creatureId)
                huntCooldowns[colonistId] = 1.5
            else
                -- Melee attack
                local damage = Equipment.getWeaponDamage(colonistId)
                local skillLevel = col.skills and col.skills.hunting or 0
                damage = math.floor(damage * (1 + skillLevel * 0.10))

                -- Drug damage buff
                local addOk, AddictionMod = pcall(require, 'src.colonist.addiction')
                if addOk and AddictionMod.getDamageMult then
                    damage = math.floor(damage * AddictionMod.getDamageMult(colonistId))
                end

                local killed = Creatures.damageCreature(creatureId, damage, colonistId)
                huntCooldowns[colonistId] = 0.8

                if killed then
                    -- Hide is dropped by onCreatureKilled hook; don't drop here too
                    Jobs.completeTask(task.id)
                    huntCooldowns[colonistId] = nil
                end
            end
        end
        return
    end

    -- Out of range: re-path to target
    if colPath and not colPath.nodes and crPos then
        local World = require('src.world.tilemap')

        local targetX, targetY = crPos.x, crPos.y
        if isRanged then
            -- Path to a tile within weapon range
            local idealDist = weaponRange - 1
            local len = distToTarget
            if len < 0.01 then len = 1 end
            local nx = dx / len
            local ny = dy / len
            targetX = math.floor(crPos.x + nx * idealDist)
            targetY = math.floor(crPos.y + ny * idealDist)
            targetX = math.max(1, math.min(World.width() - 2, targetX))
            targetY = math.max(1, math.min(World.height() - 2, targetY))
        end

        local pd = colPos.depth or 0
        if World.isWalkable(targetX, targetY, pd) then
            local route = Pathfind.find(colPos.x, colPos.y, targetX, targetY, World, colonistId, pd, pd)
            if route and #route > 0 then
                -- Take a few steps at a time (creature may move)
                local trimmed = {}
                for i = 1, math.min(6, #route) do trimmed[i] = route[i] end
                colPath.nodes = trimmed
                colPath.index = 1
                colPath.moveTimer = 0
            else
                -- Can't path: unclaim task
                Jobs.unclaimTask(task.id)
                col.task = nil
                col.state = 'idle'
                huntCooldowns[colonistId] = nil
            end
        end
    end
end

---------------------------------------------------------------------------
-- Drop hide resource when creature is killed by hunting
---------------------------------------------------------------------------

function Hunting.dropHide(crPos, cr)
    if not crPos then return end
    -- Hide amount scales with creature tier
    local hideAmount = 1
    if cr.tier == 'medium' then hideAmount = 3 end
    if cr.tier == 'megafauna' then hideAmount = 8 end
    local Items = getItems()
    if Items then Items.spawn(crPos.x, crPos.y, 'hide', hideAmount, nil, crPos.depth or 0)
    else GameState.addResource('hide', hideAmount) end
end

---------------------------------------------------------------------------
-- Check if a creature kill was from a hunting task, drop hide
-- Called externally when a creature dies (hook into Creatures.kill)
---------------------------------------------------------------------------

function Hunting.onCreatureKilled(creatureId)
    -- Check if there was an active hunt task for this creature
    local allTasks = Jobs.getAllTasks()
    for _, task in pairs(allTasks) do
        if task.type == 'hunt' and task.data.creatureId == creatureId then
            -- Drop hide
            local crPos = ECS.get(creatureId, 'pos')
            local cr = ECS.get(creatureId, 'creature')
            if crPos and cr then
                Hunting.dropHide(crPos, cr)
            end
            Jobs.completeTask(task.id)
            return
        end
    end
end

return Hunting
