-- pipes.lua — Fluid and gas transport network
-- Dual union-find networks (fluid + gas) with freeze/burst/spill mechanics.
-- Per-network pooling: fluid levels are tracked per connected network, not per pipe.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Defs      = require('src.logistics.pipe_defs')

local Pipes = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local REBUILD_INTERVAL = 2      -- seconds between topology rebuilds
local FREEZE_CHECK_INTERVAL = 1 -- seconds between freeze progression checks
local DETERIORATION_RATE = 0.002 -- HP/s natural decay
local TANK_EQUALIZE_RATE = 5    -- units/s tanks push/pull to network
local SPILL_SPREAD_RADIUS = 2   -- tiles a spill can spread

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function tileKey(x, y, depth) return (depth or 0) * 100000000 + y * 10000 + x end
local function keyToXY(k)
    local d = math.floor(k / 100000000)
    local rem = k - d * 100000000
    return rem % 10000, math.floor(rem / 10000), d
end

---------------------------------------------------------------------------
-- Union-find
---------------------------------------------------------------------------

local function ufMake(parentTbl, rankTbl, k)
    parentTbl[k] = k
    rankTbl[k] = 0
end

local function ufFind(parentTbl, k)
    if parentTbl[k] ~= k then
        parentTbl[k] = ufFind(parentTbl, parentTbl[k])
    end
    return parentTbl[k]
end

local function ufUnion(parentTbl, rankTbl, a, b)
    local ra, rb = ufFind(parentTbl, a), ufFind(parentTbl, b)
    if ra == rb then return end
    if rankTbl[ra] < rankTbl[rb] then ra, rb = rb, ra end
    parentTbl[rb] = ra
    if rankTbl[ra] == rankTbl[rb] then rankTbl[ra] = rankTbl[ra] + 1 end
end

---------------------------------------------------------------------------
-- State — dual networks (fluid / gas)
---------------------------------------------------------------------------

-- Per-medium state tables
local fluid = {
    nodes   = {},  -- nodes[tileKey] = { x, y, depth, pipeType, hp, frozenTime, leaking, entityId }
    parent  = {},
    rank    = {},
    sources = {},  -- sources[entityId] = { fluidType, rate, tileKey, x, y, depth }
    sinks   = {},  -- sinks[entityId] = { fluidType, rate, tileKey, x, y, depth }
    net     = {},  -- net[rootKey] = { [fluidType] = level }
    stats   = {},  -- stats[rootKey] = { pipeCount, totalThroughput, production, consumption }
}

local gas = {
    nodes   = {},
    parent  = {},
    rank    = {},
    sources = {},
    sinks   = {},
    net     = {},
    stats   = {},
}

local function getMedium(med)
    return med == 'gas' and gas or fluid
end

-- Spills: active tile-based effects from bursts/leaks
-- spills[tileKey] = { fluidType, medium, amount, timer, x, y, depth }
local spills = {}

-- Timers
local rebuildFluidCD = 0
local rebuildGasCD   = 0
local freezeCheckCD  = FREEZE_CHECK_INTERVAL

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Pipes.init()
    fluid.nodes, fluid.parent, fluid.rank = {}, {}, {}
    fluid.sources, fluid.sinks = {}, {}
    fluid.net, fluid.stats = {}, {}

    gas.nodes, gas.parent, gas.rank = {}, {}, {}
    gas.sources, gas.sinks = {}, {}
    gas.net, gas.stats = {}, {}

    spills = {}
    rebuildFluidCD = 0
    rebuildGasCD   = 0
    freezeCheckCD  = FREEZE_CHECK_INTERVAL
end

---------------------------------------------------------------------------
-- Pipe node management
---------------------------------------------------------------------------

