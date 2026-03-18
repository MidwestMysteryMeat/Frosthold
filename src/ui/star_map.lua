-- star_map.lua — Full-screen galaxy map panel
-- Shows discovered planets, stars, POIs, and player ship position.
-- Toggle with M key. Click on planet/POI to set autopilot destination.

local GameState = require('src.game_state')

local ok_ecs, ECS           = pcall(require, 'src.ecs.ecs')
local ok_poi, POIGenerator  = pcall(require, 'src.space.poi_generator')
local ok_cel, CelestialBodies = pcall(require, 'src.space.celestial_bodies')
local ok_pd,  PlanetDefs    = pcall(require, 'src.world.planet_defs')
local ok_sm,  ShipMovement  = pcall(require, 'src.space.ship_movement')

local StarMap = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local visible = false
local hitZones = {}       -- { {x, y, w, h, type, id, worldX, worldY}, ... }
local blinkTimer = 0

---------------------------------------------------------------------------
-- Coordinate mapping
---------------------------------------------------------------------------

-- Tilemap coord ranges (from PLANET_POSITIONS)
local WORLD_MIN_X, WORLD_MAX_X = -1100, 1400
local WORLD_MIN_Y, WORLD_MAX_Y = -1300, 1100

local function worldToScreen(wx, wy)
    local sw, sh = love.graphics.getDimensions()
    local margin = 60
    local drawW = sw - margin * 2
    local drawH = sh - margin * 2
    local rangeX = WORLD_MAX_X - WORLD_MIN_X
    local rangeY = WORLD_MAX_Y - WORLD_MIN_Y
    local scale = math.min(drawW / rangeX, drawH / rangeY)
    local ox = margin + (drawW - rangeX * scale) / 2
    local oy = margin + (drawH - rangeY * scale) / 2
    local sx = ox + (wx - WORLD_MIN_X) * scale
    local sy = oy + (wy - WORLD_MIN_Y) * scale
    return sx, sy, scale
end

---------------------------------------------------------------------------
-- Star field background (deterministic)
---------------------------------------------------------------------------

local bgStars = nil

local function generateBackgroundStars()
    if bgStars then return end
    bgStars = {}
    local rng = love.math.newRandomGenerator(42)
    for _ = 1, 200 do
        bgStars[#bgStars + 1] = {
            x = rng:random(),
            y = rng:random(),
            b = 0.3 + rng:random() * 0.5,
            s = rng:random() < 0.15 and 2 or 1,
        }
    end
end

---------------------------------------------------------------------------
-- POI color by faction / type
---------------------------------------------------------------------------

