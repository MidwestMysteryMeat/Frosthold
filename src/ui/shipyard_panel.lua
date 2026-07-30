-- shipyard_panel.lua — Ship construction UI for shipyard buildings
-- Opens when inspecting a shipyard. Shows tier/prebuilt selection,
-- construction progress, and completion status.

local GameState = require('src.game_state')

local ShipyardPanel = {}

local visible = false
local hitZones = {}
local selectedTier = 'scout'
local selectedPrebuilt = nil
local shipyardEntityId = nil
local scrollY = 0
local statusMsg, statusTimer = nil, 0

-- Lazy-loaded modules
local _ShipDefs, _ShipConstruction
local function lazyLoad()
    if _ShipDefs ~= nil then return end
    local ok
    ok, _ShipDefs = pcall(require, 'src.space.ship_defs')
    if not ok then _ShipDefs = false end
    ok, _ShipConstruction = pcall(require, 'src.space.ship_construction')
    if not ok then _ShipConstruction = false end
end

-- Colors (dark theme, matching station_panel)
local C = {
    bg       = {0, 0, 0, 0.92},
    header   = {0.08, 0.1, 0.14},
    headerLn = {0.25, 0.35, 0.5},
    white    = {1, 1, 1},
    label    = {0.8, 0.8, 0.8},
    dim      = {0.5, 0.5, 0.5},
    accent   = {0.6, 0.75, 0.9},
    rowBg    = {0.06, 0.07, 0.09, 0.8},
    rowSel   = {0.12, 0.18, 0.28, 0.9},
    btnOk    = {0.15, 0.35, 0.2, 0.9},
    btnOkH   = {0.2, 0.45, 0.3, 1},
    btnDis   = {0.12, 0.12, 0.12, 0.7},
    btnWarn  = {0.5, 0.15, 0.1, 0.9},
    btnWarnH = {0.65, 0.2, 0.15, 1},
    progress = {0.25, 0.7, 0.4},
    progBg   = {0.15, 0.15, 0.18},
    cost     = {1, 0.85, 0.3},
    costBad  = {0.9, 0.35, 0.3},
    complete = {0.3, 0.9, 0.5},
    statusOk = {0.3, 0.85, 0.4},
}

