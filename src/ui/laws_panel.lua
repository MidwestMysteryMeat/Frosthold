-- laws_panel.lua — Colony laws panel (Frostpunk-style irreversible law trees)
-- Shows three law tracks (Labor, Sustenance, Order) with tiered escalation.
-- Laws are PERMANENT once enacted — the UI must make this very clear.

local Layout = require('src.ui.ui_layout')

local LawsPanel = {}

local visible = false
local scrollY = 0
local contentH = 0
local viewH = 0
local lawRects = {}
local confirmTarget = nil  -- { treeId, lawId, law } awaiting confirmation
local confirmRects = {}    -- { yes = {x,y,w,h}, no = {x,y,w,h} }

-- Stable iteration order for the three trees
local TREE_ORDER = { 'labor', 'sustenance', 'order' }

local TREE_COLORS = {
    labor      = { 0.75, 0.55, 0.30 },  -- amber
    sustenance = { 0.40, 0.70, 0.45 },  -- green
    order      = { 0.50, 0.45, 0.80 },  -- purple
}

local TREE_ICONS = {
    labor      = '[LABOR]',
    sustenance = '[FOOD]',
    order      = '[ORDER]',
}

function LawsPanel.toggle()
    visible = not visible
    scrollY = 0
    confirmTarget = nil
end

function LawsPanel.isVisible()
    return visible
end

---------------------------------------------------------------------------
-- Drawing helpers
---------------------------------------------------------------------------

