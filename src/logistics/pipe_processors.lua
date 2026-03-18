-- pipe_processors.lua — ECS-driven fluid/gas processor system
-- Processors convert between fluid/gas types via the pipe network.
-- Each processor is an ECS entity with 'processor' + 'pos' components.
-- Powered processors also get 'machine' component for Power integration.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Defs      = require('src.logistics.pipe_defs')

local Processors = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function ensurePipeNode(x, y, medium, depth)
    if not medium then return end
    local pok, Pipes = pcall(require, 'src.logistics.pipes')
    if not pok then return end
    if Pipes.isPipe(x, y, medium, depth) then return end
    local nodeType = medium == 'gas' and 'small_duct' or 'small_pipe'
    Pipes.addPipeNode(x, y, nodeType, medium, depth)
end

---------------------------------------------------------------------------
-- Place a processor (called from building.lua)
---------------------------------------------------------------------------

function Processors.place(x, y, processorType, depth)
    local def = Defs.PROCESSOR_DEFS[processorType]
    if not def then return nil end

    local d = depth or 0
    local eid = ECS.spawn()
    ECS.set(eid, 'pos', { x = x, y = y, depth = d })
    ECS.set(eid, 'processor', {
        type   = processorType,
        active = false,
    })

    -- Pipe nodes for network connectivity (input and output may use different mediums)
    ensurePipeNode(x, y, def.inputMedium, d)
    ensurePipeNode(x, y, def.outputMedium, d)

    -- Power consumer — uses 'machine' component for Power system integration
    if def.powerDraw > 0 then
        ECS.set(eid, 'machine', {
            type = processorType, name = def.name,
            recipe = nil, inputBuf = {}, outputBuf = {},
            progress = 0, active = false, powered = true,
            assignee = nil,
        })
        local pwOk, Power = pcall(require, 'src.sim.power')
        if pwOk then Power.addConsumer(eid, def.powerDraw, x, y) end
    end

    return eid
end

---------------------------------------------------------------------------
-- Remove a processor at position
---------------------------------------------------------------------------

function Processors.remove(x, y, depth)
    local d = depth or 0
    for id, comps in ECS.query('processor', 'pos') do
        if comps.pos.x == x and comps.pos.y == y and (comps.pos.depth or 0) == d then
            local pwOk, Power = pcall(require, 'src.sim.power')
            if pwOk then
                Power.removeConsumer(id)
                Power.removeGenerator(id)
            end
            ECS.destroy(id)
            break
        end
    end
end

---------------------------------------------------------------------------
-- Processor ECS system
---------------------------------------------------------------------------

local function deactivateProcessor(proc, id, def)
    proc.active = false
    -- Remove generator registration when processor stops producing
    if def.powerOutput and def.powerOutput > 0 and proc._generatorRegistered then
        local pwOk, Power = pcall(require, 'src.sim.power')
        if pwOk then Power.removeGenerator(id) end
        proc._generatorRegistered = false
    end
end

