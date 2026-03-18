-- quest_panel.lua -- Colony goals and quest UI
-- Toggle with 'q' key. First tab surfaces colony endgame paths, then quest board,
-- active quests, and completed history.

local GameState  = require('src.game_state')
local Goals      = require('src.colony.goals')
local Objectives = require('src.quest.quest_objectives')

local ok_quest, Quest = pcall(require, 'src.quest.quest')

local QuestPanel = {}

local isOpen    = false
local tab       = 'goals'  -- 'goals' | 'board' | 'active' | 'completed'
local scrollY   = 0
local panelX, panelY, panelW, panelH = 0, 0, 0, 0

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local function recalcLayout()
    local sw, sh = love.graphics.getDimensions()
    panelW = math.min(520, sw - 60)
    panelH = math.min(560, sh - 80)
    panelX = math.floor((sw - panelW) / 2)
    panelY = math.floor((sh - panelH) / 2)
end

---------------------------------------------------------------------------
-- Drawing helpers
---------------------------------------------------------------------------

local function drawStars(x, y, count)
    love.graphics.setColor(0.95, 0.8, 0.2)
    local star = string.rep('*', count or 2)
    love.graphics.print(star, x, y)
    return love.graphics.getFont():getWidth(star)
end

local function drawTabs()
    local tabs = {
        { id = 'goals',     label = 'Goals' },
        { id = 'board',     label = 'Quest Board' },
        { id = 'active',    label = 'Active' },
        { id = 'completed', label = 'Completed' },
    }
    local tabW = math.floor(panelW / #tabs)
    for i, t in ipairs(tabs) do
        local tx = panelX + (i - 1) * tabW
        local ty = panelY

        if t.id == tab then
            love.graphics.setColor(0.2, 0.3, 0.4, 1)
        else
            love.graphics.setColor(0.12, 0.16, 0.22, 1)
        end
        love.graphics.rectangle('fill', tx, ty, tabW, 28, 2)
        love.graphics.setColor(0.8, 0.85, 0.9)
        local font = love.graphics.getFont()
        love.graphics.print(t.label, tx + tabW / 2 - font:getWidth(t.label) / 2, ty + 6)
    end
end

---------------------------------------------------------------------------
-- Goal entry drawing
---------------------------------------------------------------------------

local GOAL_ENTRY_H = 126

local function drawGoalEntry(goal, x, y, w)
    local font = love.graphics.getFont()

    love.graphics.setColor(0.09, 0.12, 0.18, 0.92)
    love.graphics.rectangle('fill', x, y, w, GOAL_ENTRY_H, 4)
    love.graphics.setColor(0.28, 0.4, 0.58, 0.8)
    love.graphics.rectangle('line', x, y, w, GOAL_ENTRY_H, 4)

    love.graphics.setColor(0.95, 0.88, 0.62)
    love.graphics.print(goal.title, x + 8, y + 6)

    local pct = math.floor((goal.progress or 0) * 100 + 0.5)
    local pctText = string.format('%d%%', pct)
    love.graphics.setColor(0.55, 0.72, 0.95)
    love.graphics.print(pctText, x + w - font:getWidth(pctText) - 8, y + 6)

    love.graphics.setColor(0.7, 0.74, 0.8)
    love.graphics.printf(goal.desc or '', x + 8, y + 24, w - 16, 'left')

    local barX, barY, barW, barH = x + 8, y + 52, w - 16, 10
    love.graphics.setColor(0.12, 0.14, 0.18, 1)
    love.graphics.rectangle('fill', barX, barY, barW, barH, 2)
    love.graphics.setColor(0.32, 0.68, 0.44, 0.95)
    love.graphics.rectangle('fill', barX, barY, barW * math.max(0, math.min(1, goal.progress or 0)), barH, 2)

    love.graphics.setColor(0.52, 0.7, 0.88)
    love.graphics.print(goal.status or 'No status', x + 8, y + 68)

    local sy = y + 86
    for i, step in ipairs(goal.steps or {}) do
        if i > 3 then
            love.graphics.setColor(0.5, 0.5, 0.55)
            love.graphics.print('...', x + 18, sy)
            break
        end
        local prefix = step.done and '[x]' or '[ ]'
        love.graphics.setColor(step.done and {0.35, 0.85, 0.45} or {0.65, 0.67, 0.72})
        love.graphics.print(prefix .. ' ' .. step.label, x + 12, sy)
        sy = sy + 14
    end

    return GOAL_ENTRY_H
end

---------------------------------------------------------------------------
-- Quest entry drawing
---------------------------------------------------------------------------

local ENTRY_H = 94  -- taller to fit extra info

local function drawQuestEntry(q, x, y, w, showAccept, showAbandon)
    local font = love.graphics.getFont()

    -- Background
    love.graphics.setColor(0.1, 0.14, 0.2, 0.9)
    love.graphics.rectangle('fill', x, y, w, ENTRY_H, 4)
    -- Border: highlight threat quests in red, chain quests in blue
    if q.threatInfo then
        love.graphics.setColor(0.6, 0.2, 0.2, 0.9)
    elseif q.chainId then
        love.graphics.setColor(0.2, 0.3, 0.6, 0.9)
    else
        love.graphics.setColor(0.3, 0.4, 0.5, 0.8)
    end
    love.graphics.rectangle('line', x, y, w, ENTRY_H, 4)

    -- Row 1: Stars + Title + Faction/Chain
    local titleX = x + 8
    if q.stars then
        local sw = drawStars(titleX, y + 4, q.stars)
        titleX = titleX + sw + 4
    end
    love.graphics.setColor(0.95, 0.85, 0.5)
    love.graphics.print(q.title or '???', titleX, y + 4)

    -- Faction name or chain progress (right side of title row)
    local infoX = x + w - 8
    if q.chainId and q.chainStep then
        local chainTxt = string.format('Step %d/%d', q.chainStep, q.chainTotal or '?')
        love.graphics.setColor(0.4, 0.6, 0.9)
        love.graphics.print(chainTxt, infoX - font:getWidth(chainTxt), y + 4)
    elseif q.factionName then
        love.graphics.setColor(0.5, 0.7, 0.8)
        local fTxt = q.factionName
        love.graphics.print(fTxt, infoX - font:getWidth(fTxt), y + 4)
    end

    -- Row 2: Description (truncated)
    love.graphics.setColor(0.7, 0.7, 0.75)
    local desc = q.desc or ''
    local maxDescLen = q.threatInfo and 50 or 60
    if #desc > maxDescLen then desc = desc:sub(1, maxDescLen - 3) .. '...' end
    love.graphics.print(desc, x + 8, y + 20)

    -- Threat warning (same row as desc, right side)
    if q.threatInfo then
        love.graphics.setColor(1, 0.3, 0.3)
        local warnTxt = 'TRIGGERS RAID'
        love.graphics.print(warnTxt, x + w - font:getWidth(warnTxt) - 8, y + 20)
    end

    -- Row 3: Objectives
    if q.objectives then
        local oy = y + 36
        for _, obj in ipairs(q.objectives) do
            local objDesc = Objectives.describe(obj)
            if obj.done then
                love.graphics.setColor(0.3, 0.8, 0.3)
                objDesc = '[done] ' .. objDesc
            else
                love.graphics.setColor(0.6, 0.6, 0.65)
            end
            love.graphics.print(objDesc, x + 16, oy)
            oy = oy + 14
        end
    end

    -- Row 4: Rewards
    local rewardParts = {}
    if q.reward then
        if q.reward.thermalCores then
            rewardParts[#rewardParts + 1] = q.reward.thermalCores .. ' cores'
        end
        if q.reward.colonist then
            rewardParts[#rewardParts + 1] = 'new colonist'
        end
        if q.reward.resources then
            rewardParts[#rewardParts + 1] = 'resources'
        end
        if q.reward.knowledge then
            rewardParts[#rewardParts + 1] = 'research'
        end
        if q.reward.factionRep then
            rewardParts[#rewardParts + 1] = '+' .. q.reward.factionRep .. ' rep'
        end
    end
    -- Exclusive reward
    if q.exclusiveReward then
        rewardParts[#rewardParts + 1] = q.exclusiveReward.name
    end
    if #rewardParts > 0 then
        love.graphics.setColor(0.6, 0.8, 0.4)
        love.graphics.print('Reward: ' .. table.concat(rewardParts, ', '), x + 8, y + ENTRY_H - 18)
    end

    -- Accept button (board tab)
    if showAccept then
        local btnW, btnH = 60, 20
        local btnX = x + w - btnW - 8
        local btnY = y + ENTRY_H - 24
        love.graphics.setColor(0.2, 0.5, 0.3, 0.9)
        love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 3)
        love.graphics.setColor(0.9, 0.95, 0.9)
        love.graphics.print('Accept', btnX + btnW / 2 - font:getWidth('Accept') / 2, btnY + 3)
    end

    -- Abandon button (active tab)
    if showAbandon then
        local btnW, btnH = 66, 20
        local btnX = x + w - btnW - 8
        local btnY = y + ENTRY_H - 24
        love.graphics.setColor(0.5, 0.2, 0.2, 0.9)
        love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 3)
        love.graphics.setColor(0.95, 0.8, 0.8)
        love.graphics.print('Abandon', btnX + btnW / 2 - font:getWidth('Abandon') / 2, btnY + 3)
    end

    -- Time remaining / Board TTL
    if q.state == 'active' and q.timeLimit and q.timeLimit > 0 then
        local elapsed = GameState.day - (q.acceptedDay or 0)
        local remaining = q.timeLimit - elapsed
        local rTxt = math.ceil(remaining) .. ' days left'
        love.graphics.setColor(remaining <= 3 and {1, 0.4, 0.3} or {0.7, 0.7, 0.5})
        love.graphics.print(rTxt, x + 8, y + ENTRY_H - 32)
    elseif q.state == 'available' then
        local age = GameState.day - (q.offeredDay or 0)
        local ttl = q.boardTTL or 5
        local remaining = ttl - age
        if remaining <= 3 then
            local eTxt = math.ceil(remaining) .. 'd on board'
            love.graphics.setColor(remaining <= 1 and {1, 0.4, 0.3} or {0.7, 0.6, 0.4})
            love.graphics.print(eTxt, x + 8, y + ENTRY_H - 32)
        end
    end

    return ENTRY_H
end

---------------------------------------------------------------------------
-- Main draw
---------------------------------------------------------------------------

function QuestPanel.draw()
    if not isOpen then return end

    recalcLayout()

    -- Dim background
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Panel background
    love.graphics.setColor(0.08, 0.1, 0.15, 0.95)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH, 6)
    love.graphics.setColor(0.3, 0.4, 0.5, 0.8)
    love.graphics.rectangle('line', panelX, panelY, panelW, panelH, 6)

    drawTabs()

    -- Content area
    local contentY = panelY + 34
    local contentH = panelH - 34
    love.graphics.setScissor(panelX, contentY, panelW, contentH)

    local quests = {}
    local showAccept = false
    local showAbandon = false
    local goals = {}
    if tab == 'goals' then
        goals = Goals.getAll()
    elseif tab == 'board' then
        if not ok_quest then quests = {} else
        quests = Quest.getAvailable()
        showAccept = true
        end
    elseif tab == 'active' then
        if not ok_quest then quests = {} else
        quests = Quest.getActive()
        showAbandon = true
        end
    elseif tab == 'completed' then
        if not ok_quest then quests = {} else
        quests = Quest.getCompleted()
        end
    end

    if tab == 'goals' then
        local ey = contentY + 4 - scrollY
        for _, goal in ipairs(goals) do
            local h = drawGoalEntry(goal, panelX + 8, ey, panelW - 16)
            ey = ey + h + 8
        end
    elseif #quests == 0 then
        love.graphics.setColor(0.5, 0.5, 0.55)
        local msg
        if not ok_quest then
            msg = 'Quest system unavailable.'
        else
            msg = tab == 'board' and 'No quests available. Check back later.'
                 or tab == 'active' and 'No active quests.'
                 or 'No completed quests.'
        end
        love.graphics.print(msg, panelX + 16, contentY + 20)
    else
        local ey = contentY + 4 - scrollY
        for _, q in ipairs(quests) do
            local h = drawQuestEntry(q, panelX + 8, ey, panelW - 16, showAccept, showAbandon)
            ey = ey + h + 6
        end
    end

    love.graphics.setScissor()

    -- Close hint
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.print('Q to close', panelX + panelW - 70, panelY + panelH - 16)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function QuestPanel.keypressed(key)
    if key == 'q' then
        isOpen = not isOpen
        scrollY = 0
        if isOpen then
            if ok_quest then Quest.refreshBoard() end
        end
        return true
    end
    if not isOpen then return false end

    if key == '1' then tab = 'goals';     scrollY = 0; return true end
    if key == '2' then tab = 'board';     scrollY = 0; return true end
    if key == '3' then tab = 'active';    scrollY = 0; return true end
    if key == '4' then tab = 'completed'; scrollY = 0; return true end
    if key == 'escape' then isOpen = false; return true end

    return false
end

function QuestPanel.mousepressed(x, y, button)
    if not isOpen then return false end

    -- Tab clicks
    if y >= panelY and y <= panelY + 28 then
        local tabs = { 'goals', 'board', 'active', 'completed' }
        local tabW = math.floor(panelW / #tabs)
        for i, t in ipairs(tabs) do
            local tx = panelX + (i - 1) * tabW
            if x >= tx and x < tx + tabW then
                tab = t
                scrollY = 0
                return true
            end
        end
    end

    -- Accept button clicks (board tab)
    if tab == 'board' and button == 1 and ok_quest then
        local quests = Quest.getAvailable()
        local contentY = panelY + 34
        local ey = contentY + 4 - scrollY
        for _, q in ipairs(quests) do
            local btnW, btnH = 60, 20
            local btnX = panelX + 8 + (panelW - 16) - btnW - 8
            local btnY = ey + ENTRY_H - 24
            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                Quest.accept(q.id)
                return true
            end
            ey = ey + ENTRY_H + 6
        end
    end

    -- Abandon button clicks (active tab)
    if tab == 'active' and button == 1 and ok_quest then
        local quests = Quest.getActive()
        local contentY = panelY + 34
        local ey = contentY + 4 - scrollY
        for _, q in ipairs(quests) do
            local btnW, btnH = 66, 20
            local btnX = panelX + 8 + (panelW - 16) - btnW - 8
            local btnY = ey + ENTRY_H - 24
            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                Quest.abandon(q.id)
                return true
            end
            ey = ey + ENTRY_H + 6
        end
    end

    -- Consume clicks inside panel
    if x >= panelX and x <= panelX + panelW and y >= panelY and y <= panelY + panelH then
        return true
    end

    return false
end

function QuestPanel.wheelmoved(dx, dy)
    if not isOpen then return false end
    scrollY = math.max(0, scrollY - dy * 20)
    return true
end

function QuestPanel.isOpen()
    return isOpen
end

function QuestPanel.toggle()
    isOpen = not isOpen
    scrollY = 0
end

return QuestPanel