function Pipes.addPipeNode(x, y, pipeType, medium, depth)
    local tok, Tilemap = pcall(require, 'src.world.tilemap')
    if tok and not Tilemap.inBounds(x, y) then return false end

    local def = Defs.PIPE_DEFS[pipeType]
    if not def then return false end

    local d = depth or 0
    local med = getMedium(medium or def.medium)
    local k = tileKey(x, y, d)
    if med.nodes[k] then return false end

    -- Spawn ECS entity for save/load persistence
    local eid = ECS.spawn()
    ECS.set(eid, 'pos', { x = x, y = y, depth = d })
    ECS.set(eid, 'pipe_node', {
        pipeType   = pipeType,
        medium     = medium or def.medium,
        hp         = def.durability,
        frozenTime = 0,
        leaking    = false,
        x = x, y = y, depth = d,
    })

    med.nodes[k] = {
        x = x, y = y, depth = d,
        pipeType   = pipeType,
        hp         = def.durability,
        frozenTime = 0,
        leaking    = false,
        entityId   = eid,
    }

    -- Force rebuild
    if med == fluid then rebuildFluidCD = 0 else rebuildGasCD = 0 end
    return true, eid
end

function Pipes.removePipeNode(x, y, medium, depth)
    local med = getMedium(medium or 'fluid')
    local k = tileKey(x, y, depth)
    local node = med.nodes[k]
    if not node then return false end

    -- Destroy ECS entity
    if node.entityId and ECS.isAlive(node.entityId) then
        ECS.destroy(node.entityId)
    end

    med.nodes[k] = nil

    -- Force rebuild
    if med == fluid then rebuildFluidCD = 0 else rebuildGasCD = 0 end
    return true
end

function Pipes.isPipe(x, y, medium, depth)
    local med = getMedium(medium or 'fluid')
    return med.nodes[tileKey(x, y, depth)] ~= nil
end

---------------------------------------------------------------------------
-- Source / Sink registration
---------------------------------------------------------------------------

function Pipes.addSource(entityId, fluidType, rate, x, y, medium, depth)
    local d = depth or 0
    local med = getMedium(medium or 'fluid')
    local k = tileKey(x, y, d)
    med.sources[entityId] = {
        fluidType = fluidType, rate = rate,
        tileKey = k, x = x, y = y, depth = d,
    }
    -- Source tile also acts as pipe node if not already
    if not med.nodes[k] then
        local defKey = (med == gas) and 'small_duct' or 'small_pipe'
        local def = Defs.PIPE_DEFS[defKey]
        med.nodes[k] = {
            x = x, y = y, depth = d,
            pipeType = defKey,
            hp = def.durability,
            frozenTime = 0, leaking = false,
            entityId = nil, -- no ECS entity for implicit nodes
        }
    end
    if med == fluid then rebuildFluidCD = 0 else rebuildGasCD = 0 end
end

-- Shared cleanup: remove an endpoint (source or sink) and its implicit pipe node
local function removeEndpoint(entityId, collectionKey, otherKey)
    for _, med in ipairs({ fluid, gas }) do
        local entry = med[collectionKey][entityId]
        if entry then
            local k = entry.tileKey
            local node = med.nodes[k]
            if node and node.entityId == nil then
                local otherRef = false
                for eid, s in pairs(med[collectionKey]) do
                    if eid ~= entityId and s.tileKey == k then otherRef = true; break end
                end
                if not otherRef then
                    for _, s in pairs(med[otherKey]) do
                        if s.tileKey == k then otherRef = true; break end
                    end
                end
                if not otherRef then
                    med.nodes[k] = nil
                end
            end
            med[collectionKey][entityId] = nil
        end
    end
end

function Pipes.removeSource(entityId)
    removeEndpoint(entityId, 'sources', 'sinks')
end

function Pipes.addSink(entityId, fluidType, rate, x, y, medium, depth)
    local d = depth or 0
    local med = getMedium(medium or 'fluid')
    local k = tileKey(x, y, d)
    med.sinks[entityId] = {
        fluidType = fluidType, rate = rate,
        tileKey = k, x = x, y = y, depth = d,
    }
    if not med.nodes[k] then
        local defKey = (med == gas) and 'small_duct' or 'small_pipe'
        local def = Defs.PIPE_DEFS[defKey]
        med.nodes[k] = {
            x = x, y = y, depth = d,
            pipeType = defKey,
            hp = def.durability,
            frozenTime = 0, leaking = false,
            entityId = nil,
        }
    end
    if med == fluid then rebuildFluidCD = 0 else rebuildGasCD = 0 end
end

function Pipes.removeSink(entityId)
    removeEndpoint(entityId, 'sinks', 'sources')
end

---------------------------------------------------------------------------
-- Network rebuild with fluid conservation
---------------------------------------------------------------------------

