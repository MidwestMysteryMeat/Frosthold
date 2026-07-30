-- trade_panel.lua — Merchant trading interface with quantity selector

local GameState = require('src.game_state')
local Layout    = require('src.ui.ui_layout')

local TradePanel = {}

local visible = false
local scrollY = 0
local buyRects = {}
local sellRects = {}
local buyPlusRects = {}
local buyMinusRects = {}
local sellPlusRects = {}
local sellMinusRects = {}

-- Quantity state per item (reset when panel closes or merchant changes)
local buyQty = {}       -- { [itemName] = int }
local sellQty = {}      -- { [itemName] = int }
local lastMerchantId = nil

local function resetQuantities()
    buyQty = {}
    sellQty = {}
end

local function clampBuyQty(item, stock, pricePerUnit)
    local cores = GameState.resources.thermalCores or 0
    local maxAfford = pricePerUnit > 0 and math.floor(cores / pricePerUnit) or 0
    local maxQty = math.min(stock, maxAfford)
    local qty = buyQty[item] or 1
    qty = math.max(1, math.min(qty, maxQty))
    buyQty[item] = qty
    return qty
end

local function clampSellQty(item, available)
    local qty = sellQty[item] or 1
    qty = math.max(1, math.min(qty, available))
    sellQty[item] = qty
    return qty
end

-- Determine quantity step based on modifier keys
local function getModifierStep()
    local shift = love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')
    local ctrl = love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
    if ctrl then
        return 'max'
    elseif shift then
        return 5
    end
    return 1
end

function TradePanel.toggle()
    visible = not visible
    scrollY = 0
    if not visible then
        resetQuantities()
    end
end

function TradePanel.isVisible()
    return visible
end

