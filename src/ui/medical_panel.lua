-- medical_panel.lua — Medical overview and surgery queue panel
-- Shows all colonist health status, wounds, diseases, implants.
-- Queue surgery operations on surgery tables.
-- Toggle with H key.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Layout    = require('src.ui.ui_layout')

local MedPanel = {}

local visible = false
local scrollY = 0
local view = 'list'   -- 'list' | 'detail' | 'surgery'
local selectedId = nil -- colonist entity ID for detail/surgery
local hitZones = {}    -- rebuilt each frame

-- Color palette
local C = {
    bg        = { 0, 0, 0, 0.92 },
    header    = { 0.12, 0.08, 0.08 },
    headerLine = { 0.45, 0.2, 0.2 },
    label     = { 0.8, 0.8, 0.8 },
    dim       = { 0.5, 0.5, 0.5 },
    healthy   = { 0.4, 0.75, 0.4 },
    injured   = { 0.9, 0.8, 0.2 },
    critical  = { 0.9, 0.3, 0.2 },
    destroyed = { 0.5, 0.15, 0.15 },
    disease   = { 0.7, 0.5, 0.9 },
    implant   = { 0.4, 0.7, 0.9 },
    btn       = { 0.2, 0.15, 0.15 },
    btnHover  = { 0.3, 0.2, 0.2 },
    btnText   = { 0.85, 0.8, 0.8 },
    back      = { 0.35, 0.35, 0.35 },
}

---------------------------------------------------------------------------
-- Toggle
---------------------------------------------------------------------------

function MedPanel.toggle()
    visible = not visible
    scrollY = 0
    view = 'list'
    selectedId = nil
    hitZones = {}
end