local function inRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function addZone(id, x, y, w, h, action, data)
    hitZones[#hitZones + 1] = { id = id, x = x, y = y, w = w, h = h, action = action, data = data }
end

local function setStatus(msg)
    statusMsg = msg; statusTimer = 3
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function ShipyardPanel.open(entityId)
    shipyardEntityId = entityId
    visible = true
    hitZones = {}
    scrollY = 0
    selectedPrebuilt = nil
end

function ShipyardPanel.toggle()
    visible = not visible
    hitZones = {}
    scrollY = 0
end

function ShipyardPanel.isVisible() return visible end

function ShipyardPanel.close()
    visible = false
    hitZones = {}
end

---------------------------------------------------------------------------
-- Cost calculation (mirrors ship_construction.lua logic)
---------------------------------------------------------------------------

local function calcCost(tier)
    if not tier then return {} end
    return {
        { name = 'steel',      amount = math.floor(tier.gridW * tier.gridH * 0.5) },
        { name = 'components', amount = math.floor(tier.gridW * tier.gridH * 0.2) },
        { name = 'circuit',    amount = math.floor(tier.gridW * tier.gridH * 0.1) },
    }
end

local function canAffordAll(costs)
    for _, c in ipairs(costs) do
        if (GameState.resources[c.name] or 0) < c.amount then return false end
    end
    return true
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function ShipyardPanel.draw()
    if not visible then return end
    lazyLoad()
    if not _ShipDefs or not _ShipConstruction then return end

    local sw, sh = love.graphics.getDimensions()
    hitZones = {}
    local mx, my = love.mouse.getPosition()

    local panelW = math.min(620, sw - 60)
    local panelH = sh - 80
    local panelX = (sw - panelW) / 2
    local panelY = 40

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    love.graphics.setColor(C.bg)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH, 4, 4)

    -- Header bar
    love.graphics.setColor(C.header)
    love.graphics.rectangle('fill', panelX, panelY, panelW, 44, 4, 4)
    love.graphics.setColor(C.headerLn)
    love.graphics.line(panelX, panelY + 44, panelX + panelW, panelY + 44)

    local active = _ShipConstruction.getActive()

    -- Title
    love.graphics.setColor(C.white)
    if active and active.phase == 'complete' then
        love.graphics.print('SHIPYARD — COMPLETE', panelX + 14, panelY + 14)
    elseif active and active.phase == 'building' then
        local prebuilt = _ShipDefs.getPrebuilt(active.prebuiltId)
        local shipName = prebuilt and prebuilt.name or active.prebuiltId
        love.graphics.print('SHIPYARD — BUILDING ' .. shipName, panelX + 14, panelY + 10)
    else
        love.graphics.print('SHIPYARD', panelX + 14, panelY + 14)
    end
    love.graphics.setColor(C.dim)
    love.graphics.print('ESC - close', panelX + panelW - 100, panelY + 14)

    -- Content area
    local cX = panelX + 14
    local cW = panelW - 28
    local cTop = panelY + 52
    local cH = panelH - 52 - 30
    love.graphics.setScissor(panelX, cTop, panelW, cH)

    local cy = cTop + 4 - scrollY

    ---------------------------------------------------------------------------
    -- State: construction complete
    ---------------------------------------------------------------------------
    if active and active.phase == 'complete' then
        love.graphics.setColor(C.complete)
        love.graphics.print('Ship construction complete!', cX, cy)
        cy = cy + 24
        love.graphics.setColor(C.label)
        love.graphics.print('Your vessel is ready. Use Shift+L to launch.', cX, cy)
        cy = cy + 30

        local prebuilt = _ShipDefs.getPrebuilt(active.prebuiltId)
        local tier = _ShipDefs.getTier(active.tierId)
        if prebuilt then
            love.graphics.setColor(C.accent)
            love.graphics.print('Ship: ' .. (prebuilt.name or active.prebuiltId), cX, cy)
            cy = cy + 18
            love.graphics.setColor(C.dim)
            love.graphics.print(prebuilt.desc or '', cX, cy)
            cy = cy + 22
        end
        if tier then
            love.graphics.setColor(C.label)
            love.graphics.print(string.format('Grid: %dx%d   Fuel: %d   Speed: %d',
                tier.gridW, tier.gridH, tier.fuelCapacity, tier.baseSpeed), cX, cy)
            cy = cy + 18
            love.graphics.print(string.format('Modules: %d required', #tier.requiredModules), cX, cy)
        end

    ---------------------------------------------------------------------------
    -- State: construction in progress
    ---------------------------------------------------------------------------
    elseif active and active.phase == 'building' then
        local progress, totalWork = _ShipConstruction.getProgress()
        local pct = totalWork > 0 and (progress / totalWork) or 0

        love.graphics.setColor(C.label)
        love.graphics.print(string.format('Progress: %d / %d  (%.0f%%)', progress, totalWork, pct * 100), cX, cy)
        cy = cy + 24

        -- Progress bar
        local barW = cW - 20
        local barH = 22
        love.graphics.setColor(C.progBg)
        love.graphics.rectangle('fill', cX, cy, barW, barH, 3, 3)
        love.graphics.setColor(C.progress)
        love.graphics.rectangle('fill', cX, cy, barW * pct, barH, 3, 3)
        love.graphics.setColor(C.white)
        love.graphics.print(string.format('%.0f%%', pct * 100), cX + barW / 2 - 14, cy + 3)
        cy = cy + barH + 16

        love.graphics.setColor(C.dim)
        love.graphics.print('Assign a colonist to the shipyard to advance construction.', cX, cy)
        cy = cy + 30

        -- Cancel button
        local cancelW, cancelH = 140, 30
        local cancelX = cX + cW / 2 - cancelW / 2
        local hover = inRect(mx, my, cancelX, cy, cancelW, cancelH)
        love.graphics.setColor(hover and C.btnWarnH or C.btnWarn)
        love.graphics.rectangle('fill', cancelX, cy, cancelW, cancelH, 3, 3)
        love.graphics.setColor(C.white)
        love.graphics.print('Cancel (50% refund)', cancelX + 8, cy + 7)
        addZone('cancel', cancelX, cy, cancelW, cancelH, 'cancel', {})

    ---------------------------------------------------------------------------
    -- State: no active construction — tier + prebuilt selection
    ---------------------------------------------------------------------------
    else
        -- Tier tabs
        love.graphics.setColor(C.accent)
        love.graphics.print('SELECT SHIP TIER', cX, cy)
        cy = cy + 22

        local tierIds = { 'scout', 'colony' }
        local tabW = 120
        local tabH = 28
        for i, tid in ipairs(tierIds) do
            local tier = _ShipDefs.getTier(tid)
            if tier then
                local tx = cX + (i - 1) * (tabW + 10)
                local isSel = (selectedTier == tid)
                local hover = inRect(mx, my, tx, cy, tabW, tabH)
                love.graphics.setColor(isSel and C.rowSel or (hover and {0.1, 0.14, 0.2, 0.8} or C.rowBg))
                love.graphics.rectangle('fill', tx, cy, tabW, tabH, 3, 3)
                love.graphics.setColor(isSel and C.white or C.label)
                love.graphics.print(tier.name, tx + 8, cy + 6)
                addZone('tier_' .. tid, tx, cy, tabW, tabH, 'select_tier', { tier = tid })
            end
        end
        cy = cy + tabH + 14

        -- Current tier info
        local tier = _ShipDefs.getTier(selectedTier)
        if tier then
            love.graphics.setColor(C.dim)
            love.graphics.print(string.format('Grid: %dx%d   Fuel capacity: %d   Speed: %d   Stealth: %.1f',
                tier.gridW, tier.gridH, tier.fuelCapacity, tier.baseSpeed, tier.baseStealth), cX, cy)
            cy = cy + 16
            love.graphics.print(string.format('Required modules: %d', #tier.requiredModules), cX, cy)
            cy = cy + 14
            for _, m in ipairs(tier.requiredModules) do
                love.graphics.print(string.format('  - %s (%dx%d)', m.name, m.w, m.h), cX + 10, cy)
                cy = cy + 14
            end
            cy = cy + 8

            -- Cost display
            local costs = calcCost(tier)
            love.graphics.setColor(C.accent)
            love.graphics.print('Construction Cost:', cX, cy)
            cy = cy + 18
            for _, c in ipairs(costs) do
                local have = GameState.resources[c.name] or 0
                local enough = have >= c.amount
                love.graphics.setColor(enough and C.cost or C.costBad)
                love.graphics.print(string.format('  %s: %d / %d', c.name, have, c.amount), cX + 10, cy)
                cy = cy + 16
            end
            cy = cy + 12

            -- Prebuilt selection
            love.graphics.setColor(C.accent)
            love.graphics.print('CHOOSE LAYOUT', cX, cy)
            cy = cy + 20

            local prebuilts = _ShipDefs.getPrebuiltsForTier(selectedTier)
            table.sort(prebuilts, function(a, b) return a.id < b.id end)

            for _, entry in ipairs(prebuilts) do
                local rowH = 56
                if cy + rowH > cTop and cy < cTop + cH then
                    local isSel = (selectedPrebuilt == entry.id)
                    local hover = inRect(mx, my, cX, cy, cW, rowH - 4)
                    love.graphics.setColor(isSel and C.rowSel or (hover and {0.08, 0.1, 0.15, 0.8} or C.rowBg))
                    love.graphics.rectangle('fill', cX, cy, cW, rowH - 4, 3, 3)

                    love.graphics.setColor(isSel and C.white or C.label)
                    love.graphics.print(entry.def.name, cX + 10, cy + 6)
                    love.graphics.setColor(C.dim)
                    love.graphics.print(entry.def.desc or '', cX + 10, cy + 22)
                    local extraCount = entry.def.extras and #entry.def.extras or 0
                    love.graphics.print(string.format('%d modules + %d extras',
                        #entry.def.modules, extraCount), cX + 10, cy + 36)

                    addZone('prebuilt_' .. entry.id, cX, cy, cW, rowH - 4, 'select_prebuilt', { id = entry.id })
                end
                cy = cy + rowH
            end
            cy = cy + 12

            -- Begin Construction button
            local canBuild = selectedPrebuilt and canAffordAll(costs) and shipyardEntityId
            local btnW, btnH = 180, 34
            local btnX = cX + cW / 2 - btnW / 2
            if cy + btnH > cTop and cy < cTop + cH then
                local hover = canBuild and inRect(mx, my, btnX, cy, btnW, btnH)
                love.graphics.setColor(canBuild and (hover and C.btnOkH or C.btnOk) or C.btnDis)
                love.graphics.rectangle('fill', btnX, cy, btnW, btnH, 3, 3)
                love.graphics.setColor(canBuild and C.white or C.dim)
                love.graphics.print('Begin Construction', btnX + 20, cy + 9)
                if canBuild then
                    addZone('build', btnX, cy, btnW, btnH, 'begin_construction', { prebuiltId = selectedPrebuilt })
                end
            end
        end
    end

    love.graphics.setScissor()

    -- Status message
    if statusMsg and statusTimer > 0 then
        love.graphics.setColor(C.statusOk)
        love.graphics.print(statusMsg, panelX + 14, panelY + panelH - 24)
    end
end

---------------------------------------------------------------------------
-- Update (status timer)
---------------------------------------------------------------------------

function ShipyardPanel.update(dt)
    if statusTimer > 0 then
        statusTimer = statusTimer - dt
        if statusTimer <= 0 then statusMsg = nil end
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function ShipyardPanel.keypressed(key)
    if not visible then return false end
    if key == 'escape' then
        ShipyardPanel.close()
        return true
    end
    return true
end

function ShipyardPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end
    lazyLoad()
    if not _ShipDefs or not _ShipConstruction then return true end

    for _, zone in ipairs(hitZones) do
        if inRect(x, y, zone.x, zone.y, zone.w, zone.h) then
            if zone.action == 'select_tier' then
                selectedTier = zone.data.tier
                selectedPrebuilt = nil
                return true

            elseif zone.action == 'select_prebuilt' then
                selectedPrebuilt = zone.data.id
                return true

            elseif zone.action == 'begin_construction' then
                local ok, err = _ShipConstruction.startConstruction(shipyardEntityId, zone.data.prebuiltId)
                if ok then
                    setStatus('Construction started!')
                else
                    setStatus(err or 'Cannot start construction.')
                end
                return true

            elseif zone.action == 'cancel' then
                _ShipConstruction.cancel()
                setStatus('Construction cancelled. 50% resources refunded.')
                return true
            end
        end
    end
    return true
end

function ShipyardPanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return ShipyardPanel
