-- ui_selection.lua — Selection panel (bottom): colonist tabs (needs/health/social/work/schedule/gear)

local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')
local BuildingInfo = require('src.ui.ui_building_info')

local Selection = {}

-- Hit zones (rebuilt each frame during draw)
local tabBtns = {}
local workCells = {}
local scheduleCells = {}
local gearAutoBtn = nil

-- Selected tab state
local selectedTab = 'needs'

-- Drag state for work priority painting
local dragWork = nil

-- Shared screen dimensions (set from coordinator)
local screenW, screenH = 1280, 720

function Selection.resize(w, h)
    screenW = w
    screenH = h
end

function Selection.init()
    selectedTab = 'needs'
    tabBtns = {}
    workCells = {}
    scheduleCells = {}
    gearAutoBtn = nil
    BuildingInfo.clearEndgameActionBtn()
    BuildingInfo.clearInteractionBtns()
    dragWork = nil
end

function Selection.getTabBtns() return tabBtns end
function Selection.getWorkCells() return workCells end
function Selection.getScheduleCells() return scheduleCells end
function Selection.getGearAutoBtn() return gearAutoBtn end
function Selection.getEndgameActionBtn() return BuildingInfo.getEndgameActionBtn() end
function Selection.getInteractionBtns() return BuildingInfo.getInteractionBtns() end
function Selection.getSelectedTab() return selectedTab end
function Selection.setSelectedTab(tab) selectedTab = tab end
function Selection.getDragWork() return dragWork end
function Selection.setDragWork(val) dragWork = val end

---------------------------------------------------------------------------
-- Selection panel (bottom) with tabs
---------------------------------------------------------------------------

