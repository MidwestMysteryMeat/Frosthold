-- alerts.lua — Letter/notification system
-- Major events generate letters that stack in the corner.
-- Letters persist until dismissed. Each has a priority tier and optional
-- camera jump position. Audio cues play on arrival.

local GameState = require('src.game_state')

local Alerts = {}

---------------------------------------------------------------------------
-- Priority tiers
---------------------------------------------------------------------------

Alerts.PRIORITY = {
    critical = { rank = 1, color = { 0.9, 0.15, 0.15 }, sound = 'alert_critical' },
    major    = { rank = 2, color = { 1.0, 0.6, 0.15 },  sound = 'alert_major' },
    minor    = { rank = 3, color = { 0.9, 0.85, 0.2 },   sound = 'alert_minor' },
    info     = { rank = 4, color = { 0.5, 0.7, 0.9 },    sound = nil },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local letters = {}       -- active letters (newest first)
local MAX_LETTERS = 30
local MAX_VISIBLE = 5    -- show at most 5 letters in the stack

---------------------------------------------------------------------------
-- Create a letter
---------------------------------------------------------------------------

function Alerts.send(title, body, priority, jumpX, jumpY)
    local tier = Alerts.PRIORITY[priority] or Alerts.PRIORITY.info

    local letter = {
        id       = #letters + 1 + math.random(10000),
        title    = title,
        body     = body,
        priority = priority or 'info',
        tier     = tier,
        day      = GameState.day,
        hour     = math.floor(GameState.hour),
        jumpX    = jumpX,
        jumpY    = jumpY,
        read     = false,
    }

    -- Insert at front (newest first)
    table.insert(letters, 1, letter)

    -- Trim old letters
    while #letters > MAX_LETTERS do
        table.remove(letters)
    end

    -- Play sound
    if tier.sound then
        local sok, Sound = pcall(require, 'src.audio.sound')
        if sok then Sound.play(tier.sound) end
    end

    return letter
end

-- Convenience wrappers
function Alerts.critical(title, body, jumpX, jumpY)
    return Alerts.send(title, body, 'critical', jumpX, jumpY)
end

function Alerts.major(title, body, jumpX, jumpY)
    return Alerts.send(title, body, 'major', jumpX, jumpY)
end

function Alerts.minor(title, body, jumpX, jumpY)
    return Alerts.send(title, body, 'minor', jumpX, jumpY)
end

function Alerts.info(title, body, jumpX, jumpY)
    return Alerts.send(title, body, 'info', jumpX, jumpY)
end

---------------------------------------------------------------------------
-- Dismiss / interact
---------------------------------------------------------------------------

function Alerts.dismiss(letterId)
    for i, l in ipairs(letters) do
        if l.id == letterId then
            table.remove(letters, i)
            return true
        end
    end
    return false
end

function Alerts.markRead(letterId)
    for _, l in ipairs(letters) do
        if l.id == letterId then
            l.read = true
            return true
        end
    end
    return false
end

function Alerts.dismissAll()
    letters = {}
end

---------------------------------------------------------------------------
-- Drawing — letter stack in top-right corner
---------------------------------------------------------------------------

local letterHitZones = {}

function Alerts.draw()
    local screenW = love.graphics.getWidth()
    letterHitZones = {}

    local unread = 0
    for _, l in ipairs(letters) do
        if not l.read then unread = unread + 1 end
    end
    if #letters == 0 then return end

    local alertFont = love.graphics.newFont(13)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(alertFont)
    local font = alertFont
    local fh = font:getHeight()
    local cardW = 290
    local cardH = fh * 2 + 10
    local stackX = screenW - cardW - 12
    local stackY = 50

    local shown = math.min(#letters, MAX_VISIBLE)

    for i = 1, shown do
        local l = letters[i]
        local tier = l.tier or Alerts.PRIORITY.info
        local cy = stackY + (i - 1) * (cardH + 4)

        -- Card background — critical/major events get tinted bg
        local isCrit = tier.rank and tier.rank <= 2 and not l.read
        if isCrit then
            love.graphics.setColor(tier.color[1] * 0.15, tier.color[2] * 0.1, tier.color[3] * 0.08, 0.95)
        else
            love.graphics.setColor(0.06, 0.06, 0.09, 0.92)
        end
        love.graphics.rectangle('fill', stackX, cy, cardW, cardH, 4)

        -- Priority stripe (left edge, wider for critical)
        local stripeW = isCrit and 5 or 4
        love.graphics.setColor(tier.color[1], tier.color[2], tier.color[3], l.read and 0.4 or 1.0)
        love.graphics.rectangle('fill', stackX, cy, stripeW, cardH, 2)

        -- Unread dot
        if not l.read then
            love.graphics.setColor(tier.color[1], tier.color[2], tier.color[3])
            love.graphics.circle('fill', stackX + 14, cy + cardH / 2, 4)
        end

        -- Title
        love.graphics.setColor(l.read and 0.5 or 0.9, l.read and 0.5 or 0.9, l.read and 0.5 or 0.9)
        local titleStr = l.title or ''
        if font:getWidth(titleStr) > cardW - 60 then
            while #titleStr > 1 and font:getWidth(titleStr .. '..') > cardW - 60 do
                titleStr = titleStr:sub(1, -2)
            end
            titleStr = titleStr .. '..'
        end
        love.graphics.print(titleStr, stackX + 24, cy + 3)

        -- Day stamp
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print(string.format('D%d', l.day or 0), stackX + cardW - 36, cy + 3)

        -- Body preview (truncated)
        if l.body then
            love.graphics.setColor(0.5, 0.5, 0.5)
            local bodyStr = l.body
            if font:getWidth(bodyStr) > cardW - 30 then
                while #bodyStr > 1 and font:getWidth(bodyStr .. '..') > cardW - 30 do
                    bodyStr = bodyStr:sub(1, -2)
                end
                bodyStr = bodyStr .. '..'
            end
            love.graphics.print(bodyStr, stackX + 24, cy + fh + 3)
        end

        -- Hit zone for click
        letterHitZones[#letterHitZones + 1] = {
            x = stackX, y = cy, w = cardW, h = cardH,
            letterId = l.id,
            jumpX = l.jumpX, jumpY = l.jumpY,
        }
    end

    -- Overflow indicator
    if #letters > MAX_VISIBLE then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print(string.format('+%d more', #letters - MAX_VISIBLE),
            stackX + 24, stackY + shown * (cardH + 4) + 2)
    end
    love.graphics.setFont(prevFont)
end

---------------------------------------------------------------------------
-- Input — returns true if consumed
---------------------------------------------------------------------------

function Alerts.mousepressed(mx, my, button)
    if button ~= 1 then return false end

    for _, zone in ipairs(letterHitZones) do
        if mx >= zone.x and mx <= zone.x + zone.w
           and my >= zone.y and my <= zone.y + zone.h then
            -- Mark as read
            Alerts.markRead(zone.letterId)

            -- Jump camera if position available
            if zone.jumpX and zone.jumpY then
                local cok, Camera = pcall(require, 'src.render.camera')
                if cok and Camera.setTarget then
                    Camera.setTarget(zone.jumpX, zone.jumpY)
                end
            end

            return true
        end
    end
    return false
end

-- Right-click to dismiss
function Alerts.mouserightpressed(mx, my)
    for _, zone in ipairs(letterHitZones) do
        if mx >= zone.x and mx <= zone.x + zone.w
           and my >= zone.y and my <= zone.y + zone.h then
            Alerts.dismiss(zone.letterId)
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Alerts.getLetters()
    return letters
end

function Alerts.getUnreadCount()
    local n = 0
    for _, l in ipairs(letters) do
        if not l.read then n = n + 1 end
    end
    return n
end

function Alerts.hasUnread()
    return Alerts.getUnreadCount() > 0
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Alerts.getState()
    return letters
end

function Alerts.restoreState(state)
    letters = state or {}
    -- Rebuild tier references
    for _, l in ipairs(letters) do
        l.tier = Alerts.PRIORITY[l.priority] or Alerts.PRIORITY.info
    end
end

return Alerts
