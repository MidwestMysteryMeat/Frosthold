-- faction_panel.lua — Faction diplomacy and trade route panel
-- Shows all factions, reputation bars, standings, trade modifiers, gift buttons,
-- and trade route management (establish/cancel for allied factions).
-- Toggle with F key.

local GameState = require('src.game_state')

local FactionPanel = {}

local visible = false
local scrollY = 0
local hitZones = {}

-- Lazy-loaded modules
local _Factions, _TradeRoutes
local function lazyLoad()
    if _Factions ~= nil then return end
    local ok
    ok, _Factions = pcall(require, 'src.colony.factions')
    if not ok then _Factions = false end
    ok, _TradeRoutes = pcall(require, 'src.trade.trade_routes')
    if not ok then _TradeRoutes = false end
end

-- Colors
local C = {
    bg         = { 0, 0, 0, 0.92 },
    header     = { 0.08, 0.1, 0.14 },
    headerLine = { 0.25, 0.35, 0.5 },
    label      = { 0.8, 0.8, 0.8 },
    dim        = { 0.5, 0.5, 0.5 },
    white      = { 1, 1, 1 },
    cardBg     = { 0.06, 0.07, 0.09, 0.8 },
    cardHover  = { 0.1, 0.12, 0.16, 0.9 },
    hostile    = { 0.9, 0.25, 0.2 },
    unfriendly = { 0.85, 0.5, 0.2 },
    neutral    = { 0.6, 0.6, 0.6 },
    friendly   = { 0.3, 0.7, 0.4 },
    allied     = { 0.3, 0.6, 0.9 },
    repBarBg   = { 0.15, 0.15, 0.15 },
    repBarNeg  = { 0.7, 0.2, 0.15 },
    repBarPos  = { 0.2, 0.55, 0.3 },
    giftBtn    = { 0.2, 0.35, 0.5, 0.9 },
    giftBtnHov = { 0.3, 0.45, 0.6, 1 },
    routeBtn   = { 0.2, 0.4, 0.25, 0.9 },
    routeBtnHov = { 0.3, 0.5, 0.35, 1 },
    cancelBtn  = { 0.5, 0.2, 0.15, 0.9 },
    cancelBtnHov = { 0.65, 0.3, 0.2, 1 },
    tradeGood  = { 0.6, 0.7, 0.5 },
    bonus      = { 0.5, 0.7, 0.9 },
    disrupted  = { 0.9, 0.5, 0.2 },
    routeActive = { 0.3, 0.65, 0.4 },
}

local STANDING_COLORS = {
    hostile    = C.hostile,
    unfriendly = C.unfriendly,
    neutral    = C.neutral,
    friendly   = C.friendly,
    allied     = C.allied,
}

---------------------------------------------------------------------------
-- Toggle
---------------------------------------------------------------------------

function FactionPanel.toggle()
    visible = not visible
    scrollY = 0
    hitZones = {}
end

