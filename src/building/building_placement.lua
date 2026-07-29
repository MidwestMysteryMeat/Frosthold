local Tiles = require('src.world.tiles')
local GameState = require('src.game_state')

local function attach(Building, State)
    local key = State.key

    function Building.tryPlace(defId, x, y, builderId, skipCost, depth)
        depth = depth or 0
        local def = Building.defs[defId]
        if not def then
            return false, 'Unknown building'
        end

        local World = require('src.world.tilemap')

        -- Miners validate their own tiles (ore veins are not buildable)
        local skipBuildableCheck = (def.entitySpawn == 'miner')

        for dy = 0, def.h - 1 do
            for dx = 0, def.w - 1 do
                local tx, ty = x + dx, y + dy
                if not World.inBounds(tx, ty) then
                    return false, 'Out of bounds'
                end
                if not skipBuildableCheck and not Tiles.isBuildable(World.getTile(tx, ty, depth)) then
                    return false, 'Cannot build here'
                end
            end
        end

        if def.entitySpawn == 'conveyor' or def.entitySpawn == 'splitter' then
            local cok, ConvMod = pcall(require, 'src.logistics.conveyors')
            if cok and ConvMod.isOccupied and ConvMod.isOccupied(x, y) then
                return false, 'Belt position occupied'
            end
        end

        if not skipCost then
            local costToResource = {
                raw_ice = 'water',
                raw_meat = 'food',
            }

            local costMult = 1.0
            if builderId then
                local skOk, Skills = pcall(require, 'src.colonist.skills')
                if skOk and Skills.hasMastery(builderId, 'architect') then
                    local eff = Skills.getMasteryEffect(builderId, 'architect')
                    if eff and eff.costMult then
                        costMult = eff.costMult
                    end
                end
            end

            for res, amount in pairs(def.cost) do
                local resKey = costToResource[res] or res
                local effective = math.max(1, math.ceil(amount * costMult))
                if (GameState.resources[resKey] or 0) < effective then
                    return false, 'Not enough ' .. res
                end
            end

            for res, amount in pairs(def.cost) do
                local resKey = costToResource[res] or res
                local effective = math.max(1, math.ceil(amount * costMult))
                local snetOk, SNetBP = pcall(require, 'src.logistics.storage_network')
                if snetOk and SNetBP.withdraw then SNetBP.withdraw(resKey, effective, x, y)
                else GameState.spendResource(resKey, effective) end
            end
        end

        if def.tile then
            for dy = 0, def.h - 1 do
                for dx = 0, def.w - 1 do
                    World.setTile(x + dx, y + dy, def.tile, depth)
                end
            end
        end

        if def.heatOutput then
            local Thermal = require('src.sim.thermal')
            local powerGated = def.powerDraw and def.powerDraw > 0
            if not powerGated then
                Thermal.addHeatSource(x, y, def.heatOutput, depth,
                    def.heatTarget, def.heatDanger, def.heatControllable)
            end
            local info = {
                def = def,
                x = x,
                y = y,
                depth = depth,
                fuel = 100,
                active = true,
                powered = not powerGated,
                upgradeLevel = 0,
            }
            State.placed[key(x, y, depth)] = info
            -- Electric heat buildings (heater, radiator, coolers) draw
            -- grid power and stop heating/cooling when unpowered.
            if powerGated then
                local Power = require('src.sim.power')
                info._powerId = 'heatbld_' .. key(x, y, depth)
                Power.addConsumer(info._powerId, def.powerDraw, x, y)
            end
        end

        if def.entitySpawn == 'bed' then
            local Beds = require('src.building.beds')
            Beds.place(x, y, depth, def.bedQuality)
        elseif def.entitySpawn == 'memorial' then
            local ECS2 = require('src.ecs.ecs')
            local eid = ECS2.spawn()
            ECS2.set(eid, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(eid, 'decoration', { type = 'memorial', beauty = 5, name = 'Memorial' })
        elseif def.entitySpawn == 'steam_hub' then
            local GeneratorMod = require('src.sim.generator')
            GeneratorMod.placeHub(x, y)
        elseif def.entitySpawn == 'cloning_vat' then
            local Power = require('src.sim.power')
            local ECS2 = require('src.ecs.ecs')
            local vatId = ECS2.spawn()
            ECS2.set(vatId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(vatId, 'cloning_vat', {
                active = false,
                progress = 0,
                grown = 0,
            })
            Power.addConsumer(vatId, def.powerDraw, x, y)
        elseif def.entitySpawn == 'radio_beacon' then
            local Power = require('src.sim.power')
            local ECS2 = require('src.ecs.ecs')
            local beaconId = ECS2.spawn()
            ECS2.set(beaconId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(beaconId, 'radio_beacon', {
                powered = false,
                timer = 300,
            })
            Power.addConsumer(beaconId, def.powerDraw, x, y, 'low')
        elseif def.entitySpawn == 'sos_beacon' then
            local Power = require('src.sim.power')
            local ECS2 = require('src.ecs.ecs')
            local beaconId = ECS2.spawn()
            ECS2.set(beaconId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(beaconId, 'sos_beacon', {
                powered = false,
                active = false,
                fired = false,
                countdown = nil,
            })
            ECS2.set(beaconId, 'building_ref', { type = 'sos_beacon', defId = defId })
            Power.addConsumer(beaconId, def.powerDraw, x, y, 'critical')
        elseif def.entitySpawn == 'data_terminal' then
            local Power = require('src.sim.power')
            local ECS2 = require('src.ecs.ecs')
            local termId = ECS2.spawn()
            ECS2.set(termId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(termId, 'data_terminal', {
                powered = false,
                processingDisc = nil,
                processTimer = nil,
            })
            ECS2.set(termId, 'building_ref', { type = 'data_terminal', defId = defId })
            Power.addConsumer(termId, def.powerDraw, x, y, 'low')
        elseif def.entitySpawn == 'endgame' and def.endgameType then
            local Power = require('src.sim.power')
            local ECS2 = require('src.ecs.ecs')
            local egId = ECS2.spawn()
            ECS2.set(egId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(egId, 'endgame_building', {
                type = def.endgameType,
                powered = false,
                chargeProgress = 0,
                phase = 'idle',
                finalWaveSpawned = false,
            })
            ECS2.set(egId, 'building_ref', { type = 'endgame', defId = defId })
            Power.addConsumer(egId, def.powerDraw, x, y, 'critical')
        elseif def.entitySpawn == 'ship_module' then
            local Power = require('src.sim.power')
            local ECS2 = require('src.ecs.ecs')
            local modId = ECS2.spawn()
            ECS2.set(modId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(modId, 'ship_module', {
                shipId = nil,
                systemType = def.shipSystemType or defId,
                operational = true,
                efficiency = 1.0,
            })
            ECS2.set(modId, 'building_ref', { type = 'ship_module', defId = defId })
            ECS2.set(modId, 'durability', { hp = 100, maxHp = 100 })
            if def.powerDraw then
                Power.addConsumer(modId, def.powerDraw, x, y)
            end
        elseif def.entitySpawn == 'shipyard' then
            local Power = require('src.sim.power')
            local ECS2 = require('src.ecs.ecs')
            local yardId = ECS2.spawn()
            ECS2.set(yardId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(yardId, 'machine', {
                type = 'shipyard',
                name = 'Shipyard',
                recipe = nil,
                inputBuf = {},
                outputBuf = {},
                progress = 0,
                active = false,
                powered = false,
                assignee = nil,
            })
            ECS2.set(yardId, 'building_ref', { type = 'shipyard', defId = defId })
            ECS2.set(yardId, 'durability', { hp = 100, maxHp = 100 })
            Power.addConsumer(yardId, def.powerDraw, x, y)
        elseif def.entitySpawn == 'water_vehicle' then
            local ECS2 = require('src.ecs.ecs')
            local boatId = ECS2.spawn()
            ECS2.set(boatId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(boatId, 'building_ref', { type = 'water_vehicle', defId = defId })
            ECS2.set(boatId, 'durability', { hp = 80, maxHp = 80 })
            ECS2.set(boatId, 'machine', {
                type = def.waterVehicleType or 'raft',
                name = def.name,
                recipe = nil,
                inputBuf = {},
                outputBuf = {},
                progress = 0,
                active = false,
                powered = false,
                assignee = nil,
                capacity = def.capacity or 1,
                speed = def.speed or 0.5,
            })
        elseif def.entitySpawn == 'machine' and def.machineType then
            local ECS2 = require('src.ecs.ecs')
            local machId = ECS2.spawn()
            ECS2.set(machId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(machId, 'machine', {
                type = def.machineType,
                name = def.name,
                recipe = nil,
                inputBuf = {},
                outputBuf = {},
                progress = 0,
                active = false,
                powered = true,
                assignee = nil,
            })
            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(machId, def.powerDraw, x, y)
            end
        elseif def.entitySpawn == 'farm_plot' then
            local ECS2 = require('src.ecs.ecs')
            local plotId = ECS2.spawn()
            ECS2.set(plotId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(plotId, 'decoration', { type = 'farm_plot', beauty = 0, name = 'Farm Plot' })
        elseif def.entitySpawn == 'power_conduit' then
            local Power = require('src.sim.power')
            Power.addConduit(x, y)
        elseif def.entitySpawn == 'battery' then
            local ECS2 = require('src.ecs.ecs')
            local batId = ECS2.spawn()
            ECS2.set(batId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(batId, 'building_ref', { defId = defId, type = 'battery' })
            ECS2.set(batId, 'battery', {
                stored = 0,
                capacity = def.batteryCapacity or 1000,
                chargeEff = def.batteryChargeEff or 0.5,
                selfDischarge = def.batterySelfDischarge or 0.002,
            })
            local Power = require('src.sim.power')
            Power.addBattery(batId, x, y, def.batteryCapacity, def.batteryChargeEff, def.batterySelfDischarge)
        elseif def.entitySpawn == 'sump_pump' then
            local ECS2 = require('src.ecs.ecs')
            local pumpId = ECS2.spawn()
            ECS2.set(pumpId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(pumpId, 'building_ref', { defId = defId, type = 'sump_pump' })
            local Power = require('src.sim.power')
            Power.addConsumer(pumpId, def.powerDraw, x, y)
            local fOk, Flooding = pcall(require, 'src.sim.flooding')
            if fOk then
                local World2 = require('src.world.tilemap')
                local roomId = World2.getRoom(x, y, depth)
                Flooding.addPump(pumpId, roomId, 0.03)
            end
        elseif def.entitySpawn == 'power_switch' then
            local ECS2 = require('src.ecs.ecs')
            local swId = ECS2.spawn()
            ECS2.set(swId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(swId, 'building_ref', { defId = defId, type = 'power_switch' })
            ECS2.set(swId, 'power_switch', { on = true })
            local Power = require('src.sim.power')
            Power.addSwitch(swId, x, y)
        elseif def.entitySpawn == 'generator' and def.genType then
            local ECS2 = require('src.ecs.ecs')
            local genId = ECS2.spawn()
            ECS2.set(genId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(genId, 'building_ref', { defId = defId, type = 'generator' })
            local Power = require('src.sim.power')
            Power.addGenerator(genId, def.genType, x, y)
        elseif def.entitySpawn == 'turret' and def.turretType then
            local ECS2 = require('src.ecs.ecs')
            local tid = ECS2.spawn()
            ECS2.set(tid, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(tid, 'turret', {
                type = def.turretType,
                name = def.name,
                cooldown = 0,
                target = nil,
                ammo = 50,
                powered = not def.powerDraw,
            })
            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(tid, def.powerDraw, x, y)
            end
        elseif def.entitySpawn == 'trap' and def.trapType then
            local ECS2 = require('src.ecs.ecs')
            local dOk, Defenses = pcall(require, 'src.combat.defenses')
            local trapDef = dOk and Defenses.TRAP_DEFS[def.trapType]
            local trapId = ECS2.spawn()
            ECS2.set(trapId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(trapId, 'trap', {
                type = def.trapType,
                armed = true,
                uses = trapDef and trapDef.uses or 1,
            })
        elseif def.entitySpawn == 'cover' then
            local ECS2 = require('src.ecs.ecs')
            local coverId = ECS2.spawn()
            ECS2.set(coverId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(coverId, 'cover', {
                value = def.coverValue or 0.4,
                name = def.name,
            })
        elseif def.entitySpawn == 'watchtower' then
            local ECS2 = require('src.ecs.ecs')
            local towerId = ECS2.spawn()
            ECS2.set(towerId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(towerId, 'watchtower', {
                sightRange = 12,
                accuracyBonus = 0.15,
            })
        elseif def.entitySpawn == 'pipe' and def.pipeType then
            local pok2, PipesMod = pcall(require, 'src.logistics.pipes')
            if pok2 then
                PipesMod.addPipeNode(x, y, def.pipeType, def.pipeMedium, depth)
            end
        elseif def.entitySpawn == 'tank' and def.tankType then
            local ECS2 = require('src.ecs.ecs')
            local PipeDefs = require('src.logistics.pipe_defs')
            local tankDef = PipeDefs.TANK_DEFS[def.tankType]
            if tankDef then
                local tankId = ECS2.spawn()
                ECS2.set(tankId, 'pos', { x = x, y = y, depth = depth })
                ECS2.set(tankId, 'tank', {
                    type = def.tankType,
                    medium = tankDef.medium,
                    capacity = tankDef.capacity,
                    pressurized = tankDef.pressurized,
                    contents = {},
                })
                local pok2, PipesMod = pcall(require, 'src.logistics.pipes')
                if pok2 and not PipesMod.isPipe(x, y, tankDef.medium, depth) then
                    local nodeType = tankDef.medium == 'gas' and 'small_duct' or 'small_pipe'
                    PipesMod.addPipeNode(x, y, nodeType, tankDef.medium, depth)
                end
            end
        elseif def.entitySpawn == 'processor' and def.processorType then
            local ppok, ProcessorsMod = pcall(require, 'src.logistics.pipe_processors')
            if ppok then
                ProcessorsMod.place(x, y, def.processorType, depth)
            end
        elseif def.entitySpawn == 'quest_board' then
            local ECS2 = require('src.ecs.ecs')
            local qbId = ECS2.spawn()
            ECS2.set(qbId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(qbId, 'quest_board', { active = true })
        elseif def.entitySpawn == 'shield' then
            local ECS2 = require('src.ecs.ecs')
            local shieldId = ECS2.spawn()
            ECS2.set(shieldId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(shieldId, 'shield', {
                radius = 5,
                hp = 200,
                maxHp = 200,
                regenRate = 2.0,
                regenDelay = 5.0,
                regenCooldown = 0,
                active = true,
            })
            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(shieldId, def.powerDraw, x, y, 'critical')
            end
        elseif def.entitySpawn == 'laser_fence' and def.laserType then
            local ECS2 = require('src.ecs.ecs')
            local dOk, DefMod = pcall(require, 'src.combat.defenses')
            local laserDef = dOk and DefMod.LASER_DEFS[def.laserType]
            local fenceId = ECS2.spawn()
            ECS2.set(fenceId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(fenceId, 'laser_fence', {
                type = def.laserType,
                active = true,
                toggled = true,
                hp = laserDef and laserDef.hp or 100,
                maxHp = laserDef and laserDef.hp or 100,
            })
            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(fenceId, def.powerDraw, x, y)
            end
        elseif def.entitySpawn == 'sensor' then
            local ECS2 = require('src.ecs.ecs')
            local sensorId = ECS2.spawn()
            ECS2.set(sensorId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(sensorId, 'sensor', {
                radius = def.sensorRadius or 15,
                scanTimer = 0,
                scanInterval = 2.0,
                alertDuration = 60,
            })
            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(sensorId, def.powerDraw, x, y)
            end
        elseif def.entitySpawn == 'light_source' then
            if def.powerDraw then
                local Power = require('src.sim.power')
                local ECS2 = require('src.ecs.ecs')
                local lampId = ECS2.spawn()
                ECS2.set(lampId, 'pos', { x = x, y = y, depth = depth })
                ECS2.set(lampId, 'building_ref', { defId = defId, type = 'light_source' })
                Power.addConsumer(lampId, def.powerDraw, x, y, 'low')
            end
        elseif def.entitySpawn == 'conveyor' then
            local cok, ConvMod = pcall(require, 'src.logistics.conveyors')
            if cok then
                local dirRaw = GameState.buildDirection or 'right'
                local convDir = ({ right = 'E', left = 'W', up = 'N', down = 'S', E = 'E', W = 'W', N = 'N', S = 'S' })[dirRaw] or 'E'
                if not ConvMod.place(x, y, convDir, def.beltSpeed) then
                    return false, 'Belt position occupied'
                end
            end
        elseif def.entitySpawn == 'splitter' then
            local cok, ConvMod = pcall(require, 'src.logistics.conveyors')
            if cok then
                local dirRaw = GameState.buildDirection or 'right'
                local convDir = ({ right = 'E', left = 'W', up = 'N', down = 'S', E = 'E', W = 'W', N = 'N', S = 'S' })[dirRaw] or 'E'
                if not ConvMod.placeSplitter(x, y, convDir, def.beltSpeed) then
                    return false, 'Splitter position occupied'
                end
            end
        elseif def.entitySpawn == 'inserter' and def.inserterType then
            local iok, InsMod = pcall(require, 'src.logistics.inserters')
            if iok then
                local dir = GameState.buildDirection or 'right'
                local dx, dy = 0, 0
                if dir == 'right' then
                    dx = 1
                elseif dir == 'left' then
                    dx = -1
                elseif dir == 'up' then
                    dy = -1
                elseif dir == 'down' then
                    dy = 1
                end
                InsMod.spawn(def.inserterType, x, y, x - dx, y - dy, x + dx, y + dy)
            end
        elseif def.entitySpawn == 'stockpile' then
            local ECS2 = require('src.ecs.ecs')
            local sid = ECS2.spawn()
            ECS2.set(sid, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(sid, 'stockpile', {
                items = {},
                capacity = def.stockpileCapacity or 20,
            })
            ECS2.set(sid, 'building_ref', { type = 'stockpile', defId = defId })
        elseif def.entitySpawn == 'miner' and def.minerType then
            local mok, MinersMod = pcall(require, 'src.building.miners')
            if mok and MinersMod.place then
                local mid, err = MinersMod.place(x, y, depth, def.minerType)
                if not mid then return false, err or 'Cannot place miner here' end
            end
        elseif def.entitySpawn == 'deep_drill' then
            local dok, DrillMod = pcall(require, 'src.building.deep_drill')
            if dok and DrillMod.place then
                DrillMod.place(x, y)
            end
        elseif def.entitySpawn == 'expedition_table' then
            local ECS2 = require('src.ecs.ecs')
            local etId = ECS2.spawn()
            ECS2.set(etId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(etId, 'building_ref', { defId = defId, type = 'expedition_table' })
        elseif def.entitySpawn == 'cryo_pod' then
            local ECS2 = require('src.ecs.ecs')
            local cpId = ECS2.spawn()
            ECS2.set(cpId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(cpId, 'building_ref', { defId = defId, type = 'cryo_pod' })
            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(cpId, def.powerDraw, x, y)
            end
        elseif def.entitySpawn == 'recreation' then
            local ECS2 = require('src.ecs.ecs')
            local recId = ECS2.spawn()
            ECS2.set(recId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(recId, 'building_ref', { defId = defId, type = 'recreation' })
            ECS2.set(recId, 'recreation', {
                recType = def.recType or 'bonfire',
                joyRate = def.recJoy or 0.10,
                capacity = def.recCapacity or 4,
                users = {},
                userCount = 0,
            })
            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(recId, def.powerDraw, x, y, 'low')
            end
        elseif def.entitySpawn == 'scrubber' then
            local ECS2 = require('src.ecs.ecs')
            local scId = ECS2.spawn()
            ECS2.set(scId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(scId, 'building_ref', { defId = defId, type = 'scrubber' })
            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(scId, def.powerDraw, x, y)
            end
        elseif def.entitySpawn == 'containment' then
            local ECS2 = require('src.ecs.ecs')
            local cellId = ECS2.spawn()
            ECS2.set(cellId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(cellId, 'building_ref', { defId = defId, type = 'containment' })
            ECS2.set(cellId, 'containment_cell', {
                cellType = def.cellType or 'cell',
                mode = 'study',
                subjectId = nil,
                currentRisk = 0,
                incidentCooldown = 0,
            })
            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(cellId, def.powerDraw, x, y)
            end
        elseif def.entitySpawn == 'storage' then
            local StorageMod = require('src.building.storage')
            local storId = StorageMod.place(x, y, depth, defId)
            if storId and def.powerDraw and def.powerDraw > 0 then
                local Power = require('src.sim.power')
                Power.addConsumer(storId, def.powerDraw, x, y)
            end
        end

        if def.lightPreset then
            local lok, Lighting = pcall(require, 'src.sim.lighting')
            if lok then
                Lighting.addLight(x, y, def.lightPreset)
            end
        elseif def.lightRadius then
            local lok, Lighting = pcall(require, 'src.sim.lighting')
            if lok then
                Lighting.addLightCustom(x, y, def.lightRadius, def.lightIntensity or 0.8)
            end
        end

        if def.sightRadius then
            local vok, Vis = pcall(require, 'src.sim.visibility')
            if vok then
                Vis.addSight('bld_' .. key(x, y, depth), x, y, def.sightRadius)
            end
        end

        local sok, Sound = pcall(require, 'src.audio.sound')
        if sok then
            Sound.play('build_place', x, y)
        end

        local qok2, QuestMod = pcall(require, 'src.quest.quest')
        if qok2 and QuestMod.onBuildingPlaced then
            QuestMod.onBuildingPlaced(defId)
        end

        if def.ventType then
            local ok, Atmosphere = pcall(require, 'src.sim.atmosphere')
            local ECS2 = require('src.ecs.ecs')
            local ventEntityId = ECS2.spawn()
            ECS2.set(ventEntityId, 'pos', { x = x, y = y, depth = depth or 0 })
            ECS2.set(ventEntityId, 'machine', {
                type = def.ventType,
                name = def.name,
                recipe = nil,
                inputBuf = {},
                outputBuf = {},
                progress = 0,
                active = false,
                powered = not def.powerDraw,
                assignee = nil,
            })

            if def.powerDraw then
                local Power = require('src.sim.power')
                Power.addConsumer(ventEntityId, def.powerDraw, x, y)
            end

            if ok then
                local World2 = require('src.world.tilemap')
                local rid = World2.getRoom(x, y, depth or 0)
                Atmosphere.addVent(ventEntityId, def.ventType, rid, x, y, ventEntityId, depth)
            end
            State.placed[key(x, y, depth)] = {
                def = def,
                x = x,
                y = y,
                depth = depth,
                fuel = 100,
                active = true,
                ventKey = ventEntityId,
            }
        end

        local dok, Det = pcall(require, 'src.sim.deterioration')
        if dok and Det.attach then
            local ECS2 = require('src.ecs.ecs')
            for id, comps in ECS2.query('pos') do
                if comps.pos.x == x and comps.pos.y == y then
                    if not ECS2.get(id, 'durability') then
                        if ECS2.get(id, 'machine') or ECS2.get(id, 'turret')
                            or ECS2.get(id, 'building_ref') or ECS2.get(id, 'trap') then
                            Det.attach(id)
                        end
                    end
                end
            end
        end

        -- MRP structural engineering: boost HP of newly placed buildings by 15%
        local smok, MRPBld = pcall(require, 'src.sim.mrp')
        if smok and MRPBld.hasUnlock('structural_engineering') then
            local ECS2 = require('src.ecs.ecs')
            for entityId, comps in ECS2.query('pos') do
                if comps.pos.x == x and comps.pos.y == y then
                    local dur = ECS2.get(entityId, 'durability')
                    if dur then
                        dur.maxHp = math.floor(dur.maxHp * 1.15)
                        dur.hp = dur.maxHp
                    end
                end
            end
        end

        if not State.placed[key(x, y, depth)] then
            State.placed[key(x, y, depth)] = { def = def, x = x, y = y, depth = depth }
        end

        if def.w > 1 or def.h > 1 then
            for sdy = 0, def.h - 1 do
                for sdx = 0, def.w - 1 do
                    if sdx ~= 0 or sdy ~= 0 then
                        State.placed[key(x + sdx, y + sdy, depth)] = { def = def, x = x, y = y, depth = depth, subTile = true }
                    end
                end
            end
        end

        GameState.buildingsConstructed = (GameState.buildingsConstructed or 0) + 1
        return true
    end

    function Building.remove(x, y, depth)
        depth = depth or 0
        local placedKey = key(x, y, depth)
        local info = State.placed[placedKey]
        if info and info.subTile then
            x, y = info.x, info.y
            placedKey = key(x, y, depth)
            info = State.placed[placedKey]
        end

        if info then
            if info.def.heatOutput then
                local Thermal = require('src.sim.thermal')
                local heatOut = info.def.heatOutput
                local uok, Upgrades = pcall(require, 'src.building.upgrades')
                if uok and info.upgradeLevel and info.upgradeLevel > 0 then
                    heatOut = Upgrades.getEffectiveStat(info, 'heatOutput')
                end
                -- Only registered while active + powered.
                if info.active and info.powered ~= false then
                    Thermal.removeHeatSource(x, y, heatOut, depth)
                end
                if info._powerId then
                    local PowerMod = require('src.sim.power')
                    PowerMod.removeConsumer(info._powerId)
                end
            end
            if info.def.ventType then
                local ok, Atmosphere = pcall(require, 'src.sim.atmosphere')
                if ok then
                    Atmosphere.removeVent(info.ventKey or placedKey)
                end
            end
            if info.def.lightPreset or info.def.lightRadius then
                local lok, Lighting = pcall(require, 'src.sim.lighting')
                if lok then
                    Lighting.removeLight(x, y)
                end
            end
            if info.def.sightRadius then
                local vok, Vis = pcall(require, 'src.sim.visibility')
                if vok then
                    Vis.removeSight('bld_' .. placedKey)
                end
            end
        end

        local bw = (info and info.def) and (info.def.w or 1) or 1
        local bh = (info and info.def) and (info.def.h or 1) or 1
        for fdy = 0, bh - 1 do
            for fdx = 0, bw - 1 do
                State.placed[key(x + fdx, y + fdy, depth)] = nil
            end
        end

        if info and info.def then
            local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if stOk and Storyteller.logEvent then
                Storyteller.logEvent('building_removed', (info.def.name or 'Building') .. ' removed.')
            end
        end

        local cok, ConvMod = pcall(require, 'src.logistics.conveyors')
        if cok then
            ConvMod.remove(x, y)
        end

        local pok, PipesMod = pcall(require, 'src.logistics.pipes')
        if pok then
            PipesMod.removePipeNode(x, y, 'fluid', depth)
            PipesMod.removePipeNode(x, y, 'gas', depth)
        end

        local ppok, ProcessorsMod = pcall(require, 'src.logistics.pipe_processors')
        if ppok then
            ProcessorsMod.remove(x, y, depth)
        end

        local pwOk2, PowerMod2 = pcall(require, 'src.sim.power')
        if pwOk2 then
            PowerMod2.removeConduit(x, y)
            PowerMod2.removeSwitch(x, y)
        end

        local flOk, FloodMod = pcall(require, 'src.sim.flooding')
        if flOk then
            local ECS3 = require('src.ecs.ecs')
            for id, comps in ECS3.query('building_ref', 'pos') do
                if comps.pos.x == x and comps.pos.y == y and comps.building_ref.type == 'sump_pump' then
                    FloodMod.removePump(id)
                end
            end
        end

        local ECS2 = require('src.ecs.ecs')
        local buildingComps = {
            'tank', 'bed', 'decoration', 'machine', 'turret', 'trap',
            'shield', 'watchtower', 'quest_board', 'research_bench',
            'deep_drill', 'miner', 'cloning_vat', 'radio_beacon', 'inserter',
            'battery', 'power_switch', 'stockpile',
            'laser_fence', 'sensor', 'cover', 'building_ref',
            'endgame_building', 'cryo_pod', 'scrubber', 'expedition_table',
            'farm_plot', 'steam_hub', 'containment_cell',
            'recreation', 'storage',
        }
        local toDestroy = {}
        for _, compName in ipairs(buildingComps) do
            for id, comps in ECS2.query(compName, 'pos') do
                if comps.pos.x == x and comps.pos.y == y and (comps.pos.depth or 0) == depth then
                    toDestroy[id] = true
                    break
                end
            end
        end
        for id in pairs(toDestroy) do
            -- Drop storage contents on the ground before destroying the entity
            if ECS2.get(id, 'storage') then
                local sOk, StorageMod = pcall(require, 'src.building.storage')
                if sOk then
                    StorageMod.spawnContentsOnGround(id)
                end
            end
            local pwOk, PowerMod = pcall(require, 'src.sim.power')
            if pwOk then
                PowerMod.removeConsumer(id)
                PowerMod.removeBattery(id)
                PowerMod.removeGenerator(id)
            end
            ECS2.destroy(id)
        end

        local stOk, Structural = pcall(require, 'src.world.structural')
        if stOk and Structural.onColumnRemoved then
            Structural.onColumnRemoved(x, y, depth)
        end

        local World = require('src.world.tilemap')
        for fdy = 0, bh - 1 do
            for fdx = 0, bw - 1 do
                World.setTile(x + fdx, y + fdy, Tiles.DEBRIS, depth)
            end
        end
    end

    -- Auto-refuel: 1 wood from colony stores buys this much fuel
    local REFUEL_THRESHOLD  = 30
    local FUEL_PER_WOOD     = 25

    -- Heat buildings are tile-backed rather than ECS-backed, so their power
    -- consumers must be re-created explicitly after Power.init() on save load.
    function Building.restorePowerConsumers()
        local PowerMod = require('src.sim.power')
        for placedKey, info in pairs(State.placed) do
            local def = info.def
            if not info.subTile and def and def.heatOutput
                and def.powerDraw and def.powerDraw > 0 then
                info._powerId = 'heatbld_' .. placedKey
                info.powered = false
                PowerMod.addConsumer(info._powerId, def.powerDraw, info.x, info.y)
            end
        end
    end

    function Building.update(dt)
        local uok, Upgrades = pcall(require, 'src.building.upgrades')
        for _, info in pairs(State.placed) do
            local def = info.def
            if not info.subTile and (def.fuelRate or (info._powerId and def.heatOutput)) then
                local fuelRate = def.fuelRate
                local heatOut = def.heatOutput
                if uok and info.upgradeLevel and info.upgradeLevel > 0 then
                    if def.fuelRate then
                        fuelRate = Upgrades.getEffectiveStat(info, 'fuelRate')
                    end
                    heatOut = Upgrades.getEffectiveStat(info, 'heatOutput')
                end

                -- Electric heat buildings: only heat/cool while the grid
                -- powers them. Heat source is registered iff active+powered.
                if info._powerId and heatOut then
                    local PowerMod = require('src.sim.power')
                    local powered = PowerMod.isConsumerPowered(info._powerId)
                    if info.powered == nil then info.powered = true end
                    if powered ~= info.powered then
                        local Thermal = require('src.sim.thermal')
                        if powered and info.active and (info.fuel or 100) > 0 then
                            Thermal.addHeatSource(info.x, info.y, heatOut, info.depth or 0,
                                def.heatTarget, def.heatDanger, def.heatControllable)
                        elseif not powered and info.active then
                            Thermal.removeHeatSource(info.x, info.y, heatOut, info.depth or 0)
                        end
                        info.powered = powered
                    end
                end

                if fuelRate then
                    -- Burn fuel only while running (active and powered).
                    if info.active and info.powered ~= false then
                        info.fuel = info.fuel - fuelRate * dt
                    end

                    -- Auto-refuel from colony wood before (or after) burning out.
                    if info.fuel < REFUEL_THRESHOLD then
                        while info.fuel < REFUEL_THRESHOLD
                            and GameState.spendResource('wood', 1) do
                            info.fuel = math.min(100, info.fuel + FUEL_PER_WOOD)
                        end
                        -- Re-ignite a burned-out heater once it has fuel again.
                        if not info.active and info.fuel > 0 and heatOut then
                            info.active = true
                            if info.powered ~= false then
                                local Thermal = require('src.sim.thermal')
                                Thermal.addHeatSource(info.x, info.y, heatOut, info.depth or 0,
                                    def.heatTarget, def.heatDanger, def.heatControllable)
                            end
                        end
                    end

                    if info.active and info.fuel <= 0 then
                        info.fuel = 0
                        info.active = false
                        if heatOut and info.powered ~= false then
                            local Thermal = require('src.sim.thermal')
                            Thermal.removeHeatSource(info.x, info.y, heatOut, info.depth or 0)
                        end
                    end
                end
            end
        end
    end
end

return attach
