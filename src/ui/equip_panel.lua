-- equip_panel.lua — Equipment management panel
-- Shows all colonists with their gear. Click to equip/unequip weapons, armor, accessories,
-- and the 5 clothing slots (under, outer, head, hands, feet).
-- Toggle with V key.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local EquipPanel = {}

local visible = false
local scrollY = 0
local selectedColonist = nil  -- entity ID
local selectedSlot = nil      -- 'weapon' | 'under' | 'outer' | 'head' | 'hands' | 'feet' | 'accessory'

-- Hit zones rebuilt each frame
local colonistBtns = {}
local slotBtns = {}
local itemBtns = {}
local unequipBtn = nil

-- Clothing slots set for picker routing
local CLOTHING_SLOTS = { under = true, outer = true, head = true, hands = true, feet = true }

---------------------------------------------------------------------------
-- Toggle
---------------------------------------------------------------------------

function EquipPanel.toggle()
    visible = not visible
    scrollY = 0
    selectedColonist = nil
    selectedSlot = nil
end

function EquipPanel.isVisible()
    return visible
end

---------------------------------------------------------------------------
-- View: Colonist list
---------------------------------------------------------------------------

local function drawColonistList(sw, sh, Equipment)
    love.graphics.setColor(0.8, 0.8, 0.75)
    love.graphics.print('SELECT COLONIST', 20, 58)

    local y = 80 - scrollY
    local rowH = 60

    for id, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state ~= 'dead' then
            if y > 40 and y < sh - 10 then
                love.graphics.setColor(0.08, 0.07, 0.07)
                love.graphics.rectangle('fill', 20, y, sw - 40, rowH - 4, 3)
                love.graphics.setColor(0.2, 0.18, 0.18)
                love.graphics.rectangle('line', 20, y, sw - 40, rowH - 4, 3)

                -- Name
                love.graphics.setColor(0.9, 0.9, 0.85)
                love.graphics.print(col.name or 'Colonist', 30, y + 4)

                -- Current gear summary
                local equip = ECS.get(id, 'equipment')
                local weaponName = (equip and equip.weapon) and equip.weapon.name or 'Unarmed'
                local armorName = (equip and equip.armor) and equip.armor.name or 'None'
                local accName = (equip and equip.accessory) and equip.accessory.name or 'None'

                love.graphics.setColor(0.6, 0.55, 0.5)
                love.graphics.print(string.format('Weapon: %s   Armor: %s   Accessory: %s',
                    weaponName, armorName, accName), 30, y + 24)

                -- Health
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print(string.format('HP: %d/%d  State: %s',
                    col.health or 100, col.maxHealth or 100, col.state or '?'), 30, y + 40)

                colonistBtns[#colonistBtns + 1] = {
                    x = 20, y = y, w = sw - 40, h = rowH - 4, entityId = id,
                }
            end
            y = y + rowH
        end
    end
end

---------------------------------------------------------------------------
-- View: Colonist gear detail (7 slots: weapon, under, outer, head, hands, feet, accessory)
---------------------------------------------------------------------------

