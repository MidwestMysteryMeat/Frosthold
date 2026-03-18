-- save_menu.lua — Save/Load slot selection panel
-- Shown from the pause menu. Two modes: 'save' and 'load'.
-- Displays manual slots, quicksave, and auto-saves with metadata.

local GameState = require('src.game_state')

local SaveMenu = {}

local screenW, screenH = 1280, 720
local mode = 'save'  -- 'save' or 'load'
local slotList = {}   -- refreshed on open
local hoverSlot = nil
local hoverDelete = nil
local hoverBack = false
local hoverIntervalUp = false
local hoverIntervalDn = false
local scrollOffset = 0
local autoInterval = 3

-- Naming input state
local namingSlot = nil     -- slot ID being named (nil = not naming)
local namingText = ''      -- current text input

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local PANEL_W     = 540
local PANEL_H     = 540
local SLOT_H      = 48
local SLOT_GAP    = 4
local MARGIN      = 16
local HEADER_H    = 36
local FOOTER_H    = 60
local DELETE_W    = 28

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------

function SaveMenu.open(m)
    mode = m or 'save'
    hoverSlot = nil
    hoverDelete = nil
    hoverBack = false
    scrollOffset = 0
    namingSlot = nil
    namingText = ''
    SaveMenu.refreshSlots()
end

function SaveMenu.refreshSlots()
    local sok, Save = pcall(require, 'src.persistence.save')
    if sok then
        slotList = Save.getSlotList()
        autoInterval = Save.getAutoSaveInterval()
    end
end

function SaveMenu.resize(w, h)
    screenW = w
    screenH = h
end

---------------------------------------------------------------------------
-- Timestamp formatting
---------------------------------------------------------------------------

