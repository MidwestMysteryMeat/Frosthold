-- FROSTHOLD — Combat Simulation Agent
-- src/testing/agents/combat_agent.lua
-- Tests raids, creature combat, damage system, wounds.
-- Can trigger test raids to stress-test combat systems.

local SimAgent = require('src.testing.sim_agent')

local CombatAgent = {}

function CombatAgent.new(config)
    config = config or {}
    config.name = config.name or 'CombatAgent'
    config.description = config.description or 'Tests combat and raid systems'
    config.tickInterval = config.tickInterval or 10  -- every 0.5 seconds

    local agent = SimAgent.new(config)

    -- Config
    agent.triggerTestRaids = config.triggerTestRaids or false
    agent.raidIntervalDays = config.raidIntervalDays or 5
    agent.lastRaidDay = 0

    -- Tracking
    agent.raids = {}
    agent.combatEvents = {}
    agent.creatureStates = {}
    agent.wounds = {}

    -----------------------------------------------------------------
    -- Init
    -----------------------------------------------------------------
    function agent:onInit()
        self.raids = {}
        self.combatEvents = {}
        self.creatureStates = {}
        self.wounds = {}
        self.lastRaidDay = 0
        self:snapshotCreatures()
    end

    -----------------------------------------------------------------
    -- Snapshot creatures
    -----------------------------------------------------------------
    function agent:snapshotCreatures()
        local ECS = require('src.ecs.ecs')

        local newStates = {}
        for id, comps in ECS.query('creature') do
            local cr = comps.creature
            local pos = ECS.get(id, 'pos')

            newStates[id] = {
                species = cr.species,
                health = cr.health,
                maxHealth = cr.maxHealth,
                state = cr.state,
                hostile = cr.hostile,
                x = pos and pos.x,
                y = pos and pos.y,
            }
        end
        self.creatureStates = newStates
    end

    -----------------------------------------------------------------
    -- Tick
    -----------------------------------------------------------------
    function agent:onTick(dt)
        local ECS = require('src.ecs.ecs')
        local GameState = self:getGameState()

        -- Check raid state
        self:checkRaidState()

        -- Count creatures
        local hostileCount = 0
        local friendlyCount = 0
        local deadCount = 0

        for id, comps in ECS.query('creature') do
            local cr = comps.creature
            local prev = self.creatureStates[id]

            if cr.state == 'dead' then
                deadCount = deadCount + 1
                -- Check for new deaths
                if prev and prev.state ~= 'dead' then
                    self:recordCombatEvent('creature_death', {
                        entityId = id,
                        species = cr.species,
                        wasHostile = cr.hostile,
                    })
                end
            else
                if cr.hostile then
                    hostileCount = hostileCount + 1
                else
                    friendlyCount = friendlyCount + 1
                end

                -- Check for damage taken
                if prev and prev.health and cr.health then
                    local damage = prev.health - cr.health
                    if damage > 0 then
                        self:recordCombatEvent('creature_damaged', {
                            entityId = id,
                            species = cr.species,
                            damage = damage,
                            healthRemaining = cr.health,
                        })
                    end
                end
            end

            -- Validate creature state
            if cr.health and cr.health < 0 then
                self:high('negative_health',
                    'Creature ' .. (cr.species or id) .. ' has negative health: ' .. cr.health,
                    { entityId = id, health = cr.health })
            end
        end

        -- Track metrics
        self:trackMetric('hostile_creatures', hostileCount)
        self:trackMetric('friendly_creatures', friendlyCount)

        -- Check colonist wounds
        self:checkColonistWounds()

        -- Trigger test raids if enabled
        if self.triggerTestRaids then
            local day = GameState.day or 0
            if day - self.lastRaidDay >= self.raidIntervalDays then
                self:triggerRaid()
                self.lastRaidDay = day
            end
        end

        -- Update snapshot
        self:snapshotCreatures()
    end

    -----------------------------------------------------------------
    -- Raid state checking
    -----------------------------------------------------------------
    function agent:checkRaidState()
        local ok, Raids = pcall(require, 'src.sim.raids')
        if not ok then return end

        local isActive = Raids.isRaidActive and Raids.isRaidActive()
        local GameState = self:getGameState()

        -- Detect raid start
        if isActive and not self._raidActive then
            self._raidActive = true
            self._raidStartDay = GameState.day
            self._raidStartTick = GameState.simTick

            local raidInfo = {
                startDay = GameState.day,
                startHour = GameState.hour,
                tick = GameState.simTick,
            }
            self.raids[#self.raids + 1] = raidInfo

            self:medium('raid_start',
                'Raid started on day ' .. GameState.day,
                raidInfo)
        end

        -- Detect raid end
        if not isActive and self._raidActive then
            self._raidActive = false
            local duration = (GameState.simTick or 0) - (self._raidStartTick or 0)

            self:medium('raid_end',
                'Raid ended after ' .. duration .. ' ticks',
                { duration = duration, day = GameState.day })

            -- Check for very long raids (might indicate stuck state)
            if duration > 2400 then  -- 2 minutes at 20Hz
                self:high('long_raid',
                    'Raid lasted unusually long: ' .. duration .. ' ticks',
                    { duration = duration })
            end
        end
    end

    -----------------------------------------------------------------
    -- Colonist wounds
    -----------------------------------------------------------------
    function agent:checkColonistWounds()
        local ECS = require('src.ecs.ecs')

        for id, comps in ECS.query('colonist', 'wounds') do
            local col = comps.colonist
            local wounds = comps.wounds

            if wounds and wounds.list then
                for i, wound in ipairs(wounds.list) do
                    -- Track new wounds
                    local woundKey = id .. '_' .. i .. '_' .. (wound.type or 'unknown')
                    if not self.wounds[woundKey] then
                        self.wounds[woundKey] = true
                        self:recordCombatEvent('wound_inflicted', {
                            entityId = id,
                            colonistName = col.name,
                            woundType = wound.type,
                            part = wound.part,
                            severity = wound.severity,
                        })
                    end

                    -- Check for infected wounds
                    if wound.infected and wound.treatment ~= 'medicated' then
                        self:medium('infected_wound',
                            (col.name or 'Colonist') .. ' has infected ' .. (wound.type or 'wound'),
                            { entityId = id, woundType = wound.type })
                    end
                end
            end
        end
    end

    -----------------------------------------------------------------
    -- Combat event recording
    -----------------------------------------------------------------
    function agent:recordCombatEvent(eventType, data)
        local GameState = self:getGameState()
        local event = {
            type = eventType,
            data = data,
            day = GameState.day,
            tick = GameState.simTick,
        }
        self.combatEvents[#self.combatEvents + 1] = event
    end

    -----------------------------------------------------------------
    -- Trigger test raid
    -----------------------------------------------------------------
    function agent:triggerRaid()
        local ok, Raids = pcall(require, 'src.sim.raids')
        if not ok or not Raids.triggerRaid then
            self:low('module_missing', 'Could not trigger test raid - module unavailable')
            return false
        end

        local success = Raids.triggerRaid({
            budget = 100,
            direction = 'random',
            forced = true,
        })

        if success then
            self:recordAction('trigger_raid', { budget = 100 }, 'success')
        else
            self:recordAction('trigger_raid', { budget = 100 }, 'failed')
        end

        return success
    end

    -----------------------------------------------------------------
    -- Spawn test creature
    -----------------------------------------------------------------
    function agent:spawnTestCreature(species, x, y, hostile)
        local ok, Creatures = pcall(require, 'src.creatures.creatures')
        if not ok or not Creatures.spawn then
            return nil
        end

        local id = Creatures.spawn(species, x, y)
        if id and hostile ~= nil then
            local ECS = require('src.ecs.ecs')
            local cr = ECS.get(id, 'creature')
            if cr then
                cr.hostile = hostile
            end
        end

        self:recordAction('spawn_creature', { species = species, x = x, y = y }, id and 'success' or 'failed')
        return id
    end

    -----------------------------------------------------------------
    -- Finish
    -----------------------------------------------------------------
    function agent:onFinish()
        self:observe('total_raids', #self.raids)
        self:observe('total_combat_events', #self.combatEvents)

        -- Count event types
        local eventCounts = {}
        for _, event in ipairs(self.combatEvents) do
            eventCounts[event.type] = (eventCounts[event.type] or 0) + 1
        end
        for eventType, count in pairs(eventCounts) do
            self:observe('combat_' .. eventType, count)
        end
    end

    return agent
end

return CombatAgent