function FactionPanel.isVisible()
    return visible
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function addZone(id, x, y, w, h, action, data)
    hitZones[#hitZones + 1] = { id = id, x = x, y = y, w = w, h = h, action = action, data = data }
end

local function showToast(msg)
    local uok, UIMod = pcall(require, 'src.ui.ui')
    if uok and UIMod.showSaveToast then UIMod.showSaveToast(msg) end
end

local GIFT_AMOUNT = 5

---------------------------------------------------------------------------
-- Draw a single faction card, returns card height used
---------------------------------------------------------------------------

local function drawFactionCard(fac, def, cardX, y, cardW, mx, my)
    local hasRoute = _TradeRoutes and _TradeRoutes.hasRoute(fac.id)
    local isAllied = fac.standing == 'allied'
    local cardH = hasRoute and 130 or (isAllied and 130 or 110)

    -- Card background
    local isHover = mx >= cardX and mx <= cardX + cardW and my >= y and my < y + cardH
    if isHover then
        love.graphics.setColor(C.cardHover)
    else
        love.graphics.setColor(C.cardBg)
    end
    love.graphics.rectangle('fill', cardX, y, cardW, cardH, 3, 3)

    -- Faction name
    love.graphics.setColor(C.white)
    love.graphics.print(fac.name, cardX + 10, y + 6)

    -- Standing badge
    local standColor = STANDING_COLORS[fac.standing] or C.neutral
    love.graphics.setColor(standColor)
    local standLabel = (fac.standing or 'neutral'):upper()
    love.graphics.print(standLabel, cardX + cardW - 80, y + 6)

    -- Description
    love.graphics.setColor(C.dim)
    love.graphics.print(fac.desc or '', cardX + 10, y + 22)

    -- Reputation bar: -100 to +100, centered at midpoint
    local barX = cardX + 10
    local barY = y + 40
    local barW = cardW - 20
    local barH = 10

    love.graphics.setColor(C.repBarBg)
    love.graphics.rectangle('fill', barX, barY, barW, barH, 2, 2)

    -- Center line
    local centerX = barX + barW / 2
    love.graphics.setColor(C.dim)
    love.graphics.line(centerX, barY, centerX, barY + barH)

    -- Fill from center
    local rep = fac.rep or 0
    if rep > 0 then
        local fillW = (rep / 100) * (barW / 2)
        love.graphics.setColor(C.repBarPos)
        love.graphics.rectangle('fill', centerX, barY + 1, fillW, barH - 2)
    elseif rep < 0 then
        local fillW = (math.abs(rep) / 100) * (barW / 2)
        love.graphics.setColor(C.repBarNeg)
        love.graphics.rectangle('fill', centerX - fillW, barY + 1, fillW, barH - 2)
    end

    -- Rep number
    love.graphics.setColor(C.label)
    love.graphics.print(string.format('Rep: %d', rep), barX, barY + barH + 2)

    -- Trade mult
    local tradeMult = _Factions.getTradeMult(fac.id)
    love.graphics.setColor(C.dim)
    love.graphics.print(string.format('Trade: %.0f%%', tradeMult * 100), barX + 80, barY + barH + 2)

    -- Core price mult
    local coreMult = _Factions.getCorePriceMult(fac.id)
    love.graphics.setColor(C.dim)
    love.graphics.print(string.format('Core value: %.0fx', coreMult), barX + 170, barY + barH + 2)

    -- Research bonus (if any)
    if def.researchBonus and def.researchBonus > 0 then
        love.graphics.setColor(C.bonus)
        love.graphics.print(string.format('+%d%% research (allied)', math.floor(def.researchBonus * 100)),
            barX + 290, barY + barH + 2)
    end

    -- Trade goods row
    local goodsY = y + 72
    love.graphics.setColor(C.dim)
    love.graphics.print('Trades:', cardX + 10, goodsY)
    love.graphics.setColor(C.tradeGood)
    love.graphics.print(table.concat(def.tradeGoods or {}, ', '), cardX + 58, goodsY)

    -- Gift preference + button
    love.graphics.setColor(C.dim)
    love.graphics.print('Prefers:', cardX + 10, goodsY + 16)
    love.graphics.setColor(C.friendly)
    love.graphics.print(def.giftPreference or '?', cardX + 58, goodsY + 16)

    -- Gift button
    local btnW = 90
    local btnH = 20
    local giftBtnX = cardX + cardW - btnW - 10
    local giftBtnY = goodsY + 4
    local giftHover = mx >= giftBtnX and mx <= giftBtnX + btnW and my >= giftBtnY and my < giftBtnY + btnH

    love.graphics.setColor(giftHover and C.giftBtnHov or C.giftBtn)
    love.graphics.rectangle('fill', giftBtnX, giftBtnY, btnW, btnH, 3, 3)
    love.graphics.setColor(C.white)
    love.graphics.print(string.format('Gift %d %s', GIFT_AMOUNT, (def.giftPreference or '?'):sub(1, 8)),
        giftBtnX + 4, giftBtnY + 3)

    addZone(fac.id .. '_gift', giftBtnX, giftBtnY, btnW, btnH, 'gift', {
        factionId = fac.id,
        resource = def.giftPreference,
        amount = GIFT_AMOUNT,
    })

    -- Trade route section (allied factions only, or if route exists)
    if _TradeRoutes and (isAllied or hasRoute) then
        local routeY = goodsY + 36

        if hasRoute then
            local route = _TradeRoutes.getRoute(fac.id)
            local routeDef = _TradeRoutes.ROUTE_DEFS[fac.id]

            if route.disrupted then
                love.graphics.setColor(C.disrupted)
                love.graphics.print(string.format('Trade route DISRUPTED (until day %d)', route.disruptedUntil),
                    cardX + 10, routeY)
            else
                love.graphics.setColor(C.routeActive)
                local nextShip = route.lastShipment + (routeDef and routeDef.interval or 0)
                love.graphics.print(string.format('Trade route active (%d shipments, next day %d, %d fuel/ship)',
                    route.totalShipments, nextShip, routeDef and routeDef.fuelCost or 0),
                    cardX + 10, routeY)
            end

            -- Cancel button
            local cBtnW = 60
            local cBtnH = 18
            local cBtnX = cardX + cardW - cBtnW - 10
            local cBtnY = routeY
            local cHover = mx >= cBtnX and mx <= cBtnX + cBtnW and my >= cBtnY and my < cBtnY + cBtnH

            love.graphics.setColor(cHover and C.cancelBtnHov or C.cancelBtn)
            love.graphics.rectangle('fill', cBtnX, cBtnY, cBtnW, cBtnH, 3, 3)
            love.graphics.setColor(C.white)
            love.graphics.print('Cancel', cBtnX + 8, cBtnY + 2)

            addZone(fac.id .. '_cancel_route', cBtnX, cBtnY, cBtnW, cBtnH, 'cancel_route', {
                factionId = fac.id,
            })
        else
            -- Establish button
            local routeDef = _TradeRoutes.ROUTE_DEFS[fac.id]
            if routeDef then
                local goodsList = {}
                for _, g in ipairs(routeDef.goods) do
                    goodsList[#goodsList + 1] = g.item
                end

                love.graphics.setColor(C.dim)
                love.graphics.print(string.format('Route available: %s (every %dd, %d fuel)',
                    table.concat(goodsList, '/'), routeDef.interval, routeDef.fuelCost),
                    cardX + 10, routeY)

                local eBtnW = 70
                local eBtnH = 18
                local eBtnX = cardX + cardW - eBtnW - 10
                local eBtnY = routeY
                local eHover = mx >= eBtnX and mx <= eBtnX + eBtnW and my >= eBtnY and my < eBtnY + eBtnH

                love.graphics.setColor(eHover and C.routeBtnHov or C.routeBtn)
                love.graphics.rectangle('fill', eBtnX, eBtnY, eBtnW, eBtnH, 3, 3)
                love.graphics.setColor(C.white)
                love.graphics.print('Establish', eBtnX + 4, eBtnY + 2)

                addZone(fac.id .. '_establish_route', eBtnX, eBtnY, eBtnW, eBtnH, 'establish_route', {
                    factionId = fac.id,
                })
            end
        end
    end

    return cardH
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function FactionPanel.draw()
    if not visible then return end
    lazyLoad()
    if not _Factions then return end

    local sw, sh = love.graphics.getDimensions()
    hitZones = {}

    -- Panel dimensions (centered, not full screen)
    local panelW = math.min(620, sw - 60)
    local panelH = sh - 80
    local panelX = (sw - panelW) / 2
    local panelY = 40

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Panel background
    love.graphics.setColor(C.bg)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH, 4, 4)

    -- Header bar
    love.graphics.setColor(C.header)
    love.graphics.rectangle('fill', panelX, panelY, panelW, 44, 4, 4)
    love.graphics.setColor(C.headerLine)
    love.graphics.line(panelX, panelY + 44, panelX + panelW, panelY + 44)

    -- Title
    love.graphics.setColor(C.label)
    love.graphics.print('Faction Diplomacy (F)', panelX + panelW / 2 - 75, panelY + 14)

    -- Scissor to clip content area
    local contentY = panelY + 48
    local contentH = panelH - 48 - 24
    love.graphics.setScissor(panelX, contentY, panelW, contentH)

    -- Gather faction data
    local factions = _Factions.getAll()
    local defs = _Factions.FACTION_DEFS

    local mx, my = love.mouse.getPosition()
    local cardGap = 8
    local cardX = panelX + 12
    local cardW = panelW - 24

    local cursorY = contentY + 6 - scrollY

    for _, fac in ipairs(factions) do
        local def = defs[fac.id]
        if def then
            if cursorY < contentY + contentH and cursorY + 140 > contentY then
                local h = drawFactionCard(fac, def, cardX, cursorY, cardW, mx, my)
                cursorY = cursorY + h + cardGap
            else
                -- Estimate height for off-screen cards (scroll math)
                local hasRoute = _TradeRoutes and _TradeRoutes.hasRoute(fac.id)
                local isAllied = fac.standing == 'allied'
                local h = hasRoute and 130 or (isAllied and 130 or 110)
                cursorY = cursorY + h + cardGap
            end
        end
    end

    love.graphics.setScissor()

    -- Footer
    love.graphics.setColor(C.dim)
    love.graphics.print('F - close    Scroll - navigate    Gift sends resources, Trade routes deliver goods',
        panelX + 12, panelY + panelH - 18)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function FactionPanel.keypressed(key)
    if not visible then return false end
    if key == 'f' or key == 'escape' then
        FactionPanel.toggle()
        return true
    end
    return true -- consume keys while open
end

function FactionPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end

    lazyLoad()
    if not _Factions then return true end

    for _, zone in ipairs(hitZones) do
        if x >= zone.x and x <= zone.x + zone.w and y >= zone.y and y <= zone.y + zone.h then
            if zone.action == 'gift' then
                local data = zone.data
                local ok, repGain = _Factions.sendGift(data.factionId, data.resource, data.amount)
                if ok then
                    showToast(string.format('Sent %d %s (+%.0f rep)', data.amount, data.resource, repGain))
                else
                    showToast('Not enough ' .. (data.resource or 'resources'))
                end
                return true

            elseif zone.action == 'establish_route' then
                if _TradeRoutes then
                    local ok, err = _TradeRoutes.establish(zone.data.factionId)
                    if ok then
                        showToast('Trade route established')
                    else
                        showToast(err or 'Cannot establish route')
                    end
                end
                return true

            elseif zone.action == 'cancel_route' then
                if _TradeRoutes then
                    _TradeRoutes.cancel(zone.data.factionId)
                    showToast('Trade route canceled')
                end
                return true
            end
        end
    end

    return true -- consume click while open
end

function FactionPanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return FactionPanel