local DIRS = { {1,0}, {-1,0}, {0,1}, {0,-1} }

local function rebuildNetwork(med)
    -- Phase 1: snapshot old root membership
    local tileToOldRoot = {}
    local oldRootPipeCount = {}
    for k in pairs(med.nodes) do
        if med.parent[k] then
            local oldRoot = ufFind(med.parent, k)
            tileToOldRoot[k] = oldRoot
            oldRootPipeCount[oldRoot] = (oldRootPipeCount[oldRoot] or 0) + 1
        end
    end
    local oldNet = med.net

    -- Phase 2: fresh union-find
    med.parent = {}
    med.rank   = {}
    for k in pairs(med.nodes) do
        ufMake(med.parent, med.rank, k)
    end

    for k, node in pairs(med.nodes) do
        for _, dir in ipairs(DIRS) do
            local nk = tileKey(node.x + dir[1], node.y + dir[2], node.depth)
            if med.nodes[nk] then
                ufUnion(med.parent, med.rank, k, nk)
            end
        end
    end

    -- Compute stats per new network
    med.stats = {}
    for k, node in pairs(med.nodes) do
        local root = ufFind(med.parent, k)
        if not med.stats[root] then
            med.stats[root] = { pipeCount = 0, totalThroughput = 0, production = {}, consumption = {} }
        end
        local s = med.stats[root]
        s.pipeCount = s.pipeCount + 1
        local def = Defs.PIPE_DEFS[node.pipeType]
        if def then
            s.totalThroughput = s.totalThroughput + def.throughput
        end
    end

    -- Phase 3: conserve fluid across topology changes
    med.net = {}
    -- Track how much fluid each old root contributes to each new root
    local oldToNew = {} -- oldToNew[oldRoot] = { [newRoot] = tileCount }
    for k in pairs(med.nodes) do
        local oldRoot = tileToOldRoot[k]
        local newRoot = ufFind(med.parent, k)
        if oldRoot and oldNet[oldRoot] then
            if not oldToNew[oldRoot] then oldToNew[oldRoot] = {} end
            oldToNew[oldRoot][newRoot] = (oldToNew[oldRoot][newRoot] or 0) + 1
        end
        if not med.net[newRoot] then med.net[newRoot] = {} end
    end

    -- Distribute old fluid proportionally to new networks
    for oldRoot, newRoots in pairs(oldToNew) do
        local oldFluids = oldNet[oldRoot]
        if oldFluids then
            local totalOldPipes = oldRootPipeCount[oldRoot] or 1
            for newRoot, count in pairs(newRoots) do
                local share = count / totalOldPipes
                if not med.net[newRoot] then med.net[newRoot] = {} end
                for fType, amount in pairs(oldFluids) do
                    med.net[newRoot][fType] = (med.net[newRoot][fType] or 0) + amount * share
                end
            end
        end
    end

    -- Tally source/sink rates
    for _, src in pairs(med.sources) do
        local root = med.parent[src.tileKey] and ufFind(med.parent, src.tileKey)
        if root and med.stats[root] then
            local p = med.stats[root].production
            p[src.fluidType] = (p[src.fluidType] or 0) + src.rate
        end
    end
    for _, snk in pairs(med.sinks) do
        local root = med.parent[snk.tileKey] and ufFind(med.parent, snk.tileKey)
        if root and med.stats[root] then
            local c = med.stats[root].consumption
            c[snk.fluidType] = (c[snk.fluidType] or 0) + snk.rate
        end
    end
end

---------------------------------------------------------------------------
-- Freeze / damage / burst system
---------------------------------------------------------------------------

local function getFreezeStage(frozenTime)
    local stage = Defs.FREEZE_STAGES[1]
    for i = #Defs.FREEZE_STAGES, 1, -1 do
        if frozenTime >= Defs.FREEZE_STAGES[i].threshold then
            stage = Defs.FREEZE_STAGES[i]
            break
        end
    end
    return stage
end

