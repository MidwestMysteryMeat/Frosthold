-- colonist_info.lua — Expanded colonist info panel tabs
-- Bio: backstory, traits, passions, work restrictions, family
-- Combat: stance, kills, scars, prosthetics, equipment effectiveness
-- Log: personal event history

local ECS       = require('src.ecs.ecs')
local Layout = require('src.ui.ui_layout')
local GameState = require('src.game_state')

local ColonistInfo = {}

local screenW, screenH = love.graphics.getDimensions()

local function updateScreenSize()
    screenW, screenH = love.graphics.getDimensions()
end

---------------------------------------------------------------------------
-- Bio Tab
---------------------------------------------------------------------------

function ColonistInfo.drawBioTab(id, col, y)
    updateScreenSize()
    local x = 16
    local rightCol = 300

    -- Name and age
    love.graphics.setColor(1, 1, 1)
    local name = col.name or 'Unknown'
    love.graphics.print('Name: ' .. name, x, y)
    y = y + 16

    if col.age or col.gender then
        love.graphics.setColor(0.7, 0.7, 0.7)
        local info = ''
        if col.age then info = 'Age: ' .. col.age end
        if col.gender then
            local gLabel = col.gender == 'male' and 'Male' or (col.gender == 'female' and 'Female' or 'Non-binary')
            if info ~= '' then info = info .. '  |  ' end
            info = info .. gLabel
        end
        love.graphics.print(info, x, y)
        y = y + 16
    end

    -- Backstory
    if col.backstory then
        love.graphics.setColor(0.6, 0.6, 0.55)
        love.graphics.print('Background: ' .. col.backstory, x, y)
        y = y + 16
    end

    local sok, Social = pcall(require, 'src.colonist.social')
    if sok and Social.getBond then
        local bond = Social.getBond(id)
        if bond and ECS.isAlive(bond.partnerId) then
            local partner = ECS.get(bond.partnerId, 'colonist')
            if partner then
                love.graphics.setColor(0.85, 0.72, 0.62)
                local label = bond.stage == 'lovers' and 'Lover' or 'Dating'
                love.graphics.print(label .. ': ' .. (partner.name or 'Unknown'), x, y)
                y = y + 16
            end
        end
    end

    -- Origin work restrictions
    if col.origin and col.origin.disabledWork then
        love.graphics.setColor(0.9, 0.4, 0.3)
        local disabled = {}
        for work in pairs(col.origin.disabledWork) do
            disabled[#disabled + 1] = work
        end
        if #disabled > 0 then
            love.graphics.print('Cannot: ' .. table.concat(disabled, ', '), x, y)
            y = y + 16
        end
    end

    -- Traits with detail
    if col.traits and #col.traits > 0 then
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print('Traits:', x, y)
        y = y + 14
        for _, t in ipairs(col.traits) do
            if y > screenH - 14 then break end
            -- Color by impact
            if (t.workSpeed and t.workSpeed > 0) or (t.combatMod and t.combatMod > 0) then
                love.graphics.setColor(0.3, 0.9, 0.4)
            elseif (t.workSpeed and t.workSpeed < 0) or (t.combatMod and t.combatMod < 0) then
                love.graphics.setColor(0.9, 0.4, 0.3)
            else
                love.graphics.setColor(0.7, 0.7, 0.5)
            end
            love.graphics.print('  ' .. (t.name or t.id), x, y)
            -- Short desc to the right
            if t.desc then
                love.graphics.setColor(0.5, 0.5, 0.5)
                local descTrunc = Layout.truncate(t.desc, screenW - (x + 140) - 20)
                love.graphics.print(descTrunc, x + 140, y)
            end
            y = y + 13
        end
    end

    -- Skills with passions (right column)
    local skillsOk, Skills = pcall(require, 'src.colonist.skills')
    if skillsOk and col.skills then
        local sy = y - (#(col.traits or {}) * 13 + 14)
        if sy < y - 100 then sy = y - 100 end  -- clamp
        sy = math.max(sy, (screenH - 200) + 76)  -- don't go above tab content area

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print('Skills:', rightCol, sy)
        sy = sy + 14
        local skillNames = {
            'mining', 'build', 'cooking', 'hunting', 'research',
            'medical', 'melee', 'ranged', 'farming', 'social',
        }
        for _, sk in ipairs(skillNames) do
            if sy > screenH - 14 then break end
            local level = col.skills[sk] or 0
            if level > 0 then
                local passion = sok and Skills.getPassion(id, sk) or 0
                local passionStr = ''
                if passion == 2 then
                    passionStr = ' **'
                    love.graphics.setColor(1.0, 0.85, 0.2)
                elseif passion == 1 then
                    passionStr = ' *'
                    love.graphics.setColor(0.6, 0.8, 1.0)
                else
                    love.graphics.setColor(0.6, 0.6, 0.6)
                end
                love.graphics.print(string.format('  %s: %d%s', sk, level, passionStr), rightCol, sy)
                sy = sy + 13
            end
        end
    end
end

---------------------------------------------------------------------------
-- Combat Tab
---------------------------------------------------------------------------

function ColonistInfo.drawCombatTab(id, col, y)
    updateScreenSize()
    local x = 16

    -- Combat stance
    local caOk, CombatAI = pcall(require, 'src.combat.combat_ai')
    if caOk and CombatAI.getStance then
        local stance = CombatAI.getStance(id)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print('Stance: ' .. (stance or 'balanced'), x, y)
        y = y + 16
    end

    -- Equipment effectiveness
    local eqOk, Equipment = pcall(require, 'src.colonist.equipment')
    if eqOk then
        local weapon = Equipment.getWeapon(id)
        local armor = Equipment.getArmor(id)

        if weapon then
            love.graphics.setColor(0.9, 0.7, 0.3)
            local wpnStr = weapon.name or 'Unknown'
            if weapon.dmg then wpnStr = wpnStr .. ' (DMG:' .. weapon.dmg .. ')' end
            if weapon.range then wpnStr = wpnStr .. ' (RNG:' .. weapon.range .. ')' end
            love.graphics.print('Weapon: ' .. wpnStr, x, y)
            y = y + 14
        end

        if armor then
            love.graphics.setColor(0.5, 0.7, 0.9)
            local armStr = armor.name or 'Unknown'
            if armor.reduction then armStr = armStr .. ' (DEF:' .. armor.reduction .. ')' end
            love.graphics.print('Armor: ' .. armStr, x, y)
            y = y + 14
        end
    end

    y = y + 4

    -- Kill count
    love.graphics.setColor(0.8, 0.8, 0.8)
    local kills = col.kills or 0
    love.graphics.print('Kills: ' .. kills, x, y)
    y = y + 16

    -- Wounds / Scars
    local body = ECS.get(id, 'body')
    if body and body.parts then
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print('Body:', x, y)
        y = y + 14

        for partName, part in pairs(body.parts) do
            if y > screenH - 14 then break end
            local maxHp = part.maxHp or 0
            local hp = part.hp or maxHp
            local hpPct = maxHp > 0 and hp / maxHp or 1
            if hpPct < 1 then
                if hpPct > 0.5 then
                    love.graphics.setColor(0.9, 0.8, 0.2)
                else
                    love.graphics.setColor(0.9, 0.3, 0.3)
                end
                love.graphics.print(string.format('  %s: %d/%d', partName, hp, maxHp), x, y)
                y = y + 13
            end
        end
    end

    -- Prosthetics
    local pOk, Prosthetics = pcall(require, 'src.combat.prosthetics')
    if pOk and Prosthetics.list then
        local installed = Prosthetics.list(id)
        if installed and #installed > 0 then
            love.graphics.setColor(0.4, 0.8, 0.9)
            love.graphics.print('Prosthetics:', x + 200, y - 13 * #installed - 14)
            local py = y - 13 * #installed
            for _, p in ipairs(installed) do
                love.graphics.print('  ' .. (p.name or p.id) .. ' (' .. (p.part or '?') .. ')', x + 200, py)
                py = py + 13
            end
        end
    end

    -- Scar traits
    local stOk, ScarTraits = pcall(require, 'src.colonist.scar_traits')
    if stOk and ScarTraits.getScars then
        local scars = ScarTraits.getScars(id)
        if scars and #scars > 0 then
            love.graphics.setColor(0.7, 0.5, 0.5)
            love.graphics.print('Scars:', x + 200, y)
            y = y + 14
            for _, s in ipairs(scars) do
                if y > screenH - 14 then break end
                love.graphics.print('  ' .. (s.name or s.id), x + 200, y)
                y = y + 13
            end
        end
    end
end

---------------------------------------------------------------------------
-- Log Tab — personal event history
---------------------------------------------------------------------------

-- Each colonist stores a log of recent events in col.eventLog
-- We populate it from various systems that already notify colonists

function ColonistInfo.drawLogTab(id, col, y)
    updateScreenSize()
    local x = 16

    local eventLog = col.eventLog or {}

    if #eventLog == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No events recorded yet.', x, y)
        return
    end

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print('Recent Events:', x, y)
    y = y + 16

    -- Show most recent first, up to what fits on screen
    for i = #eventLog, 1, -1 do
        if y > screenH - 14 then break end
        local ev = eventLog[i]
        -- Day/hour prefix
        love.graphics.setColor(0.4, 0.4, 0.4)
        local prefix = string.format('D%d %02d:00', ev.day or 0, ev.hour or 0)
        love.graphics.print(prefix, x, y)

        -- Event text color by type
        if ev.type == 'danger' then
            love.graphics.setColor(0.9, 0.3, 0.3)
        elseif ev.type == 'positive' then
            love.graphics.setColor(0.3, 0.9, 0.4)
        elseif ev.type == 'social' then
            love.graphics.setColor(0.5, 0.7, 1.0)
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
        end
        love.graphics.print(ev.text or '', x + 80, y)
        y = y + 13
    end
end

---------------------------------------------------------------------------
-- Colonist event logging — call from various systems
---------------------------------------------------------------------------

local MAX_COLONIST_LOG = 50

function ColonistInfo.logEvent(colonistId, text, eventType)
    local col = ECS.get(colonistId, 'colonist')
    if not col then return end
    if not col.eventLog then col.eventLog = {} end

    col.eventLog[#col.eventLog + 1] = {
        text = text,
        type = eventType or 'neutral',
        day  = GameState.day,
        hour = math.floor(GameState.hour or 0),
    }

    -- Trim to max
    while #col.eventLog > MAX_COLONIST_LOG do
        table.remove(col.eventLog, 1)
    end
end

---------------------------------------------------------------------------
-- Character portrait (simple procedural ASCII-art style)
---------------------------------------------------------------------------

function ColonistInfo.drawPortrait(id, col, x, y, w, h)
    updateScreenSize()
    -- Background
    love.graphics.setColor(0.12, 0.12, 0.15)
    love.graphics.rectangle('fill', x, y, w, h, 4)
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle('line', x, y, w, h, 4)

    local cx = x + w / 2
    local cy = y + h / 2

    -- Body silhouette (simple shapes)
    -- Head
    love.graphics.setColor(0.7, 0.6, 0.5)
    love.graphics.circle('fill', cx, cy - h * 0.2, w * 0.12)

    -- Torso
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle('fill', cx - w * 0.15, cy - h * 0.05, w * 0.3, h * 0.25, 2)

    -- Arms
    love.graphics.rectangle('fill', cx - w * 0.25, cy - h * 0.03, w * 0.08, h * 0.2, 2)
    love.graphics.rectangle('fill', cx + w * 0.17, cy - h * 0.03, w * 0.08, h * 0.2, 2)

    -- Legs
    love.graphics.rectangle('fill', cx - w * 0.12, cy + h * 0.22, w * 0.1, h * 0.2, 2)
    love.graphics.rectangle('fill', cx + w * 0.02, cy + h * 0.22, w * 0.1, h * 0.2, 2)

    -- Wound indicators (red marks on injured parts)
    local body = ECS.get(id, 'body')
    if body and body.parts then
        love.graphics.setColor(0.9, 0.2, 0.2, 0.7)
        for partName, part in pairs(body.parts) do
            if (part.hp or 0) < (part.maxHp or 0) then
                if partName == 'head' then
                    love.graphics.circle('fill', cx + w * 0.08, cy - h * 0.22, 3)
                elseif partName == 'torso' then
                    love.graphics.circle('fill', cx + w * 0.05, cy + h * 0.05, 3)
                elseif partName == 'left_arm' then
                    love.graphics.circle('fill', cx - w * 0.22, cy + h * 0.05, 3)
                elseif partName == 'right_arm' then
                    love.graphics.circle('fill', cx + w * 0.22, cy + h * 0.05, 3)
                elseif partName == 'left_leg' then
                    love.graphics.circle('fill', cx - w * 0.08, cy + h * 0.32, 3)
                elseif partName == 'right_leg' then
                    love.graphics.circle('fill', cx + w * 0.08, cy + h * 0.32, 3)
                end
            end
        end
    end

    -- Prosthetic indicators (cyan marks)
    local pOk, Prosthetics = pcall(require, 'src.combat.prosthetics')
    if pOk and Prosthetics.list then
        local installed = Prosthetics.list(id)
        if installed then
            love.graphics.setColor(0.2, 0.8, 0.9, 0.8)
            for _, p in ipairs(installed) do
                if p.part == 'left_leg' then
                    love.graphics.rectangle('fill', cx - w * 0.14, cy + h * 0.22, w * 0.1, h * 0.2, 2)
                elseif p.part == 'right_leg' then
                    love.graphics.rectangle('fill', cx + w * 0.04, cy + h * 0.22, w * 0.1, h * 0.2, 2)
                elseif p.part == 'left_arm' then
                    love.graphics.rectangle('fill', cx - w * 0.27, cy - h * 0.03, w * 0.08, h * 0.2, 2)
                elseif p.part == 'right_arm' then
                    love.graphics.rectangle('fill', cx + w * 0.19, cy - h * 0.03, w * 0.08, h * 0.2, 2)
                end
            end
        end
    end

    -- Weapon icon (small rectangle by right hand)
    local eqOk, Equipment = pcall(require, 'src.colonist.equipment')
    if eqOk then
        local weapon = Equipment.getWeapon(id)
        if weapon then
            love.graphics.setColor(0.8, 0.6, 0.2)
            love.graphics.rectangle('fill', cx + w * 0.26, cy - h * 0.02, 3, h * 0.15, 1)
        end
    end
end

return ColonistInfo
