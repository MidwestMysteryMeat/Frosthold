-- ui_context.lua — Right-click context menu: open, draw, execute actions

local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')

local Context = {}

-- Context menu state
local contextMenu = nil  -- { x, y, targetId, targetType, options }

-- Shared screen dimensions (set from coordinator)
local screenW, screenH = 1280, 720

function Context.resize(w, h)
    screenW = w
    screenH = h
end

function Context.init()
    contextMenu = nil
end

function Context.isOpen()
    return contextMenu ~= nil
end

function Context.close()
    contextMenu = nil
end

---------------------------------------------------------------------------
-- Open context menu (right-click on entity)
---------------------------------------------------------------------------

function Context.open(sx, sy, targetId, targetType, actingColonistId, tileX, tileY, tileDepth)
    local options = {}

    if targetType == 'colonist' then
        local col = ECS.get(targetId, 'colonist')
        if not col or col.state == 'dead' then return end

        -- Treat wounds
        local wok, Wounds = pcall(require, 'src.combat.wounds')
        if wok and Wounds.hasUntreatedWounds and Wounds.hasUntreatedWounds(targetId) then
            options[#options + 1] = {
                label = 'Prioritize Treatment',
                action = 'treat_wounds',
                enabled = true,
            }
        end

        -- Treat disease
        local disease = ECS.get(targetId, 'disease')
        if disease and disease.id then
            options[#options + 1] = {
                label = 'Treat Disease: ' .. disease.id,
                action = 'treat_disease',
                enabled = true,
            }
        end

        -- Medical panel shortcut
        options[#options + 1] = {
            label = 'Medical Overview',
            action = 'open_medical',
            enabled = true,
        }

        -- Draft toggle
        options[#options + 1] = {
            label = col.drafted and 'Undraft' or 'Draft',
            action = 'toggle_draft',
            enabled = true,
        }

    elseif targetType == 'corpse' then
        local item = ECS.get(targetId, 'item')
        if not item then return end

        local hasSerum = (GameState.resources.revivify_serum or 0) >= 1
        local resOk, Research = pcall(require, 'src.research.research')
        local researched = resOk and Research.isCompleted('revival_biochem')

        local reason = ''
        local enabled = true
        if not researched then
            reason = ' (not researched)'
            enabled = false
        elseif not hasSerum then
            reason = ' (no serum)'
            enabled = false
        end

        options[#options + 1] = {
            label = 'Revive' .. reason,
            action = 'revive',
            enabled = enabled,
        }

        -- Show stored identity if available
        if item._colonistName then
            options[#options + 1] = {
                label = 'Corpse: ' .. item._colonistName,
                action = nil,
                enabled = false,
            }
        end

    elseif targetType == 'creature' then
        local cr = ECS.get(targetId, 'creature')
        if not cr or cr.state == 'dead' then return end

        options[#options + 1] = {
            label = 'Hunt',
            action = 'hunt',
            enabled = true,
        }

        -- Show creature name/species
        local speciesName = cr.species or cr.name or 'Unknown'
        options[#options + 1] = {
            label = speciesName,
            action = nil,
            enabled = false,
        }

    elseif targetType == 'building' then
        local bref = ECS.get(targetId, 'building_ref')
        if not bref then return end

        -- Select building
        options[#options + 1] = {
            label = 'Inspect',
            action = 'inspect_building',
            enabled = true,
        }

        -- Shipyard: add dedicated management option
        local machCheck = ECS.get(targetId, 'machine')
        if machCheck and machCheck.type == 'shipyard' then
            options[#options + 1] = {
                label = 'Manage Shipyard',
                action = 'open_shipyard',
                enabled = true,
            }
        end

        -- Prioritize repair if damaged
        local dok, Deterioration = pcall(require, 'src.sim.deterioration')
        if dok then
            local cur, mx = Deterioration.getDurability(targetId)
            if cur and mx and cur < mx then
                options[#options + 1] = {
                    label = string.format('Prioritize Repair (%.0f/%.0f)', cur, mx),
                    action = 'repair_building',
                    enabled = true,
                }
            end
        end

        -- Deconstruct
        options[#options + 1] = {
            label = 'Deconstruct',
            action = 'deconstruct',
            enabled = true,
        }

    elseif targetType == 'item' then
        local item = ECS.get(targetId, 'item')
        if not item then return end

        local itemName = item.name or item.itemId or 'Item'
        options[#options + 1] = {
            label = 'Haul: ' .. itemName,
            action = 'haul_item',
            enabled = true,
        }

    elseif targetType == 'tile' then
        -- Empty tile with force options (mine, chop)
        local World = require('src.world.tilemap')
        local Tiles = require('src.world.tiles')
        local tile = World.getTile(tileX, tileY, tileDepth or 0)
        if tile == Tiles.TREE then
            options[#options + 1] = {
                label = 'Force Chop',
                action = 'force_chop',
                enabled = actingColonistId ~= nil,
            }
        elseif tile == Tiles.ROCK or tile == Tiles.ICE or tile == Tiles.ORE_VEIN
               or tile == Tiles.DEEP_ROCK or tile == Tiles.UNDERGROUND_ROCK then
            options[#options + 1] = {
                label = 'Force Mine',
                action = 'force_mine',
                enabled = actingColonistId ~= nil,
            }
        end
    end

    -- Force-task options when a colonist is selected and right-clicking an entity
    if actingColonistId and targetType ~= 'colonist' and targetType ~= 'tile' then
        local acol = ECS.get(actingColonistId, 'colonist')
        local acolName = acol and acol.name or 'Colonist'
        local shortName = #acolName > 10 and acolName:sub(1, 9) .. '.' or acolName

        if targetType == 'creature' then
            options[#options + 1] = {
                label = shortName .. ': Force Attack',
                action = 'force_attack',
                enabled = true,
            }
        end

        if targetType == 'item' then
            local item = ECS.get(targetId, 'item')
            if item then
                -- Check if it's food
                local pok, ProdMod = pcall(require, 'src.building.production')
                local isFood = pok and ProdMod.FOOD_QUALITY and ProdMod.FOOD_QUALITY[item.itemId]
                if isFood then
                    options[#options + 1] = {
                        label = shortName .. ': Force Eat',
                        action = 'force_eat',
                        enabled = true,
                    }
                end
                options[#options + 1] = {
                    label = shortName .. ': Force Haul',
                    action = 'force_haul',
                    enabled = true,
                }
            end
        end

        if targetType == 'building' then
            -- Check for machine to operate
            local mach = ECS.get(targetId, 'machine')
            if mach and mach.recipe then
                options[#options + 1] = {
                    label = shortName .. ': Force Operate',
                    action = 'force_operate',
                    enabled = true,
                }
            end
        end
    end

    if #options == 0 then return end

    contextMenu = {
        x = sx,
        y = sy,
        targetId = targetId,
        targetType = targetType,
        actingColonistId = actingColonistId,
        tileX = tileX,
        tileY = tileY,
        tileDepth = tileDepth,
        options = options,
    }
