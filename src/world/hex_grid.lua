-- hex_grid.lua — Hex math utilities and procedural hex grid generation
-- Flat-top hexagonal grid using axial coordinates (q, r).
-- Radius-3 grid = 37 hexes. Each hex has biome, resources, threat, elevation.

local HexGrid = {}

local SQRT3 = math.sqrt(3)

---------------------------------------------------------------------------
-- Axial coordinate utilities
---------------------------------------------------------------------------

function HexGrid.hexKey(q, r)
    return q .. ',' .. r
end

--- Flat-top hex: axial to pixel center
function HexGrid.hexToPixel(q, r, size)
    local x = size * (3 / 2 * q)
    local y = size * (SQRT3 / 2 * q + SQRT3 * r)
    return x, y
end

--- Flat-top hex: pixel to fractional axial, then round
function HexGrid.pixelToHex(px, py, size)
    local q = (2 / 3 * px) / size
    local r = (-1 / 3 * px + SQRT3 / 3 * py) / size
    return HexGrid.axialRound(q, r)
end

--- Round fractional axial to nearest hex (cube rounding)
function HexGrid.axialRound(qf, rf)
    local sf = -qf - rf
    local qi = math.floor(qf + 0.5)
    local ri = math.floor(rf + 0.5)
    local si = math.floor(sf + 0.5)

    local dq = math.abs(qi - qf)
    local dr = math.abs(ri - rf)
    local ds = math.abs(si - sf)

    if dq > dr and dq > ds then
        qi = -ri - si
    elseif dr > ds then
        ri = -qi - si
    end
    return qi, ri
end

--- 6 neighbor offsets for axial coords
local NEIGHBORS = {
    { 1,  0}, { 1, -1}, { 0, -1},
    {-1,  0}, {-1,  1}, { 0,  1},
}

function HexGrid.getNeighbors(q, r)
    local out = {}
    for i = 1, 6 do
        out[i] = { q + NEIGHBORS[i][1], r + NEIGHBORS[i][2] }
    end
    return out
end

--- Returns 6 corner vertices for a flat-top hex polygon
function HexGrid.hexCorners(cx, cy, size)
    local corners = {}
    for i = 0, 5 do
        local angle = math.pi / 180 * (60 * i)
        corners[#corners + 1] = cx + size * math.cos(angle)
        corners[#corners + 1] = cy + size * math.sin(angle)
    end
    return corners
end

--- Distance between two hexes in axial coords
function HexGrid.hexDistance(q1, r1, q2, r2)
    return (math.abs(q1 - q2) + math.abs(q1 + r1 - q2 - r2) + math.abs(r1 - r2)) / 2
end

---------------------------------------------------------------------------
-- Procedural hex grid generation
---------------------------------------------------------------------------

--- Generate a radius-3 hex grid for a planet.
--- Returns { radius, seed, planetId, hexes = { [key] = hexData } }
function HexGrid.generate(planetId, seed)
    local radius = 3
    seed = seed or 0

    -- Load planet biome palette
    local biomes, biomeProps
    local pok, PlanetDefs = pcall(require, 'src.world.planet_defs')
    if pok then
        local pdef = PlanetDefs.get(planetId)
        if pdef and pdef.worldMap then
            biomes = pdef.worldMap.biomes
            biomeProps = pdef.worldMap.biomeProperties
        end
    end

    -- Fallback biomes if planet has no worldMap defined
    if not biomes then
        biomes = {
            { id = 'default', name = 'Standard', color = {0.6, 0.65, 0.7}, weight = 1.0 },
        }
    end
    if not biomeProps then
        biomeProps = {
            default = { tempMod = 0, resourceBias = 'normal', threatBias = 'medium' },
        }
    end

    -- Compute cumulative weights for biome selection
    local totalWeight = 0
    for _, b in ipairs(biomes) do totalWeight = totalWeight + b.weight end

    local hexes = {}

    for q = -radius, radius do
        local r1 = math.max(-radius, -q - radius)
        local r2 = math.min(radius, -q + radius)
        for r = r1, r2 do
            -- Noise sampling for this hex
            local nq = q * 0.45 + seed * 0.01
            local nr = r * 0.45 + seed * 0.01 + 50

            local biomeNoise = love.math.noise(nq + seed, nr + seed)
            local elevNoise  = love.math.noise(nq + seed + 100, nr + seed + 100)
            local resNoise   = love.math.noise(nq + seed + 200, nr + seed + 200)
            local threatNoise = love.math.noise(nq + seed + 300, nr + seed + 300)

            -- Pick biome from weighted palette
            local roll = biomeNoise * totalWeight
            local acc = 0
            local biome = biomes[1]
            for _, b in ipairs(biomes) do
                acc = acc + b.weight
                if roll <= acc then biome = b; break end
            end

            -- Elevation 0-1
            local elevation = elevNoise

            -- Resource richness
            local resVal = resNoise + elevation * 0.2
            local resources = 'normal'
            if resVal < 0.35 then resources = 'sparse'
            elseif resVal > 0.7 then resources = 'rich' end

            -- Threat level (edges higher)
            local dist = HexGrid.hexDistance(q, r, 0, 0)
            local threatVal = threatNoise * 0.6 + (dist / radius) * 0.4
            local threat = 'medium'
            if threatVal < 0.3 then threat = 'low'
            elseif threatVal > 0.7 then threat = 'high'
            elseif threatVal > 0.85 then threat = 'extreme' end

            -- Temperature modifier from biome properties
            local props = biomeProps[biome.id] or {}
            local tempMod = props.tempMod or 0

            -- Override resource/threat from biome bias if defined
            if props.resourceBias and resources == 'normal' then
                resources = props.resourceBias
            end

            local key = HexGrid.hexKey(q, r)
            hexes[key] = {
                q = q,
                r = r,
                biome = biome.id,
                biomeName = biome.name,
                biomeColor = biome.color,
                tempMod = tempMod,
                resources = resources,
                threat = threat,
                elevation = elevation,
            }
        end
    end

    return {
        radius = radius,
        seed = seed,
        planetId = planetId,
        hexes = hexes,
    }
end

return HexGrid
