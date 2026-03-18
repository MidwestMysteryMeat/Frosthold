-- ui_building_info.lua — Building inspection panel and endgame building panel

local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')

local BuildingInfo = {}

-- Endgame action button hit zone (written during draw, read by coordinator)
local endgameActionBtn = nil
local interactionBtns = {}

function BuildingInfo.getEndgameActionBtn() return endgameActionBtn end
function BuildingInfo.clearEndgameActionBtn() endgameActionBtn = nil end
function BuildingInfo.getInteractionBtns() return interactionBtns end
function BuildingInfo.clearInteractionBtns() interactionBtns = {} end

local function addInteractionBtn(x, y, label, kind, entityId, action, colors)
    local font = love.graphics.getFont()
    local btnW = font:getWidth(label) + 24
    local btnH = 24
    interactionBtns[#interactionBtns + 1] = {
        x = x, y = y, w = btnW, h = btnH,
        kind = kind, entityId = entityId, action = action,
        data = colors and colors.data or nil,
    }

    local fill = colors and colors.fill or { 0.12, 0.22, 0.32 }
    local line = colors and colors.line or { 0.35, 0.65, 0.9 }
    local text = colors and colors.text or { 0.55, 0.85, 1.0 }
    love.graphics.setColor(fill[1], fill[2], fill[3])
    love.graphics.rectangle('fill', x, y, btnW, btnH, 4)
    love.graphics.setColor(line[1], line[2], line[3])
    love.graphics.rectangle('line', x, y, btnW, btnH, 4)
    love.graphics.setColor(text[1], text[2], text[3])
    love.graphics.print(label, x + 12, y + 5)
    return btnW
end

-- Public wrapper for adding interaction buttons from other UI modules
function BuildingInfo.addPrisonerBtn(x, y, label, kind, entityId, action, colors)
    return addInteractionBtn(x, y, label, kind, entityId, action, colors)
end

local function getSingleFilterKey(filterTable)
    if not filterTable then return nil end
    for key in pairs(filterTable) do
        return key
    end
    return nil
end

local function getSortedItemChoices()
    local ok, Production = pcall(require, 'src.building.production')
    if not ok or not Production.ITEMS then return {} end
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

