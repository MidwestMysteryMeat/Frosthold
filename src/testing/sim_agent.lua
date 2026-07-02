-- FROSTHOLD — Simulation Agent Base
-- src/testing/sim_agent.lua
-- Base class for all simulation test agents.
-- Agents observe game state, take actions, and detect issues.

local SimAgent = {}
SimAgent.__index = SimAgent

---------------------------------------------------------------------------
-- Constructor
---------------------------------------------------------------------------

function SimAgent.new(config)
    local self = setmetatable({}, SimAgent)
    self.name = config.name or 'SimAgent'
    self.description = config.description or ''
    self.enabled = true
    self.tickInterval = config.tickInterval or 1  -- how often to run (in sim ticks)
    self.lastTick = 0

    -- State
    self.issues = {}          -- detected issues
    self.actions = {}         -- action history
    self.observations = {}    -- observation history
    self.metrics = {}         -- tracked metrics over time
    self.startDay = 0
    self.startTick = 0

    -- Callbacks (override in subclasses)
    self.onInit = config.onInit or function() end
    self.onTick = config.onTick or function() end
    self.onFinish = config.onFinish or function() end

    return self
end

---------------------------------------------------------------------------
-- Issue reporting
---------------------------------------------------------------------------

function SimAgent:reportIssue(severity, category, message, data)
    local GameState = require('src.game_state')
    local issue = {
        severity = severity,  -- 'critical', 'high', 'medium', 'low'
        category = category,
        message = message,
        data = data or {},
        day = GameState.day or 0,
        hour = GameState.hour or 0,
        tick = GameState.simTick or 0,
        agent = self.name,
        timestamp = os.time(),
    }
    self.issues[#self.issues + 1] = issue

    -- Print immediately for visibility
    local prefix = string.format('[%s] Day %d %.1fh',
        self.name, issue.day, issue.hour)
    print(string.format('%s [%s] %s: %s',
        prefix, severity:upper(), category, message))

    return issue
end

function SimAgent:critical(category, message, data)
    return self:reportIssue('critical', category, message, data)
end

function SimAgent:high(category, message, data)
    return self:reportIssue('high', category, message, data)
end

function SimAgent:medium(category, message, data)
    return self:reportIssue('medium', category, message, data)
end

function SimAgent:low(category, message, data)
    return self:reportIssue('low', category, message, data)
end

---------------------------------------------------------------------------
-- Observation helpers
---------------------------------------------------------------------------

function SimAgent:observe(key, value)
    local GameState = require('src.game_state')
    local obs = {
        key = key,
        value = value,
        tick = GameState.simTick or 0,
        day = GameState.day or 0,
    }
    self.observations[#self.observations + 1] = obs
    return obs
end

function SimAgent:trackMetric(name, value)
    local GameState = require('src.game_state')
    if not self.metrics[name] then
        self.metrics[name] = {}
    end
    self.metrics[name][#self.metrics[name] + 1] = {
        value = value,
        tick = GameState.simTick or 0,
        day = GameState.day or 0,
    }
end

---------------------------------------------------------------------------
-- Action helpers
---------------------------------------------------------------------------

function SimAgent:recordAction(actionType, params, result)
    local GameState = require('src.game_state')
    local action = {
        type = actionType,
        params = params,
        result = result,
        tick = GameState.simTick or 0,
        day = GameState.day or 0,
    }
    self.actions[#self.actions + 1] = action
    return action
end

---------------------------------------------------------------------------
-- ECS query helpers
---------------------------------------------------------------------------

function SimAgent:queryECS(...)
    local ok, ECS = pcall(require, 'src.ecs.ecs')
    if not ok then return function() end end
    return ECS.query(...)
end

function SimAgent:countEntities(component)
    local ok, ECS = pcall(require, 'src.ecs.ecs')
    if not ok then return 0 end
    return ECS.countWith(component) or 0
end

function SimAgent:getComponent(entityId, component)
    local ok, ECS = pcall(require, 'src.ecs.ecs')
    if not ok then return nil end
    return ECS.get(entityId, component)
end

---------------------------------------------------------------------------
-- Game state helpers
---------------------------------------------------------------------------

function SimAgent:getGameState()
    return require('src.game_state')
end

function SimAgent:getResource(name)
    local gs = self:getGameState()
    return (gs.resources or {})[name] or 0
end

function SimAgent:setResource(name, value)
    local gs = self:getGameState()
    gs.resources = gs.resources or {}
    gs.resources[name] = value
end

function SimAgent:addResource(name, amount)
    local gs = self:getGameState()
    if gs.addResource then
        gs.addResource(name, amount)
    else
        gs.resources = gs.resources or {}
        gs.resources[name] = (gs.resources[name] or 0) + amount
    end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function SimAgent:init()
    local GameState = require('src.game_state')
    self.startDay = GameState.day or 0
    self.startTick = GameState.simTick or 0
    self.issues = {}
    self.actions = {}
    self.observations = {}
    self.metrics = {}

    local ok, err = pcall(self.onInit, self)
    if not ok then
        self:critical('agent_error', 'onInit failed: ' .. tostring(err))
    end
end

function SimAgent:step(dt)
    if not self.enabled then return end

    local GameState = require('src.game_state')
    local tick = GameState.simTick or 0

    -- Respect tick interval
    if tick - self.lastTick < self.tickInterval then return end
    self.lastTick = tick

    local ok, err = pcall(self.onTick, self, dt)
    if not ok then
        self:critical('agent_error', 'onTick failed: ' .. tostring(err))
    end
end

function SimAgent:finish()
    local ok, err = pcall(self.onFinish, self)
    if not ok then
        self:critical('agent_error', 'onFinish failed: ' .. tostring(err))
    end
end

---------------------------------------------------------------------------
-- Results
---------------------------------------------------------------------------

function SimAgent:getResults()
    local GameState = require('src.game_state')
    return {
        name = self.name,
        description = self.description,
        startDay = self.startDay,
        endDay = GameState.day or 0,
        startTick = self.startTick,
        endTick = GameState.simTick or 0,
        issues = self.issues,
        actionCount = #self.actions,
        observationCount = #self.observations,
        metrics = self.metrics,
    }
end

function SimAgent:hasIssues()
    return #self.issues > 0
end

function SimAgent:countIssues(severity)
    if not severity then return #self.issues end
    local count = 0
    for _, issue in ipairs(self.issues) do
        if issue.severity == severity then
            count = count + 1
        end
    end
    return count
end

return SimAgent
