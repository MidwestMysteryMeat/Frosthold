-- palette.lua — Color data and utilities for the sprite editor

local Palette = {}

---------------------------------------------------------------------------
-- DB32 (DawnBringer 32) + extras = 48 colors
---------------------------------------------------------------------------

local function c(r, g, b, a)
    return {r / 255, g / 255, b / 255, (a or 255) / 255}
end

Palette.COLORS = {
    -- DB32 row 1
    c(0,0,0),       c(34,32,52),    c(69,40,60),    c(102,57,49),
    c(143,86,59),   c(223,113,38),  c(217,160,102), c(238,195,154),
    -- DB32 row 2
    c(251,242,54),  c(153,229,80),  c(106,190,48),  c(55,148,110),
    c(75,105,47),   c(82,75,36),    c(50,60,57),    c(63,63,116),
    -- DB32 row 3
    c(48,96,130),   c(91,110,225),  c(99,155,255),  c(95,205,228),
    c(203,219,252), c(255,255,255), c(155,173,183), c(132,126,135),
    -- DB32 row 4
    c(105,106,106), c(89,86,82),    c(118,66,138),  c(172,50,50),
    c(217,87,99),   c(215,123,186), c(143,151,74),  c(138,111,48),
    -- Pure primaries + grays
    c(255,0,0),     c(0,200,0),     c(0,0,255),     c(255,255,0),
    c(255,0,255),   c(0,255,255),   c(128,128,128), c(192,192,192),
    -- Darks, skin tones
    c(64,64,64),    c(32,32,32),    c(210,160,120), c(170,120,80),
    c(130,85,55),   c(90,55,35),    c(30,60,90),    c(60,30,30),
}

---------------------------------------------------------------------------
-- HSV <-> RGB conversion
---------------------------------------------------------------------------

function Palette.hsv2rgb(h, s, v)
    if s <= 0 then return v, v, v end
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

function Palette.rgb2hsv(r, g, b)
    local mx = math.max(r, g, b)
    local mn = math.min(r, g, b)
    local d = mx - mn
    local v = mx
    local s = mx == 0 and 0 or d / mx
    local h = 0
    if d > 0 then
        if mx == r then
            h = (g - b) / d
            if h < 0 then h = h + 6 end
        elseif mx == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h, s, v
end

---------------------------------------------------------------------------
-- Color ramp generation (linear interpolation with optional hue shift)
---------------------------------------------------------------------------

function Palette.generateRamp(c1, c2, steps)
    local ramp = {}
    for i = 0, steps - 1 do
        local t = steps <= 1 and 0 or i / (steps - 1)
        ramp[#ramp + 1] = {
            c1[1] + (c2[1] - c1[1]) * t,
            c1[2] + (c2[2] - c1[2]) * t,
            c1[3] + (c2[3] - c1[3]) * t,
            c1[4] + (c2[4] - c1[4]) * t,
        }
    end
    return ramp
end

return Palette