local function getSortedMaterialChoices()
    local ok, Materials = pcall(require, 'src.world.materials')
    if not ok or not Materials.DEFS then return {} end
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
    if not ok or not Quality.TIERS then return {} end
    local choices = { { id = nil, name = 'Any Quality' } }
    for _, tier in ipairs(Quality.TIERS) do
        choices[#choices + 1] = { id = tier.id, name = tier.name }
    end
    return choices
end

---------------------------------------------------------------------------
-- Building inspection panel
---------------------------------------------------------------------------

function BuildingInfo.drawBuildingPanel(id, bref, panelY)
    local bok, Building = pcall(require, 'src.building.building')
    local def = bok and Building.defs[bref.defId]
    local name = def and def.name or bref.defId

    -- Header: building name
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(name, 16, panelY + 8)

    -- Description
    if def and def.desc then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print(def.desc, 16, panelY + 24)
    end

    local infoY = panelY + 44

    -- Durability bar
    local dok, Deterioration = pcall(require, 'src.sim.deterioration')
    if dok then
        local cur, mx = Deterioration.getDurability(id)
        if cur and mx then
            local frac = cur / mx
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.print(string.format('Durability: %.0f / %.0f', cur, mx), 16, infoY)
            local barX, barW, barH = 180, 100, 8
            love.graphics.setColor(0.15, 0.15, 0.15)
            love.graphics.rectangle('fill', barX, infoY + 2, barW, barH, 2)
            if frac > 0.5 then
                love.graphics.setColor(0.3, 0.8, 0.3)
            elseif frac > 0.25 then
                love.graphics.setColor(0.9, 0.7, 0.2)
            else
                love.graphics.setColor(0.9, 0.3, 0.2)
            end
            love.graphics.rectangle('fill', barX, infoY + 2, barW * frac, barH, 2)
            infoY = infoY + 18
        end
    end

    -- Machine info (recipe, progress)
    local mach = ECS.get(id, 'machine')
    if mach then
        love.graphics.setColor(0.7, 0.8, 0.9)
        love.graphics.print('Type: ' .. (mach.name or mach.type), 16, infoY)
        infoY = infoY + 16

        if mach.recipe then
            local pok, Production = pcall(require, 'src.building.production')
            local recipeName = pok and Production.getRecipeName(mach.recipe) or mach.recipe
            love.graphics.setColor(0.6, 0.7, 0.6)
            love.graphics.print('Recipe: ' .. recipeName, 16, infoY)
            infoY = infoY + 16

            if mach.active and mach.progress then
                local pct = 0
                local pok2, Prod2 = pcall(require, 'src.building.production')
                if pok2 then
                    local recipes = Prod2.getRecipesForMachine(mach.type)
                    for _, r in ipairs(recipes) do
                        if r.id == mach.recipe then
                            pct = r.recipe.time > 0 and (mach.progress / r.recipe.time * 100) or 0
                            break
                        end
                    end
                end
                love.graphics.setColor(0.5, 0.7, 0.9)
                love.graphics.print(string.format('Progress: %.0f%%', pct), 16, infoY)

                -- Progress bar
                local barX, barW, barH = 130, 100, 8
                love.graphics.setColor(0.15, 0.15, 0.15)
                love.graphics.rectangle('fill', barX, infoY + 2, barW, barH, 2)
                love.graphics.setColor(0.2, 0.6, 0.9)
                love.graphics.rectangle('fill', barX, infoY + 2, barW * math.min(1, pct / 100), barH, 2)
                infoY = infoY + 16
            end
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print('No recipe set', 16, infoY)
            infoY = infoY + 16
        end

        -- Power status
        if not mach.powered then
            love.graphics.setColor(0.9, 0.3, 0.2)
            love.graphics.print('No Power', 16, infoY)
            infoY = infoY + 16
        end

        local wok, WorkOrders = pcall(require, 'src.building.work_orders')
        local pok3, Prod3 = pcall(require, 'src.building.production')
        local recipes = pok3 and Prod3.getRecipesForMachine and Prod3.getRecipesForMachine(mach.type) or {}
        table.sort(recipes, function(a, b)
            return (a.recipe.name or a.id) < (b.recipe.name or b.id)
        end)

        if #recipes > 0 then
            mach._uiRecipeIndex = math.max(1, math.min(#recipes, mach._uiRecipeIndex or 1))
            local recipeEntry = recipes[mach._uiRecipeIndex]
            love.graphics.setColor(0.72, 0.8, 0.9)
            love.graphics.print('Browse Recipe: ' .. (recipeEntry.recipe.name or recipeEntry.id), 16, infoY)
            infoY = infoY + 18

            local btnX = 16
            btnX = btnX + addInteractionBtn(btnX, infoY, '<', 'machine', id, 'cycle_recipe', {
                data = { dir = -1 },
            }) + 6
            btnX = btnX + addInteractionBtn(btnX, infoY, '>', 'machine', id, 'cycle_recipe', {
                data = { dir = 1 },
            }) + 6
            btnX = btnX + addInteractionBtn(btnX, infoY, 'Set Recipe', 'machine', id, 'set_recipe') + 6
            btnX = btnX + addInteractionBtn(btnX, infoY, 'Add Bill', 'machine', id, 'add_bill') + 6
            addInteractionBtn(btnX, infoY, 'Clear Recipe', 'machine', id, 'clear_recipe')
            infoY = infoY + 28
        end

        if wok and WorkOrders then
            local bills = WorkOrders.getBills(id)
            if #bills > 0 then
                mach._uiBillIndex = math.max(1, math.min(#bills, mach._uiBillIndex or 1))
                local bill = bills[mach._uiBillIndex]
                local modeLabel = WorkOrders.MODES[bill.mode] or bill.mode
                local materialId = getSingleFilterKey(bill.materialFilter)
                local qualityId = bill.qualityMin

                love.graphics.setColor(0.84, 0.86, 0.9)
                love.graphics.print(string.format('Bill %d/%d: %s', mach._uiBillIndex, #bills, bill.recipeId), 16, infoY)
                infoY = infoY + 16
                love.graphics.setColor(0.62, 0.68, 0.76)
                love.graphics.print(string.format(
                    '%s  Target %d  Produced %d  %s',
                    modeLabel,
                    bill.target or 1,
                    bill.produced or 0,
                    bill.paused and 'Paused' or 'Active'
                ), 16, infoY)
                infoY = infoY + 16
                love.graphics.print(string.format(
                    'Quality: %s  Radius: %d  Material: %s',
                    qualityId or 'Any',
                    bill.ingredientRadius or 999,
                    materialId or 'Any'
                ), 16, infoY)
                infoY = infoY + 20

                local btnX = 16
                btnX = btnX + addInteractionBtn(btnX, infoY, 'Prev Bill', 'machine', id, 'cycle_bill', {
                    data = { dir = -1 },
                }) + 6
                btnX = btnX + addInteractionBtn(btnX, infoY, 'Next Bill', 'machine', id, 'cycle_bill', {
                    data = { dir = 1 },
                }) + 6
                btnX = btnX + addInteractionBtn(btnX, infoY, bill.paused and 'Resume' or 'Pause', 'machine', id, 'toggle_bill_pause') + 6
                addInteractionBtn(btnX, infoY, 'Remove', 'machine', id, 'remove_bill')
                infoY = infoY + 28

                btnX = 16
                btnX = btnX + addInteractionBtn(btnX, infoY, 'Mode', 'machine', id, 'cycle_bill_mode') + 6
                btnX = btnX + addInteractionBtn(btnX, infoY, 'Target -', 'machine', id, 'adjust_bill_target', {
                    data = { delta = -1 },
                }) + 6
                btnX = btnX + addInteractionBtn(btnX, infoY, 'Target +', 'machine', id, 'adjust_bill_target', {
                    data = { delta = 1 },
                }) + 6
                btnX = btnX + addInteractionBtn(btnX, infoY, 'Up', 'machine', id, 'move_bill', {
                    data = { dir = -1 },
                }) + 6
                addInteractionBtn(btnX, infoY, 'Down', 'machine', id, 'move_bill', {
                    data = { dir = 1 },
                })
                infoY = infoY + 28

                btnX = 16
                btnX = btnX + addInteractionBtn(btnX, infoY, 'Quality', 'machine', id, 'cycle_bill_quality') + 6
                btnX = btnX + addInteractionBtn(btnX, infoY, 'Radius -', 'machine', id, 'adjust_bill_radius', {
                    data = { delta = -10 },
                }) + 6
                btnX = btnX + addInteractionBtn(btnX, infoY, 'Radius +', 'machine', id, 'adjust_bill_radius', {
                    data = { delta = 10 },
                }) + 6
                addInteractionBtn(btnX, infoY, 'Material', 'machine', id, 'cycle_bill_material')
                infoY = infoY + 28
            else
                love.graphics.setColor(0.5, 0.5, 0.55)
                love.graphics.print('No bills queued.', 16, infoY)
                infoY = infoY + 16
            end
        end
    end

    -- Steam hub info
    local hub = ECS.get(id, 'steam_hub')
    if hub then
        if hub.active then
            love.graphics.setColor(0.3, 0.9, 0.4)
            love.graphics.print('Active', 16, infoY)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print('Inactive', 16, infoY)
        end
        infoY = infoY + 16
    end

    -- Battery info
    local bat = ECS.get(id, 'battery')
    if bat then
        local pct = bat.capacity > 0 and (bat.stored / bat.capacity * 100) or 0
        love.graphics.setColor(0.6, 0.8, 0.3)
        love.graphics.print(string.format('Charge: %.0f / %.0f (%.0f%%)', bat.stored, bat.capacity, pct), 16, infoY)
        local barX, barW, barH = 250, 100, 8
        love.graphics.setColor(0.15, 0.15, 0.15)
        love.graphics.rectangle('fill', barX, infoY + 2, barW, barH, 2)
        love.graphics.setColor(0.4, 0.8, 0.2)
        love.graphics.rectangle('fill', barX, infoY + 2, barW * math.min(1, pct / 100), barH, 2)
        infoY = infoY + 16
    end

    -- Cloning vat info
    local vat = ECS.get(id, 'cloning_vat')
    if vat then
        if vat.active then
            local pct = vat.progress and (vat.progress / 300 * 100) or 0
            love.graphics.setColor(0.5, 0.9, 0.7)
            love.graphics.print(string.format('Growing clone: %.0f%%', pct), 16, infoY)
            local barX, barW, barH = 180, 100, 8
            love.graphics.setColor(0.15, 0.15, 0.15)
            love.graphics.rectangle('fill', barX, infoY + 2, barW, barH, 2)
            love.graphics.setColor(0.3, 0.8, 0.6)
            love.graphics.rectangle('fill', barX, infoY + 2, barW * math.min(1, pct / 100), barH, 2)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print('Idle', 16, infoY)
            if vat.grown and vat.grown > 0 then
                love.graphics.setColor(0.6, 0.8, 0.6)
                love.graphics.print(string.format('  Clones grown: %d', vat.grown), 100, infoY)
            end
        end
        infoY = infoY + 16
    end

    -- Radio beacon info
    local beacon = ECS.get(id, 'radio_beacon')
    if beacon then
        if beacon.powered then
            love.graphics.setColor(0.3, 0.9, 0.4)
            love.graphics.print('Broadcasting', 16, infoY)
        else
            love.graphics.setColor(0.9, 0.3, 0.2)
            love.graphics.print('No Power', 16, infoY)
        end
        infoY = infoY + 16
    end

    local containment = ECS.get(id, 'containment_cell')
    if containment then
        local cok, Containment = pcall(require, 'src.sim.containment')
        local snap = cok and Containment.getCellSnapshot and Containment.getCellSnapshot(id) or nil
        local risk = snap and snap.risk or 0
        local env = snap and snap.env or nil
        local subject = snap and snap.subject or nil

        love.graphics.setColor(0.75, 0.82, 0.95)
        love.graphics.print('Containment: ' .. ((containment.cellType == 'locker') and 'Locker' or 'Live Cell'), 16, infoY)
        infoY = infoY + 16

        love.graphics.setColor(0.65, 0.75, 0.82)
        love.graphics.print('Mode: ' .. (snap and snap.modeLabel or 'Study'), 16, infoY)
        love.graphics.print(string.format('Pending Subjects: %d', snap and snap.pending or 0), 180, infoY)
        infoY = infoY + 16

        if risk >= 70 then
            love.graphics.setColor(0.95, 0.3, 0.25)
        elseif risk >= 40 then
            love.graphics.setColor(0.95, 0.7, 0.25)
        else
            love.graphics.setColor(0.35, 0.9, 0.45)
        end
        love.graphics.print(string.format('Risk: %.0f%%', risk), 16, infoY)

        if env then
            if env.powered then
                love.graphics.setColor(0.4, 0.85, 0.45)
            else
                love.graphics.setColor(0.9, 0.3, 0.2)
            end
            love.graphics.print(env.powered and 'Powered' or 'No Power', 110, infoY)
            if env.sealed then
                love.graphics.setColor(0.45, 0.82, 1)
            else
                love.graphics.setColor(0.9, 0.45, 0.2)
            end
            love.graphics.print(env.sealed and 'Sealed' or 'Unsealed', 200, infoY)
            love.graphics.setColor(0.6, 0.7, 0.75)
            love.graphics.print(string.format('O2 %.0f%%  Temp %.0fC  Filth %.1f', env.o2 or 0, env.avgTemp or 0, env.filth or 0), 300, infoY)
            infoY = infoY + 16
            love.graphics.setColor(0.55, 0.6, 0.65)
            love.graphics.print('Room: ' .. (env.roomTypeName or 'Room'), 16, infoY)
            infoY = infoY + 16
        else
            infoY = infoY + 16
        end

        if subject then
            love.graphics.setColor(0.95, 0.9, 0.82)
            love.graphics.print(subject.label or 'Subject', 16, infoY)
            infoY = infoY + 16
            love.graphics.setColor(0.62, 0.64, 0.68)
            love.graphics.print(subject.desc or 'Recovered anomaly subject.', 16, infoY)
            infoY = infoY + 16
            love.graphics.print(string.format('Instability %d  Research %d  Leak %.2f',
                subject.instability or 0, subject.researchValue or 0, subject.anomalyLeak or 0), 16, infoY)
            infoY = infoY + 22

            local btnX = 16
            btnX = btnX + addInteractionBtn(btnX, infoY, 'Mode: ' .. (snap and snap.modeLabel or 'Study'),
                'containment', id, 'cycle_mode') + 8
            btnX = btnX + addInteractionBtn(btnX, infoY, 'Transfer Intact', 'containment', id, 'transfer', {
                fill = { 0.12, 0.18, 0.26 }, line = { 0.45, 0.72, 0.98 }, text = { 0.72, 0.88, 1.0 },
            }) + 8
            btnX = btnX + addInteractionBtn(btnX, infoY, 'Purge', 'containment', id, 'purge', {
                fill = { 0.25, 0.12, 0.1 }, line = { 0.9, 0.35, 0.25 }, text = { 1.0, 0.55, 0.45 },
            }) + 8
            if snap and snap.canAdmit then
                addInteractionBtn(btnX, infoY, 'Admit Survivor', 'containment', id, 'admit', {
                    fill = { 0.12, 0.28, 0.18 }, line = { 0.45, 0.95, 0.55 }, text = { 0.65, 1.0, 0.7 },
                })
            end
        else
            love.graphics.setColor(0.45, 0.48, 0.52)
            love.graphics.print('No subject assigned.', 16, infoY)
            infoY = infoY + 22
            if snap and snap.canAssign then
                addInteractionBtn(16, infoY, 'Assign Next Subject', 'containment', id, 'assign')
            end
        end
    end
end

function BuildingInfo.drawInserterPanel(id, inserter, panelY)
    local ok, Inserters = pcall(require, 'src.logistics.inserters')
    local def = ok and Inserters.TYPES[inserter.type] or nil
    local name = def and def.name or inserter.type

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(name, 16, panelY + 8)

    local infoY = panelY + 32
    love.graphics.setColor(0.65, 0.75, 0.85)
    love.graphics.print(
        string.format('Source %d,%d  Destination %d,%d', inserter.sourceX, inserter.sourceY, inserter.destX, inserter.destY),
        16,
        infoY
    )
    infoY = infoY + 18

    love.graphics.print('Power: ' .. (inserter.powered and 'Online' or 'Offline'), 16, infoY)
    infoY = infoY + 18

    if def and def.filter then
        local choices = getSortedItemChoices()
        local filterName = 'Any Item'
        for _, choice in ipairs(choices) do
            if choice.id == inserter.filterItem then
                filterName = choice.name
                break
            end
        end

        love.graphics.setColor(0.8, 0.86, 0.94)
        love.graphics.print('Filter: ' .. filterName, 16, infoY)
        infoY = infoY + 22

        local btnX = 16
        btnX = btnX + addInteractionBtn(btnX, infoY, '<', 'inserter', id, 'cycle_filter', {
            data = { dir = -1 },
        }) + 6
        btnX = btnX + addInteractionBtn(btnX, infoY, '>', 'inserter', id, 'cycle_filter', {
            data = { dir = 1 },
        }) + 6
        addInteractionBtn(btnX, infoY, 'Clear Filter', 'inserter', id, 'clear_filter')
    else
        love.graphics.setColor(0.5, 0.55, 0.6)
        love.graphics.print('This inserter moves any item.', 16, infoY)
    end
end

function BuildingInfo.drawBarrierPanel(id, fence, panelY)
    local ok, Defenses = pcall(require, 'src.combat.defenses')
    local def = ok and Defenses.LASER_DEFS and Defenses.LASER_DEFS[fence.type] or nil

    love.graphics.setColor(1, 1, 1)
    love.graphics.print((def and def.name) or fence.type, 16, panelY + 8)

    local infoY = panelY + 32
    love.graphics.setColor(0.72, 0.8, 0.9)
    love.graphics.print(string.format('HP: %.0f / %.0f', fence.hp or 0, fence.maxHp or 0), 16, infoY)
    infoY = infoY + 18
    love.graphics.print('State: ' .. ((fence.toggled == false) and 'Open' or 'Closed'), 16, infoY)
    infoY = infoY + 18
    love.graphics.print('Barrier: ' .. ((fence.active and 'Active') or 'Inactive'), 16, infoY)
    infoY = infoY + 24

    if def and def.toggleable then
        addInteractionBtn(16, infoY, (fence.toggled == false) and 'Close Gate' or 'Open Gate', 'barrier', id, 'toggle_barrier')
    end
end

function BuildingInfo.drawZonePanel(zoneId, panelY)
    local Zones = require('src.world.zones')
    local zone = Zones.getAll()[zoneId]
    if not zone then return end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print((Zones.TYPES[zone.type] and Zones.TYPES[zone.type].name) or zone.type, 16, panelY + 8)

    local infoY = panelY + 28
    love.graphics.setColor(0.6, 0.65, 0.72)
    love.graphics.print(string.format('Tiles: %d', #zone.tileList), 16, infoY)
    if zone.type == 'stockpile' then
        love.graphics.print(string.format('Stored: %d  Free: %d', Zones.countItems(zoneId), Zones.countFree(zoneId)), 120, infoY)
    end
    infoY = infoY + 18

    if zone.type == 'restricted' then
        love.graphics.setColor(0.75, 0.82, 0.95)
        love.graphics.print('Autonomous colonists will stay inside the union of allowed areas on this depth.', 16, infoY)
        infoY = infoY + 24
        addInteractionBtn(16, infoY, 'Delete Area', 'zone', zoneId, 'delete_zone')
        return
    end

    local btnX = 16
    love.graphics.setColor(0.78, 0.84, 0.92)
    love.graphics.print('Priority: ' .. Zones.PRIORITY_NAMES[zone.priority or 5], 16, infoY)
    btnX = btnX + addInteractionBtn(160, infoY - 4, '-', 'zone', zoneId, 'adjust_priority', {
        data = { delta = 1 },
    }) + 6
    btnX = btnX + addInteractionBtn(btnX, infoY - 4, '+', 'zone', zoneId, 'adjust_priority', {
        data = { delta = -1 },
    }) + 6
    btnX = btnX + addInteractionBtn(btnX, infoY - 4, 'Clear Filters', 'zone', zoneId, 'clear_filters') + 6
    addInteractionBtn(btnX, infoY - 4, 'Delete Zone', 'zone', zoneId, 'delete_zone')
    infoY = infoY + 26

    if zone.type == 'stockpile' then
        love.graphics.setColor(0.82, 0.86, 0.9)
        love.graphics.print('Categories:', 16, infoY)
        infoY = infoY + 18

        local colX = 16
        local colY = infoY
        for i, category in ipairs(Zones.CATEGORIES) do
            local active = next(zone.filter) == nil or zone.filter[category]
            local colors = active and {
                fill = { 0.12, 0.28, 0.18 }, line = { 0.4, 0.85, 0.5 }, text = { 0.68, 0.98, 0.72 },
                data = { category = category },
            } or {
                fill = { 0.12, 0.15, 0.18 }, line = { 0.35, 0.4, 0.46 }, text = { 0.62, 0.66, 0.72 },
                data = { category = category },
            }
            local btnW = addInteractionBtn(colX, colY, category, 'zone', zoneId, 'toggle_category', colors)
            if i % 4 == 0 then
                colX = 16
                colY = colY + 28
            else
                colX = colX + btnW + 6
            end
        end
        infoY = colY + 32

        local itemFilter = getSingleFilterKey(zone.itemFilter)
        local materialFilter = getSingleFilterKey(zone.materialFilter)
        local qualityFilter = zone.qualityMin

        love.graphics.setColor(0.75, 0.82, 0.95)
        love.graphics.print('Item: ' .. (itemFilter or 'Any Item'), 16, infoY)
        infoY = infoY + 18
        btnX = 16
        btnX = btnX + addInteractionBtn(btnX, infoY - 4, '<', 'zone', zoneId, 'cycle_item', {
            data = { dir = -1 },
        }) + 6
        btnX = btnX + addInteractionBtn(btnX, infoY - 4, '>', 'zone', zoneId, 'cycle_item', {
            data = { dir = 1 },
        }) + 12
        btnX = btnX + addInteractionBtn(btnX, infoY - 4, 'Quality', 'zone', zoneId, 'cycle_quality') + 6
        addInteractionBtn(btnX, infoY - 4, 'Material', 'zone', zoneId, 'cycle_material')
        infoY = infoY + 22

        love.graphics.setColor(0.62, 0.68, 0.74)
        love.graphics.print(
            string.format('Min Quality: %s  Material: %s', qualityFilter or 'Any', materialFilter or 'Any'),
            16,
            infoY
        )
    else
        love.graphics.setColor(0.75, 0.82, 0.95)
        love.graphics.print('Dumping zones mark floor space for junk and corpses.', 16, infoY)
    end
end

function BuildingInfo.drawArtifactPanel(id, artifact, panelY)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(artifact.name or 'Artifact', 16, panelY + 8)

    love.graphics.setColor(0.55, 0.55, 0.6)
    love.graphics.print(artifact.desc or 'Recovered from the ice.', 16, panelY + 24)

    local infoY = panelY + 48
    love.graphics.setColor(0.75, 0.82, 0.95)
    love.graphics.print('Status: ' .. (artifact.activated and 'Resolved' or 'Unresolved'), 16, infoY)
    infoY = infoY + 16

    if artifact.subjectTemplate or artifact.subjectTemplates or artifact.recoverable then
        love.graphics.setColor(0.85, 0.75, 0.65)
        love.graphics.print('Recover this find first, then route it into containment, transfer, or study.', 16, infoY)
        infoY = infoY + 24
        addInteractionBtn(16, infoY, artifact.actionLabel or 'Recover Subject', 'artifact', id, 'activate')
    else
        love.graphics.setColor(0.7, 0.76, 0.82)
        love.graphics.print('Unstable field artifact. Activating it resolves the encounter immediately.', 16, infoY)
        infoY = infoY + 24
        addInteractionBtn(16, infoY, 'Activate', 'artifact', id, 'activate')
    end
end

---------------------------------------------------------------------------
-- Endgame building panel
---------------------------------------------------------------------------

local ENDGAME_NAMES = {
    transmission_array = 'Transmission Array',
    launch_pad         = 'Launch Pad',
    sealing_apparatus  = 'Sealing Apparatus',
}
local ENDGAME_START_LABELS = {
    transmission_array = 'Transmit Claim',
    launch_pad         = 'Begin Escape Sequence',
    sealing_apparatus  = 'Seal the Deep',
}

function BuildingInfo.drawEndgamePanel(id, eg, panelY)
    local name = ENDGAME_NAMES[eg.type] or 'Endgame Building'

    -- Name
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(name, 16, panelY + 8)

    -- Power status
    if eg.powered then
        love.graphics.setColor(0.3, 0.9, 0.4)
        love.graphics.print('Powered', 200, panelY + 8)
    else
        love.graphics.setColor(0.9, 0.3, 0.2)
        love.graphics.print('No Power', 200, panelY + 8)
    end

    -- Phase label
    local phaseColors = {
        idle       = {0.5, 0.5, 0.5},
        charging   = {0.2, 0.6, 0.9},
        ready      = {0.3, 0.9, 0.4},
        activating = {1, 0.6, 0.2},
        complete   = {1, 0.85, 0.2},
    }
    local phaseLabels = {
        idle       = 'Idle',
        charging   = 'Charging...',
        ready      = 'READY',
        activating = 'Activating...',
        complete   = 'Complete',
    }
    local pc = phaseColors[eg.phase] or {0.5, 0.5, 0.5}
    love.graphics.setColor(pc[1], pc[2], pc[3])
    love.graphics.print(phaseLabels[eg.phase] or eg.phase, 16, panelY + 28)

    -- Charge progress bar
    if eg.phase ~= 'idle' then
        local eok, EndgameMod = pcall(require, 'src.sim.endgame')
        local pct = eok and EndgameMod.getChargePercent(id) or 0
        local CHARGE_TIME = eok and EndgameMod.CHARGE_TIME or (3 * 24 * 60)

        local barX, barY, barW, barH = 16, panelY + 50, 300, 14
        love.graphics.setColor(0.15, 0.15, 0.15)
        love.graphics.rectangle('fill', barX, barY, barW, barH, 3)

        if eg.phase == 'ready' or eg.phase == 'activating' or eg.phase == 'complete' then
            love.graphics.setColor(0.3, 0.9, 0.4)
        else
            love.graphics.setColor(0.2, 0.6, 0.9)
        end
        love.graphics.rectangle('fill', barX, barY, barW * pct / 100, barH, 3)

        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.rectangle('line', barX, barY, barW, barH, 3)

        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format('%.0f%%', pct), barX + barW + 8, barY - 1)

        -- Time remaining (charging only)
        if eg.phase == 'charging' then
            local remaining = math.max(0, CHARGE_TIME - eg.chargeProgress)
            local days = math.floor(remaining / (24 * 60))
            local hours = math.floor((remaining % (24 * 60)) / 60)
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.print(string.format('%dd %dh remaining', days, hours), barX, barY + 18)
            if not eg.powered then
                love.graphics.setColor(0.9, 0.3, 0.2)
                love.graphics.print('STALLED', barX + 140, barY + 18)
            end
        end
    end

    -- Action buttons
    local btnY = panelY + 90
    if eg.phase == 'idle' then
        local label = ENDGAME_START_LABELS[eg.type] or 'Begin'
        local font = love.graphics.getFont()
        local btnW = font:getWidth(label) + 24
        local btnH = 28
        endgameActionBtn = { x = 16, y = btnY, w = btnW, h = btnH, entityId = id, action = 'start' }

        love.graphics.setColor(0.12, 0.25, 0.35)
        love.graphics.rectangle('fill', 16, btnY, btnW, btnH, 4)
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.rectangle('line', 16, btnY, btnW, btnH, 4)
        love.graphics.setColor(0.4, 0.8, 1)
        love.graphics.print(label, 28, btnY + 7)

    elseif eg.phase == 'ready' then
        local btnW, btnH = 140, 28
        endgameActionBtn = { x = 16, y = btnY, w = btnW, h = btnH, entityId = id, action = 'activate' }

        love.graphics.setColor(0.2, 0.35, 0.12)
        love.graphics.rectangle('fill', 16, btnY, btnW, btnH, 4)
        love.graphics.setColor(0.4, 0.9, 0.3)
        love.graphics.rectangle('line', 16, btnY, btnW, btnH, 4)
        love.graphics.setColor(0.5, 1, 0.4)
        love.graphics.print('ACTIVATE', 46, btnY + 7)

    elseif eg.phase == 'activating' then
        if eg.type == 'transmission_array' then
            if eg.finalWaveSpawned then
                love.graphics.setColor(0.9, 0.3, 0.2)
                love.graphics.print('Final assault in progress. Survive to secure the claim.', 16, btnY)
            else
                love.graphics.setColor(1, 0.6, 0.2)
                love.graphics.print('Claim transmitted. Brace for hostile response.', 16, btnY)
            end
        else
            love.graphics.setColor(1, 0.85, 0.2)
            love.graphics.print('Activating...', 16, btnY)
        end

    elseif eg.phase == 'complete' then
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.print('Outcome locked in.', 16, btnY)
    end

    -- Description from building def
    local bref = ECS.get(id, 'building_ref')
    if bref then
        local bok, Building = pcall(require, 'src.building.building')
        if bok then
            local def = Building.defs[bref.defId]
            if def and def.desc then
                love.graphics.setColor(0.45, 0.45, 0.45)
                love.graphics.print(def.desc, 16, panelY + 160)
            end
        end
    end
end

return BuildingInfo
