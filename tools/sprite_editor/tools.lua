-- tools.lua — Pure drawing algorithms for the sprite editor
-- All functions are stateless: they take imageData + parameters, return results.

local Tools = {}

---------------------------------------------------------------------------
-- Bresenham line — returns list of {x,y} pixel coordinates
---------------------------------------------------------------------------

function Tools.linePixels(x0, y0, x1, y1)
    local pixels = {}
    local dx  = math.abs(x1 - x0)
    local dy  = -math.abs(y1 - y0)
    local sx  = x0 < x1 and 1 or -1
    local sy  = y0 < y1 and 1 or -1
    local err = dx + dy
    while true do
        pixels[#pixels + 1] = {x = x0, y = y0}
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 >= dy then err = err + dy; x0 = x0 + sx end
        if e2 <= dx then err = err + dx; y0 = y0 + sy end
    end
    return pixels
end

---------------------------------------------------------------------------
-- Bresenham with callback (for real-time freehand drawing)
---------------------------------------------------------------------------

function Tools.bresenhamCB(x0, y0, x1, y1, fn)
    local dx  = math.abs(x1 - x0)
    local dy  = -math.abs(y1 - y0)
    local sx  = x0 < x1 and 1 or -1
    local sy  = y0 < y1 and 1 or -1
    local err = dx + dy
    while true do
        fn(x0, y0)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 >= dy then err = err + dy; x0 = x0 + sx end
        if e2 <= dx then err = err + dx; y0 = y0 + sy end
    end
end

---------------------------------------------------------------------------
-- Pixel-perfect filter — removes L-shaped corner pixels from freehand strokes
-- Makes single-pixel-wide strokes stay exactly 1px wide.
---------------------------------------------------------------------------

function Tools.pixelPerfect(points)
    if #points < 3 then return points end
    local result = {points[1]}
    for i = 2, #points - 1 do
        local prev = points[i - 1]
        local curr = points[i]
        local nxt  = points[i + 1]
        -- L-corner: prev-curr share one axis, curr-next share the other
        local isCorner = (prev.x == curr.x and curr.y == nxt.y) or
                         (prev.y == curr.y and curr.x == nxt.x)
        -- Only remove if prev and next are truly diagonal
        local isDiag = prev.x ~= nxt.x and prev.y ~= nxt.y
        if not (isCorner and isDiag) then
            result[#result + 1] = curr
        end
    end
    result[#result + 1] = points[#points]
    return result
end

---------------------------------------------------------------------------
-- Rectangle pixels (outline or filled)
---------------------------------------------------------------------------

function Tools.rectPixels(x0, y0, x1, y1, filled)
    local pixels = {}
    local minX = math.min(x0, x1)
    local maxX = math.max(x0, x1)
    local minY = math.min(y0, y1)
    local maxY = math.max(y0, y1)
    if filled then
        for y = minY, maxY do
            for x = minX, maxX do
                pixels[#pixels + 1] = {x = x, y = y}
            end
        end
    else
        for x = minX, maxX do
            pixels[#pixels + 1] = {x = x, y = minY}
            if minY ~= maxY then
                pixels[#pixels + 1] = {x = x, y = maxY}
            end
        end
        for y = minY + 1, maxY - 1 do
            pixels[#pixels + 1] = {x = minX, y = y}
            if minX ~= maxX then
                pixels[#pixels + 1] = {x = maxX, y = y}
            end
        end
    end
    return pixels
end

---------------------------------------------------------------------------
-- Ellipse pixels (midpoint algorithm, outline or filled)
---------------------------------------------------------------------------

function Tools.ellipsePixels(cx, cy, rx, ry, filled)
    local pixels = {}
    if rx <= 0 and ry <= 0 then
        pixels[#pixels + 1] = {x = cx, y = cy}
        return pixels
    end
    if rx <= 0 then rx = 1 end
    if ry <= 0 then ry = 1 end

    local set = {}
    local function add(x, y)
        local k = y * 100000 + x
        if not set[k] then
            set[k] = true
            pixels[#pixels + 1] = {x = x, y = y}
        end
    end

    local function plot4(px, py)
        if filled then
            for x = cx - px, cx + px do
                add(x, cy + py)
                add(x, cy - py)
            end
        else
            add(cx + px, cy + py)
            add(cx - px, cy + py)
            add(cx + px, cy - py)
            add(cx - px, cy - py)
        end
    end

    -- Region 1
    local x, y = 0, ry
    local rx2 = rx * rx
    local ry2 = ry * ry
    local d1 = ry2 - rx2 * ry + 0.25 * rx2
    local dx2 = 2 * ry2 * x
    local dy2 = 2 * rx2 * y
    while dx2 < dy2 do
        plot4(x, y)
        x = x + 1
        dx2 = dx2 + 2 * ry2
        if d1 < 0 then
            d1 = d1 + dx2 + ry2
        else
            y = y - 1
            dy2 = dy2 - 2 * rx2
            d1 = d1 + dx2 - dy2 + ry2
        end
    end
    -- Region 2
    local d2 = ry2 * (x + 0.5) * (x + 0.5) + rx2 * (y - 1) * (y - 1) - rx2 * ry2
    while y >= 0 do
        plot4(x, y)
        y = y - 1
        dy2 = dy2 - 2 * rx2
        if d2 > 0 then
            d2 = d2 + rx2 - dy2
        else
            x = x + 1
            dx2 = dx2 + 2 * ry2
            d2 = d2 + dx2 - dy2 + rx2
        end
    end
    return pixels
end

---------------------------------------------------------------------------
-- Symmetry — mirror pixel list across H/V axes
---------------------------------------------------------------------------

function Tools.applySymmetry(pixels, w, h, symH, symV)
    if not symH and not symV then return pixels end
    local result = {}
    local set = {}
    local function add(x, y)
        if x < 0 or y < 0 or x >= w or y >= h then return end
        local k = y * 100000 + x
        if not set[k] then
            set[k] = true
            result[#result + 1] = {x = x, y = y}
        end
    end
    for _, p in ipairs(pixels) do
        add(p.x, p.y)
        if symH then add(w - 1 - p.x, p.y) end
        if symV then add(p.x, h - 1 - p.y) end
        if symH and symV then add(w - 1 - p.x, h - 1 - p.y) end
    end
    return result
end

---------------------------------------------------------------------------
-- Flood fill with tolerance and optional replace-all mode
---------------------------------------------------------------------------

function Tools.floodFill(imageData, sx, sy, color, tolerance, replaceAll)
    local w, h = imageData:getDimensions()
    if sx < 0 or sy < 0 or sx >= w or sy >= h then return false end
    local oR, oG, oB, oA = imageData:getPixel(sx, sy)
    local nR, nG, nB, nA = color[1], color[2], color[3], color[4]
    local tol = (tolerance or 0) / 255

    local function matches(r, g, b, a)
        return math.abs(r - oR) <= tol and math.abs(g - oG) <= tol
           and math.abs(b - oB) <= tol and math.abs(a - oA) <= tol
    end

    -- Don't fill if target matches fill color
    if matches(nR, nG, nB, nA) then return false end

    if replaceAll then
        -- Replace all matching pixels globally (not just contiguous)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local r, g, b, a = imageData:getPixel(x, y)
                if matches(r, g, b, a) then
                    imageData:setPixel(x, y, nR, nG, nB, nA)
                end
            end
        end
    else
        -- Standard BFS flood fill
        local queue = {{sx, sy}}
        local visited = {}
        while #queue > 0 do
            local pt = table.remove(queue, 1)
            local x, y = pt[1], pt[2]
            local k = y * w + x
            if not visited[k] then
                visited[k] = true
                local r, g, b, a = imageData:getPixel(x, y)
                if matches(r, g, b, a) then
                    imageData:setPixel(x, y, nR, nG, nB, nA)
                    if x > 0     then queue[#queue + 1] = {x - 1, y} end
                    if x < w - 1 then queue[#queue + 1] = {x + 1, y} end
                    if y > 0     then queue[#queue + 1] = {x, y - 1} end
                    if y < h - 1 then queue[#queue + 1] = {x, y + 1} end
                end
            end
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Dither patterns — returns true if pixel should be drawn
---------------------------------------------------------------------------

function Tools.shouldDither(x, y, pattern)
    if not pattern or pattern == 'none' then return true end
    if pattern == 'checker' then
        return (x + y) % 2 == 0
    elseif pattern == 'checker2x2' then
        return (math.floor(x / 2) + math.floor(y / 2)) % 2 == 0
    elseif pattern == 'horizontal' then
        return y % 2 == 0
    elseif pattern == 'vertical' then
        return x % 2 == 0
    end
    return true
end

-- Available dither patterns for cycling
Tools.DITHER_PATTERNS = {'none', 'checker', 'checker2x2', 'horizontal', 'vertical'}

---------------------------------------------------------------------------
-- Apply a list of pixels to imageData (with bounds checking and dither)
---------------------------------------------------------------------------

function Tools.commitPixels(imageData, pixels, color, ditherPattern)
    local w, h = imageData:getDimensions()
    local r, g, b, a = color[1], color[2], color[3], color[4]
    for _, p in ipairs(pixels) do
        if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h then
            if Tools.shouldDither(p.x, p.y, ditherPattern) then
                imageData:setPixel(p.x, p.y, r, g, b, a)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Expand pixels by brush size (square brush)
---------------------------------------------------------------------------

function Tools.expandBrush(pixels, brushSize, w, h)
    if brushSize <= 1 then return pixels end
    local bs = brushSize - 1
    local set = {}
    local result = {}
    for _, p in ipairs(pixels) do
        for dy = -bs, bs do
            for dx = -bs, bs do
                local bx, by = p.x + dx, p.y + dy
                if bx >= 0 and by >= 0 and bx < w and by < h then
                    local k = by * 100000 + bx
                    if not set[k] then
                        set[k] = true
                        result[#result + 1] = {x = bx, y = by}
                    end
                end
            end
        end
    end
    return result
end

return Tools