local function poiColor(poi)
    local t = poi.type or ''
    local f = poi.faction or ''
    if f == 'utc' or t:find('utc') then return 0.3, 0.5, 1.0 end
    if f == 'black_maw' or f == 'void_serpents' or f == 'rust_reavers' or t:find('pirate') then return 0.9, 0.2, 0.2 end
    if f == 'mammona' or t:find('starbyte') or t:find('fortune') or t:find('corporate') then return 0.2, 0.8, 0.3 end
    if t:find('derelict') or t:find('wreck') or t:find('salvage') then return 0.5, 0.5, 0.5 end
    return 0.6, 0.6, 0.6
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function StarMap.draw()
    if not visible then return end

    generateBackgroundStars()

    local sw, sh = love.graphics.getDimensions()
    hitZones = {}

    -- Dark background
    love.graphics.setColor(0.02, 0.02, 0.06, 0.95)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Background star field
    for _, s in ipairs(bgStars) do
        love.graphics.setColor(s.b, s.b, s.b * 1.1, 0.8)
        love.graphics.rectangle('fill', s.x * sw, s.y * sh, s.s, s.s)
    end

    -- Title
    love.graphics.setColor(0.9, 0.9, 0.95)
    local title = 'STAR MAP'
    local font = love.graphics.getFont()
    love.graphics.print(title, sw / 2 - font:getWidth(title) / 2, 16)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.print('Click destination to set autopilot  |  M / Escape to close', sw / 2 - font:getWidth('Click destination to set autopilot  |  M / Escape to close') / 2, 34)

    -- Star systems (yellow/orange dots)
    if ok_cel then
        local systems = CelestialBodies.getStarSystems()
        if systems then
            for _, sys in pairs(systems) do
                if sys.star then
                    local sx2, sy2 = worldToScreen(sys.star.x, sys.star.y)
                    local r = math.max(3, (sys.star.size or 2))
                    love.graphics.setColor(1.0, 0.85, 0.3, 0.9)
                    love.graphics.circle('fill', sx2, sy2, r)
                    love.graphics.setColor(1.0, 0.95, 0.6, 0.4)
                    love.graphics.circle('fill', sx2, sy2, r + 2)
                end
                if sys.twinStar then
                    local sx2, sy2 = worldToScreen(sys.twinStar.x, sys.twinStar.y)
                    local r = math.max(2, (sys.twinStar.size or 2))
                    love.graphics.setColor(1.0, 0.7, 0.2, 0.9)
                    love.graphics.circle('fill', sx2, sy2, r)
                end
            end
        end
    end

    -- Planets
    if ok_poi then
        local positions = POIGenerator.getAllPlanetPositions()
        if positions then
            for planetId, pos in pairs(positions) do
                local sx2, sy2, sc = worldToScreen(pos.x, pos.y)
                local discovered = GameState.discoveredPlanets and GameState.discoveredPlanets[planetId]
                local radius = 8

                if discovered then
                    local def = ok_pd and PlanetDefs.get(planetId)
                    local col = def and def.color or { 0.6, 0.6, 0.6 }
                    love.graphics.setColor(col[1], col[2], col[3], 0.9)
                    love.graphics.circle('fill', sx2, sy2, radius)
                    love.graphics.setColor(col[1] * 0.7, col[2] * 0.7, col[3] * 0.7)
                    love.graphics.circle('line', sx2, sy2, radius)

                    -- Label
                    local label = def and def.name or planetId
                    love.graphics.setColor(0.85, 0.85, 0.9)
                    love.graphics.print(label, sx2 - font:getWidth(label) / 2, sy2 + radius + 3)
                else
                    -- Undiscovered: dim circle with ?
                    love.graphics.setColor(0.3, 0.3, 0.35, 0.6)
                    love.graphics.circle('fill', sx2, sy2, radius)
                    love.graphics.setColor(0.4, 0.4, 0.45)
                    love.graphics.circle('line', sx2, sy2, radius)
                    love.graphics.setColor(0.5, 0.5, 0.55)
                    love.graphics.print('?', sx2 - font:getWidth('?') / 2, sy2 - font:getHeight() / 2)
                end

                -- Hit zone for clicking
                hitZones[#hitZones + 1] = {
                    x = sx2 - radius, y = sy2 - radius,
                    w = radius * 2, h = radius * 2,
                    type = 'planet', id = planetId,
                    worldX = pos.x, worldY = pos.y,
                }
            end
        end
    end

    -- POI markers (discovered only)
    local pois = GameState.discoveredPOIs
    if pois then
        for poiId, poi in pairs(pois) do
            if poi.x and poi.y then
                local sx2, sy2 = worldToScreen(poi.x, poi.y)
                local cr, cg, cb = poiColor(poi)
                local radius = 4
                love.graphics.setColor(cr, cg, cb, 0.85)
                love.graphics.circle('fill', sx2, sy2, radius)
                -- Tiny label on hover (always show name if present)
                if poi.name then
                    love.graphics.setColor(cr, cg, cb, 0.6)
                    love.graphics.print(poi.name, sx2 + radius + 2, sy2 - font:getHeight() / 2)
                end

                hitZones[#hitZones + 1] = {
                    x = sx2 - radius, y = sy2 - radius,
                    w = radius * 2, h = radius * 2,
                    type = 'poi', id = poiId,
                    worldX = poi.x, worldY = poi.y,
                }
            end
        end
    end

    -- Player ship (white blinking dot)
    blinkTimer = blinkTimer + love.timer.getDelta()
    if ok_ecs then
        for id, comps in ECS.query('ship', 'pos') do
            if not ECS.has(id, 'npc_ship') then
                local sx2, sy2 = worldToScreen(comps.pos.x, comps.pos.y)
                local alpha = 0.5 + 0.5 * math.abs(math.sin(blinkTimer * 3))
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.circle('fill', sx2, sy2, 5)
                love.graphics.setColor(1, 1, 1, alpha * 0.5)
                love.graphics.circle('line', sx2, sy2, 8)
                love.graphics.setColor(0.9, 0.9, 0.95, alpha)
                love.graphics.print('SHIP', sx2 + 10, sy2 - font:getHeight() / 2)
                break  -- only the player ship
            end
        end
    end

    -- Legend
    local lx, ly = 20, sh - 90
    love.graphics.setColor(0.6, 0.6, 0.65)
    love.graphics.print('Legend:', lx, ly)
    ly = ly + 16
    love.graphics.setColor(0.3, 0.5, 1.0)
    love.graphics.circle('fill', lx + 5, ly + 6, 3)
    love.graphics.setColor(0.7, 0.7, 0.75)
    love.graphics.print('UTC Outpost', lx + 14, ly)
    ly = ly + 14
    love.graphics.setColor(0.9, 0.2, 0.2)
    love.graphics.circle('fill', lx + 5, ly + 6, 3)
    love.graphics.setColor(0.7, 0.7, 0.75)
    love.graphics.print('Pirate', lx + 14, ly)
    ly = ly + 14
    love.graphics.setColor(0.2, 0.8, 0.3)
    love.graphics.circle('fill', lx + 5, ly + 6, 3)
    love.graphics.setColor(0.7, 0.7, 0.75)
    love.graphics.print('Corporate', lx + 14, ly)
    ly = ly + 14
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.circle('fill', lx + 5, ly + 6, 3)
    love.graphics.setColor(0.7, 0.7, 0.75)
    love.graphics.print('Derelict', lx + 14, ly)

    love.graphics.setColor(1, 1, 1)
end

---------------------------------------------------------------------------
-- Toggle / visibility
---------------------------------------------------------------------------

function StarMap.toggle()
    visible = not visible
    hitZones = {}
end

function StarMap.isVisible()
    return visible
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function StarMap.keypressed(key)
    if not visible then return false end
    if key == 'm' or key == 'escape' then
        visible = false
        hitZones = {}
        return true
    end
    return true  -- consume all keys while open
end

function StarMap.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end

    -- Check hit zones
    for _, zone in ipairs(hitZones) do
        if x >= zone.x and x <= zone.x + zone.w
           and y >= zone.y and y <= zone.y + zone.h then
            -- Set autopilot to this destination
            if ok_sm and ShipMovement.setAutopilot then
                ShipMovement.setAutopilot(zone.worldX, zone.worldY)
            end
            visible = false
            hitZones = {}
            return true
        end
    end

    return true  -- consume click even if nothing hit
end

return StarMap
