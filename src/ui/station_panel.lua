-- station_panel.lua — Station services panel (docked at a space station)
-- Shows station info, services (repair, refuel, star chart, medical),
-- contracts (from SpaceEconomy), and undock button.

local GameState = require('src.game_state')

local StationPanel = {}

local visible = false
local scrollY = 0
local hitZones = {}
local statusMsg, statusTimer = nil, 0

-- Lazy-loaded modules
local _Docking, _Economy, _ECS
local function lazyLoad()
    if _Docking ~= nil then return end
    local ok
    ok, _Docking = pcall(require, 'src.space.station_docking')
    if not ok then _Docking = false end
    ok, _Economy = pcall(require, 'src.space.space_economy')
    if not ok then _Economy = false end
    ok, _ECS = pcall(require, 'src.ecs.ecs')
    if not ok then _ECS = false end
end

-- Colors
local C = {
    bg = {0,0,0,0.92}, header = {0.08,0.1,0.14}, headerLine = {0.25,0.35,0.5},
    label = {0.8,0.8,0.8}, dim = {0.5,0.5,0.5}, white = {1,1,1},
    credits = {1,0.85,0.3}, sectionHdr = {0.6,0.75,0.9},
    rowBg = {0.06,0.07,0.09,0.8},
    btnOk = {0.15,0.35,0.2,0.9}, btnOkHov = {0.2,0.45,0.3,1},
    btnDis = {0.12,0.12,0.12,0.7},
    btnWarn = {0.5,0.15,0.1,0.9}, btnWarnHov = {0.65,0.2,0.15,1},
    btnAcc = {0.15,0.3,0.45,0.9}, btnAccHov = {0.2,0.4,0.55,1},
    reward = {0.3,0.9,0.4}, timelimit = {0.7,0.55,0.4},
    statusOk = {0.3,0.85,0.4},  statusErr = {0.9,0.35,0.3},
}

-- Service definitions (display order)
local SERVICES = {
    { id = 'repair_hull', label = 'Repair Hull (+10 HP)',  cost = 50,  fn = 'repairHull' },
    { id = 'refuel',      label = 'Refuel (+50 fuel)',     cost = 30,  fn = 'refuel' },
    { id = 'star_chart',  label = 'Buy Star Chart',        cost = 200, fn = 'buyStarChart' },
    { id = 'medical',     label = 'Medical (full heal)',   cost = 100, fn = 'healColonist' },
}

function StationPanel.toggle() visible = not visible; scrollY = 0; hitZones = {} end
function StationPanel.show()   visible = true;  scrollY = 0; hitZones = {} end
function StationPanel.hide()   visible = false;  hitZones = {} end
function StationPanel.isVisible() return visible end