local function drawColonistGear(sw, sh, Equipment)
    if not ECS.isAlive(selectedColonist) then
        selectedColonist = nil
        return
    end

    local col = ECS.get(selectedColonist, 'colonist')
    local equip = ECS.get(selectedColonist, 'equipment')
    if not col then selectedColonist = nil; return end

    -- Load clothing module for this colonist
    local cok, Clothing = pcall(require, 'src.colonist.clothing')
    local clothComp = (cok and Clothing.getComponent) and Clothing.getComponent(selectedColonist) or {}

    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('< Back (ESC)', 20, 58)

    love.graphics.setColor(0.9, 0.9, 0.85)
    love.graphics.print(col.name or 'Colonist', 20, 78)

    -- Protection summary banner
    local protY = 98
    if cok and Clothing.getProtection then
        local prot = Clothing.getProtection(selectedColonist)
        if prot then
            local protText = string.format(
                'Protection -- Cold: %d  Heat: %d  Rad: %d  Press: %d  Tox: %d',
                math.floor(prot.cold or 0),
                math.floor(prot.heat or 0),
                math.floor(prot.radiation or 0),
                math.floor(prot.pressure or 0),
                math.floor(prot.toxicity or 0)
            )
            love.graphics.setColor(0.7, 0.8, 0.9)
            love.graphics.print(protText, 20, protY)
        end
    end

    local slotY = 118
    local slotH = 55

    local slots = {
        { key = 'weapon',    label = 'WEAPON',    data = equip and equip.weapon,         slotType = 'equipment' },
        { key = 'under',     label = 'UNDER',     data = clothComp and clothComp.under,  slotType = 'clothing' },
        { key = 'outer',     label = 'OUTER',     data = clothComp and clothComp.outer,  slotType = 'clothing' },
        { key = 'head',      label = 'HEAD',       data = clothComp and clothComp.head,   slotType = 'clothing' },
        { key = 'hands',     label = 'HANDS',     data = clothComp and clothComp.hands,  slotType = 'clothing' },
        { key = 'feet',      label = 'FEET',       data = clothComp and clothComp.feet,   slotType = 'clothing' },
        { key = 'accessory', label = 'ACCESSORY', data = equip and equip.accessory,      slotType = 'equipment' },
    }

    for _, slot in ipairs(slots) do
        -- Slot card
        love.graphics.setColor(0.08, 0.08, 0.08)
        love.graphics.rectangle('fill', 20, slotY, sw - 40, slotH, 4)
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle('line', 20, slotY, sw - 40, slotH, 4)

        -- Label
        love.graphics.setColor(0.6, 0.6, 0.5)
        love.graphics.print(slot.label, 30, slotY + 6)

        if slot.data then
            if slot.slotType == 'clothing' then
                -- Clothing item: name + durability percent
                local item = slot.data
                local durPct = item.maxDurability and item.maxDurability > 0
                    and math.floor((item.durability / item.maxDurability) * 100) or 0
                local nameStr = string.format('%s (%d%%)', item.name or item.id or '?', durPct)

                -- Color by durability
                if durPct < 25 then
                    love.graphics.setColor(0.85, 0.35, 0.25)
                elseif durPct < 50 then
                    love.graphics.setColor(0.85, 0.75, 0.25)
                else
                    love.graphics.setColor(0.9, 0.85, 0.75)
                end
                love.graphics.print(nameStr, 140, slotY + 4)

                -- Protection stats line
                love.graphics.setColor(0.55, 0.65, 0.75)
                love.graphics.print(string.format('Cold: +%d  Heat: +%d  Armor: %d',
                    item.cold or 0, item.heat or 0, item.armor or 0), 140, slotY + 22)

                -- Remove button
                local ubX = sw - 110
                love.graphics.setColor(0.25, 0.12, 0.12)
                love.graphics.rectangle('fill', ubX, slotY + 4, 60, 22, 3)
                love.graphics.setColor(0.7, 0.4, 0.4)
                love.graphics.print('Remove', ubX + 4, slotY + 7)

                slotBtns[#slotBtns + 1] = {
                    x = ubX, y = slotY + 4, w = 60, h = 22,
                    action = 'unequip', slot = slot.key, slotType = 'clothing',
                }
            else
                -- Equipment item (weapon / accessory)
                love.graphics.setColor(0.9, 0.85, 0.75)
                love.graphics.print(slot.data.name or slot.data.id, 140, slotY + 6)

                love.graphics.setColor(0.55, 0.55, 0.5)
                if slot.key == 'weapon' then
                    love.graphics.print(string.format('DMG: %d  Range: %d  %s',
                        slot.data.dmg or 0, slot.data.range or 1, slot.data.category or ''), 140, slotY + 24)
                elseif slot.key == 'accessory' then
                    love.graphics.print(string.format('Effect: %s +%s',
                        slot.data.effect or '?', tostring(slot.data.value or 0)), 140, slotY + 24)
                end

                -- Unequip button
                local ubX = sw - 110
                love.graphics.setColor(0.25, 0.12, 0.12)
                love.graphics.rectangle('fill', ubX, slotY + 6, 60, 24, 3)
                love.graphics.setColor(0.7, 0.4, 0.4)
                love.graphics.print('Remove', ubX + 4, slotY + 10)

                slotBtns[#slotBtns + 1] = {
                    x = ubX, y = slotY + 6, w = 60, h = 24,
                    action = 'unequip', slot = slot.key, slotType = 'equipment',
                }
            end
        else
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.print('(empty)', 140, slotY + 6)
        end

        -- Equip / Change button
        local eqX = sw - 185
        love.graphics.setColor(0.12, 0.2, 0.12)
        love.graphics.rectangle('fill', eqX, slotY + (slotH - 28) / 2, 70, 24, 3)
        love.graphics.setColor(0.4, 0.7, 0.4)
        love.graphics.print(slot.data and 'Change' or 'Equip', eqX + 10, slotY + (slotH - 28) / 2 + 4)

        slotBtns[#slotBtns + 1] = {
            x = eqX, y = slotY + (slotH - 28) / 2, w = 70, h = 24,
            action = 'pick', slot = slot.key, slotType = slot.slotType,
        }

        slotY = slotY + slotH + 6
    end

    -- Auto-equip button (equipment only)
    local autoX = 20
    local autoY = slotY + 10
    love.graphics.setColor(0.15, 0.15, 0.25)
    love.graphics.rectangle('fill', autoX, autoY, 120, 30, 4)
    love.graphics.setColor(0.5, 0.5, 0.8)
    love.graphics.print('Auto-Equip', autoX + 14, autoY + 8)

    slotBtns[#slotBtns + 1] = {
        x = autoX, y = autoY, w = 120, h = 30,
        action = 'auto',
    }
