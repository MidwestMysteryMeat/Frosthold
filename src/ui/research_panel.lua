-- research_panel.lua — Tech tree panel for selecting and viewing research

local Research = require('src.research.research')
local Layout   = require('src.ui.ui_layout')

local ResearchPanel = {}

local visible = false
local scrollY = 0
local nodeRects = {}
local searchTerm = ''
local searchFocused = false
local searchBox = { x = 150, y = 10, w = 260, h = 24 }

local TIER_COLORS = {
    {0.4, 0.65, 0.4},
    {0.4, 0.5, 0.75},
    {0.6, 0.4, 0.7},
    {0.75, 0.55, 0.3},
    {0.75, 0.3, 0.3},
}

function ResearchPanel.toggle()
    visible = not visible
    scrollY = 0
    searchFocused = false
end

function ResearchPanel.isVisible()
    return visible
end

local function matchesSearch(node)
    if searchTerm == '' then return true end
    local haystack = table.concat({
        node.id or '',
        node.name or '',
        node.desc or '',
    }, ' '):lower()
    return haystack:find(searchTerm:lower(), 1, true) ~= nil
end

local function getFilteredNodesByTier(tier)
    local filtered = {}
    for _, node in ipairs(Research.getNodesByTier(tier)) do
        if matchesSearch(node) then
            filtered[#filtered + 1] = node
        end
    end
    return filtered
end

function ResearchPanel.getFilteredNodeCount()
    local total = 0
    for tier = 1, 5 do
        total = total + #getFilteredNodesByTier(tier)
    end
    return total
end

function ResearchPanel.getMaxScrollY()
    local maxRows = 0
    for tier = 1, 5 do
        local count = #getFilteredNodesByTier(tier)
        if count > maxRows then maxRows = count end
    end
    return math.max(0, maxRows * 62 - 400)
end

function ResearchPanel.draw()
    if not visible then return end

    local sw, sh = love.graphics.getDimensions()
    nodeRects = {}

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header bar
    love.graphics.setColor(0.1, 0.12, 0.16)
    love.graphics.rectangle('fill', 0, 0, sw, 84)
    love.graphics.setColor(0.25, 0.35, 0.45)
    love.graphics.line(0, 84, sw, 84)

    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.print('RESEARCH', 20, 10)

    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('R / ESC to close', sw - 130, 10)

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(string.format('%d / %d completed',
        Research.getTotalCompleted(), Research.getTotalNodes()), sw - 180, 30)

    local searchText = (searchTerm ~= '' and searchTerm) or 'Search research...'
    love.graphics.setColor(searchFocused and 0.14 or 0.08, searchFocused and 0.18 or 0.08, 0.2, 0.92)
    love.graphics.rectangle('fill', searchBox.x, searchBox.y, searchBox.w, searchBox.h, 4)
    love.graphics.setColor(searchFocused and 0.45 or 0.28, searchFocused and 0.7 or 0.35, searchFocused and 1 or 0.45, 0.75)
    love.graphics.rectangle('line', searchBox.x, searchBox.y, searchBox.w, searchBox.h, 4)
    love.graphics.setColor(searchTerm ~= '' and 0.9 or 0.45, searchTerm ~= '' and 0.92 or 0.45, searchTerm ~= '' and 0.95 or 0.45)
    -- A long search term used to run straight out of the box and across the
    -- header. Show the tail, so what you just typed stays visible.
    do
        local shown = searchText
        local budget = searchBox.w - 16
        if Layout.textWidth(shown) > budget then
            local n = 1
            while n < #shown and Layout.textWidth(shown:sub(n)) > budget do n = n + 1 end
            shown = shown:sub(n)
        end
        love.graphics.print(shown, searchBox.x + 8, searchBox.y + 4)
    end

    -- Current research progress
    local currentId = Research.getCurrent()
    if currentId then
        local node = Research.getNode(currentId)
        local prog, cost = Research.getProgress()
        love.graphics.setColor(0.8, 0.8, 0.3)
        love.graphics.print(string.format('Researching: %s', node and node.name or currentId), 20, 36)
        local barW = 300
        love.graphics.setColor(0.15, 0.15, 0.15)
        love.graphics.rectangle('fill', 20, 56, barW, 10, 2)
        love.graphics.setColor(0.3, 0.7, 0.9)
        love.graphics.rectangle('fill', 20, 56, barW * (prog / math.max(cost, 1)), 10, 2)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print(string.format('%.0f / %d pts  (click to cancel)', prog, cost), barW + 28, 52)
    else
        love.graphics.setColor(0.45, 0.45, 0.45)
        love.graphics.print('No research selected. Click an available node to begin.', 20, 42)
    end

    -- Tech tree: 5 tier columns
    local colW = math.floor((sw - 60) / 5)
    local nodeW = colW - 10
    local nodeH = 56
    local gapY = 6
    local baseY = 90 - scrollY

    -- Clip the grid to the area below the header. Nodes drawn while scrolled up
    -- used to paint over the search box and progress bar, and their hit zones
    -- were registered there too, so header clicks selected hidden research.
    local treeTop = 86
    local treeH = sh - treeTop - Layout.BOTTOM_RESERVE
    Layout.pushClip(0, treeTop, sw, treeH)

    for tier = 1, 5 do
        local colX = 10 + (tier - 1) * colW
        local tc = TIER_COLORS[tier]

        love.graphics.setColor(tc[1], tc[2], tc[3], 0.9)
        love.graphics.print(string.format('TIER %d', tier), colX + 4, baseY)

        local nodes = getFilteredNodesByTier(tier)
        local ny = baseY + 18

        for _, node in ipairs(nodes) do
            if ny + nodeH > treeTop and ny < treeTop + treeH then
                local isComp = Research.isCompleted(node.id)
                local isAvail = Research.canResearch(node.id)
                local isCur = (currentId == node.id)

                -- Background
                if isCur then
                    love.graphics.setColor(0.12, 0.2, 0.32)
                elseif isComp then
                    love.graphics.setColor(0.06, 0.18, 0.06)
                elseif isAvail then
                    love.graphics.setColor(0.1, 0.1, 0.18)
                else
                    love.graphics.setColor(0.06, 0.06, 0.06)
                end
                love.graphics.rectangle('fill', colX, ny, nodeW, nodeH, 3)

                -- Border
                if isCur then
                    love.graphics.setColor(0.4, 0.7, 1, 0.8)
                elseif isComp then
                    love.graphics.setColor(0.3, 0.7, 0.3, 0.6)
                elseif isAvail then
                    love.graphics.setColor(tc[1], tc[2], tc[3], 0.5)
                else
                    love.graphics.setColor(0.15, 0.15, 0.15)
                end
                love.graphics.rectangle('line', colX, ny, nodeW, nodeH, 3)

                -- Name
                local nc = (isComp or isAvail or isCur) and 0.9 or 0.35
                love.graphics.setColor(nc, nc, nc)
                -- Measured, not guessed. The old math.floor(nodeW / 7) assumed
                -- 7px per character against a 16px font, so long names spilled
                -- ~35px into the next tier column.
                love.graphics.print(Layout.truncate(node.name, nodeW - 10), colX + 5, ny + 3)

                -- Status
                if isComp then
                    love.graphics.setColor(0.3, 0.7, 0.3)
                    love.graphics.print('DONE', colX + 5, ny + 19)
                elseif isCur then
                    local p, c = Research.getProgress()
                    love.graphics.setColor(0.4, 0.7, 1)
                    love.graphics.print(string.format('%.0f / %d', p, c), colX + 5, ny + 19)
                    love.graphics.setColor(0.15, 0.15, 0.15)
                    love.graphics.rectangle('fill', colX + 5, ny + 33, nodeW - 10, 4, 1)
                    love.graphics.setColor(0.4, 0.7, 1)
                    love.graphics.rectangle('fill', colX + 5, ny + 33,
                        (nodeW - 10) * (p / math.max(c, 1)), 4, 1)
                else
                    love.graphics.setColor(0.35, 0.35, 0.35)
                    love.graphics.print(string.format('%d pts', node.cost), colX + 5, ny + 19)
                end

                -- Desc
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.print(Layout.truncate(node.desc or '', nodeW - 10), colX + 5, ny + 40)

                -- Only register a node the player can actually see.
                if ny >= treeTop and ny + nodeH <= treeTop + treeH then
                    nodeRects[#nodeRects + 1] = {
                        x = colX, y = ny, w = nodeW, h = nodeH, id = node.id
                    }
                end
            end
            ny = ny + nodeH + gapY
        end
    end

    Layout.popClip()
end

function ResearchPanel.keypressed(key)
    if not visible then return false end
    if searchFocused then
        if key == 'backspace' then
            searchTerm = Layout.dropLastChar(searchTerm)
            scrollY = 0
            return true
        end
        if key == 'escape' then
            searchFocused = false
            return true
        end
        return true
    end
    if key == 'r' or key == 'escape' then
        visible = false
        return true
    end
    return true
end

function ResearchPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button == 1 then
        if x >= searchBox.x and x <= searchBox.x + searchBox.w and y >= searchBox.y and y <= searchBox.y + searchBox.h then
            searchFocused = true
            return true
        end
        searchFocused = false
        for _, rect in ipairs(nodeRects) do
            if x >= rect.x and x <= rect.x + rect.w
            and y >= rect.y and y <= rect.y + rect.h then
                local currentId = Research.getCurrent()
                if currentId == rect.id then
                    Research.cancelCurrent()
                elseif Research.canResearch(rect.id) then
                    Research.setCurrent(rect.id)
                end
                return true
            end
        end
    end
    return true
end

function ResearchPanel.wheelmoved(dx, dy)
    if not visible then return false end
    local maxScrollY = ResearchPanel.getMaxScrollY()
    scrollY = math.max(0, math.min(maxScrollY, scrollY - dy * 30))
    return true
end

function ResearchPanel.textinput(text)
    if not visible or not searchFocused then return false end
    if (text:match('%S') or text == ' ') and #searchTerm < 40 then
        searchTerm = searchTerm .. text
        scrollY = 0
    end
    return true
end

return ResearchPanel
