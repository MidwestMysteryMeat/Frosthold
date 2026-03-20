-- requisition_panel.lua — Mammona Requisition screen
-- Full-screen panel for spending MRP on permanent unlocks or per-run picks.
-- Two modes: 'unlocks' (permanent purchases) and 'picks' (per-run deployment bonuses).

local GameState = require('src.game_state')

local RequisitionPanel = {}

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local ITEM_H       = 60
local ITEM_PAD     = 4
local SIDEBAR_W    = 180
local HEADER_H     = 80
local FOOTER_H     = 50

-- Category display metadata
local CATEGORY_LABELS = {
    genetic    = 'GENETIC PROGRAM',
    knowledge  = 'CORPORATE KNOWLEDGE',
    operations = 'OPERATIONAL UPGRADES',
    augment    = 'COLONIST AUGMENTS',
    deployment = 'DEPLOYMENT BONUSES',
}

local CATEGORY_COLORS = {
    genetic    = {0.4, 0.75, 0.5},
    knowledge  = {0.5, 0.65, 0.85},
    operations = {0.8, 0.6, 0.3},
    augment    = {0.7, 0.45, 0.7},
    deployment = {0.6, 0.7, 0.5},
}

-- Category ordering per mode
local UNLOCK_CATEGORIES = { 'genetic', 'knowledge', 'operations' }
local PICK_CATEGORIES   = { 'augment', 'deployment' }

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local mode          = 'unlocks'   -- 'unlocks' or 'picks'
local done          = false
local selectedIndex = 1
local scrollY       = 0
local items         = {}          -- flat list of displayable items
local picksPurchased = {}         -- list of pick ids bought this session

-- Fonts (created lazily)
local titleFont, headerFont, bodyFont, smallFont

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function getMRP()
    local ok, MRP = pcall(require, 'src.sim.mrp')
    if ok then return MRP end
    return nil
end

local function buildItemList()
    local MRP = getMRP()
    if not MRP then items = {}; return end

    items = {}
    local tier = MRP.getTier()

    if mode == 'unlocks' then
        local categories = UNLOCK_CATEGORIES
        for _, cat in ipairs(categories) do
            for _, unlock in ipairs(MRP.PERMANENT_UNLOCKS) do
                if unlock.category == cat then
                    items[#items + 1] = {
                        id       = unlock.id,
                        name     = unlock.name,
                        cost     = unlock.cost,
                        tier     = unlock.tier,
                        category = unlock.category,
                        desc     = unlock.desc,
                        owned    = MRP.hasUnlock(unlock.id),
                        locked   = unlock.tier > tier,
                    }
                end
            end
        end
    else
        local categories = PICK_CATEGORIES
        for _, cat in ipairs(categories) do
            for _, pick in ipairs(MRP.PER_RUN_PICKS) do
                if pick.category == cat then
                    items[#items + 1] = {
                        id       = pick.id,
                        name     = pick.name,
                        cost     = pick.cost,
                        category = pick.category,
                        desc     = pick.desc,
                        targetColonist = pick.targetColonist,
                    }
                end
            end
        end
    end
end

local function clampScroll(sh)
    local contentH = #items * (ITEM_H + ITEM_PAD) + 40
    local viewH = sh - HEADER_H - FOOTER_H
    local maxScroll = math.max(0, contentH - viewH)
    scrollY = math.max(0, math.min(scrollY, maxScroll))
end