end

---------------------------------------------------------------------------
-- View: Item picker — equipment slots use Equipment tables,
--       clothing slots use ClothingDefs.getBySlot
---------------------------------------------------------------------------

local function drawItemPicker(sw, sh, Equipment)
    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('< Back (ESC)', 20, 58)

    local slotLabel = string.upper(selectedSlot)
    love.graphics.setColor(0.8, 0.8, 0.75)
    love.graphics.print('SELECT ' .. slotLabel, 20, 78)

    local y = 100 - scrollY
    local rowH = 40

    if CLOTHING_SLOTS[selectedSlot] then
        -- Clothing item picker
        local cok, ClothingDefs = pcall(require, 'src.colonist.clothing_defs')
        if not cok then return end

        local items = ClothingDefs.getBySlot(selectedSlot)
        table.sort(items, function(a, b) return a.id < b.id end)

        for _, entry in ipairs(items) do
            local def = entry.def
            if y > 40 and y < sh - 10 then
                love.graphics.setColor(0.08, 0.07, 0.07)
                love.graphics.rectangle('fill', 20, y, sw - 40, rowH - 4, 3)
                love.graphics.setColor(0.18, 0.18, 0.18)
                love.graphics.rectangle('line', 20, y, sw - 40, rowH - 4, 3)

                love.graphics.setColor(0.9, 0.85, 0.75)
                love.graphics.print(def.name or entry.id, 30, y + 4)

                love.graphics.setColor(0.55, 0.65, 0.75)
                love.graphics.print(string.format('Cold: +%d  Heat: +%d  Armor: %d  Dur: %d',
                    def.cold or 0, def.heat or 0, def.armor or 0, def.maxDurability or 0), 220, y + 4)

                -- Equip button
                local btnX = sw - 90
                love.graphics.setColor(0.12, 0.22, 0.12)
                love.graphics.rectangle('fill', btnX, y + 4, 50, 26, 3)
                love.graphics.setColor(0.4, 0.75, 0.4)
                love.graphics.print('Equip', btnX + 6, y + 8)

                itemBtns[#itemBtns + 1] = {
                    x = btnX, y = y + 4, w = 50, h = 26,
                    itemId = entry.id, isClothing = true,
                }
            end
            y = y + rowH
        end
    else
        -- Equipment item picker (weapon / accessory)
        local items
        if selectedSlot == 'weapon' then
            items = Equipment.WEAPONS
        else
            items = Equipment.ACCESSORIES
        end

        local sorted = {}
        for iid, def in pairs(items) do
            sorted[#sorted + 1] = { id = iid, def = def }
        end
        table.sort(sorted, function(a, b) return a.id < b.id end)

        for _, entry in ipairs(sorted) do
            local def = entry.def
            if y > 40 and y < sh - 10 then
                if not def.singleUse then
                    love.graphics.setColor(0.08, 0.07, 0.07)
                    love.graphics.rectangle('fill', 20, y, sw - 40, rowH - 4, 3)
                    love.graphics.setColor(0.18, 0.18, 0.18)
                    love.graphics.rectangle('line', 20, y, sw - 40, rowH - 4, 3)

                    love.graphics.setColor(0.9, 0.85, 0.75)
                    love.graphics.print(def.name or entry.id, 30, y + 4)

                    love.graphics.setColor(0.55, 0.55, 0.5)
                    if selectedSlot == 'weapon' then
                        love.graphics.print(string.format('DMG: %d  Range: %d  %s',
                            def.dmg or 0, def.range or 1, def.category or ''), 220, y + 4)
                        if def.accuracy then
                            love.graphics.print(string.format('Acc: %d%%', def.accuracy * 100), 420, y + 4)
                        end
                    else
                        love.graphics.print(string.format('%s +%s',
                            def.effect or '?', tostring(def.value or 0)), 220, y + 4)
                    end

                    -- Equip button
                    local btnX = sw - 90
                    love.graphics.setColor(0.12, 0.22, 0.12)
                    love.graphics.rectangle('fill', btnX, y + 4, 50, 26, 3)
                    love.graphics.setColor(0.4, 0.75, 0.4)
                    love.graphics.print('Equip', btnX + 6, y + 8)

                    itemBtns[#itemBtns + 1] = {
                        x = btnX, y = y + 4, w = 50, h = 26,
                        itemId = entry.id, isClothing = false,
                    }
                end
            end
            if not def.singleUse then
                y = y + rowH
            end
        end
    end
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function EquipPanel.draw()
    if not visible then return end

    local eok, Equipment = pcall(require, 'src.colonist.equipment')
    if not eok then return end

    local sw, sh = love.graphics.getDimensions()
    colonistBtns = {}
    slotBtns = {}
    itemBtns = {}
    unequipBtn = nil

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header
    love.graphics.setColor(0.14, 0.1, 0.1)
    love.graphics.rectangle('fill', 0, 0, sw, 50)
    love.graphics.setColor(0.45, 0.25, 0.25)
    love.graphics.line(0, 50, sw, 50)

    love.graphics.setColor(0.9, 0.8, 0.7)
    love.graphics.print('EQUIPMENT', 20, 16)
    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('V / ESC to close', sw - 130, 16)

    if selectedColonist and selectedSlot then
        drawItemPicker(sw, sh, Equipment)
        return
    end

    if selectedColonist then
        drawColonistGear(sw, sh, Equipment)
        return
    end

    drawColonistList(sw, sh, Equipment)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function EquipPanel.keypressed(key)
    if not visible then return false end
    if key == 'v' or key == 'escape' then
        if selectedSlot then
            selectedSlot = nil
            scrollY = 0
        elseif selectedColonist then
            selectedColonist = nil
            scrollY = 0
        else
            visible = false
        end
        return true
    end
    return true
end

function EquipPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end

    local eok, Equipment = pcall(require, 'src.colonist.equipment')
    if not eok then return true end

    -- Item picker mode
    if selectedColonist and selectedSlot then
        for _, btn in ipairs(itemBtns) do
            if x >= btn.x and x <= btn.x + btn.w
            and y >= btn.y and y <= btn.y + btn.h then
                if btn.isClothing then
                    -- Equip clothing item via Clothing module
                    local cok, Clothing = pcall(require, 'src.colonist.clothing')
                    if cok and Clothing.equip then
                        Clothing.unequip(selectedColonist, selectedSlot)
                        Clothing.equip(selectedColonist, btn.itemId, 'normal')
                    end
                elseif selectedSlot == 'weapon' then
                    Equipment.equipWeapon(selectedColonist, btn.itemId)
                elseif selectedSlot == 'accessory' then
                    Equipment.equipAccessory(selectedColonist, btn.itemId)
                end
                selectedSlot = nil
                scrollY = 0
                return true
            end
        end
        return true
    end

    -- Colonist gear view
    if selectedColonist then
        for _, btn in ipairs(slotBtns) do
            if x >= btn.x and x <= btn.x + btn.w
            and y >= btn.y and y <= btn.y + btn.h then
                if btn.action == 'unequip' then
                    if btn.slotType == 'clothing' then
                        local cok, Clothing = pcall(require, 'src.colonist.clothing')
                        if cok and Clothing.unequip then
                            Clothing.unequip(selectedColonist, btn.slot)
                        end
                    elseif btn.slot == 'weapon' then
                        Equipment.unequipWeapon(selectedColonist)
                    elseif btn.slot == 'accessory' then
                        Equipment.unequipAccessory(selectedColonist)
                    end
                elseif btn.action == 'pick' then
                    selectedSlot = btn.slot
                    scrollY = 0
                    itemBtns = {}
                elseif btn.action == 'auto' then
                    Equipment.autoEquip(selectedColonist)
                end
                return true
            end
        end
        return true
    end

    -- Colonist list
    for _, btn in ipairs(colonistBtns) do
        if x >= btn.x and x <= btn.x + btn.w
        and y >= btn.y and y <= btn.y + btn.h then
            selectedColonist = btn.entityId
            scrollY = 0
            slotBtns = {}
            return true
        end
    end

    return true
end

function EquipPanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return EquipPanel