end

---------------------------------------------------------------------------
-- Draw context menu
---------------------------------------------------------------------------

function Context.draw()
    if not contextMenu then return end

    local font = love.graphics.getFont()
    local itemH = 24
    local padX = 12
    local padY = 6

    -- Measure width
    local maxW = 0
    for _, opt in ipairs(contextMenu.options) do
        local w = font:getWidth(opt.label)
        if w > maxW then maxW = w end
    end
    local menuW = maxW + padX * 2
    local menuH = #contextMenu.options * itemH + padY * 2

    -- Keep on screen
    local mx = contextMenu.x
    local my = contextMenu.y
    if mx + menuW > screenW then mx = screenW - menuW end
    if my + menuH > screenH then my = screenH - menuH end

    -- Background
    love.graphics.setColor(0.08, 0.08, 0.1, 0.95)
    love.graphics.rectangle('fill', mx, my, menuW, menuH, 4, 4)
    love.graphics.setColor(0.35, 0.4, 0.5, 0.8)
    love.graphics.rectangle('line', mx, my, menuW, menuH, 4, 4)

    -- Options
    local mouseX, mouseY = love.mouse.getPosition()
    for i, opt in ipairs(contextMenu.options) do
        local oy = my + padY + (i - 1) * itemH

        -- Hover highlight
        local hovered = mouseX >= mx and mouseX <= mx + menuW
                    and mouseY >= oy and mouseY <= oy + itemH
        if hovered and opt.enabled then
            love.graphics.setColor(0.2, 0.25, 0.35, 0.8)
            love.graphics.rectangle('fill', mx + 2, oy, menuW - 4, itemH, 2, 2)
        end

        -- Text
        if opt.enabled then
            love.graphics.setColor(0.9, 0.9, 0.9)
        else
            love.graphics.setColor(0.45, 0.45, 0.45)
        end
        love.graphics.print(opt.label, mx + padX, oy + 4)
    end
