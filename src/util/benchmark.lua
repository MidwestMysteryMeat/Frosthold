local ECS         = require('src.ecs.ecs')
local GameState   = require('src.game_state')
local Tilemap     = require('src.world.tilemap')
local Weather     = require('src.weather.weather')
local Elastic     = require('src.sim.elastic_difficulty')
local Quotas      = require('src.sim.quotas')
local Raids       = require('src.sim.raids')
local Ordnance    = require('src.combat.ordnance')
local Containment = require('src.sim.containment')
local Profiler    = require('src.util.profiler')
local Tuning      = require('src.sim.tuning')

local Benchmark = {}

local DEFAULT_SEED = 1337

local function shallowCopy(src)
    local out = {}
    for k, v in pairs(src or {}) do
        out[k] = v
    end
    return out
end

local function listCopy(src)
    local out = {}
    for i = 1, #(src or {}) do
        out[i] = src[i]
    end
    return out
end

local function sortedPairsByValue(map)
    local out = {}
    for key, value in pairs(map or {}) do
        out[#out + 1] = { key = key, value = value }
    end
    table.sort(out, function(a, b)
        if a.value == b.value then
            return tostring(a.key) < tostring(b.key)
        end
        return a.value > b.value
    end)
    return out
end

local function spawnColonist(x, y, opts)
    opts = opts or {}
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, prevX = x, prevY = y, depth = opts.depth or 0 })
    ECS.set(id, 'colonist', {
        name = opts.name or ('Bench' .. tostring(id)),
        state = opts.state or 'idle',
        task = opts.task,
        health = opts.health or 100,
        maxHealth = opts.maxHealth or 100,
    })
    ECS.set(id, 'needs', {
        food = opts.food or 80,
        warmth = opts.warmth or 80,
        rest = opts.rest or 80,
        morale = opts.morale or 65,
    })
    return id
end

local function spawnMachine(active)
    local id = ECS.spawn()
    ECS.set(id, 'machine', { active = active ~= false })
    return id
end

local function spawnDeepDrill(active)
    local id = ECS.spawn()
    ECS.set(id, 'deep_drill', { active = active ~= false })
    return id
end

local function spawnContainmentCell(x, y, cellType)
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, prevX = x, prevY = y, depth = 0 })
    ECS.set(id, 'containment_cell', {
        cellType = cellType or 'cell',
        mode = 'study',
        subjectId = nil,
        currentRisk = 0,
        incidentCooldown = 0,
    })
    return id
end

local function resetCore(seed)
    math.randomseed(seed or DEFAULT_SEED)
    GameState.init()
    GameState.phase = 'playing'
    GameState.paused = false
    ECS.init()
    Tilemap.init(64, 64)
    Weather.init()
    Elastic.init()
    Quotas.init()
    Raids.init()
    Ordnance.init()
    Containment.init()
    Profiler.reset()
    Profiler.setEnabled(true)
end

local function advanceScenarioDay(delta)
    delta = delta or 1
    GameState.day = (GameState.day or 1) + delta
    GameState.hour = ((GameState.hour or 6) + delta * 6) % 24
end

local function runCommonFrame(dt)
    Profiler.call('Elastic:Step', Elastic.step, dt)
    Profiler.call('Weather:Step', Weather.step, dt)
    Profiler.call('Quotas:Step', Quotas.step, dt)
end

