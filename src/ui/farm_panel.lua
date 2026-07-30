-- farm_panel.lua — Farming management panel
-- Shows all farm plots, lets player plant crops, view growth progress.
-- Toggle with G key.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Layout    = require('src.ui.ui_layout')

local FarmPanel = {}

local visible = false
local scrollY = 0
local plantBtns = {}   -- hit zones rebuilt each frame
local selectedPlot = nil  -- entity ID of plot being planted

---------------------------------------------------------------------------
-- Toggle
---------------------------------------------------------------------------

function FarmPanel.toggle()
    visible = not visible
    scrollY = 0
    selectedPlot = nil
end

function FarmPanel.isVisible()
    return visible
end

---------------------------------------------------------------------------
-- Crop picker sub-view — shown when player clicks Plant on an empty plot
---------------------------------------------------------------------------

local cropBtns = {}

local function drawCropPicker(sw, sh, Agriculture)
    cropBtns = {}

    love.graphics.setColor(0.7, 0.85, 0.7)
    love.graphics.print('SELECT CROP TO PLANT', 20, 58)
    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('Click a crop, or ESC to cancel',
        20 + Layout.textWidth('SELECT CROP TO PLANT') + Layout.FIELD_GAP, 58)

    local CROPS = Agriculture.CROPS
    -- 260px cards held 344px of stats, so every card bled ~92px into the one
    -- beside it. Size the card to the widest line it can contain instead.
    local cardW = math.max(260, Layout.textWidth('Grow: 00:00  Yield: 00-00 cooked_meal  Seed: 00 food') + 20)
    local cardH = 90
    local cols = math.max(1, math.floor((sw - 40) / (cardW + 10)))
    local x0 = 20
    local y0 = 82 - scrollY
    local col = 0

    -- Sort crop IDs for stable display order
    local cropIds = {}
    for cid in pairs(CROPS) do
        cropIds[#cropIds + 1] = cid
    end
    table.sort(cropIds)

    for _, cid in ipairs(cropIds) do
        local def = CROPS[cid]
        local cx = x0 + col * (cardW + 10)
        local cy = y0

        local cardMaxW = cardW - 16
        if cy + cardH > 78 and cy < sh - Layout.BOTTOM_RESERVE - 10 then
            local canAfford = (GameState.resources.food or 0) >= def.seedCost

            -- Card background
            love.graphics.setColor(canAfford and 0.08 or 0.06, canAfford and 0.1 or 0.06, canAfford and 0.08 or 0.06)
            love.graphics.rectangle('fill', cx, cy, cardW, cardH, 4)
            love.graphics.setColor(canAfford and 0.2 or 0.12, canAfford and 0.3 or 0.12, canAfford and 0.2 or 0.12)
            love.graphics.rectangle('line', cx, cy, cardW, cardH, 4)

            -- Name
            love.graphics.setColor(canAfford and 0.9 or 0.5, canAfford and 0.9 or 0.5, canAfford and 0.85 or 0.45)
            love.graphics.print(Layout.truncate(def.name, cardMaxW), cx + 8, cy + 4)

            -- Desc
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print(Layout.truncate(def.desc or '', cardMaxW), cx + 8, cy + 20)

            -- Stats line
            local growMins = math.floor(def.growTime / 60)
            local growSecs = def.growTime % 60
            local statsStr = string.format('Grow: %d:%02d  Yield: %d-%d %s  Seed: %d food',
                growMins, growSecs, def.yield.min, def.yield.max, def.yield.item, def.seedCost)
            love.graphics.setColor(0.55, 0.55, 0.45)
            love.graphics.print(Layout.truncate(statsStr, cardMaxW), cx + 8, cy + 38)

            -- Temp range
            love.graphics.setColor(0.45, 0.5, 0.55)
            local tempStr = string.format('Temp: %d to %d°C (ideal %d-%d)',
                def.minTemp, def.maxTemp, def.idealTemp[1], def.idealTemp[2])
            love.graphics.print(Layout.truncate(tempStr, cardMaxW), cx + 8, cy + 54)

            -- Traits
            local traits = {}
            if not def.light then traits[#traits + 1] = 'Dark OK' end
            if def.co2Bonus then traits[#traits + 1] = 'CO2+' end
            if def.waterNeed == 0 then traits[#traits + 1] = 'No Water' end
            if def.hardiness and def.hardiness >= 0.7 then traits[#traits + 1] = 'Hardy' end
            if #traits > 0 then
                love.graphics.setColor(0.5, 0.7, 0.5)
                love.graphics.print(Layout.truncate(table.concat(traits, '  '), cardMaxW), cx + 8, cy + 70)
            end

            if canAfford then
                cropBtns[#cropBtns + 1] = {
                    x = cx, y = cy, w = cardW, h = cardH,
                    cropId = cid,
                }
            end
        end

        col = col + 1
        if col >= cols then
            col = 0
            y0 = y0 + cardH + 8
        end
    end
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function FarmPanel.draw()
    if not visible then return end

    local aok, Agriculture = pcall(require, 'src.building.agriculture')
    if not aok then return end

    local sw, sh = love.graphics.getDimensions()
    plantBtns = {}

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header
    love.graphics.setColor(0.1, 0.14, 0.1)
    love.graphics.rectangle('fill', 0, 0, sw, 50)
    love.graphics.setColor(0.25, 0.45, 0.25)
    love.graphics.line(0, 50, sw, 50)

    love.graphics.setColor(0.7, 0.9, 0.7)
    love.graphics.print('FARMING', 20, 16)
    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('G / ESC to close', sw - 130, 16)

    -- If selecting a crop for a plot, show crop picker
    if selectedPlot then
        drawCropPicker(sw, sh, Agriculture)
        return
    end

    -- List all farm plots and crops
    local rowH = 50
    local y = 60 - scrollY

    -- Section: Active crops
    love.graphics.setColor(0.8, 0.85, 0.7)
    love.graphics.print('GROWING CROPS', 20, y)
    y = y + 22

    local cropCount = 0
    for id, comps in ECS.query('crop', 'pos') do
        if y + rowH > 78 and y < sh - Layout.BOTTOM_RESERVE - 10 then
            cropCount = cropCount + 1
            local crop = comps.crop
            local pos = comps.pos
            local progress = crop.growth / math.max(crop.growTime, 1)

            -- Row background
            love.graphics.setColor(0.07, 0.09, 0.07)
            love.graphics.rectangle('fill', 20, y, sw - 40, rowH - 4, 3)
            love.graphics.setColor(0.15, 0.2, 0.15)
            love.graphics.rectangle('line', 20, y, sw - 40, rowH - 4, 3)

            -- Crop name and position
            love.graphics.setColor(0.85, 0.85, 0.85)
            love.graphics.print(Layout.fitLabel(crop.name or crop.type, 30, 200), 30, y + 4)
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print(string.format('(%d, %d)', pos.x, pos.y), 200, y + 4)

            -- Status
            if crop.wilted then
                love.graphics.setColor(0.8, 0.3, 0.3)
                love.graphics.print('WILTED', 300, y + 4)
            elseif crop.mature then
                love.graphics.setColor(0.3, 0.8, 0.3)
                love.graphics.print('READY', 300, y + 4)
            else
                love.graphics.setColor(0.7, 0.7, 0.5)
                love.graphics.print(string.format('%d%%', math.floor(progress * 100)), 300, y + 4)
            end

            -- Progress bar
            local barX = 30
            local barY = y + 24
            local barW = sw - 80
            local barH = 10
            love.graphics.setColor(0.15, 0.15, 0.15)
            love.graphics.rectangle('fill', barX, barY, barW, barH, 2)
            if crop.wilted then
                love.graphics.setColor(0.6, 0.2, 0.2)
            elseif crop.mature then
                love.graphics.setColor(0.2, 0.7, 0.2)
            else
                love.graphics.setColor(0.3, 0.6, 0.3)
            end
            love.graphics.rectangle('fill', barX, barY, barW * math.min(1, progress), barH, 2)
        end
        y = y + rowH
    end

    if cropCount == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No crops growing.', 30, y + 4)
        y = y + 24
    end

    -- Section: Empty farm plots
    y = y + 16
    love.graphics.setColor(0.8, 0.85, 0.7)
    love.graphics.print('EMPTY FARM PLOTS', 20, y)
    y = y + 22

    local emptyCount = 0
    for id, comps in ECS.query('decoration', 'pos') do
        if comps.decoration.type == 'farm_plot' then
            -- Check if a crop already exists at this position
            local hasCrop = false
            for _, ccomps in ECS.query('crop', 'pos') do
                if ccomps.pos.x == comps.pos.x and ccomps.pos.y == comps.pos.y then
                    hasCrop = true
                    break
                end
            end
            if not hasCrop then
                emptyCount = emptyCount + 1
                if y > 40 and y < sh - 10 then
                    love.graphics.setColor(0.07, 0.07, 0.09)
                    love.graphics.rectangle('fill', 20, y, sw - 40, 30, 3)
                    love.graphics.setColor(0.15, 0.18, 0.15)
                    love.graphics.rectangle('line', 20, y, sw - 40, 30, 3)

                    love.graphics.setColor(0.7, 0.7, 0.7)
                    love.graphics.print(string.format('Farm Plot (%d, %d)', comps.pos.x, comps.pos.y), 30, y + 6)

                    -- Plant button, sized to its label
                    local btnRect = Layout.buttonRectRight('Plant', sw - 40, y + 3, { h = 24, minW = 60 })
                    Layout.drawButton('Plant', btnRect, 'normal',
                        { normal = { 0.15, 0.3, 0.15 }, text = { 0.4, 0.8, 0.4 } })

                    plantBtns[#plantBtns + 1] = {
                        x = btnRect.x, y = btnRect.y, w = btnRect.w, h = btnRect.h,
                        plotId = id, px = comps.pos.x, py = comps.pos.y,
                    }
                end
                y = y + 34
            end
        end
    end

    if emptyCount == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No empty farm plots. Build farm plots first (B key).', 30, y + 4)
    end
end

---------------------------------------------------------------------------
-- Input handling
---------------------------------------------------------------------------

function FarmPanel.keypressed(key)
    if not visible then return false end
    if key == 'g' or key == 'escape' then
        if selectedPlot then
            selectedPlot = nil  -- back to plot list
        else
            visible = false
        end
        return true
    end
    return true
end

function FarmPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end

    if selectedPlot then
        -- Crop picker mode
        local aok, Agriculture = pcall(require, 'src.building.agriculture')
        if aok then
            for _, btn in ipairs(cropBtns) do
                if x >= btn.x and x <= btn.x + btn.w
                and y >= btn.y and y <= btn.y + btn.h then
                    local plotPos = selectedPlot
                    Agriculture.plantCrop(plotPos.x, plotPos.y, btn.cropId)
                    selectedPlot = nil
                    return true
                end
            end
        end
    else
        -- Plot list mode — check plant buttons
        for _, btn in ipairs(plantBtns) do
            if x >= btn.x and x <= btn.x + btn.w
            and y >= btn.y and y <= btn.y + btn.h then
                selectedPlot = { x = btn.px, y = btn.py }
                scrollY = 0
                cropBtns = {}
                return true
            end
        end
    end
    return true
end

function FarmPanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return FarmPanel
