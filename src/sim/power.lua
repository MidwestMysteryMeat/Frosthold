-- power.lua — Power grid system (union-find based)
-- Generators produce watts, machines consume watts.
-- Connected via conduit wires. Batteries store excess. Priority-based brownout.
-- Generators can fault: lose 50% efficiency, emit 3x CO2, need repair.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Jobs      = require('src.colonist.jobs')

local Power = {}

---------------------------------------------------------------------------
-- Generator definitions (extracted to power_defs.lua)
---------------------------------------------------------------------------

local GENERATORS = require('src.sim.power_defs')
Power.GENERATORS = GENERATORS

---------------------------------------------------------------------------
-- Union-find for grid connectivity
---------------------------------------------------------------------------

local parent = {}
local rank   = {}

local function ufFind(x)
    if parent[x] ~= x then
        parent[x] = ufFind(parent[x])
    end
    return parent[x]
end

local function ufUnion(a, b)
    local ra, rb = ufFind(a), ufFind(b)
    if ra == rb then return end
    if rank[ra] < rank[rb] then ra, rb = rb, ra end
    parent[rb] = ra
    if rank[ra] == rank[rb] then rank[ra] = rank[ra] + 1 end
end

---------------------------------------------------------------------------
-- Battery / switch / priority constants
---------------------------------------------------------------------------

-- Default battery properties (overridden per-type via addBattery params)
local BATTERY_CAPACITY         = 2000   -- energy units per battery (standard)
local BATTERY_CHARGE_EFF       = 0.5    -- 50% charge efficiency
local BATTERY_SELF_DISCHARGE   = 0.002  -- energy units drained per second
local ZZZT_BASE_CHANCE         = 0.00002  -- per tick, scaled by stored ratio

-- Consumer priority levels (shed order: low first, then normal, critical last)
Power.PRIORITY_CRITICAL = 'critical'
Power.PRIORITY_NORMAL   = 'normal'
Power.PRIORITY_LOW      = 'low'

local function isPriorityPowered(priority, level)
    if level == 'all' then return true end
    if level == 'normal' then return priority ~= 'low' end
    if level == 'critical' then return priority == 'critical' end
    return false  -- 'none'
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local conduits   = {}  -- { [tileKey] = { x, y } }
local generators = {}  -- { [entityId] = { genType, tileKey, fuel, ... } }
local consumers  = {}  -- { [entityId] = { watts, tileKey, priority } }
local batteries  = {}  -- { [entityId] = { tileKey, x, y, stored, capacity } }
local switches   = {}  -- { [tileKey] = { on = bool, entityId = id } }
local gridStats  = {}  -- { [rootKey] = { supply, demand, ... } }

local rebuildCooldown = 0
local REBUILD_INTERVAL = 2

local forcedBrownout = 0  -- remaining seconds of forced brownout
local passiveWatts = 0    -- free watts from exclusive rewards (precursor core etc.)

local function tileKey(x, y) return y * 10000 + x end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Power.init()
    conduits = {}
    generators = {}
    consumers = {}
    batteries = {}
    switches = {}
    gridStats = {}
    parent = {}
    rank = {}
end

function Power.addConduit(x, y)
    local k = tileKey(x, y)
    conduits[k] = { x = x, y = y }
    rebuildCooldown = 0  -- force rebuild
end

function Power.removeConduit(x, y)
    conduits[tileKey(x, y)] = nil
    rebuildCooldown = 0
end

-- Fault system constants
local FAULT_CHANCE_PER_TICK = 0.00005  -- ~1 fault per generator per game-day
local FAULT_EFFICIENCY_MULT = 0.5    -- faulted generators produce 50% power
local FAULT_CO2_MULT        = 3.0    -- faulted generators emit 3x CO2

function Power.addGenerator(entityId, genType, x, y)
    generators[entityId] = {
        genType = genType,
        tileKey = tileKey(x, y),
        fuel    = 100,  -- start full
        x = x, y = y,
        faulted = false,      -- fault state
        repairTaskId = nil,   -- associated repair task
    }
    -- Also acts as conduit
    Power.addConduit(x, y)