local function ensureSelectedVisible(sh)
    local viewH = sh - HEADER_H - FOOTER_H
    local itemTop = (selectedIndex - 1) * (ITEM_H + ITEM_PAD)
    local itemBot = itemTop + ITEM_H
    if itemTop - scrollY < 0 then
        scrollY = itemTop
    elseif itemBot - scrollY > viewH then
        scrollY = itemBot - viewH
    end
    clampScroll(sh)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function RequisitionPanel.init(newMode)
    mode = newMode or 'unlocks'
    done = false
    selectedIndex = 1
    scrollY = 0
    if mode == 'picks' then
        picksPurchased = {}
    end

    if love and love.graphics then
        titleFont  = love.graphics.newFont(24)
        headerFont = love.graphics.newFont(14)
        bodyFont   = love.graphics.newFont(12)
        smallFont  = love.graphics.newFont(10)
    end

    buildItemList()
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function RequisitionPanel.draw()
    local MRP = getMRP()
    if not MRP then return end

    local sw, sh = love.graphics.getDimensions()
    clampScroll(sh)

    -- Background
    love.graphics.clear(0.03, 0.04, 0.08)

    -- Header bar
    love.graphics.setColor(0.08, 0.1, 0.15)
    love.graphics.rectangle('fill', 0, 0, sw, HEADER_H)
    love.graphics.setColor(0.2, 0.3, 0.4)
    love.graphics.line(0, HEADER_H, sw, HEADER_H)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.9, 0.85, 0.7)
    if mode == 'unlocks' then
        love.graphics.print('MAMMONA REQUISITION', 20, 12)
    else
        love.graphics.print('DEPLOYMENT REQUISITION', 20, 12)
    end

    -- Subtitle
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.5, 0.55, 0.65)
    if mode == 'unlocks' then
        love.graphics.print('Permanent upgrades across all future deployments', 20, 42)
    else
        love.graphics.print('One-time bonuses for this deployment only', 20, 42)
    end

    -- Balance (gold text, top right)
    love.graphics.setFont(headerFont)
    love.graphics.setColor(0.95, 0.85, 0.35)
    local balText = string.format('MRP: %d', MRP.getBalance())
    local balW = headerFont:getWidth(balText)
    love.graphics.print(balText, sw - balW - 20, 14)

    -- Tier info
    love.graphics.setFont(smallFont)
    local tier = MRP.getTier()
    local lifetime = MRP.getLifetime()
    local tierThresholds = { 100, 250, 500, 1000 }
    local nextThreshold = tierThresholds[tier + 1]
    local tierText
    if nextThreshold then
        tierText = string.format('Tier %d  (%d / %d to next)', tier, lifetime, nextThreshold)
    else
        tierText = string.format('Tier %d  (MAX)', tier)
    end
    love.graphics.setColor(0.6, 0.65, 0.75)
    local tierW = smallFont:getWidth(tierText)
    love.graphics.print(tierText, sw - tierW - 20, 38)

    -- Picks purchased count (picks mode only)
    if mode == 'picks' and #picksPurchased > 0 then
        love.graphics.setColor(0.5, 0.8, 0.5)
        local pickText = string.format('Picks purchased: %d', #picksPurchased)
        local pickW = smallFont:getWidth(pickText)
        love.graphics.print(pickText, sw - pickW - 20, 54)
    end

    -- Footer bar
    love.graphics.setColor(0.08, 0.1, 0.15)
    love.graphics.rectangle('fill', 0, sh - FOOTER_H, sw, FOOTER_H)
    love.graphics.setColor(0.2, 0.3, 0.4)
    love.graphics.line(0, sh - FOOTER_H, sw, sh - FOOTER_H)

    -- Footer controls
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.5, 0.55, 0.65)
    love.graphics.print('UP/DOWN: Navigate    ENTER: Purchase    ESC: Continue', 20, sh - FOOTER_H + 18)

    -- Item list area
    local listX = 20
    local listW = sw - 40
    local listTop = HEADER_H
    local listBot = sh - FOOTER_H

    love.graphics.setScissor(listX, listTop, listW, listBot - listTop)

    local y = listTop + 10 - scrollY
    local lastCat = nil

    for i, item in ipairs(items) do
        -- Category header
        if item.category ~= lastCat then
            lastCat = item.category
            local catLabel = CATEGORY_LABELS[item.category] or item.category:upper()
            local catColor = CATEGORY_COLORS[item.category] or {0.6, 0.6, 0.6}

            if y >= listTop - 20 and y <= listBot then
                love.graphics.setFont(smallFont)
                love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.8)
                love.graphics.print(catLabel, listX + 4, y + 2)
                love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.3)
                local labelW = smallFont:getWidth(catLabel)
                love.graphics.line(listX + labelW + 10, y + 10, listX + listW, y + 10)
            end
            y = y + 20
        end

        -- Item row
        local isSelected = (i == selectedIndex)
        local canAfford = MRP.getBalance() >= item.cost
        local isOwned = item.owned
        local isLocked = item.locked

        if y + ITEM_H >= listTop and y <= listBot then
            -- Background
            if isSelected then
                love.graphics.setColor(0.12, 0.18, 0.28, 0.95)
            else
                love.graphics.setColor(0.06, 0.08, 0.12, 0.85)
            end
            love.graphics.rectangle('fill', listX, y, listW, ITEM_H, 4)

            -- Border
            if isSelected then
                local catColor = CATEGORY_COLORS[item.category] or {0.5, 0.6, 0.7}
                love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.8)
            else
                love.graphics.setColor(0.2, 0.25, 0.35, 0.5)
            end
            love.graphics.rectangle('line', listX, y, listW, ITEM_H, 4)

            -- Dim overlay for unaffordable or locked items
            local textAlpha = 1.0
            if isLocked or (not canAfford and not isOwned) then
                textAlpha = 0.4
                love.graphics.setColor(0.02, 0.03, 0.06, 0.5)
                love.graphics.rectangle('fill', listX, y, listW, ITEM_H, 4)
            end

            -- Item name
            love.graphics.setFont(headerFont)
            love.graphics.setColor(0.9, 0.9, 0.95, textAlpha)
            love.graphics.print(item.name, listX + 12, y + 8)

            -- Cost badge
            love.graphics.setFont(smallFont)
            if isOwned then
                love.graphics.setColor(0.3, 0.8, 0.3, 0.9)
                love.graphics.print('OWNED', listX + listW - 60, y + 10)
            elseif isLocked then
                love.graphics.setColor(0.6, 0.4, 0.3, 0.7)
                local lockText = string.format('Locked (Tier %d)', item.tier)
                local lockW = smallFont:getWidth(lockText)
                love.graphics.print(lockText, listX + listW - lockW - 12, y + 10)
            else
                if canAfford then
                    love.graphics.setColor(0.95, 0.85, 0.35, textAlpha)
                else
                    love.graphics.setColor(0.7, 0.35, 0.3, textAlpha)
                end
                local costText = string.format('%d MRP', item.cost)
                local costW = smallFont:getWidth(costText)
                love.graphics.print(costText, listX + listW - costW - 12, y + 10)
            end

            -- Description
            love.graphics.setFont(bodyFont)
            love.graphics.setColor(0.55, 0.6, 0.7, textAlpha)
            love.graphics.print(item.desc, listX + 12, y + 32)

            -- Target colonist badge (picks mode)
            if item.targetColonist and not isOwned and not isLocked then
                love.graphics.setFont(smallFont)
                love.graphics.setColor(0.6, 0.5, 0.7, textAlpha * 0.7)
                love.graphics.print('[Per Colonist]', listX + 12, y + 48)
            end
        end

        y = y + ITEM_H + ITEM_PAD
    end

    love.graphics.setScissor()

    -- Scroll indicator
    local contentH = y + scrollY - listTop - 10
    local viewH = listBot - listTop
    if contentH > viewH then
        local barH = math.max(20, (viewH / contentH) * viewH)
        local barY = listTop + (scrollY / (contentH - viewH)) * (viewH - barH)
        love.graphics.setColor(0.3, 0.35, 0.45, 0.5)
        love.graphics.rectangle('fill', sw - 10, barY, 6, barH, 3)
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function RequisitionPanel.keypressed(key)
    local MRP = getMRP()
    if not MRP then return end

    local sh = 720
    if love and love.graphics then
        local _, h = love.graphics.getDimensions()
        sh = h
    end

    if key == 'up' then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then selectedIndex = #items end
        ensureSelectedVisible(sh)
    elseif key == 'down' then
        selectedIndex = selectedIndex + 1
        if selectedIndex > #items then selectedIndex = 1 end
        ensureSelectedVisible(sh)
    elseif key == 'return' or key == 'kpenter' then
        if #items == 0 then return end
        local item = items[selectedIndex]
        if not item then return end

        if mode == 'unlocks' then
            if item.owned or item.locked then return end
            if MRP.purchaseUnlock(item.id, item.cost) then
                item.owned = true
                MRP.save()
            end
        else
            -- Per-run picks: can buy multiples, deducts from balance
            if MRP.spend(item.cost) then
                picksPurchased[#picksPurchased + 1] = item.id
                MRP.save()
            end
        end
        -- Refresh affordability
        buildItemList()
        if selectedIndex > #items then selectedIndex = math.max(1, #items) end
    elseif key == 'escape' then
        done = true
    end
end

function RequisitionPanel.wheelmoved(dx, dy)
    scrollY = scrollY - dy * 30
    local sh = 720
    if love and love.graphics then
        local _, h = love.graphics.getDimensions()
        sh = h
    end
    clampScroll(sh)
end

function RequisitionPanel.mousepressed(x, y, button)
    if button ~= 1 then return end
    local MRP = getMRP()
    if not MRP then return end

    local sw, sh = love.graphics.getDimensions()
    local listX = 20
    local listW = sw - 40
    local listTop = HEADER_H

    -- Map click position to item index
    local relY = y - listTop - 10 + scrollY
    local curY = 0
    local lastCat = nil
    for i, item in ipairs(items) do
        if item.category ~= lastCat then
            lastCat = item.category
            curY = curY + 20
        end
        if relY >= curY and relY < curY + ITEM_H then
            if x >= listX and x <= listX + listW then
                selectedIndex = i
                return
            end
        end
        curY = curY + ITEM_H + ITEM_PAD
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function RequisitionPanel.isDone()
    return done
end

function RequisitionPanel.getPicksPurchased()
    return picksPurchased
end

function RequisitionPanel.getMode()
    return mode
end

return RequisitionPanel
