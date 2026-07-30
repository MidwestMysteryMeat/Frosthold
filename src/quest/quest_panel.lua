-- quest_panel.lua -- Colony goals and quest UI
-- Toggle with 'q' key. First tab surfaces colony endgame paths, then quest board,
-- active quests, and completed history.

local GameState  = require('src.game_state')
local Goals      = require('src.colony.goals')
local Objectives = require('src.quest.quest_objectives')

local Layout     = require('src.ui.ui_layout')

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
    panelH = math.min(560, sh - 80 - Layout.BOTTOM_RESERVE)
    panelX = math.floor((sw - panelW) / 2)
    panelY = math.floor((sh - Layout.BOTTOM_RESERVE - panelH) / 2)
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

-- 86px of header/description/bar/status, then four 14px rows: three steps plus
-- the "+N more" marker. At 126 the third step was clipped in half and the marker
-- landed on the next card's border.
local GOAL_ENTRY_H = 148

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

    -- One line, ellipsised. printf wrapped a long description to a second line
    -- the fixed-height card had no room for, so it was drawn half-cut under the
    -- progress bar.
    love.graphics.setColor(0.7, 0.74, 0.8)
    love.graphics.print(Layout.truncate(goal.desc or '', w - 16, font), x + 8, y + 24)

    local barX, barY, barW, barH = x + 8, y + 52, w - 16, 10
    love.graphics.setColor(0.12, 0.14, 0.18, 1)
    love.graphics.rectangle('fill', barX, barY, barW, barH, 2)
    love.graphics.setColor(0.32, 0.68, 0.44, 0.95)
    love.graphics.rectangle('fill', barX, barY, barW * math.max(0, math.min(1, goal.progress or 0)), barH, 2)

    love.graphics.setColor(0.52, 0.7, 0.88)
    love.graphics.print(goal.status or 'No status', x + 8, y + 68)

    -- Step rows must finish inside the card: three rows of 14px from y+86 ended
    -- at y+128 against a 126px card, so the last one was clipped in half.
    local sy = y + 86
    local stepBottom = y + GOAL_ENTRY_H - 4
    for i, step in ipairs(goal.steps or {}) do
        if sy + 14 > stepBottom then
            love.graphics.setColor(0.5, 0.5, 0.55)
            love.graphics.print(string.format('+%d more', #goal.steps - i + 1), x + 18, sy)
            break
        end
        if i > 3 then
            love.graphics.setColor(0.5, 0.5, 0.55)
            love.graphics.print(string.format('+%d more', #goal.steps - i + 1), x + 18, sy)
            break
        end
        local prefix = step.done and '[x]' or '[ ]'
        love.graphics.setColor(step.done and {0.35, 0.85, 0.45} or {0.65, 0.67, 0.72})
        love.graphics.print(Layout.truncate(prefix .. ' ' .. step.label, w - 24, font), x + 12, sy)
        sy = sy + 14
    end

    return GOAL_ENTRY_H
end

---------------------------------------------------------------------------
-- Quest entry drawing
---------------------------------------------------------------------------

local ENTRY_H = 94  -- taller to fit extra info

--- Rect of an entry's Accept/Abandon button. Shared by the draw pass and the
--- hit test, which previously each recomputed the geometry from constants and
--- would have silently disagreed the moment either changed.
local function actionButtonRect(label, entryX, entryY, entryW, font)
    return Layout.buttonRectRight(label, entryX + entryW - 8, entryY + ENTRY_H - 26, {
        h = Layout.textHeight(font) + 8,
        minW = label == 'Accept' and 60 or 66,
        font = font,
    })
end

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

    -- Row 2: Description, ellipsised at whatever the warning leaves free.
    -- Truncating at a byte count (50/60 chars) let a description reach x+408
    -- while 'TRIGGERS RAID' started at x+392.
    local descRight = x + w - 8
    if q.threatInfo then
        descRight = descRight - font:getWidth('TRIGGERS RAID') - Layout.MIN_GAP
    end
    love.graphics.setColor(0.7, 0.7, 0.75)
    love.graphics.print(Layout.truncate(q.desc or '', descRight - (x + 8), font), x + 8, y + 20)

    -- Threat warning (same row as desc, right side)
    if q.threatInfo then
        love.graphics.setColor(1, 0.3, 0.3)
        local warnTxt = 'TRIGGERS RAID'
        love.graphics.print(warnTxt, x + w - font:getWidth(warnTxt) - 8, y + 20)
    end

    -- Row 3: Objectives
    if q.objectives then
        -- The card is ENTRY_H tall and the reward line sits at ENTRY_H-18, so
        -- only the rows that fit above it are drawn; an uncapped loop used to
        -- write the fourth objective straight through the reward text.
        local oy = y + 36
        local objLimit = math.floor(((y + ENTRY_H - 20) - oy) / 14)
        local shown = math.min(#q.objectives, math.max(1, objLimit))
        for i = 1, shown do
            local obj = q.objectives[i]
            local objDesc = Objectives.describe(obj)
            if obj.done then
                love.graphics.setColor(0.3, 0.8, 0.3)
                objDesc = '[done] ' .. objDesc
            else
                love.graphics.setColor(0.6, 0.6, 0.65)
            end
            love.graphics.print(Layout.truncate(objDesc, w - 24, font), x + 16, oy)
            oy = oy + 14
        end
        if #q.objectives > shown then
            love.graphics.setColor(0.5, 0.5, 0.55)
            love.graphics.print(string.format('+%d more', #q.objectives - shown), x + 16, oy)
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
    -- Action buttons are laid out first so the reward line knows where to stop.
    -- A five-part reward list used to run underneath the Accept button.
    local actionRect = nil
    if showAccept then
        actionRect = actionButtonRect('Accept', x, y, w, font)
    elseif showAbandon then
        actionRect = actionButtonRect('Abandon', x, y, w, font)
    end

    if #rewardParts > 0 then
        local rewardRight = actionRect and (actionRect.x - Layout.MIN_GAP) or (x + w - 8)
        love.graphics.setColor(0.6, 0.8, 0.4)
        love.graphics.print(Layout.truncate('Reward: ' .. table.concat(rewardParts, ', '),
            rewardRight - (x + 8), font), x + 8, y + ENTRY_H - 18)
    end

    if actionRect then
        Layout.drawButton(showAccept and 'Accept' or 'Abandon', actionRect, 'normal', {
            normal = showAccept and { 0.2, 0.5, 0.3, 0.9 } or { 0.5, 0.2, 0.2, 0.9 },
            text   = showAccept and { 0.9, 0.95, 0.9 } or { 0.95, 0.8, 0.8 },
            font   = font,
        })
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
    local contentH = panelH - 34 - 20
    Layout.pushClip(panelX, contentY, panelW, contentH)

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

    Layout.popClip()

    -- Close hint, in its own footer strip below the scrolled content
    love.graphics.setColor(0.08, 0.1, 0.15, 0.95)
    love.graphics.rectangle('fill', panelX + 1, panelY + panelH - 20, panelW - 2, 19)
    love.graphics.setColor(0.5, 0.5, 0.55)
    do
        local hint = 'Q to close'
        love.graphics.print(hint, panelX + panelW - Layout.textWidth(hint) - 10,
            panelY + panelH - 18)
    end
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

    -- Accept / Abandon clicks. The rect comes from the same helper the draw
    -- pass uses, and a button scrolled out of the content area is not clickable
    -- any more — it used to still respond from behind the tab strip.
    local actionTabs = { board = { 'Accept', Quest and Quest.getAvailable },
                         active = { 'Abandon', Quest and Quest.getActive } }
    local spec = actionTabs[tab]
    if spec and button == 1 and ok_quest and spec[2] then
        local font = love.graphics.getFont()
        local contentY = panelY + 34
        local contentBottom = panelY + panelH - 20   -- above the footer strip
        local ey = contentY + 4 - scrollY
        for _, q in ipairs(spec[2]()) do
            local rect = actionButtonRect(spec[1], panelX + 8, ey, panelW - 16, font)
            if rect.y >= contentY and rect.y + rect.h <= contentBottom
               and Layout.hit(x, y, rect) then
                if spec[1] == 'Accept' then Quest.accept(q.id) else Quest.abandon(q.id) end
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
    -- Refreshing only in keypressed meant opening the panel from the bottom
    -- toolbar showed a stale board.
    if isOpen and ok_quest and Quest.refreshBoard then Quest.refreshBoard() end
end

return QuestPanel
