-- jobs.lua — Job/task system
-- Tasks are queued by player actions (designate mine, build order, haul request).
-- Colonists claim tasks based on work priority, skill, and distance.
-- Each task has a type, target position, required skill, and progress.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Pathfind  = require('src.util.pathfind')
local Occupancy = require('src.util.occupancy')
local Zones     = require('src.world.zones')
local sok_snd, Sound = pcall(require, 'src.audio.sound')

local Jobs = {}

---------------------------------------------------------------------------
-- Job type definitions
---------------------------------------------------------------------------

Jobs.TYPES = {
    mine     = { name = 'Mine',     skill = 'mining',   priority = 'mining',   duration = 3.0 },
    build    = { name = 'Build',    skill = 'building',  priority = 'building', duration = 4.0 },
    haul     = { name = 'Haul',     skill = nil,         priority = 'hauling',  duration = 1.0 },
    operate  = { name = 'Operate',  skill = nil,         priority = 'operating',duration = 0 },  -- continuous
    cook     = { name = 'Cook',     skill = 'cooking',   priority = 'cooking',  duration = 0 },
    hunt     = { name = 'Hunt',     skill = 'hunting',   priority = 'hunting',  duration = 2.0 },
    research = { name = 'Research', skill = 'research',  priority = 'research', duration = 0 },
    medical  = { name = 'Medical',  skill = 'medical',   priority = 'medical',  duration = 3.0 },
    clean    = { name = 'Clean',    skill = nil,         priority = 'cleaning', duration = 1.5 },
    harvest  = { name = 'Harvest',  skill = 'cooking',   priority = 'cooking',  duration = 2.0 },
    forage   = { name = 'Forage',   skill = 'cooking',   priority = 'cooking',  duration = 3.0 },
    operate_generator = { name = 'Operate Generator', skill = nil, priority = 'operating', duration = 9999 },
    terraform= { name = 'Terraform', skill = 'mining',    priority = 'mining',   duration = 0 },  -- duration from op def
    eat      = { name = 'Eat',      skill = nil,         priority = '_eat',     duration = 2.0 },
    sleep    = { name = 'Sleep',    skill = nil,         priority = '_sleep',   duration = 0 },
    repair          = { name = 'Repair',          skill = 'building', priority = 'building', duration = 5.0 },
    repair_building = { name = 'Repair Building', skill = 'building', priority = 'building', duration = 5.0 },
    extinguish      = { name = 'Extinguish',      skill = nil,        priority = 'operating', duration = 3.0 },
    revive          = { name = 'Revive',          skill = 'medical',  priority = 'medical',  duration = 8.0 },
    deconstruct     = { name = 'Deconstruct',    skill = 'building', priority = 'building', duration = 3.0 },
    fish            = { name = 'Fish',           skill = 'hunting',  priority = 'hunting',  duration = 5.0 },
    tame            = { name = 'Tame',           skill = 'hunting',  priority = 'hunting',  duration = 4.0 },
}

---------------------------------------------------------------------------
-- Task queue (global pool of available tasks)
---------------------------------------------------------------------------

local taskQueue = {}   -- { [taskId] = task }
local nextTaskId = 1

function Jobs.reset()
    taskQueue = {}
    nextTaskId = 1
end

function Jobs.createTask(jobType, tx, ty, data)
    local def = Jobs.TYPES[jobType]
    if not def then return nil end

    local id = nextTaskId
    nextTaskId = nextTaskId + 1

    data = data or {}
    taskQueue[id] = {
        id       = id,
        type     = jobType,
        def      = def,
        x        = tx,
        y        = ty,
        depth    = data.depth or 0,
        data     = data,           -- extra info (item type, building def, etc.)
        claimed  = nil,           -- entity ID of colonist working this
        progress = 0,
        complete = false,
    }
    return id
end

-- Clear machine.assignee when a machine-bound task ends
local function clearMachineAssignee(task)
    if task.data and task.data.machineEntityId and task.data._assigned then
        local m = ECS.get(task.data.machineEntityId, 'machine')
        if m and m.assignee == task.claimed then
            m.assignee = nil
        end
    end
end

