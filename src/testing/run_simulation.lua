-- FROSTHOLD — Simulation Test Entry Point
-- src/testing/run_simulation.lua
-- Main entry point for running simulation tests.
-- Can be integrated with main.lua or run standalone.

local RunSimulation = {}

local SimRunner = require('src.testing.sim_runner')
local Agents = require('src.testing.agents.init')
local Invariants = require('src.testing.invariants')

---------------------------------------------------------------------------
-- Predefined test scenarios
---------------------------------------------------------------------------

local SCENARIOS = {
    -- Quick smoke test
    quick = {
        name = 'quick',
        description = 'Quick 5-day smoke test',
        days = 5,
        agents = { 'colonist', 'economy', 'thermal' },
    },

    -- Standard survival test
    survival = {
        name = 'survival',
        description = 'Standard 30-day survival test',
        days = 30,
        agents = { 'colonist', 'building', 'combat', 'economy', 'thermal' },
    },

    -- Extended endurance test
    endurance = {
        name = 'endurance',
        description = 'Extended 100-day endurance test',
        days = 100,
        agents = { 'colonist', 'building', 'combat', 'economy', 'thermal', 'saveload' },
    },

    -- Combat stress test
    combat = {
        name = 'combat',
        description = 'Combat-focused test with frequent raids',
        days = 20,
        agents = { 'colonist', 'combat' },
        agentConfig = {
            combat = {
                triggerTestRaids = true,
                raidIntervalDays = 3,
            },
        },
    },

    -- Building stress test
    building = {
        name = 'building',
        description = 'Building system stress test',
        days = 15,
        agents = { 'colonist', 'building', 'economy' },
        agentConfig = {
            building = {
                autoBuild = true,
                buildBudget = 50,
            },
        },
    },

    -- Save/load persistence test
    persistence = {
        name = 'persistence',
        description = 'Save/load round-trip testing',
        days = 10,
        agents = { 'colonist', 'economy', 'saveload' },
        agentConfig = {
            saveload = {
                testInterval = 300,
                enableRoundTrip = true,
            },
        },
    },

    -- Full comprehensive test
    full = {
        name = 'full',
        description = 'Comprehensive test with all agents',
        days = 50,
        agents = { 'colonist', 'building', 'combat', 'economy', 'thermal', 'saveload' },
        agentConfig = {
            combat = { triggerTestRaids = true, raidIntervalDays = 7 },
            building = { autoBuild = true, buildBudget = 20 },
            saveload = { testInterval = 600 },
        },
    },
}

---------------------------------------------------------------------------
-- Create agents from scenario
---------------------------------------------------------------------------

local function createAgentsFromScenario(scenario)
    local agents = {}
    local agentConfig = scenario.agentConfig or {}

    local agentMap = {
        colonist = Agents.ColonistAgent,
        building = Agents.BuildingAgent,
        combat = Agents.CombatAgent,
        economy = Agents.EconomyAgent,
        thermal = Agents.ThermalAgent,
        saveload = Agents.SaveLoadAgent,
    }

    for _, agentName in ipairs(scenario.agents or {}) do
        local AgentClass = agentMap[agentName]
        if AgentClass then
            local config = agentConfig[agentName] or {}
            agents[#agents + 1] = AgentClass.new(config)
        end
    end

    return agents
end

---------------------------------------------------------------------------
-- Setup and start
---------------------------------------------------------------------------

function RunSimulation.setup(scenarioName)
    scenarioName = scenarioName or 'survival'
    local scenario = SCENARIOS[scenarioName]

    if not scenario then
        print('[RunSimulation] Unknown scenario: ' .. scenarioName)
        print('[RunSimulation] Available: ' .. table.concat(RunSimulation.listScenarios(), ', '))
        scenario = SCENARIOS.survival
    end

    print('[RunSimulation] Setting up scenario: ' .. scenario.name)
    print('[RunSimulation] Description: ' .. scenario.description)
    print('[RunSimulation] Target: ' .. scenario.days .. ' days')

    -- Clear and add agents
    SimRunner.clearAgents()
    local agents = createAgentsFromScenario(scenario)
    for _, agent in ipairs(agents) do
        SimRunner.addAgent(agent)
    end

    -- Set scenario
    SimRunner.setScenario(scenario)

    return scenario
end

function RunSimulation.start(opts)
    opts = opts or {}

    SimRunner.start({
        onIssue = function(issue)
            -- Could log to file, send webhook, etc.
        end,
        onDayChange = function(day)
            -- Progress update
        end,
        onFinish = function(results)
            RunSimulation.onFinish(results)
        end,
    })
end

function RunSimulation.onFinish(results)
    print('\n')
    SimRunner.printSummary()

    -- Export results if we have a path
    local exportPath = './simulation_results_' .. os.time() .. '.json'
    if love and love.filesystem and love.filesystem.getSaveDirectory then
        local saveDir = love.filesystem.getSaveDirectory()
        if saveDir then
            exportPath = saveDir .. '/simulation_results_' .. os.time() .. '.json'
        end
    end

    SimRunner.exportJSON(exportPath)
end

---------------------------------------------------------------------------
-- Step (call from main.lua update loop)
---------------------------------------------------------------------------

function RunSimulation.step(dt)
    SimRunner.step(dt)
end

---------------------------------------------------------------------------
-- Query functions
---------------------------------------------------------------------------

function RunSimulation.isRunning()
    return SimRunner.isRunning()
end

function RunSimulation.stop(reason)
    return SimRunner.stop(reason)
end

function RunSimulation.getResults()
    return SimRunner.getResults()
end

function RunSimulation.printSummary()
    return SimRunner.printSummary()
end

function RunSimulation.listScenarios()
    local names = {}
    for name in pairs(SCENARIOS) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function RunSimulation.getScenario(name)
    return SCENARIOS[name]
end

---------------------------------------------------------------------------
-- Quick test function
---------------------------------------------------------------------------

function RunSimulation.runQuick()
    RunSimulation.setup('quick')
    RunSimulation.start()
end

function RunSimulation.runFull()
    RunSimulation.setup('full')
    RunSimulation.start()
end

---------------------------------------------------------------------------
-- Standalone invariant check
---------------------------------------------------------------------------

function RunSimulation.checkInvariants()
    local violations = Invariants.checkAll()

    if #violations == 0 then
        print('[Invariants] All checks passed')
        return true
    end

    print('[Invariants] ' .. #violations .. ' violations found:')
    for i, v in ipairs(violations) do
        print(string.format('  %d. [%s] %s', i, v.checkName or 'unknown', v.message))
    end
    return false, violations
end

return RunSimulation