function MedPanel.isVisible()
    return visible
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function addZone(id, x, y, w, h, action, data)
    hitZones[#hitZones + 1] = { id = id, x = x, y = y, w = w, h = h, action = action, data = data }
end

local function getWoundCount(entityId)
    local wounds = ECS.get(entityId, 'wounds')
    if not wounds or not wounds.list then return 0 end
    local count = 0
    for _, w in ipairs(wounds.list) do
        if w.treatment ~= 'healed' then count = count + 1 end
    end
    return count
end

local function getDisease(entityId)
    local d = ECS.get(entityId, 'disease')
    if d and d.id then return d end
    return nil
end

local function getImplantCount(entityId)
    local col = ECS.get(entityId, 'colonist') or ECS.get(entityId, 'slave') -- legacy slave fallback for old saves
    if not col or not col.implants then return 0 end
    return #col.implants
end

local function healthColor(frac)
    if frac >= 0.8 then return C.healthy end
    if frac >= 0.5 then return C.injured end
    return C.critical
end

local function partStatusColor(part)
    if part.status == 'destroyed' then return C.destroyed end
    local frac = part.hp / math.max(part.maxHp, 1)
    if frac >= 0.8 then return C.healthy end
    if frac >= 0.5 then return C.injured end
    return C.critical
end

local function prettyPartName(name)
    return name:gsub('_', ' '):gsub('^%l', string.upper)
end

local function prettyWoundType(t)
    return (t or 'wound'):gsub('^%l', string.upper)
end

---------------------------------------------------------------------------
-- Draw: colonist list
---------------------------------------------------------------------------

local function drawList()
    local sw, sh = love.graphics.getDimensions()

    -- Gather colonists
    local colonists = {}
    for id, comps in ECS.query('colonist', 'pos') do
        if comps.colonist.state ~= 'dead' then
            colonists[#colonists + 1] = { id = id, col = comps.colonist }
        end
    end
    table.sort(colonists, function(a, b) return (a.col.name or '') < (b.col.name or '') end)

    -- One column table drives both the header and the rows. The health
    -- percentage used to be printed at x=310 and reach x=342, two pixels into
    -- the Wounds column at x=340.
    local COL = { name = 20, health = 200, healthPct = 306, wounds = 360, disease = 430, implants = 610 }
    local listTop = 56
    local listH = sh - listTop - Layout.BOTTOM_RESERVE - 24
    Layout.pushClip(0, listTop, sw, listH)

    -- List header
    local y = 60 - scrollY
    love.graphics.setColor(C.label)
    love.graphics.print('Name', COL.name, y)
    love.graphics.print('Health', COL.health, y)
    love.graphics.print('Wounds', COL.wounds, y)
    love.graphics.print('Disease', COL.disease, y)
    love.graphics.print('Implants', COL.implants, y)
    y = y + 22

    love.graphics.setColor(C.headerLine)
    love.graphics.line(20, y, sw - 20, y)
    y = y + 4

    -- Rows
    for _, entry in ipairs(colonists) do
        if y > listTop + listH then break end
        if y + 24 > listTop then
            local rowH = 24
            addZone(entry.id, 20, y, sw - 40, rowH, 'select_colonist', entry.id)

            -- Name
            love.graphics.setColor(C.label)
            love.graphics.print(Layout.fitLabel(entry.col.name or '???', COL.name, COL.health),
                COL.name, y + 2)

            -- Health bar
            local hp = entry.col.health or 100
            local maxHp = 100
            local frac = math.max(0, math.min(1, hp / maxHp))
            local barW = 100
            love.graphics.setColor(0.2, 0.15, 0.15)
            love.graphics.rectangle('fill', COL.health, y + 4, barW, 14)
            love.graphics.setColor(healthColor(frac))
            love.graphics.rectangle('fill', COL.health, y + 4, barW * frac, 14)
            love.graphics.setColor(C.label)
            love.graphics.print(string.format('%d%%', math.floor(frac * 100)), COL.healthPct, y + 2)

            -- Wound count
            local wc = getWoundCount(entry.id)
            if wc > 0 then
                love.graphics.setColor(C.critical)
                love.graphics.print(tostring(wc), COL.wounds, y + 2)
            else
                love.graphics.setColor(C.dim)
                love.graphics.print('0', COL.wounds, y + 2)
            end

            -- Disease
            local dis = getDisease(entry.id)
            if dis then
                love.graphics.setColor(C.disease)
                love.graphics.print(Layout.fitLabel(
                    string.format('%s (%.0f%%)', dis.id, dis.severity or 0),
                    COL.disease, COL.implants), COL.disease, y + 2)
            else
                love.graphics.setColor(C.dim)
                love.graphics.print('none', COL.disease, y + 2)
            end

            -- Implants
            local ic = getImplantCount(entry.id)
            if ic > 0 then
                love.graphics.setColor(C.implant)
                love.graphics.print(tostring(ic), COL.implants, y + 2)
            else
                love.graphics.setColor(C.dim)
                love.graphics.print('0', COL.implants, y + 2)
            end
        end
        y = y + 26
    end

    if #colonists == 0 then
        love.graphics.setColor(C.dim)
        love.graphics.print('No living colonists.', 20, y)
    end

    Layout.popClip()
    scrollY = (Layout.clampScroll(scrollY, #colonists * 26 + 30, listH))
end

---------------------------------------------------------------------------
-- Draw: colonist detail
---------------------------------------------------------------------------

local function drawDetail()
    local sw, sh = love.graphics.getDimensions()

    if not selectedId or not ECS.isAlive(selectedId) then
        view = 'list'
        return
    end

    local col = ECS.get(selectedId, 'colonist')
    if not col then view = 'list'; return end

    -- Back button
    addZone('back', 20, 60, 80, 24, 'back')
    love.graphics.setColor(C.back)
    love.graphics.rectangle('fill', 20, 60, 80, 24, 3, 3)
    love.graphics.setColor(C.label)
    love.graphics.print('< Back', 32, 63)

    -- Surgery button
    addZone('surgery', sw - 200, 60, 160, 24, 'open_surgery')
    love.graphics.setColor(C.btn)
    love.graphics.rectangle('fill', sw - 200, 60, 160, 24, 3, 3)
    love.graphics.setColor(C.btnText)
    love.graphics.print('Queue Surgery', sw - 188, 63)

    -- Name and overall health
    love.graphics.setColor(C.label)
    love.graphics.print(string.format('%s — Health: %d%%', col.name or '???', col.health or 100), 120, 63)

    local y = 100 - scrollY

    -- Body parts
    local body = ECS.get(selectedId, 'body')
    love.graphics.setColor(C.label)
    love.graphics.print('Body Parts', 20, y)
    y = y + 20

    if body and body.parts then
        local bok, BodyMod = pcall(require, 'src.combat.body')
        local partNames = bok and BodyMod.PART_NAMES or {}
        if #partNames == 0 then
            for k in pairs(body.parts) do partNames[#partNames + 1] = k end
        end

        for _, pname in ipairs(partNames) do
            local part = body.parts[pname]
            if part and y > 50 and y < sh then
                local frac = part.hp / math.max(part.maxHp, 1)
                love.graphics.setColor(partStatusColor(part))
                love.graphics.print(string.format('%-12s', prettyPartName(pname)), 30, y)

                -- HP bar
                local barX, barW = 160, 120
                love.graphics.setColor(0.2, 0.15, 0.15)
                love.graphics.rectangle('fill', barX, y + 2, barW, 12)
                love.graphics.setColor(partStatusColor(part))
                love.graphics.rectangle('fill', barX, y + 2, barW * math.max(0, frac), 12)

                -- HP text
                love.graphics.setColor(C.label)
                -- '100/100' from barX+barW+8 reached barX+barW+64, six pixels
                -- from the status label; a four-digit maxHp overran it.
                local hpX = barX + barW + 8
                local statusX = hpX + Layout.textWidth('0000/0000') + Layout.MIN_GAP
                love.graphics.print(Layout.fitLabel(
                    string.format('%d/%d', part.hp, part.maxHp), hpX, statusX), hpX, y)

                -- Status label
                if part.status == 'destroyed' then
                    love.graphics.setColor(C.destroyed)
                    love.graphics.print('DESTROYED', statusX, y)
                elseif part.status == 'injured' then
                    love.graphics.setColor(C.injured)
                    love.graphics.print('injured', statusX, y)
                end
            end
            y = y + 18
        end
    else
        love.graphics.setColor(C.dim)
        love.graphics.print('No body data', 30, y)
        y = y + 18
    end

    y = y + 10

    -- Wounds
    local wounds = ECS.get(selectedId, 'wounds')
    love.graphics.setColor(C.label)
    love.graphics.print('Wounds', 20, y)
    y = y + 20

    if wounds and wounds.list and #wounds.list > 0 then
        for _, w in ipairs(wounds.list) do
            if w.treatment ~= 'healed' and y > 50 and y < sh then
                love.graphics.setColor(C.critical)
                local infStr = w.infected and ' [INFECTED]' or ''
                love.graphics.print(string.format('%s on %s — %s (sev %.0f%%)%s',
                    prettyWoundType(w.type), prettyPartName(w.part or '?'),
                    w.treatment or 'untreated',
                    (w.severity or 0) * 100,
                    infStr), 30, y)
                y = y + 16
            end
        end
    else
        love.graphics.setColor(C.dim)
        love.graphics.print('No active wounds.', 30, y)
        y = y + 16
    end

    y = y + 10

    -- Disease
    local disease = getDisease(selectedId)
    love.graphics.setColor(C.label)
    love.graphics.print('Disease', 20, y)
    y = y + 20

    if disease then
        love.graphics.setColor(C.disease)
        love.graphics.print(string.format('%s — Severity: %.0f%%  Immunity: %.0f%%  %s',
            disease.id,
            disease.severity or 0,
            disease.immunity or 0,
            disease.treated and 'TREATED' or 'UNTREATED'), 30, y)
        y = y + 16

        -- Severity/immunity bars
        local barX, barW = 30, 250
        -- Severity bar (red)
        love.graphics.setColor(0.2, 0.1, 0.1)
        love.graphics.rectangle('fill', barX, y + 2, barW, 10)
        love.graphics.setColor(0.8, 0.2, 0.2)
        love.graphics.rectangle('fill', barX, y + 2, barW * math.min(1, (disease.severity or 0) / 100), 10)
        love.graphics.setColor(C.label)
        love.graphics.print('Severity', barX + barW + 8, y)
        y = y + 14

        -- Immunity bar (green)
        love.graphics.setColor(0.1, 0.15, 0.1)
        love.graphics.rectangle('fill', barX, y + 2, barW, 10)
        love.graphics.setColor(0.3, 0.7, 0.3)
        love.graphics.rectangle('fill', barX, y + 2, barW * math.min(1, (disease.immunity or 0) / 100), 10)
        love.graphics.setColor(C.label)
        love.graphics.print('Immunity', barX + barW + 8, y)
        y = y + 18
    else
        love.graphics.setColor(C.dim)
        love.graphics.print('No active disease.', 30, y)
        y = y + 16
    end

    y = y + 10

    -- Implants
    love.graphics.setColor(C.label)
    love.graphics.print('Implants', 20, y)
    y = y + 20

    local implants = {}
    local sok, SurgeryMod = pcall(require, 'src.medical.surgery')
    if sok then implants = SurgeryMod.getImplants(selectedId) end

    if #implants > 0 then
        for _, imp in ipairs(implants) do
            if y > 50 and y < sh then
                love.graphics.setColor(C.implant)
                local stats = imp.stats or {}
                local detail = ''
                if stats.moveMult then detail = string.format('Move: %.0f%%', stats.moveMult * 100) end
                if stats.workMult then detail = string.format('Work: %.0f%%', stats.workMult * 100) end
                if stats.accuracyBonus then detail = string.format('Accuracy: +%.0f%%', stats.accuracyBonus * 100) end
                love.graphics.print(string.format('%s on %s  %s',
                    stats.label or imp.item or '?',
                    prettyPartName(imp.part or '?'),
                    detail), 30, y)
                y = y + 16
            end
        end
    else
        love.graphics.setColor(C.dim)
        love.graphics.print('No implants.', 30, y)
        y = y + 16
    end

    -- Hypothermia
    if col.hypothermia and col.hypothermia > 0 then
        y = y + 10
        local stages = { 'chilled', 'cold', 'hypothermic', 'severe', 'critical' }
        local stage = stages[col.hypothermia] or 'unknown'
        love.graphics.setColor(0.4, 0.7, 1)
        love.graphics.print('Hypothermia: ' .. stage, 20, y)
    end
end

---------------------------------------------------------------------------
-- Draw: surgery queue view
---------------------------------------------------------------------------

local function drawSurgery()
    local sw, sh = love.graphics.getDimensions()

    if not selectedId or not ECS.isAlive(selectedId) then
        view = 'detail'
        return
    end

    local col = ECS.get(selectedId, 'colonist')
    if not col then view = 'list'; return end

    -- Back button
    addZone('back', 20, 60, 80, 24, 'back_to_detail')
    love.graphics.setColor(C.back)
    love.graphics.rectangle('fill', 20, 60, 80, 24, 3, 3)
    love.graphics.setColor(C.label)
    love.graphics.print('< Back', 32, 63)

    love.graphics.setColor(C.label)
    love.graphics.print(string.format('Surgery — %s', col.name or '???'), 120, 63)

    local y = 100 - scrollY

    -- Find surgery tables
    local tables = {}
    for tid, tcomps in ECS.query('machine') do
        if tcomps.machine.type == 'surgery_table' then
            tables[#tables + 1] = { id = tid, machine = tcomps.machine }
        end
    end

    if #tables == 0 then
        love.graphics.setColor(C.dim)
        love.graphics.print('No surgery tables built. Build one to queue operations.', 20, y)
        return
    end

    -- Available operations based on body state
    local body = ECS.get(selectedId, 'body')
    local sok, SurgeryMod = pcall(require, 'src.medical.surgery')
    if not sok then
        love.graphics.setColor(C.dim)
        love.graphics.print('Surgery module not loaded.', 20, y)
        return
    end

    -- Build operation list filtered by relevance
    love.graphics.setColor(C.label)
    love.graphics.print('Available Operations:', 20, y)
    y = y + 22

    local ops = SurgeryMod.OPERATIONS
    local opList = {}
    for opId, op in pairs(ops) do
        opList[#opList + 1] = { id = opId, def = op }
    end
    table.sort(opList, function(a, b) return a.def.label < b.def.label end)

    for _, entry in ipairs(opList) do
        if y > sh then break end
        if y > 50 then
            local op = entry.def
            -- Check if we have the item for installs
            local canDo = true
            local reason = ''
            if op.type == 'install' and (not GameState.resources[op.item] or GameState.resources[op.item] < 1) then
                canDo = false
                reason = ' (no item)'
            end

            -- Determine target parts for this operation
            local targetParts = {}
            if op.type == 'install' then
                local stats = SurgeryMod.IMPLANT_STATS[op.item]
                if stats then
                    if stats.slot == 'leg' then
                        targetParts = { 'left_leg', 'right_leg' }
                    elseif stats.slot == 'arm' then
                        targetParts = { 'left_arm', 'right_arm' }
                    elseif stats.slot == 'eye' then
                        targetParts = { 'head' }
                    end
                end
            elseif op.type == 'amputate' then
                if entry.id == 'amputate_arm' then
                    targetParts = { 'left_arm', 'right_arm' }
                elseif entry.id == 'amputate_leg' then
                    targetParts = { 'left_leg', 'right_leg' }
                end
            elseif op.type == 'harvest' then
                targetParts = { 'torso' } -- organs are on torso/head
                for _, org in ipairs(SurgeryMod.ORGANS) do
                    if org.id == op.organ then
                        targetParts = { org.part }
                        break
                    end
                end
            end

            -- Draw operation row
            local rowH = 22
            if canDo then
                love.graphics.setColor(C.label)
            else
                love.graphics.setColor(C.dim)
            end
            love.graphics.print(string.format('%s  (skill %d+, %ds)%s',
                op.label, op.minSkill, op.duration, reason), 30, y + 2)

            -- Queue buttons per target part (for install/amputate with L/R sides)
            if canDo and #targetParts > 0 then
                local btnX = sw - 300
                for _, tp in ipairs(targetParts) do
                    local btnW = 100
                    local partLabel = prettyPartName(tp)

                    addZone(entry.id .. '_' .. tp, btnX, y, btnW, rowH, 'queue_op', {
                        opId = entry.id, targetPart = tp
                    })
                    love.graphics.setColor(C.btn)
                    love.graphics.rectangle('fill', btnX, y, btnW, rowH, 3, 3)
                    love.graphics.setColor(C.btnText)
                    love.graphics.print(partLabel, btnX + 4, y + 2)
                    btnX = btnX + btnW + 8
                end
            end

            y = y + rowH + 4
        end
    end

    -- Show current queue for first surgery table
    y = y + 16
    love.graphics.setColor(C.label)
    love.graphics.print('Surgery Queue:', 20, y)
    y = y + 22

    local anyQueued = false
    for _, t in ipairs(tables) do
        local queue = t.machine._surgeryQueue
        if queue and #queue > 0 then
            for qi, qentry in ipairs(queue) do
                if y > 50 and y < sh then
                    anyQueued = true
                    local opDef = ops[qentry.opId]
                    local patientCol = ECS.isAlive(qentry.patientId) and ECS.get(qentry.patientId, 'colonist') or nil
                    local pName = patientCol and patientCol.name or '???'
                    local progress = qentry.progress or 0
                    local duration = opDef and opDef.duration or 1

                    love.graphics.setColor(C.label)
                    love.graphics.print(string.format('%d. %s on %s (%s) — %.0f%%',
                        qi,
                        opDef and opDef.label or qentry.opId,
                        pName,
                        prettyPartName(qentry.targetPart or '?'),
                        math.min(100, progress / math.max(duration, 1) * 100)), 30, y)

                    -- Cancel button
                    local cancelX = sw - 100
                    addZone('cancel_' .. qi, cancelX, y, 70, 18, 'cancel_queue', {
                        tableId = t.id, index = qi
                    })
                    love.graphics.setColor(C.critical)
                    love.graphics.rectangle('fill', cancelX, y, 70, 18, 3, 3)
                    love.graphics.setColor(C.label)
                    love.graphics.print('Cancel', cancelX + 8, y + 1)

                    y = y + 22
                end
            end
        end
    end

    if not anyQueued then
        love.graphics.setColor(C.dim)
        love.graphics.print('No pending operations.', 30, y)
    end
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function MedPanel.draw()
    if not visible then return end

    local sw, sh = love.graphics.getDimensions()
    hitZones = {}

    -- Backdrop
    love.graphics.setColor(C.bg)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header
    love.graphics.setColor(C.header)
    love.graphics.rectangle('fill', 0, 0, sw, 50)
    love.graphics.setColor(C.headerLine)
    love.graphics.line(0, 50, sw, 50)
    love.graphics.setColor(C.label)
    love.graphics.print('Medical Overview (H)', sw / 2 - 70, 16)

    -- Clip every view below the header. The detail and surgery views scroll a
    -- bare `y = 100 - scrollY` cursor, so their section titles used to print at
    -- negative y across the header bar.
    local bodyTop = 52
    local bodyH = sh - bodyTop - Layout.BOTTOM_RESERVE - 22
    Layout.pushClip(0, bodyTop, sw, bodyH)
    if view == 'list' then
        drawList()
    elseif view == 'detail' then
        drawDetail()
    elseif view == 'surgery' then
        drawSurgery()
    end
    Layout.popClip()

    -- Footer hint, kept clear of the bottom toolbar
    love.graphics.setColor(C.dim)
    love.graphics.print('H — close    Scroll — navigate', 20, sh - Layout.BOTTOM_RESERVE - 18)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function MedPanel.keypressed(key)
    if not visible then return false end
    if key == 'h' then
        MedPanel.toggle()
        return true
    end
    if key == 'escape' then
        if view == 'surgery' then
            view = 'detail'
            scrollY = 0
            return true
        elseif view == 'detail' then
            view = 'list'
            scrollY = 0
            selectedId = nil
            return true
        else
            MedPanel.toggle()
            return true
        end
    end
    return true -- consume all keys while open
end

function MedPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end

    for _, zone in ipairs(hitZones) do
        if x >= zone.x and x <= zone.x + zone.w and y >= zone.y and y <= zone.y + zone.h then
            if zone.action == 'select_colonist' then
                selectedId = zone.data
                view = 'detail'
                scrollY = 0
                return true
            elseif zone.action == 'back' then
                view = 'list'
                scrollY = 0
                selectedId = nil
                return true
            elseif zone.action == 'back_to_detail' then
                view = 'detail'
                scrollY = 0
                return true
            elseif zone.action == 'open_surgery' then
                view = 'surgery'
                scrollY = 0
                return true
            elseif zone.action == 'queue_op' then
                -- Find first surgery table and queue operation
                local sok, SurgeryMod = pcall(require, 'src.medical.surgery')
                if sok and selectedId then
                    for tid, tcomps in ECS.query('machine') do
                        if tcomps.machine.type == 'surgery_table' then
                            SurgeryMod.queueOperation(tid, zone.data.opId, selectedId, zone.data.targetPart)
                            break
                        end
                    end
                end
                return true
            elseif zone.action == 'cancel_queue' then
                local data = zone.data
                local machine = ECS.get(data.tableId, 'machine')
                if machine and machine._surgeryQueue then
                    table.remove(machine._surgeryQueue, data.index)
                end
                return true
            end
        end
    end

    return true -- consume click while open
end

function MedPanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return MedPanel
