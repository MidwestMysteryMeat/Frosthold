local VFX = {}

local effects = {}
local pool = {}

local function takeEffect()
    local fx = pool[#pool]
    if fx then
        pool[#pool] = nil
        return fx
    end
    return {}
end

local function recycleEffect(index)
    local fx = effects[index]
    if not fx then return end
    effects[index] = effects[#effects]
    effects[#effects] = nil
    for k in pairs(fx) do
        fx[k] = nil
    end
    pool[#pool + 1] = fx
end

function VFX.init()
    effects = {}
    pool = {}
end

function VFX.reset()
    VFX.init()
end

function VFX.spawn(kind, x, y, depth, opts)
    local fx = takeEffect()
    opts = opts or {}
    fx.kind = kind or 'burst'
    fx.x = x or 0
    fx.y = y or 0
    fx.x2 = opts.x2
    fx.y2 = opts.y2
    fx.depth = depth or 0
    fx.duration = math.max(0.05, opts.duration or 0.35)
    fx.elapsed = 0
    fx.radius = opts.radius or 0.15
    fx.endRadius = opts.endRadius or math.max(fx.radius, opts.endRadius or 0.9)
    fx.width = opts.width or 2
    fx.pad = opts.pad or 0
    fx.color = opts.color or { 1, 1, 1, 1 }
    fx.fill = opts.fill ~= false
    effects[#effects + 1] = fx
    return fx
end

function VFX.step(dt)
    for i = #effects, 1, -1 do
        local fx = effects[i]
        fx.elapsed = (fx.elapsed or 0) + dt
        if fx.elapsed >= (fx.duration or 0) then
            recycleEffect(i)
        end
    end
end

function VFX.draw(viewDepth, tileSize)
    if #effects == 0 then return end
    local ts = tileSize or 32
    for i = 1, #effects do
        local fx = effects[i]
        if (fx.depth or 0) == (viewDepth or 0) then
            local life = math.max(0, math.min(1, (fx.elapsed or 0) / math.max(0.001, fx.duration or 0.35)))
            local fade = 1 - life
            local color = fx.color or { 1, 1, 1, 1 }
            local alpha = (color[4] or 1) * fade
            local radius = (fx.radius or 0.2) + ((fx.endRadius or fx.radius or 0.2) - (fx.radius or 0.2)) * life
            local cx = fx.x * ts + ts / 2
            local cy = fx.y * ts + ts / 2

            if fx.kind == 'ring' then
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.setLineWidth(fx.width or 2)
                love.graphics.circle('line', cx, cy, radius * ts)
                love.graphics.setLineWidth(1)
            elseif fx.kind == 'line' then
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.setLineWidth(fx.width or 2)
                love.graphics.line(
                    cx,
                    cy,
                    (fx.x2 or fx.x) * ts + ts / 2,
                    (fx.y2 or fx.y) * ts + ts / 2
                )
                love.graphics.setLineWidth(1)
            elseif fx.kind == 'tile' then
                local pad = fx.pad or 0
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.rectangle('fill', fx.x * ts + pad, fx.y * ts + pad, ts - pad * 2, ts - pad * 2, 3, 3)
            else
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                if fx.fill then
                    love.graphics.circle('fill', cx, cy, radius * ts)
                else
                    love.graphics.circle('line', cx, cy, radius * ts)
                end
            end
        end
    end
end

function VFX.getActiveCount()
    return #effects
end

return VFX
