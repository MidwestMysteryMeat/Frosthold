-- faction_panel.lua — Faction diplomacy and trade route panel
-- Shows all factions, reputation bars, standings, trade modifiers, gift buttons,
-- and trade route management (establish/cancel for allied factions).
-- Toggle with Shift+F.
--
-- Layout goes through src/ui/ui_layout.lua. The previous version placed every
-- field at a hand-picked pixel offset, so at the real 16px font the labels ran
-- into their values ("Trades:fuel, metal") and the fixed-width gift button cut
-- its own label in half.

local GameState = require('src.game_state')
local Layout    = require('src.ui.ui_layout')

local FactionPanel = {}

local visible = false
local scrollY = 0
local contentH = 0
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
    disabledBtn = { 0.13, 0.14, 0.16, 0.9 },
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

local GIFT_AMOUNT = 5
local CARD_PAD = Layout.ROW_PAD
local CARD_GAP = 8
local REP_BAR_H = 10

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

function FactionPanel.close()
    visible = false
    scrollY = 0
    hitZones = {}
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function addZone(id, rect, action, data)
    hitZones[#hitZones + 1] = {
        id = id, x = rect.x, y = rect.y, w = rect.w, h = rect.h,
        action = action, data = data,
    }
end

local function showToast(msg)
    local uok, UIMod = pcall(require, 'src.ui.ui')
    if uok and UIMod.showSaveToast then UIMod.showSaveToast(msg) end
end

--- Does this faction get a trade-route row on its card?
local function routeState(factionId, standing)
    local hasRoute = _TradeRoutes and _TradeRoutes.hasRoute(factionId) or false
    local eligible = _TradeRoutes and _TradeRoutes.ROUTE_DEFS[factionId] ~= nil
    -- The route row is shown for any faction that has a route definition, not
    -- only allied ones. Hiding the row until you were already allied meant the
    -- footer promised "trade routes deliver goods" with nothing on screen that
    -- could ever produce one.
    return hasRoute, eligible, standing == 'allied'
end

--- Height a card needs. Kept separate from drawing so scroll bounds and
--- off-screen cards agree with what is actually rendered.
local function cardHeight(fac, line)
    local hasRoute, eligible = routeState(fac.id, fac.standing)
    local h = 6                                   -- top padding
        + line                                    -- name + standing
        + line                                    -- description
        + REP_BAR_H + 6                           -- reputation bar
        + line                                    -- rep / trade / core value
        + line                                    -- trades
        + math.max(line, Layout.BTN_H)            -- prefers + gift button
        + 6                                       -- bottom padding
    if hasRoute or eligible then
        h = h + math.max(line, Layout.BTN_H) + 2
    end
    return h
end

---------------------------------------------------------------------------
-- Draw a single faction card
---------------------------------------------------------------------------