local function addZone(id, x, y, w, h, action, data)
    hitZones[#hitZones+1] = {id=id, x=x, y=y, w=w, h=h, action=action, data=data}
end

local function setStatus(msg)
    statusMsg = msg; statusTimer = 3
end

local function inRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x+w and my >= y and my <= y+h
end

local function findInjuredColonist()
    if not _ECS then return nil end
    for id, comps in _ECS.query('colonist') do
        local col = comps.colonist
        if col and col.health and col.maxHealth and col.health < col.maxHealth then
            return id
        end
        local wounds = _ECS.get(id, 'wounds')
        if wounds and wounds.list and #wounds.list > 0 then return id end
    end
    return nil
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function StationPanel.draw()
    if not visible then return end
    lazyLoad()
    if not _Docking then return end

    local sw, sh = love.graphics.getDimensions()
    hitZones = {}
    local mx, my = love.mouse.getPosition()

    local panelW = math.min(580, sw - 60)
    local panelH = sh - 80
    local panelX = (sw - panelW) / 2
    local panelY = 40

    -- Backdrop + panel bg
    love.graphics.setColor(0,0,0,0.6)
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    love.graphics.setColor(C.bg)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH, 4, 4)

    -- Header
    love.graphics.setColor(C.header)
    love.graphics.rectangle('fill', panelX, panelY, panelW, 44, 4, 4)
    love.graphics.setColor(C.headerLine)
    love.graphics.line(panelX, panelY+44, panelX+panelW, panelY+44)

    local station = _Docking.getDockedStation()
    local stationName = station and (station.name or 'Unknown Station') or 'Not Docked'
    local factionName = station and (station.faction or 'Independent') or ''

    love.graphics.setColor(C.white)
    love.graphics.print(stationName, panelX+14, panelY+8)
    love.graphics.setColor(C.dim)
    love.graphics.print(factionName, panelX+14, panelY+24)
    love.graphics.setColor(C.credits)
    love.graphics.print(string.format('Credits: %d', GameState.credits or 0),
        panelX+panelW-140, panelY+14)

    -- Content area with scissor
    local cX = panelX + 12
    local cW = panelW - 24
    local cTop = panelY + 52
    local cH = panelH - 52 - 30
    love.graphics.setScissor(panelX, cTop, panelW, cH)

    local cy = cTop + 4 - scrollY

    if not _Docking.isDocked() then
        love.graphics.setColor(C.dim)
        love.graphics.print('No station docked. Approach a station to dock.', cX, cy)
        love.graphics.setScissor()
        return
    end

    -- Services header
    love.graphics.setColor(C.sectionHdr)
    love.graphics.print('SERVICES', cX, cy)
    cy = cy + 20

    local available = _Docking.getAvailableServices()
    local availSet = {}
    for _, svc in ipairs(available) do availSet[svc] = true end

    local rowH = 36
    for _, svc in ipairs(SERVICES) do
        if cy + rowH > cTop and cy < cTop + cH then
            local enabled = (#available == 0 or availSet[svc.id])
            local canAfford = (GameState.credits or 0) >= svc.cost
            local active = enabled and canAfford

            love.graphics.setColor(C.rowBg)
            love.graphics.rectangle('fill', cX, cy, cW, rowH-4, 3, 3)
            love.graphics.setColor(active and C.label or C.dim)
            love.graphics.print(svc.label, cX+8, cy+6)
            love.graphics.setColor(canAfford and C.credits or C.statusErr)
            love.graphics.print(string.format('%d cr', svc.cost), cX+200, cy+6)

            local bx, by, bw, bh = cX+cW-70, cy+3, 60, 24
            local hover = active and inRect(mx, my, bx, by, bw, bh)
            love.graphics.setColor(active and (hover and C.btnOkHov or C.btnOk) or C.btnDis)
            love.graphics.rectangle('fill', bx, by, bw, bh, 3, 3)
            love.graphics.setColor(active and C.white or C.dim)
            love.graphics.print('Buy', bx+18, by+4)

            if active then
                addZone(svc.id, bx, by, bw, bh, 'service', {serviceId=svc.id, fn=svc.fn})
            end
        end
        cy = cy + rowH
    end
    -- Sunny vending (StarByte stations)
    if station and (station.type == 'starbyte_station' or station.type == 'orbit_hub_71') then
        cy = cy + 6
        local snackCost = 5
        local canSnack = (GameState.credits or 0) >= snackCost
        love.graphics.setColor(C.rowBg)
        love.graphics.rectangle('fill', cX, cy, cW, rowH-4, 3, 3)
        love.graphics.setColor(canSnack and C.label or C.dim)
        love.graphics.print('Sunny Snack (+3 morale)', cX+8, cy+6)
        love.graphics.setColor(canSnack and C.credits or C.statusErr)
        love.graphics.print(string.format('%d cr', snackCost), cX+200, cy+6)

        local sbx, sby, sbw, sbh = cX+cW-70, cy+3, 60, 24
        local sHov = canSnack and inRect(mx, my, sbx, sby, sbw, sbh)
        love.graphics.setColor(canSnack and (sHov and C.btnOkHov or C.btnOk) or C.btnDis)
        love.graphics.rectangle('fill', sbx, sby, sbw, sbh, 3, 3)
        love.graphics.setColor(canSnack and C.white or C.dim)
        love.graphics.print('Buy', sbx+18, sby+4)

        if canSnack then
            addZone('sunny_snack', sbx, sby, sbw, sbh, 'service', {serviceId='sunny_snack', fn='buySnack'})
        end
        cy = cy + rowH
    end

    -- Orbit Hub 71 crew interactions
    if _Docking.isOrbitHub71 and _Docking.isOrbitHub71() then
        cy = cy + 10
        love.graphics.setColor(C.sectionHdr)
        love.graphics.print('ORBIT HUB 71 CREW', cX, cy)
        cy = cy + 20

        local crewOptions = {
            { id = 'talk_tessa', label = 'Talk to Tessa (Lore)', cost = 0, fn = 'talkToTessa' },
            { id = 'talk_marv8_repair', label = 'MARV-8 Repair (+10 HP, half price)', cost = 25, fn = 'repairHullMAR8' },
            { id = 'talk_marv8', label = 'Talk to MARV-8 (Lore)', cost = 0, fn = 'talkToMARV8' },
            { id = 'talk_cass', label = 'Talk to Cass (Supply rumors)', cost = 0, fn = 'talkToCass' },
            { id = 'ask_sandy', label = 'Ask Sandy for intel (reveals POIs)', cost = 30, fn = 'askSandyIntel' },
        }

        for _, opt in ipairs(crewOptions) do
            if cy + rowH > cTop and cy < cTop + cH then
                local canAfford = opt.cost == 0 or (GameState.credits or 0) >= opt.cost
                love.graphics.setColor(C.rowBg)
                love.graphics.rectangle('fill', cX, cy, cW, rowH-4, 3, 3)
                love.graphics.setColor(canAfford and C.label or C.dim)
                love.graphics.print(opt.label, cX+8, cy+6)
                if opt.cost > 0 then
                    love.graphics.setColor(canAfford and C.credits or C.statusErr)
                    love.graphics.print(string.format('%d cr', opt.cost), cX+200, cy+6)
                else
                    love.graphics.setColor(C.dim)
                    love.graphics.print('Free', cX+200, cy+6)
                end

                local obx, oby, obw, obh = cX+cW-70, cy+3, 60, 24
                local oHov = canAfford and inRect(mx, my, obx, oby, obw, obh)
                love.graphics.setColor(canAfford and (oHov and C.btnAccHov or C.btnAcc) or C.btnDis)
                love.graphics.rectangle('fill', obx, oby, obw, obh, 3, 3)
                love.graphics.setColor(canAfford and C.white or C.dim)
                love.graphics.print(opt.cost > 0 and 'Buy' or 'Talk', obx+14, oby+4)

                if canAfford then
                    addZone(opt.id, obx, oby, obw, obh, 'service', {serviceId=opt.id, fn=opt.fn})
                end
            end
            cy = cy + rowH
        end
    end

    cy = cy + 10

    -- Contracts section
    if _Economy and station and station.id then
        love.graphics.setColor(C.sectionHdr)
        love.graphics.print('CONTRACTS', cX, cy)
        cy = cy + 20

        local contracts = _Economy.getContractsAtStation(station.id)
        if #contracts == 0 then
            love.graphics.setColor(C.dim)
            love.graphics.print('No contracts available.', cX+8, cy)
            cy = cy + 20
        else
            for i, ct in ipairs(contracts) do
                local cRowH = 54
                if cy + cRowH > cTop and cy < cTop + cH then
                    love.graphics.setColor(C.rowBg)
                    love.graphics.rectangle('fill', cX, cy, cW, cRowH-4, 3, 3)

                    love.graphics.setColor(C.white)
                    love.graphics.print(ct.name or ct.type or '???', cX+8, cy+4)
                    love.graphics.setColor(C.dim)
                    love.graphics.print(ct.desc or '', cX+8, cy+20)

                    love.graphics.setColor(C.reward)
                    love.graphics.print(string.format('+%d cr', ct.reward or 0), cX+cW-180, cy+4)
                    love.graphics.setColor(C.timelimit)
                    love.graphics.print(string.format('%d days', ct.timeLimit or 0), cX+cW-180, cy+20)

                    local abx, aby, abw, abh = cX+cW-70, cy+10, 60, 24
                    local aHov = inRect(mx, my, abx, aby, abw, abh)
                    love.graphics.setColor(aHov and C.btnAccHov or C.btnAcc)
                    love.graphics.rectangle('fill', abx, aby, abw, abh, 3, 3)
                    love.graphics.setColor(C.white)
                    love.graphics.print('Accept', abx+8, aby+4)

                    addZone('contract_'..(ct.id or i), abx, aby, abw, abh,
                        'accept_contract', {contractId = ct.id})
                end
                cy = cy + cRowH
            end
        end
    end
    cy = cy + 16

    -- Undock button
    if cy + 36 > cTop and cy < cTop + cH then
        local ubx = cX + cW/2 - 50
        local uby, ubw, ubh = cy, 100, 30
        local uHov = inRect(mx, my, ubx, uby, ubw, ubh)
        love.graphics.setColor(uHov and C.btnWarnHov or C.btnWarn)
        love.graphics.rectangle('fill', ubx, uby, ubw, ubh, 3, 3)
        love.graphics.setColor(C.white)
        love.graphics.print('Undock', ubx+26, uby+7)
        addZone('undock', ubx, uby, ubw, ubh, 'undock', {})
    end

    love.graphics.setScissor()

    -- Status message
    if statusMsg and statusTimer > 0 then
        love.graphics.setColor(C.statusOk)
        love.graphics.print(statusMsg, panelX+14, panelY+panelH-24)
    end
    love.graphics.setColor(C.dim)
    love.graphics.print('ESC - close    Scroll - navigate', panelX+panelW-210, panelY+panelH-24)
end

---------------------------------------------------------------------------
-- Update / Input
---------------------------------------------------------------------------

function StationPanel.update(dt)
    if statusTimer > 0 then
        statusTimer = statusTimer - dt
        if statusTimer <= 0 then statusMsg = nil end
    end
end

function StationPanel.keypressed(key)
    if not visible then return false end
    if key == 'escape' then StationPanel.hide(); return true end
    return true
end

function StationPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end
    lazyLoad()
    if not _Docking then return true end

    for _, zone in ipairs(hitZones) do
        if inRect(x, y, zone.x, zone.y, zone.w, zone.h) then
            if zone.action == 'service' then
                local fn = zone.data.fn
                if fn == 'healColonist' then
                    local colId = findInjuredColonist()
                    if colId then
                        local ok, err = _Docking.healColonist(colId)
                        setStatus(ok and 'Colonist healed.' or (err or 'Cannot heal.'))
                    else
                        setStatus('No injured colonists.')
                    end
                elseif _Docking[fn] then
                    local ok, err = _Docking[fn]()
                    setStatus(ok and (zone.data.serviceId:gsub('_',' ')..' complete.') or (err or 'Service unavailable.'))
                end
                return true
            elseif zone.action == 'accept_contract' then
                if _Economy then
                    local ok = _Economy.acceptContract(zone.data.contractId)
                    setStatus(ok and 'Contract accepted!' or 'Cannot accept contract.')
                end
                return true
            elseif zone.action == 'undock' then
                _Docking.undock()
                StationPanel.hide()
                return true
            end
        end
    end
    return true
end

function StationPanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return StationPanel
