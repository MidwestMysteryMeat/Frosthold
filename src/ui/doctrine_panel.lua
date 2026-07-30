local Layout = require('src.ui.ui_layout')

local DoctrinePanel = {}

local visible = false
local unlockRects = {}
local flashText = nil
local flashTimer = 0
local scrollY = 0
local contentH = 0
local viewH = 0

local function setFlash(text)
    flashText = text
    flashTimer = 4.0
end

function DoctrinePanel.toggle()
    visible = not visible
    scrollY = 0
end

function DoctrinePanel.isVisible()
    return visible
end

function DoctrinePanel.update(dt)
    if flashTimer > 0 then
        flashTimer = math.max(0, flashTimer - dt)
        if flashTimer == 0 then flashText = nil end
    end
end

function DoctrinePanel.draw()
    if not visible then return end

    local dok, Doctrines = pcall(require, 'src.colony.doctrines')
    if not dok then return end

    local sw, sh = love.graphics.getDimensions()
    local paths = Doctrines.getAllPaths and Doctrines.getAllPaths() or {}
    local points = Doctrines.getPoints and Doctrines.getPoints() or 0
    local chosen = Doctrines.getChosenPath and Doctrines.getChosenPath() or nil

    unlockRects = {}

    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    love.graphics.setColor(0.1, 0.12, 0.16)
    love.graphics.rectangle('fill', 0, 0, sw, 54)
    love.graphics.setColor(0.25, 0.35, 0.45)
    love.graphics.line(0, 54, sw, 54)

    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.print('COLONY DOCTRINES', 20, 18)
    love.graphics.setColor(0.45, 0.45, 0.45)
    do
        local hint = 'O / ESC to close'
        love.graphics.print(hint, sw - Layout.textWidth(hint) - 20, 18)
    end

    love.graphics.setColor(0.65, 0.65, 0.58)
    local chosenText = chosen and ('Committed path: ' .. chosen) or 'No doctrine path chosen yet'
    love.graphics.print(Layout.truncate(
        string.format('Doctrine points: %d  |  %s', points, chosenText), sw - 40), 20, 66)

    local margin = 20
    local gap = 14
    local panelY = 100
    local pathW = math.floor((sw - margin * 2 - gap * 2) / 3)

    -- Tier cards used to run straight off the bottom of the path card and off
    -- the screen: four tiers need ~400px below panelY, and wheelmoved was a stub
    -- that consumed the scroll without moving anything.
    local TIER_H, TIER_GAP, TIERS_TOP = 90, 10, 82
    local maxTiers = 0
    for _, path in ipairs(paths) do
        maxTiers = math.max(maxTiers, #(path.tiers or {}))
    end
    viewH = sh - panelY - Layout.BOTTOM_RESERVE - 30
    local pathH = viewH
    contentH = TIERS_TOP + maxTiers * (TIER_H + TIER_GAP)
    scrollY = (Layout.clampScroll(scrollY, contentH, pathH))

    for i, path in ipairs(paths) do
        local px = margin + (i - 1) * (pathW + gap)
        local py = panelY

        if path.locked then
            love.graphics.setColor(0.08, 0.08, 0.1, 0.95)
        else
            love.graphics.setColor(0.11, 0.11, 0.14, 0.95)
        end
        love.graphics.rectangle('fill', px, py, pathW, pathH, 6, 6)

        if chosen == path.id then
            love.graphics.setColor(0.4, 0.65, 0.35, 0.9)
        elseif path.locked then
            love.graphics.setColor(0.25, 0.2, 0.2, 0.7)
        else
            love.graphics.setColor(0.25, 0.3, 0.38, 0.8)
        end
        love.graphics.rectangle('line', px, py, pathW, pathH, 6, 6)

        love.graphics.setColor(0.92, 0.88, 0.74)
        love.graphics.print(Layout.truncate(string.upper(path.name or path.id), pathW - 24),
            px + 12, py + 12)
        love.graphics.setColor(0.58, 0.58, 0.52)
        love.graphics.printf(path.desc or '', px + 12, py + 30, pathW - 24)

        -- Tiers scroll inside their path card
        local clip = Layout.pushClip(px + 1, py + TIERS_TOP - 6, pathW - 2, pathH - TIERS_TOP + 4)
        local tierY = py + TIERS_TOP - scrollY
        for tierIndex, tier in ipairs(path.tiers or {}) do
            local currentTier = path.currentTier or 0
            local unlocked = tierIndex <= currentTier
            local available = (not path.locked) and tierIndex == currentTier + 1
            local rectH = 90

            if unlocked then
                love.graphics.setColor(0.12, 0.22, 0.12)
            elseif available then
                love.graphics.setColor(0.16, 0.16, 0.2)
            else
                love.graphics.setColor(0.08, 0.08, 0.1)
            end
            love.graphics.rectangle('fill', px + 10, tierY, pathW - 20, rectH, 4, 4)

            if unlocked then
                love.graphics.setColor(0.35, 0.75, 0.35, 0.8)
            elseif available then
                love.graphics.setColor(0.45, 0.4, 0.2, 0.8)
                -- Only register a tier the player can actually see and click.
                if tierY >= clip.y and tierY + rectH <= clip.y + clip.h then
                    unlockRects[#unlockRects + 1] = {
                        x = px + 10, y = tierY, w = pathW - 20, h = rectH,
                        pathId = path.id,
                    }
                end
            else
                love.graphics.setColor(0.22, 0.22, 0.28, 0.8)
            end
            love.graphics.rectangle('line', px + 10, tierY, pathW - 20, rectH, 4, 4)

            love.graphics.setColor(0.85, 0.85, 0.82)
            love.graphics.print(Layout.truncate(
                string.format('Tier %d: %s', tierIndex, tier.name or tier.id), pathW - 36),
                px + 18, tierY + 10)
            love.graphics.setColor(0.58, 0.58, 0.56)
            love.graphics.printf(tier.desc or '', px + 18, tierY + 28, pathW - 56)

            local status = 'Locked'
            if unlocked then
                status = 'Unlocked'
            elseif available then
                status = string.format('Unlock (%d pts)', tier.cost or 0)
            elseif path.locked then
                status = 'Other path chosen'
            end

            love.graphics.setColor(0.6, 0.55, 0.4)
            love.graphics.print(Layout.truncate(status, pathW - 36), px + 18, tierY + 68)
            tierY = tierY + rectH + TIER_GAP
        end
        Layout.popClip()
        Layout.drawScrollbar({ x = px, y = py + TIERS_TOP, w = pathW, h = pathH - TIERS_TOP },
            scrollY, contentH - TIERS_TOP)
    end

    if flashText then
        love.graphics.setColor(0.92, 0.82, 0.55)
        love.graphics.printf(flashText, 20, sh - Layout.BOTTOM_RESERVE - 22, sw - 40, 'center')
    end
end

function DoctrinePanel.keypressed(key)
    if not visible then return false end
    if key == 'o' or key == 'escape' then
        visible = false
        return true
    end
    return true
end

function DoctrinePanel.mousepressed(x, y, button)
    if not visible then return false end
    if button == 1 then
        local dok, Doctrines = pcall(require, 'src.colony.doctrines')
        if dok and Doctrines.unlock then
            for _, rect in ipairs(unlockRects) do
                if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
                    local ok, msg = Doctrines.unlock(rect.pathId)
                    if ok then
                        local StorytellerOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
                        local pathName = rect.pathId:gsub('_', ' ')
                        if StorytellerOk and Storyteller.logEvent then
                            Storyteller.logEvent('Doctrine Unlocked', 'Doctrine path advanced: ' .. pathName)
                        end
                        setFlash('Doctrine advanced: ' .. pathName)
                    else
                        setFlash(msg or 'Unable to unlock doctrine')
                    end
                    return true
                end
            end
        end
    end
    return true
end

function DoctrinePanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = (Layout.clampScroll(scrollY - dy * 30, contentH, viewH))
    return true
end

return DoctrinePanel