local function processorSystem(dt, id, comps)
    local proc = comps.processor
    local pos  = comps.pos

    local def = Defs.PROCESSOR_DEFS[proc.type]
    if not def then return end

    -- Power check
    if def.powerDraw > 0 then
        local machine = ECS.get(id, 'machine')
        if not machine or not machine.powered then
            deactivateProcessor(proc, id, def)
            return
        end
    end

    local pok, Pipes = pcall(require, 'src.logistics.pipes')
    if not pok then return end

    -- Steam boiler: requires tile temperature >= 50°C (external heat source)
    if def.heatConsume > 0 then
        local tok, Tilemap = pcall(require, 'src.world.tilemap')
        if tok then
            local pd = pos.depth or 0
            local tileTemp = Tilemap.getTemp(pos.x, pos.y, pd)
            if tileTemp < 50 then
                deactivateProcessor(proc, id, def)
                return
            end
            -- Consume heat from room avgTemp (tile temps get overwritten by room each step)
            local thOk, ThermalMod = pcall(require, 'src.sim.thermal')
            if thOk then
                local rid = Tilemap.getRoom(pos.x, pos.y, pd)
                if rid and rid > 0 then
                    local allRooms = ThermalMod.getRooms()
                    if allRooms[rid] then
                        allRooms[rid].avgTemp = allRooms[rid].avgTemp - def.heatConsume * dt * 0.1
                    end
                end
            end
        end
    end

    -- Ichor extractor: consumes eldritch_ichor items from a nearby sessile node's outputBuf
    if def.needsEldritchNode then
        local consumed = false
        for nid, ncomps in ECS.query('eldritch_growth', 'pos') do
            local eg = ncomps.eldritch_growth
            if eg.stage and eg.stage >= 3 then
                local np = ncomps.pos
                local dx = math.abs((np.x or 0) - pos.x)
                local dy = math.abs((np.y or 0) - pos.y)
                if dx <= 3 and dy <= 3 and (np.depth or 0) == (pos.depth or 0) then
                    local nodeMachine = ECS.get(nid, 'machine')
                    if nodeMachine and nodeMachine.outputBuf then
                        local ichorCount = nodeMachine.outputBuf.eldritch_ichor or 0
                        if ichorCount >= 1 then
                            nodeMachine.outputBuf.eldritch_ichor = ichorCount - 1
                            if nodeMachine.outputBuf.eldritch_ichor <= 0 then
                                nodeMachine.outputBuf.eldritch_ichor = nil
                            end
                            consumed = true
                            -- Fractional accumulator: 1 item = outputRate seconds of fluid
                            proc._ichorBuf = (proc._ichorBuf or 0) + 5.0
                        end
                    end
                    break
                end
            end
        end
        -- Drain accumulated ichor buffer into pipe fluid
        if (proc._ichorBuf or 0) > 0 then
            proc.active = true
            local inject = math.min(proc._ichorBuf, def.outputRate * dt)
            proc._ichorBuf = proc._ichorBuf - inject
            local pd2 = pos.depth or 0
            Pipes.injectFluid(pos.x, pos.y, def.outputFluid, inject, def.outputMedium, pd2)
            if def.wasteFluid and def.wasteRate > 0 then
                Pipes.injectFluid(pos.x, pos.y, def.wasteFluid, def.wasteRate * dt, def.inputMedium or 'fluid', pd2)
            end
            return
        elseif not consumed then
            deactivateProcessor(proc, id, def)
            return
        end
    end

    local pd = pos.depth or 0

    -- Consume input fluid/gas
    if def.inputFluid and def.inputRate > 0 then
        local needed = def.inputRate * dt
        if not Pipes.hasFluid(pos.x, pos.y, def.inputFluid, needed, def.inputMedium, pd) then
            deactivateProcessor(proc, id, def)
            return
        end
        Pipes.consumeFluid(pos.x, pos.y, def.inputFluid, needed, def.inputMedium, pd)
    end

    proc.active = true

    -- Power generation (ichor_converter produces power as byproduct)
    if def.powerOutput and def.powerOutput > 0 then
        local pwOk, Power = pcall(require, 'src.sim.power')
        if pwOk and not proc._generatorRegistered then
            Power.addGenerator(id, proc.type, pos.x, pos.y)
            proc._generatorRegistered = true
        end
    end

    -- Produce output fluid/gas
    if def.outputFluid and def.outputRate > 0 and not def.needsEldritchNode then
        Pipes.injectFluid(pos.x, pos.y, def.outputFluid, def.outputRate * dt, def.outputMedium, pd)
    end

    -- Produce waste (into the same medium as input)
    if def.wasteFluid and def.wasteRate > 0 then
        Pipes.injectFluid(pos.x, pos.y, def.wasteFluid, def.wasteRate * dt, def.inputMedium or 'fluid', pd)
    end

    -- CO2 emission to room atmosphere (waste_processor)
    if def.co2Emission > 0 then
        local aok, Atmosphere = pcall(require, 'src.sim.atmosphere')
        if aok then
            local tok, Tilemap = pcall(require, 'src.world.tilemap')
            if tok then
                local roomId = Tilemap.getRoom(pos.x, pos.y, pd)
                if roomId then
                    Atmosphere.addCO2(roomId, def.co2Emission * dt)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Processors.registerSystems()
    ECS.addSystem('processor_tick', { 'processor', 'pos' }, processorSystem, 30)
end

return Processors