end

function Power.removeGenerator(entityId)
    local gen = generators[entityId]
    if gen then
        Power.removeConduit(gen.x, gen.y)
    end
    generators[entityId] = nil
end

function Power.addConsumer(entityId, watts, x, y, priority)
    consumers[entityId] = {
        watts    = watts,
        tileKey  = tileKey(x, y),
        x = x, y = y,
        priority = priority or 'normal',
    }
    Power.addConduit(x, y)
end

function Power.removeConsumer(entityId)
    consumers[entityId] = nil
end

---------------------------------------------------------------------------
-- Battery API
---------------------------------------------------------------------------

function Power.addBattery(entityId, x, y, capacity, chargeEff, selfDischarge)
    batteries[entityId] = {
        tileKey       = tileKey(x, y),
        x = x, y = y,
        stored        = 0,
        capacity      = capacity or BATTERY_CAPACITY,
        chargeEff     = chargeEff or BATTERY_CHARGE_EFF,
        selfDischarge = selfDischarge or BATTERY_SELF_DISCHARGE,
    }
    Power.addConduit(x, y)
end

function Power.removeBattery(entityId)
    batteries[entityId] = nil
end

function Power.getBatteryCharge(entityId)
    local bat = batteries[entityId]
    return bat and bat.stored or 0
end

function Power.getBatteryPercent(entityId)
    local bat = batteries[entityId]
    if not bat or bat.capacity <= 0 then return 0 end
    return bat.stored / bat.capacity
end

function Power.getBatteries()
    return batteries
end

function Power.getTotalStored()
    local total = 0
    for _, bat in pairs(batteries) do
        total = total + bat.stored
    end
    return total
end

---------------------------------------------------------------------------
-- Switch API
---------------------------------------------------------------------------

function Power.addSwitch(entityId, x, y)
    local k = tileKey(x, y)
    switches[k] = { on = true, entityId = entityId }
    Power.addConduit(x, y)
end

function Power.removeSwitch(x, y)
    switches[tileKey(x, y)] = nil
end

function Power.toggleSwitch(x, y)
    local k = tileKey(x, y)
    if switches[k] then
        switches[k].on = not switches[k].on
        rebuildCooldown = 0  -- force grid rebuild
    end
end

function Power.isSwitchOn(x, y)
    local k = tileKey(x, y)
    if not switches[k] then return true end
    return switches[k].on
end

---------------------------------------------------------------------------
-- Rebuild grid connectivity
---------------------------------------------------------------------------

