-- ui.lua — UI coordinator: delegates to sub-modules for HUD, selection, context, overlays, menus

local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')
local Input     = require('src.ui.input')
local BuildMenu = require('src.ui.build_menu')
local HUD       = require('src.ui.ui_hud')
local Selection = require('src.ui.ui_selection')
local Context   = require('src.ui.ui_context')
local Overlays  = require('src.ui.ui_overlays')
local Menus     = require('src.ui.ui_menus')
local sok_snd, Sound = pcall(require, 'src.audio.sound')
local function playClick() if sok_snd then Sound.play('click') end end

local UI = {}

local screenW, screenH = 1280, 720

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function UI.init()
    Selection.init()
    Context.init()
    Overlays.init()
    Menus.init()
end

function UI.update(dt)
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function UI.draw()
    love.graphics.setColor(1, 1, 1, 1)

    HUD.drawResourceBar()
    HUD.drawTimeBar()
    HUD.drawAlerts()
    -- Letter stack (right side)
    do
        local aOk, AlertsMod = pcall(require, 'src.ui.alerts')
        if aOk then AlertsMod.draw() end
    end
    HUD.drawColonistBar()
    if GameState.buildMode then
        BuildMenu.draw()
    else
        Selection.drawSelectionPanel()
    end
    HUD.drawSelectionBox()
    if not GameState.buildMode then
        HUD.drawToolbar()
    end

    HUD.drawTileTooltip(Context.isOpen(), Menus.getMenuStackLen())
    HUD.drawColonistBarTooltip(Context.isOpen(), Menus.getMenuStackLen())
    HUD.drawResourceTooltip()
    Overlays.drawEventLog()
    Overlays.drawTaskQueue()
    Overlays.drawHotkeyHelp()

    if Context.isOpen() then
        Context.draw()
    end

    if Menus.isMenuOpen() then
        Menus.drawMenu()
    end

    -- Save toast (always visible regardless of menu state)
    Menus.drawSaveToast()
end

---------------------------------------------------------------------------
-- Hit testing utility
---------------------------------------------------------------------------

local function hitTest(mx, my, rect)
    return mx >= rect.x and mx <= rect.x + rect.w
       and my >= rect.y and my <= rect.y + rect.h
end

local function cycleChoice(choices, currentId, dir)
    local index = 1
    for i, choice in ipairs(choices) do
        if choice.id == currentId then
            index = i
            break
        end
    end
    index = index + (dir or 1)
    if index < 1 then index = #choices end
    if index > #choices then index = 1 end
    return choices[index]
end

local function getSingleKey(filterTable)
    if not filterTable then return nil end
    for key in pairs(filterTable) do
        return key
    end
    return nil
end