local function createSpill(x, y, fluidType, medium, amount, depth)
    local d = depth or 0
    local k = tileKey(x, y, d)
    local effect = Defs.SPILL_EFFECTS[fluidType]
    if not effect then return end

    spills[k] = {
        fluidType = fluidType,
        medium    = medium,
        amount    = amount,
        timer     = effect.duration,
        x = x, y = y, depth = d,
    }

    -- Immediate environmental effects
    local tok, Tilemap = pcall(require, 'src.world.tilemap')

    -- Temperature drop
    if tok and effect.tempDelta ~= 0 then
        local tempData = Tilemap.rawTempData(d)
        local w = Tilemap.width()
        if Tilemap.inBounds(x, y) then
            local idx = y * w + x + 1
            tempData[idx] = tempData[idx] + effect.tempDelta
        end
    end

    -- Pollution
    if effect.pollutionRate > 0 then
        local pok, Pollution = pcall(require, 'src.sim.pollution')
        if pok and Pollution.set then
            local cur = Pollution.get and Pollution.get(x, y) or 0
            Pollution.set(x, y, math.min(100, cur + effect.pollutionRate * 20))
        end
    end

    -- Fuel spill: fire risk
    if fluidType == 'fuel' or fluidType == 'oil' then
        local fok, Fire = pcall(require, 'src.sim.fire')
        if fok and Fire.isOnFire and Fire.isOnFire(x, y) then
            -- Already on fire, spill feeds it
        elseif fok and fluidType == 'fuel' and math.random() < 0.15 then
            if Fire.ignite then Fire.ignite(x, y, 'pipe_burst', d) end
        end
    end
end

local function burstPipe(med, k, node)
    -- Determine what fluid was in the network
    local root = med.parent[k] and ufFind(med.parent, k)
    local spillFluid = nil
    local spillAmount = 0

    if root and med.net[root] then
        for fType, amount in pairs(med.net[root]) do
            if amount > 0 then
                spillFluid = fType
                -- Spill a portion of network fluid
                spillAmount = math.min(amount, 20)
                med.net[root][fType] = amount - spillAmount
                break
            end
        end
    end

    -- Create spill at burst location
    local nd = node.depth or 0
    local medName = med == gas and 'gas' or 'fluid'
    if spillFluid then
        createSpill(node.x, node.y, spillFluid, medName, spillAmount, nd)
        -- Spread to adjacent tiles
        for _, dir in ipairs(DIRS) do
            if math.random() < 0.4 then
                local sx, sy = node.x + dir[1], node.y + dir[2]
                local tok, Tilemap = pcall(require, 'src.world.tilemap')
                if tok and Tilemap.inBounds(sx, sy) then
                    createSpill(sx, sy, spillFluid, medName, spillAmount * 0.3, nd)
                end
            end
        end
        -- Notify flooding system: water pipes flood rooms, fuel pipes leak fuel
        if spillFluid == 'water' or spillFluid == 'coolant' then
            local tfOk, TileFluids = pcall(require, 'src.sim.tile_fluids')
            if tfOk and TileFluids.onPipeBurst then
                TileFluids.onPipeBurst(node.x, node.y, nd)
            else
                local flOk, Flooding = pcall(require, 'src.sim.flooding')
                if flOk then Flooding.onPipeBurst(node.x, node.y, nd) end
            end
        elseif spillFluid == 'fuel' or spillFluid == 'oil' then
            local flOk, Flooding = pcall(require, 'src.sim.flooding')
            if flOk then
                Flooding.onFuelLeak(node.x, node.y, spillAmount * 0.1, nd)
            end
        end
    end

    -- Create repair task
    local jok, Jobs = pcall(require, 'src.colonist.jobs')
    if jok and Jobs.createTask then
        Jobs.createTask('build', node.x, node.y, {
            label = 'Repair burst pipe',
            pipeRepair = true,
            tileKey = k,
            medium = medName,
            depth = nd,
        })
    end

    -- Destroy the pipe node
    Pipes.removePipeNode(node.x, node.y, medName, nd)
end