local function drawConfirmDialog(sw, sh, law)
    -- Dim backdrop
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    local dlgW = math.min(460, sw - 40)
    local dlgH = 180
    local dlgX = math.floor((sw - dlgW) / 2)
    local dlgY = math.floor((sh - dlgH) / 2)

    -- Dialog box
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle('fill', dlgX, dlgY, dlgW, dlgH, 6)

    local borderColor = law.crossesMoralLine and { 0.8, 0.2, 0.2, 0.9 } or { 0.6, 0.5, 0.3, 0.9 }
    love.graphics.setColor(unpack(borderColor))
    love.graphics.rectangle('line', dlgX, dlgY, dlgW, dlgH, 6)

    -- Warning header
    if law.crossesMoralLine then
        love.graphics.setColor(1, 0.25, 0.25)
        love.graphics.print('MORAL EVENT HORIZON', dlgX + 16, dlgY + 12)
        love.graphics.setColor(0.8, 0.3, 0.3)
        love.graphics.print('This law crosses a line that cannot be uncrossed.',
            dlgX + 16, dlgY + 30)
    else
        love.graphics.setColor(1, 0.85, 0.4)
        love.graphics.print('ENACT LAW — PERMANENT', dlgX + 16, dlgY + 12)
        love.graphics.setColor(0.7, 0.6, 0.4)
        love.graphics.print('This law CANNOT be repealed once enacted.',
            dlgX + 16, dlgY + 30)
    end

    -- Law name and description
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.print(law.name or '???', dlgX + 16, dlgY + 56)
    love.graphics.setColor(0.6, 0.6, 0.6)
    -- printf wraps on measured width. The old math.floor((dlgW-32)/7) assumed
    -- 7px per character, so a long law description ran 44px outside the dialog.
    love.graphics.printf(law.desc or '', dlgX + 16, dlgY + 76, dlgW - 32)

    -- Buttons
    local btnW = 100
    local btnH = 30
    local btnY = dlgY + dlgH - 46

    -- Yes button
    local yesX = dlgX + dlgW / 2 - btnW - 16
    love.graphics.setColor(0.5, 0.18, 0.18)
    love.graphics.rectangle('fill', yesX, btnY, btnW, btnH, 4)
    love.graphics.setColor(1, 0.6, 0.6)
    love.graphics.rectangle('line', yesX, btnY, btnW, btnH, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('ENACT', yesX + 28, btnY + 7)

    -- No button
    local noX = dlgX + dlgW / 2 + 16
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle('fill', noX, btnY, btnW, btnH, 4)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.rectangle('line', noX, btnY, btnW, btnH, 4)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print('Cancel', noX + 26, btnY + 7)

    confirmRects = {
        yes = { x = yesX, y = btnY, w = btnW, h = btnH },
        no  = { x = noX,  y = btnY, w = btnW, h = btnH },
    }
end

local function formatEffects(law)
    local fx = {}
    local e = law.effects or {}
    if e.workHoursAdd and e.workHoursAdd ~= 0 then
        fx[#fx + 1] = string.format('Work +%dh', e.workHoursAdd)
    end
    if e.workSpeedMult and e.workSpeedMult ~= 1 then
        fx[#fx + 1] = string.format('Work speed %.0f%%', e.workSpeedMult * 100)
    end
    if e.moraleDrainMult and e.moraleDrainMult ~= 1 then
        fx[#fx + 1] = string.format('Morale drain %.0f%%', e.moraleDrainMult * 100)
    end
    if e.foodDrainMult and e.foodDrainMult ~= 1 then
        fx[#fx + 1] = string.format('Food drain %.0f%%', e.foodDrainMult * 100)
    end
    if e.restRecoveryMult and e.restRecoveryMult ~= 1 then
        fx[#fx + 1] = string.format('Rest recovery %.0f%%', e.restRecoveryMult * 100)
    end
    if e.noExemptions then fx[#fx + 1] = 'No exemptions' end
    if e.blockMentalBreak then fx[#fx + 1] = 'Block mental breaks' end
    if e.moraleLock then fx[#fx + 1] = string.format('Morale locked at %d', e.moraleLock) end
    if e.noFoodMorale then fx[#fx + 1] = 'No food morale' end
    if e.woundedFoodPenalty then fx[#fx + 1] = 'Wounded get less food' end
    if e.foodPerDeath and e.foodPerDeath > 0 then
        fx[#fx + 1] = string.format('+%d food per death', e.foodPerDeath)
    end
    if e.curfew then fx[#fx + 1] = 'Curfew active' end
    if e.prisonBreakMult and e.prisonBreakMult ~= 1 then
        fx[#fx + 1] = string.format('Prison breaks %.0f%%', e.prisonBreakMult * 100)
    end
    if e.hopeBonusPerDay then
        fx[#fx + 1] = string.format('+%d hope/day', e.hopeBonusPerDay)
    end
    if e.discontentBonusPerDay then
        fx[#fx + 1] = string.format('+%d discontent/day', e.discontentBonusPerDay)
    end
    if e.noSocialFights then fx[#fx + 1] = 'No social fights' end
    if e.socialBondRate and e.socialBondRate ~= 1 then
        fx[#fx + 1] = string.format('Bond rate %.0f%%', e.socialBondRate * 100)
    end
    if e.discontentCap then
        fx[#fx + 1] = string.format('Discontent capped at %d', e.discontentCap)
    end
    if e.hopeFloor then
        fx[#fx + 1] = string.format('Hope floor %d', e.hopeFloor)
    end
    if e.combatBuff and e.combatBuff ~= 0 then
        fx[#fx + 1] = string.format('Combat +%.0f%%', e.combatBuff * 100)
    end
    return fx
end

---------------------------------------------------------------------------
-- Main draw
---------------------------------------------------------------------------

function LawsPanel.draw()
    if not visible then return end

    local lok, Laws = pcall(require, 'src.colony.laws')
    if not lok then return end

    local sw, sh = love.graphics.getDimensions()
    lawRects = {}

    -- Full-screen backdrop
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header bar
    love.graphics.setColor(0.1, 0.12, 0.16)
    love.graphics.rectangle('fill', 0, 0, sw, 50)
    love.graphics.setColor(0.25, 0.35, 0.45)
    love.graphics.line(0, 50, sw, 50)

    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.print('COLONY LAWS', 20, 16)
    love.graphics.setColor(0.45, 0.45, 0.45)
    do
        local hint = 'L / ESC to close'
        love.graphics.print(hint, sw - Layout.textWidth(hint) - 20, 16)
    end

    -- Moral line warning
    if Laws.hasCrossedMoralLine() then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
        love.graphics.print('You have crossed the moral event horizon.', sw / 2 - 140, 16)
    end

    -- Subtitle
    love.graphics.setColor(0.5, 0.45, 0.35)
    love.graphics.print('Laws are PERMANENT once enacted. Choose carefully.', 20, 56)

    -- Three-column layout for law trees
    local colCount = #TREE_ORDER
    local margin = 16
    local colGap = 12
    local totalGap = (colCount - 1) * colGap + margin * 2
    local colW = math.floor((sw - totalGap) / colCount)

    -- Clip the columns below the subtitle. Cards straddling y=50 used to paint
    -- over the header bar and remained clickable there.
    local listTop = 74
    local listH = sh - listTop - Layout.BOTTOM_RESERVE - 8
    local maxLaws = 0
    for _, treeId in ipairs(TREE_ORDER) do
        local ts = Laws.getTreeState(treeId)
        if ts then maxLaws = math.max(maxLaws, #ts.laws) end
    end
    contentH = 36 + maxLaws * 98 + 8
    scrollY = (Layout.clampScroll(scrollY, contentH, listH))
    viewH = listH
    local clip = Layout.pushClip(0, listTop, sw, listH)
    local baseY = 80 - scrollY

    for colIdx, treeId in ipairs(TREE_ORDER) do
        local treeState = Laws.getTreeState(treeId)
        if treeState then
            local colX = margin + (colIdx - 1) * (colW + colGap)
            local tc = TREE_COLORS[treeId] or { 0.6, 0.6, 0.6 }
            local icon = TREE_ICONS[treeId] or ''

            -- Tree header
            local headerY = baseY
            if headerY + 28 > clip.y and headerY < clip.y + clip.h then
                love.graphics.setColor(tc[1], tc[2], tc[3], 0.15)
                love.graphics.rectangle('fill', colX, headerY, colW, 28, 4)
                love.graphics.setColor(tc[1], tc[2], tc[3], 0.6)
                love.graphics.rectangle('line', colX, headerY, colW, 28, 4)
                love.graphics.setColor(tc[1], tc[2], tc[3])
                love.graphics.print(icon .. ' ' .. treeState.name, colX + 8, headerY + 6)
            end

            -- Law cards
            local cardY = headerY + 36
            local cardH = 90

            for _, law in ipairs(treeState.laws) do
                if cardY + cardH > clip.y and cardY < clip.y + clip.h then
                    local enacted = law.enacted
                    local canEnact = law.canEnact

                    -- Card background
                    if enacted then
                        love.graphics.setColor(0.08, 0.18, 0.08)
                    elseif canEnact then
                        love.graphics.setColor(0.12, 0.10, 0.06)
                    else
                        love.graphics.setColor(0.05, 0.05, 0.06)
                    end
                    love.graphics.rectangle('fill', colX, cardY, colW, cardH, 4)

                    -- Card border
                    if enacted then
                        love.graphics.setColor(0.3, 0.7, 0.3, 0.6)
                    elseif canEnact then
                        love.graphics.setColor(tc[1], tc[2], tc[3], 0.5)
                    else
                        love.graphics.setColor(0.15, 0.15, 0.15)
                    end
                    love.graphics.rectangle('line', colX, cardY, colW, cardH, 4)

                    -- Tier badge
                    local tierX = colX + 6
                    local tierY = cardY + 6
                    if law.crossesMoralLine then
                        love.graphics.setColor(0.6, 0.15, 0.15)
                    else
                        love.graphics.setColor(tc[1] * 0.4, tc[2] * 0.4, tc[3] * 0.4)
                    end
                    love.graphics.rectangle('fill', tierX, tierY, 20, 16, 3)
                    love.graphics.setColor(0.9, 0.9, 0.9)
                    love.graphics.print(tostring(law.tier), tierX + 6, tierY + 1)

                    -- Status indicator
                    -- Badge right-aligned by measurement; 'AVAILABLE' at a
                    -- hardcoded colW-72 landed exactly on the card border and
                    -- overlapped long law names by 8px.
                    local badge, badgeColor
                    if enacted then
                        badge, badgeColor = 'ENACTED', { 0.3, 0.8, 0.3 }
                    elseif canEnact then
                        badge, badgeColor = 'AVAILABLE', { tc[1], tc[2], tc[3], 0.8 }
                    else
                        badge, badgeColor = 'LOCKED', { 0.3, 0.3, 0.3 }
                    end
                    local badgeX = colX + colW - Layout.textWidth(badge) - 8
                    love.graphics.setColor(badgeColor)
                    love.graphics.print(badge, badgeX, cardY + 6)

                    -- Law name
                    local nameColor = enacted and 0.95 or (canEnact and 0.85 or 0.4)
                    love.graphics.setColor(nameColor, nameColor, nameColor)
                    love.graphics.print(Layout.fitLabel(law.name or '???', colX + 32, badgeX),
                        colX + 32, cardY + 6)

                    -- Description: wrapped to the card, two lines max. Slicing
                    -- at 6px per character overflowed 120px into the next column.
                    local descAlpha = enacted and 0.6 or (canEnact and 0.55 or 0.3)
                    love.graphics.setColor(descAlpha, descAlpha, descAlpha)
                    love.graphics.printf(law.desc or '', colX + 8, cardY + 26, colW - 16)

                    -- Effects summary (compact)
                    local rawLaw = Laws.LAW_TREES[treeId]
                    local fullLaw = nil
                    if rawLaw then
                        for _, rl in ipairs(rawLaw.laws) do
                            if rl.id == law.id then fullLaw = rl; break end
                        end
                    end
                    if fullLaw then
                        local fx = formatEffects(fullLaw)
                        if #fx > 0 then
                            love.graphics.setColor(0.55, 0.45, 0.3, enacted and 0.8 or 0.6)
                            love.graphics.print(
                                Layout.truncate(table.concat(fx, ' | '), colW - 16),
                                colX + 8, cardY + 58)
                        end

                        -- Hope/discontent impact
                        local impactParts = {}
                        if fullLaw.hopeChange and fullLaw.hopeChange ~= 0 then
                            impactParts[#impactParts + 1] = string.format('Hope %+d', fullLaw.hopeChange)
                        end
                        if fullLaw.discontentChange and fullLaw.discontentChange ~= 0 then
                            impactParts[#impactParts + 1] = string.format('Discontent %+d', fullLaw.discontentChange)
                        end
                        if #impactParts > 0 then
                            local impactColor = (fullLaw.hopeChange or 0) < 0
                                and { 0.7, 0.35, 0.35 } or { 0.5, 0.5, 0.5 }
                            love.graphics.setColor(impactColor[1], impactColor[2], impactColor[3],
                                enacted and 0.6 or 0.8)
                            love.graphics.print(table.concat(impactParts, '  '),
                                colX + 8, cardY + 74)
                        end
                    end

                    -- Moral line skull marker
                    if law.crossesMoralLine then
                        love.graphics.setColor(0.8, 0.15, 0.15, enacted and 0.5 or 0.8)
                        love.graphics.print('!!!', colX + colW - 26, cardY + cardH - 18)
                    end

                    -- Clickable rect (only for enactable laws that are fully
                    -- inside the clipped list — a card scrolled under the header
                    -- must not stay clickable there)
                    if canEnact and not enacted
                       and cardY >= clip.y and cardY + cardH <= clip.y + clip.h then
                        lawRects[#lawRects + 1] = {
                            x = colX, y = cardY, w = colW, h = cardH,
                            treeId = treeId, lawId = law.id, law = law,
                        }
                    end
                end

                -- Connection line between tiers
                if law.tier < 4 then
                    local lineY = cardY + cardH
                    if lineY > 50 and lineY + 8 < sh then
                        -- law.enacted, not the `enacted` local: that one is scoped
                        -- to the on-screen-card branch above, which has closed here.
                        if law.enacted then
                            love.graphics.setColor(0.3, 0.6, 0.3, 0.5)
                        else
                            love.graphics.setColor(0.2, 0.2, 0.2, 0.4)
                        end
                        local midX = colX + math.floor(colW / 2)
                        love.graphics.line(midX, lineY, midX, lineY + 8)
                    end
                end

                cardY = cardY + cardH + 8
            end
        end
    end

    Layout.popClip()
    Layout.drawScrollbar({ x = 0, y = listTop, w = sw, h = listH }, scrollY, contentH)

    -- Confirmation dialog overlay (drawn last, on top of everything)
    if confirmTarget then
        drawConfirmDialog(sw, sh, confirmTarget.law)
    end
end

---------------------------------------------------------------------------
-- Input handlers
---------------------------------------------------------------------------

function LawsPanel.keypressed(key)
    if not visible then return false end
    if confirmTarget then
        if key == 'escape' then
            confirmTarget = nil
            confirmRects = {}
            return true
        end
        return true
    end
    if key == 'l' or key == 'escape' then
        visible = false
        return true
    end
    return true
end

function LawsPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end

    -- Confirmation dialog active — check dialog buttons
    if confirmTarget then
        local yes = confirmRects.yes
        local no = confirmRects.no
        if yes and x >= yes.x and x <= yes.x + yes.w
        and y >= yes.y and y <= yes.y + yes.h then
            -- Enact the law
            local lok, Laws = pcall(require, 'src.colony.laws')
            if lok then
                Laws.enact(confirmTarget.treeId, confirmTarget.lawId)
            end
            confirmTarget = nil
            confirmRects = {}
            return true
        end
        if no and x >= no.x and x <= no.x + no.w
        and y >= no.y and y <= no.y + no.h then
            confirmTarget = nil
            confirmRects = {}
            return true
        end
        -- Click outside dialog dismisses it
        confirmTarget = nil
        confirmRects = {}
        return true
    end

    -- Check law card clicks
    for _, rect in ipairs(lawRects) do
        if x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h then
            -- Open confirmation dialog — need full law data for the dialog
            local lok, Laws = pcall(require, 'src.colony.laws')
            if lok then
                local tree = Laws.LAW_TREES[rect.treeId]
                if tree then
                    for _, fullLaw in ipairs(tree.laws) do
                        if fullLaw.id == rect.lawId then
                            confirmTarget = {
                                treeId = rect.treeId,
                                lawId = rect.lawId,
                                law = fullLaw,
                            }
                            confirmRects = {}
                            break
                        end
                    end
                end
            end
            return true
        end
    end

    return true
end

function LawsPanel.wheelmoved(dx, dy)
    if not visible then return false end
    if confirmTarget then return true end
    scrollY = (Layout.clampScroll(scrollY - dy * 30, contentH, viewH))
    return true
end

return LawsPanel