local function formatTimestamp(ts)
    if not ts or ts == 0 then return '' end
    return os.date('%b %d, %Y  %I:%M%p', ts)
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function SaveMenu.draw()
    screenW, screenH = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local px = math.floor(screenW / 2 - PANEL_W / 2)
    local py = math.floor(screenH / 2 - PANEL_H / 2)

    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', 0, 0, screenW, screenH)

    -- Panel background
    love.graphics.setColor(0.06, 0.06, 0.09, 0.98)
    love.graphics.rectangle('fill', px, py, PANEL_W, PANEL_H, 6, 6)
    love.graphics.setColor(0.35, 0.4, 0.5, 0.8)
    love.graphics.rectangle('line', px, py, PANEL_W, PANEL_H, 6, 6)

    -- Title
    local title = mode == 'save' and 'SAVE GAME' or 'LOAD GAME'
    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.print(title, px + PANEL_W / 2 - font:getWidth(title) / 2, py + 10)

    -- Slot list area
    local listX = px + MARGIN
    local listY = py + HEADER_H
    local listW = PANEL_W - MARGIN * 2
    local listH = PANEL_H - HEADER_H - FOOTER_H

    -- Scissor clip for scrolling
    love.graphics.setScissor(listX, listY, listW, listH)

    local y = listY - scrollOffset
    local mouseX, mouseY = love.mouse.getPosition()
    hoverSlot = nil
    hoverDelete = nil

    for i, slot in ipairs(slotList) do
        local slotY = y + (i - 1) * (SLOT_H + SLOT_GAP)
        if slotY + SLOT_H > listY and slotY < listY + listH then
            local inSlot = mouseX >= listX and mouseX <= listX + listW
                       and mouseY >= slotY and mouseY <= slotY + SLOT_H
                       and mouseY >= listY and mouseY < listY + listH

            -- Naming mode: highlight the slot being named
            if namingSlot == slot.id then
                love.graphics.setColor(0.2, 0.25, 0.35)
                love.graphics.rectangle('fill', listX, slotY, listW, SLOT_H, 4, 4)
                love.graphics.setColor(0.4, 0.7, 1.0)
                love.graphics.rectangle('line', listX, slotY, listW, SLOT_H, 4, 4)
            elseif inSlot then
                hoverSlot = slot.id
                love.graphics.setColor(0.18, 0.22, 0.32)
                love.graphics.rectangle('fill', listX, slotY, listW, SLOT_H, 4, 4)
            else
                love.graphics.setColor(0.10, 0.10, 0.14)
                love.graphics.rectangle('fill', listX, slotY, listW, SLOT_H, 4, 4)
            end

            -- Border for current slot
            if slot.current then
                love.graphics.setColor(0.3, 0.7, 0.4, 0.7)
                love.graphics.rectangle('line', listX, slotY, listW, SLOT_H, 4, 4)
            else
                love.graphics.setColor(0.25, 0.28, 0.35, 0.6)
                love.graphics.rectangle('line', listX, slotY, listW, SLOT_H, 4, 4)
            end

            -- Slot label
            local label
            if slot.type == 'manual' then
                label = 'Slot ' .. slot.index
            elseif slot.type == 'quick' then
                label = 'Quicksave'
            else
                label = 'Auto-save ' .. (slot.index or '?')
            end
            love.graphics.setColor(0.7, 0.85, 1.0)
            love.graphics.print(label, listX + 8, slotY + 4)

            -- Slot metadata
            if slot.meta then
                -- Name
                love.graphics.setColor(1, 1, 1)
                local displayName = slot.meta.name or ''
                if namingSlot == slot.id then
                    displayName = namingText .. '_'  -- cursor
                end
                love.graphics.print(displayName, listX + 100, slotY + 4)

                -- Colony / Day / Colonists
                love.graphics.setColor(0.5, 0.55, 0.6)
                local info = string.format('%s  Day %d  %d colonist%s',
                    slot.meta.colonyName or 'Frosthold',
                    slot.meta.day or 0,
                    slot.meta.colonists or 0,
                    (slot.meta.colonists or 0) == 1 and '' or 's')
                love.graphics.print(info, listX + 8, slotY + 20)

                -- Timestamp
                love.graphics.setColor(0.4, 0.4, 0.45)
                local ts = formatTimestamp(slot.meta.timestamp)
                love.graphics.print(ts, listX + 100, slotY + 32)

                -- Delete button (only for non-empty slots, not during naming)
                if namingSlot ~= slot.id then
                    local delX = listX + listW - DELETE_W - 4
                    local delY = slotY + SLOT_H / 2 - 10
                    local inDel = mouseX >= delX and mouseX <= delX + DELETE_W
                             and mouseY >= delY and mouseY <= delY + 20
                             and mouseY >= listY and mouseY < listY + listH
                    if inDel then
                        hoverDelete = slot.id
                        love.graphics.setColor(0.7, 0.2, 0.2)
                    else
                        love.graphics.setColor(0.4, 0.25, 0.25)
                    end
                    love.graphics.print('X', delX + 9, delY + 2)
                end
            else
                -- Empty slot
                if namingSlot == slot.id then
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(namingText .. '_', listX + 100, slotY + 4)
                else
                    love.graphics.setColor(0.3, 0.3, 0.35)
                    love.graphics.print('-- Empty --', listX + 100, slotY + SLOT_H / 2 - 6)
                end
            end
        end
    end

    love.graphics.setScissor()

    -- Footer: auto-save interval + back button
    local footerY = py + PANEL_H - FOOTER_H

    -- Auto-save interval (only in save mode)
    if mode == 'save' then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print('Auto-save every:', px + MARGIN, footerY + 6)

        local intX = px + MARGIN + font:getWidth('Auto-save every:') + 10
        local intY = footerY + 4

        -- Down arrow
        local dnX = intX
        local inDn = mouseX >= dnX and mouseX <= dnX + 20 and mouseY >= intY and mouseY <= intY + 20
        hoverIntervalDn = inDn
        love.graphics.setColor(inDn and 0.6 or 0.35, inDn and 0.6 or 0.35, inDn and 0.7 or 0.45)
        love.graphics.print('<', dnX + 4, intY + 2)

        -- Value
        love.graphics.setColor(0.9, 0.85, 0.7)
        local valStr = tostring(autoInterval) .. ' days'
        love.graphics.print(valStr, dnX + 24, intY + 2)

        -- Up arrow
        local upX = dnX + 24 + font:getWidth(valStr) + 6
        local inUp = mouseX >= upX and mouseX <= upX + 20 and mouseY >= intY and mouseY <= intY + 20
        hoverIntervalUp = inUp
        love.graphics.setColor(inUp and 0.6 or 0.35, inUp and 0.6 or 0.35, inUp and 0.7 or 0.45)
        love.graphics.print('>', upX + 4, intY + 2)
    end

    -- Back button
    local backW, backH = 100, 28
    local backX = px + PANEL_W / 2 - backW / 2
    local backY = footerY + 30
    hoverBack = mouseX >= backX and mouseX <= backX + backW
            and mouseY >= backY and mouseY <= backY + backH

    love.graphics.setColor(hoverBack and 0.25 or 0.15, hoverBack and 0.3 or 0.15, hoverBack and 0.4 or 0.2)
    love.graphics.rectangle('fill', backX, backY, backW, backH, 4, 4)
    love.graphics.setColor(0.4, 0.5, 0.6)
    love.graphics.rectangle('line', backX, backY, backW, backH, 4, 4)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print('Back', backX + backW / 2 - font:getWidth('Back') / 2, backY + 7)