local function getItemChoices()
    local ok, Production = pcall(require, 'src.building.production')
    if not ok or not Production.ITEMS then return { { id = nil, name = 'Any Item' } } end
    local choices = { { id = nil, name = 'Any Item' } }
    for itemId, def in pairs(Production.ITEMS) do
        choices[#choices + 1] = { id = itemId, name = def.name or itemId }
    end
    table.sort(choices, function(a, b)
        if a.id == nil then return true end
        if b.id == nil then return false end
        return a.name < b.name
    end)
    return choices
end

local function getMaterialChoices()
    local ok, Materials = pcall(require, 'src.world.materials')
    if not ok or not Materials.DEFS then return { { id = nil, name = 'Any Material' } } end
    local choices = { { id = nil, name = 'Any Material' } }
    for materialId, def in pairs(Materials.DEFS) do
        choices[#choices + 1] = { id = materialId, name = def.name or materialId }
    end
    table.sort(choices, function(a, b)
        if a.id == nil then return true end
        if b.id == nil then return false end
        return a.name < b.name
    end)
    return choices
end

local function getQualityChoices()
    local ok, Quality = pcall(require, 'src.world.quality')
    if not ok or not Quality.TIERS then return { { id = nil, name = 'Any Quality' } } end
    local choices = { { id = nil, name = 'Any Quality' } }
    for _, tier in ipairs(Quality.TIERS) do
        choices[#choices + 1] = { id = tier.id, name = tier.name }
    end
    return choices
end

---------------------------------------------------------------------------
-- Input handlers
---------------------------------------------------------------------------

function UI.keypressed(key)
    if Context.keypressed(key) then return true end
    if BuildMenu.keypressed and BuildMenu.keypressed(key) then return true end
end

function UI.textinput(text)
    if BuildMenu.textinput and BuildMenu.textinput(text) then return true end
    return false
end

function UI.mousepressed(x, y, button)
    -- Menu handling (consumes all clicks when open)
    if Menus.mousepressed(x, y, button, playClick) then
        return true
    end

    -- Context menu handling
    if Context.mousepressed(x, y, button, playClick) then
        return true
    end

    if button == 1 then
        -- Clickable alerts (camera jump)
        local Camera = require('src.render.camera')
        for _, zone in ipairs(HUD.getAlertHitZones()) do
            if hitTest(x, y, zone) then
                playClick()
                Camera.centerOn(zone.jumpX, zone.jumpY)
                return true
            end
        end

        -- Letter stack clicks
        do
            local aOk, AlertsMod = pcall(require, 'src.ui.alerts')
            if aOk and AlertsMod.mousepressed(x, y, 1) then
                playClick()
                return true
            end
        end

        -- Speed buttons
        for _, btn in ipairs(HUD.getSpeedBtns()) do
            if hitTest(x, y, btn) then
                playClick()
                GameState.speed = btn.speed
                GameState.paused = false
                return true
            end
        end

        -- Pause button
        local pauseBtn = HUD.getPauseBtn()
        if pauseBtn and hitTest(x, y, pauseBtn) then
            playClick()
            GameState.paused = not GameState.paused
            return true
        end

        -- Colonist cards
        for _, card in ipairs(HUD.getColonistCards()) do
            if hitTest(x, y, card) then
                playClick()
                if not love.keyboard.isDown('lshift') then
                    GameState.selectedEntities = {}
                    GameState.selectedZoneId = nil
                end
                GameState.selectedEntities[card.id] = true
                return true
            end
        end

        -- Tab buttons
        for _, btn in ipairs(Selection.getTabBtns()) do
            if hitTest(x, y, btn) then
                playClick()
                Selection.setSelectedTab(btn.tab)
                return true
            end
        end

        -- Work priority cells (click cycles, starts drag for painting)
        for _, cell in ipairs(Selection.getWorkCells()) do
            if hitTest(x, y, cell) then
                playClick()
                local wp = ECS.get(cell.id, 'workPriority')
                if wp then
                    local cur = wp[cell.col] or 0
                    local newVal = (cur + 1) % 5
                    wp[cell.col] = newVal
                    Selection.setDragWork({ value = newVal })
                end
                return true
            end
        end

        -- Schedule cells (cycle block type)
        for _, cell in ipairs(Selection.getScheduleCells()) do
            if hitTest(x, y, cell) then
                playClick()
                if not ECS.isAlive(cell.entityId) then return true end
                local sched = ECS.get(cell.entityId, 'schedule')
                if sched then
                    local order = {'work', 'eat', 'sleep', 'free'}
                    local cur = sched[cell.hour] or 'work'
                    local idx = 1
                    for i, b in ipairs(order) do
                        if b == cur then idx = i break end
                    end
                    sched[cell.hour] = order[(idx % #order) + 1]
                end
                return true
            end
        end

        -- Gear auto-equip button
        local gearAutoBtn = Selection.getGearAutoBtn()
        if gearAutoBtn and hitTest(x, y, gearAutoBtn) then
            playClick()
            local eok, Equipment = pcall(require, 'src.colonist.equipment')
            if eok and Equipment.autoEquip and ECS.isAlive(gearAutoBtn.entityId) then
                Equipment.autoEquip(gearAutoBtn.entityId)
            end
            return true
        end

        -- Endgame building action button
        local endgameActionBtn = Selection.getEndgameActionBtn()
        if endgameActionBtn and hitTest(x, y, endgameActionBtn) then
            playClick()
            local eok, EndgameMod = pcall(require, 'src.sim.endgame')
            if eok then
                if endgameActionBtn.action == 'start' then
                    EndgameMod.startCharging(endgameActionBtn.entityId)
                elseif endgameActionBtn.action == 'activate' then
                    EndgameMod.activate(endgameActionBtn.entityId)
                end
            end
            return true
        end

        for _, btn in ipairs(Selection.getInteractionBtns()) do
            if hitTest(x, y, btn) then
                playClick()
                if btn.kind == 'containment' then
                    local cok, Containment = pcall(require, 'src.sim.containment')
                    if cok and Containment.performAction then
                        local ok, detail = Containment.performAction(btn.entityId, btn.action)
                        if not ok and detail then
                            UI.showSaveToast(detail)
                        end
                    end
                elseif btn.kind == 'artifact' then
                    local mok, MapSecrets = pcall(require, 'src.world.map_secrets')
                    if mok and MapSecrets.activate then
                        local ok, detail = MapSecrets.activate(btn.entityId)
                        if not ok and detail then
                            UI.showSaveToast(detail)
                        end
                    end
                elseif btn.kind == 'zone' then
                    local Zones = require('src.world.zones')
                    local zone = Zones.getAll()[btn.entityId]
                    local data = btn.data or {}
                    if zone then
                        if btn.action == 'adjust_priority' then
                            Zones.cyclePriority(btn.entityId, data.delta or 0)
                        elseif btn.action == 'toggle_category' and data.category then
                            Zones.toggleCategory(btn.entityId, data.category)
                        elseif btn.action == 'clear_filters' then
                            Zones.clearFilters(btn.entityId)
                        elseif btn.action == 'delete_zone' then
                            Zones.delete(btn.entityId)
                            if GameState.selectedZoneId == btn.entityId then
                                GameState.selectedZoneId = nil
                            end
                        elseif btn.action == 'cycle_item' then
                            local nextChoice = cycleChoice(getItemChoices(), getSingleKey(zone.itemFilter), (data.dir or 1))
                            Zones.setSingleItemFilter(btn.entityId, nextChoice.id)
                        elseif btn.action == 'cycle_quality' then
                            local nextChoice = cycleChoice(getQualityChoices(), zone.qualityMin, 1)
                            Zones.setQualityRange(btn.entityId, nextChoice.id, nil)
                        elseif btn.action == 'cycle_material' then
                            local nextChoice = cycleChoice(getMaterialChoices(), getSingleKey(zone.materialFilter), 1)
                            Zones.setSingleMaterialFilter(btn.entityId, nextChoice.id)
                        end
                    end
                elseif btn.kind == 'machine' then
                    local machine = ECS.get(btn.entityId, 'machine')
                    if machine then
                        local pok, Production = pcall(require, 'src.building.production')
                        local wok, WorkOrders = pcall(require, 'src.building.work_orders')
                        local recipes = pok and Production.getRecipesForMachine and Production.getRecipesForMachine(machine.type) or {}
                        table.sort(recipes, function(a, b)
                            return (a.recipe.name or a.id) < (b.recipe.name or b.id)
                        end)
                        machine._uiRecipeIndex = math.max(1, math.min(math.max(#recipes, 1), machine._uiRecipeIndex or 1))
                        local bills = wok and WorkOrders.getBills(btn.entityId) or {}
                        machine._uiBillIndex = math.max(1, math.min(math.max(#bills, 1), machine._uiBillIndex or 1))
                        local bill = bills[machine._uiBillIndex]
                        local data = btn.data or {}

                        if btn.action == 'cycle_recipe' and #recipes > 0 then
                            machine._uiRecipeIndex = machine._uiRecipeIndex + (data.dir or 1)
                            if machine._uiRecipeIndex < 1 then machine._uiRecipeIndex = #recipes end
                            if machine._uiRecipeIndex > #recipes then machine._uiRecipeIndex = 1 end
                        elseif btn.action == 'set_recipe' and recipes[machine._uiRecipeIndex] then
                            machine.recipe = recipes[machine._uiRecipeIndex].id
                            machine._activeBillId = nil
                        elseif btn.action == 'clear_recipe' then
                            machine.recipe = nil
                            machine._activeBillId = nil
                        elseif btn.action == 'add_bill' and wok and WorkOrders and recipes[machine._uiRecipeIndex] then
                            WorkOrders.addBill(btn.entityId, WorkOrders.createBill(recipes[machine._uiRecipeIndex].id, 'count', 5))
                            machine._uiBillIndex = WorkOrders.getBillCount(btn.entityId)
                        elseif bill and wok and WorkOrders then
                            if btn.action == 'cycle_bill' then
                                machine._uiBillIndex = machine._uiBillIndex + (data.dir or 1)
                                if machine._uiBillIndex < 1 then machine._uiBillIndex = #bills end
                                if machine._uiBillIndex > #bills then machine._uiBillIndex = 1 end
                            elseif btn.action == 'toggle_bill_pause' then
                                WorkOrders.togglePause(btn.entityId, bill.id)
                            elseif btn.action == 'remove_bill' then
                                WorkOrders.removeBill(btn.entityId, bill.id)
                                machine._uiBillIndex = math.max(1, math.min(machine._uiBillIndex, math.max(WorkOrders.getBillCount(btn.entityId), 1)))
                            elseif btn.action == 'move_bill' then
                                if (data.dir or 0) < 0 then
                                    WorkOrders.moveBillUp(btn.entityId, bill.id)
                                else
                                    WorkOrders.moveBillDown(btn.entityId, bill.id)
                                end
                            elseif btn.action == 'cycle_bill_mode' then
                                local orderedModes = { 'count', 'until_x', 'forever' }
                                local current = 1
                                for i, modeId in ipairs(orderedModes) do
                                    if bill.mode == modeId then current = i break end
                                end
                                WorkOrders.setBillMode(btn.entityId, bill.id, orderedModes[(current % #orderedModes) + 1])
                            elseif btn.action == 'adjust_bill_target' then
                                WorkOrders.setBillTarget(btn.entityId, bill.id, (bill.target or 1) + (data.delta or 0))
                            elseif btn.action == 'cycle_bill_quality' then
                                local nextChoice = cycleChoice(getQualityChoices(), bill.qualityMin, 1)
                                WorkOrders.setBillQualityMin(btn.entityId, bill.id, nextChoice.id)
                            elseif btn.action == 'adjust_bill_radius' then
                                bill.ingredientRadius = math.max(5, math.min(999, (bill.ingredientRadius or 999) + (data.delta or 0)))
                            elseif btn.action == 'cycle_bill_material' then
                                local nextChoice = cycleChoice(getMaterialChoices(), getSingleKey(bill.materialFilter), 1)
                                WorkOrders.setBillMaterialFilter(btn.entityId, bill.id, nextChoice.id and { [nextChoice.id] = true } or nil)
                            end
                        end
                    end
                elseif btn.kind == 'inserter' then
                    local ok, Inserters = pcall(require, 'src.logistics.inserters')
                    local inserter = ECS.get(btn.entityId, 'inserter')
                    if ok and inserter then
                        if btn.action == 'clear_filter' then
                            Inserters.setFilter(btn.entityId, nil)
                        elseif btn.action == 'cycle_filter' then
                            local nextChoice = cycleChoice(getItemChoices(), inserter.filterItem, (btn.data and btn.data.dir) or 1)
                            Inserters.setFilter(btn.entityId, nextChoice.id)
                        end
                    end
                elseif btn.kind == 'barrier' then
                    local fence = ECS.get(btn.entityId, 'laser_fence')
                    if fence and btn.action == 'toggle_barrier' then
                        fence.toggled = not (fence.toggled ~= false)
                    end
                elseif btn.kind == 'prisoner' then
                    local rok, Recruitment = pcall(require, 'src.colonist.recruitment')
                    if rok then
                        if btn.action == 'recruit' then
                            local ok, msg = Recruitment.attemptManualRecruit(btn.entityId)
                            if msg then UI.showSaveToast(msg) end
                            if ok then GameState.selectedEntities = {} end
                        elseif btn.action == 'release' then
                            local ok = Recruitment.releasePrisoner(btn.entityId)
                            if ok then
                                UI.showSaveToast('Prisoner released')
                                GameState.selectedEntities = {}
                            end
                        elseif btn.action == 'execute' then
                            local ok = Recruitment.executePrisoner(btn.entityId)
                            if ok then
                                UI.showSaveToast('Prisoner executed')
                                GameState.selectedEntities = {}
                            end
                        end
                    end
                end
                return true
            end
        end
    end

    if BuildMenu.mousepressed(x, y, button) then
        return true
    end
    return false
end

function UI.mousereleased(x, y, button)
    if Menus.mousereleased and Menus.mousereleased(x, y, button) then return end
    if button == 1 then
        Selection.setDragWork(nil)
    end
end

function UI.mousemoved(x, y)
    if Menus.mousemoved and Menus.mousemoved(x, y) then return end
    -- Drag-paint work priorities across cells
    local dragWork = Selection.getDragWork()
    if dragWork and love.mouse.isDown(1) then
        for _, cell in ipairs(Selection.getWorkCells()) do
            if hitTest(x, y, cell) then
                local wp = ECS.get(cell.id, 'workPriority')
                if wp then
                    wp[cell.col] = dragWork.value
                end
                return
            end
        end
    end
end

function UI.wheelmoved(dx, dy)
    if Menus.isMenuOpen() then return true end
    if BuildMenu.wheelmoved(dx, dy) then return true end
    return false
end

function UI.resize(w, h)
    screenW = w
    screenH = h
    HUD.resize(w, h)
    Selection.resize(w, h)
    Context.resize(w, h)
    Overlays.resize(w, h)
    Menus.resize(w, h)
end

---------------------------------------------------------------------------
-- Public API forwarding (called by input.lua and main.lua)
---------------------------------------------------------------------------

function UI.openContextMenu(sx, sy, targetId, targetType, actingColonistId, tileX, tileY, tileDepth)
    Context.open(sx, sy, targetId, targetType, actingColonistId, tileX, tileY, tileDepth)
end

function UI.closeContextMenu()
    Context.close()
end

function UI.isContextMenuOpen()
    return Context.isOpen()
end

function UI.toggleEventLog()
    Overlays.toggleEventLog()
end

function UI.toggleTaskQueue()
    Overlays.toggleTaskQueue()
end

function UI.toggleHotkeyHelp()
    Overlays.toggleHotkeyHelp()
end

function UI.openMenu(name)
    Menus.openMenu(name)
end

function UI.closeMenu()
    Menus.closeMenu()
end

function UI.isMenuOpen()
    return Menus.isMenuOpen()
end

function UI.showSaveToast(text)
    Menus.showSaveToast(text)
end

return UI