local function tickFreeze(med, dt)
    local tok, Tilemap = pcall(require, 'src.world.tilemap')
    if not tok then return end

    -- Collect burst candidates first — cannot modify med.nodes during iteration
    local toBurst = {}

    for k, node in pairs(med.nodes) do
        local temp = Tilemap.getTemp(node.x, node.y, node.depth or 0)
        local def = Defs.PIPE_DEFS[node.pipeType]
        if not def then goto continue end

        -- Determine effective freeze threshold for fluids at this node
        local isFreezing = false
        if med == fluid then
            local root = med.parent[k] and ufFind(med.parent, k)
            if root and med.net[root] then
                for fType, amount in pairs(med.net[root]) do
                    if amount > 0 then
                        local fDef = Defs.FLUIDS[fType]
                        if fDef and temp < (fDef.freezeTemp + def.freezeResist) then
                            isFreezing = true
                            break
                        end
                    end
                end
            end
            -- Empty pipes don't freeze
            if not isFreezing and not next(med.net[med.parent[k] and ufFind(med.parent, k)] or {}) then
                isFreezing = false
            end
        end
        -- Gas ducts don't freeze (gases don't have freezeTemp)

        if isFreezing then
            node.frozenTime = node.frozenTime + dt
        else
            -- Thaw: reduce frozen time (hysteresis)
            node.frozenTime = math.max(0, node.frozenTime - dt * 2)
        end

        local stage = getFreezeStage(node.frozenTime)

        -- Apply freeze damage
        if stage.damagePerTick > 0 then
            node.hp = node.hp - stage.damagePerTick * dt
        end

        -- Burst check — defer to avoid modifying table during iteration
        if stage.burstChance > 0 and math.random() < stage.burstChance * dt then
            toBurst[#toBurst + 1] = { k = k, node = node }
            goto continue
        end

        -- HP death
        if node.hp <= 0 then
            toBurst[#toBurst + 1] = { k = k, node = node }
            goto continue
        end

        -- Sync ECS component
        if node.entityId and ECS.isAlive(node.entityId) then
            local comp = ECS.get(node.entityId, 'pipe_node')
            if comp then
                comp.hp = node.hp
                comp.frozenTime = node.frozenTime
                comp.leaking = node.leaking
            end
        end

        ::continue::
    end

    -- Process bursts after iteration is complete
    for _, entry in ipairs(toBurst) do
        if med.nodes[entry.k] then
            burstPipe(med, entry.k, entry.node)
        end
    end
end

local function tickLeaks(med, dt)
    for k, node in pairs(med.nodes) do
        if node.leaking then
            local root = med.parent[k] and ufFind(med.parent, k)
            if root and med.net[root] then
                for fType, amount in pairs(med.net[root]) do
                    if amount > 0 then
                        local leakAmt
                        if med == gas then
                            local gDef = Defs.GASES[fType]
                            leakAmt = (gDef and gDef.leakRate or 0.3) * dt
                        else
                            leakAmt = 0.5 * dt
                        end
                        leakAmt = math.min(amount, leakAmt)
                        med.net[root][fType] = amount - leakAmt
                        -- Small spill at leak location
                        if math.random() < 0.05 then
                            createSpill(node.x, node.y, fType, med == gas and 'gas' or 'fluid', leakAmt, node.depth or 0)
                        end
                    end
                end
            end
        end
    end
end

local function tickDeterioration(med, dt)
    for _, node in pairs(med.nodes) do
        local def = Defs.PIPE_DEFS[node.pipeType]
        if def then
            node.hp = node.hp - DETERIORATION_RATE * dt
        end
    end
end

---------------------------------------------------------------------------
-- Spill tick
---------------------------------------------------------------------------

local function tickSpills(dt)
    local expired = {}
    for k, spill in pairs(spills) do
        spill.timer = spill.timer - dt
        if spill.timer <= 0 then
            expired[#expired + 1] = k
        else
            -- Ongoing effects: pollution, toxic radius, gas suffocation
            local effect = Defs.SPILL_EFFECTS[spill.fluidType]
            if effect then
                if effect.toxicRadius > 0 then
                    -- Apply status effect to nearby colonists
                    local sok, StatusFx = pcall(require, 'src.sim.status_effects')
                    if sok and StatusFx.applyArea then
                        StatusFx.applyArea(spill.x, spill.y, effect.toxicRadius, 'toxic_exposure', dt)
                    end
                end
                -- Gas spills inject CO2 into room atmosphere (suffocation hazard)
                if spill.medium == 'gas' then
                    local aok, Atmo = pcall(require, 'src.sim.atmosphere')
                    if aok and Atmo.injectCO2 then
                        local co2Rate = 0.5  -- units/s displacing O2
                        Atmo.injectCO2(spill.x, spill.y, co2Rate * dt, spill.depth)
                    end
                end
            end
        end
    end
    for _, k in ipairs(expired) do
        spills[k] = nil
    end
end

---------------------------------------------------------------------------
-- Production / consumption / tank equalization
---------------------------------------------------------------------------

local function tickProduction(med, dt)
    for _, src in pairs(med.sources) do
        local root = med.parent[src.tileKey] and ufFind(med.parent, src.tileKey)
        if root and med.net[root] and med.stats[root] then
            -- Check if source node is frozen
            local srcNode = med.nodes[src.tileKey]
            if srcNode then
                local stage = getFreezeStage(srcNode.frozenTime)
                if stage.throughputMult <= 0 then goto next_src end
            end

            local cap = med.stats[root].totalThroughput
            local current = med.net[root][src.fluidType] or 0
            local produced = src.rate * dt
            med.net[root][src.fluidType] = math.min(cap, current + produced)
        end
        ::next_src::
    end
end

local function tickConsumption(med, dt)
    for _, snk in pairs(med.sinks) do
        local root = med.parent[snk.tileKey] and ufFind(med.parent, snk.tileKey)
        if root and med.net[root] then
            local current = med.net[root][snk.fluidType] or 0
            local wanted = snk.rate * dt
            local consumed = math.min(current, wanted)
            med.net[root][snk.fluidType] = current - consumed
        end
    end
end

local function tickTanks(dt)
    for id, comps in ECS.query('tank', 'pos') do
        local tank = comps.tank
        local pos  = comps.pos
        local med  = getMedium(tank.medium or 'fluid')
        local k    = tileKey(pos.x, pos.y, pos.depth or 0)
        local root = med.parent[k] and ufFind(med.parent, k)
        if not root or not med.net[root] then goto next_tank end

        -- Equalize: push from tank to network if network is low, pull if high
        for fType, stored in pairs(tank.contents) do
            local netLevel = med.net[root][fType] or 0
            local cap = med.stats[root] and med.stats[root].totalThroughput or 100
            local threshold = cap * 0.5

            if netLevel < threshold and stored > 0 then
                -- Push from tank into network
                local push = math.min(stored, TANK_EQUALIZE_RATE * dt)
                tank.contents[fType] = stored - push
                med.net[root][fType] = netLevel + push
            elseif netLevel > threshold then
                -- Pull from network into tank
                local space = tank.capacity - Pipes.getTankFill(tank)
                if space > 0 then
                    local pull = math.min(netLevel - threshold, TANK_EQUALIZE_RATE * dt, space)
                    tank.contents[fType] = stored + pull
                    med.net[root][fType] = netLevel - pull
                end
            end
        end

        -- Also absorb any fluid type in the network that tank doesn't have yet
        for fType, netLevel in pairs(med.net[root]) do
            if netLevel > 0 and not tank.contents[fType] then
                local space = tank.capacity - Pipes.getTankFill(tank)
                if space > 0 then
                    local pull = math.min(netLevel * 0.5, TANK_EQUALIZE_RATE * dt, space)
                    tank.contents[fType] = pull
                    med.net[root][fType] = netLevel - pull
                end
            end
        end

        ::next_tank::
    end
end

function Pipes.getTankFill(tank)
    local total = 0
    for _, v in pairs(tank.contents or {}) do total = total + v end
    return total
end

---------------------------------------------------------------------------
-- Damage API (for raids, explosions, etc.)
---------------------------------------------------------------------------

function Pipes.damagePipe(x, y, medium, amount, damageType, depth)
    local med = getMedium(medium or 'fluid')
    local k = tileKey(x, y, depth)
    local node = med.nodes[k]
    if not node then return end

    local def = Defs.PIPE_DEFS[node.pipeType]
    node.hp = node.hp - amount

    -- Leak chance
    if def and math.random() < def.leakChanceOnDamage then
        node.leaking = true
    end

    -- Burst if HP depleted
    if node.hp <= 0 then
        burstPipe(med, k, node)
    end
end

function Pipes.repairPipe(x, y, medium, depth)
    local med = getMedium(medium or 'fluid')
    local k = tileKey(x, y, depth)
    local node = med.nodes[k]
    if not node then return false end

    local def = Defs.PIPE_DEFS[node.pipeType]
    if def then
        node.hp = def.durability
        node.leaking = false
        node.frozenTime = 0
    end
    return true
end

---------------------------------------------------------------------------
-- Step
---------------------------------------------------------------------------

function Pipes.step(dt)
    -- Rebuild networks if needed
    rebuildFluidCD = rebuildFluidCD - dt
    if rebuildFluidCD <= 0 then
        rebuildNetwork(fluid)
        rebuildFluidCD = REBUILD_INTERVAL
    end

    rebuildGasCD = rebuildGasCD - dt
    if rebuildGasCD <= 0 then
        rebuildNetwork(gas)
        rebuildGasCD = REBUILD_INTERVAL
    end

    -- Freeze/damage (less frequent)
    freezeCheckCD = freezeCheckCD - dt
    if freezeCheckCD <= 0 then
        tickFreeze(fluid, FREEZE_CHECK_INTERVAL)
        tickDeterioration(fluid, FREEZE_CHECK_INTERVAL)
        tickDeterioration(gas, FREEZE_CHECK_INTERVAL)
        freezeCheckCD = FREEZE_CHECK_INTERVAL
    end

    -- Leaks (every tick)
    tickLeaks(fluid, dt)
    tickLeaks(gas, dt)

    -- Production → consumption → tank equalization
    tickProduction(fluid, dt)
    tickProduction(gas, dt)
    tickConsumption(fluid, dt)
    tickConsumption(gas, dt)
    tickTanks(dt)

    -- Spill effects
    tickSpills(dt)
end

---------------------------------------------------------------------------
-- Query API
---------------------------------------------------------------------------

function Pipes.getNetworkFluid(x, y, fluidType, medium, depth)
    local med = getMedium(medium or 'fluid')
    local k = tileKey(x, y, depth)
    if not med.parent[k] then return 0 end
    local root = ufFind(med.parent, k)
    if not med.net[root] then return 0 end
    return med.net[root][fluidType] or 0
end

function Pipes.hasFluid(x, y, fluidType, amount, medium, depth)
    return Pipes.getNetworkFluid(x, y, fluidType, medium, depth) >= (amount or 0.01)
end

function Pipes.consumeFluid(x, y, fluidType, amount, medium, depth)
    local med = getMedium(medium or 'fluid')
    local k = tileKey(x, y, depth)
    if not med.parent[k] then return false end
    local root = ufFind(med.parent, k)
    if not med.net[root] then return false end
    local current = med.net[root][fluidType] or 0
    if current < amount then return false end
    med.net[root][fluidType] = current - amount
    return true
end

function Pipes.injectFluid(x, y, fluidType, amount, medium, depth)
    local med = getMedium(medium or 'fluid')
    local k = tileKey(x, y, depth)
    if not med.parent[k] then return 0 end
    local root = ufFind(med.parent, k)
    if not med.net[root] then return 0 end
    local cap = med.stats[root] and med.stats[root].totalThroughput or 100
    local current = med.net[root][fluidType] or 0
    local space = math.max(0, cap - current)
    local injected = math.min(amount, space)
    med.net[root][fluidType] = current + injected
    return injected
end

function Pipes.getTotalFluid(fluidType, medium)
    local med = getMedium(medium or 'fluid')
    local total = 0
    for _, fluids in pairs(med.net) do
        total = total + (fluids[fluidType] or 0)
    end
    return total
end

function Pipes.getNetworkStats(medium)
    return getMedium(medium or 'fluid').stats
end

function Pipes.getNetworkFluids(medium)
    return getMedium(medium or 'fluid').net
end

function Pipes.getSpills()
    return spills
end

function Pipes.isNodeFrozen(x, y, medium, depth)
    local med = getMedium(medium or 'fluid')
    local node = med.nodes[tileKey(x, y, depth)]
    return node and node.frozenTime > 10
end

function Pipes.isNodeLeaking(x, y, medium, depth)
    local med = getMedium(medium or 'fluid')
    local node = med.nodes[tileKey(x, y, depth)]
    return node and node.leaking
end

function Pipes.getNodeHP(x, y, medium, depth)
    local med = getMedium(medium or 'fluid')
    local node = med.nodes[tileKey(x, y, depth)]
    if not node then return 0 end
    return node.hp
end

function Pipes.getFrozenCount(medium)
    local med = getMedium(medium or 'fluid')
    local n = 0
    for _, node in pairs(med.nodes) do
        if node.frozenTime > 10 then n = n + 1 end
    end
    return n
end

function Pipes.count(medium)
    local med = getMedium(medium or 'fluid')
    local n = 0
    for _ in pairs(med.nodes) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Serialization (save/load)
---------------------------------------------------------------------------

function Pipes.getState()
    -- Serialize network fluid levels by tile position (stable across loads)
    local function serializeNet(med)
        local out = {}
        for root, fluids in pairs(med.net) do
            local rx, ry, rd = keyToXY(root)
            out[#out + 1] = { x = rx, y = ry, depth = rd, fluids = fluids }
        end
        return out
    end

    local function serializeSources(srcs)
        local out = {}
        for eid, src in pairs(srcs) do
            out[#out + 1] = {
                entityId = eid, fluidType = src.fluidType,
                rate = src.rate, x = src.x, y = src.y,
                depth = src.depth or 0,
            }
        end
        return out
    end

    return {
        fluidNet     = serializeNet(fluid),
        gasNet       = serializeNet(gas),
        fluidSources = serializeSources(fluid.sources),
        fluidSinks   = serializeSources(fluid.sinks),
        gasSources   = serializeSources(gas.sources),
        gasSinks     = serializeSources(gas.sinks),
        spills       = spills,
    }
end

function Pipes.loadState(saved)
    if not saved then return end

    -- Reconstruct pipe nodes from ECS entities
    for id, comps in ECS.query('pipe_node', 'pos') do
        local pn = comps.pipe_node
        local pos = comps.pos
        local pd = pos.depth or 0
        local med = getMedium(pn.medium or 'fluid')
        local k = tileKey(pos.x, pos.y, pd)
        med.nodes[k] = {
            x = pos.x, y = pos.y, depth = pd,
            pipeType   = pn.pipeType,
            hp         = pn.hp,
            frozenTime = pn.frozenTime or 0,
            leaking    = pn.leaking or false,
            entityId   = id,
        }
    end

    -- Reconstruct tank nodes from ECS entities
    for id, comps in ECS.query('tank', 'pos') do
        local tank = comps.tank
        local pos = comps.pos
        local td = pos.depth or 0
        local med = getMedium(tank.medium or 'fluid')
        local k = tileKey(pos.x, pos.y, td)
        if not med.nodes[k] then
            local defKey = (med == gas) and 'small_duct' or 'small_pipe'
            local def = Defs.PIPE_DEFS[defKey]
            med.nodes[k] = {
                x = pos.x, y = pos.y, depth = td,
                pipeType = defKey,
                hp = def.durability,
                frozenTime = 0, leaking = false,
                entityId = nil,
            }
        end
    end

    -- Restore sources/sinks
    local function restoreSrcSink(tbl, med, data)
        if not data then return end
        for _, entry in ipairs(data) do
            local ed = entry.depth or 0
            tbl[entry.entityId] = {
                fluidType = entry.fluidType, rate = entry.rate,
                tileKey = tileKey(entry.x, entry.y, ed),
                x = entry.x, y = entry.y, depth = ed,
            }
        end
    end
    restoreSrcSink(fluid.sources, fluid, saved.fluidSources)
    restoreSrcSink(fluid.sinks, fluid, saved.fluidSinks)
    restoreSrcSink(gas.sources, gas, saved.gasSources)
    restoreSrcSink(gas.sinks, gas, saved.gasSinks)

    -- Force rebuild to establish connectivity
    rebuildNetwork(fluid)
    rebuildNetwork(gas)

    -- Overlay saved fluid levels onto rebuilt networks
    local function restoreNet(med, data)
        if not data then return end
        for _, entry in ipairs(data) do
            local k = tileKey(entry.x, entry.y, entry.depth or 0)
            if med.parent[k] then
                local root = ufFind(med.parent, k)
                if med.net[root] then
                    for fType, amount in pairs(entry.fluids) do
                        med.net[root][fType] = (med.net[root][fType] or 0) + amount
                    end
                end
            end
        end
    end
    restoreNet(fluid, saved.fluidNet)
    restoreNet(gas, saved.gasNet)

    -- Restore spills
    spills = saved.spills or {}
end

-- No-op for save.lua re-registration pattern
function Pipes.registerSystems() end

return Pipes
