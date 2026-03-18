-- combat_hud.lua — FTL-style combat targeting HUD overlay
-- Draws over the game during ship combat or boarding. Not full-screen.
-- Left: player systems + HP bars. Right: enemy systems (clickable targets).
-- Bottom: weapon mounts with assignments. Click weapon -> click enemy system.

local ECS = require('src.ecs.ecs')
local ok_sc, ShipCombat = pcall(require, 'src.space.ship_combat')
if not ok_sc then ShipCombat = nil end
local ok_bd, Boarding = pcall(require, 'src.space.boarding')
if not ok_bd then Boarding = nil end

local CombatHUD = {}

local selectedWeaponId = nil
local hudFont, hudFontSmall
local PA = 0.85 -- panel alpha
local enemySystemBtns, weaponBtns, boardBtn = {}, {}, nil

local function ensureFonts()
    if not hudFont then
        hudFont = love.graphics.newFont(13)
        hudFontSmall = love.graphics.newFont(11)
    end
end

local SYS_NAMES = {
    cockpit = 'Cockpit', bridge = 'Bridge', engine = 'Engine',
    engine_bay = 'Engine Bay', life_support = 'Life Support',
    life_support_array = 'Life Support', shield_generator = 'Shields',
    weapon_mount = 'Weapons', sensor_array = 'Sensors', comms_array = 'Comms',
    mini_reactor = 'Reactor', reactor = 'Reactor', cargo_bay = 'Cargo Bay',
    workshop = 'Workshop', stealth_module = 'Stealth', airlock = 'Airlock',
}
local function sysLabel(t) return SYS_NAMES[t] or t end

local function findPlayerShip()
    for id, c in ECS.query('ship', 'pos') do
        if not ECS.has(id, 'npc_ship') then return id, c.ship, c.pos end
    end
end

local function findEnemyShip()
    for id, c in ECS.query('npc_ship', 'ship', 'pos') do
        if c.npc_ship.aiState == 'engage' then
            return id, c.ship, c.npc_ship, c.pos
        end
    end
end

local function getModules(shipEid)
    local ship = ECS.get(shipEid, 'ship')
    if not ship then return {} end
    local out = {}
    for mid, c in ECS.query('ship_module') do
        local m = c.ship_module
        if m.shipId == ship.shipId then
            local d = ECS.get(mid, 'durability')
            out[#out+1] = {
                entityId = mid, systemType = m.systemType,
                operational = m.operational, efficiency = m.efficiency or 1,
                hp = d and d.hp or 100, maxHp = d and d.maxHp or 100,
            }
        end
    end
    return out
end

local NPC_VIRTUAL = { 'engine', 'shield_generator', 'life_support', 'cockpit' }

