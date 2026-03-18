-- colony_panel.lua — Colony overview panel
-- Full-screen roster of all colonists with stats, skills, and status.
-- Click a row to select and center camera on that colonist.
-- Toggle with C key.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local ColonyPanel = {}

local visible = false
local scrollY = 0
local hitZones = {}
local sortKey = 'name' -- name | health | mood | task
local sortAsc = true

-- Colors
local C = {
    bg         = { 0, 0, 0, 0.92 },
    header     = { 0.08, 0.1, 0.14 },
    headerLine = { 0.25, 0.35, 0.5 },
    label      = { 0.8, 0.8, 0.8 },
    dim        = { 0.5, 0.5, 0.5 },
    rowEven    = { 0.08, 0.1, 0.12, 0.6 },
    rowOdd     = { 0.06, 0.07, 0.09, 0.4 },
    rowHover   = { 0.15, 0.2, 0.28, 0.7 },
    healthy    = { 0.4, 0.75, 0.4 },
    injured    = { 0.9, 0.8, 0.2 },
    critical   = { 0.9, 0.3, 0.2 },
    mood_good  = { 0.3, 0.7, 0.9 },
    mood_mid   = { 0.9, 0.7, 0.2 },
    mood_bad   = { 0.9, 0.3, 0.2 },
    skill_high = { 0.5, 0.8, 0.5 },
    skill_mid  = { 0.6, 0.6, 0.6 },
    skill_low  = { 0.4, 0.4, 0.4 },
    disease    = { 0.7, 0.5, 0.9 },
    wound      = { 0.9, 0.35, 0.3 },
    sortActive = { 0.5, 0.7, 1 },
}

---------------------------------------------------------------------------
-- Toggle
---------------------------------------------------------------------------

function ColonyPanel.toggle()
    visible = not visible
    scrollY = 0
    hitZones = {}
end

