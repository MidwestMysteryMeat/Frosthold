-- test_jobs.lua — Job/task queue tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Jobs')

T.test('createTask returns incrementing IDs', function()
    H.resetAll()
    local Jobs = require('src.colonist.jobs')
    local id1 = Jobs.createTask('mine', 10, 10)
    local id2 = Jobs.createTask('build', 11, 11, { buildingId = 'wall_wood' })
    T.notnil(id1, 'first task created')
    T.notnil(id2, 'second task created')
    T.neq(id1, id2, 'different IDs')
end)

T.test('getTask returns correct task', function()
    H.resetAll()
    local Jobs = require('src.colonist.jobs')
    local tid = Jobs.createTask('mine', 15, 15)
    local task = Jobs.getTask(tid)
    T.notnil(task)
    T.eq(task.type, 'mine')
    T.eq(task.x, 15)
    T.eq(task.y, 15)
    T.eq(task.progress, 0)
    T.eq(task.complete, false)
    T.isnil(task.claimed)
end)

T.test('claimTask assigns colonist', function()
    H.resetAll()
    local Jobs = require('src.colonist.jobs')
    local tid = Jobs.createTask('mine', 10, 10)
    local ok = Jobs.claimTask(tid, 42)
    T.eq(ok, true, 'claim succeeded')
    local task = Jobs.getTask(tid)
    T.eq(task.claimed, 42)
end)

T.test('claimTask fails if already claimed', function()
    H.resetAll()
    local Jobs = require('src.colonist.jobs')
    local tid = Jobs.createTask('mine', 10, 10)
    Jobs.claimTask(tid, 42)
    local ok = Jobs.claimTask(tid, 43)
    T.eq(ok, false, 'second claim failed')
end)

T.test('unclaimTask releases task', function()
    H.resetAll()
    local Jobs = require('src.colonist.jobs')
    local tid = Jobs.createTask('mine', 10, 10)
    Jobs.claimTask(tid, 42)
    Jobs.unclaimTask(tid)
    local task = Jobs.getTask(tid)
    T.isnil(task.claimed, 'unclaimed')
end)

T.test('completeTask removes from queue', function()
    H.resetAll()
    local Jobs = require('src.colonist.jobs')
    local tid = Jobs.createTask('mine', 10, 10)
    Jobs.completeTask(tid)
    T.isnil(Jobs.getTask(tid), 'task removed after completion')
end)

T.test('cancelTask removes from queue', function()
    H.resetAll()
    local Jobs = require('src.colonist.jobs')
    local tid = Jobs.createTask('mine', 10, 10)
    Jobs.cancelTask(tid)
    T.isnil(Jobs.getTask(tid), 'task removed after cancel')
end)

T.test('getUnclaimedCount returns correct count', function()
    H.resetAll()
    local Jobs = require('src.colonist.jobs')
    T.eq(Jobs.getUnclaimedCount(), 0, 'empty at start')
    Jobs.createTask('mine', 10, 10)
    Jobs.createTask('mine', 11, 11)
    T.eq(Jobs.getUnclaimedCount(), 2, 'two unclaimed')
    local tid = Jobs.createTask('mine', 12, 12)
    Jobs.claimTask(tid, 1)
    T.eq(Jobs.getUnclaimedCount(), 2, 'still two unclaimed after claiming third')
end)

T.test('defaultPriorities has all columns', function()
    local Jobs = require('src.colonist.jobs')
    local p = Jobs.defaultPriorities()
    for _, col in ipairs(Jobs.PRIORITY_COLUMNS) do
        T.notnil(p[col], 'has priority for ' .. col)
        T.eq(p[col], 3, 'default is 3 for ' .. col)
    end
end)

T.test('TYPES has expected job definitions', function()
    local Jobs = require('src.colonist.jobs')
    local expected = { 'mine', 'build', 'haul', 'operate', 'cook', 'hunt', 'research', 'medical', 'clean' }
    for _, jtype in ipairs(expected) do
        T.notnil(Jobs.TYPES[jtype], 'job type exists: ' .. jtype)
        T.notnil(Jobs.TYPES[jtype].name, 'job has name: ' .. jtype)
    end
end)

T.test('findBestTask picks nearest unclaimed', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Jobs = require('src.colonist.jobs')

    -- Create colonist at 64,64
    local cid = H.spawnTestColonist(64, 64)

    -- Create two mine tasks, one near one far
    Jobs.createTask('mine', 65, 64)  -- 1 tile away
    Jobs.createTask('mine', 80, 80)  -- ~23 tiles away

    local best = Jobs.findBestTask(cid)
    T.notnil(best, 'found a task')
    T.eq(best.x, 65, 'picked nearer task')
    T.eq(best.y, 64)
end)

T.test('a colonist with zero medical skill can still claim medical tasks', function()
    H.resetAll()
    local Jobs = require('src.colonist.jobs')

    -- Three random starting colonists frequently all roll medical 0. The hard
    -- skill gate meant nobody could ever tend a wound, so injuries went septic
    -- and killed colonists beside idle housemates.
    local cid = H.spawnTestColonist(64, 64, {
        skills = { mining = 0, building = 0, cooking = 0,
                   hunting = 0, research = 0, medical = 0 },
    })

    Jobs.createTask('medical', 65, 64, { patientId = cid })
    local best = Jobs.findBestTask(cid)
    T.notnil(best, 'unskilled colonist may still tend wounds')
    T.eq(best.type, 'medical', 'and the task offered is the medical one')

    -- The skill gate still applies to ordinary work
    Jobs.createTask('mine', 65, 64)
    local mineTask = nil
    for _, t in pairs(Jobs.getAllTasks()) do
        if t.type == 'mine' then mineTask = t end
    end
    T.notnil(mineTask, 'mine task was created')
    Jobs.claimTask(best.id, cid)
    T.eq(Jobs.findBestTask(cid), nil, 'mining still requires mining skill')
end)

T.test('a colonist standing on its own task tile still executes it', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Jobs = require('src.colonist.jobs')
    local Wounds = require('src.combat.wounds')
    local WorkAI = require('src.colonist.work_ai')
    local World = require('src.world.tilemap')
    local GameState = require('src.game_state')

    World.init(32, 32)
    require('src.sim.lighting').init(World)
    require('src.sim.thermal').init(World)
    GameState.hour = 10  -- daytime work block

    -- A wounded colonist tends itself. Pathfind.find returns {} when the mover
    -- is already on the goal tile, and `{}` is truthy, so the colonist used to
    -- wait forever for a movement that had nothing to do -- while still
    -- holding the task claim, so nobody else could tend it either.
    local patient = H.spawnTestColonist(10, 10, {
        skills = { mining = 0, building = 0, cooking = 0,
                   hunting = 0, research = 0, medical = 0 },
    })
    require('src.util.occupancy').rebuild()
    Wounds.apply(patient, 'torso', 'cut', 0.8)
    local wound = ECS.get(patient, 'wounds').list[1]
    T.eq(wound.treatment, 'untreated', 'wound starts untreated')

    Wounds.requestMedicalTask(patient)
    WorkAI.registerSystems()
    require('src.colonist.colonist').registerSystems()
    for _ = 1, 200 do
        ECS.update(0.05)
        if wound.treatment ~= 'untreated' then break end
    end
    T.eq(wound.treatment, 'bandaged', 'self-tended wound reaches bandaged')
end)