function Selection.drawSelectionPanel()
    tabBtns = {}
    workCells = {}
    scheduleCells = {}
    gearAutoBtn = nil
    BuildingInfo.clearEndgameActionBtn()
    BuildingInfo.clearInteractionBtns()

    local selected = {}
    for id in pairs(GameState.selectedEntities) do
        if ECS.isAlive(id) then
            selected[#selected + 1] = id
        end
    end
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    local panelH = math.max(230, fh * 12 + 40)
    local panelY = screenH - panelH

    if #selected == 0 and not GameState.selectedZoneId then
        return
    end

    -- Panel background — stronger separation from map
    love.graphics.setColor(0.03, 0.04, 0.07, 0.92)
    love.graphics.rectangle('fill', 0, panelY, screenW, panelH)
    love.graphics.setColor(0.25, 0.35, 0.5, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, panelY, screenW, panelY)
    love.graphics.setLineWidth(1)

    if #selected == 0 and GameState.selectedZoneId then
        BuildingInfo.drawZonePanel(GameState.selectedZoneId, panelY)
        return
    end

    if #selected == 1 then
        local id = selected[1]

        -- Endgame building panel
        local eg = ECS.get(id, 'endgame_building')
        if eg then
            BuildingInfo.drawEndgamePanel(id, eg, panelY)
            return
        end

        local fence = ECS.get(id, 'laser_fence')
        if fence then
            BuildingInfo.drawBarrierPanel(id, fence, panelY)
            return
        end

        local inserter = ECS.get(id, 'inserter')
        if inserter then
            BuildingInfo.drawInserterPanel(id, inserter, panelY)
            return
        end

        -- Building inspection panel (any entity with building_ref)
        local bref = ECS.get(id, 'building_ref')
        if bref and not ECS.get(id, 'colonist') then
            BuildingInfo.drawBuildingPanel(id, bref, panelY)
            return
        end

        local artifact = ECS.get(id, 'artifact')
        if artifact and not ECS.get(id, 'colonist') then
            BuildingInfo.drawArtifactPanel(id, artifact, panelY)
            return
        end

        -- Prisoner inspection panel
        local prisoner = ECS.get(id, 'prisoner')
        if prisoner then
            Selection.drawPrisonerPanel(id, prisoner, panelY)
            return
        end

        local col = ECS.get(id, 'colonist')
        local needs = ECS.get(id, 'needs')

        if col then
            -- Header: name + HP
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(col.name, 16, panelY + 8)

            local displayHealth = math.max(0, col.health)
            local hpText = string.format('HP: %.0f/%d', displayHealth, col.maxHealth)
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print(hpText, 16, panelY + 8 + fh + 2)

            -- HP bar
            local hpFrac = math.max(0, col.health / col.maxHealth)
            local hpBarW = 120
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle('fill', 16, panelY + 8 + fh * 2 + 4, hpBarW, 8)
            local hr = hpFrac < 0.3 and 1 or (1 - hpFrac)
            local hg = hpFrac > 0.5 and 0.8 or hpFrac
            love.graphics.setColor(hr, hg, 0.1)
            love.graphics.rectangle('fill', 16, panelY + 8 + fh * 2 + 4, hpBarW * hpFrac, 8)

            -- Character portrait (right side of header)
            do
                local ciOk, CInfo = pcall(require, 'src.ui.colonist_info')
                if ciOk then
                    CInfo.drawPortrait(id, col, screenW - 90, panelY + 4, 80, 110)
                end
            end

            -- Task
            local taskLabel = col.state or 'idle'
            if col.task then
                local jOk, Jobs = pcall(require, 'src.colonist.jobs')
                local task = jOk and Jobs.getTask(col.task.taskId) or nil
                if task then
                    if task.def.duration and task.def.duration > 0 then
                        taskLabel = string.format('%s (%s %.0f%%)', col.state, task.type,
                            (task.progress / task.def.duration) * 100)
                    else
                        taskLabel = string.format('%s (%s)', col.state, task.type)
                    end
                end
            end
            love.graphics.setColor(0.6, 0.7, 0.6)
            love.graphics.print(taskLabel, 150, panelY + 8 + fh + 2)

            -- Why idle hint
            if (col.state == 'idle' or col.state == 'drafted') and col._idleReason then
                local IDLE_LABELS = {
                    allowed_area = 'Returning to allowed area',
                    revolt     = 'Colony in revolt',
                    free_time  = 'Scheduled free time',
                    no_tasks   = 'No available tasks',
                    no_path    = 'Cannot reach task',
                    drafted    = 'Drafted (R or right-click to undraft)',
                }
                local hint = IDLE_LABELS[col._idleReason] or col._idleReason
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print('(' .. hint .. ')', 150, panelY + 8 + fh * 2 + 2)
            end

            -- Tab bar
            local tabs = { 'Needs', 'Health', 'Social', 'Work', 'Sched', 'Gear', 'Bio', 'Combat', 'Log' }
            local tabKeys = { 'needs', 'health', 'social', 'work', 'schedule', 'gear', 'bio', 'combat', 'log' }
            local tabX = 16
            local tabBtnH = fh + 6
            local tabY = panelY + 8 + fh * 2 + 16

            for ti, tname in ipairs(tabs) do
                local tw = font:getWidth(tname) + 16
                local isActive = selectedTab == tabKeys[ti]
                tabBtns[#tabBtns + 1] = { x = tabX, y = tabY, w = tw, h = tabBtnH, tab = tabKeys[ti] }

                if isActive then
                    love.graphics.setColor(0.25, 0.35, 0.45)
                else
                    love.graphics.setColor(0.15, 0.15, 0.18)
                end
                love.graphics.rectangle('fill', tabX, tabY, tw, tabBtnH, 3)

                love.graphics.setColor(isActive and 1 or 0.5, isActive and 1 or 0.5, isActive and 1 or 0.5)
                love.graphics.print(tname, tabX + 8, tabY + 3)
                tabX = tabX + tw + 4
            end

            -- Tab content
            local contentY = tabY + tabBtnH + 6
            if selectedTab == 'needs' then
                Selection.drawNeedsTab(id, col, needs, contentY)
            elseif selectedTab == 'health' then
                Selection.drawHealthTab(id, col, contentY)
            elseif selectedTab == 'social' then
                Selection.drawSocialTab(id, col, contentY)
            elseif selectedTab == 'work' then
                Selection.drawWorkTab(id, col, contentY)
            elseif selectedTab == 'schedule' then
                Selection.drawScheduleTab(id, col, contentY)
            elseif selectedTab == 'gear' then
                Selection.drawGearTab(id, col, contentY)
            elseif selectedTab == 'bio' or selectedTab == 'combat' or selectedTab == 'log' then
                local ciOk, CInfo = pcall(require, 'src.ui.colonist_info')
                if ciOk then
                    if selectedTab == 'bio' then
                        CInfo.drawBioTab(id, col, contentY)
                    elseif selectedTab == 'combat' then
                        CInfo.drawCombatTab(id, col, contentY)
                    elseif selectedTab == 'log' then
                        CInfo.drawLogTab(id, col, contentY)
                    end
                end
            end
        end
    else
        -- Multiple selected: group summary
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format('%d colonists selected', #selected), 16, panelY + 8)

        -- Group status counts
        local statusCounts = {}
        local totalHp, totalMaxHp = 0, 0
        for _, sid in ipairs(selected) do
            local sc = ECS.get(sid, 'colonist')
            if sc then
                local st = sc.state or 'idle'
                statusCounts[st] = (statusCounts[st] or 0) + 1
                totalHp = totalHp + (sc.health or 0)
                totalMaxHp = totalMaxHp + (sc.maxHealth or 100)
            end
        end
        local statLine = {}
        for st, cnt in pairs(statusCounts) do
            statLine[#statLine + 1] = st .. ':' .. cnt
        end
        love.graphics.setColor(0.6, 0.7, 0.6)
        love.graphics.print(table.concat(statLine, '  '), 16, panelY + 24)

        -- Average health
        local avgHp = totalMaxHp > 0 and (totalHp / totalMaxHp * 100) or 0
        love.graphics.setColor(0.5, 0.7, 0.5)
        love.graphics.print(string.format('Avg HP: %.0f%%', avgHp), 16, panelY + 38)

        -- Name list (compact, 2 columns)
        local nameY = panelY + 56
        for i, sid in ipairs(selected) do
            if i > 20 then
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print('+' .. (#selected - 20) .. ' more', 16, nameY)
                break
            end
            local sc = ECS.get(sid, 'colonist')
            if sc then
                local colIdx = (i - 1) % 2
                local row = math.floor((i - 1) / 2)
                love.graphics.setColor(0.7, 0.8, 0.9)
                love.graphics.print(sc.name or '???', 16 + colIdx * 160, nameY + row * 14)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Prisoner panel — displays prisoner info and action buttons
---------------------------------------------------------------------------

function Selection.drawPrisonerPanel(id, prisoner, panelY)
    -- Header: name + status
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.print('PRISONER: ' .. (prisoner.name or 'Unknown'), 16, panelY + 8)

    -- Phase label
    local phaseLabel
    if prisoner.phase == 'resist' then
        phaseLabel = string.format('Breaking resistance: %.0f remaining', prisoner.resistance or 0)
    else
        phaseLabel = string.format('Ready to recruit (%d%% base chance)', prisoner.recruitChance or 0)
    end
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(phaseLabel, 16, panelY + 24)

    -- Health bar
    local health = prisoner.health or 0
    local hpBarW = 120
    local hpBarX = 16
    local hpBarY = panelY + 40
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('fill', hpBarX, hpBarY, hpBarW, 6)
    local hpFrac = math.max(0, math.min(1, health / 100))
    local hr = hpFrac < 0.3 and 1 or (1 - hpFrac)
    local hg = hpFrac > 0.5 and 0.8 or hpFrac
    love.graphics.setColor(hr, hg, 0.1)
    love.graphics.rectangle('fill', hpBarX, hpBarY, hpBarW * hpFrac, 6)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(string.format('HP: %.0f/100', health), hpBarX + hpBarW + 8, hpBarY - 4)

    -- Info column: mood, fed, wounded
    local infoY = panelY + 54
    local moodColor
    if (prisoner.mood or 0) >= 60 then
        moodColor = {0.3, 0.9, 0.4}
    elseif (prisoner.mood or 0) >= 30 then
        moodColor = {0.9, 0.8, 0.2}
    else
        moodColor = {0.9, 0.3, 0.3}
    end
    love.graphics.setColor(moodColor[1], moodColor[2], moodColor[3])
    love.graphics.print(string.format('Mood: %d', prisoner.mood or 0), 16, infoY)

    love.graphics.setColor(prisoner.fed and 0.5 or 0.9, prisoner.fed and 0.8 or 0.3, prisoner.fed and 0.5 or 0.3)
    love.graphics.print(prisoner.fed and 'Fed' or 'Hungry', 100, infoY)

    if prisoner.wounded then
        love.graphics.setColor(0.9, 0.4, 0.3)
        love.graphics.print('Wounded', 160, infoY)
    end

    -- Skills summary (right column)
    if prisoner.skills then
        local sx = 300
        local sy = panelY + 8
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print('Skills:', sx, sy)
        sy = sy + 14
        local skillNames = {'mining', 'building', 'cooking', 'hunting', 'research', 'medical'}
        for _, sk in ipairs(skillNames) do
            local val = prisoner.skills[sk] or 0
            if val > 0 then
                if val >= 7 then
                    love.graphics.setColor(0.4, 0.8, 0.5)
                elseif val >= 4 then
                    love.graphics.setColor(0.6, 0.7, 0.8)
                else
                    love.graphics.setColor(0.5, 0.5, 0.5)
                end
                love.graphics.print(string.format('%s: %d', sk, val), sx, sy)
                sy = sy + 13
            end
        end
    end

    -- Backstory
    if prisoner.backstory then
        love.graphics.setColor(0.5, 0.5, 0.45)
        local backstory = prisoner.backstory
        if #backstory > 60 then backstory = backstory:sub(1, 57) .. '...' end
        love.graphics.print(backstory, 16, panelY + 70)
    end

    -- Resistance bar (only in resist phase)
    if prisoner.phase == 'resist' then
        local barX = 16
        local barY = panelY + 88
        local barW = 200
        local barH = 10
        local maxResist = 30
        local resistFrac = math.max(0, math.min(1, (prisoner.resistance or 0) / maxResist))
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle('fill', barX, barY, barW, barH, 2)
        love.graphics.setColor(0.7, 0.3, 0.2)
        love.graphics.rectangle('fill', barX, barY, barW * resistFrac, barH, 2)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(string.format('Resistance: %.1f', prisoner.resistance or 0), barX + barW + 8, barY - 2)
    end

    -- Action buttons row
    local btnY = panelY + 108
    local btnX = 16

    -- Recruit button — only available when resistance is broken
    if prisoner.phase == 'recruit' then
        btnX = btnX + BuildingInfo.addPrisonerBtn(btnX, btnY, 'Recruit', 'prisoner', id, 'recruit', {
            fill = {0.1, 0.3, 0.15},
            line = {0.3, 0.8, 0.4},
            text = {0.4, 0.95, 0.5},
        }) + 6
    else
        -- Show disabled recruit label when still in resist phase
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.print('(Break resistance to recruit)', btnX, btnY + 5)
        btnX = btnX + 210
    end

    -- Release button
    btnX = btnX + BuildingInfo.addPrisonerBtn(btnX, btnY, 'Release', 'prisoner', id, 'release', {
        fill = {0.15, 0.18, 0.28},
        line = {0.4, 0.5, 0.7},
        text = {0.55, 0.65, 0.85},
    }) + 6

    -- Execute button
    btnX = btnX + BuildingInfo.addPrisonerBtn(btnX, btnY, 'Execute', 'prisoner', id, 'execute', {
        fill = {0.3, 0.1, 0.1},
        line = {0.8, 0.3, 0.3},
        text = {0.95, 0.4, 0.4},
    }) + 6

    -- Traits
    if prisoner.traits and #prisoner.traits > 0 then
        local traitY = panelY + 140
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print('Traits:', 16, traitY)
        local tx = 70
        for _, t in ipairs(prisoner.traits) do
            love.graphics.setColor(0.7, 0.7, 0.5)
            love.graphics.print(t.name or t.id or '?', tx, traitY)
            tx = tx + love.graphics.getFont():getWidth(t.name or t.id or '?') + 10
            if tx > screenW - 100 then break end
        end
    end
end

---------------------------------------------------------------------------
-- Tab: Needs
---------------------------------------------------------------------------

function Selection.drawNeedsTab(id, col, needs, y)
    if not needs then return end

    local font = love.graphics.getFont()
    local fh = font:getHeight()
    local barX = 16
    local barW = 120
    local barH = 12
    local rowH = fh + 4
    local needsList = {
        { 'Warmth', needs.warmth, {0.9, 0.3, 0.2} },
        { 'Food',   needs.food,   {0.3, 0.8, 0.3} },
        { 'Water',  needs.water or 80, {0.2, 0.6, 0.9} },
        { 'Rest',   needs.rest,   {0.3, 0.3, 0.9} },
        { 'Morale', needs.morale, {0.9, 0.8, 0.2} },
    }
    for _, n in ipairs(needsList) do
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle('fill', barX, y + 2, barW, barH)
        love.graphics.setColor(n[3][1], n[3][2], n[3][3])
        love.graphics.rectangle('fill', barX, y + 2, barW * n[2] / 100, barH)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(string.format('%s: %.0f', n[1], n[2]), barX + barW + 10, y)
        y = y + rowH
    end

    -- Traits
    if col.traits then
        local tx = 320
        local ty = y - rowH * #needsList
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print('Traits:', tx, ty)
        ty = ty + fh + 2
        for _, t in ipairs(col.traits) do
            if ty > screenH - 10 then break end
            if t.workSpeed and t.workSpeed > 0 or t.moraleMod and t.moraleMod > 0 or
               t.combatMod and t.combatMod > 0 or t.coldResist and t.coldResist > 0 then
                love.graphics.setColor(0.3, 0.9, 0.4)
            elseif t.workSpeed and t.workSpeed < 0 or t.moraleMod and t.moraleMod < 0 or
                   t.combatMod and t.combatMod < 0 or t.coldResist and t.coldResist < 0 then
                love.graphics.setColor(0.9, 0.4, 0.3)
            else
                love.graphics.setColor(0.7, 0.7, 0.5)
            end
            love.graphics.print((t.name or t.id or '?') .. ' - ' .. (t.desc or ''), tx, ty)
            ty = ty + fh + 2
        end
    end

    -- Backstory
    if col.backstory then
        love.graphics.setColor(0.55, 0.55, 0.5)
        love.graphics.print(col.backstory, 16, screenH - fh - 6)
    end
end

---------------------------------------------------------------------------
-- Tab: Health
---------------------------------------------------------------------------

function Selection.drawHealthTab(id, col, y)
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    local lineH = fh + 2
    local startY = y

    -- Body parts
    local body = ECS.get(id, 'body')
    if body and body.parts then
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print('Body:', 16, y)
        y = y + lineH
        for _, part in ipairs(body.parts) do
            if y > screenH - 20 then break end
            local hp = part.hp or 0
            local maxHp = part.maxHp or 1
            local frac = hp / maxHp
            if frac < 0.5 then
                love.graphics.setColor(0.9, 0.3, 0.2)
            elseif frac < 1 then
                love.graphics.setColor(0.9, 0.8, 0.3)
            else
                love.graphics.setColor(0.5, 0.8, 0.5)
            end
            love.graphics.print(string.format('%s: %d/%d', part.name or part.id, hp, maxHp), 16, y)
            y = y + lineH
        end
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No injuries', 16, y)
    end

    -- Wounds
    local wounds = ECS.get(id, 'wounds')
    if wounds and wounds.list and #wounds.list > 0 then
        local wy = startY
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print('Wounds:', 300, wy)
        wy = wy + lineH
        for _, w in ipairs(wounds.list) do
            if wy > screenH - 20 then break end
            love.graphics.setColor(0.9, 0.4, 0.3)
            love.graphics.print(string.format('%s on %s', w.type or 'wound', w.part or '?'), 300, wy)
            wy = wy + lineH
        end
    end

    -- Disease
    local disease = ECS.get(id, 'disease')
    if disease and disease.id then
        love.graphics.setColor(0.6, 0.9, 0.3)
        love.graphics.print(string.format('Disease: %s (sev %.0f%%, imm %.0f%%)',
            disease.id, (disease.severity or 0), (disease.immunity or 0)),
            16, screenH - 35)
    end

    -- Hypothermia
    if col.hypothermia and col.hypothermia > 0 then
        local stages = {'chilled', 'cold', 'hypothermic', 'severe', 'critical'}
        local stage = stages[col.hypothermia] or 'unknown'
        love.graphics.setColor(0.4, 0.7, 1)
        love.graphics.print('Hypothermia: ' .. stage, 16, screenH - 20)
    end

    -- Suffocation
    if col._suffocating and col._suffocating > 0 then
        local suffStages = {'low O2', 'suffocating', 'critical'}
        local suffStage = suffStages[col._suffocating] or 'unknown'
        love.graphics.setColor(0.6, 0.3, 0.7)
        love.graphics.print('Oxygen: ' .. suffStage, 16, screenH - 5)
    end

    -- Addictions
    local addictions = ECS.get(id, 'addictions')
    if addictions then
        local addY = startY
        local hasAny = false
        for drugId, entry in pairs(addictions) do
            if entry.addicted then
                if not hasAny then
                    love.graphics.setColor(0.8, 0.6, 0.2)
                    love.graphics.print('Addictions:', 500, addY)
                    addY = addY + 16
                    hasAny = true
                end
                if addY > screenH - 20 then break end
                if entry.withdrawalTimer and entry.withdrawalTimer > 0 then
                    love.graphics.setColor(0.9, 0.3, 0.2)
                    love.graphics.print(string.format('%s (WITHDRAWAL %.0fd)', drugId, entry.withdrawalTimer), 500, addY)
                else
                    love.graphics.setColor(0.8, 0.6, 0.3)
                    love.graphics.print(string.format('%s (addicted)', drugId), 500, addY)
                end
                addY = addY + 14
            end
        end
    end

    -- Mental break status
    if col._mentalBreak then
        love.graphics.setColor(0.9, 0.2, 0.2)
        local mbType = col._mentalBreak.type or 'unknown'
        local mbTime = col._mentalBreak.timer or 0
        love.graphics.print(string.format('MENTAL BREAK: %s (%.0fs)', mbType, mbTime), 500, screenH - 35)
    end
end

---------------------------------------------------------------------------
-- Tab: Social
---------------------------------------------------------------------------

function Selection.drawSocialTab(id, col, y)
    local sok, Social = pcall(require, 'src.colonist.social')
    if not sok or not Social.getRelationships then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('Social system not loaded', 16, y)
        return
    end

    local rels = Social.getRelationships(id) or {}
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print('Relationships:', 16, y)
    y = y + 16

    if not next(rels) then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No relationships yet', 16, y)
        return
    end

    for _, rel in ipairs(rels) do
        if y > screenH - 10 then break end
        if rel.label == 'lover' or rel.label == 'dating' then
            love.graphics.setColor(0.9, 0.55, 0.62)
        elseif rel.opinion > 20 then
            love.graphics.setColor(0.3, 0.9, 0.4)
        elseif rel.opinion < -20 then
            love.graphics.setColor(0.9, 0.3, 0.3)
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
        end
        local suffix = ''
        if rel.label == 'lover' then
            suffix = ' (lover)'
        elseif rel.label == 'dating' then
            suffix = ' (dating)'
        elseif rel.label == 'friend' then
            suffix = ' (friend)'
        elseif rel.label == 'rival' then
            suffix = ' (rival)'
        end
        love.graphics.print(string.format('%s%s: %+d', rel.name, suffix, rel.opinion), 16, y)
        y = y + 14
    end
end

---------------------------------------------------------------------------
-- Tab: Work priorities
---------------------------------------------------------------------------

function Selection.drawWorkTab(id, col, y)
    workCells = {}

    local wp = ECS.get(id, 'workPriority')
    if not wp then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No work priorities (not a worker)', 16, y)
        return
    end

    local jok, Jobs = pcall(require, 'src.colonist.jobs')
    if not jok or not Jobs.PRIORITY_COLUMNS then return end

    local columns = Jobs.PRIORITY_COLUMNS
    local cellW = 55
    local cellH = 22
    local startX = 16

    -- Column headers (hover shows full name)
    local mx, my = love.mouse.getPosition()
    local headerTooltip = nil
    love.graphics.setColor(0.7, 0.7, 0.7)
    for i, colName in ipairs(columns) do
        local cx = startX + (i - 1) * (cellW + 2)
        local abbr = colName:sub(1, 6)
        love.graphics.print(abbr, cx + 4, y)
        if mx >= cx and mx <= cx + cellW and my >= y and my <= y + 16 then
            headerTooltip = colName
        end
    end
    if headerTooltip then
        local font = love.graphics.getFont()
        local tw = font:getWidth(headerTooltip) + 10
        love.graphics.setColor(0.05, 0.06, 0.08, 0.92)
        love.graphics.rectangle('fill', mx + 8, my - 18, tw, 18, 3)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(headerTooltip, mx + 13, my - 16)
    end
    y = y + 18

    -- Priority cells (clickable)
    for i, colName in ipairs(columns) do
        local cx = startX + (i - 1) * (cellW + 2)
        local val = wp[colName] or 0

        workCells[#workCells + 1] = { x = cx, y = y, w = cellW, h = cellH, id = id, col = colName }

        -- Cell background by priority level
        if val == 0 then
            love.graphics.setColor(0.15, 0.15, 0.15)
        elseif val == 1 then
            love.graphics.setColor(0.1, 0.4, 0.15)
        elseif val == 2 then
            love.graphics.setColor(0.15, 0.3, 0.1)
        elseif val == 3 then
            love.graphics.setColor(0.25, 0.25, 0.1)
        else
            love.graphics.setColor(0.35, 0.18, 0.1)
        end
        love.graphics.rectangle('fill', cx, y, cellW, cellH, 2)

        -- Border
        love.graphics.setColor(0.35, 0.35, 0.4)
        love.graphics.rectangle('line', cx, y, cellW, cellH, 2)

        -- Value
        local label = val == 0 and '-' or tostring(val)
        local textCol = val == 0 and 0.4 or 1
        love.graphics.setColor(textCol, textCol, textCol)
        love.graphics.print(label, cx + cellW / 2 - 3, y + 4)
    end

    -- Legend
    y = y + cellH + 8
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print('Click to cycle: - (off) > 1 (urgent) > 2 > 3 > 4 (low) > -', 16, y)

    -- Skills
    if col.skills then
        y = y + 20
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print('Skills:', 16, y)
        local sx = 70
        for skill, level in pairs(col.skills) do
            love.graphics.setColor(0.6, 0.7, 0.8)
            love.graphics.print(string.format('%s:%d', skill, level), sx, y)
            sx = sx + 80
            if sx > screenW - 100 then
                sx = 70
                y = y + 14
            end
        end
    end
end

---------------------------------------------------------------------------
-- Tab: Schedule
---------------------------------------------------------------------------

function Selection.drawScheduleTab(id, col, y)
    local sok, Schedule = pcall(require, 'src.colonist.schedule')
    if not sok then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('Schedule system not loaded', 16, y)
        return
    end

    local sched = ECS.get(id, 'schedule')
    if not sched then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No schedule assigned', 16, y)
        return
    end

    local blockColors = {
        work  = {0.3, 0.6, 0.3},
        eat   = {0.8, 0.7, 0.2},
        sleep = {0.3, 0.3, 0.7},
        free  = {0.5, 0.5, 0.5},
    }

    local cellW = math.floor((screenW - 80) / 24)
    local cellH = 24
    local startX = 40

    -- Hour labels
    love.graphics.setColor(0.5, 0.5, 0.5)
    for h = 0, 23 do
        if h % 3 == 0 then
            love.graphics.print(tostring(h), startX + h * cellW + 2, y)
        end
    end
    y = y + 14

    -- Block cells
    for h = 0, 23 do
        local block = sched[h] or 'work'
        local bc = blockColors[block] or {0.3, 0.3, 0.3}
        local cx = startX + h * cellW

        love.graphics.setColor(bc[1], bc[2], bc[3], 0.7)
        love.graphics.rectangle('fill', cx, y, cellW - 1, cellH, 2)
        love.graphics.setColor(bc[1], bc[2], bc[3])
        love.graphics.rectangle('line', cx, y, cellW - 1, cellH, 2)

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(block:sub(1, 1):upper(), cx + cellW / 2 - 3, y + 5)

        -- Current hour marker
        local curH = math.floor(GameState.hour)
        if h == curH then
            love.graphics.setColor(1, 1, 0, 0.6)
            love.graphics.rectangle('line', cx - 1, y - 1, cellW + 1, cellH + 2, 2)
        end

        scheduleCells[#scheduleCells + 1] = {
            x = cx, y = y, w = cellW - 1, h = cellH, entityId = id, hour = h
        }
    end

    y = y + cellH + 8

    -- Legend
    local lx = 40
    for _, pair in ipairs({{'work', 'Work'}, {'eat', 'Eat'}, {'sleep', 'Sleep'}, {'free', 'Free'}}) do
        local bc = blockColors[pair[1]]
        love.graphics.setColor(bc[1], bc[2], bc[3])
        love.graphics.rectangle('fill', lx, y, 10, 10, 1)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(pair[2], lx + 14, y - 2)
        lx = lx + 65
    end

    y = y + 16
    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('Click cells to cycle: Work > Eat > Sleep > Free', 40, y)
end

---------------------------------------------------------------------------
-- Tab: Gear
---------------------------------------------------------------------------

function Selection.drawGearTab(id, col, y)
    local eok, Equipment = pcall(require, 'src.colonist.equipment')
    if not eok then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('Equipment system not loaded', 16, y)
        return
    end

    local equip = ECS.get(id, 'equipment')

    -- Weapon
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print('Weapon:', 16, y)
    if equip and equip.weapon then
        love.graphics.setColor(0.9, 0.7, 0.3)
        love.graphics.print(string.format('%s (DMG %d, RNG %d)',
            equip.weapon.name, equip.weapon.dmg or 0, equip.weapon.range or 0), 90, y)
    else
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('none (fists, DMG 5)', 90, y)
    end
    y = y + 18

    -- Armor
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print('Armor:', 16, y)
    if equip and equip.armor then
        love.graphics.setColor(0.5, 0.7, 0.9)
        local info = equip.armor.name or '?'
        if equip.armor.reduction then info = info .. string.format(' (-%d DMG', equip.armor.reduction) end
        if equip.armor.warmthBonus and equip.armor.warmthBonus > 0 then
            info = info .. string.format(', +%d warmth', equip.armor.warmthBonus)
        end
        info = info .. ')'
        love.graphics.print(info, 90, y)
    else
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('none', 90, y)
    end
    y = y + 18

    -- Accessory
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print('Accessory:', 16, y)
    if equip and equip.accessory then
        love.graphics.setColor(0.8, 0.6, 0.9)
        love.graphics.print(string.format('%s (%s +%s)',
            equip.accessory.name or equip.accessory.id or '?',
            equip.accessory.effect or '?', tostring(equip.accessory.value or 0)), 90, y)
    else
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('none', 90, y)
    end
    y = y + 24

    -- Auto-Equip button
    gearAutoBtn = { x = 16, y = y, w = 90, h = 22, entityId = id }
    love.graphics.setColor(0.12, 0.22, 0.32)
    love.graphics.rectangle('fill', 16, y, 90, 22, 3)
    love.graphics.setColor(0.4, 0.65, 0.9)
    love.graphics.print('Auto-Equip', 22, y + 4)
end

return Selection
