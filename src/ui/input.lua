-- input.lua — Input handling: selection, building, tool modes
-- Translates mouse/keyboard into game actions.

local Camera    = require('src.render.camera')
local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')
local Jobs      = require('src.colonist.jobs')
local Zones     = require('src.world.zones')
local BuildMenu = require('src.ui.build_menu')

local Input = {}

local selectionBox = nil  -- {x1, y1, x2, y2} in screen coords during drag
local zoneDragStart = nil -- {x, y} tile coords for zone painting

function Input.init()
    selectionBox = nil
    zoneDragStart = nil
end

function Input.update(dt)
    -- Nothing continuous for now
end

function Input.keypressed(key)
    if BuildMenu.isCapturingKeyboard and BuildMenu.isCapturingKeyboard() then
        if BuildMenu.keypressed then
            BuildMenu.keypressed(key)
        end
        return
    end

    -- Speed controls
    if key == '1' then GameState.speed = 1 end
    if key == '2' then GameState.speed = 2 end
    if key == '3' then GameState.speed = 3 end
    if key == 'space' then GameState.paused = not GameState.paused end

    -- Tool shortcuts
    if key == 'b' then
        GameState.buildMode = not GameState.buildMode
        if GameState.buildMode then
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.selectedTool = 'build'
            GameState.selectedZoneId = nil
        else
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.selectedTool = nil
            GameState.buildGhost = nil
        end
    end

    -- Mine designation tool
    if key == 'm' then
        if GameState.selectedTool == 'mine' then
            GameState.selectedTool = nil
        else
            GameState.buildMode = false
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.buildGhost = nil
            GameState.selectedTool = 'mine'
        end
    end

    -- Zone designation tool (stockpile)
    if key == 'z' then
        if GameState.selectedTool == 'zone_stockpile' then
            GameState.selectedTool = nil
        else
            GameState.buildMode = false
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.buildGhost = nil
            GameState.selectedTool = 'zone_stockpile'
        end
    end

    -- Dumping zone tool
    if key == 'x' then
        if GameState.selectedTool == 'zone_dumping' then
            GameState.selectedTool = nil
        else
            GameState.buildMode = false
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.buildGhost = nil
            GameState.selectedTool = 'zone_dumping'
        end
    end

    -- Allowed area tool
    if key == 'y' then
        if GameState.selectedTool == 'zone_restricted' then
            GameState.selectedTool = nil
        else
            GameState.buildMode = false
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.buildGhost = nil
            GameState.selectedTool = 'zone_restricted'
            GameState.selectedZoneId = nil
        end
    end

    -- Deconstruct planner tool
    if key == 'd' then
        if GameState.selectedTool == 'deconstruct' then
            GameState.selectedTool = nil
        else
            GameState.buildMode = false
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.buildGhost = nil
            GameState.selectedTool = 'deconstruct'
        end
    end

    -- Forage designation tool
    if key == 'f' then
        if GameState.selectedTool == 'forage' then
            GameState.selectedTool = nil
        else
            GameState.buildMode = false
            if BuildMenu.reset then BuildMenu.reset() end
            GameState.buildGhost = nil
            GameState.selectedTool = 'forage'
        end
    end

    -- Thermal overlay toggle
    if key == 'f2' then
        local Renderer = require('src.render.renderer')
        Renderer.toggleThermalOverlay()
    end

    -- Power overlay toggle
    if key == 'f4' then
        local Renderer = require('src.render.renderer')
        Renderer.togglePowerOverlay()
    end

    if key == 'f6' then
        local Renderer = require('src.render.renderer')
        if Renderer.toggleAtmosphereOverlay then Renderer.toggleAtmosphereOverlay() end
    end

    if key == 'f7' then
        local Renderer = require('src.render.renderer')
        if Renderer.toggleLogisticsOverlay then Renderer.toggleLogisticsOverlay() end
    end

    if key == 'f8' then
        local Renderer = require('src.render.renderer')
        if Renderer.toggleContainmentOverlay then Renderer.toggleContainmentOverlay() end
    end

    if key == 'f10' then
        local Renderer = require('src.render.renderer')
        if Renderer.toggleStructuralOverlay then Renderer.toggleStructuralOverlay() end
    end

    -- Event log toggle
    if key == 'l' then
        local UI = require('src.ui.ui')
        UI.toggleEventLog()
    end

    -- Hotkey help toggle ('/' only; 'h' is used by medical panel)
    if key == '/' then
        local UI = require('src.ui.ui')
        UI.toggleHotkeyHelp()
    end

    -- Task queue toggle
    if key == 'j' and not GameState.buildMode then
        local UI = require('src.ui.ui')
        if UI.toggleTaskQueue then UI.toggleTaskQueue() end
    end

    -- Rotate build direction (R = clockwise in build mode)
    -- Draft toggle (R outside build mode) is handled in main.lua
    if key == 'r' and GameState.buildMode then
        local cycle = { right = 'down', down = 'left', left = 'up', up = 'right' }
        GameState.buildDirection = cycle[GameState.buildDirection or 'right'] or 'right'
    end

    -- Cancel current action
    if key == 'escape' then
        GameState.buildMode = false
        if BuildMenu.reset then BuildMenu.reset() end
        GameState.buildGhost = nil
        GameState.selectedTool = nil
        GameState.selectedEntities = {}
        GameState.selectedZoneId = nil
        zoneDragStart = nil
    end

    -- N: cycle selected colonist
    if key == 'n' then
        local colonists = {}
        for id, comps in ECS.query('colonist') do
            if comps.colonist.state ~= 'dead' then
                colonists[#colonists + 1] = id
            end
        end
        if #colonists > 0 then
            table.sort(colonists)
            local current = nil
            for id in pairs(GameState.selectedEntities) do
                current = id
                break
            end
            local nextIdx = 1
            if current then
                for i, id in ipairs(colonists) do
                    if id == current then
                        nextIdx = (i % #colonists) + 1
                        break
                    end
                end
            end
            GameState.selectedEntities = { [colonists[nextIdx]] = true }
            -- Center camera on selected colonist and follow to their depth
            local pos = ECS.get(colonists[nextIdx], 'pos')
            if pos then
                Camera.centerOn(pos.x, pos.y)
                GameState.viewDepth = pos.depth or 0
            end
        end
    end

    -- Speed adjust
    if key == ',' then
        GameState.speed = math.max(1, GameState.speed - 1)
    end
    if key == '.' then
        GameState.speed = math.min(3, GameState.speed + 1)
    end

    -- Depth cycling: [ = go deeper, ] = go shallower
    if key == '[' then
        local World = require('src.world.tilemap')
        local maxDepth = World.getMaxDepth and World.getMaxDepth() or 5
        local vd = GameState.viewDepth or 0
        if vd < maxDepth then
            GameState.viewDepth = vd + 1
        end
    end
    if key == ']' then
        local vd = GameState.viewDepth or 0
        if vd > 0 then
            GameState.viewDepth = vd - 1
        end
    end

    -- Terraform tool shortcuts (only outside build mode)
    if not GameState.buildMode then
        -- Shift+S: dig stairs down
        if key == 's' and love.keyboard.isDown('lshift', 'rshift') then
            if GameState.selectedTool == 'terraform_dig_stair_down' then
                GameState.selectedTool = nil
            else
                GameState.selectedTool = 'terraform_dig_stair_down'
            end
        end
        -- Shift+W: dig stairs up
        if key == 'w' and love.keyboard.isDown('lshift', 'rshift') then
            if GameState.selectedTool == 'terraform_dig_stair_up' then
                GameState.selectedTool = nil
            else
                GameState.selectedTool = 'terraform_dig_stair_up'
            end
        end
        -- Shift+C: dig channel
        if key == 'c' and love.keyboard.isDown('lshift', 'rshift') then
            if GameState.selectedTool == 'terraform_dig_channel' then
                GameState.selectedTool = nil
            else
                GameState.selectedTool = 'terraform_dig_channel'
            end
        end
        -- Shift+R: carve ramp (only when not in build mode)
        if key == 'r' and love.keyboard.isDown('lshift', 'rshift') then
            if GameState.selectedTool == 'terraform_carve_ramp' then
                GameState.selectedTool = nil
            else
                GameState.selectedTool = 'terraform_carve_ramp'
            end
        end
        -- Shift+H: dig shaft
        if key == 'h' and love.keyboard.isDown('lshift', 'rshift') then
            if GameState.selectedTool == 'terraform_dig_shaft' then
                GameState.selectedTool = nil
            else
                GameState.selectedTool = 'terraform_dig_shaft'
            end
        end
    end

    -- Ship navigation controls (only active in space)
    if GameState.activeMap == 'space' then
        local smOk, ShipMovement = pcall(require, 'src.space.ship_movement')
        if smOk then
            if key == 'w' then
                ShipMovement.setHeading(-math.pi / 2)  -- up
                ShipMovement.setThrust(true)
            elseif key == 's' and not love.keyboard.isDown('lshift', 'rshift') then
                ShipMovement.setHeading(math.pi / 2)   -- down
                ShipMovement.setThrust(true)
            elseif key == 'a' then
                ShipMovement.setHeading(math.pi)        -- left
                ShipMovement.setThrust(true)
            elseif key == 'd' then
                ShipMovement.setHeading(0)              -- right
                ShipMovement.setThrust(true)
            elseif key == 'space' then
                ShipMovement.setThrust(false)           -- brake / cut engines
                ShipMovement.cancelAutopilot()
            end
        end

        -- Land on planet (Shift+L in space near planet orbit)
        if key == 'l' and love.keyboard.isDown('lshift', 'rshift') then
            local ECS = require('src.ecs.ecs')
            local playerX, playerY = 0, 0
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    playerX = comps.pos.x
                    playerY = comps.pos.y
                    break
                end
            end
            local poiOk, POIGen = pcall(require, 'src.space.poi_generator')
            if poiOk then
                local nearest, dist = POIGen.getNearestPOI(playerX, playerY, 'planet_orbit')
                if nearest and dist < 10 then
                    local planetId = nearest.subtype
                    local pdOk, PlanetDiscovery = pcall(require, 'src.space.planet_discovery')
                    if pdOk and PlanetDiscovery.isDiscovered(planetId) then
                        local csOk, ContextSwap = pcall(require, 'src.space.context_swap')
                        if csOk then
                            -- Check if we have a colony here already
                            local colonyId = nil
                            for cid, colony in pairs(GameState.colonies or {}) do
                                if colony.planetId == planetId then
                                    colonyId = cid
                                    break
                                end
                            end
                            if colonyId then
                                ContextSwap.landOnColony(colonyId)
                            else
                                ContextSwap.landOnNewPlanet(planetId)
                            end
                            local alOk, Alerts = pcall(require, 'src.ui.alerts')
                            if alOk and Alerts.send then
                                Alerts.send('DISCOVERY', 'Landing on ' .. planetId .. '...')
                            end
                        end
                    end
                end
            end
        end

        -- Stealth toggle (X key)
        if key == 'x' then
            local stOk, Stealth = pcall(require, 'src.space.stealth')
            if stOk then
                if Stealth.isStealthActive() then
                    Stealth.deactivateStealth()
                else
                    Stealth.activateStealth()
                end
            end
        end

        -- Launch from colony (L key when ship exists on colony map)
    elseif key == 'l' and love.keyboard.isDown('lshift', 'rshift') then
        -- Shift+L = launch ship (only on planet surface, not in space)
        if GameState.activeMap and GameState.activeMap ~= 'space' then
            local smOk, ShipManager = pcall(require, 'src.space.ship_manager')
            if smOk then
                local shipId = ShipManager.getShipAnchor()
                if shipId then
                    local csOk, ContextSwap = pcall(require, 'src.space.context_swap')
                    if csOk then
                        -- Extract ship from colony and launch to space
                        local ECS = require('src.ecs.ecs')
                        local shipComp = ECS.get(shipId, 'ship')
                        local pos = ECS.get(shipId, 'pos')
                        if shipComp and pos then
                            local sdOk, ShipDefs = pcall(require, 'src.space.ship_defs')
                            local tier = sdOk and ShipDefs.getTier(shipComp.tier)
                            local gridW = tier and tier.gridW or 12
                            local gridH = tier and tier.gridH or 8
                            local shipSnapshot = ShipManager.extractFromColony(pos.x, pos.y, gridW, gridH)
                            local colonyId = GameState.activeMap
                            ContextSwap.launchToSpace(colonyId, shipSnapshot)

                            local alOk, Alerts = pcall(require, 'src.ui.alerts')
                            if alOk and Alerts.send then
                                Alerts.send('DISCOVERY', 'Launched into space!')
                            end
                        end
                    end
                end
            end
        end
    end
end

function Input.keyreleased(key)
end

function Input.mousepressed(x, y, button)
    if button == 2 then
        -- Right click in space: set autopilot destination
        if GameState.activeMap == 'space' then
            local tileX = math.floor((x + GameState.camX) / 32)
            local tileY = math.floor((y + GameState.camY) / 32)
            local smOk, ShipMovement = pcall(require, 'src.space.ship_movement')
            if smOk then
                ShipMovement.setAutopilot(tileX, tileY)
            end
            return
        end

        -- Right click: context menu or move (immediate, no camera drag)
        if GameState.buildMode then
            if GameState.buildGhost then
                GameState.buildGhost = nil
            else
                GameState.buildMode = false
                if BuildMenu.reset then BuildMenu.reset() end
                GameState.selectedTool = nil
            end
            return
        end

        local UI = require('src.ui.ui')
        if UI.isContextMenuOpen() then
            UI.closeContextMenu()
            return
        end

        Input._handleRightClick(x, y)
        return
    end

    if button == 3 then
        Camera.startDrag(x, y)
        return
    end

    if button == 1 then
        -- Terraform tool designation (single click or drag)
        local tfTool = GameState.selectedTool
        if tfTool and tfTool:match('^terraform_') then
            local opId = tfTool:match('^terraform_(.+)$')
            selectionBox = { x1 = x, y1 = y, x2 = x, y2 = y, mode = 'terraform', opId = opId }
            return
        end

        if GameState.selectedTool == 'deconstruct' then
            -- Start deconstruct designation drag
            selectionBox = { x1 = x, y1 = y, x2 = x, y2 = y, mode = 'deconstruct' }
        elseif GameState.selectedTool == 'mine' then
            -- Start mine designation drag
            local tx, ty = Camera.screenToTile(x, y)
            selectionBox = { x1 = x, y1 = y, x2 = x, y2 = y, mode = 'mine' }
        elseif GameState.selectedTool == 'forage' then
            -- Start forage designation drag
            local tx, ty = Camera.screenToTile(x, y)
            selectionBox = { x1 = x, y1 = y, x2 = x, y2 = y, mode = 'forage' }
        elseif GameState.selectedTool == 'zone_stockpile'
            or GameState.selectedTool == 'zone_dumping'
            or GameState.selectedTool == 'zone_restricted' then
            -- Start zone drawing drag
            local tx, ty = Camera.screenToTile(x, y)
            selectionBox = { x1 = x, y1 = y, x2 = x, y2 = y, mode = GameState.selectedTool }
        elseif GameState.buildMode and GameState.buildGhost then
            local Building = require('src.building.building')
            local def = Building.defs[GameState.buildGhost.id]
            local es = def and def.entitySpawn
            -- Drag-line for linear buildings (belts, pipes, inserters, splitters)
            if es == 'conveyor' or es == 'splitter' or es == 'inserter' or es == 'pipe' then
                selectionBox = { x1 = x, y1 = y, x2 = x, y2 = y, mode = 'build_line' }
            else
                -- Single-click placement for other buildings
                local tx, ty = Camera.screenToTile(x, y)
                local bvd = GameState.viewDepth or 0
                if def then
                    local World = require('src.world.tilemap')
                    local Tiles = require('src.world.tiles')
                    local UI = require('src.ui.ui')
                    local canPlace = true
                    local failReason = nil
                    for dy = 0, (def.h or 1) - 1 do
                        for dx = 0, (def.w or 1) - 1 do
                            local bx, by = tx + dx, ty + dy
                            if not World.inBounds(bx, by) or not Tiles.isBuildable(World.getTile(bx, by, bvd)) then
                                canPlace = false
                                failReason = 'Cannot build here'
                            end
                        end
                    end
                    if canPlace and def.cost then
                        for res, amount in pairs(def.cost) do
                            if (GameState.resources[res] or 0) < amount then
                                canPlace = false
                                failReason = string.format('Need %s (have %d, need %d)',
                                    res, GameState.resources[res] or 0, amount)
                            end
                        end
                    end
                    if canPlace then
                        Jobs.designateBuild(tx, ty, GameState.buildGhost.id, bvd)
                    elseif failReason then
                        UI.showSaveToast(failReason)
                    end
                end
            end
        else
            -- Start selection box
            selectionBox = { x1 = x, y1 = y, x2 = x, y2 = y }
        end
    end
end

---------------------------------------------------------------------------
-- Right-click action (deferred from mousepressed to allow drag-to-pan)
---------------------------------------------------------------------------

function Input._handleRightClick(x, y)
    local UI = require('src.ui.ui')
    local tx, ty = Camera.screenToTile(x, y)
    local vd = GameState.viewDepth or 0

    -- Determine acting colonist (single selected, alive)
    local actingColonistId = nil
    local selCount = 0
    for sid in pairs(GameState.selectedEntities) do
        selCount = selCount + 1
        actingColonistId = sid
    end
    if selCount ~= 1 or not actingColonistId then
        actingColonistId = nil
    elseif actingColonistId then
        local acol = ECS.get(actingColonistId, 'colonist')
        if not acol or acol.state == 'dead' then actingColonistId = nil end
    end

    -- Drafted colonist: attack-move on creature, else normal move
    if actingColonistId then
        local acol = ECS.get(actingColonistId, 'colonist')
        if acol and acol.drafted then
            for cid, comps in ECS.query('creature', 'pos') do
                local cpos = comps.pos
                if cpos.x == tx and cpos.y == ty and (cpos.depth or 0) == vd
                   and comps.creature.state ~= 'dead' then
                    local hok, Hunting = pcall(require, 'src.combat.hunting')
                    if hok and Hunting.designate then
                        Hunting.designate(cid)
                    end
                    return
                end
            end
        end
    end

    -- Check for living colonist at tile
    for id, comps in ECS.query('colonist', 'pos') do
        local pos = comps.pos
        if pos.x == tx and pos.y == ty and (pos.depth or 0) == vd
           and comps.colonist.state ~= 'dead' then
            UI.openContextMenu(x, y, id, 'colonist')
            return
        end
    end

    -- Check for corpse item at tile
    for id, comps in ECS.query('item', 'pos') do
        local pos = comps.pos
        if pos.x == tx and pos.y == ty and (pos.depth or 0) == vd
           and comps.item.itemId == 'corpse_human' then
            UI.openContextMenu(x, y, id, 'corpse', actingColonistId)
            return
        end
    end

    -- Check for creature at tile
    for id, comps in ECS.query('creature', 'pos') do
        local pos = comps.pos
        if pos.x == tx and pos.y == ty and (pos.depth or 0) == vd
           and comps.creature.state ~= 'dead' then
            UI.openContextMenu(x, y, id, 'creature', actingColonistId)
            return
        end
    end

    -- Check for building at tile (multi-tile footprint)
    local bok, Building = pcall(require, 'src.building.building')
    if bok then
        for id, comps in ECS.query('building_ref', 'pos') do
            local pos = comps.pos
            local def = Building.defs[comps.building_ref.defId]
            local bw = def and def.w or 1
            local bh = def and def.h or 1
            if (pos.depth or 0) == vd
               and tx >= pos.x and tx < pos.x + bw
               and ty >= pos.y and ty < pos.y + bh then
                UI.openContextMenu(x, y, id, 'building', actingColonistId)
                return
            end
        end
    end

    -- Check for non-corpse item at tile
    for id, comps in ECS.query('item', 'pos') do
        local pos = comps.pos
        if pos.x == tx and pos.y == ty and (pos.depth or 0) == vd
           and comps.item.itemId ~= 'corpse_human' then
            UI.openContextMenu(x, y, id, 'item', actingColonistId)
            return
        end
    end

    -- No entity at tile: show tile-based force options if colonist selected
    if actingColonistId then
        local World = require('src.world.tilemap')
        local Tiles = require('src.world.tiles')
        local tile = World.getTile(tx, ty, vd)
        local hasForceOption = false

        if tile == Tiles.ROCK or tile == Tiles.ICE or tile == Tiles.ORE_VEIN
           or tile == Tiles.DEEP_ROCK or tile == Tiles.UNDERGROUND_ROCK
           or tile == Tiles.LEAD_ORE then
            hasForceOption = true
        end
        if tile == Tiles.TREE then
            hasForceOption = true
        end

        if hasForceOption then
            UI.openContextMenu(x, y, nil, 'tile', actingColonistId, tx, ty, vd)
            return
        end
    end

    -- No entity found: move drafted colonist, or open tile context menu for undrafted
    local canMove = false
    if actingColonistId then
        local col = ECS.get(actingColonistId, 'colonist')
        if col and col.drafted then
            canMove = true
        end
    end

    if canMove then
        local World = require('src.world.tilemap')
        local mvd = GameState.viewDepth or 0
        if World.isWalkable(tx, ty, mvd) then
            local Pathfind = require('src.util.pathfind')
            local targets = {}
            local count = 0
            for _ in pairs(GameState.selectedEntities) do count = count + 1 end
            if count <= 1 then
                targets[1] = { x = tx, y = ty }
            else
                targets[1] = { x = tx, y = ty }
                local spread = { {0,0},{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1} }
                for i = 2, count do
                    local s = spread[i] or spread[1]
                    local sx, sy = tx + s[1], ty + s[2]
                    if World.inBounds(sx, sy) and World.isWalkable(sx, sy, mvd) then
                        targets[i] = { x = sx, y = sy }
                    else
                        targets[i] = { x = tx, y = ty }
                    end
                end
            end
            local ti = 1
            for id in pairs(GameState.selectedEntities) do
                if ECS.has(id, 'colonist') and ECS.has(id, 'path') then
                    local pos = ECS.get(id, 'pos')
                    local tgt = targets[ti] or targets[1]
                    ti = ti + 1
                    local route = Pathfind.find(pos.x, pos.y, tgt.x, tgt.y, World, id, pos.depth or 0, mvd)
                    if route then
                        local path = ECS.get(id, 'path')
                        path.nodes = route
                        path.index = 1
                        path.moveTimer = 0
                    end
                end
            end
        end
    else
        -- Undrafted colonist selected (or no colonist): open tile context menu
        if actingColonistId then
            UI.openContextMenu(x, y, nil, 'tile', actingColonistId, tx, ty, vd)
        end
    end
end

function Input.mousereleased(x, y, button)
    if button == 3 then
        Camera.stopDrag()
        return
    end


    if button == 1 and selectionBox then
        selectionBox.x2 = x
        selectionBox.y2 = y

        local wx1, wy1 = Camera.screenToWorld(
            math.min(selectionBox.x1, selectionBox.x2),
            math.min(selectionBox.y1, selectionBox.y2)
        )
        local wx2, wy2 = Camera.screenToWorld(
            math.max(selectionBox.x1, selectionBox.x2),
            math.max(selectionBox.y1, selectionBox.y2)
        )

        local ts = 32
        local tx1 = math.floor(wx1 / ts)
        local ty1 = math.floor(wy1 / ts)
        local tx2 = math.floor(wx2 / ts)
        local ty2 = math.floor(wy2 / ts)

        local vd = GameState.viewDepth or 0

        -- Deconstruct designation mode
        if selectionBox.mode == 'deconstruct' then
            local Building = require('src.building.building')
            local marked = {}
            for eid, comps in ECS.query('building_ref', 'pos') do
                local bpos = comps.pos
                if (bpos.depth or 0) == vd then
                    local def = Building.defs[comps.building_ref.defId]
                    local bw = def and def.w or 1
                    local bh = def and def.h or 1
                    -- Check if any tile of this building is inside the drag area
                    for dy = 0, bh - 1 do
                        for dx = 0, bw - 1 do
                            local bx, by = bpos.x + dx, bpos.y + dy
                            if bx >= tx1 and bx <= tx2 and by >= ty1 and by <= ty2
                                and not marked[eid] then
                                marked[eid] = true
                                Jobs.designateDeconstruct(eid, bpos.x, bpos.y, vd)
                            end
                        end
                    end
                end
            end
            selectionBox = nil
            return
        end

        -- Mine designation mode
        if selectionBox.mode == 'mine' then
            local World = require('src.world.tilemap')
            local count = 0
            for ty = ty1, ty2 do
                for tx = tx1, tx2 do
                    if World.inBounds(tx, ty) then
                        local taskId = Jobs.designateMine(tx, ty, vd)
                        if taskId then count = count + 1 end
                    end
                end
            end
            selectionBox = nil
            return
        end

        -- Terraform designation mode (stair/channel/ramp/shaft)
        if selectionBox.mode == 'terraform' and selectionBox.opId then
            local World = require('src.world.tilemap')
            local opId = selectionBox.opId
            local count = 0
            for ty = ty1, ty2 do
                for tx = tx1, tx2 do
                    if World.inBounds(tx, ty) then
                        local taskId = Jobs.designateTerraform(tx, ty, opId, vd)
                        if taskId then count = count + 1 end
                    end
                end
            end
            selectionBox = nil
            return
        end

        -- Forage designation mode
        if selectionBox.mode == 'forage' then
            local World = require('src.world.tilemap')
            local Foraging = require('src.colonist.foraging')
            local count = 0
            for ty = ty1, ty2 do
                for tx = tx1, tx2 do
                    if World.inBounds(tx, ty) then
                        local taskId = Foraging.designateForage(tx, ty, vd)
                        if taskId then count = count + 1 end
                    end
                end
            end
            selectionBox = nil
            return
        end

        -- Zone drawing mode
        if selectionBox.mode == 'zone_stockpile'
            or selectionBox.mode == 'zone_dumping'
            or selectionBox.mode == 'zone_restricted' then
            local World = require('src.world.tilemap')
            local Tiles = require('src.world.tiles')
            local zoneType = 'restricted'
            if selectionBox.mode == 'zone_stockpile' then
                zoneType = 'stockpile'
            elseif selectionBox.mode == 'zone_dumping' then
                zoneType = 'dumping'
            end
            local tiles = {}
            for ty = ty1, ty2 do
                for tx = tx1, tx2 do
                    if World.inBounds(tx, ty) and World.isWalkable(tx, ty, vd) then
                        tiles[#tiles + 1] = { x = tx, y = ty, depth = vd }
                    end
                end
            end
            if #tiles > 0 then
                GameState.selectedZoneId = Zones.create(zoneType, tiles)
                GameState.selectedEntities = {}
            end
            selectionBox = nil
            return
        end

        -- Build line mode: place belt/pipe/inserter along a straight line
        if selectionBox.mode == 'build_line' and GameState.buildGhost then
            local Building = require('src.building.building')
            local def = Building.defs[GameState.buildGhost.id]
            if def then
                local World = require('src.world.tilemap')
                local Tiles = require('src.world.tiles')
                local startTx, startTy = Camera.screenToTile(selectionBox.x1, selectionBox.y1)
                local endTx, endTy = Camera.screenToTile(selectionBox.x2, selectionBox.y2)
                local ddx = endTx - startTx
                local ddy = endTy - startTy

                -- Determine line direction (straight: pick dominant axis)
                local stepX, stepY = 0, 0
                if math.abs(ddx) >= math.abs(ddy) then
                    stepX = ddx > 0 and 1 or (ddx < 0 and -1 or 0)
                else
                    stepY = ddy > 0 and 1 or (ddy < 0 and -1 or 0)
                end

                -- Auto-set build direction from drag for conveyors/splitters
                local es = def.entitySpawn
                if (es == 'conveyor' or es == 'splitter') and (stepX ~= 0 or stepY ~= 0) then
                    if stepX == 1 then GameState.buildDirection = 'right'
                    elseif stepX == -1 then GameState.buildDirection = 'left'
                    elseif stepY == 1 then GameState.buildDirection = 'down'
                    elseif stepY == -1 then GameState.buildDirection = 'up' end
                end

                -- Walk the line and place
                local lineLen = math.max(math.abs(ddx), math.abs(ddy))
                for i = 0, lineLen do
                    local px = startTx + stepX * i
                    local py = startTy + stepY * i
                    if World.inBounds(px, py) and Tiles.isBuildable(World.getTile(px, py, vd)) then
                        local canAfford = true
                        if def.cost then
                            for res, amount in pairs(def.cost) do
                                if (GameState.resources[res] or 0) < amount then
                                    canAfford = false
                                    break
                                end
                            end
                        end
                        if canAfford then
                            Jobs.designateBuild(px, py, GameState.buildGhost.id, vd)
                        end
                    end
                end
            end
            selectionBox = nil
            return
        end

        -- Normal entity selection
        if not love.keyboard.isDown('lshift') then
            GameState.selectedEntities = {}
            GameState.selectedZoneId = nil
        end

        local isDrag = math.abs(selectionBox.x2 - selectionBox.x1) > 4 or
                       math.abs(selectionBox.y2 - selectionBox.y1) > 4

        if isDrag then
            for id, comps in ECS.query('pos', 'colonist') do
                local pos = comps.pos
                if (pos.depth or 0) == vd
                    and pos.x >= tx1 and pos.x <= tx2
                    and pos.y >= ty1 and pos.y <= ty2 then
                    GameState.selectedEntities[id] = true
                end
            end
        else
            -- Single click: pick the nearest colonist within 0.75 tiles of
            -- the click, using the RENDERED (interpolated) position. Sprites
            -- are drawn between prevX/Y and x/y, so an exact-tile test made
            -- moving colonists nearly impossible to click.
            local clickTX = wx1 / ts
            local clickTY = wy1 / ts
            local a = GameState.alpha or 0
            local bestId, bestDist = nil, 0.75
            for id, comps in ECS.query('pos', 'colonist') do
                local pos = comps.pos
                if (pos.depth or 0) == vd then
                    local px = pos.prevX or pos.x
                    local py = pos.prevY or pos.y
                    local ix = px + (pos.x - px) * a + 0.5
                    local iy = py + (pos.y - py) * a + 0.5
                    local dxT = ix - clickTX
                    local dyT = iy - clickTY
                    local d = math.sqrt(dxT * dxT + dyT * dyT)
                    if d < bestDist then
                        bestDist = d
                        bestId = id
                    end
                end
            end
            if bestId then
                GameState.selectedEntities[bestId] = true
            end
        end

        -- Prisoner selection (single click only — prisoners are individuals)
        if not isDrag and not next(GameState.selectedEntities) then
            for id, comps in ECS.query('pos', 'prisoner') do
                local pos = comps.pos
                if (pos.depth or 0) == vd and pos.x == tx1 and pos.y == ty1 then
                    GameState.selectedEntities[id] = true
                    break
                end
            end
        end

        -- Single click on empty tile: check for buildings (multi-tile footprint)
        if not isDrag and not next(GameState.selectedEntities) then
            local bok, Building = pcall(require, 'src.building.building')
            if bok then
                for id, comps in ECS.query('pos', 'building_ref') do
                    local pos = comps.pos
                    local def = Building.defs[comps.building_ref.defId]
                    local bw = def and def.w or 1
                    local bh = def and def.h or 1
                    if (pos.depth or 0) == vd
                       and tx1 >= pos.x and tx1 < pos.x + bw
                       and ty1 >= pos.y and ty1 < pos.y + bh then
                        GameState.selectedEntities[id] = true
                        GameState.selectedZoneId = nil
                        break
                    end
                end
            end
        end

        if not isDrag and not next(GameState.selectedEntities) then
            for id, comps in ECS.query('pos', 'artifact') do
                local pos = comps.pos
                if (pos.depth or 0) == vd and pos.x == tx1 and pos.y == ty1 then
                    GameState.selectedEntities[id] = true
                    GameState.selectedZoneId = nil
                    break
                end
            end
        end

        if not isDrag and not next(GameState.selectedEntities) then
            for id, comps in ECS.query('pos', 'inserter') do
                local pos = comps.pos
                if (pos.depth or 0) == vd and pos.x == tx1 and pos.y == ty1 then
                    GameState.selectedEntities[id] = true
                    GameState.selectedZoneId = nil
                    break
                end
            end
        end

        if not isDrag and not next(GameState.selectedEntities) then
            for id, comps in ECS.query('pos', 'laser_fence') do
                local pos = comps.pos
                if (pos.depth or 0) == vd and pos.x == tx1 and pos.y == ty1 then
                    GameState.selectedEntities[id] = true
                    GameState.selectedZoneId = nil
                    break
                end
            end
        end

        if not isDrag and not next(GameState.selectedEntities) then
            local zone = Zones.getZoneAt(tx1, ty1, vd)
            GameState.selectedZoneId = zone and zone.id or nil
        end

        selectionBox = nil
    end
end

function Input.getSelectionBox()
    if not selectionBox then return nil end
    if not love.mouse.isDown(1) then return nil end
    local mx, my = love.mouse.getPosition()
    return {
        x = math.min(selectionBox.x1, mx),
        y = math.min(selectionBox.y1, my),
        w = math.abs(mx - selectionBox.x1),
        h = math.abs(my - selectionBox.y1),
    }
end

return Input