local scenarios = {
    early_colony = {
        frames = 6,
        dt = 5.0,
        setup = function()
            GameState.day = 3
            GameState.resources.food = 24
            GameState.resources.fuel = 12
            GameState.resources.metal = 4
            spawnColonist(12, 12, { task = 'mine', morale = 62 })
            spawnColonist(13, 12, { task = 'haul', morale = 68 })
            spawnColonist(12, 13, { morale = 71 })
        end,
        step = function(dt)
            runCommonFrame(dt)
            Profiler.call('Raids:Pick', Raids.pickRaidType)
            Profiler.call('Wealth:Calc', GameState.getColonyWealth)
            advanceScenarioDay(1)
        end,
        check = function()
            return Quotas.getCurrentQuota() ~= nil
        end,
    },
    mid_colony_logistics = {
        frames = 8,
        dt = 5.0,
        setup = function()
            GameState.day = 18
            GameState.resources.food = 90
            GameState.resources.fuel = 45
            GameState.resources.metal = 80
            GameState.resources.components = 10
            for i = 1, 8 do
                spawnColonist(10 + (i % 4), 10 + math.floor(i / 4), {
                    task = (i % 2 == 0) and 'haul' or 'build',
                    morale = 58 + i,
                })
            end
            for i = 1, 5 do
                spawnMachine(true)
            end
            for i = 1, 2 do
                spawnDeepDrill(true)
            end
        end,
        step = function(dt)
            runCommonFrame(dt)
            Profiler.call('Raids:Activity', Raids.getActivityLevel)
            Profiler.call('Raids:Heat', Raids.getHeatSignature)
            Profiler.call('Raids:Pick', Raids.pickRaidType)
            Profiler.call('Wealth:Calc', GameState.getColonyWealth)
            advanceScenarioDay(1)
        end,
        check = function()
            return Raids.getActivityLevel() >= 8
        end,
    },
    late_colony_containment = {
        frames = 10,
        dt = 5.0,
        setup = function()
            GameState.day = 42
            GameState.resources.food = 130
            GameState.resources.fuel = 70
            GameState.resources.metal = 140
            GameState.resources.components = 18
            for i = 1, 12 do
                spawnColonist(20 + (i % 6), 18 + math.floor(i / 6), {
                    task = (i % 3 == 0) and 'research' or 'haul',
                    morale = 52 + i,
                    health = 92 + (i % 4),
                })
            end
            for i = 1, 6 do
                spawnMachine(true)
            end
            for i = 1, 3 do
                spawnDeepDrill(true)
            end

            local cellA = spawnContainmentCell(30, 30, 'cell')
            local cellB = spawnContainmentCell(31, 30, 'locker')
            local cellC = spawnContainmentCell(32, 30, 'cell')

            Containment.registerFieldSubject('latent_survivor', { source = 'sealed chamber' })
            Containment.registerFieldSubject('signal_idol', { source = 'artifact vault' })
            Containment.registerFieldSubject('vessel_host', { source = 'deep shaft' })
            Containment.assignNextSubject(cellA)
            Containment.assignNextSubject(cellB)
            Containment.assignNextSubject(cellC)

            Ordnance.spawnBioCloud(28, 28, 0, 2, 18, 'ice_plague', 0.25)
            Ordnance.spawnNapalmField(34, 28, 0, 2, 12, 0.8)
        end,
        step = function(dt)
            runCommonFrame(dt)
            Profiler.call('Containment:Step', Containment.step, dt)
            Profiler.call('Ordnance:Step', Ordnance.step, dt)
            Profiler.call('Containment:Interest', Containment.getSubjectInterest)
            Profiler.call('Raids:Pick', Raids.pickRaidType)
            advanceScenarioDay(1)
        end,
        check = function()
            return Containment.getSubjectInterest() > 0
        end,
    },
}

Benchmark.SCENARIOS = scenarios

function Benchmark.getScenarioNames()
    local names = {}
    for name in pairs(scenarios) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function Benchmark.runScenario(name, opts)
    opts = opts or {}
    local scenario = scenarios[name]
    if not scenario then
        return nil, 'Unknown benchmark scenario: ' .. tostring(name)
    end

    local savedOverrides = Tuning.getOverrides()
    local ok, result = pcall(function()
        if opts.tuningOverrides then
            Tuning.applyOverrides(opts.tuningOverrides)
        end

        resetCore(opts.seed or DEFAULT_SEED)
        if scenario.setup then
            scenario.setup(opts)
        end

        local frames = opts.frames or scenario.frames or 6
        local dt = opts.dt or scenario.dt or 5.0
        for frame = 1, frames do
            local token = Profiler.begin('Sim Tick')
            scenario.step(dt, frame, opts)
            Profiler.finish(token)
            if scenario.check and not scenario.check(frame, opts) then
                error('Benchmark invariant failed for ' .. name .. ' at frame ' .. frame)
            end
        end

        return {
            name = name,
            frames = frames,
            dt = dt,
            frame = Profiler.getFrameSummary(),
            entries = Profiler.getEntries(),
            categories = Profiler.getCategorySummaries(),
            quotaSummary = Quotas.getStatusSummary(),
            subjectInterest = Containment.getSubjectInterest(),
            day = GameState.day,
        }
    end)

    Tuning.replaceOverrides(savedOverrides)
    if not ok then
        return nil, result
    end
    return result
end