local function getEnemySystems(eid)
    local mods = getModules(eid)
    if #mods > 0 then return mods end
    local npc = ECS.get(eid, 'npc_ship')
    local ship = ECS.get(eid, 'ship')
    local hp = ship and ship.hullHP or 100
    local out = {}
    for _, st in ipairs(NPC_VIRTUAL) do
        out[#out+1] = { entityId=eid, systemType=st, operational=true, efficiency=1, hp=hp, maxHp=100 }
    end
    if npc and (npc.weaponCount or 0) > 0 then
        out[#out+1] = { entityId=eid, systemType='weapon_mount', operational=true, efficiency=1, hp=hp, maxHp=100 }
    end
    return out
end

local function getWeapons()
    local out = {}
    for wid, c in ECS.query('weapon_mount', 'pos') do
        local wm = c.weapon_mount
        out[#out+1] = { entityId=wid, targetSystemType=wm.targetSystemType, targetEntityId=wm.targetEntityId }
    end
    return out
end

local function hitTest(mx, my, b)
    return mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
end

local function drawBar(x, y, w, h, hp, maxHp, op)
    local f = maxHp > 0 and math.max(0, math.min(1, hp/maxHp)) or 0
    love.graphics.setColor(0.12, 0.12, 0.12, 0.9)
    love.graphics.rectangle('fill', x, y, w, h, 2)
    if not op then love.graphics.setColor(0.5, 0.15, 0.15, 0.9)
    elseif f < 0.3 then love.graphics.setColor(0.85, 0.25, 0.15, 0.9)
    elseif f < 0.6 then love.graphics.setColor(0.85, 0.7, 0.2, 0.9)
    else love.graphics.setColor(0.2, 0.75, 0.35, 0.9) end
    love.graphics.rectangle('fill', x, y, w*f, h, 2)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.9)
    love.graphics.rectangle('line', x, y, w, h, 2)
end

-- Left panel: player ship systems
local function drawPlayerPanel(pid)
    local mods = getModules(pid)
    local ship = ECS.get(pid, 'ship')
    local pW, rH, hH = 220, 26, 28
    local pH = hH + #mods * rH + 10
    local pX, pY = 8, 60
    love.graphics.setColor(0.04, 0.04, 0.06, PA)
    love.graphics.rectangle('fill', pX, pY, pW, pH, 4)
    love.graphics.setColor(0.15, 0.4, 0.6, 0.7)
    love.graphics.rectangle('line', pX, pY, pW, pH, 4)
    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.5, 0.8, 1.0)
    love.graphics.print('YOUR SHIP', pX+8, pY+7)
    love.graphics.setFont(hudFontSmall)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print(string.format('Hull: %d%%', math.floor(ship and ship.hullHP or 0)), pX+120, pY+9)
    local y = pY + hH
    for _, m in ipairs(mods) do
        love.graphics.setColor(m.operational and {0.8,0.8,0.75} or {0.7,0.3,0.3})
        local lbl = sysLabel(m.systemType) .. (m.operational and '' or ' [DOWN]')
        love.graphics.print(lbl, pX+10, y+2)
        drawBar(pX+120, y+2, 85, 11, m.hp, m.maxHp, m.operational)
        y = y + rH
    end
end

-- Right panel: enemy systems (clickable)
local function drawEnemyPanel(eid, eShip, eNpc)
    local sys = getEnemySystems(eid)
    local sw = love.graphics.getWidth()
    local pW, rH, hH = 230, 28, 32
    local pH = hH + #sys * rH + 6
    local pX, pY = sw - pW - 8, 60
    love.graphics.setColor(0.06, 0.03, 0.03, PA)
    love.graphics.rectangle('fill', pX, pY, pW, pH, 4)
    love.graphics.setColor(0.6, 0.2, 0.15, 0.7)
    love.graphics.rectangle('line', pX, pY, pW, pH, 4)
    love.graphics.setFont(hudFont)
    love.graphics.setColor(1.0, 0.5, 0.4)
    love.graphics.print((eNpc and eNpc.name) or 'Enemy Ship', pX+8, pY+8)
    love.graphics.setFont(hudFontSmall)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print(string.format('Hull: %d%%', math.floor(eShip and eShip.hullHP or 0)), pX+140, pY+10)
    enemySystemBtns = {}
    local y = pY + hH
    for _, s in ipairs(sys) do
        if selectedWeaponId then
            love.graphics.setColor(0.15, 0.08, 0.06, 0.6)
            love.graphics.rectangle('fill', pX+4, y, pW-8, rH-2, 3)
        end
        love.graphics.setColor(s.operational and {0.85,0.8,0.7} or {0.65,0.3,0.25})
        love.graphics.print(sysLabel(s.systemType) .. (s.operational and '' or ' OFFLINE'), pX+10, y+4)
        drawBar(pX+130, y+4, 85, 11, s.hp, s.maxHp, s.operational)
        enemySystemBtns[#enemySystemBtns+1] = { x=pX+4, y=y, w=pW-8, h=rH-2, systemType=s.systemType, enemyId=eid }
        y = y + rH
    end
end

-- Bottom bar: weapon mounts + board button
local function drawWeaponBar(eid)
    local wpns = getWeapons()
    local sw, sh = love.graphics.getDimensions()
    local bH, bY, bX, sW = 50, sh - 54, 8, 155
    local tW = math.max(#wpns * (sW+6) + 6, 200)
    love.graphics.setColor(0.04, 0.04, 0.06, PA)
    love.graphics.rectangle('fill', bX, bY, tW, bH, 4)
    love.graphics.setColor(0.15, 0.4, 0.6, 0.5)
    love.graphics.rectangle('line', bX, bY, tW, bH, 4)
    weaponBtns = {}
    love.graphics.setFont(hudFontSmall)
    if #wpns == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No weapon mounts installed', bX+10, bY+18)
    else
        local x = bX + 6
        for i, w in ipairs(wpns) do
            local sel = (selectedWeaponId == w.entityId)
            love.graphics.setColor(sel and {0.2,0.3,0.45,0.8} or {0.08,0.08,0.1,0.8})
            love.graphics.rectangle('fill', x, bY+4, sW, bH-8, 3)
            love.graphics.setColor(sel and {0.4,0.7,1,0.8} or {0.25,0.25,0.3,0.8})
            love.graphics.rectangle('line', x, bY+4, sW, bH-8, 3)
            love.graphics.setColor(0.8, 0.85, 0.9)
            love.graphics.print('Weapon '..i, x+6, bY+8)
            local tl = w.targetSystemType and ('-> '..sysLabel(w.targetSystemType)) or '(no target)'
            love.graphics.setColor(w.targetSystemType and {0.9,0.6,0.3} or {0.45,0.45,0.45})
            love.graphics.print(tl, x+6, bY+24)
            weaponBtns[#weaponBtns+1] = { x=x, y=bY+4, w=sW, h=bH-8, entityId=w.entityId }
            x = x + sW + 6
        end
    end
    -- Board button
    boardBtn = nil
    if not eid or (Boarding and Boarding.isActive()) then return end
    local pid = findPlayerShip()
    if not pid then return end
    local pp, ep = ECS.get(pid, 'pos'), ECS.get(eid, 'pos')
    if not pp or not ep then return end
    local dx, dy = ep.x - pp.x, ep.y - pp.y
    if math.sqrt(dx*dx + dy*dy) >= 5 then return end
    local canBoard = false
    for _, s in ipairs(getEnemySystems(eid)) do
        if (s.systemType == 'engine' or s.systemType == 'engine_bay') and not s.operational then
            canBoard = true; break
        end
    end
    if not canBoard then return end
    local btnW, btnX = 100, sw - 116
    love.graphics.setColor(0.3, 0.12, 0.08, 0.9)
    love.graphics.rectangle('fill', btnX, bY+6, btnW, bH-12, 4)
    love.graphics.setColor(1.0, 0.5, 0.3)
    love.graphics.rectangle('line', btnX, bY+6, btnW, bH-12, 4)
    love.graphics.setFont(hudFont)
    love.graphics.setColor(1.0, 0.7, 0.4)
    love.graphics.print('BOARD', btnX+22, bY+14)
    boardBtn = { x=btnX, y=bY+6, w=btnW, h=bH-12, enemyId=eid }
end

-- Boarding phase banner (center-top)
local function drawBoardingBanner()
    if not Boarding or not Boarding.isActive() then return end
    local sw = love.graphics.getWidth()
    local phase = Boarding.getPhase() or '?'
    local def = Boarding.isPlayerDefending()
    local col = def and {1,0.4,0.3} or {0.4,0.8,1}
    local txt = (def and 'DEFENDING: ' or 'BOARDING: ') .. string.upper(phase)
    local bW, bH = 260, 28
    local bx = math.floor((sw - bW) / 2)
    love.graphics.setColor(0.06, 0.03, 0.03, 0.9)
    love.graphics.rectangle('fill', bx, 62, bW, bH, 4)
    love.graphics.setColor(col[1], col[2], col[3], 0.7)
    love.graphics.rectangle('line', bx, 62, bW, bH, 4)
    love.graphics.setFont(hudFont)
    love.graphics.setColor(col)
    love.graphics.printf(txt, bx, 69, bW, 'center')
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function CombatHUD.draw()
    local combat = ShipCombat and ShipCombat.isInCombat()
    local boarding = Boarding and Boarding.isActive()
    if not combat and not boarding then selectedWeaponId = nil; return end
    ensureFonts()
    local prev = love.graphics.getFont()
    local pid = findPlayerShip()
    local eid, eShip, eNpc = findEnemyShip()
    if pid then drawPlayerPanel(pid) end
    if eid then drawEnemyPanel(eid, eShip, eNpc) end
    drawWeaponBar(eid)
    drawBoardingBanner()
    if selectedWeaponId then
        love.graphics.setFont(hudFontSmall)
        love.graphics.setColor(0.9, 0.8, 0.3)
        love.graphics.printf('Click an enemy system to assign target (right-click to cancel)',
            0, 46, love.graphics.getWidth(), 'center')
    end
    love.graphics.setFont(prev)
end

function CombatHUD.mousepressed(x, y, button)
    local combat = ShipCombat and ShipCombat.isInCombat()
    local boarding = Boarding and Boarding.isActive()
    if not combat and not boarding then return false end
    if button == 2 and selectedWeaponId then selectedWeaponId = nil; return true end
    if button ~= 1 then return false end
    -- Weapon selected: assign to clicked enemy system
    if selectedWeaponId then
        for _, b in ipairs(enemySystemBtns) do
            if hitTest(x, y, b) then
                if ShipCombat then
                    ShipCombat.assignWeaponTarget(selectedWeaponId, b.systemType, b.enemyId)
                end
                selectedWeaponId = nil
                return true
            end
        end
        selectedWeaponId = nil
        return true
    end
    -- Weapon bar: select weapon
    for _, b in ipairs(weaponBtns) do
        if hitTest(x, y, b) then selectedWeaponId = b.entityId; return true end
    end
    -- Board button
    if boardBtn and hitTest(x, y, boardBtn) then
        if Boarding then
            local pid = findPlayerShip()
            if pid then Boarding.initiate(pid, boardBtn.enemyId) end
        end
        return true
    end
    return false
end

return CombatHUD