end

---------------------------------------------------------------------------
-- Execute context menu action
---------------------------------------------------------------------------

function Context.executeAction(action, targetId, targetType, actingColonistId, tileX, tileY, tileDepth)
    local Jobs = require('src.colonist.jobs')

    -- Force-task actions (use actingColonistId, not targetId)
    if action == 'force_mine' or action == 'force_chop' then
        if actingColonistId and tileX and tileY then
            local World = require('src.world.tilemap')
            local tile = World.getTile(tileX, tileY, tileDepth or 0)
            Jobs.forceAssign(actingColonistId, 'mine', tileX, tileY, {
                tile = tile, depth = tileDepth or 0,
            })
        end
        return
    end

    if action == 'force_attack' then
        if actingColonistId and targetId and ECS.isAlive(targetId) then
            local hok, Hunting = pcall(require, 'src.combat.hunting')
            if hok and Hunting.designate then
                Hunting.designate(targetId)
            end
        end
        return
    end

    if action == 'force_eat' then
        if actingColonistId and targetId and ECS.isAlive(targetId) then
            local col = ECS.get(actingColonistId, 'colonist')
            local targetPos = ECS.get(targetId, 'pos')
            local item = ECS.get(targetId, 'item')
            if col and targetPos and item then
                -- Cancel current task
                if col.task then
                    Jobs.unclaimTask(col.task.taskId)
                    col.task = nil
                end
                -- Use the eat state machine
                col._eatTarget = {
                    source = 'ground',
                    entityId = targetId,
                    itemId = item.itemId,
                    x = targetPos.x,
                    y = targetPos.y,
                    depth = targetPos.depth or 0,
                }
                col.state = 'moving_to_food'
                -- Pathfind
                local pos = ECS.get(actingColonistId, 'pos')
                local path = ECS.get(actingColonistId, 'path')
                if pos and path then
                    local World = require('src.world.tilemap')
                    local Pathfind = require('src.util.pathfind')
                    local route = Pathfind.find(pos.x, pos.y, targetPos.x, targetPos.y,
                        World, actingColonistId, pos.depth or 0, targetPos.depth or 0)
                    if route then
                        path.nodes = route
                        path.index = 1
                        path.moveTimer = 0
                    end
                end
            end
        end
        return
    end

    if action == 'force_haul' then
        if actingColonistId and targetId and ECS.isAlive(targetId) then
            local targetPos = ECS.get(targetId, 'pos')
            local item = ECS.get(targetId, 'item')
            if targetPos and item then
                Jobs.forceAssign(actingColonistId, 'haul', targetPos.x, targetPos.y, {
                    itemEntityId = targetId,
                    itemId = item.itemId,
                    depth = targetPos.depth or 0,
                })
            end
        end
        return
    end

    if action == 'force_operate' then
        if actingColonistId and targetId and ECS.isAlive(targetId) then
            local targetPos = ECS.get(targetId, 'pos')
            local mach = ECS.get(targetId, 'machine')
            if targetPos and mach then
                local COOKING_MACHINES = { kitchen = true, smokehouse = true }
                local taskType = COOKING_MACHINES[mach.type] and 'cook' or 'operate'
                Jobs.forceAssign(actingColonistId, taskType, targetPos.x, targetPos.y, {
                    machineEntityId = targetId,
                    depth = targetPos.depth or 0,
                })
            end
        end
        return
    end

    if not targetId or not ECS.isAlive(targetId) then return end

    if action == 'toggle_draft' then
        local col = ECS.get(targetId, 'colonist')
        if col then
            col.drafted = not col.drafted
            if not col.drafted then col.state = 'idle' end
        end
        return
    end

    if action == 'treat_wounds' then
        local wok, Wounds = pcall(require, 'src.combat.wounds')
        if wok and Wounds.requestMedicalTask then
            Wounds.requestMedicalTask(targetId)
        end

    elseif action == 'treat_disease' then
        local pos = ECS.get(targetId, 'pos')
        if pos then
            Jobs.createTask('medical', pos.x, pos.y, {
                patientId = targetId, diseaseTask = true,
            })
        end

    elseif action == 'open_medical' then
        local mok, MedPanel = pcall(require, 'src.ui.medical_panel')
        if mok then
            if not MedPanel.isVisible() then MedPanel.toggle() end
        end

    elseif action == 'revive' then
        local pos = ECS.get(targetId, 'pos')
        if pos then
            Jobs.createTask('revive', pos.x, pos.y, {
                corpseEntityId = targetId,
            })
        end

    elseif action == 'hunt' then
        local hok, Hunting = pcall(require, 'src.combat.hunting')
        if hok and Hunting.designate then
            Hunting.designate(targetId)
        end

    elseif action == 'inspect_building' then
        -- Open shipyard panel if this is a shipyard building
        local mach = ECS.get(targetId, 'machine')
        if mach and mach.type == 'shipyard' then
            local spOk, ShipyardPanel = pcall(require, 'src.ui.shipyard_panel')
            if spOk and ShipyardPanel.open then
                ShipyardPanel.open(targetId)
                contextMenu = nil
                return
            end
        end
        GameState.selectedEntities = { [targetId] = true }

    elseif action == 'open_shipyard' then
        local spOk, ShipyardPanel = pcall(require, 'src.ui.shipyard_panel')
        if spOk and ShipyardPanel.open then
            ShipyardPanel.open(targetId)
        end

    elseif action == 'repair_building' then
        local pos = ECS.get(targetId, 'pos')
        if pos then
            Jobs.createTask('repair_building', pos.x, pos.y, {
                entityId = targetId,
                depth = pos.depth or 0,
            })
        end

    elseif action == 'deconstruct' then
        local bref = ECS.get(targetId, 'building_ref')
        local pos = ECS.get(targetId, 'pos')
        if bref and pos then
            local bok2, Building = pcall(require, 'src.building.building')
            if bok2 and Building.remove then
                Building.remove(pos.x, pos.y, pos.depth or 0)
            end
        end

    elseif action == 'haul_item' then
        local pos = ECS.get(targetId, 'pos')
        if pos then
            local item = ECS.get(targetId, 'item')
            if item then
                Jobs.createTask('haul', pos.x, pos.y, {
                    itemEntityId = targetId,
                    itemId = item.itemId,
                })
            end
        end
    end