end

---------------------------------------------------------------------------
-- Input: mouse
---------------------------------------------------------------------------

--- closeFn: called when user clicks Back or ESC (closes the panel).
--- toastFn(msg): called after a save operation to display a toast.
--- loadFn(slotId): called when user clicks a slot to load it. Caller handles the actual load.
function SaveMenu.mousepressed(x, y, button, closeFn, toastFn, loadFn)
    if button ~= 1 then return true end

    local sok, Save = pcall(require, 'src.persistence.save')
    if not sok then return true end

    -- Back button
    if hoverBack then
        namingSlot = nil
        closeFn()
        return true
    end

    -- Auto-save interval buttons
    if mode == 'save' then
        if hoverIntervalDn then
            Save.setAutoSaveInterval(autoInterval - 1)
            autoInterval = Save.getAutoSaveInterval()
            return true
        end
        if hoverIntervalUp then
            Save.setAutoSaveInterval(autoInterval + 1)
            autoInterval = Save.getAutoSaveInterval()
            return true
        end
    end

    -- Delete button
    if hoverDelete then
        Save.deleteSlot(hoverDelete)
        SaveMenu.refreshSlots()
        return true
    end

    -- Slot click
    if hoverSlot then
        if mode == 'save' then
            -- If clicking a manual slot, enter naming mode
            local slotType = nil
            for _, s in ipairs(slotList) do
                if s.id == hoverSlot then slotType = s.type; break end
            end
            if slotType == 'manual' then
                if namingSlot == hoverSlot then
                    -- Already naming this slot: confirm save
                    local name = namingText ~= '' and namingText or nil
                    Save.saveToSlot(hoverSlot, name)
                    namingSlot = nil
                    namingText = ''
                    SaveMenu.refreshSlots()
                    if toastFn then toastFn('Saved to ' .. hoverSlot) end
                else
                    -- Start naming
                    namingSlot = hoverSlot
                    -- Pre-fill with colony name + day
                    namingText = (GameState.colonyName or 'Frosthold') .. ' Day ' .. GameState.day
                end
            end
        else
            -- Load mode: load the slot
            local hasMeta = false
            for _, s in ipairs(slotList) do
                if s.id == hoverSlot and s.meta then hasMeta = true; break end
            end
            if hasMeta then
                namingSlot = nil
                if loadFn then
                    loadFn(hoverSlot)
                else
                    -- Default: load directly (in-game pause menu path)
                    Save.loadSlot(hoverSlot)
                    closeFn()
                    GameState.paused = false
                    if toastFn then toastFn('Loaded ' .. hoverSlot) end
                end
            end
        end
        return true
    end

    -- Click outside naming cancels it
    if namingSlot then
        namingSlot = nil
        namingText = ''
    end

    return true  -- consume all clicks when panel is open
end

---------------------------------------------------------------------------
-- Input: keyboard (for slot naming)
---------------------------------------------------------------------------

function SaveMenu.keypressed(key, closeFn, toastFn)
    if key == 'escape' then
        if namingSlot then
            namingSlot = nil
            namingText = ''
        else
            closeFn()
        end
        return true
    end

    if namingSlot then
        local sok, Save = pcall(require, 'src.persistence.save')
        if key == 'return' then
            -- Confirm save
            if sok then
                local name = namingText ~= '' and namingText or nil
                Save.saveToSlot(namingSlot, name)
                namingSlot = nil
                namingText = ''
                SaveMenu.refreshSlots()
                if toastFn then toastFn('Game Saved') end
            end
            return true
        elseif key == 'backspace' then
            namingText = namingText:sub(1, -2)
            return true
        end
    end

    return false
end

---------------------------------------------------------------------------
-- Input: text input (for slot naming)
---------------------------------------------------------------------------

function SaveMenu.textinput(text)
    if namingSlot then
        -- Limit name length
        if #namingText < 40 then
            namingText = namingText .. text
        end
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Input: scroll
---------------------------------------------------------------------------

function SaveMenu.wheelmoved(x, y)
    local totalH = #slotList * (SLOT_H + SLOT_GAP)
    local listH = PANEL_H - HEADER_H - FOOTER_H
    local maxScroll = math.max(0, totalH - listH)
    scrollOffset = math.max(0, math.min(maxScroll, scrollOffset - y * 30))
    return true
end

function SaveMenu.getMode()
    return mode
end

function SaveMenu.isNaming()
    return namingSlot ~= nil
end

return SaveMenu