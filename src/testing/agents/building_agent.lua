-- FROSTHOLD — Building Simulation Agent
-- src/testing/agents/building_agent.lua
-- Tests building placement, construction, and functionality.
-- Can proactively place buildings to stress-test the system.

local SimAgent = require('src.testing.sim_agent')

local BuildingAgent = {}

function BuildingAgent.new(config)
    config = config or {}
    config.name = config.name or 'BuildingAgent'
    config.description = config.description or 'Tests building systems'
    config.tickInterval = config.tickInterval or 40  -- every 2 seconds

    local agent = SimAgent.new(config)

    -- Config
    agent.autoBuild = config.autoBuild or false     -- automatically place buildings
    agent.buildBudget = config.buildBudget or 10    -- max buildings to auto-place
    agent.builtCount = 0

    -- Tracking
    agent.buildingStates = {}
    agent.constructionJobs = {}
    agent.stuckConstructions = {}

    -----------------------------------------------------------------
    -- Building definitions to test
    -----------------------------------------------------------------
    local TEST_BUILDINGS = {
        { id = 'wall_wood', priority = 1, minResources = { wood = 5 } },
        { id = 'floor_wood', priority = 1, minResources = { wood = 2 } },
        { id = 'door', priority = 2, minResources = { wood = 10 } },
        { id = 'campfire', priority = 3, minResources = { wood = 10 } },
        { id = 'bed', priority = 4, minResources = { wood = 20 } },
        { id = 'storage_crate', priority = 5, minResources = { wood = 15 } },
        { id = 'workbench', priority = 6, minResources = { wood = 30, stone = 10 } },
    }

    -----------------------------------------------------------------
    -- Init
    -----------------------------------------------------------------
    function agent:onInit()
        self.buildingStates = {}
        self.constructionJobs = {}
        self.stuckConstructions = {}
        self.builtCount = 0
        self:snapshotBuildings()
    end

    -----------------------------------------------------------------
    -- Snapshot buildings
    -----------------------------------------------------------------
    function agent:snapshotBuildings()
        local ECS = require('src.ecs.ecs')

        for id, comps in ECS.query('building') do
            local b = comps.building
            local pos = ECS.get(id, 'pos')

            self.buildingStates[id] = {
                defId = b.defId,
                complete = b.complete,
                progress = b.progress,
                x = pos and pos.x,
                y = pos and pos.y,
                lastProgress = self.buildingStates[id] and self.buildingStates[id].progress or 0,
                staleTicks = self.buildingStates[id] and self.buildingStates[id].staleTicks or 0,
            }
        end
    end

    -----------------------------------------------------------------
    -- Tick
    -----------------------------------------------------------------
    function agent:onTick(dt)
        local ECS = require('src.ecs.ecs')
        local GameState = self:getGameState()

        local totalBuildings = 0
        local completeBuildings = 0
        local underConstruction = 0

        for id, comps in ECS.query('building') do
            totalBuildings = totalBuildings + 1
            local b = comps.building
            local prev = self.buildingStates[id]

            if b.complete then
                completeBuildings = completeBuildings + 1
            else
                underConstruction = underConstruction + 1

                -- Check for stuck construction
                if prev then
                    local progressDelta = (b.progress or 0) - (prev.lastProgress or 0)
                    if progressDelta <= 0.001 then
                        prev.staleTicks = (prev.staleTicks or 0) + 1
                        if prev.staleTicks > 600 then  -- 30 seconds with no progress
                            if not self.stuckConstructions[id] then
                                self.stuckConstructions[id] = true
                                local pos = ECS.get(id, 'pos')
                                self:medium('stuck_construction',
                                    'Building ' .. (b.defId or 'unknown') .. ' stuck at ' ..
                                    math.floor((b.progress or 0) * 100) .. '%',
                                    { entityId = id, defId = b.defId,
                                      progress = b.progress,
                                      x = pos and pos.x, y = pos and pos.y })
                            end
                        end
                    else
                        prev.staleTicks = 0
                        self.stuckConstructions[id] = nil
                    end
                    prev.lastProgress = b.progress or 0
                end
            end

            -- Check for invalid building state
            if b.progress and (b.progress < 0 or b.progress > 1.1) then
                self:high('invalid_progress',
                    'Building ' .. (b.defId or id) .. ' has invalid progress: ' .. b.progress,
                    { entityId = id, progress = b.progress })
            end
        end

        -- Track metrics
        self:trackMetric('total_buildings', totalBuildings)
        self:trackMetric('under_construction', underConstruction)

        -- Auto-build if enabled
        if self.autoBuild and self.builtCount < self.buildBudget then
            self:tryAutoBuild()
        end

        -- Update snapshot
        self:snapshotBuildings()
    end

    -----------------------------------------------------------------
    -- Auto-build (for stress testing)
    -----------------------------------------------------------------
    function agent:tryAutoBuild()
        local ok, Building = pcall(require, 'src.building.building')
        if not ok or not Building.tryPlace then return end

        local GameState = self:getGameState()
        local resources = GameState.resources or {}

        -- Find a building we can afford
        for _, def in ipairs(TEST_BUILDINGS) do
            local canAfford = true
            if def.minResources then
                for res, amount in pairs(def.minResources) do
                    if (resources[res] or 0) < amount then
                        canAfford = false
                        break
                    end
                end
            end

            if canAfford then
                -- Find a valid placement spot
                local cx = GameState.startX or 64
                local cy = GameState.startY or 64
                local radius = 10 + self.builtCount

                for attempt = 1, 20 do
                    local x = cx + math.random(-radius, radius)
                    local y = cy + math.random(-radius, radius)

                    local success, msg = Building.tryPlace(def.id, x, y, nil, false, 0)
                    if success then
                        self.builtCount = self.builtCount + 1
                        self:recordAction('place_building', { defId = def.id, x = x, y = y }, 'success')
                        return
                    end
                end
            end
        end
    end

    -----------------------------------------------------------------
    -- Test specific building placement
    -----------------------------------------------------------------
    function agent:testPlacement(defId, x, y)
        local ok, Building = pcall(require, 'src.building.building')
        if not ok then
            self:critical('module_error', 'Failed to load building module')
            return false
        end

        local success, msg = Building.tryPlace(defId, x, y, nil, false, 0)

        if success then
            self:recordAction('test_placement', { defId = defId, x = x, y = y }, 'success')
        else
            self:recordAction('test_placement', { defId = defId, x = x, y = y }, msg or 'failed')
            -- This might be expected (blocked terrain, etc.), so only log as low
            self:low('placement_failed',
                'Could not place ' .. defId .. ' at ' .. x .. ',' .. y .. ': ' .. (msg or 'unknown'),
                { defId = defId, x = x, y = y, reason = msg })
        end

        return success
    end

    -----------------------------------------------------------------
    -- Finish
    -----------------------------------------------------------------
    function agent:onFinish()
        local totalBuilt = 0
        local totalComplete = 0
        for id, state in pairs(self.buildingStates) do
            totalBuilt = totalBuilt + 1
            if state.complete then totalComplete = totalComplete + 1 end
        end

        self:observe('total_buildings_tracked', totalBuilt)
        self:observe('complete_buildings', totalComplete)
        self:observe('stuck_constructions', self:tableLen(self.stuckConstructions))
        self:observe('auto_built', self.builtCount)
    end

    function agent:tableLen(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    return agent
end

return BuildingAgent