function Jobs.cancelTask(taskId)
    local task = taskQueue[taskId]
    if task then
        -- Refund resources for build tasks that paid at designation
        if task.type == 'build' and task.data and task.data.costPaid then
            for res, amount in pairs(task.data.costPaid) do
                GameState.resources[res] = (GameState.resources[res] or 0) + amount
            end
        end
        -- Unassign generator crew if operating
        if task.type == 'operate_generator' and task.data._assigned and task.claimed then
            local pok, Power = pcall(require, 'src.sim.power')
            if pok and task.data.generatorId then
                Power.unassignWorker(task.data.generatorId, task.claimed)
            end
        end
        -- Clear machine assignee for operate/cook/research tasks
        clearMachineAssignee(task)
        -- Unassign colonist
        if task.claimed then
            local col = ECS.get(task.claimed, 'colonist')
            if col and col.task and col.task.taskId == taskId then
                col.task = nil
                col.state = 'idle'
            end
        end
        taskQueue[taskId] = nil
    end
end

function Jobs.completeTask(taskId)
    local task = taskQueue[taskId]
    if task then
        task.complete = true
        -- Clear machine assignee for operate/cook/research tasks
        clearMachineAssignee(task)
        if task.claimed then
            local col = ECS.get(task.claimed, 'colonist')
            if col and col.task and col.task.taskId == taskId then
                col.task = nil
                col.state = 'idle'
            end
        end
        -- Sound feedback for significant completions
        if sok_snd and (task.type == 'build' or task.type == 'mine' or task.type == 'research') then
            Sound.play('task_complete', task.x, task.y)
        end
        taskQueue[taskId] = nil
    end
end

function Jobs.getTask(taskId)
    return taskQueue[taskId]
end

function Jobs.getAllTasks()
    return taskQueue
end

function Jobs.getUnclaimedCount()
    local n = 0
    for _, t in pairs(taskQueue) do
        if not t.claimed and not t.complete then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Work priority defaults
---------------------------------------------------------------------------

-- Priority columns in order of importance (left = checked first)
Jobs.PRIORITY_COLUMNS = {
    'medical', 'hauling', 'cooking', 'building', 'mining',
    'operating', 'hunting', 'research', 'cleaning',
}

function Jobs.defaultPriorities()
    local p = {}
    for _, col in ipairs(Jobs.PRIORITY_COLUMNS) do
        p[col] = 3  -- default medium priority (1=urgent, 4=low, 0=disabled)
    end
    return p
end

---------------------------------------------------------------------------
-- Find best task for a colonist
---------------------------------------------------------------------------

