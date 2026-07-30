-- FROSTHOLD — Economy Simulation Agent
-- src/testing/agents/economy_agent.lua
-- Tests resource flow, production, trade, and economic balance.

local SimAgent = require('src.testing.sim_agent')

local EconomyAgent = {}

function EconomyAgent.new(config)
    config = config or {}
    config.name = config.name or 'EconomyAgent'
    config.description = config.description or 'Tests economic systems'
    config.tickInterval = config.tickInterval or 100  -- every 5 seconds

    local agent = SimAgent.new(config)

    -- Tracking
    agent.resourceHistory = {}
    agent.productionEvents = {}
    agent.tradeEvents = {}
    agent.lastResources = {}

    -- Thresholds for warnings
    agent.criticalThresholds = {
        food = 10,
        wood = 5,
        fuel = 5,
    }
    agent.abundanceThresholds = {
        food = 500,
        wood = 1000,
        metal = 500,
    }

    -----------------------------------------------------------------
    -- Init
    -----------------------------------------------------------------
    function agent:onInit()
        self.resourceHistory = {}
        self.productionEvents = {}
        self.tradeEvents = {}
        self:snapshotResources()
    end

    -----------------------------------------------------------------
    -- Snapshot resources
    -----------------------------------------------------------------
    function agent:snapshotResources()
        local GameState = self:getGameState()
        local resources = GameState.resources or {}

        self.lastResources = {}
        for name, amount in pairs(resources) do
            self.lastResources[name] = amount
        end
    end

    -----------------------------------------------------------------
    -- Edible stock on the map (ground items + stockpile zones), counted in
    -- units. Food lives as items now, so any real shortage check needs these.
    -----------------------------------------------------------------
    function agent:countFoodItems()
        local pok, Prod = pcall(require, 'src.building.production')
        if not pok or not Prod.FOOD_QUALITY then return 0 end
        local fq = Prod.FOOD_QUALITY
        local total = 0

        local eok, ECS = pcall(require, 'src.ecs.ecs')
        if eok then
            for _, comps in ECS.query('pos', 'item') do
                local item = comps.item
                if fq[item.itemId] then total = total + (item.amount or 1) end
            end
        end

        local zok, Zones = pcall(require, 'src.world.zones')
        if zok and Zones.getByType then
            for _, zone in ipairs(Zones.getByType('stockpile')) do
                for _, item in pairs(zone.items or {}) do
                    if fq[item.itemId] then total = total + (item.amount or 1) end
                end
            end
        end
        return total
    end

    -----------------------------------------------------------------
    -- Tick
    -----------------------------------------------------------------
    function agent:onTick(dt)
        local GameState = self:getGameState()
        local resources = GameState.resources or {}

        -- Track resource changes
        for name, amount in pairs(resources) do
            local prev = self.lastResources[name] or 0
            local delta = amount - prev

            -- Record significant changes
            if math.abs(delta) > 5 then
                self:recordResourceChange(name, prev, amount, delta)
            end

            -- Track metrics for key resources
            if name == 'food' or name == 'wood' or name == 'metal' or name == 'fuel' then
                self:trackMetric('resource_' .. name, amount)
            end

            -- Check critical thresholds.
            -- 'food' is special: it became physical items, and the crashlanded
            -- start deliberately pins the legacy global pool at 10. Counting
            -- only the pool reported a critical shortage 544 times in a
            -- 5-day run while the colony had a week of rations on the ground.
            local effective = amount
            if name == 'food' then
                effective = amount + self:countFoodItems()
            end
            if self.criticalThresholds[name] and effective < self.criticalThresholds[name] then
                self:high('critical_resource',
                    'Critical ' .. name .. ' shortage: ' .. effective,
                    { resource = name, amount = effective, threshold = self.criticalThresholds[name] })
            end

            -- Check for negative resources (bug)
            if amount < 0 then
                self:critical('negative_resource',
                    'Resource ' .. name .. ' is negative: ' .. amount,
                    { resource = name, amount = amount })
            end

            -- Check for NaN
            if amount ~= amount then
                self:critical('nan_resource',
                    'Resource ' .. name .. ' is NaN',
                    { resource = name })
            end

            -- Check for infinite
            if amount == math.huge or amount == -math.huge then
                self:critical('infinite_resource',
                    'Resource ' .. name .. ' is infinite',
                    { resource = name, amount = tostring(amount) })
            end
        end

        -- Check production buildings
        self:checkProduction()

        -- Check trade
        self:checkTrade()

        -- Update snapshot
        self:snapshotResources()
    end

    -----------------------------------------------------------------
    -- Resource change recording
    -----------------------------------------------------------------
    function agent:recordResourceChange(name, prev, current, delta)
        local GameState = self:getGameState()
        local entry = {
            resource = name,
            previous = prev,
            current = current,
            delta = delta,
            day = GameState.day,
            tick = GameState.simTick,
        }

        if not self.resourceHistory[name] then
            self.resourceHistory[name] = {}
        end
        local history = self.resourceHistory[name]
        history[#history + 1] = entry

        -- Keep history bounded
        if #history > 100 then
            table.remove(history, 1)
        end
    end

    -----------------------------------------------------------------
    -- Production checking
    -----------------------------------------------------------------
    function agent:checkProduction()
        local ok, ECS = pcall(require, 'src.ecs.ecs')
        if not ok then return end

        local activeProducers = 0
        local idleProducers = 0

        for id, comps in ECS.query('producer') do
            local prod = comps.producer
            local building = ECS.get(id, 'building')

            if building and building.complete then
                if prod.active or prod.currentRecipe then
                    activeProducers = activeProducers + 1
                else
                    idleProducers = idleProducers + 1
                end

                -- Check for stuck producers
                if prod._stuckTicks then
                    prod._stuckTicks = prod._stuckTicks + 1
                    if prod._stuckTicks > 1200 then  -- 1 minute stuck
                        self:medium('stuck_producer',
                            'Production building stuck for extended period',
                            { entityId = id, recipe = prod.currentRecipe })
                        prod._stuckTicks = 0  -- reset
                    end
                end

                -- Check production progress validity
                if prod.progress and (prod.progress < 0 or prod.progress > 1.1) then
                    self:high('invalid_production_progress',
                        'Production progress out of bounds: ' .. prod.progress,
                        { entityId = id, progress = prod.progress })
                end
            end
        end

        self:trackMetric('active_producers', activeProducers)
        self:trackMetric('idle_producers', idleProducers)
    end

    -----------------------------------------------------------------
    -- Trade checking
    -----------------------------------------------------------------
    function agent:checkTrade()
        local ok, Merchants = pcall(require, 'src.trade.merchants')
        if not ok then return end

        -- Check if merchant is present
        if Merchants.isMerchantPresent and Merchants.isMerchantPresent() then
            self:trackMetric('merchant_present', 1)
        else
            self:trackMetric('merchant_present', 0)
        end
    end

    -----------------------------------------------------------------
    -- Economy health assessment
    -----------------------------------------------------------------
    function agent:assessEconomyHealth()
        local GameState = self:getGameState()
        local resources = GameState.resources or {}

        local score = 100
        local issues = {}

        -- Food security (pool + edible items on the map)
        local food = (resources.food or 0) + self:countFoodItems()
        if food < 20 then
            score = score - 30
            issues[#issues + 1] = 'critical food shortage'
        elseif food < 50 then
            score = score - 10
            issues[#issues + 1] = 'low food'
        end

        -- Building materials
        local wood = resources.wood or 0
        local stone = resources.stone or 0
        if wood < 10 and stone < 10 then
            score = score - 20
            issues[#issues + 1] = 'no building materials'
        end

        -- Fuel for heating
        local fuel = resources.fuel or 0
        if fuel < 10 then
            score = score - 15
            issues[#issues + 1] = 'low fuel'
        end

        return {
            score = math.max(0, score),
            issues = issues,
            resources = resources,
        }
    end

    -----------------------------------------------------------------
    -- Finish
    -----------------------------------------------------------------
    function agent:onFinish()
        local health = self:assessEconomyHealth()
        self:observe('economy_health_score', health.score)
        self:observe('economy_issues', #health.issues)

        -- Summarize resource flow
        for name, history in pairs(self.resourceHistory) do
            local totalGain = 0
            local totalLoss = 0
            for _, entry in ipairs(history) do
                if entry.delta > 0 then
                    totalGain = totalGain + entry.delta
                else
                    totalLoss = totalLoss + math.abs(entry.delta)
                end
            end
            self:observe(name .. '_total_gained', totalGain)
            self:observe(name .. '_total_lost', totalLoss)
        end
    end

    return agent
end

return EconomyAgent
