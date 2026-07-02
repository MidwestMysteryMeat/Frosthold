-- FROSTHOLD — Colonist Simulation Agent
-- src/testing/agents/colonist_agent.lua
-- Tests colonist survival loop: needs, health, jobs, mental state.

local SimAgent = require('src.testing.sim_agent')

local ColonistAgent = {}

function ColonistAgent.new(config)
    config = config or {}
    config.name = config.name or 'ColonistAgent'
    config.description = config.description or 'Tests colonist survival systems'
    config.tickInterval = config.tickInterval or 20  -- every second at 20Hz

    local agent = SimAgent.new(config)

    -- Tracking
    agent.colonistStates = {}   -- { [id] = { health, needs, etc. } }
    agent.deaths = {}
    agent.mentalBreaks = {}
    agent.lastColonistCount = 0
    agent.needsHistory = {}     -- for trend analysis

    -----------------------------------------------------------------
    -- Init
    -----------------------------------------------------------------
    function agent:onInit()
        self.colonistStates = {}
        self.deaths = {}
        self.mentalBreaks = {}
        self.lastColonistCount = 0
        self:snapshotColonists()
    end

    -----------------------------------------------------------------
    -- Snapshot current colonist state
    -----------------------------------------------------------------
    function agent:snapshotColonists()
        local ECS = require('src.ecs.ecs')

        for id, comps in ECS.query('colonist', 'needs') do
            local col = comps.colonist
            local needs = comps.needs
            local pos = ECS.get(id, 'pos')

            self.colonistStates[id] = {
                name = col.name or 'Unknown',
                health = col.health,
                maxHealth = col.maxHealth,
                state = col.state,
                task = col.task,
                warmth = needs.warmth,
                food = needs.food,
                rest = needs.rest,
                morale = needs.morale,
                x = pos and pos.x,
                y = pos and pos.y,
            }
        end
    end

    -----------------------------------------------------------------
    -- Tick
    -----------------------------------------------------------------
    function agent:onTick(dt)
        local ECS = require('src.ecs.ecs')
        local GameState = self:getGameState()

        -- Count living colonists
        local aliveCount = 0
        local totalCount = 0

        for id, comps in ECS.query('colonist') do
            totalCount = totalCount + 1
            local col = comps.colonist
            local needs = ECS.get(id, 'needs')
            local prev = self.colonistStates[id]

            -- Check for new deaths (must check BEFORE alive/dead branch)
            local isDead = col.state == 'dead' or (col.health and col.health <= 0)
            local wasDead = prev and (prev.state == 'dead' or (prev.health and prev.health <= 0))
            if isDead and not wasDead then
                self:reportDeath(id, col, prev or {
                    name = col.name,
                    health = col.maxHealth or 100,
                    warmth = needs and needs.warmth or 50,
                    food = needs and needs.food or 50,
                })
            end

            if col.state ~= 'dead' then
                aliveCount = aliveCount + 1

                -- Check for mental breaks
                if col.state == 'mental_break' and (not prev or prev.state ~= 'mental_break') then
                    self:reportMentalBreak(id, col, needs)
                end

                -- Check for critical needs
                if needs then
                    self:checkCriticalNeeds(id, col, needs)
                end

                -- Check for stuck colonists (no task for extended period)
                if col.state == 'idle' and prev and prev.state == 'idle' then
                    -- Track idle time in a separate field
                    col._idleTime = (col._idleTime or 0) + 1
                    if col._idleTime > 200 then  -- 10 seconds of continuous idle
                        self:low('stuck_colonist',
                            col.name .. ' has been idle for extended period',
                            { entityId = id, state = col.state })
                        col._idleTime = 0  -- reset to avoid spam
                    end
                else
                    col._idleTime = 0
                end

                -- Health checks
                if col.health and col.maxHealth then
                    local healthPct = col.health / col.maxHealth
                    if healthPct < 0.25 then
                        self:trackMetric('critical_health', healthPct)
                    end
                end
            end
        end

        -- Track population
        self:trackMetric('population', aliveCount)

        -- Check for population changes
        if aliveCount < self.lastColonistCount then
            local lost = self.lastColonistCount - aliveCount
            self:medium('population_loss',
                'Lost ' .. lost .. ' colonist(s), now at ' .. aliveCount,
                { previous = self.lastColonistCount, current = aliveCount })
        end
        self.lastColonistCount = aliveCount

        -- Check for total wipe
        if aliveCount == 0 and totalCount > 0 and (GameState.day or 0) > 0 then
            self:critical('colony_death',
                'All colonists dead on day ' .. (GameState.day or 0),
                { day = GameState.day })
        end

        -- Update snapshot
        self:snapshotColonists()
    end

    -----------------------------------------------------------------
    -- Death reporting
    -----------------------------------------------------------------
    function agent:reportDeath(id, col, prevState)
        local GameState = self:getGameState()
        local death = {
            entityId = id,
            name = col.name,
            day = GameState.day,
            hour = GameState.hour,
            cause = self:inferDeathCause(col, prevState),
            lastHealth = prevState.health,
            lastWarmth = prevState.warmth,
            lastFood = prevState.food,
        }
        self.deaths[#self.deaths + 1] = death

        self:high('colonist_death',
            col.name .. ' died (cause: ' .. death.cause .. ')',
            death)
    end

    function agent:inferDeathCause(col, prevState)
        if prevState.warmth and prevState.warmth < 10 then
            return 'hypothermia'
        elseif prevState.food and prevState.food < 5 then
            return 'starvation'
        elseif col.health and col.health <= 0 then
            return 'health_loss'
        else
            return 'unknown'
        end
    end

    -----------------------------------------------------------------
    -- Mental break reporting
    -----------------------------------------------------------------
    function agent:reportMentalBreak(id, col, needs)
        local GameState = self:getGameState()
        local breakInfo = {
            entityId = id,
            name = col.name,
            day = GameState.day,
            breakType = col._mentalBreak and col._mentalBreak.type or 'unknown',
            morale = needs and needs.morale,
        }
        self.mentalBreaks[#self.mentalBreaks + 1] = breakInfo

        self:medium('mental_break',
            col.name .. ' had mental break: ' .. breakInfo.breakType,
            breakInfo)
    end

    -----------------------------------------------------------------
    -- Critical needs check
    -----------------------------------------------------------------
    function agent:checkCriticalNeeds(id, col, needs)
        local name = col.name or 'Colonist ' .. id

        if needs.warmth and needs.warmth < 5 then
            self:high('critical_need',
                name .. ' is freezing (warmth: ' .. math.floor(needs.warmth) .. ')',
                { entityId = id, need = 'warmth', value = needs.warmth })
        end

        if needs.food and needs.food < 5 then
            self:high('critical_need',
                name .. ' is starving (food: ' .. math.floor(needs.food) .. ')',
                { entityId = id, need = 'food', value = needs.food })
        end

        if needs.rest and needs.rest < 5 then
            self:medium('critical_need',
                name .. ' is exhausted (rest: ' .. math.floor(needs.rest) .. ')',
                { entityId = id, need = 'rest', value = needs.rest })
        end

        if needs.morale and needs.morale < 10 then
            self:medium('critical_need',
                name .. ' has critical morale (' .. math.floor(needs.morale) .. ')',
                { entityId = id, need = 'morale', value = needs.morale })
        end
    end

    -----------------------------------------------------------------
    -- Finish
    -----------------------------------------------------------------
    function agent:onFinish()
        self:observe('total_deaths', #self.deaths)
        self:observe('total_mental_breaks', #self.mentalBreaks)
        self:observe('final_population', self.lastColonistCount)
    end

    return agent
end

return ColonistAgent
