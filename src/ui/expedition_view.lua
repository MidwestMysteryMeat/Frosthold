-- expedition_view.lua — Full-screen overlay for viewing active expedition maps
-- Shows mini-tilemap, colonist positions, POI markers, fog, event log.
-- Toggle with E key. ESC closes.

local GameState   = require('src.game_state')
local ExpMap      = require('src.exploration.expedition_map')

local Layout = require('src.ui.ui_layout')

local ExpView = {}

local active = false
local viewingIdx = 1  -- index into activeExpeditions
local logScroll = 0

---------------------------------------------------------------------------
-- Tile colors
---------------------------------------------------------------------------

local TILE_COLORS = {
    [0] = { 0.15, 0.15, 0.2 },   -- wall
    [1] = { 0.35, 0.38, 0.4 },   -- floor
    [2] = { 0.5, 0.7, 0.9 },     -- ice
    [3] = { 0.25, 0.22, 0.2 },   -- rock
}

local FOG_COLOR = { 0.05, 0.05, 0.08, 0.92 }

local POI_COLORS = {
    entrance  = { 0.2, 0.8, 0.2 },
    loot      = { 1.0, 0.85, 0.2 },
    encounter = { 1.0, 0.3, 0.2 },
    objective = { 0.3, 0.6, 1.0 },
}

local POI_SYMBOLS = {
    entrance  = 'E',
    loot      = '$',
    encounter = '!',
    objective = '*',
}

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function ExpView.isActive()
    return active
end

function ExpView.toggle()
    active = not active
    logScroll = 0
end

function ExpView.close()
    active = false
end