function Jobs.findBestTask(colonistId)
    local col = ECS.get(colonistId, 'colonist')
    local pos = ECS.get(colonistId, 'pos')
    local priorities = ECS.get(colonistId, 'workPriority')
    if not col or not pos or not priorities then return nil end

    local World = require('src.world.tilemap')
    local restrictedActive = Zones.hasRestrictedZones(pos.depth or 0)

    -- Emergency protocol: override all priorities to 1
    local allPrio1 = false
    local polOk, Policies = pcall(require, 'src.colony.policies')
    if polOk and Policies.isAllPriority1 and Policies.isAllPriority1() then
        allPrio1 = true
    end

    -- Gather unclaimed tasks grouped by priority column
    local buckets = {}  -- { [priorityLevel] = { [column] = { tasks } } }

    for taskId, task in pairs(taskQueue) do
        if not task.claimed and not task.complete
            -- Player-forced tasks may only be picked up by their colonist
            and not (task.data and task.data.forcedFor and task.data.forcedFor ~= colonistId) then
            local prioCol = task.def.priority
            local level = allPrio1 and 1 or priorities[prioCol]

            -- Skip disabled (0) or internal priorities (_eat, _sleep)
            if level and level > 0 and prioCol:sub(1, 1) ~= '_' then
                -- Skill check + trait disabledWork
                local canDo = true
                if task.def.skill then
                    local skillLevel = col.skills[task.def.skill] or 0
                    if skillLevel <= 0 then canDo = false end
                end
                -- Trait disabledWork: pacifist can't hunt, etc.
                if canDo and col.traits then
                    for _, t in ipairs(col.traits) do
                        if t.disabledWork and t.disabledWork == prioCol then
                            canDo = false
                            break
                        end
                    end
                end
                -- Backstory work locks
                if canDo and col.disabledWork then
                    for _, dw in ipairs(col.disabledWork) do
                        if dw == prioCol then
                            canDo = false
                            break
                        end
                    end
                end

                if canDo then
                    if restrictedActive then
                        local taskAllowed = Zones.isTileAllowed(task.x, task.y, task.depth or 0)
                        if taskAllowed and task.data and task.data.toX and task.data.toY then
                            taskAllowed = Zones.isTileAllowed(task.data.toX, task.data.toY, task.data.toDepth or task.depth or 0)
                        end
                        if not taskAllowed then
                            canDo = false
                        end
                    end

                    if not buckets[level] then buckets[level] = {} end
                    if not buckets[level][prioCol] then buckets[level][prioCol] = {} end
                    table.insert(buckets[level][prioCol], task)
                end
            end
        end
    end

    -- Scan priority levels 1→4, within each level scan columns left→right
    for level = 1, 4 do
        if buckets[level] then
            for _, colName in ipairs(Jobs.PRIORITY_COLUMNS) do
                local tasks = buckets[level][colName]
                if tasks and #tasks > 0 then
                    -- Pick nearest task
                    local best, bestDist = nil, math.huge
                    local posDepth = pos.depth or 0
                    for _, task in ipairs(tasks) do
                        local dx = task.x - pos.x
                        local dy = task.y - pos.y
                        local dd = (task.depth or 0) - posDepth
                        local d = dx * dx + dy * dy + dd * dd * 400
                        if d < bestDist then
                            bestDist = d
                            best = task
                        end
                    end
                    if best then return best end
                end
            end
        end
    end

    return nil
end

-- Legacy task finder for slave entities retained only for old save compatibility.
local SLAVE_TASK_TYPES = {
    mine = true, build = true, haul = true, operate = true,
    cook = true, clean = true, operate_generator = true,
}

function Jobs.findTaskForSlave(entityId)
    local pos = ECS.get(entityId, 'pos')
    if not pos then return nil end

    local best, bestDist = nil, math.huge
    for _, task in pairs(taskQueue) do
        if not task.claimed and not task.complete then
            if SLAVE_TASK_TYPES[task.type] then
                local dx = task.x - pos.x
                local dy = task.y - pos.y
                local d = dx * dx + dy * dy
                if d < bestDist then
                    bestDist = d
                    best = task
                end
            end
        end
    end
    return best
end

---------------------------------------------------------------------------
-- Claim / unclaim
---------------------------------------------------------------------------

function Jobs.claimTask(taskId, colonistId)
    local task = taskQueue[taskId]
    if not task or task.claimed then return false end
    task.claimed = colonistId
    return true
end

function Jobs.unclaimTask(taskId)
    local task = taskQueue[taskId]
    if not task then return end
    -- Unassign generator crew when dropping operate_generator task
    if task.type == 'operate_generator' and task.data._assigned and task.claimed then
        local pok, Power = pcall(require, 'src.sim.power')
        if pok and task.data.generatorId then
            Power.unassignWorker(task.data.generatorId, task.claimed)
        end
        task.data._assigned = nil
    end
    -- Clear machine assignee
    clearMachineAssignee(task)
    if task.data then task.data._assigned = nil end
    task.claimed = nil
end

---------------------------------------------------------------------------
-- Force-assign a task to a specific colonist
---------------------------------------------------------------------------