end

---------------------------------------------------------------------------
-- Input: click handling for context menu
---------------------------------------------------------------------------

function Context.mousepressed(x, y, button, playClick)
    if not contextMenu then return false end

    if button == 1 then
        local font = love.graphics.getFont()
        local itemH = 24
        local padX = 12
        local padY = 6

        local maxW = 0
        for _, opt in ipairs(contextMenu.options) do
            local w = font:getWidth(opt.label)
            if w > maxW then maxW = w end
        end
        local menuW = maxW + padX * 2
        local menuH = #contextMenu.options * itemH + padY * 2

        local mx = contextMenu.x
        local my = contextMenu.y
        if mx + menuW > screenW then mx = screenW - menuW end
        if my + menuH > screenH then my = screenH - menuH end

        -- Check if click is inside menu
        if x >= mx and x <= mx + menuW and y >= my and y <= my + menuH then
            local idx = math.floor((y - my - padY) / itemH) + 1
            local opt = contextMenu.options[idx]
            if opt and opt.enabled and opt.action then
                playClick()
                Context.executeAction(opt.action, contextMenu.targetId, contextMenu.targetType,
                    contextMenu.actingColonistId, contextMenu.tileX, contextMenu.tileY, contextMenu.tileDepth)
            end
            contextMenu = nil
            return true
        end
    end
    -- Any click outside or right-click closes context menu
    contextMenu = nil
    return true
end

function Context.keypressed(key)
    if contextMenu and key == 'escape' then
        contextMenu = nil
        return true
    end
    return false
end

return Context