local function drawFactionCard(fac, def, card, mx, my, line, clip)
    local hasRoute, eligible, isAllied = routeState(fac.id, fac.standing)
    local left = card.x + CARD_PAD
    local right = card.x + card.w - CARD_PAD
    local visibleCard = card.y + card.h > clip.y and card.y < clip.y + clip.h

    -- Card background
    local isHover = Layout.hit(mx, my, card)
    love.graphics.setColor(isHover and C.cardHover or C.cardBg)
    love.graphics.rectangle('fill', card.x, card.y, card.w, card.h, 3, 3)

    local y = card.y + 6

    -- Faction name, with the standing badge pinned right. The name is
    -- ellipsised at the badge, never drawn through it.
    local standLabel = (fac.standing or 'neutral'):upper()
    local standW = Layout.textWidth(standLabel)
    local badgeX = right - standW
    love.graphics.setColor(C.white)
    love.graphics.print(Layout.fitLabel(fac.name or fac.id, left, badgeX), left, y)
    love.graphics.setColor(STANDING_COLORS[fac.standing] or C.neutral)
    love.graphics.print(standLabel, badgeX, y)
    y = y + line

    -- Description
    love.graphics.setColor(C.dim)
    love.graphics.print(Layout.truncate(def.desc or '', right - left), left, y)
    y = y + line

    -- Reputation bar: -100 to +100, filled outward from the midpoint
    local rep = fac.rep or 0
    local barW = right - left
    love.graphics.setColor(C.repBarBg)
    love.graphics.rectangle('fill', left, y, barW, REP_BAR_H, 2, 2)
    local centerX = left + barW / 2
    love.graphics.setColor(C.dim)
    love.graphics.line(centerX, y, centerX, y + REP_BAR_H)
    if rep > 0 then
        love.graphics.setColor(C.repBarPos)
        love.graphics.rectangle('fill', centerX, y + 1, (rep / 100) * (barW / 2), REP_BAR_H - 2)
    elseif rep < 0 then
        local fillW = (math.abs(rep) / 100) * (barW / 2)
        love.graphics.setColor(C.repBarNeg)
        love.graphics.rectangle('fill', centerX - fillW, y + 1, fillW, REP_BAR_H - 2)
    end
    y = y + REP_BAR_H + 6

    -- Numbers row. drawInline spaces the fields instead of trusting hardcoded
    -- x offsets, which is what produced "Trade: 100%Core value: 1x".
    local stats = {
        { text = string.format('Rep: %d', rep), color = C.label },
        { text = string.format('Trade: %.0f%%', _Factions.getTradeMult(fac.id) * 100), color = C.dim },
        { text = string.format('Core value: %.1fx', _Factions.getCorePriceMult(fac.id)), color = C.dim },
    }
    if def.researchBonus and def.researchBonus > 0 then
        stats[#stats + 1] = {
            text = string.format('+%d%% research (allied)', math.floor(def.researchBonus * 100)),
            color = C.bonus,
        }
    end
    Layout.drawInline(left, y, stats, { maxX = right })
    y = y + line

    -- Label column width is measured from the widest label on the card, so the
    -- value column can never sit inside a label.
    local valueX = left + math.max(Layout.textWidth('Trades:'), Layout.textWidth('Prefers:'))
        + Layout.MIN_GAP

    -- Trade goods
    Layout.labelValue('Trades:', table.concat(def.tradeGoods or {}, ', '), left, y, valueX, {
        labelColor = C.dim, valueColor = C.tradeGood, maxValueW = right - valueX,
    })
    y = y + line

    -- Gift preference and the gift button
    local giftRes = def.giftPreference
    local available = _Factions.getGiftableAmount and _Factions.getGiftableAmount(giftRes) or 0
    local canAfford = available >= GIFT_AMOUNT

    local giftLabel = string.format('Gift %d %s', GIFT_AMOUNT, giftRes or '?')
    local giftRect = Layout.buttonRectRight(giftLabel, right, y, { maxW = card.w - CARD_PAD * 2 })
    local giftState = 'normal'
    if not canAfford then
        giftState = 'disabled'
    elseif Layout.hit(mx, my, giftRect) then
        giftState = 'hover'
    end
    Layout.drawButton(giftLabel, giftRect, giftState, {
        normal = C.giftBtn, hover = C.giftBtnHov, disabled = C.disabledBtn,
    })
    if canAfford and visibleCard then
        addZone(fac.id .. '_gift', giftRect, 'gift', {
            factionId = fac.id, resource = giftRes, amount = GIFT_AMOUNT,
        })
    end

    Layout.labelValue('Prefers:', string.format('%s (%d available)', giftRes or '?', available),
        left, y + math.floor((Layout.BTN_H - line) / 2) + 2, valueX, {
            labelColor = C.dim,
            valueColor = canAfford and C.friendly or C.dim,
            maxValueW = giftRect.x - Layout.MIN_GAP - valueX,
        })
    y = y + math.max(line, Layout.BTN_H)

    -- Trade route row
    if _TradeRoutes and (hasRoute or eligible) then
        local routeDef = _TradeRoutes.ROUTE_DEFS[fac.id]
        local btnRect, btnLabel, btnAction, btnColors
        local statusText, statusColor

        if hasRoute then
            local route = _TradeRoutes.getRoute(fac.id)
            if route.disrupted then
                statusText = string.format('Trade route DISRUPTED (until day %d)', route.disruptedUntil)
                statusColor = C.disrupted
            else
                local nextShip = route.lastShipment + (routeDef and routeDef.interval or 0)
                statusText = string.format('Trade route active - %d shipments, next day %d, %d fuel/ship',
                    route.totalShipments, nextShip, routeDef and routeDef.fuelCost or 0)
                statusColor = C.routeActive
            end
            btnLabel = 'Cancel'
            btnAction = 'cancel_route'
            btnColors = { normal = C.cancelBtn, hover = C.cancelBtnHov }
        else
            local goodsList = {}
            for _, g in ipairs(routeDef.goods or {}) do
                goodsList[#goodsList + 1] = g.item
            end
            statusColor = C.dim
            if isAllied then
                statusText = string.format('Route available: %s (every %dd, %d fuel)',
                    table.concat(goodsList, '/'), routeDef.interval, routeDef.fuelCost)
                btnLabel = 'Establish'
                btnAction = 'establish_route'
                btnColors = { normal = C.routeBtn, hover = C.routeBtnHov }
            else
                -- Say why the button is off instead of hiding the whole row and
                -- leaving the footer's promise unexplained.
                statusText = string.format('Route needs allied standing: %s (every %dd, %d fuel)',
                    table.concat(goodsList, '/'), routeDef.interval, routeDef.fuelCost)
                btnLabel = 'Establish'
                btnAction = nil
                btnColors = { normal = C.routeBtn, hover = C.routeBtnHov }
            end
        end

        btnRect = Layout.buttonRectRight(btnLabel, right, y, { h = 20 })
        local state = 'normal'
        if not btnAction then
            state = 'disabled'
        elseif Layout.hit(mx, my, btnRect) then
            state = 'hover'
        end
        btnColors.disabled = C.disabledBtn
        Layout.drawButton(btnLabel, btnRect, state, btnColors)
        if btnAction and visibleCard then
            addZone(fac.id .. '_' .. btnAction, btnRect, btnAction, { factionId = fac.id })
        end

        love.graphics.setColor(statusColor)
        love.graphics.print(Layout.truncate(statusText, btnRect.x - Layout.MIN_GAP - left),
            left, y + 2)
    end

    return card.h
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

    local frame = Layout.panelFrame(sw, sh, { w = 680, h = sh - 100, margin = 30 })
    local panel, header, content, footer = frame.panel, frame.header, frame.content, frame.footer
    local line = Layout.textHeight() + 4

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Panel background
    love.graphics.setColor(C.bg)
    love.graphics.rectangle('fill', panel.x, panel.y, panel.w, panel.h, 4, 4)

    -- Header
    love.graphics.setColor(C.header)
    love.graphics.rectangle('fill', header.x, header.y, header.w, header.h, 4, 4)
    love.graphics.setColor(C.headerLine)
    love.graphics.line(header.x, header.y + header.h, header.x + header.w, header.y + header.h)
    love.graphics.setColor(C.label)
    Layout.printCentered('Faction Diplomacy', header, header.y + math.floor((header.h - line) / 2) + 2)

    -- Gather faction data
    local factions = _Factions.getAll()
    local defs = _Factions.FACTION_DEFS
    local mx, my = love.mouse.getPosition()

    -- Total content height first, so the scroll offset can be clamped before
    -- anything is drawn. Scrolling past the end used to leave an empty panel.
    contentH = 0
    local rows = {}
    for _, fac in ipairs(factions) do
        local def = defs[fac.id]
        if def then
            local h = cardHeight(fac, line)
            rows[#rows + 1] = { fac = fac, def = def, h = h }
            contentH = contentH + h + CARD_GAP
        end
    end
    scrollY = (Layout.clampScroll(scrollY, contentH, content.h))

    local clip = Layout.pushClip(content.x, content.y, content.w, content.h)
    local cardX = content.x + 12
    local cardW = content.w - 24 - 8   -- 8px lane for the scrollbar
    local cursorY = content.y + 6 - scrollY

    for _, row in ipairs(rows) do
        if cursorY + row.h > content.y and cursorY < content.y + content.h then
            drawFactionCard(row.fac, row.def,
                { x = cardX, y = cursorY, w = cardW, h = row.h }, mx, my, line, clip)
        end
        cursorY = cursorY + row.h + CARD_GAP
    end

    Layout.popClip()
    Layout.drawScrollbar(content, scrollY, contentH)

    -- Footer
    love.graphics.setColor(C.dim)
    love.graphics.print(Layout.truncate(
        'Shift+F or ESC - close    Scroll - navigate    Gift sends resources, Trade routes deliver goods',
        footer.w - 24), footer.x + 12, footer.y + 4)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function FactionPanel.keypressed(key)
    if not visible then return false end
    if key == 'f' or key == 'escape' then
        FactionPanel.close()
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
        if Layout.hit(x, y, zone) then
            if zone.action == 'gift' then
                local data = zone.data
                local ok, detail = _Factions.sendGift(data.factionId, data.resource, data.amount)
                if ok then
                    showToast(string.format('Sent %d %s (+%.0f rep)', data.amount, data.resource, detail))
                else
                    showToast(detail or ('Not enough ' .. tostring(data.resource)))
                end
                return true

            elseif zone.action == 'establish_route' then
                if _TradeRoutes then
                    local ok, err = _TradeRoutes.establish(zone.data.factionId)
                    showToast(ok and 'Trade route established' or (err or 'Cannot establish route'))
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

--- Hit zones from the last drawn frame. Exposed for the dev screenshot pass
--- (src/testing/ui_shots.lua), which clicks the gift button to prove the action
--- fires and reports back in-game.
function FactionPanel.getHitZones()
    return hitZones
end

function FactionPanel.wheelmoved(dx, dy)
    if not visible then return false end
    local sw, sh = love.graphics.getDimensions()
    local frame = Layout.panelFrame(sw, sh, { w = 680, h = sh - 100, margin = 30 })
    scrollY = (Layout.clampScroll(scrollY - dy * 30, contentH, frame.content.h))
    return true
end

return FactionPanel