function Jobs.forceAssign(colonistId, jobType, tx, ty, data)
    local col = ECS.get(colonistId, 'colonist')
    local pos = ECS.get(colonistId, 'pos')
    local path = ECS.get(colonistId, 'path')
    if not col or not pos or not path then return nil end

    -- Cancel current task
    if col.task then
        Jobs.unclaimTask(col.task.taskId)
        col.task = nil
    end

    data = data or {}
    data.forcedFor = colonistId

    local taskId = Jobs.createTask(jobType, tx, ty, data)
    if not taskId then return nil end

    -- Pre-claim
    local task = taskQueue[taskId]
    task.claimed = colonistId
    col.task = { taskId = taskId, arrived = false }
    col.state = 'moving_to_task'

    -- Pathfind to task
    local World = require('src.world.tilemap')
    local posDepth = pos.depth or 0
    local taskDepth = data.depth or 0
    local destX, destY = tx, ty

    if not World.isWalkable(destX, destY, posDepth) then
        local dirs = { {-1,0},{1,0},{0,-1},{0,1} }
        local best, bestDist = nil, math.huge
        for _, d in ipairs(dirs) do
            local nx, ny = destX + d[1], destY + d[2]
            if World.inBounds(nx, ny) and World.isWalkable(nx, ny, posDepth) then
                local dist = math.abs(nx - pos.x) + math.abs(ny - pos.y)
                if dist < bestDist then
                    bestDist = dist
                    best = { x = nx, y = ny }
                end
            end
        end
        if best then destX, destY = best.x, best.y end
    end

    local route = Pathfind.find(pos.x, pos.y, destX, destY, World, colonistId, posDepth, taskDepth)
    if route then
        path.nodes = route
        path.index = 1
        path.moveTimer = 0
    else
        -- Can't path — clean up
        Jobs.cancelTask(taskId)
        col.task = nil
        col.state = 'idle'
        return nil
    end

    return taskId
end

---------------------------------------------------------------------------
-- Designation helpers (player creates tasks by designating tiles)
---------------------------------------------------------------------------

function Jobs.designateMine(x, y, depth)
    depth = depth or 0
    local World = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')
    local tile = World.getTile(x, y, depth)
    -- Use the minable property from tile defs instead of a hardcoded whitelist
    local tileProps = Tiles.get(tile)
    if tileProps and tileProps.minable then
        return Jobs.createTask('mine', x, y, { tile = tile, depth = depth })
    end
    return nil
end

function Jobs.designateTerraform(x, y, opId, depth)
    depth = depth or 0
    local tOk, Terraform = pcall(require, 'src.world.terraform')
    if not tOk then return nil end
    if not Terraform.canApply(opId, x, y, depth) then return nil end
    local op = Terraform.OPS[opId]
    return Jobs.createTask('terraform', x, y, {
        opId = opId, duration = op.duration, depth = depth,
    })
end

function Jobs.designateBuild(x, y, buildingId, depth)
    local bok, Building = pcall(require, 'src.building.building')
    if not bok then return nil end
    local def = Building.defs[buildingId]
    if not def then return nil end

    -- Spend resources at designation to prevent over-designation
    local spent = {}
    if def.cost then
        for res, amount in pairs(def.cost) do
            local resourceOk = (GameState.resources[res] or 0) >= amount
            if not resourceOk then
                -- Try storage network as fallback
                local snetOk, SNet = pcall(require, 'src.logistics.storage_network')
                if snetOk then
                    local hasEnough = SNet.query(res, amount, x, y)
                    if hasEnough then
                        local withdrawn = SNet.withdraw(res, amount, x, y)
                        if withdrawn >= amount then
                            spent[res] = amount
                            resourceOk = true
                        end
                    end
                end
            end
            if not resourceOk then
                -- Insufficient — refund what we already deducted
                for r, a in pairs(spent) do
                    GameState.resources[r] = (GameState.resources[r] or 0) + a
                end
                return nil
            end
            if not spent[res] then
                -- Not already handled by storage network withdrawal
                local snet2Ok, SNet2 = pcall(require, 'src.logistics.storage_network')
                if snet2Ok and SNet2.withdraw then
                    SNet2.withdraw(res, amount, x, y)
                else
                    GameState.spendResource(res, amount)
                end
                spent[res] = amount
            end
        end
    end

    return Jobs.createTask('build', x, y, { buildingId = buildingId, costPaid = spent, depth = depth or 0 })
end

function Jobs.designateDeconstruct(entityId, x, y, depth)
    return Jobs.createTask('deconstruct', x, y, {
        entityId = entityId, depth = depth or 0,
    })
end