local function rebuildGrid()
    parent = {}
    rank = {}

    -- Init each conduit as its own set
    for k in pairs(conduits) do
        parent[k] = k
        rank[k] = 0
    end

    -- Union adjacent conduits (OFF switches block connectivity)
    for k, c in pairs(conduits) do
        if not switches[k] or switches[k].on then
            local dirs = { {1,0}, {-1,0}, {0,1}, {0,-1} }
            for _, d in ipairs(dirs) do
                local nk = tileKey(c.x + d[1], c.y + d[2])
                if conduits[nk] and (not switches[nk] or switches[nk].on) then
                    ufUnion(k, nk)
                end
            end
        end
    end

    -- Calculate supply/demand per grid
    gridStats = {}
    local function ensureGrid(root)
        if not gridStats[root] then
            gridStats[root] = {
                supply = 0, demand = 0,
                demandCritical = 0, demandNormal = 0, demandLow = 0,
                batteryIds = {}, batteryStored = 0, batteryCapacity = 0,
                poweredLevel = 'all',
            }
        end
    end

    for eid, gen in pairs(generators) do
        local root = ufFind(gen.tileKey)
        if root then
            ensureGrid(root)
            local def = GENERATORS[gen.genType]
            if def then
                -- Fuel-based generators need fuel > 0; fuelless generators always produce
                local hasFuel = (not def.fuelType) or gen.fuel > 0
                if hasFuel then
                    local output = def.output * (gen.outputMult or 1.0)

                    -- Intermittent sources scale with conditions
                    if def.intermittent == 'solar' then
                        -- 0% at night, ramp up 6-8 AM, peak 10-14, ramp down 16-18, 0% at 18+
                        local h = GameState.hour
                        if h < 6 or h >= 18 then
                            output = 0
                        elseif h < 8 then
                            output = output * ((h - 6) / 2)
                        elseif h > 16 then
                            output = output * ((18 - h) / 2)
                        end
                        local wok, Weather = pcall(require, 'src.weather.weather')
                        if wok then
                            local _, wdef = Weather.getCurrent()
                            if wdef and wdef.solarPenalty then
                                output = output * (1 - wdef.solarPenalty)
                            end
                        end

                    elseif def.intermittent == 'wind' then
                        local windFactor = 0.5 + math.min(0.7, math.abs(GameState.windChill) / 30)
                        output = output * windFactor

                    elseif def.intermittent == 'storm' then
                        -- Lightning rod: only produces during storms
                        local wok, Weather = pcall(require, 'src.weather.weather')
                        local active = false
                        if wok then
                            local _, wdef = Weather.getCurrent()
                            if wdef and wdef.lightning then active = true end
                        end
                        output = active and output or 0

                    elseif def.intermittent == 'heat' then
                        -- Steam turbine: scales with nearby tile temperature
                        local tok, Thermal = pcall(require, 'src.sim.thermal')
                        if tok then
                            local World = require('src.world.tilemap')
                            local temp = World.getTemp(gen.x, gen.y, gen.depth or 0)
                            -- 0% below 20°C, ramps to 100% at 80°C+
                            local heatFactor = math.max(0, math.min(1, (temp - 20) / 60))
                            output = output * heatFactor
                        else
                            output = 0
                        end

                    elseif def.intermittent == 'water' then
                        -- Hydrogen cell: needs water resource available
                        local waterAvail = GameState.resources.water or 0
                        output = waterAvail > 0 and output or (output * 0.3)

                    elseif def.intermittent == 'thermal_diff' then
                        -- Thermopile/Stirling: power from temperature differential
                        local tok, _ = pcall(require, 'src.sim.thermal')
                        if tok then
                            local World = require('src.world.tilemap')
                            local indoorTemp = World.getTemp(gen.x, gen.y, gen.depth or 0)
                            local delta = math.abs(indoorTemp - GameState.globalTemp)
                            -- More diff = more power, peaks at 60°C delta
                            local diffFactor = math.min(1.5, delta / 40)
                            output = output * diffFactor
                        else
                            output = 0
                        end

                    elseif def.intermittent == 'cold' then
                        -- Cryo-kinetic: generates power from cold temps
                        -- 0% at 0°C+, ramps to 100% at -30°C, peaks at 150% at -60°C
                        local temp = GameState.globalTemp or 0
                        if temp >= 0 then
                            output = 0
                        else
                            local coldFactor = math.min(1.5, -temp / 40)
                            output = output * coldFactor
                        end
                    end

                    -- Manned generators scale output with crew present
                    if def.manned then
                        local crewNeeded = def.crewSize or 1
                        local crewPresent = gen.assignedCount or 0
                        output = output * math.min(1, crewPresent / crewNeeded)
                    end

                    if gen.faulted then
                        output = output * FAULT_EFFICIENCY_MULT
                    end
                    gridStats[root].supply = gridStats[root].supply + output
                end
            end
        end
    end

    for eid, con in pairs(consumers) do
        local root = ufFind(con.tileKey)
        if root then
            ensureGrid(root)
            gridStats[root].demand = gridStats[root].demand + con.watts
            local p = con.priority or 'normal'
            if p == 'critical' then
                gridStats[root].demandCritical = gridStats[root].demandCritical + con.watts
            elseif p == 'low' then
                gridStats[root].demandLow = gridStats[root].demandLow + con.watts
            else
                gridStats[root].demandNormal = gridStats[root].demandNormal + con.watts
            end
        end
    end

    -- Distribute passive watts (precursor core etc.) across all grids
    if passiveWatts > 0 then
        local gridCount = 0
        for _ in pairs(gridStats) do gridCount = gridCount + 1 end
        if gridCount > 0 then
            local perGrid = passiveWatts / gridCount
            for _, stats in pairs(gridStats) do
                stats.supply = stats.supply + perGrid
            end
        end
    end

    -- Register batteries on each grid
    for eid, bat in pairs(batteries) do
        local root = parent[bat.tileKey] and ufFind(bat.tileKey)
        if root then
            ensureGrid(root)
            local ids = gridStats[root].batteryIds
            ids[#ids + 1] = eid
            gridStats[root].batteryStored = gridStats[root].batteryStored + bat.stored
            gridStats[root].batteryCapacity = gridStats[root].batteryCapacity + bat.capacity
        end
    end
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Power.step(dt)
    Power.tickBrownout(dt)
    rebuildCooldown = rebuildCooldown - dt
    if rebuildCooldown <= 0 then
        rebuildGrid()
        rebuildCooldown = REBUILD_INTERVAL
    end

    -- Consume fuel in generators + fault rolls + CO2 emission
    for eid, gen in pairs(generators) do
        local def = GENERATORS[gen.genType]
        if def and def.fuelRate > 0 then
            gen.fuel = gen.fuel - def.fuelRate * dt
            -- "any" fuel type: auto-refuel from organic resources when low
            if gen.fuel <= 10 and def.fuelType == 'any' then
                local fuelSources = { 'wood', 'food', 'hide', 'corpse_creature', 'corpse_human' }
                for _, resKey in ipairs(fuelSources) do
                    local avail = GameState.resources[resKey] or 0
                    if avail >= 1 then
                        GameState.resources[resKey] = avail - 1
                        gen.fuel = gen.fuel + 30
                        break
                    end
                end
            -- Named fuel type: auto-refuel from resource
            elseif gen.fuel <= 10 and def.fuelType then
                local resKey = def.fuelType
                -- Map fuel types to resource keys
                local FUEL_TO_RES = {
                    raw_wood = 'wood', coal = 'fuel', thermal_core = 'thermalCores',
                    fuel_cell = 'fuel', components = 'components',
                    food = 'food', corpse_creature = 'corpse_creature',
                    eldritch_ichor = 'eldritch_ichor',
                }
                local rk = FUEL_TO_RES[resKey] or resKey
                local avail = GameState.resources[rk] or 0
                if avail >= 1 then
                    GameState.resources[rk] = avail - 1
                    gen.fuel = gen.fuel + 50
                end
            end
            if gen.fuel <= 0 then gen.fuel = 0 end
        end

        -- Nuclear meltdown check: faulted nuclear reactor can melt down
        if def and def.meltdownRisk and gen.faulted and gen.fuel > 0 then
            if math.random() < def.meltdownRisk then
                -- Meltdown: massive damage, radiation, fire
                gen.fuel = 0
                gen.faulted = true
                gen.meltdown = true
                -- Spawn fire at generator location
                local fok, Fire = pcall(require, 'src.sim.fire')
                if fok and Fire.ignite then
                    local genDepth = gen.depth or 0
                    Fire.ignite(gen.x, gen.y, 'meltdown', genDepth)
                    -- Spread to adjacent tiles
                    for dx = -2, 2 do
                        for dy = -2, 2 do
                            if math.random() < 0.6 then
                                Fire.ignite(gen.x + dx, gen.y + dy, 'meltdown', genDepth)
                            end
                        end
                    end
                end
                -- Colony-wide consequences
                local hok, Hope = pcall(require, 'src.colony.hope')
                if hok then Hope.applyDelta(-20, 15) end
            end
        end

        -- Ensure repair job type is registered
        if not Jobs.TYPES.repair then
            Jobs.TYPES.repair = {
                name     = 'Repair',
                skill    = 'building',
                priority = 'building',
                duration = 5.0,
            }
        end

        -- Fault roll: only for running (fueled) generators that aren't already faulted
        if def and gen.fuel > 0 and not gen.faulted then
            if math.random() < FAULT_CHANCE_PER_TICK then
                gen.faulted = true
                gen.repairTaskId = Jobs.createTask('repair', gen.x, gen.y, {
                    entityId = eid,
                    genType  = gen.genType,
                })
            end
        end

        -- Re-create repair task for faulted generators missing one (e.g. after load)
        if def and gen.faulted and not gen.repairTaskId then
            gen.repairTaskId = Jobs.createTask('repair', gen.x, gen.y, {
                entityId = eid,
                genType  = gen.genType,
            })
        end

        -- CO2 emission: proportional to fuel burn rate * co2 multiplier
        -- Even fuelless generators can emit (geothermal = sulfur trace)
        if def then
            local baseCO2 = (def.co2Mult or 1.0)
            if def.fuelRate > 0 and gen.fuel > 0 then
                local co2Rate = def.fuelRate * 2.0 * baseCO2
                if gen.faulted then
                    co2Rate = co2Rate * FAULT_CO2_MULT
                end
                gen._co2Rate = co2Rate
            elseif not def.fuelType and baseCO2 > 0 then
                -- Fuelless but still emits trace (e.g. geothermal)
                gen._co2Rate = 0.005 * baseCO2
            else
                gen._co2Rate = 0
            end
        end
    end

    -- Manage manned generator tasks and assignees
    for eid, gen in pairs(generators) do
        local def = GENERATORS[gen.genType]
        if def and def.manned then
            local crewNeeded = def.crewSize or 1

            -- Initialize assignee tracking
            if not gen.assignees then gen.assignees = {} end

            -- Clean dead/gone assignees
            local alive = {}
            for _, wid in ipairs(gen.assignees) do
                if ECS.isAlive(wid) then
                    alive[#alive + 1] = wid
                end
            end
            gen.assignees = alive
            gen.assignedCount = #alive

            -- Initialize task tracking
            if not gen.taskIds then gen.taskIds = {} end

            -- Clean dead tasks
            local liveTasks = {}
            for _, tid in ipairs(gen.taskIds) do
                local task = Jobs.getTask(tid)
                if task and not task.complete then
                    liveTasks[#liveTasks + 1] = tid
                end
            end
            gen.taskIds = liveTasks

            -- Create tasks for unfilled crew slots
            local slotsOpen = crewNeeded - #gen.taskIds
            for _ = 1, slotsOpen do
                local tid = Jobs.createTask('operate_generator', gen.x, gen.y, {
                    generatorId = eid,
                    genType     = gen.genType,
                    laborType   = def.laborType,
                })
                if tid then
                    gen.taskIds[#gen.taskIds + 1] = tid
                end
            end
        end
    end

    -- Battery charge/discharge per grid
    for root, stats in pairs(gridStats) do
        local surplus = stats.supply - stats.demand
        if surplus > 0 then
            -- Charge batteries with excess (per-battery efficiency)
            local surplusPerTick = surplus * dt
            for _, eid in ipairs(stats.batteryIds) do
                local bat = batteries[eid]
                if bat and surplusPerTick > 0 then
                    local space = bat.capacity - bat.stored
                    if space > 0 then
                        local eff = bat.chargeEff or BATTERY_CHARGE_EFF
                        local charge = math.min(surplusPerTick * eff, space)
                        bat.stored = bat.stored + charge
                        surplusPerTick = surplusPerTick - (charge / eff)
                    end
                end
            end
            stats.poweredLevel = 'all'
        elseif surplus < 0 then
            -- Discharge batteries to cover deficit
            local deficit = -surplus * dt
            for _, eid in ipairs(stats.batteryIds) do
                local bat = batteries[eid]
                if bat and bat.stored > 0 then
                    local discharge = math.min(deficit, bat.stored)
                    bat.stored = bat.stored - discharge
                    deficit = deficit - discharge
                end
                if deficit <= 0 then break end
            end
            if deficit <= 0 then
                stats.poweredLevel = 'all'
            else
                -- Batteries couldn't cover all demand — shed by priority
                local avail = stats.supply
                for _, eid in ipairs(stats.batteryIds) do
                    local bat = batteries[eid]
                    if bat then avail = avail + bat.stored / 5.0 end
                end
                if avail >= stats.demandCritical + stats.demandNormal then
                    stats.poweredLevel = 'normal'
                elseif avail >= stats.demandCritical then
                    stats.poweredLevel = 'critical'
                else
                    stats.poweredLevel = 'none'
                end
            end
        else
            stats.poweredLevel = 'all'
        end
    end

    -- Battery self-discharge (per-battery rate)
    for _, bat in pairs(batteries) do
        if bat.stored > 0 then
            local rate = bat.selfDischarge or BATTERY_SELF_DISCHARGE
            bat.stored = math.max(0, bat.stored - rate * dt)
        end
    end

    -- Zzzt short circuit event — random chance proportional to stored energy
    for root, stats in pairs(gridStats) do
        if stats.batteryStored > 0 and stats.batteryCapacity > 0 then
            local chargeRatio = stats.batteryStored / stats.batteryCapacity
            if math.random() < ZZZT_BASE_CHANCE * chargeRatio then
                Power.triggerZzzt(root, stats)
            end
        end
    end

    -- Update powered status for all consumer entities
    for eid, con in pairs(consumers) do
        local root = parent[con.tileKey] and ufFind(con.tileKey)
        local powered = false
        if root and gridStats[root] then
            powered = isPriorityPowered(con.priority or 'normal', gridStats[root].poweredLevel)
        end
        -- Forced brownout overrides all grids (solar flare etc.)
        if forcedBrownout > 0 then powered = false end
        -- Update machine component
        local machine = ECS.get(eid, 'machine')
        if machine then
            machine.powered = powered
        end
        -- Update turret component
        local turret = ECS.get(eid, 'turret')
        if turret then
            turret.powered = powered
        end
        -- Update battery component
        local batComp = ECS.get(eid, 'battery')
        if batComp then
            local bat = batteries[eid]
            if bat then
                batComp.stored = bat.stored
                batComp.capacity = bat.capacity
            end
        end
        -- Update light source: add/remove light based on power state
        local bref = ECS.get(eid, 'building_ref')
        if bref and bref.type == 'light_source' then
            local bok, BuildingMod = pcall(require, 'src.building.building')
            if bok then
                local def = BuildingMod.defs[bref.defId]
                if def then
                    local lok, Lighting = pcall(require, 'src.sim.lighting')
                    if lok then
                        if powered then
                            if def.lightPreset then
                                Lighting.addLight(con.x, con.y, def.lightPreset)
                            elseif def.lightRadius then
                                Lighting.addLightCustom(con.x, con.y, def.lightRadius, def.lightIntensity or 0.8)
                            end
                        else
                            Lighting.removeLight(con.x, con.y)
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Zzzt short circuit
---------------------------------------------------------------------------

function Power.triggerZzzt(root, stats)
    -- Drain 20-50% of stored energy from all batteries on this grid
    local drainFrac = 0.2 + math.random() * 0.3
    for _, eid in ipairs(stats.batteryIds) do
        local bat = batteries[eid]
        if bat then
            local drained = bat.stored * drainFrac
            bat.stored = bat.stored - drained
            if bat.stored < 0 then bat.stored = 0 end
        end
    end
    -- Cause fire at a random conduit on this grid
    local gridConduits = {}
    for k, c in pairs(conduits) do
        if parent[k] and ufFind(k) == root then
            gridConduits[#gridConduits + 1] = c
        end
    end
    if #gridConduits > 0 then
        local target = gridConduits[math.random(#gridConduits)]
        local fok, Fire = pcall(require, 'src.sim.fire')
        if fok and Fire.ignite then
            Fire.ignite(target.x, target.y, 'zzzt', target.depth or 0)
        end
    end
    -- Notify colony
    local hok, Hope = pcall(require, 'src.colony.hope')
    if hok then Hope.applyDelta(-3, 5) end
end

-- Flood-triggered electrical short: Zzzt in a specific room
function Power.onFloodShort(roomId)
    local World = require('src.world.tilemap')
    -- Find consumers in the flooded room and short one
    for eid, con in pairs(consumers) do
        if World.getRoom(con.x, con.y) == roomId then
            -- Trigger fire at the consumer's location
            local fok, Fire = pcall(require, 'src.sim.fire')
            if fok and Fire.ignite then Fire.ignite(con.x, con.y, 'flood_short', con.depth or 0) end
            local hok, Hope = pcall(require, 'src.colony.hope')
            if hok then Hope.applyDelta(-2, 3) end
            return
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Power.getGridStats()
    return gridStats
end

function Power.isConsumerPowered(entityId)
    local con = consumers[entityId]
    if not con then return false end
    if forcedBrownout > 0 then return false end
    local root = parent[con.tileKey] and ufFind(con.tileKey)
    if not root or not gridStats[root] then return false end
    return isPriorityPowered(con.priority or 'normal', gridStats[root].poweredLevel)
end

function Power.isGridPowered(x, y)
    local k = tileKey(x, y)
    if not parent[k] then return false end
    local root = ufFind(k)
    if not gridStats[root] then return false end
    return gridStats[root].poweredLevel == 'all'
end

function Power.getGridRoot(x, y)
    local k = tileKey(x, y)
    if not parent[k] then return nil end
    return ufFind(k)
end

function Power.getTotalSupply()
    local total = passiveWatts
    for _, stats in pairs(gridStats) do
        total = total + stats.supply
    end
    return total
end

function Power.addPassiveWatts(watts)
    passiveWatts = passiveWatts + watts
end

function Power.getPassiveWatts()
    return passiveWatts
end

function Power.getTotalDemand()
    local total = 0
    for _, stats in pairs(gridStats) do
        total = total + stats.demand
    end
    return total
end

---------------------------------------------------------------------------
-- Fault system queries
---------------------------------------------------------------------------

function Power.isGeneratorFaulted(entityId)
    local gen = generators[entityId]
    return gen and gen.faulted or false
end

function Power.repairGenerator(entityId)
    local gen = generators[entityId]
    if not gen then return false end
    gen.faulted = false
    if gen.repairTaskId then
        Jobs.completeTask(gen.repairTaskId)
        gen.repairTaskId = nil
    end
    return true
end

function Power.getGeneratorCO2Rate(entityId)
    local gen = generators[entityId]
    return gen and gen._co2Rate or 0
end

function Power.getGenerators()
    return generators
end

function Power.setGeneratorOutputMult(entityId, mult)
    local gen = generators[entityId]
    if gen then gen.outputMult = mult end
end

---------------------------------------------------------------------------
-- Manned generator worker assignment
---------------------------------------------------------------------------

function Power.assignWorker(entityId, workerId)
    local gen = generators[entityId]
    if not gen then return false end
    if not gen.assignees then gen.assignees = {} end
    -- Avoid duplicates
    for _, wid in ipairs(gen.assignees) do
        if wid == workerId then return true end
    end
    gen.assignees[#gen.assignees + 1] = workerId
    gen.assignedCount = #gen.assignees
    return true
end

function Power.unassignWorker(entityId, workerId)
    local gen = generators[entityId]
    if not gen or not gen.assignees then return end
    local filtered = {}
    for _, wid in ipairs(gen.assignees) do
        if wid ~= workerId then filtered[#filtered + 1] = wid end
    end
    gen.assignees = filtered
    gen.assignedCount = #filtered
end

---------------------------------------------------------------------------
-- Brownout — force all grids into brownout for a duration (solar flare etc.)
---------------------------------------------------------------------------

function Power.triggerBrownout(duration)
    forcedBrownout = math.max(forcedBrownout, duration or 60)
end

function Power.isForcedBrownout()
    return forcedBrownout > 0
end

function Power.tickBrownout(dt)
    if forcedBrownout > 0 then
        forcedBrownout = forcedBrownout - dt
        if forcedBrownout < 0 then forcedBrownout = 0 end
    end
end

---------------------------------------------------------------------------
-- Save / Load — preserve generator runtime state across save/load
---------------------------------------------------------------------------

function Power.getState()
    local genState = {}
    for eid, gen in pairs(generators) do
        genState[eid] = {
            fuel     = gen.fuel,
            faulted  = gen.faulted,
            meltdown = gen.meltdown,
            assignees = gen.assignees or {},
            assignedCount = gen.assignedCount or 0,
            outputMult = gen.outputMult,
        }
    end
    local batState = {}
    for eid, bat in pairs(batteries) do
        batState[eid] = {
            stored        = bat.stored,
            capacity      = bat.capacity,
            chargeEff     = bat.chargeEff,
            selfDischarge = bat.selfDischarge,
        }
    end
    local swState = {}
    for k, sw in pairs(switches) do
        swState[k] = { on = sw.on, entityId = sw.entityId }
    end
    -- Save standalone conduit positions (placed by player, no ECS entity)
    local conduitList = {}
    for k, c in pairs(conduits) do
        conduitList[#conduitList + 1] = { x = c.x, y = c.y }
    end
    return {
        generators     = genState,
        batteries      = batState,
        switches       = swState,
        conduits       = conduitList,
        forcedBrownout = forcedBrownout,
        passiveWatts   = passiveWatts,
    }
end

function Power.loadState(saved)
    if not saved then return end
    if saved.forcedBrownout then
        forcedBrownout = saved.forcedBrownout
    end
    passiveWatts = saved.passiveWatts or 0
    -- Restore generator runtime state after addGenerator has re-created entries
    if saved.generators then
        for eid, state in pairs(saved.generators) do
            if generators[eid] then
                generators[eid].fuel     = state.fuel
                generators[eid].faulted  = state.faulted
                generators[eid].meltdown = state.meltdown
                generators[eid].assignees = state.assignees or {}
                generators[eid].assignedCount = state.assignedCount or 0
                generators[eid].outputMult = state.outputMult or 1.0
            end
        end
    end
    -- Restore battery charge levels and per-type properties
    if saved.batteries then
        for eid, state in pairs(saved.batteries) do
            if batteries[eid] then
                batteries[eid].stored        = state.stored or 0
                batteries[eid].capacity      = state.capacity or BATTERY_CAPACITY
                batteries[eid].chargeEff     = state.chargeEff or batteries[eid].chargeEff
                batteries[eid].selfDischarge = state.selfDischarge or batteries[eid].selfDischarge
            end
        end
    end
    -- Restore switch states
    if saved.switches then
        for k, state in pairs(saved.switches) do
            if switches[k] then
                switches[k].on = state.on
            end
        end
    end
    -- Restore standalone conduit positions
    if saved.conduits then
        for _, c in ipairs(saved.conduits) do
            Power.addConduit(c.x, c.y)
        end
    end
    -- Force immediate grid rebuild after load
    rebuildCooldown = 0
end

function Power.getMannedGenerators()
    local result = {}
    for eid, gen in pairs(generators) do
        local def = GENERATORS[gen.genType]
        if def and def.manned then
            result[eid] = gen
        end
    end
    return result
end

return Power
