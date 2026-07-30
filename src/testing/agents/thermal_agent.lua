-- FROSTHOLD — Thermal Simulation Agent
-- src/testing/agents/thermal_agent.lua
-- Tests temperature system, heating, cold damage, frostbite.

local SimAgent = require('src.testing.sim_agent')

local ThermalAgent = {}

function ThermalAgent.new(config)
    config = config or {}
    config.name = config.name or 'ThermalAgent'
    config.description = config.description or 'Tests thermal/temperature systems'
    config.tickInterval = config.tickInterval or 20  -- every second

    local agent = SimAgent.new(config)

    -- Tracking
    agent.tempHistory = {}
    agent.heatingEvents = {}
    agent.frostbiteEvents = {}
    agent.extremeTemps = {}

    -----------------------------------------------------------------
    -- Init
    -----------------------------------------------------------------
    function agent:onInit()
        self.tempHistory = {}
        self.heatingEvents = {}
        self.frostbiteEvents = {}
        self.extremeTemps = {}
    end

    -----------------------------------------------------------------
    -- Tick
    -----------------------------------------------------------------
    function agent:onTick(dt)
        local ECS = require('src.ecs.ecs')
        local GameState = self:getGameState()

        -- Track global temperature
        local globalTemp = GameState.globalTemp or -40
        self:trackMetric('global_temp', globalTemp)

        -- Check for extreme temperatures
        if globalTemp < -80 then
            self:high('extreme_cold',
                'Extremely cold temperature: ' .. globalTemp .. 'C',
                { temp = globalTemp })
        elseif globalTemp > 50 then
            self:high('extreme_heat',
                'Extremely hot temperature: ' .. globalTemp .. 'C',
                { temp = globalTemp })
        end

        -- Check temperature validity
        if globalTemp ~= globalTemp then  -- NaN
            self:critical('nan_temperature',
                'Global temperature is NaN', {})
        end

        -- Check colonist warmth needs
        self:checkColonistWarmth()

        -- Check heating infrastructure
        self:checkHeatingInfrastructure()

        -- Check generator state
        self:checkGenerator()

        -- Track room temperatures (sample)
        self:sampleRoomTemps()

        -- Dev diagnostic (--coldtrace): how much warm ground actually exists,
        -- and what state the fires are in. A freezing death with no reachable
        -- warm tile looks identical to one where the colonist just walked the
        -- wrong way; this line separates the two.
        if _G.COLD_TRACE then
            self._ctBeat = (self._ctBeat or 0) + 1
            if self._ctBeat >= 10 then
                self._ctBeat = 0
                local World = require('src.world.tilemap')
                local warm, mild = 0, 0
                for ty = 0, World.height() - 1 do
                    for tx = 0, World.width() - 1 do
                        local t = World.getTemp(tx, ty, 0)
                        if t > 15 then warm = warm + 1
                        elseif t > 10 then mild = mild + 1 end
                    end
                end
                local fires = {}
                local bok, Building = pcall(require, 'src.building.building')
                if bok and Building.getAll then
                    for _, info in pairs(Building.getAll()) do
                        if info.def and info.def.heatDanger and not info.subTile then
                            fires[#fires + 1] = string.format('%s@(%d,%d) fuel=%.0f active=%s',
                                tostring(info.id or info.def.name), info.x or -1, info.y or -1,
                                info.fuel or -1, tostring(info.active))
                        end
                    end
                end
                print(string.format('[Cold] d%d %05.2f WORLD amb=%.1f warm>15=%d mild>10=%d wood=%.0f fires[%s]',
                    GameState.day or 0, GameState.hour or 0,
                    GameState.getEffectiveTemp(), warm, mild,
                    (GameState.resources and GameState.resources.wood) or -1,
                    table.concat(fires, ' | ')))
            end
        end
    end

    -----------------------------------------------------------------
    -- Colonist warmth
    -----------------------------------------------------------------
    function agent:checkColonistWarmth()
        local ECS = require('src.ecs.ecs')
        local GameState = self:getGameState()

        local freezingCount = 0
        local coldCount = 0
        local warmCount = 0

        for id, comps in ECS.query('colonist', 'needs') do
            local col = comps.colonist
            local needs = comps.needs

            if col.state ~= 'dead' then
                local warmth = needs.warmth or 50

                if warmth < 10 then
                    freezingCount = freezingCount + 1

                    -- Check for hypothermia progression
                    if col.hypothermiaStage and col.hypothermiaStage >= 3 then
                        self:high('severe_hypothermia',
                            (col.name or 'Colonist') .. ' has severe hypothermia (stage ' ..
                            col.hypothermiaStage .. ')',
                            { entityId = id, stage = col.hypothermiaStage, warmth = warmth })
                    end
                elseif warmth < 30 then
                    coldCount = coldCount + 1
                else
                    warmCount = warmCount + 1
                end

                -- Track warmth metric
                self:trackMetric('colonist_warmth_avg', warmth)
            end
        end

        self:trackMetric('freezing_colonists', freezingCount)
        self:trackMetric('cold_colonists', coldCount)
        self:trackMetric('warm_colonists', warmCount)

        -- Alert if all colonists are freezing
        if freezingCount > 0 and warmCount == 0 then
            self:high('all_freezing',
                'All colonists are freezing (' .. freezingCount .. ' colonists)',
                { count = freezingCount })
        end
    end

    -----------------------------------------------------------------
    -- Heating infrastructure
    -----------------------------------------------------------------
    function agent:checkHeatingInfrastructure()
        local ECS = require('src.ecs.ecs')

        local heaters = 0
        local activeHeaters = 0
        local steamHubs = 0
        local activeSteamHubs = 0

        for id, comps in ECS.query('building') do
            local b = comps.building

            if b.complete then
                if b.defId == 'heater' or b.defId == 'steam_hub' then
                    if b.defId == 'heater' then
                        heaters = heaters + 1
                    else
                        steamHubs = steamHubs + 1
                    end

                    -- Check if powered/active
                    local power = ECS.get(id, 'power_consumer')
                    if power and power.powered then
                        if b.defId == 'heater' then
                            activeHeaters = activeHeaters + 1
                        else
                            activeSteamHubs = activeSteamHubs + 1
                        end
                    end
                end
            end
        end

        self:trackMetric('heaters', heaters)
        self:trackMetric('active_heaters', activeHeaters)
        self:trackMetric('steam_hubs', steamHubs)
        self:trackMetric('active_steam_hubs', activeSteamHubs)
    end

    -----------------------------------------------------------------
    -- Generator
    -----------------------------------------------------------------
    function agent:checkGenerator()
        local ok, Generator = pcall(require, 'src.sim.generator')
        if not ok then return end

        -- Check generator state
        if Generator.getState then
            local state = Generator.getState()
            if state then
                self:trackMetric('generator_power_level', state.powerLevel or 0)
                self:trackMetric('generator_fuel', state.fuel or 0)
                self:trackMetric('generator_heat', state.heat or 0)

                -- Check for overheat
                if state.heat and state.heat > 90 then
                    self:high('generator_overheat',
                        'Generator overheating: ' .. state.heat .. '%',
                        { heat = state.heat })
                end

                -- Check for fuel exhaustion
                if state.fuel and state.fuel < 10 and state.powerLevel > 0 then
                    self:medium('generator_low_fuel',
                        'Generator running low on fuel: ' .. state.fuel,
                        { fuel = state.fuel })
                end

                -- Check for meltdown risk
                if state.meltdownRisk and state.meltdownRisk > 0.5 then
                    self:critical('meltdown_risk',
                        'Generator meltdown risk: ' .. math.floor(state.meltdownRisk * 100) .. '%',
                        { risk = state.meltdownRisk })
                end
            end
        end
    end

    -----------------------------------------------------------------
    -- Room temperature sampling
    -----------------------------------------------------------------
    function agent:sampleRoomTemps()
        local ok, Rooms = pcall(require, 'src.world.rooms')
        if not ok or not Rooms.getAllRooms then return end

        local rooms = Rooms.getAllRooms()
        if not rooms then return end

        local coldRooms = 0
        local warmRooms = 0

        for _, room in pairs(rooms) do
            if room.temperature then
                if room.temperature < -10 then
                    coldRooms = coldRooms + 1
                elseif room.temperature > 10 then
                    warmRooms = warmRooms + 1
                end
            end
        end

        self:trackMetric('cold_rooms', coldRooms)
        self:trackMetric('warm_rooms', warmRooms)
    end

    -----------------------------------------------------------------
    -- Finish
    -----------------------------------------------------------------
    function agent:onFinish()
        -- Analyze temperature trends
        local temps = self.metrics['global_temp'] or {}
        if #temps > 0 then
            local minTemp = temps[1].value
            local maxTemp = temps[1].value
            local sumTemp = 0

            for _, entry in ipairs(temps) do
                if entry.value < minTemp then minTemp = entry.value end
                if entry.value > maxTemp then maxTemp = entry.value end
                sumTemp = sumTemp + entry.value
            end

            self:observe('temp_min', minTemp)
            self:observe('temp_max', maxTemp)
            self:observe('temp_avg', sumTemp / #temps)
            self:observe('temp_range', maxTemp - minTemp)
        end
    end

    return agent
end

return ThermalAgent
