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
