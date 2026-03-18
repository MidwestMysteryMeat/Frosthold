-- policy_panel.lua — Colony policy management panel

local GameState = require('src.game_state')

local PolicyPanel = {}

local visible = false
local policyRects = {}

function PolicyPanel.toggle()
    visible = not visible
end

function PolicyPanel.isVisible()
    return visible
end

function PolicyPanel.draw()
    if not visible then return end

    local pok, Policies = pcall(require, 'src.colony.policies')
    if not pok then return end

    local sw, sh = love.graphics.getDimensions()
    policyRects = {}

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header
    love.graphics.setColor(0.1, 0.12, 0.16)
    love.graphics.rectangle('fill', 0, 0, sw, 50)
    love.graphics.setColor(0.25, 0.35, 0.45)
    love.graphics.line(0, 50, sw, 50)

    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.print('COLONY POLICIES', 20, 16)
    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('P / ESC to close', sw - 130, 16)

    -- Active modifiers summary
    local sumY = 58
    love.graphics.setColor(0.6, 0.6, 0.5)
    local mods = {}
    local wsm = Policies.getWorkSpeedMult and Policies.getWorkSpeedMult() or 1
    local fdm = Policies.getFoodDrainMult and Policies.getFoodDrainMult() or 1
    local mda = Policies.getMoraleDrainAdd and Policies.getMoraleDrainAdd() or 0
    if wsm ~= 1 then mods[#mods + 1] = string.format('Work speed: %.0f%%', wsm * 100) end
    if fdm ~= 1 then mods[#mods + 1] = string.format('Food drain: %.0f%%', fdm * 100) end
    if mda ~= 0 then mods[#mods + 1] = string.format('Morale drain: %+.0f%%', mda * 100) end
    if #mods > 0 then
        love.graphics.print('Active effects: ' .. table.concat(mods, '  |  '), 20, sumY)
    else
        love.graphics.print('No active policies. Click to toggle.', 20, sumY)
    end

    -- Policy cards
    local order = Policies.getOrder and Policies.getOrder() or {}
    local cardY = 84
    local cardW = math.min(sw - 40, 800)
    local cardH = 64

    for _, policyId in ipairs(order) do
        local pol = Policies.get and Policies.get(policyId)
        if pol then
            local isActive = Policies.isActive(policyId)

            policyRects[#policyRects + 1] = {
                x = 20, y = cardY, w = cardW, h = cardH, id = policyId
            }

            -- Background
            if isActive then
                love.graphics.setColor(0.1, 0.2, 0.1)
            else
                love.graphics.setColor(0.07, 0.07, 0.09)
            end
            love.graphics.rectangle('fill', 20, cardY, cardW, cardH, 4)

            -- Border
            if isActive then
                love.graphics.setColor(0.3, 0.7, 0.3, 0.6)
            else
                love.graphics.setColor(0.2, 0.2, 0.25)
            end
            love.graphics.rectangle('line', 20, cardY, cardW, cardH, 4)

            -- Toggle indicator
            if isActive then
                love.graphics.setColor(0.3, 0.8, 0.3)
                love.graphics.rectangle('fill', 30, cardY + 8, 30, 16, 3)
                love.graphics.setColor(0, 0, 0)
                love.graphics.print('ON', 36, cardY + 9)
            else
                love.graphics.setColor(0.25, 0.25, 0.25)
                love.graphics.rectangle('fill', 30, cardY + 8, 30, 16, 3)
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print('OFF', 33, cardY + 9)
            end

            -- Name
            local nc = isActive and 1 or 0.65
            love.graphics.setColor(nc, nc, nc)
            love.graphics.print(pol.name or policyId, 72, cardY + 8)

            -- Description
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print(pol.description or '', 72, cardY + 26)

            -- Effects
            if pol.effects then
                local fx = {}
                local e = pol.effects
                if e.workSpeedMult and e.workSpeedMult ~= 1 then
                    fx[#fx + 1] = string.format('Work %.0f%%', e.workSpeedMult * 100)
                end
                if e.foodDrainMult and e.foodDrainMult ~= 1 then
                    fx[#fx + 1] = string.format('Food drain %.0f%%', e.foodDrainMult * 100)
                end
                if e.moraleDrainAdd and e.moraleDrainAdd ~= 0 then
                    fx[#fx + 1] = string.format('Morale %+.0f%%', e.moraleDrainAdd * 100)
                end
                if e.quotaShipmentMult and e.quotaShipmentMult ~= 1 then
                    fx[#fx + 1] = string.format('Quota %.0f%%', e.quotaShipmentMult * 100)
                end
                if e.heatSignatureMult and e.heatSignatureMult ~= 1 then
                    fx[#fx + 1] = string.format('Heat sig %.0f%%', e.heatSignatureMult * 100)
                end
                if e.warmthMult and e.warmthMult ~= 1 then
                    fx[#fx + 1] = string.format('Warmth %.0f%%', e.warmthMult * 100)
                end
                if e.noFreeTime then fx[#fx + 1] = 'No free time' end
                if e.blockMentalBreak then fx[#fx + 1] = 'Block mental breaks' end
                if e.supplyBonus then fx[#fx + 1] = 'Supply bonus' end
                if #fx > 0 then
                    love.graphics.setColor(0.55, 0.5, 0.35)
                    love.graphics.print(table.concat(fx, ' | '), 72, cardY + 44)
                end
            end

            cardY = cardY + cardH + 8
        end
    end
end

function PolicyPanel.keypressed(key)
    if not visible then return false end
    if key == 'p' or key == 'escape' then
        visible = false
        return true
    end
    return true
end

function PolicyPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button == 1 then
        local pok, Policies = pcall(require, 'src.colony.policies')
        if pok and Policies.toggle then
            for _, rect in ipairs(policyRects) do
                if x >= rect.x and x <= rect.x + rect.w
                and y >= rect.y and y <= rect.y + rect.h then
                    Policies.toggle(rect.id)
                    return true
                end
            end
        end
    end
    return true
end

function PolicyPanel.wheelmoved(dx, dy)
    if not visible then return false end
    return true
end

return PolicyPanel