function TradePanel.draw()
    if not visible then return end

    local mok, Merchants = pcall(require, 'src.trade.merchants')
    if not mok then return end

    local merchant = Merchants.getActiveMerchant and Merchants.getActiveMerchant()

    -- Reset quantities when merchant changes
    local merchId = merchant and merchant.id or nil
    if merchId ~= lastMerchantId then
        resetQuantities()
        lastMerchantId = merchId
    end

    local sw, sh = love.graphics.getDimensions()
    buyRects = {}
    sellRects = {}
    buyPlusRects = {}
    buyMinusRects = {}
    sellPlusRects = {}
    sellMinusRects = {}

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header
    love.graphics.setColor(0.1, 0.12, 0.16)
    love.graphics.rectangle('fill', 0, 0, sw, 50)
    love.graphics.setColor(0.25, 0.35, 0.45)
    love.graphics.line(0, 50, sw, 50)

    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.print('TRADE', 20, 16)
    love.graphics.setColor(0.45, 0.45, 0.45)
    do
        local hint = 'T / ESC to close'
        love.graphics.print(hint, sw - Layout.textWidth(hint) - 20, 16)
    end

    -- Thermal cores balance
    love.graphics.setColor(1, 0.5, 0.2)
    Layout.printCentered(string.format('Thermal Cores: %d',
        GameState.resources.thermalCores or 0), { x = 0, y = 0, w = sw, h = 50 }, 16)

    if not merchant or not (Merchants.isTrading and Merchants.isTrading()) then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No merchant currently trading.', sw / 2 - 120, sh / 2 - 20)
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('Merchants arrive via storyteller events.', sw / 2 - 140, sh / 2)
        return
    end

    -- Merchant info
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(string.format('Merchant: %s',
        merchant.name or merchant.type or '???'), 20, 58)

    if merchant.stayTimer then
        local mins = math.floor(merchant.stayTimer / 60)
        local secs = math.floor(merchant.stayTimer % 60)
        love.graphics.setColor(0.6, 0.5, 0.4)
        love.graphics.print(string.format('Departing in: %d:%02d', mins, secs), sw - 200, 58)
    end

    -- Modifier hint
    love.graphics.setColor(0.35, 0.35, 0.4)
    love.graphics.print('Shift+click: +/-5  |  Ctrl+click: max', sw / 2 - 130, 58)

    local midX = math.floor(sw / 2)
    local rowH = 38  -- taller rows for quantity controls

    ---------------------------------------------------------------------------
    -- Left: Buy from merchant
    ---------------------------------------------------------------------------

    love.graphics.setColor(0.7, 0.8, 0.7)
    love.graphics.print('BUY (from merchant)', 20, 80)

    -- Rows stop above the trade log; the log now stops above the bottom
    -- toolbar, which the last log line used to disappear underneath.
    local rowsBottom = sh - Layout.BOTTOM_RESERVE - 80
    local by = 100 - scrollY
    if merchant.inventory then
        for _, slot in ipairs(merchant.inventory) do
            if by > 50 and by + rowH < rowsBottom then
                local itemName = slot.item or '?'
                local stock = slot.stock or 0
                local unitPrice = slot.buyPrice or 0
                local colW = midX - 40

                -- Row background
                love.graphics.setColor(0.07, 0.07, 0.09)
                love.graphics.rectangle('fill', 20, by, colW, rowH - 2, 2)
                love.graphics.setColor(0.18, 0.18, 0.22)
                love.graphics.rectangle('line', 20, by, colW, rowH - 2, 2)

                -- Item name and stock
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.print(Layout.fitLabel(itemName, 28, 150), 28, by + 4)
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print(string.format('stock: %d', stock), 28, by + 18)

                -- Unit price
                love.graphics.setColor(1, 0.5, 0.2)
                love.graphics.print(string.format('%d ea', unitPrice), 150, by + 4)

                local cores = GameState.resources.thermalCores or 0
                local canBuyAny = stock > 0 and cores >= unitPrice and unitPrice > 0

                -- Quantity selector: [-] qty [+]
                local qtyX = 150
                local qtyY = by + 16
                local btnW = 20
                local btnH = 16

                local qty = 1
                if canBuyAny then
                    qty = clampBuyQty(itemName, stock, unitPrice)
                end

                -- Minus button
                local minusEnabled = canBuyAny and qty > 1
                if minusEnabled then
                    love.graphics.setColor(0.15, 0.15, 0.2)
                else
                    love.graphics.setColor(0.08, 0.08, 0.1)
                end
                love.graphics.rectangle('fill', qtyX, qtyY, btnW, btnH, 2)
                love.graphics.setColor(minusEnabled and 0.7 or 0.3, minusEnabled and 0.7 or 0.3, minusEnabled and 0.7 or 0.3)
                love.graphics.print('-', qtyX + 6, qtyY)
                if minusEnabled then
                    buyMinusRects[#buyMinusRects + 1] = {
                        x = qtyX, y = qtyY, w = btnW, h = btnH, item = itemName,
                        stock = stock, unitPrice = unitPrice
                    }
                end

                -- Quantity display
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.print(string.format('%d', qty), qtyX + btnW + 4, qtyY)

                -- Plus button
                local maxAfford = unitPrice > 0 and math.floor(cores / unitPrice) or 0
                local maxQty = math.min(stock, maxAfford)
                local plusEnabled = canBuyAny and qty < maxQty
                local plusX = qtyX + btnW + 28
                if plusEnabled then
                    love.graphics.setColor(0.15, 0.15, 0.2)
                else
                    love.graphics.setColor(0.08, 0.08, 0.1)
                end
                love.graphics.rectangle('fill', plusX, qtyY, btnW, btnH, 2)
                love.graphics.setColor(plusEnabled and 0.7 or 0.3, plusEnabled and 0.7 or 0.3, plusEnabled and 0.7 or 0.3)
                love.graphics.print('+', plusX + 5, qtyY)
                if plusEnabled then
                    buyPlusRects[#buyPlusRects + 1] = {
                        x = plusX, y = qtyY, w = btnW, h = btnH, item = itemName,
                        stock = stock, unitPrice = unitPrice
                    }
                end

                -- Total cost
                local totalCost = unitPrice * qty
                love.graphics.setColor(1, 0.6, 0.3)
                love.graphics.print(string.format('= %d cores', totalCost), plusX + btnW + 8, qtyY)

                -- Buy button
                local buyBtnX = midX - 80
                if canBuyAny then
                    love.graphics.setColor(0.12, 0.28, 0.12)
                else
                    love.graphics.setColor(0.08, 0.08, 0.08)
                end
                love.graphics.rectangle('fill', buyBtnX, by + 6, 50, rowH - 14, 2)
                love.graphics.setColor(canBuyAny and 0.4 or 0.2, canBuyAny and 0.8 or 0.2, canBuyAny and 0.4 or 0.2)
                love.graphics.print('Buy', buyBtnX + 12, by + 10)

                if canBuyAny then
                    buyRects[#buyRects + 1] = {
                        x = buyBtnX, y = by + 6, w = 50, h = rowH - 14,
                        item = itemName, qty = qty
                    }
                end
            end
            by = by + rowH
        end
    end

    ---------------------------------------------------------------------------
    -- Right: Sell to merchant
    ---------------------------------------------------------------------------

    love.graphics.setColor(0.8, 0.7, 0.7)
    love.graphics.print('SELL (to merchant)', midX + 10, 80)

    -- Build sell price lookup from merchant inventory
    local sellPriceLookup = {}
    if merchant.inventory then
        for _, slot in ipairs(merchant.inventory) do
            if slot.sellPrice and slot.sellPrice > 0 then
                sellPriceLookup[slot.item] = slot.sellPrice
            end
        end
    end

    local sy = 100 - scrollY
    local sellable = {}
    for name, amount in pairs(GameState.resources) do
        if amount > 0 and name ~= 'thermalCores' then
            sellable[#sellable + 1] = { name = name, amount = amount }
        end
    end
    table.sort(sellable, function(a, b) return a.name < b.name end)

    for _, res in ipairs(sellable) do
        if sy > 50 and sy + rowH < rowsBottom then
            local colW = midX - 30
            local sellPrice = sellPriceLookup[res.name]
            local canSell = sellPrice and sellPrice > 0

            -- Row background
            love.graphics.setColor(0.07, 0.07, 0.09)
            love.graphics.rectangle('fill', midX + 10, sy, colW, rowH - 2, 2)
            love.graphics.setColor(0.18, 0.18, 0.22)
            love.graphics.rectangle('line', midX + 10, sy, colW, rowH - 2, 2)

            -- Resource name and owned amount
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(Layout.fitLabel(res.name, midX + 18, midX + 150), midX + 18, sy + 4)
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print(string.format('owned: %d', res.amount), midX + 18, sy + 18)

            if canSell then
                -- Unit sell price
                love.graphics.setColor(0.2, 0.8, 1)
                love.graphics.print(string.format('%d ea', sellPrice), midX + 150, sy + 4)

                -- Quantity selector: [-] qty [+]
                local qtyX = midX + 150
                local qtyY = sy + 16
                local btnW = 20
                local btnH = 16

                local qty = clampSellQty(res.name, res.amount)

                -- Minus button
                local minusEnabled = qty > 1
                if minusEnabled then
                    love.graphics.setColor(0.15, 0.15, 0.2)
                else
                    love.graphics.setColor(0.08, 0.08, 0.1)
                end
                love.graphics.rectangle('fill', qtyX, qtyY, btnW, btnH, 2)
                love.graphics.setColor(minusEnabled and 0.7 or 0.3, minusEnabled and 0.7 or 0.3, minusEnabled and 0.7 or 0.3)
                love.graphics.print('-', qtyX + 6, qtyY)
                if minusEnabled then
                    sellMinusRects[#sellMinusRects + 1] = {
                        x = qtyX, y = qtyY, w = btnW, h = btnH, item = res.name,
                        available = res.amount
                    }
                end

                -- Quantity display
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.print(string.format('%d', qty), qtyX + btnW + 4, qtyY)

                -- Plus button
                local plusEnabled = qty < res.amount
                local plusX = qtyX + btnW + 28
                if plusEnabled then
                    love.graphics.setColor(0.15, 0.15, 0.2)
                else
                    love.graphics.setColor(0.08, 0.08, 0.1)
                end
                love.graphics.rectangle('fill', plusX, qtyY, btnW, btnH, 2)
                love.graphics.setColor(plusEnabled and 0.7 or 0.3, plusEnabled and 0.7 or 0.3, plusEnabled and 0.7 or 0.3)
                love.graphics.print('+', plusX + 5, qtyY)
                if plusEnabled then
                    sellPlusRects[#sellPlusRects + 1] = {
                        x = plusX, y = qtyY, w = btnW, h = btnH, item = res.name,
                        available = res.amount
                    }
                end

                -- Total earned
                local totalEarned = sellPrice * qty
                love.graphics.setColor(0.3, 0.9, 1)
                love.graphics.print(string.format('= %d cores', totalEarned), plusX + btnW + 8, qtyY)

                -- Sell button
                local sellBtnX = sw - 80
                love.graphics.setColor(0.28, 0.12, 0.12)
                love.graphics.rectangle('fill', sellBtnX, sy + 6, 50, rowH - 14, 2)
                love.graphics.setColor(0.8, 0.4, 0.4)
                love.graphics.print('Sell', sellBtnX + 10, sy + 10)

                sellRects[#sellRects + 1] = {
                    x = sellBtnX, y = sy + 6, w = 50, h = rowH - 14,
                    item = res.name, qty = qty
                }
            else
                -- Merchant does not buy this item
                love.graphics.setColor(0.35, 0.3, 0.3)
                love.graphics.print('no buyer', midX + 150, sy + 10)
            end
        end
        sy = sy + rowH
    end

    ---------------------------------------------------------------------------
    -- Trade log
    ---------------------------------------------------------------------------

    local tradeLog = Merchants.getLog and Merchants.getLog() or {}
    if #tradeLog > 0 then
        local logTop = sh - Layout.BOTTOM_RESERVE - 76
        love.graphics.setColor(0.25, 0.3, 0.35)
        love.graphics.line(20, logTop, sw - 20, logTop)
        love.graphics.setColor(0.55, 0.55, 0.5)
        love.graphics.print('Recent trades:', 20, logTop + 6)
        local ly = logTop + 22
        for i = #tradeLog, math.max(1, #tradeLog - 3), -1 do
            love.graphics.setColor(0.5, 0.5, 0.4)
            love.graphics.print(Layout.truncate(tradeLog[i].msg or '', sw - 40), 20, ly)
            ly = ly + 14
        end
    end
end

function TradePanel.keypressed(key)
    if not visible then return false end
    if key == 't' or key == 'escape' then
        visible = false
        resetQuantities()
        return true
    end
    return true
end

function TradePanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end

    local step = getModifierStep()

    local mok, Merchants = pcall(require, 'src.trade.merchants')
    if not mok then return true end
    local trading = Merchants.isTrading and Merchants.isTrading()

    -- Buy quantity +/- buttons
    for _, rect in ipairs(buyMinusRects) do
        if x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h then
            local cur = buyQty[rect.item] or 1
            if step == 'max' then
                buyQty[rect.item] = 1
            else
                buyQty[rect.item] = math.max(1, cur - step)
            end
            return true
        end
    end
    for _, rect in ipairs(buyPlusRects) do
        if x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h then
            local cur = buyQty[rect.item] or 1
            local cores = GameState.resources.thermalCores or 0
            local maxAfford = rect.unitPrice > 0 and math.floor(cores / rect.unitPrice) or 0
            local maxQty = math.min(rect.stock, maxAfford)
            if step == 'max' then
                buyQty[rect.item] = maxQty
            else
                buyQty[rect.item] = math.min(maxQty, cur + step)
            end
            return true
        end
    end

    -- Sell quantity +/- buttons
    for _, rect in ipairs(sellMinusRects) do
        if x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h then
            local cur = sellQty[rect.item] or 1
            if step == 'max' then
                sellQty[rect.item] = 1
            else
                sellQty[rect.item] = math.max(1, cur - step)
            end
            return true
        end
    end
    for _, rect in ipairs(sellPlusRects) do
        if x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h then
            local cur = sellQty[rect.item] or 1
            if step == 'max' then
                sellQty[rect.item] = rect.available
            else
                sellQty[rect.item] = math.min(rect.available, cur + step)
            end
            return true
        end
    end

    -- Buy / Sell execution buttons
    if trading then
        for _, rect in ipairs(buyRects) do
            if x >= rect.x and x <= rect.x + rect.w
            and y >= rect.y and y <= rect.y + rect.h then
                local qty = rect.qty or 1
                if step == 'max' then
                    -- When Ctrl+clicking Buy, trade max affordable quantity
                    qty = 9999
                elseif step == 5 then
                    qty = math.max(1, qty * 5)
                end
                Merchants.buyItem(rect.item, qty)
                -- Reset quantity after trade (stock changed)
                buyQty[rect.item] = nil
                return true
            end
        end
        for _, rect in ipairs(sellRects) do
            if x >= rect.x and x <= rect.x + rect.w
            and y >= rect.y and y <= rect.y + rect.h then
                local qty = rect.qty or 1
                if step == 'max' then
                    qty = 9999
                elseif step == 5 then
                    qty = math.max(1, qty * 5)
                end
                Merchants.sellItem(rect.item, qty)
                -- Reset quantity after trade (inventory changed)
                sellQty[rect.item] = nil
                return true
            end
        end
    end

    return true
end

function TradePanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return TradePanel
