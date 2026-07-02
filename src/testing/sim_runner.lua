-- FROSTHOLD — Simulation Test Runner
-- src/testing/sim_runner.lua
-- Orchestrates simulation tests with multiple agents and scenarios.
-- Can run headless or with graphics.

local SimRunner = {}

local SimAgent = require('src.testing.sim_agent')
local Invariants = require('src.testing.invariants')

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local state = {
    running = false,
    paused = false,
    scenario = nil,
    agents = {},
    startTime = 0,
    elapsedReal = 0,
    targetDays = 30,
    targetTicks = nil,
    invariantCheckInterval = 100,  -- check every 100 ticks
    lastInvariantCheck = 0,
    invariantViolations = {},
    issues = {},
    log = {},
    callbacks = {
        onIssue = nil,
        onDayChange = nil,
        onFinish = nil,
    },
}

---------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------

local function log(level, message)
    local GameState = require('src.game_state')
    local entry = {
        level = level,
        message = message,
        day = GameState.day or 0,
        tick = GameState.simTick or 0,
        realTime = state.elapsedReal,
    }
    state.log[#state.log + 1] = entry

    local prefix = string.format('[SimRunner Day %d Tick %d] ',
        entry.day, entry.tick)
    print(prefix .. '[' .. level:upper() .. '] ' .. message)
end

function SimRunner.info(msg) log('info', msg) end
function SimRunner.warn(msg) log('warn', msg) end
function SimRunner.error(msg) log('error', msg) end

---------------------------------------------------------------------------
-- Agent Management
---------------------------------------------------------------------------

function SimRunner.addAgent(agent)
    if not agent then return end
    state.agents[#state.agents + 1] = agent
    SimRunner.info('Added agent: ' .. agent.name)
end

function SimRunner.removeAgent(name)
    for i, agent in ipairs(state.agents) do
        if agent.name == name then
            table.remove(state.agents, i)
            SimRunner.info('Removed agent: ' .. name)
            return true
        end
    end
    return false
end

function SimRunner.getAgent(name)
    for _, agent in ipairs(state.agents) do
        if agent.name == name then
            return agent
        end
    end
    return nil
end

function SimRunner.clearAgents()
    state.agents = {}
end

---------------------------------------------------------------------------
-- Scenario Setup
---------------------------------------------------------------------------

local DEFAULT_SCENARIO = {
    name = 'default',
    description = 'Standard 30-day survival test',
    days = 30,
    planet = 'erebus',
    scenario = 'crashlanded',
    difficulty = 'normal',
    seed = 12345,
    startResources = nil,  -- use defaults
    spawnCreatures = true,
    enableRaids = true,
    enableWeather = true,
    agents = {},  -- agent configs to auto-add
}

function SimRunner.setScenario(scenario)
    state.scenario = scenario or DEFAULT_SCENARIO
    state.targetDays = scenario.days or 30
    SimRunner.info('Set scenario: ' .. (scenario.name or 'unnamed'))
end

---------------------------------------------------------------------------
-- Start/Stop
---------------------------------------------------------------------------

function SimRunner.start(opts)
    opts = opts or {}

    -- Set scenario
    state.scenario = opts.scenario or state.scenario or DEFAULT_SCENARIO
    state.targetDays = state.scenario.days or 30
    state.targetTicks = opts.targetTicks

    -- Configure
    state.invariantCheckInterval = opts.invariantCheckInterval or 100
    state.callbacks.onIssue = opts.onIssue
    state.callbacks.onDayChange = opts.onDayChange
    state.callbacks.onFinish = opts.onFinish

    -- Reset state
    state.running = true
    state.paused = false
    state.startTime = os.clock()
    state.elapsedReal = 0
    state.lastInvariantCheck = 0
    state.invariantViolations = {}
    state.issues = {}
    state.log = {}

    SimRunner.info('Starting simulation test')
    SimRunner.info('Scenario: ' .. (state.scenario.name or 'unnamed'))
    SimRunner.info('Target: ' .. state.targetDays .. ' days')
    SimRunner.info('Agents: ' .. #state.agents)

    -- Initialize all agents
    for _, agent in ipairs(state.agents) do
        agent:init()
    end
end

function SimRunner.stop(reason)
    if not state.running then return end

    state.running = false
    state.elapsedReal = os.clock() - state.startTime

    SimRunner.info('Stopping simulation: ' .. (reason or 'manual'))

    -- Finish all agents
    for _, agent in ipairs(state.agents) do
        agent:finish()
    end

    -- Collect all issues from agents
    for _, agent in ipairs(state.agents) do
        for _, issue in ipairs(agent.issues) do
            state.issues[#state.issues + 1] = issue
        end
    end

    -- Add invariant violations as issues
    for _, violation in ipairs(state.invariantViolations) do
        state.issues[#state.issues + 1] = {
            severity = 'high',
            category = 'invariant_violation',
            message = violation.message,
            data = violation.data,
            agent = 'Invariants',
        }
    end

    -- Call finish callback
    if state.callbacks.onFinish then
        state.callbacks.onFinish(SimRunner.getResults())
    end
end

---------------------------------------------------------------------------
-- Step (called from main update loop)
---------------------------------------------------------------------------

local lastDay = 0

function SimRunner.step(dt)
    if not state.running or state.paused then return end

    local GameState = require('src.game_state')
    if GameState.phase ~= 'playing' then return end

    state.elapsedReal = os.clock() - state.startTime

    -- Day change callback
    local currentDay = GameState.day or 0
    if currentDay > lastDay then
        lastDay = currentDay
        SimRunner.info('Day ' .. currentDay .. ' reached')

        if state.callbacks.onDayChange then
            state.callbacks.onDayChange(currentDay)
        end
    end

    -- Run agent steps
    for _, agent in ipairs(state.agents) do
        local ok, err = pcall(agent.step, agent, dt)
        if not ok then
            SimRunner.error('Agent ' .. agent.name .. ' step error: ' .. tostring(err))
        end
    end

    -- Invariant checks
    local tick = GameState.simTick or 0
    if tick - state.lastInvariantCheck >= state.invariantCheckInterval then
        state.lastInvariantCheck = tick
        local violations = Invariants.checkAll()
        for _, v in ipairs(violations) do
            state.invariantViolations[#state.invariantViolations + 1] = v
            SimRunner.warn('Invariant violation: ' .. v.message)
            if state.callbacks.onIssue then
                state.callbacks.onIssue({
                    severity = 'high',
                    category = 'invariant',
                    message = v.message,
                    data = v.data,
                })
            end
        end
    end

    -- Check completion conditions
    if state.targetTicks and tick >= state.targetTicks then
        SimRunner.stop('target_ticks_reached')
        return
    end

    if currentDay >= state.targetDays then
        SimRunner.stop('target_days_reached')
        return
    end

    -- Check for colony death
    local ok, ECS = pcall(require, 'src.ecs.ecs')
    if ok then
        local aliveCount = 0
        for _, comps in ECS.query('colonist') do
            if comps.colonist.state ~= 'dead' then
                aliveCount = aliveCount + 1
            end
        end
        if aliveCount == 0 and currentDay > 0 then
            SimRunner.warn('Colony wiped on day ' .. currentDay)
            SimRunner.stop('colony_death')
            return
        end
    end
end

---------------------------------------------------------------------------
-- Results
---------------------------------------------------------------------------

function SimRunner.getResults()
    local GameState = require('src.game_state')

    -- Collect agent results
    local agentResults = {}
    for _, agent in ipairs(state.agents) do
        agentResults[#agentResults + 1] = agent:getResults()
    end

    -- Count issues by severity
    local issueCounts = { critical = 0, high = 0, medium = 0, low = 0 }
    for _, issue in ipairs(state.issues) do
        local sev = issue.severity or 'low'
        issueCounts[sev] = (issueCounts[sev] or 0) + 1
    end

    return {
        scenario = state.scenario and state.scenario.name or 'unknown',
        status = state.running and 'running' or 'finished',
        daysReached = GameState.day or 0,
        ticksReached = GameState.simTick or 0,
        targetDays = state.targetDays,
        realTimeSeconds = state.elapsedReal,
        issues = state.issues,
        issueCounts = issueCounts,
        invariantViolations = #state.invariantViolations,
        agents = agentResults,
        log = state.log,
    }
end

function SimRunner.isRunning()
    return state.running
end

function SimRunner.isPaused()
    return state.paused
end

function SimRunner.pause()
    state.paused = true
end

function SimRunner.resume()
    state.paused = false
end

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------

function SimRunner.printSummary()
    local results = SimRunner.getResults()

    print('\n========================================')
    print('SIMULATION TEST RESULTS')
    print('========================================')
    print('Scenario: ' .. results.scenario)
    print('Status: ' .. results.status)
    print('Days: ' .. results.daysReached .. '/' .. results.targetDays)
    print('Ticks: ' .. results.ticksReached)
    print('Real time: ' .. string.format('%.1f', results.realTimeSeconds) .. 's')
    print('----------------------------------------')
    print('Issues:')
    print('  Critical: ' .. results.issueCounts.critical)
    print('  High: ' .. results.issueCounts.high)
    print('  Medium: ' .. results.issueCounts.medium)
    print('  Low: ' .. results.issueCounts.low)
    print('  Invariant violations: ' .. results.invariantViolations)
    print('----------------------------------------')
    print('Agents:')
    for _, agent in ipairs(results.agents) do
        local issueCount = 0
        if agent.issues then issueCount = #agent.issues end
        print('  ' .. agent.name .. ': ' .. issueCount .. ' issues')
    end
    print('========================================\n')
end

function SimRunner.exportJSON(path)
    local results = SimRunner.getResults()

    -- Simple JSON encoding (no external deps)
    local function encode(val, indent)
        indent = indent or 0
        local t = type(val)
        if t == 'nil' then
            return 'null'
        elseif t == 'boolean' then
            return val and 'true' or 'false'
        elseif t == 'number' then
            if val ~= val then return 'null' end  -- NaN
            if val == math.huge then return '1e308' end
            if val == -math.huge then return '-1e308' end
            return tostring(val)
        elseif t == 'string' then
            return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
        elseif t == 'table' then
            -- Check if array
            local isArray = #val > 0 or next(val) == nil
            if isArray then
                local parts = {}
                for i, v in ipairs(val) do
                    parts[i] = encode(v, indent + 1)
                end
                return '[' .. table.concat(parts, ',') .. ']'
            else
                local parts = {}
                for k, v in pairs(val) do
                    if type(k) == 'string' then
                        parts[#parts + 1] = '"' .. k .. '":' .. encode(v, indent + 1)
                    end
                end
                return '{' .. table.concat(parts, ',') .. '}'
            end
        else
            return 'null'
        end
    end

    local json = encode(results)

    local f = io.open(path, 'w')
    if f then
        f:write(json)
        f:close()
        SimRunner.info('Results exported to ' .. path)
        return true
    else
        SimRunner.error('Failed to write results to ' .. path)
        return false
    end
end

---------------------------------------------------------------------------
-- Quick test helpers
---------------------------------------------------------------------------

function SimRunner.runQuickTest(days, agents)
    days = days or 10
    agents = agents or {}

    SimRunner.clearAgents()
    for _, agent in ipairs(agents) do
        SimRunner.addAgent(agent)
    end

    SimRunner.setScenario({
        name = 'quick_test',
        days = days,
    })

    SimRunner.start()

    -- Note: This just sets up the test.
    -- The actual simulation runs via step() called from main.lua
    return true
end

return SimRunner
