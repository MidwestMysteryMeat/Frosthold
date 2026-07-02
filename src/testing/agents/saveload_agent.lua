-- FROSTHOLD — Save/Load Simulation Agent
-- src/testing/agents/saveload_agent.lua
-- Tests persistence by saving and loading at intervals, comparing state.

local SimAgent = require('src.testing.sim_agent')

local SaveLoadAgent = {}

function SaveLoadAgent.new(config)
    config = config or {}
    config.name = config.name or 'SaveLoadAgent'
    config.description = config.description or 'Tests save/load persistence'
    config.tickInterval = config.tickInterval or 200  -- every 10 seconds

    local agent = SimAgent.new(config)

    -- Config
    agent.testInterval = config.testInterval or 600    -- ticks between save/load tests
    agent.enableRoundTrip = config.enableRoundTrip or false  -- actually load saves
    agent.testSlotId = config.testSlotId or 'simtest'

    -- Tracking
    agent.lastTestTick = 0
    agent.saveTests = {}
    agent.loadTests = {}
    agent.stateSnapshots = {}

    -----------------------------------------------------------------
    -- Init
    -----------------------------------------------------------------
    function agent:onInit()
        self.lastTestTick = 0
        self.saveTests = {}
        self.loadTests = {}
        self.stateSnapshots = {}
    end

    -----------------------------------------------------------------
    -- Capture game state for comparison
    -----------------------------------------------------------------
    function agent:captureState()
        local ECS = require('src.ecs.ecs')
        local GameState = self:getGameState()

        local state = {
            day = GameState.day,
            hour = GameState.hour,
            tick = GameState.simTick,
            resources = {},
            colonistCount = 0,
            colonistHealth = {},
            creatureCount = 0,
            buildingCount = 0,
            jobCount = 0,
        }

        -- Copy resources
        for name, amount in pairs(GameState.resources or {}) do
            state.resources[name] = amount
        end

        -- Count and track colonists
        for id, comps in ECS.query('colonist') do
            state.colonistCount = state.colonistCount + 1
            state.colonistHealth[id] = comps.colonist.health
        end

        -- Count creatures
        state.creatureCount = ECS.countWith('creature') or 0

        -- Count buildings
        state.buildingCount = ECS.countWith('building') or 0

        -- Count jobs
        local jok, Jobs = pcall(require, 'src.colonist.jobs')
        if jok and Jobs.getAllTasks then
            local tasks = Jobs.getAllTasks()
            for _ in pairs(tasks) do
                state.jobCount = state.jobCount + 1
            end
        end

        return state
    end

    -----------------------------------------------------------------
    -- Compare two state snapshots
    -----------------------------------------------------------------
    function agent:compareStates(before, after)
        local diffs = {}

        -- Day/time should match
        if before.day ~= after.day then
            diffs[#diffs + 1] = {
                field = 'day',
                before = before.day,
                after = after.day,
                severity = 'critical',
            }
        end

        -- Colonist count
        if before.colonistCount ~= after.colonistCount then
            diffs[#diffs + 1] = {
                field = 'colonistCount',
                before = before.colonistCount,
                after = after.colonistCount,
                severity = 'high',
            }
        end

        -- Colonist health
        for id, health in pairs(before.colonistHealth) do
            local afterHealth = after.colonistHealth[id]
            if afterHealth and math.abs(health - afterHealth) > 0.1 then
                diffs[#diffs + 1] = {
                    field = 'colonistHealth[' .. id .. ']',
                    before = health,
                    after = afterHealth,
                    severity = 'medium',
                }
            end
        end

        -- Resources
        for name, amount in pairs(before.resources) do
            local afterAmount = after.resources[name]
            if afterAmount and math.abs(amount - (afterAmount or 0)) > 0.1 then
                diffs[#diffs + 1] = {
                    field = 'resources.' .. name,
                    before = amount,
                    after = afterAmount,
                    severity = 'medium',
                }
            end
        end

        -- Building count
        if before.buildingCount ~= after.buildingCount then
            diffs[#diffs + 1] = {
                field = 'buildingCount',
                before = before.buildingCount,
                after = after.buildingCount,
                severity = 'high',
            }
        end

        return diffs
    end

    -----------------------------------------------------------------
    -- Tick
    -----------------------------------------------------------------
    function agent:onTick(dt)
        local GameState = self:getGameState()
        local tick = GameState.simTick or 0

        -- Check if it's time for a save test
        if tick - self.lastTestTick >= self.testInterval then
            self.lastTestTick = tick
            self:runSaveTest()
        end

        -- Validate save module is accessible
        if tick % 1000 == 0 then
            local sok, Save = pcall(require, 'src.persistence.save')
            if not sok then
                self:critical('module_error', 'Save module failed to load')
            end
        end
    end

    -----------------------------------------------------------------
    -- Save test
    -----------------------------------------------------------------
    function agent:runSaveTest()
        local ok, Save = pcall(require, 'src.persistence.save')
        if not ok then
            self:critical('save_error', 'Could not load save module')
            return
        end

        local GameState = self:getGameState()

        -- Capture state before
        local beforeState = self:captureState()

        -- Attempt save
        local saveStart = os.clock()
        local saveOk, saveErr = pcall(function()
            if Save.saveSlot then
                Save.saveSlot(self.testSlotId)
            elseif Save.save then
                Save.save()
            end
        end)
        local saveTime = os.clock() - saveStart

        local testResult = {
            tick = GameState.simTick,
            day = GameState.day,
            saveSuccess = saveOk,
            saveError = not saveOk and tostring(saveErr) or nil,
            saveTimeMs = saveTime * 1000,
            beforeState = beforeState,
        }

        self.saveTests[#self.saveTests + 1] = testResult

        if not saveOk then
            self:critical('save_failed',
                'Save failed: ' .. tostring(saveErr),
                { error = tostring(saveErr) })
            return
        end

        -- Track save performance
        self:trackMetric('save_time_ms', saveTime * 1000)

        if saveTime > 1.0 then
            self:medium('slow_save',
                'Save took ' .. string.format('%.2f', saveTime) .. 's',
                { saveTimeMs = saveTime * 1000 })
        end

        self:recordAction('save', {
            slotId = self.testSlotId,
            timeMs = saveTime * 1000,
        }, 'success')

        -- Round-trip test if enabled
        if self.enableRoundTrip then
            self:runLoadTest(beforeState)
        end
    end

    -----------------------------------------------------------------
    -- Load test
    -----------------------------------------------------------------
    function agent:runLoadTest(beforeState)
        local ok, Save = pcall(require, 'src.persistence.save')
        if not ok then return end

        local GameState = self:getGameState()

        -- Attempt load
        local loadStart = os.clock()
        local loadOk, loadErr = pcall(function()
            if Save.loadSlot then
                Save.loadSlot(self.testSlotId)
            elseif Save.load then
                Save.load()
            end
        end)
        local loadTime = os.clock() - loadStart

        local testResult = {
            tick = GameState.simTick,
            loadSuccess = loadOk,
            loadError = not loadOk and tostring(loadErr) or nil,
            loadTimeMs = loadTime * 1000,
        }

        if not loadOk then
            self:critical('load_failed',
                'Load failed: ' .. tostring(loadErr),
                { error = tostring(loadErr) })
            self.loadTests[#self.loadTests + 1] = testResult
            return
        end

        -- Capture state after load
        local afterState = self:captureState()
        testResult.afterState = afterState

        -- Compare states
        local diffs = self:compareStates(beforeState, afterState)
        testResult.diffs = diffs

        self.loadTests[#self.loadTests + 1] = testResult

        -- Report diffs as issues
        for _, diff in ipairs(diffs) do
            local severity = diff.severity or 'medium'
            self:reportIssue(severity, 'persistence_diff',
                'State mismatch after load: ' .. diff.field ..
                ' (before=' .. tostring(diff.before) ..
                ', after=' .. tostring(diff.after) .. ')',
                diff)
        end

        self:trackMetric('load_time_ms', loadTime * 1000)

        self:recordAction('load', {
            slotId = self.testSlotId,
            timeMs = loadTime * 1000,
            diffCount = #diffs,
        }, loadOk and 'success' or 'failed')
    end

    -----------------------------------------------------------------
    -- Finish
    -----------------------------------------------------------------
    function agent:onFinish()
        self:observe('save_tests_run', #self.saveTests)
        self:observe('load_tests_run', #self.loadTests)

        -- Count failures
        local saveFails = 0
        local loadFails = 0
        for _, test in ipairs(self.saveTests) do
            if not test.saveSuccess then saveFails = saveFails + 1 end
        end
        for _, test in ipairs(self.loadTests) do
            if not test.loadSuccess then loadFails = loadFails + 1 end
        end

        self:observe('save_failures', saveFails)
        self:observe('load_failures', loadFails)
    end

    return agent
end

return SaveLoadAgent