function ColonyPanel.isVisible()
    return visible
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function addZone(id, x, y, w, h, action, data)
    hitZones[#hitZones + 1] = { id = id, x = x, y = y, w = w, h = h, action = action, data = data }
end

local function moodColor(val)
    if val >= 60 then return C.mood_good end
    if val >= 35 then return C.mood_mid end
    return C.mood_bad
end

local function healthFrac(col)
    return (col.health or 100) / math.max(col.maxHealth or 100, 1)
end

local function getWoundCount(id)
    local wounds = ECS.get(id, 'wounds')
    if not wounds or not wounds.list then return 0 end
    local count = 0
    for _, w in ipairs(wounds.list) do
        if w.treatment ~= 'healed' then count = count + 1 end
    end
    return count
end

local function getDisease(id)
    local d = ECS.get(id, 'disease')
    if d and d.id then return d end
    return nil
end

local SKILL_ORDER = { 'mining', 'building', 'cooking', 'medical', 'combat', 'research', 'farming', 'crafting' }

---------------------------------------------------------------------------
-- Sort
---------------------------------------------------------------------------

local function sortColonists(list)
    table.sort(list, function(a, b)
        local va, vb
        if sortKey == 'name' then
            va = a.col.name or ''
            vb = b.col.name or ''
        elseif sortKey == 'health' then
            va = healthFrac(a.col)
            vb = healthFrac(b.col)
        elseif sortKey == 'mood' then
            va = a.needs and a.needs.morale or 50
            vb = b.needs and b.needs.morale or 50
        elseif sortKey == 'task' then
            va = a.col.state or 'idle'
            vb = b.col.state or 'idle'
        else
            va = a.col.name or ''
            vb = b.col.name or ''
        end
        if sortAsc then
            return va < vb
        else
            return va > vb
        end
    end)
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function ColonyPanel.draw()
    if not visible then return end

    local sw, sh = love.graphics.getDimensions()
    hitZones = {}

    -- Backdrop
    love.graphics.setColor(C.bg)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header bar
    love.graphics.setColor(C.header)
    love.graphics.rectangle('fill', 0, 0, sw, 50)
    love.graphics.setColor(C.headerLine)
    love.graphics.line(0, 50, sw, 50)

    -- Title
    love.graphics.setColor(C.label)
    local aliveCount = ECS.countWith('colonist')
    love.graphics.print(string.format('Colony Overview (C) — %d colonists', aliveCount), sw / 2 - 120, 16)

    -- Colony stats summary
    local hok, Hope = pcall(require, 'src.colony.hope')
    if hok then
        love.graphics.setColor(C.dim)
        love.graphics.print(string.format('Day %d  Hope: %d  Discontent: %d  Wealth: %d',
            GameState.day,
            Hope.getHope(),
            Hope.getDiscontent(),
            GameState.getColonyWealth()), 20, 36)
    end

    -- Gather colonists
    local colonists = {}
    for id, comps in ECS.query('colonist', 'needs', 'pos') do
        if comps.colonist.state ~= 'dead' then
            colonists[#colonists + 1] = {
                id = id,
                col = comps.colonist,
                needs = comps.needs,
                pos = comps.pos,
            }
        end
    end
    sortColonists(colonists)

    -- Column headers (sortable)
    local headerY = 58
    local cols = {
        { key = 'name',   label = 'Name',    x = 20,  w = 120 },
        { key = 'health', label = 'Health',   x = 150, w = 80 },
        { key = 'mood',   label = 'Mood',     x = 240, w = 60 },
        { key = 'task',   label = 'Activity',  x = 310, w = 100 },
    }

    for _, c in ipairs(cols) do
        addZone(c.key, c.x, headerY, c.w, 16, 'sort', c.key)
        if sortKey == c.key then
            love.graphics.setColor(C.sortActive)
            local arrow = sortAsc and ' ^' or ' v'
            love.graphics.print(c.label .. arrow, c.x, headerY)
        else
            love.graphics.setColor(C.dim)
            love.graphics.print(c.label, c.x, headerY)
        end
    end

    -- Skill column headers
    local skillStartX = 420
    local skillColW = 55
    love.graphics.setColor(C.dim)
    for i, sk in ipairs(SKILL_ORDER) do
        local sx = skillStartX + (i - 1) * skillColW
        local abbr = sk:sub(1, 5)
        love.graphics.print(abbr, sx, headerY)
    end

    -- Status columns
    local statusX = skillStartX + #SKILL_ORDER * skillColW + 10
    love.graphics.setColor(C.dim)
    love.graphics.print('Wounds', statusX, headerY)
    love.graphics.print('Disease', statusX + 60, headerY)

    -- Separator
    love.graphics.setColor(C.headerLine)
    love.graphics.line(20, headerY + 16, sw - 20, headerY + 16)

    -- Rows
    local rowH = 24
    local startY = headerY + 20
    local mx, my = love.mouse.getPosition()

    for idx, entry in ipairs(colonists) do
        local y = startY + (idx - 1) * rowH - scrollY
        if y > sh then break end
        if y + rowH > 50 then
            -- Row background
            local isHover = mx >= 20 and mx <= sw - 20 and my >= y and my < y + rowH
            if isHover then
                love.graphics.setColor(C.rowHover)
            elseif idx % 2 == 0 then
                love.graphics.setColor(C.rowEven)
            else
                love.graphics.setColor(C.rowOdd)
            end
            love.graphics.rectangle('fill', 20, y, sw - 40, rowH)

            addZone(entry.id, 20, y, sw - 40, rowH, 'select', entry)

            -- Name
            love.graphics.setColor(C.label)
            love.graphics.print(entry.col.name or '???', 20, y + 4)

            -- Health bar
            local hf = healthFrac(entry.col)
            local barW = 70
            love.graphics.setColor(0.2, 0.15, 0.15)
            love.graphics.rectangle('fill', 150, y + 6, barW, 12)
            if hf < 0.3 then
                love.graphics.setColor(C.critical)
            elseif hf < 0.7 then
                love.graphics.setColor(C.injured)
            else
                love.graphics.setColor(C.healthy)
            end
            love.graphics.rectangle('fill', 150, y + 6, barW * hf, 12)
            love.graphics.setColor(C.label)
            love.graphics.print(string.format('%d%%', math.floor(hf * 100)), 225, y + 4)

            -- Mood
            local mood = entry.needs and entry.needs.morale or 50
            love.graphics.setColor(moodColor(mood))
            love.graphics.print(string.format('%.0f', mood), 240, y + 4)

            -- Activity
            local task = entry.col.state or 'idle'
            if task == 'working' and entry.col.task then
                local jok, Jobs = pcall(require, 'src.colonist.jobs')
                if jok then
                    local t = Jobs.getTask(entry.col.task.taskId)
                    if t then task = t.type end
                end
            end
            love.graphics.setColor(C.dim)
            love.graphics.print(task, 310, y + 4)

            -- Skills
            local skills = entry.col.skills or {}
            for i, sk in ipairs(SKILL_ORDER) do
                local sx = skillStartX + (i - 1) * skillColW
                local lv = skills[sk] or 0
                if lv >= 8 then
                    love.graphics.setColor(C.skill_high)
                elseif lv >= 4 then
                    love.graphics.setColor(C.skill_mid)
                else
                    love.graphics.setColor(C.skill_low)
                end
                love.graphics.print(tostring(lv), sx, y + 4)
            end

            -- Wound count
            local wc = getWoundCount(entry.id)
            if wc > 0 then
                love.graphics.setColor(C.wound)
                love.graphics.print(tostring(wc), statusX, y + 4)
            end

            -- Disease
            local dis = getDisease(entry.id)
            if dis then
                love.graphics.setColor(C.disease)
                love.graphics.print(dis.id, statusX + 60, y + 4)
            end
        end
    end

    if #colonists == 0 then
        love.graphics.setColor(C.dim)
        love.graphics.print('No living colonists.', 20, startY)
    end

    -- Footer
    love.graphics.setColor(C.dim)
    love.graphics.print('C — close    Click header to sort    Click row to select + center camera    Scroll — navigate', 20, sh - 20)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function ColonyPanel.keypressed(key)
    if not visible then return false end
    if key == 'c' then
        ColonyPanel.toggle()
        return true
    end
    if key == 'escape' then
        ColonyPanel.toggle()
        return true
    end
    return true -- consume all keys while open
end

function ColonyPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end

    for _, zone in ipairs(hitZones) do
        if x >= zone.x and x <= zone.x + zone.w and y >= zone.y and y <= zone.y + zone.h then
            if zone.action == 'sort' then
                if sortKey == zone.data then
                    sortAsc = not sortAsc
                else
                    sortKey = zone.data
                    sortAsc = true
                end
                return true
            elseif zone.action == 'select' then
                local entry = zone.data
                -- Select the colonist
                GameState.selectedEntities = {}
                GameState.selectedEntities[entry.id] = true
                -- Center camera on them
                local cok, Camera = pcall(require, 'src.render.camera')
                if cok and entry.pos then
                    Camera.centerOn(entry.pos.x, entry.pos.y)
                end
                -- Close panel
                ColonyPanel.toggle()
                return true
            end
        end
    end

    return true -- consume click while open
end

function ColonyPanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return ColonyPanel