function ExpView.setViewingIndex(idx)
    viewingIdx = idx or 1
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function ExpView.draw()
    if not active then return end

    local ok, Expeditions = pcall(require, 'src.exploration.expeditions')
    if not ok then return end

    local exps = Expeditions.getActive()
    if #exps == 0 then
        -- No active expeditions — show message
        local sw, sh = love.graphics.getDimensions()
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle('fill', 0, 0, sw, sh)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf('No active expeditions.\nPress E to close.', 0, sh / 2 - 20, sw, 'center')
        return
    end

    if viewingIdx > #exps then viewingIdx = 1 end
    local exp = exps[viewingIdx]
    local map = exp.map

    local sw, sh = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    if not map then
        -- Expedition has no visual map (legacy or pre-visual)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf(
            exp.destName .. '\nProgress: ' .. math.floor((exp.elapsed / exp.duration) * 100) .. '%\n(No visual map — timer-based expedition)\nPress E to close.',
            0, sh / 2 - 40, sw, 'center'
        )
        return
    end

    -- Calculate tile size to fit map in left 70% of screen
    local mapAreaW = math.floor(sw * 0.68)
    local mapAreaH = sh - 80  -- top/bottom margins
    local tileSize = math.floor(math.min(mapAreaW / map.w, mapAreaH / map.h))
    if tileSize < 4 then tileSize = 4 end
    if tileSize > 14 then tileSize = 14 end

    local mapPxW = map.w * tileSize
    local mapPxH = map.h * tileSize
    local mapX = 20
    local mapY = 50

    -- Title bar
    love.graphics.setColor(0.8, 0.85, 0.9)
    love.graphics.print(exp.destName .. '  —  Expedition ' .. viewingIdx .. '/' .. #exps, 20, 12)
    local progress = math.floor((exp.elapsed / exp.duration) * 100)
    love.graphics.setColor(0.5, 0.6, 0.7)
    love.graphics.print('Progress: ' .. progress .. '%    E: close    Tab: switch expedition', 20, 30)

    -- Draw tiles
    for y = 0, map.h - 1 do
        for x = 0, map.w - 1 do
            local px = mapX + x * tileSize
            local py = mapY + y * tileSize
            if map.fog[y][x] then
                local t = map.tiles[y][x]
                local c = TILE_COLORS[t] or TILE_COLORS[0]
                love.graphics.setColor(c[1], c[2], c[3])
                love.graphics.rectangle('fill', px, py, tileSize, tileSize)
            else
                love.graphics.setColor(FOG_COLOR[1], FOG_COLOR[2], FOG_COLOR[3], FOG_COLOR[4])
                love.graphics.rectangle('fill', px, py, tileSize, tileSize)
            end
        end
    end

    -- Draw POI markers (only if revealed)
    for _, poi in ipairs(map.pois) do
        if map.fog[poi.y] and map.fog[poi.y][poi.x] then
            local px = mapX + poi.x * tileSize
            local py = mapY + poi.y * tileSize
            local col = POI_COLORS[poi.type] or { 1, 1, 1 }

            if poi.resolved then
                love.graphics.setColor(col[1] * 0.4, col[2] * 0.4, col[3] * 0.4, 0.5)
            else
                local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 3)
                love.graphics.setColor(col[1], col[2], col[3], pulse)
            end

            love.graphics.rectangle('fill', px, py, tileSize, tileSize)

            -- Symbol
            if tileSize >= 8 then
                love.graphics.setColor(0, 0, 0)
                local sym = POI_SYMBOLS[poi.type] or '?'
                love.graphics.print(sym, px + 1, py - 1)
            end
        end
    end

    -- Draw explorers
    for _, exp2 in ipairs(map.explorers) do
        local px = mapX + exp2.x * tileSize + tileSize / 2
        local py = mapY + exp2.y * tileSize + tileSize / 2
        local r = math.max(2, tileSize * 0.4)
        love.graphics.setColor(0.2, 0.9, 0.3)
        love.graphics.circle('fill', px, py, r)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle('line', px, py, r)
        -- Name label
        if tileSize >= 6 then
            love.graphics.setColor(0.9, 0.95, 1)
            love.graphics.print(exp2.name, px + r + 2, py - 6)
        end
    end

    -- Right panel: info + log
    local panelX = mapX + mapPxW + 20
    local panelW = sw - panelX - 10
    local panelY = 50

    -- Every line in this column is ellipsised to panelW. The column narrows as
    -- the map grows, and unbounded prints ran off the right edge of the screen.
    local function infoLine(text, gap)
        love.graphics.print(Layout.truncate(text, panelW), panelX, panelY)
        panelY = panelY + (gap or 18)
    end

    -- Expedition info
    love.graphics.setColor(0.8, 0.85, 0.9)
    infoLine('Destination: ' .. exp.destName)
    love.graphics.setColor(0.6, 0.7, 0.8)
    infoLine('Risk: ' .. exp.risk .. '/5')
    infoLine('Party: ' .. #map.explorers)

    -- Loot collected so far
    if #map.lootCollected > 0 then
        love.graphics.setColor(1, 0.85, 0.2)
        infoLine('Loot found:', 16)
        -- Aggregate by item
        local agg = {}
        for _, loot in ipairs(map.lootCollected) do
            agg[loot.itemId] = (agg[loot.itemId] or 0) + loot.amount
        end
        -- Sorted, and capped so a long loot list cannot push the event log off
        -- the bottom of the screen (which produced a negative scissor height).
        local lootNames = {}
        for item in pairs(agg) do lootNames[#lootNames + 1] = item end
        table.sort(lootNames)
        love.graphics.setColor(0.8, 0.8, 0.6)
        local shown = math.min(#lootNames, 8)
        for i = 1, shown do
            local item = lootNames[i]
            infoLine('  ' .. item .. ': ' .. agg[item], 14)
        end
        if #lootNames > shown then
            infoLine(string.format('  +%d more', #lootNames - shown), 14)
        end
    end

    panelY = panelY + 8

    -- Combat summary
    if map.encountersWon > 0 or map.encountersLost > 0 then
        love.graphics.setColor(0.7, 0.7, 0.7)
        infoLine('Fights won: ' .. map.encountersWon .. '  lost: ' .. map.encountersLost)
    end

    -- Completion status
    if map.completed then
        local oc = map.outcome or 'partial'
        if oc == 'success' then
            love.graphics.setColor(0.2, 1, 0.3)
        elseif oc == 'partial' then
            love.graphics.setColor(1, 0.8, 0.2)
        else
            love.graphics.setColor(1, 0.3, 0.2)
        end
        infoLine('COMPLETED: ' .. oc:upper())
    end

    -- POI legend
    panelY = panelY + 12
    love.graphics.setColor(0.6, 0.6, 0.6)
    infoLine('Legend:', 16)
    local legendItems = { 'entrance', 'loot', 'encounter', 'objective' }
    for _, ptype in ipairs(legendItems) do
        local c = POI_COLORS[ptype]
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.rectangle('fill', panelX, panelY + 2, 10, 10)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(Layout.truncate(POI_SYMBOLS[ptype] .. ' ' .. ptype, panelW - 14),
            panelX + 14, panelY)
        panelY = panelY + 14
    end

    -- Event log (bottom of right panel)
    panelY = panelY + 16
    love.graphics.setColor(0.5, 0.55, 0.6)
    infoLine('Event Log:', 16)

    -- The info column above grows with loot and outcome lines. Once it reached
    -- the bottom of the screen logH went negative, and setScissor errors on a
    -- negative height: an expedition with a long loot list crashed the game.
    local logBottom = sh - Layout.BOTTOM_RESERVE - 10
    local logH = math.max(0, logBottom - panelY)
    if logH >= 14 then
        local logCount = #map.log
        local clip = Layout.pushClip(panelX, panelY, panelW, logH)
        logScroll = (Layout.clampScroll(logScroll, logCount * 14, logH))
        local logY = panelY - logScroll
        for i = logCount, 1, -1 do
            if logY > clip.y + clip.h then break end
            local entry = map.log[i]
            if logY + 14 >= clip.y then
                love.graphics.setColor(0.65, 0.7, 0.75)
                love.graphics.print(
                    Layout.truncate(string.format('[%.0fs] %s', entry.time, entry.text), panelW),
                    panelX, logY)
            end
            logY = logY + 14
        end
        Layout.popClip()
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function ExpView.keypressed(key)
    if not active then return false end
    if key == 'e' or key == 'escape' then
        active = false
        return true
    end
    if key == 'tab' then
        local ok, Expeditions = pcall(require, 'src.exploration.expeditions')
        if ok then
            local count = Expeditions.getActiveCount()
            if count > 0 then
                viewingIdx = (viewingIdx % count) + 1
                logScroll = 0
            end
        end
        return true
    end
    return true  -- consume all keys when overlay is open
end

function ExpView.wheelmoved(dx, dy)
    if not active then return false end
    logScroll = math.max(0, logScroll - dy * 14)
    return true
end

function ExpView.mousepressed(x, y, button)
    if not active then return false end
    return true  -- consume clicks
end

return ExpView