function Benchmark.runSoak(name, opts)
    opts = opts or {}
    local runs = {}
    local iterations = math.max(1, math.floor(opts.iterations or 3))
    local totalFrameMs = 0
    for i = 1, iterations do
        local runOpts = shallowCopy(opts)
        runOpts.iterations = nil
        runOpts.seed = (opts.seed or DEFAULT_SEED) + i - 1
        local result, err = Benchmark.runScenario(name, runOpts)
        if not result then
            return nil, err
        end
        runs[#runs + 1] = result
        totalFrameMs = totalFrameMs + ((result.frame and result.frame.frameMs) or 0)
    end

    return {
        name = name,
        iterations = iterations,
        averageFrameMs = totalFrameMs / math.max(1, iterations),
        runs = listCopy(runs),
    }
end

function Benchmark.summarizeSoak(soak, opts)
    opts = opts or {}
    local budgets = opts.budgets or {}
    local avgBudget = budgets.averageFrameMs or 8.0
    local peakBudget = budgets.peakFrameMs or 20.0
    local hotspotCounts = {}
    local categoryPeaks = {}
    local flags = {}
    local minFrameMs = math.huge
    local maxFrameMs = 0
    local totalInnerMs = 0
    local totalDays = 0
    local runs = soak and soak.runs or {}

    for i = 1, #runs do
        local run = runs[i]
        local frame = run.frame or {}
        local frameMs = frame.frameMs or 0
        local innerMs = frame.innerMs or 0
        minFrameMs = math.min(minFrameMs, frameMs)
        maxFrameMs = math.max(maxFrameMs, frameMs)
        totalInnerMs = totalInnerMs + innerMs
        totalDays = totalDays + (run.day or 0)

        if frame.hottest and frame.hottest.name then
            hotspotCounts[frame.hottest.name] = (hotspotCounts[frame.hottest.name] or 0) + 1
        end

        for _, cat in ipairs(run.categories or {}) do
            local peak = categoryPeaks[cat.category]
            local maxMs = cat.maxMs or cat.avgMs or 0
            if not peak or maxMs > peak then
                categoryPeaks[cat.category] = maxMs
            end
        end
    end

    if minFrameMs == math.huge then
        minFrameMs = 0
    end

    if (soak.averageFrameMs or 0) > avgBudget then
        flags[#flags + 1] = string.format('average frame %.3fms exceeds %.3fms budget', soak.averageFrameMs or 0, avgBudget)
    end
    if maxFrameMs > peakBudget then
        flags[#flags + 1] = string.format('peak frame %.3fms exceeds %.3fms budget', maxFrameMs, peakBudget)
    end

    local rankedHotspots = sortedPairsByValue(hotspotCounts)
    local rankedCategories = sortedPairsByValue(categoryPeaks)

    return {
        name = soak.name,
        iterations = soak.iterations or #runs,
        averageFrameMs = soak.averageFrameMs or 0,
        averageInnerMs = (#runs > 0) and (totalInnerMs / #runs) or 0,
        averageDay = (#runs > 0) and (totalDays / #runs) or 0,
        minFrameMs = minFrameMs,
        maxFrameMs = maxFrameMs,
        hotspotCounts = hotspotCounts,
        categoryPeaks = categoryPeaks,
        hottest = rankedHotspots[1] and { name = rankedHotspots[1].key, count = rankedHotspots[1].value } or nil,
        hottestList = rankedHotspots,
        categoryList = rankedCategories,
        flags = flags,
        status = (#flags == 0) and 'PASS' or 'WARN',
    }
end

function Benchmark.runSuite(opts)
    opts = opts or {}
    local names = opts.scenarios or Benchmark.getScenarioNames()
    local iterations = opts.iterations or 5
    local reports = {}
    local overallStatus = 'PASS'

    for i = 1, #names do
        local name = names[i]
        local soak, err = Benchmark.runSoak(name, {
            iterations = iterations,
            seed = opts.seed,
            frames = opts.frames,
            dt = opts.dt,
            tuningOverrides = opts.tuningOverrides,
        })
        if not soak then
            return nil, err
        end
        local summary = Benchmark.summarizeSoak(soak, { budgets = opts.budgets })
        reports[#reports + 1] = {
            name = name,
            soak = soak,
            summary = summary,
        }
        if summary.status ~= 'PASS' then
            overallStatus = 'WARN'
        end
    end

    return {
        status = overallStatus,
        iterations = iterations,
        reports = reports,
    }
end

return Benchmark