function Jobs.designateTame(entityId)
    local pos = ECS.get(entityId, 'pos')
    if not pos then return nil end
    local tOk, Taming = pcall(require, 'src.creatures.taming')
    if not tOk then return nil end
    local canTame, err = Taming.canTame(entityId)
    if not canTame then return nil end
    return Jobs.createTask('tame', pos.x, pos.y, {
        creatureId = entityId,
        depth = pos.depth or 0,
    })
end

function Jobs.requestHaul(fromX, fromY, toX, toY, itemId, amount, fromDepth, toDepth)
    return Jobs.createTask('haul', fromX, fromY, {
        toX = toX, toY = toY, toDepth = toDepth or 0,
        itemId = itemId, amount = amount,
        depth = fromDepth or 0,
    })
end

---------------------------------------------------------------------------
-- Periodic cleanup — remove orphaned/stale tasks
---------------------------------------------------------------------------

local cleanupTimer = 0
local CLEANUP_INTERVAL = 10.0  -- seconds

-- Cooking machine types use 'cook' task; others use 'operate'
local COOKING_MACHINES = { kitchen = true, smokehouse = true }

function Jobs.step(dt)
    cleanupTimer = cleanupTimer + dt
    if cleanupTimer < CLEANUP_INTERVAL then return end
    cleanupTimer = 0

    local resOk, Research = pcall(require, 'src.research.research')

    local toRemove = {}  -- set: toRemove[taskId] = true
    for taskId, task in pairs(taskQueue) do
        -- Remove completed tasks (shouldn't linger but safety)
        if task.complete then
            toRemove[taskId] = true
        end

        -- If claimed colonist is dead or gone, unclaim
        if task.claimed then
            local isDead = not ECS.isAlive(task.claimed)
            if not isDead then
                local col = ECS.get(task.claimed, 'colonist')
                isDead = col and col.state == 'dead'
            end
            if isDead then
                clearMachineAssignee(task)
                -- Unassign generator crew (same path as cancelTask)
                if task.type == 'operate_generator' and task.data and task.data._assigned then
                    local pok, Power = pcall(require, 'src.sim.power')
                    if pok and task.data.generatorId then
                        Power.unassignWorker(task.data.generatorId, task.claimed)
                    end
                    task.data._assigned = false
                end
                task.claimed = nil
                task.progress = 0
            end
        end

        -- Stale machine assignments: colonist moved on but task still claimed
        if task.claimed and task.data and task.data.machineEntityId then
            local col = ECS.get(task.claimed, 'colonist')
            if col and (not col.task or col.task.taskId ~= taskId) then
                clearMachineAssignee(task)
                task.claimed = nil
                task.progress = 0
            end
        end

        -- Harvest tasks: remove if crop entity is gone
        if task.type == 'harvest' and task.data.cropId then
            if not ECS.isAlive(task.data.cropId) then
                toRemove[taskId] = true
            end
        end

        -- Mine tasks: remove if tile is already mined
        if task.type == 'mine' and not task.claimed then
            local World = require('src.world.tilemap')
            local Tiles = require('src.world.tiles')
            local tile = World.getTile(task.x, task.y, task.depth)
            if tile ~= Tiles.ROCK and tile ~= Tiles.ICE and tile ~= Tiles.TREE and tile ~= Tiles.ORE_VEIN
               and tile ~= Tiles.DEEP_ROCK and tile ~= Tiles.UNDERGROUND_ROCK
               and tile ~= Tiles.VOLCANIC_ROCK and tile ~= Tiles.DEAD_TREE and tile ~= Tiles.LEAD_ORE
               and tile ~= Tiles.FUNGAL_WALL and tile ~= Tiles.MEMBRANE_WALL and tile ~= Tiles.ORGAN_WALL then
                toRemove[taskId] = true
            end
        end

        -- Machine operate/cook tasks: remove if machine gone or recipe cleared
        if (task.type == 'operate' or task.type == 'cook') and task.data and task.data.machineEntityId then
            if not ECS.isAlive(task.data.machineEntityId) then
                toRemove[taskId] = true
            else
                local m = ECS.get(task.data.machineEntityId, 'machine')
                if not m or not m.recipe then
                    toRemove[taskId] = true
                end
            end
        end

        -- Research tasks: remove if bench gone, unpowered, or no research target
        if task.type == 'research' and task.data and task.data.machineEntityId then
            if not ECS.isAlive(task.data.machineEntityId) then
                toRemove[taskId] = true
            else
                local m = ECS.get(task.data.machineEntityId, 'machine')
                if not m or not m.powered then
                    toRemove[taskId] = true
                elseif resOk and not Research.getCurrent() then
                    toRemove[taskId] = true
                end
            end
        end
    end

    for taskId in pairs(toRemove) do
        Jobs.cancelTask(taskId)
    end

    ---------------------------------------------------------------------------
    -- Create operate/cook/research tasks for unmanned machines
    ---------------------------------------------------------------------------

    -- Build lookup of machines that already have tasks
    local machinesWithTasks = {}
    for _, task in pairs(taskQueue) do
        if not task.complete and task.data and task.data.machineEntityId then
            machinesWithTasks[task.data.machineEntityId] = true
        end
    end

    -- Production machines with a recipe: create operate or cook tasks
    for machineId, comps in ECS.query('machine', 'pos') do
        if not machinesWithTasks[machineId] then
            local mtype = comps.machine.type
            -- Skip research benches (handled below)
            if mtype ~= 'research_bench' and comps.machine.recipe then
                local taskType = COOKING_MACHINES[mtype] and 'cook' or 'operate'
                Jobs.createTask(taskType, comps.pos.x, comps.pos.y, {
                    machineEntityId = machineId,
                    depth = comps.pos.depth or 0,
                })
            end
        end
    end

    -- Research benches: create research tasks when a research target is selected
    local hasResearchTarget = resOk and Research.getCurrent()
    if hasResearchTarget then
        for benchId, comps in ECS.query('machine', 'research_bench', 'pos') do
            if not machinesWithTasks[benchId] and comps.machine.powered then
                Jobs.createTask('research', comps.pos.x, comps.pos.y, {
                    machineEntityId = benchId,
                    depth = comps.pos.depth or 0,
                })
            end
        end
    end
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Jobs.getState()
    -- Serialize only uncompleted tasks (completed ones are about to be cleaned)
    local saved = {}
    for taskId, task in pairs(taskQueue) do
        if not task.complete then
            saved[taskId] = {
                id       = task.id,
                type     = task.type,
                x        = task.x,
                y        = task.y,
                depth    = task.depth,
                data     = task.data,
                claimed  = task.claimed,
                progress = task.progress,
            }
        end
    end
    return {
        tasks      = saved,
        nextTaskId = nextTaskId,
    }
end

function Jobs.loadState(saved)
    if not saved then return end
    nextTaskId = saved.nextTaskId or 1
    taskQueue = {}
    if saved.tasks then
        for taskId, t in pairs(saved.tasks) do
            local def = Jobs.TYPES[t.type]
            if def then
                taskQueue[taskId] = {
                    id       = t.id,
                    type     = t.type,
                    def      = def,
                    x        = t.x,
                    y        = t.y,
                    depth    = t.depth or 0,
                    data     = t.data or {},
                    claimed  = t.claimed,
                    progress = t.progress or 0,
                    complete = false,
                }
            end
        end
    end
end

-- Remap entity IDs after load (claimed colonists, machine refs)
function Jobs.remapEntityIds(idMap)
    for _, task in pairs(taskQueue) do
        if task.claimed and idMap[task.claimed] then
            task.claimed = idMap[task.claimed]
        end
        if task.data then
            if task.data.machineEntityId and idMap[task.data.machineEntityId] then
                task.data.machineEntityId = idMap[task.data.machineEntityId]
            end
            if task.data.cropId and idMap[task.data.cropId] then
                task.data.cropId = idMap[task.data.cropId]
            end
            if task.data.entityId and idMap[task.data.entityId] then
                task.data.entityId = idMap[task.data.entityId]
            end
            if task.data.itemEntityId and idMap[task.data.itemEntityId] then
                task.data.itemEntityId = idMap[task.data.itemEntityId]
            end
            if task.data.creatureId and idMap[task.data.creatureId] then
                task.data.creatureId = idMap[task.data.creatureId]
            end
        end
    end
end

return Jobs
