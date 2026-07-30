-- renderer.lua — World and entity rendering
-- Draws visible tiles with thermal overlay, entities, selection boxes.

local Tiles     = require('src.world.tiles')
local GameState = require('src.game_state')
local Creatures = require('src.creatures.creatures')
local ECS       = require('src.ecs.ecs')

local ok_sprites, Sprites = pcall(require, 'src.render.sprites')
if not ok_sprites then Sprites = nil end

-- Lazy-loaded optional modules (cached to avoid pcall in render loops)
local _Vis, _TileSnow, _Lighting, _Pollution, _Power, _Atmosphere
local _Conveyors, _Containment, _Structural, _TileGas, _Rooms, _Thermal
local _Ordnance, _Fire, _Jobs, _Terraform, _Zones, _Camera, _WorldMap, _Building
local _renderModsLoaded = false
local function lazyLoadRenderMods()
    if _renderModsLoaded then return end
    _renderModsLoaded = true
    local ok
    ok, _Vis = pcall(require, 'src.sim.visibility')
    if not ok then _Vis = false end
    ok, _TileSnow = pcall(require, 'src.sim.tile_snow')
    if not ok then _TileSnow = false end
    ok, _Lighting = pcall(require, 'src.sim.lighting')
    if not ok then _Lighting = false end
    ok, _Pollution = pcall(require, 'src.sim.pollution')
    if not ok then _Pollution = false end
    ok, _Power = pcall(require, 'src.sim.power')
    if not ok then _Power = false end
    ok, _Atmosphere = pcall(require, 'src.sim.atmosphere')
    if not ok then _Atmosphere = false end
    ok, _Conveyors = pcall(require, 'src.logistics.conveyors')
    if not ok then _Conveyors = false end
    ok, _Containment = pcall(require, 'src.sim.containment')
    if not ok then _Containment = false end
    ok, _Structural = pcall(require, 'src.world.structural')
    if not ok then _Structural = false end
    ok, _TileGas = pcall(require, 'src.sim.tile_gas')
    if not ok then _TileGas = false end
    ok, _Rooms = pcall(require, 'src.world.rooms')
    if not ok then _Rooms = false end
    ok, _Thermal = pcall(require, 'src.sim.thermal')
    if not ok then _Thermal = false end
    ok, _Ordnance = pcall(require, 'src.combat.ordnance')
    if not ok then _Ordnance = false end
    ok, _Fire = pcall(require, 'src.sim.fire')
    if not ok then _Fire = false end
    ok, _Jobs = pcall(require, 'src.colonist.jobs')
    if not ok then _Jobs = false end
    ok, _Terraform = pcall(require, 'src.world.terraform')
    if not ok then _Terraform = false end
    ok, _Zones = pcall(require, 'src.world.zones')
    if not ok then _Zones = false end
    ok, _Camera = pcall(require, 'src.render.camera')
    if not ok then _Camera = false end
    ok, _WorldMap = pcall(require, 'src.world.tilemap')
    if not ok then _WorldMap = false end
    ok, _Building = pcall(require, 'src.building.building')
    if not ok then _Building = false end
end

local Renderer = {}

local thermalOverlay   = false  -- toggle with F2
local pollutionOverlay = false  -- toggle with F3
local powerOverlay     = false  -- toggle with F4
local atmosphereOverlay = false -- toggle with F6
local logisticsOverlay  = false -- toggle with F7
local containmentOverlay = false -- toggle with F8
local structuralOverlay  = false -- toggle with F10

function Renderer.init()
    thermalOverlay = false
    pollutionOverlay = false
    powerOverlay = false
    atmosphereOverlay = false
    logisticsOverlay = false
    containmentOverlay = false
    structuralOverlay = false
    lazyLoadRenderMods()
    -- Preload tile sprites to avoid hitches on first render
    if Sprites then Sprites.preloadTiles() end
end

function Renderer.toggleThermalOverlay()
    thermalOverlay = not thermalOverlay
end

function Renderer.isThermalOverlay()
    return thermalOverlay
end

function Renderer.togglePollutionOverlay()
    pollutionOverlay = not pollutionOverlay
end

function Renderer.isPollutionOverlay()
    return pollutionOverlay
end

function Renderer.togglePowerOverlay()
    powerOverlay = not powerOverlay
end

function Renderer.isPowerOverlay()
    return powerOverlay
end

function Renderer.toggleAtmosphereOverlay()
    atmosphereOverlay = not atmosphereOverlay
end

function Renderer.isAtmosphereOverlay()
    return atmosphereOverlay
end

function Renderer.toggleLogisticsOverlay()
    logisticsOverlay = not logisticsOverlay
end

function Renderer.isLogisticsOverlay()
    return logisticsOverlay
end

function Renderer.toggleContainmentOverlay()
    containmentOverlay = not containmentOverlay
end

function Renderer.isContainmentOverlay()
    return containmentOverlay
end

function Renderer.toggleStructuralOverlay()
    structuralOverlay = not structuralOverlay
end

function Renderer.isStructuralOverlay()
    return structuralOverlay
end

---------------------------------------------------------------------------
-- World drawing
---------------------------------------------------------------------------

function Renderer.drawWorld(world, state)
    local ts = world.tileSize()
    local sw, sh = love.graphics.getDimensions()
    local camX, camY = state.camX, state.camY
    local camZoom = state.camZoom
    local viewDepth = GameState.viewDepth or 0

    -- Fog of war module (optional)
    lazyLoadRenderMods()
    local fogActive = GameState.fogOfWar
    local Vis = _Vis or nil
    if fogActive and not Vis then fogActive = false end

    local x1, y1, x2, y2 = world.getVisibleRange(camX, camY, sw, sh, camZoom)

    -- Underground tint: darken underground layers to distinguish from surface
    local undergroundTint = viewDepth > 0

    for y = y1, y2 do
        for x = x1, x2 do
            -- Fog of war: unexplored tiles are dark (soft blue-grey, not pitch black)
            if fogActive and not Vis.isExplored(x, y) then
                love.graphics.setColor(0.05, 0.06, 0.09)
                love.graphics.rectangle('fill', x * ts, y * ts, ts, ts)
                goto nextTile
            end

            local tile = world.getTile(x, y, viewDepth)
            local props = Tiles.get(tile)
            local px, py = x * ts, y * ts

            if thermalOverlay then
                -- Thermal view: blue (cold) to red (hot), no sprites
                local temp = world.getTemp(x, y, viewDepth)
                local t = (temp + 60) / 120
                t = math.max(0, math.min(1, t))
                love.graphics.setColor(t, 0.1, 1 - t)
                love.graphics.rectangle('fill', px, py, ts, ts)
            else
                -- Temperature tint helper
                local r, g, b = 1, 1, 1
                if undergroundTint then r, g, b = 0.75, 0.75, 0.82 end
                local temp = world.getTemp(x, y, viewDepth)
                if temp > 0 then
                    local warmth = math.min(1, temp / 40) * 0.15
                    r = math.min(1, 1 + warmth)
                    g = math.min(1, 1 + warmth * 0.3)
                elseif temp < -50 then
                    local cold = math.min(1, (-temp - 50) / 30) * 0.1
                    b = math.min(1, 1 + cold)
                end

                -- Trees: draw snow ground first, then tree sprite on top
                if tile == Tiles.TREE then
                    -- Ground layer (snow)
                    local snowSprite = Sprites and Sprites.getTile(Tiles.SNOW, x, y)
                    if snowSprite then
                        love.graphics.setColor(r, g, b)
                        local ssw = snowSprite:getWidth()
                        local ssh = snowSprite:getHeight()
                        love.graphics.draw(snowSprite, px, py, 0, ts / ssw, ts / ssh)
                    else
                        local sp = Tiles.get(Tiles.SNOW)
                        love.graphics.setColor(sp.color[1], sp.color[2], sp.color[3])
                        love.graphics.rectangle('fill', px, py, ts, ts)
                    end
                    -- Tree overlay (slightly larger, anchored at bottom)
                    local treeSprite = Sprites and Sprites.getTile(tile, x, y)
                    if treeSprite then
                        love.graphics.setColor(r, g, b)
                        local tsw = treeSprite:getWidth()
                        local tsh = treeSprite:getHeight()
                        local treeScale = 1.1
                        local drawW = ts * treeScale
                        local drawH = ts * treeScale
                        local ox = (ts - drawW) / 2
                        local oy = ts - drawH  -- anchor bottom
                        love.graphics.draw(treeSprite, px + ox, py + oy, 0,
                            drawW / tsw, drawH / tsh)
                    end
                    goto tileDrawn
                end

                -- Try sprite first
                local tileSprite = Sprites and Sprites.getTile(tile, x, y)
                if tileSprite then
                    love.graphics.setColor(r, g, b)
                    local sw = tileSprite:getWidth()
                    local sh = tileSprite:getHeight()
                    love.graphics.draw(tileSprite, px, py, 0, ts / sw, ts / sh)
                else
                    -- Fallback: colored rectangle
                    local r, g, b = props.color[1], props.color[2], props.color[3]
                    if undergroundTint then r = r * 0.75; g = g * 0.75; b = b * 0.82 end
                    local temp = world.getTemp(x, y, viewDepth)
                    if temp > 0 then
                        local warmth = math.min(1, temp / 40) * 0.15
                        r = math.min(1, r + warmth)
                        g = math.min(1, g + warmth * 0.3)
                    elseif temp < -50 then
                        local cold = math.min(1, (-temp - 50) / 30) * 0.1
                        b = math.min(1, b + cold)
                    end
                    love.graphics.setColor(r, g, b)
                    love.graphics.rectangle('fill', px, py, ts, ts)
                end
            end

            ::tileDrawn::

            -- Tile borders (subtle grid)
            love.graphics.setColor(0, 0, 0, 0.08)
            love.graphics.rectangle('line', px, py, ts, ts)

            -- Special tile effects (layered on top of sprites)
            if tile == Tiles.LAVA_VENT then
                local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 3 + x * 0.5 + y * 0.7)
                love.graphics.setColor(1, 0.4, 0.1, pulse * 0.4)
                love.graphics.rectangle('fill', px + 2, py + 2, ts - 4, ts - 4)
            end

            -- Fog of war: explored but not visible = gently dimmed
            if fogActive and not Vis.isVisible(x, y) then
                love.graphics.setColor(0, 0, 0.02, 0.28)
                love.graphics.rectangle('fill', px, py, ts, ts)
            end

            ::nextTile::
        end
    end

    -- Snow depth overlay (surface only, subtle white overlay proportional to depth)
    if viewDepth == 0 and not thermalOverlay then
        if _TileSnow and _TileSnow.getSnowAt then
            for y = y1, y2 do
                for x = x1, x2 do
                    local sd = _TileSnow.getSnowAt(x, y, 0)
                    if sd and sd >= 3 then
                        local a = (sd - 2) / 7 * 0.35
                        love.graphics.setColor(0.9, 0.92, 1.0, a)
                        love.graphics.rectangle('fill', x * ts, y * ts, ts, ts)
                    end
                end
            end
        end
    end

    -- Lighting darkness overlay (darken unlit indoor tiles) — only on surface
    if not thermalOverlay and viewDepth == 0 then
        if _Lighting then
            for y = y1, y2 do
                for x = x1, x2 do
                    local light = _Lighting.getLightAt(x, y)
                    if light < 0.9 then
                        local dark = (1 - light) * 0.35
                        love.graphics.setColor(0, 0, 0.03, dark)
                        love.graphics.rectangle('fill', x * ts, y * ts, ts, ts)
                    end
                end
            end
        end
    end

    -- Pollution overlay (toggle with F3) — only on surface
    if pollutionOverlay and viewDepth == 0 then
        if _Pollution and _Pollution.get then
            for y = y1, y2 do
                for x = x1, x2 do
                    local p = _Pollution.get(x, y)
                    if p and p > 0.01 then
                        local a = math.min(0.6, p * 0.3)
                        love.graphics.setColor(0.4, 0.3, 0.1, a)
                        love.graphics.rectangle('fill', x * ts, y * ts, ts, ts)
                    end
                end
            end
        end
    end

    -- Power overlay (toggle with F4) — only show on surface layer
    if powerOverlay and viewDepth == 0 then
        if _Power then
            -- Generators: bright green
            local gens = _Power.getGenerators()
            if gens then
                for _, gen in pairs(gens) do
                    if gen.x >= x1 and gen.x <= x2 and gen.y >= y1 and gen.y <= y2 then
                        love.graphics.setColor(0.1, 0.9, 0.2, 0.45)
                        love.graphics.rectangle('fill', gen.x * ts, gen.y * ts, ts, ts)
                    end
                end
            end
            -- Batteries: cyan
            local bats = _Power.getBatteries()
            if bats then
                for _, bat in pairs(bats) do
                    if bat.x >= x1 and bat.x <= x2 and bat.y >= y1 and bat.y <= y2 then
                        local pct = bat.stored and bat.capacity and bat.capacity > 0
                            and (bat.stored / bat.capacity) or 0
                        love.graphics.setColor(0.1, 0.5 + pct * 0.5, 0.9, 0.45)
                        love.graphics.rectangle('fill', bat.x * ts, bat.y * ts, ts, ts)
                    end
                end
            end
            -- Grid status labels at generators
            local gridStats = _Power.getGridStats()
            if gridStats and gens then
                love.graphics.setColor(1, 1, 1, 0.9)
                local font = love.graphics.getFont()
                for _, gen in pairs(gens) do
                    if gen.x >= x1 and gen.x <= x2 and gen.y >= y1 and gen.y <= y2 then
                        local root = _Power.getGridRoot and _Power.getGridRoot(gen.x, gen.y)
                        if root and gridStats[root] then
                            local gs = gridStats[root]
                            local label = string.format('%dW/%dW', gs.supply or 0, gs.demand or 0)
                            love.graphics.setColor(gs.supply >= gs.demand and {0.2,1,0.3,0.9} or {1,0.3,0.2,0.9})
                            love.graphics.print(label, gen.x * ts, gen.y * ts - 10)
                        end
                    end
                end
            end
        end
    end

    if atmosphereOverlay then
        if _Atmosphere and _Atmosphere.getTileO2 and _Atmosphere.getTileCO2 then
            for y = y1, y2 do
                for x = x1, x2 do
                    local o2 = _Atmosphere.getTileO2(x, y, viewDepth)
                    local co2 = _Atmosphere.getTileCO2(x, y, viewDepth)
                    local danger = math.max(0, (90 - o2) / 90, co2 / 35)
                    if danger > 0.01 or viewDepth > 0 then
                        local blue = math.max(0, (o2 - 60) / 40)
                        local red = math.min(1, math.max(0, (70 - o2) / 60) + co2 / 50)
                        love.graphics.setColor(red, 0.15 + blue * 0.25, 0.8 * blue, 0.12 + math.min(0.35, danger * 0.4))
                        love.graphics.rectangle('fill', x * ts, y * ts, ts, ts)
                    end
                end
            end
        end
    end

    if logisticsOverlay then
        if _Conveyors and _Conveyors.getAllBelts then
            for k, belt in pairs(_Conveyors.getAllBelts()) do
                local bx = k % 10000
                local by = math.floor(k / 10000)
                if bx >= x1 and bx <= x2 and by >= y1 and by <= y2 then
                    love.graphics.setColor(0.22, 0.82, 1.0, 0.28)
                    love.graphics.rectangle('fill', bx * ts, by * ts, ts, ts)
                    if belt.item then
                        love.graphics.setColor(1.0, 0.92, 0.38, 0.75)
                        love.graphics.circle('fill', bx * ts + ts / 2, by * ts + ts / 2, 4)
                    end
                end
            end
        end

        for _, comps in ECS.query('pipe_node', 'pos') do
            local pos = comps.pos
            if (pos.depth or 0) == viewDepth and pos.x >= x1 and pos.x <= x2 and pos.y >= y1 and pos.y <= y2 then
                love.graphics.setColor(0.2, 0.95, 0.55, 0.24)
                love.graphics.rectangle('fill', pos.x * ts, pos.y * ts, ts, ts)
            end
        end

        for _, comps in ECS.query('inserter', 'pos') do
            local pos = comps.pos
            if (pos.depth or 0) == viewDepth and pos.x >= x1 and pos.x <= x2 and pos.y >= y1 and pos.y <= y2 then
                love.graphics.setColor(0.95, 0.8, 0.2, 0.3)
                love.graphics.rectangle('line', pos.x * ts + 2, pos.y * ts + 2, ts - 4, ts - 4)
            end
        end
    end

    if containmentOverlay then
        if _Containment and _Containment.getCellSnapshot then
            for id, comps in ECS.query('containment_cell', 'pos') do
                local pos = comps.pos
                if (pos.depth or 0) == viewDepth and pos.x >= x1 and pos.x <= x2 and pos.y >= y1 and pos.y <= y2 then
                    local snap = _Containment.getCellSnapshot(id)
                    local risk = snap and snap.risk or 0
                    local alpha = 0.12 + math.min(0.35, risk / 200)
                    local r = risk >= 70 and 0.95 or (risk >= 40 and 0.95 or 0.25)
                    local g = risk >= 70 and 0.2 or (risk >= 40 and 0.65 or 0.85)
                    local b = risk >= 70 and 0.18 or (risk >= 40 and 0.22 or 0.35)
                    love.graphics.setColor(r, g, b, alpha)
                    love.graphics.rectangle('fill', pos.x * ts, pos.y * ts, ts, ts)
                    love.graphics.setColor(r, g, b, math.min(1, alpha + 0.25))
                    love.graphics.rectangle('line', pos.x * ts + 1, pos.y * ts + 1, ts - 2, ts - 2)
                end
            end
        end
    end

    if structuralOverlay and viewDepth > 0 then
        if _Structural and _Structural.getStability then
            for y = y1, y2 do
                for x = x1, x2 do
                    local stability = _Structural.getStability(x, y, viewDepth)
                    if stability < 0.999 then
                        love.graphics.setColor(1 - stability, 0.25 + stability * 0.4, 0.15, 0.1 + (1 - stability) * 0.28)
                        love.graphics.rectangle('fill', x * ts, y * ts, ts, ts)
                    end
                end
            end
        end
    end

    if atmosphereOverlay then
        if _TileGas and _TileGas.getGasAt then
            for y = y1, y2 do
                for x = x1, x2 do
                    local level, gType = _TileGas.getGasAt(x, y, viewDepth)
                    if level and level > 0 then
                        local alpha = 0.08 + (level / 7) * 0.42
                        local r, g, b = 0.55, 0.6, 0.65
                        if gType == _TileGas.TYPE_CO2 then
                            r, g, b = 0.45, 0.75, 0.2
                        elseif gType == _TileGas.TYPE_TOXIC then
                            r, g, b = 0.7, 0.85, 0.15
                        elseif gType == _TileGas.TYPE_SMOKE then
                            r, g, b = 0.55, 0.55, 0.62
                        elseif gType == _TileGas.TYPE_SPORE then
                            r, g, b = 0.5, 0.82, 0.4
                        end
                        love.graphics.setColor(r, g, b, alpha)
                        love.graphics.rectangle('fill', x * ts, y * ts, ts, ts)
                    end
                end
            end
        end
    end

    if logisticsOverlay then
        for y = y1, y2 do
            for x = x1, x2 do
                local level = world.getWater(x, y, viewDepth)
                if level and level > 0 then
                    local alpha = 0.08 + (level / 7) * 0.45
                    love.graphics.setColor(0.18, 0.48, 0.95, alpha)
                    love.graphics.rectangle('fill', x * ts, y * ts, ts, ts)
                end
            end
        end
    end

    if containmentOverlay then
        if _Rooms and _Thermal and _Rooms.getAllRoomInfo and _Thermal.getRooms then
            local roomInfo = _Rooms.getAllRoomInfo()
            local thermalRooms = _Thermal.getRooms()
            local mapW = world.width()
            for rid, room in pairs(thermalRooms) do
                if (room.depth or 0) == viewDepth then
                    local info = roomInfo[rid]
                    if info then
                        local q = math.max(0, math.min(20, info.quality or 0))
                        local t = q / 20
                        local r = 0.9 - t * 0.55
                        local g = 0.25 + t * 0.6
                        local b = 0.18 + t * 0.1
                        local sumX, sumY = 0, 0
                        for _, idx in ipairs(room.tiles or {}) do
                            local ty = math.floor((idx - 1) / mapW)
                            local tx = (idx - 1) % mapW
                            if tx >= x1 and tx <= x2 and ty >= y1 and ty <= y2 then
                                love.graphics.setColor(r, g, b, 0.14)
                                love.graphics.rectangle('fill', tx * ts, ty * ts, ts, ts)
                            end
                            sumX = sumX + tx
                            sumY = sumY + ty
                        end
                        if room.tiles and #room.tiles > 0 then
                            local cx = math.floor(sumX / #room.tiles)
                            local cy = math.floor(sumY / #room.tiles)
                            if cx >= x1 and cx <= x2 and cy >= y1 and cy <= y2 then
                                love.graphics.setColor(0.95, 0.95, 0.95, 0.9)
                                love.graphics.print(string.format('%s %.1f', info.typeName or 'Room', info.quality or 0),
                                    cx * ts, cy * ts)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Persistent ordnance hazard overlays
    if _Ordnance then
        local t = love.timer.getTime()

        local function drawZoneRect(zone, r, g, b, alpha, lineAlpha)
            if (zone.depth or 0) ~= viewDepth then return end
            if zone.x < x1 or zone.x > x2 or zone.y < y1 or zone.y > y2 then return end
            local zx, zy = zone.x * ts, zone.y * ts
            love.graphics.setColor(r, g, b, alpha)
            love.graphics.rectangle('fill', zx, zy, ts, ts)
            love.graphics.setColor(r, g, b, lineAlpha or math.min(1, alpha + 0.12))
            love.graphics.rectangle('line', zx + 1, zy + 1, ts - 2, ts - 2)
        end

        for _, zone in pairs(_Ordnance.getFoamZones()) do
            local pulse = 0.16 + 0.05 * math.sin(t * 5 + zone.x * 0.3 + zone.y * 0.2)
            drawZoneRect(zone, 0.65, 0.88, 1.0, pulse, pulse + 0.06)
        end

        for _, zone in pairs(_Ordnance.getNapalmZones()) do
            local pulse = 0.18 + 0.08 * math.sin(t * 7 + zone.x * 0.7 + zone.y * 0.5)
            drawZoneRect(zone, 0.95, 0.32, 0.05, pulse + (zone.intensity or 0.2) * 0.08, pulse + 0.08)
        end

        for _, zone in pairs(_Ordnance.getCloudZones()) do
            local pulse = 0.10 + 0.05 * math.sin(t * 4 + zone.x * 0.4 + zone.y * 0.6)
            if zone.kind == 'bio' then
                drawZoneRect(zone, 0.45, 0.78, 0.36, pulse, pulse + 0.05)
            else
                drawZoneRect(zone, 0.55, 0.82, 0.12, pulse, pulse + 0.04)
            end
        end

        for _, zone in pairs(_Ordnance.getFalloutZones()) do
            local pulse = 0.08 + 0.04 * math.sin(t * 3 + zone.x * 0.2 + zone.y * 0.3)
            drawZoneRect(zone, 0.72, 0.95, 0.22, pulse + (zone.doseRate or 0) * 0.2, pulse + 0.05)
        end
    end

    -- Fire rendering
    if _Fire then
        local fires = _Fire.getActiveFires()
        local t = love.timer.getTime()
        for _, fire in pairs(fires) do
            if (fire.depth or 0) == viewDepth and fire.x >= x1 and fire.x <= x2 and fire.y >= y1 and fire.y <= y2 then
                local fx, fy = fire.x * ts, fire.y * ts
                local flicker = 0.7 + 0.3 * math.sin(t * 8 + fire.x * 1.3 + fire.y * 0.7)
                -- Fire glow
                love.graphics.setColor(1, 0.3, 0.05, 0.5 * flicker)
                love.graphics.rectangle('fill', fx, fy, ts, ts)
                -- Fire core
                love.graphics.setColor(1, 0.6, 0.1, 0.8 * flicker)
                love.graphics.rectangle('fill', fx + 6, fy + 4, ts - 12, ts - 8)
                -- Bright center
                love.graphics.setColor(1, 0.9, 0.4, 0.6 * flicker)
                love.graphics.rectangle('fill', fx + 10, fy + 8, ts - 20, ts - 16)
            end
        end
    end

    -- Zone overlays (filtered by viewDepth)
    if _Zones and _Zones.getAll then
        for _, zone in pairs(_Zones.getAll()) do
            local zdef = _Zones.TYPES[zone.type]
            if zdef then
                local zc = zdef.color
                for _, t in ipairs(zone.tileList) do
                    if (t.depth or 0) == viewDepth and t.x >= x1 and t.x <= x2 and t.y >= y1 and t.y <= y2 then
                        love.graphics.setColor(zc[1], zc[2], zc[3], zc[4])
                        love.graphics.rectangle('fill', t.x * ts, t.y * ts, ts, ts)
                        love.graphics.setColor(zc[1], zc[2], zc[3], zc[4] + 0.15)
                        love.graphics.rectangle('line', t.x * ts, t.y * ts, ts, ts)
                    end
                end
            end
        end
    end

    -- Mine/build/terraform designation markers (filtered by viewDepth)
    if _Jobs and _Jobs.getAllTasks then
        for _, task in pairs(_Jobs.getAllTasks()) do
            local taskDepth = (task.data and task.data.depth) or 0
            if taskDepth ~= viewDepth then goto nextTask end
            if task.type == 'mine' and not task.complete then
                local taskX, taskY = task.x, task.y
                if taskX >= x1 and taskX <= x2 and taskY >= y1 and taskY <= y2 then
                    love.graphics.setColor(1, 0.8, 0.2, 0.3)
                    love.graphics.rectangle('fill', taskX * ts, taskY * ts, ts, ts)
                    if task.claimed and task.progress > 0 and task.def.duration > 0 then
                        local frac = task.progress / task.def.duration
                        love.graphics.setColor(0.2, 1, 0.3, 0.6)
                        love.graphics.rectangle('fill', taskX * ts + 2, (taskY + 1) * ts - 4, (ts - 4) * frac, 3)
                    end
                end
            elseif task.type == 'build' and not task.complete then
                local taskX, taskY = task.x, task.y
                if taskX >= x1 and taskX <= x2 and taskY >= y1 and taskY <= y2 then
                    love.graphics.setColor(0.2, 0.6, 1, 0.3)
                    love.graphics.rectangle('fill', taskX * ts, taskY * ts, ts, ts)
                    if task.claimed and task.progress > 0 and task.def.duration > 0 then
                        local frac = task.progress / task.def.duration
                        love.graphics.setColor(0.2, 1, 0.3, 0.6)
                        love.graphics.rectangle('fill', taskX * ts + 2, (taskY + 1) * ts - 4, (ts - 4) * frac, 3)
                    end
                end
            elseif task.type == 'terraform' and not task.complete then
                local taskX, taskY = task.x, task.y
                if taskX >= x1 and taskX <= x2 and taskY >= y1 and taskY <= y2 then
                    love.graphics.setColor(0.3, 0.7, 1, 0.3)
                    love.graphics.rectangle('fill', taskX * ts, taskY * ts, ts, ts)
                    if task.claimed and task.progress > 0 and task.data.duration and task.data.duration > 0 then
                        local frac = task.progress / task.data.duration
                        love.graphics.setColor(0.2, 1, 0.3, 0.6)
                        love.graphics.rectangle('fill', taskX * ts + 2, (taskY + 1) * ts - 4, (ts - 4) * frac, 3)
                    end
                end
            elseif task.type == 'forage' and not task.complete then
                local taskX, taskY = task.x, task.y
                if taskX >= x1 and taskX <= x2 and taskY >= y1 and taskY <= y2 then
                    love.graphics.setColor(0.2, 0.8, 0.2, 0.3)
                    love.graphics.rectangle('fill', taskX * ts, taskY * ts, ts, ts)
                end
            elseif task.type == 'deconstruct' and not task.complete then
                local taskX, taskY = task.x, task.y
                if taskX >= x1 and taskX <= x2 and taskY >= y1 and taskY <= y2 then
                    love.graphics.setColor(0.8, 0.2, 0.2, 0.3)
                    love.graphics.rectangle('fill', taskX * ts, taskY * ts, ts, ts)
                end
            end
            ::nextTask::
        end
    end

    -- Room labels (debug, shown in thermal view) — filter by depth
    if thermalOverlay then
        love.graphics.setColor(1, 1, 1, 0.6)
        local font = love.graphics.getFont()
        if _Thermal then for rid, room in pairs(_Thermal.getRooms()) do
            if #room.tiles > 0 and (room.depth or 0) == viewDepth then
                -- Find center of room
                local w = world.width()
                local sumX, sumY = 0, 0
                for _, idx in ipairs(room.tiles) do
                    local ty = math.floor((idx - 1) / w)
                    local tx = (idx - 1) % w
                    sumX = sumX + tx
                    sumY = sumY + ty
                end
                local cx = (sumX / #room.tiles) * ts
                local cy = (sumY / #room.tiles) * ts
                local label = string.format('R%d: %.0f°C', rid, room.avgTemp)
                love.graphics.print(label, cx - font:getWidth(label) / 2, cy)
            end
        end
    end end
end

---------------------------------------------------------------------------
-- Entity drawing
---------------------------------------------------------------------------

function Renderer.drawEntities(ecs, state)
    local ts = 32
    local viewDepth = GameState.viewDepth or 0
    lazyLoadRenderMods()

    -- Fog of war visibility check helper
    local fogActive = GameState.fogOfWar
    local Vis = _Vis or nil
    if fogActive and not Vis then fogActive = false end
    local function tileVisible(tx, ty)
        if not fogActive then return true end
        return Vis.isVisible(tx, ty)
    end
    local function tileExplored(tx, ty)
        if not fogActive then return true end
        return Vis.isExplored(tx, ty)
    end

    -- Draw beds
    local bedSprite = Sprites and Sprites.getBuilding('bed')
    for id, comps in ecs.query('pos', 'bed') do
        local bpos = comps.pos
        if (bpos.depth or 0) ~= viewDepth then goto nextBed end
        local bed = comps.bed
        local bx, by = bpos.x * ts, bpos.y * ts
        if bedSprite then
            if bed.occupied then
                love.graphics.setColor(0.7, 0.65, 0.6)
            else
                love.graphics.setColor(1, 1, 1)
            end
            local sw = bedSprite:getWidth()
            local sh = bedSprite:getHeight()
            love.graphics.draw(bedSprite, bx, by, 0, ts / sw, ts / sh)
        else
            if bed.occupied then
                love.graphics.setColor(0.4, 0.3, 0.2)
            else
                love.graphics.setColor(0.6, 0.45, 0.3)
            end
            love.graphics.rectangle('fill', bx + 3, by + 3, ts - 6, ts - 6)
            love.graphics.setColor(0.85, 0.85, 0.8)
            love.graphics.rectangle('fill', bx + 4, by + 4, 10, 8)
        end
        -- Owner indicator
        if bed.owner then
            love.graphics.setColor(0.2, 0.7, 1, 0.5)
            love.graphics.rectangle('line', bx + 1, by + 1, ts - 2, ts - 2)
        end
        ::nextBed::
    end

    -- Draw decorations
    for id, comps in ecs.query('pos', 'decoration') do
        local dpos = comps.pos
        if (dpos.depth or 0) ~= viewDepth then goto nextDecoration end
        local dec = comps.decoration
        local dx, dy = dpos.x * ts, dpos.y * ts
        local decSprite = Sprites and Sprites.getBuilding(dec.type)
        if decSprite then
            love.graphics.setColor(1, 1, 1)
            local sw = decSprite:getWidth()
            local sh = decSprite:getHeight()
            love.graphics.draw(decSprite, dx, dy, 0, ts / sw, ts / sh)
        elseif dec.type == 'memorial' then
            love.graphics.setColor(0.7, 0.7, 0.75)
            love.graphics.rectangle('fill', dx + 10, dy + 6, ts - 20, ts - 12)
            love.graphics.setColor(0.5, 0.5, 0.55)
            love.graphics.rectangle('line', dx + 10, dy + 6, ts - 20, ts - 12)
        elseif dec.type == 'trophy_mount' then
            love.graphics.setColor(0.8, 0.5, 0.2)
            love.graphics.circle('fill', dx + ts/2, dy + ts/2, 6)
        else
            love.graphics.setColor(0.6, 0.5, 0.4, 0.6)
            love.graphics.rectangle('fill', dx + 6, dy + 6, ts - 12, ts - 12)
        end
        ::nextDecoration::
    end

    -- Draw containment infrastructure
    for id, comps in ecs.query('pos', 'containment_cell') do
        local pos = comps.pos
        if (pos.depth or 0) ~= viewDepth then goto nextContainment end
        local cell = comps.containment_cell
        if not tileExplored(pos.x, pos.y) then goto nextContainment end
        local cx, cy = pos.x * ts, pos.y * ts
        if cell.cellType == 'locker' then
            love.graphics.setColor(0.28, 0.35, 0.42)
            love.graphics.rectangle('fill', cx + 4, cy + 4, ts - 8, ts - 8, 3)
            love.graphics.setColor(0.55, 0.75, 0.9)
            love.graphics.rectangle('line', cx + 4, cy + 4, ts - 8, ts - 8, 3)
        else
            love.graphics.setColor(0.18, 0.22, 0.3)
            love.graphics.rectangle('fill', cx + 3, cy + 3, ts - 6, ts - 6, 3)
            love.graphics.setColor(0.4, 0.75, 1.0)
            love.graphics.rectangle('line', cx + 3, cy + 3, ts - 6, ts - 6, 3)
            love.graphics.setColor(0.7, 0.9, 1.0, 0.5)
            love.graphics.line(cx + ts / 2, cy + 4, cx + ts / 2, cy + ts - 4)
        end
        if cell.subjectId then
            local risk = cell.currentRisk or 0
            if risk >= 70 then
                love.graphics.setColor(1, 0.25, 0.2, 0.7)
            elseif risk >= 40 then
                love.graphics.setColor(1, 0.75, 0.2, 0.7)
            else
                love.graphics.setColor(0.3, 1, 0.45, 0.6)
            end
            love.graphics.rectangle('line', cx + 1, cy + 1, ts - 2, ts - 2)
        end
        if state.selectedEntities[id] then
            love.graphics.setColor(0.2, 1, 0.35, 0.6)
            love.graphics.rectangle('line', cx, cy, ts, ts)
        end
        ::nextContainment::
    end

    -- Draw map secret artifacts
    for id, comps in ecs.query('pos', 'artifact') do
        local pos = comps.pos
        if (pos.depth or 0) ~= viewDepth then goto nextArtifact end
        if not tileExplored(pos.x, pos.y) then goto nextArtifact end
        local ax, ay = pos.x * ts, pos.y * ts
        local art = comps.artifact
        if art.activated then
            love.graphics.setColor(0.35, 0.35, 0.4, 0.5)
            love.graphics.circle('line', ax + ts / 2, ay + ts / 2, 7)
        else
            love.graphics.setColor(0.75, 0.55, 0.95, 0.8)
            love.graphics.circle('fill', ax + ts / 2, ay + ts / 2, 6)
            love.graphics.setColor(0.95, 0.85, 1, 0.9)
            love.graphics.circle('line', ax + ts / 2, ay + ts / 2, 9)
        end
        if state.selectedEntities[id] then
            love.graphics.setColor(0.2, 1, 0.35, 0.6)
            love.graphics.rectangle('line', ax + 2, ay + 2, ts - 4, ts - 4)
        end
        ::nextArtifact::
    end

    -- Draw creature lairs (only on explored tiles)
    for id, comps in ecs.query('pos', 'lair') do
        local lpos = comps.pos
        if (lpos.depth or 0) ~= viewDepth then goto nextLair end
        if not tileExplored(lpos.x, lpos.y) then goto nextLair end
        local lair = comps.lair
        local lx, ly = lpos.x * ts, lpos.y * ts
        love.graphics.setColor(0.3, 0.15, 0.1)
        love.graphics.circle('fill', lx + ts/2, ly + ts/2, 12)
        love.graphics.setColor(0.5, 0.2, 0.1, 0.8)
        love.graphics.circle('line', lx + ts/2, ly + ts/2, 14)
        -- Health bar if damaged
        if lair.health < lair.maxHealth then
            local frac = lair.health / lair.maxHealth
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle('fill', lx + 4, ly - 4, ts - 8, 3)
            love.graphics.setColor(0.8, 0.3, 0.1)
            love.graphics.rectangle('fill', lx + 4, ly - 4, (ts - 8) * frac, 3)
        end
        ::nextLair::
    end

    -- Draw machines (sawmill, smelter, kitchen, etc.)
    if Sprites then
        for id, comps in ecs.query('pos', 'machine') do
            local mpos = comps.pos
            if (mpos.depth or 0) ~= viewDepth then goto nextMachine end
            local mach = comps.machine
            local machSprite = Sprites.getBuilding(mach.type)
            if machSprite then
                local mx, my = mpos.x * ts, mpos.y * ts
                love.graphics.setColor(1, 1, 1)
                local sw = machSprite:getWidth()
                local sh = machSprite:getHeight()
                love.graphics.draw(machSprite, mx, my, 0, ts / sw, ts / sh)
            end
            ::nextMachine::
        end
    end

    -- Draw turrets
    if Sprites then
        for id, comps in ecs.query('pos', 'turret') do
            local tpos = comps.pos
            if (tpos.depth or 0) ~= viewDepth then goto nextTurret end
            local turr = comps.turret
            local turrSprite = Sprites.getDefense(turr.type) or Sprites.getBuilding(turr.type)
            if turrSprite then
                local tx, ty = tpos.x * ts, tpos.y * ts
                love.graphics.setColor(1, 1, 1)
                local sw = turrSprite:getWidth()
                local sh = turrSprite:getHeight()
                love.graphics.draw(turrSprite, tx, ty, 0, ts / sw, ts / sh)
            end
            ::nextTurret::
        end
    end

    -- Draw traps
    if Sprites then
        for id, comps in ecs.query('pos', 'trap') do
            local trpos = comps.pos
            if (trpos.depth or 0) ~= viewDepth then goto nextTrap end
            local trap = comps.trap
            local trapSprite = Sprites.getDefense(trap.type) or Sprites.getBuilding(trap.type)
            if trapSprite then
                local trx, try = trpos.x * ts, trpos.y * ts
                love.graphics.setColor(1, 1, 1)
                local sw = trapSprite:getWidth()
                local sh = trapSprite:getHeight()
                love.graphics.draw(trapSprite, trx, try, 0, ts / sw, ts / sh)
            end
            ::nextTrap::
        end
    end

    -- Draw projectiles
    for id, comps in ecs.query('pos', 'projectile') do
        local ppos = comps.pos
        local proj = comps.projectile
        if (ppos.depth or 0) ~= viewDepth then goto nextProjectile end
        local px, py = ppos.x * ts + ts/2, ppos.y * ts + ts/2
        if ppos.prevX and ppos.prevY then
            local a = state.alpha
            px = (ppos.prevX + (ppos.x - ppos.prevX) * a) * ts + ts/2
            py = (ppos.prevY + (ppos.y - ppos.prevY) * a) * ts + ts/2
        end

        local r, g, b, radius = 1, 0.9, 0.3, 3
        if proj.isMissile and proj.missileType then
            radius = 4
            if proj.missileType == 'missile_napalm' then
                r, g, b = 1, 0.45, 0.1
            elseif proj.missileType == 'missile_bio' then
                r, g, b = 0.55, 0.9, 0.25
            elseif proj.missileType == 'missile_foam' then
                r, g, b = 0.65, 0.9, 1.0
            elseif proj.missileType == 'missile_nuke' then
                r, g, b = 1.0, 0.95, 0.55
                radius = 5
            elseif proj.missileType == 'missile_bunker' then
                r, g, b = 0.95, 0.75, 0.4
            else
                r, g, b = 1.0, 0.8, 0.2
            end
            if ppos.prevX and ppos.prevY then
                local tx = ppos.prevX * ts + ts/2
                local ty = ppos.prevY * ts + ts/2
                love.graphics.setColor(r, g, b, 0.35)
                love.graphics.setLineWidth(2)
                love.graphics.line(tx, ty, px, py)
                love.graphics.setLineWidth(1)
            end
        end
        love.graphics.setColor(r, g, b, 0.9)
        love.graphics.circle('fill', px, py, radius)
        ::nextProjectile::
    end

    -- Draw ground items (only on visible tiles)
    for id, comps in ecs.query('pos', 'item') do
        local ipos = comps.pos
        if (ipos.depth or 0) ~= viewDepth then goto nextItem end
        local item = comps.item
        if not item.hauled and tileVisible(ipos.x, ipos.y) then
            local ix, iy = ipos.x * ts, ipos.y * ts
            local itemSprite = Sprites and Sprites.getItem(item.itemId)
            if itemSprite then
                love.graphics.setColor(1, 1, 1)
                local sw = itemSprite:getWidth()
                local sh = itemSprite:getHeight()
                -- Items are 16px sprites, draw centered in tile
                local itemScale = (ts * 0.5) / math.max(sw, sh)
                local drawW = sw * itemScale
                local drawH = sh * itemScale
                love.graphics.draw(itemSprite, ix + (ts - drawW) / 2, iy + (ts - drawH) / 2, 0, itemScale, itemScale)
            else
                love.graphics.setColor(0.9, 0.8, 0.3, 0.8)
                love.graphics.rectangle('fill', ix + 10, iy + 10, ts - 20, ts - 20)
                love.graphics.setColor(0.7, 0.6, 0.2)
                love.graphics.rectangle('line', ix + 10, iy + 10, ts - 20, ts - 20)
            end
        end
        ::nextItem::
    end

    -- Draw selected colonist paths on the current layer
    for id, comps in ecs.query('pos', 'path', 'colonist') do
        if not state.selectedEntities[id] then goto nextSelectedPath end
        local pos = comps.pos
        local path = comps.path
        if (pos.depth or 0) ~= viewDepth or not path.nodes or path.index > #path.nodes then
            goto nextSelectedPath
        end

        local points = { pos.x * ts + ts / 2, pos.y * ts + ts / 2 }
        for i = path.index, #path.nodes do
            local node = path.nodes[i]
            if (node.depth or 0) == viewDepth then
                points[#points + 1] = node.x * ts + ts / 2
                points[#points + 1] = node.y * ts + ts / 2
            end
        end
        if #points >= 4 then
            local color = comps.colonist.drafted and { 1.0, 0.35, 0.2 } or { 0.15, 0.95, 0.45 }
            love.graphics.setColor(color[1], color[2], color[3], 0.75)
            love.graphics.setLineWidth(2)
            love.graphics.line(points)
            love.graphics.setLineWidth(1)
            local endX = points[#points - 1]
            local endY = points[#points]
            love.graphics.circle('line', endX, endY, 6)
        end
        ::nextSelectedPath::
    end

    -- Draw colonist vision cones (under colonists, above terrain) — surface only
    if fogActive and Vis and viewDepth == 0 then
        local cones = Vis.getColonistCones()
        for _, cone in pairs(cones) do
            love.graphics.setColor(0.3, 0.7, 1, 0.06)
            for _, idx in ipairs(cone.tiles) do
                local ty = math.floor((idx - 1) / state.mapWidth)
                local tx = (idx - 1) - ty * state.mapWidth
                love.graphics.rectangle('fill', tx * ts, ty * ts, ts, ts)
            end
            -- Draw facing direction indicator (small line from colonist center)
            local cx = cone.x * ts + ts / 2
            local cy = cone.y * ts + ts / 2
            local lineLen = ts * 1.2
            love.graphics.setColor(0.3, 0.7, 1, 0.35)
            love.graphics.setLineWidth(2)
            love.graphics.line(cx, cy,
                cx + math.cos(cone.facing) * lineLen,
                cy + math.sin(cone.facing) * lineLen)
            love.graphics.setLineWidth(1)
        end
    end

    -- Draw colonists
    for id, comps in ecs.query('pos', 'colonist') do
        local pos = comps.pos
        if (pos.depth or 0) ~= viewDepth then goto nextColonist end
        local col = comps.colonist
        local px, py = pos.x * ts, pos.y * ts

        -- Interpolate position for smooth movement
        if pos.prevX and pos.prevY then
            local a = state.alpha
            px = (pos.prevX + (pos.x - pos.prevX) * a) * ts
            py = (pos.prevY + (pos.y - pos.prevY) * a) * ts
        end

        -- Determine visual state and try sprite
        local taskType = nil
        if col.task then
            if _Jobs then
                local t = _Jobs.getTask(col.task.taskId)
                if t then taskType = t.type end
            end
        end
        local colState = Sprites and Sprites.getColonistState(col, taskType) or 'idle'
        local colSprite = Sprites and Sprites.getColonist(colState)

        if colSprite then
            -- Tint by state
            local cr, cg, cb = 1, 1, 1
            if col.mentalBreak then
                cr, cg, cb = 1, 0.5, 0.5
            elseif col._suffocating and col._suffocating >= 2 then
                local suf = math.min(1, (col._suffocating - 1) * 0.5)
                cr = 1 - suf * 0.4
                cg = 1 - suf * 0.5
                cb = math.min(1, 0.7 + suf * 0.3)
            elseif col.hypothermiaStage and col.hypothermiaStage >= 3 then
                local frost = math.min(1, (col.hypothermiaStage - 2) * 0.3)
                cg = 1 - frost * 0.3
                cb = math.min(1, 1 + frost * 0.1)
                cr = 1 - frost * 0.4
            end
            love.graphics.setColor(cr, cg, cb)
            local sw = colSprite:getWidth()
            local sh = colSprite:getHeight()
            love.graphics.draw(colSprite, px, py, 0, ts / sw, ts / sh)
        else
            -- Fallback: rectangle body + circle head
            local br, bg, bb = 0.2, 0.5, 0.8
            if col.mentalBreak then
                br, bg, bb = 0.8, 0.15, 0.15
            elseif col._suffocating and col._suffocating >= 2 then
                br, bg, bb = 0.4, 0.2, 0.6
            elseif col.hypothermiaStage and col.hypothermiaStage >= 3 then
                local frost = math.min(1, (col.hypothermiaStage - 2) * 0.3)
                br = br * (1 - frost * 0.5)
                bg = bg * (1 - frost * 0.3)
                bb = math.min(1, bb + frost * 0.2)
            end
            love.graphics.setColor(br, bg, bb)
            love.graphics.rectangle('fill', px + 4, py + 4, ts - 8, ts - 8)
            love.graphics.setColor(0.85, 0.75, 0.6)
            love.graphics.circle('fill', px + ts / 2, py + 8, 6)
        end

        -- Name
        love.graphics.setColor(1, 1, 1, 0.8)
        local name = col.name or ('C' .. id)
        local font = love.graphics.getFont()
        love.graphics.print(name, px + ts / 2 - font:getWidth(name) / 2, py - 12)

        -- Selection highlight
        if state.selectedEntities[id] then
            love.graphics.setColor(0, 1, 0, 0.5)
            love.graphics.rectangle('line', px + 1, py + 1, ts - 2, ts - 2)
        end

        -- Health bar (only show when damaged and alive)
        if col.state ~= 'dead' and col.maxHealth > 0 and col.health < col.maxHealth then
            local hpFrac = math.max(0, col.health / col.maxHealth)
            local hpBarW = ts - 8
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
            love.graphics.rectangle('fill', px + 4, py + ts - 4, hpBarW, 3)
            local hr = hpFrac < 0.3 and 1 or (1 - hpFrac)
            local hg = hpFrac > 0.5 and 0.8 or hpFrac
            love.graphics.setColor(hr, hg, 0.1)
            love.graphics.rectangle('fill', px + 4, py + ts - 4, hpBarW * hpFrac, 3)
        end

        -- Need bars (tiny bars above head) — hide for dead colonists
        local needs = (col.state ~= 'dead') and ecs.get(id, 'needs') or nil
        if needs then
            local barW = ts - 8
            local barH = 2
            local barY = py - 16

            -- Warmth bar (blue to red)
            local warmth = needs.warmth / 100
            love.graphics.setColor(0.3, 0.3, 0.8)
            love.graphics.rectangle('fill', px + 4, barY, barW, barH)
            love.graphics.setColor(0.9, 0.3, 0.2)
            love.graphics.rectangle('fill', px + 4, barY, barW * warmth, barH)

            -- Hunger bar
            local hunger = needs.food / 100
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle('fill', px + 4, barY - 3, barW, barH)
            love.graphics.setColor(0.2, 0.8, 0.3)
            love.graphics.rectangle('fill', px + 4, barY - 3, barW * hunger, barH)

            -- Water bar
            local water = (needs.water or 80) / 100
            love.graphics.setColor(0.1, 0.2, 0.4)
            love.graphics.rectangle('fill', px + 4, barY - 6, barW, barH)
            love.graphics.setColor(0.2, 0.6, 0.9)
            love.graphics.rectangle('fill', px + 4, barY - 6, barW * water, barH)
        end

        -- Mental break / stress speech bubble
        if col.mentalBreak then
            local bubX = px + ts - 2
            local bubY = py - 8
            love.graphics.setColor(0.9, 0.2, 0.2, 0.85)
            love.graphics.rectangle('fill', bubX, bubY, 8, 8, 2, 2)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print('!', bubX + 1, bubY - 1)
        end
        ::nextColonist::
    end

    -- Draw creatures (only on visible tiles)
    for id, comps in ecs.query('pos', 'creature') do
        local pos = comps.pos
        if (pos.depth or 0) ~= viewDepth then goto nextCreature end
        if not tileVisible(pos.x, pos.y) then goto nextCreature end
        local cr = comps.creature
        local px, py = pos.x * ts, pos.y * ts

        -- Interpolate for smooth movement
        if pos.prevX and pos.prevY then
            local a = state.alpha
            px = (pos.prevX + (pos.x - pos.prevX) * a) * ts
            py = (pos.prevY + (pos.y - pos.prevY) * a) * ts
        end

        local size = cr.size or 1
        local halfS = ts * size / 2
        local col = cr.color or { 0.7, 0.7, 0.65 }
        local sp = Creatures.SPECIES[cr.species]
        local isHumanoid = sp and sp.humanoid

        -- Try sprite
        local crSprite = Sprites and Sprites.getCreature(cr.species)
        if crSprite then
            love.graphics.setColor(1, 1, 1)
            local sw = crSprite:getWidth()
            local sh = crSprite:getHeight()
            -- Scale sprite to creature size (centered on tile)
            local drawSize = ts * size
            local scale = drawSize / math.max(sw, sh)
            local drawW = sw * scale
            local drawH = sh * scale
            local drawX = px + ts / 2 - drawW / 2
            local drawY = py + ts / 2 - drawH / 2
            love.graphics.draw(crSprite, drawX, drawY, 0, scale, scale)
        else
            -- Fallback: colored shapes
            love.graphics.setColor(col[1], col[2], col[3])
            if isHumanoid then
                local bw = ts * size * 0.7
                local bh = ts * size * 0.9
                local bx = px + ts / 2 - bw / 2
                local by = py + ts / 2 - bh / 2
                love.graphics.rectangle('fill', bx, by, bw, bh)
                love.graphics.setColor(col[1] * 0.85, col[2] * 0.85, col[3] * 0.85)
                love.graphics.circle('fill', px + ts / 2, by + 4, bw * 0.35)
            else
                love.graphics.circle('fill', px + ts / 2, py + ts / 2, halfS)
            end
        end

        -- Hostile indicator
        if cr.hostile then
            if isHumanoid then
                love.graphics.setColor(1, 0.5, 0, 0.6)
                local bw = ts * size * 0.7 + 4
                local bh = ts * size * 0.9 + 4
                love.graphics.rectangle('line', px + ts / 2 - bw / 2, py + ts / 2 - bh / 2, bw, bh)
            else
                love.graphics.setColor(1, 0, 0, 0.6)
                love.graphics.circle('line', px + ts / 2, py + ts / 2, halfS + 2)
            end
        end

        -- Health bar for damaged creatures
        if cr.maxHealth > 0 and cr.health < cr.maxHealth then
            local barW = halfS * 2
            local barH = 3
            local barX = px + ts / 2 - halfS
            local barY = py + ts / 2 - halfS - 6
            local hpFrac = cr.health / cr.maxHealth
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle('fill', barX, barY, barW, barH)
            local r = hpFrac < 0.3 and 1 or (1 - hpFrac)
            local g = hpFrac > 0.5 and 0.8 or hpFrac
            love.graphics.setColor(r, g, 0.1)
            love.graphics.rectangle('fill', barX, barY, barW * hpFrac, barH)
        end

        -- Tier label for megafauna and humanoid raiders
        if cr.tier == 'megafauna' then
            love.graphics.setColor(1, 0.4, 0.3, 0.8)
            local font = love.graphics.getFont()
            local label = cr.name
            love.graphics.print(label, px + ts / 2 - font:getWidth(label) / 2, py + ts / 2 - halfS - 18)
        elseif isHumanoid then
            love.graphics.setColor(1, 0.7, 0.3, 0.7)
            local font = love.graphics.getFont()
            local label = cr.name
            love.graphics.print(label, px + ts / 2 - font:getWidth(label) / 2, py - 12)
        end
        ::nextCreature::
    end

    -- Build ghost preview
    if state.buildMode and state.buildGhost then
        local mx, my = love.mouse.getPosition()
        local tx, ty = _Camera.screenToTile(mx, my)
        local ghost = state.buildGhost

        for dy = 0, (ghost.h or 1) - 1 do
            for dx = 0, (ghost.w or 1) - 1 do
                local gx, gy = tx + dx, ty + dy
                local rvd = GameState.viewDepth or 0
                local valid = _WorldMap.inBounds(gx, gy) and Tiles.isBuildable(_WorldMap.getTile(gx, gy, rvd))

                if valid then
                    love.graphics.setColor(0, 0.8, 0.4, 0.35)
                else
                    love.graphics.setColor(0.8, 0.1, 0.1, 0.35)
                end
                love.graphics.rectangle('fill', gx * ts, gy * ts, ts, ts)
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.rectangle('line', gx * ts, gy * ts, ts, ts)
            end
        end

        -- Direction arrow for directional buildings (conveyors, inserters, splitters)
        local def = ghost.id and _Building and _Building.defs[ghost.id]
        if def and (def.entitySpawn == 'conveyor' or def.entitySpawn == 'splitter' or def.entitySpawn == 'inserter') then
            local dir = state.buildDirection or 'right'
            local cx, cy = tx * ts + ts / 2, ty * ts + ts / 2
            local arrowLen = ts * 0.35
            local adx, ady = 0, 0
            if dir == 'right' then adx = 1
            elseif dir == 'left' then adx = -1
            elseif dir == 'down' then ady = 1
            elseif dir == 'up' then ady = -1 end
            local ex, ey = cx + adx * arrowLen, cy + ady * arrowLen
            love.graphics.setColor(1, 1, 0, 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.line(cx - adx * arrowLen * 0.5, cy - ady * arrowLen * 0.5, ex, ey)
            -- Arrowhead
            local perpX, perpY = -ady, adx
            love.graphics.polygon('fill',
                ex, ey,
                ex - adx * 6 + perpX * 4, ey - ady * 6 + perpY * 4,
                ex - adx * 6 - perpX * 4, ey - ady * 6 - perpY * 4)
            love.graphics.setLineWidth(1)
        end

        -- Build tooltip: show name, desc, and cost near cursor
        def = ghost.id and _Building and _Building.defs[ghost.id]
        if def then
            love.graphics.push()
            love.graphics.origin()
            local font = love.graphics.getFont()
            local tipX, tipY = mx + 16, my + 16
            local lines = { def.name }
            if def.desc then lines[#lines + 1] = def.desc end
            if def.entitySpawn == 'conveyor' or def.entitySpawn == 'splitter' or def.entitySpawn == 'inserter' then
                lines[#lines + 1] = '[R] rotate (' .. (state.buildDirection or 'right') .. ')'
            end
            if def.cost then
                local parts = {}
                for res, amt in pairs(def.cost) do
                    parts[#parts + 1] = res .. ': ' .. amt
                end
                lines[#lines + 1] = table.concat(parts, '  ')
            end
            local lineH = font:getHeight()
            local maxW = 0
            for _, ln in ipairs(lines) do
                local lw = font:getWidth(ln)
                if lw > maxW then maxW = lw end
            end
            local padX, padY = 8, 4
            local boxW = maxW + padX * 2
            local boxH = #lines * lineH + padY * 2
            local sw, sh = love.graphics.getDimensions()
            if tipX + boxW > sw then tipX = mx - boxW - 4 end
            if tipY + boxH > sh then tipY = my - boxH - 4 end
            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.rectangle('fill', tipX, tipY, boxW, boxH, 4, 4)
            love.graphics.setColor(0.4, 0.6, 0.8, 0.8)
            love.graphics.rectangle('line', tipX, tipY, boxW, boxH, 4, 4)
            for i, ln in ipairs(lines) do
                if i == 1 then
                    love.graphics.setColor(1, 1, 1, 1)
                elseif i == #lines and def.cost then
                    love.graphics.setColor(0.8, 0.7, 0.3, 1)
                else
                    love.graphics.setColor(0.7, 0.7, 0.7, 0.9)
                end
                love.graphics.print(ln, tipX + padX, tipY + padY + (i - 1) * lineH)
            end
            love.graphics.pop()
        end
    end
end

---------------------------------------------------------------------------
-- Depth indicator HUD — shows current view layer
---------------------------------------------------------------------------

function Renderer.drawDepthIndicator()
    local vd = GameState.viewDepth or 0
    if vd == 0 then return end  -- surface = no indicator needed

    local sw = love.graphics.getWidth()
    local font = love.graphics.getFont()
    local label = string.format('Depth %d  [  deeper  /  ]  shallower', vd)
    local tw = font:getWidth(label)
    local tx = sw / 2 - tw / 2
    local ty = 8

    -- Background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', tx - 12, ty - 4, tw + 24, font:getHeight() + 8, 4, 4)
    -- Border
    love.graphics.setColor(0.4, 0.5, 0.7, 0.8)
    love.graphics.rectangle('line', tx - 12, ty - 4, tw + 24, font:getHeight() + 8, 4, 4)
    -- Text
    love.graphics.setColor(0.7, 0.8, 1, 1)
    love.graphics.print(label, tx, ty)
end

---------------------------------------------------------------------------
-- Terraform tool ghost — shows designation preview for dig operations
---------------------------------------------------------------------------

function Renderer.drawTerraformGhost(world)
    local tool = GameState.selectedTool
    if not tool then return end
    -- Match terraform_* tools
    local opId = tool:match('^terraform_(.+)$')
    if not opId then return end

    local ts = world.tileSize()
    local mx, my = love.mouse.getPosition()
    lazyLoadRenderMods()
    if not _Camera then return end
    local tx, ty = _Camera.screenToTile(mx, my)
    local vd = GameState.viewDepth or 0

    if not _Terraform then return end
    local op = _Terraform.OPS[opId]
    if not op then return end

    local canApply = _Terraform.canApply(opId, tx, ty, vd)
    if canApply then
        love.graphics.setColor(0.3, 0.7, 1, 0.35)
    else
        love.graphics.setColor(0.8, 0.1, 0.1, 0.35)
    end
    love.graphics.rectangle('fill', tx * ts, ty * ts, ts, ts)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle('line', tx * ts, ty * ts, ts, ts)

    -- Tooltip
    love.graphics.push()
    love.graphics.origin()
    local font = love.graphics.getFont()
    local tipX, tipY = mx + 16, my + 16
    local lines = { op.name }
    if op.desc then lines[#lines + 1] = op.desc end
    if op.cost then
        local parts = {}
        for res, amt in pairs(op.cost) do
            parts[#parts + 1] = res .. ': ' .. amt
        end
        lines[#lines + 1] = table.concat(parts, '  ')
    end
    local lineH = font:getHeight()
    local maxW = 0
    for _, ln in ipairs(lines) do
        local lw = font:getWidth(ln)
        if lw > maxW then maxW = lw end
    end
    local padX, padY = 8, 4
    local boxW = maxW + padX * 2
    local boxH = #lines * lineH + padY * 2
    local sw2, sh2 = love.graphics.getDimensions()
    if tipX + boxW > sw2 then tipX = mx - boxW - 4 end
    if tipY + boxH > sh2 then tipY = my - boxH - 4 end
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', tipX, tipY, boxW, boxH, 4, 4)
    love.graphics.setColor(0.4, 0.6, 0.8, 0.8)
    love.graphics.rectangle('line', tipX, tipY, boxW, boxH, 4, 4)
    for i, ln in ipairs(lines) do
        if i == 1 then
            love.graphics.setColor(0.7, 0.85, 1, 1)
        else
            love.graphics.setColor(0.7, 0.7, 0.7, 0.9)
        end
        love.graphics.print(ln, tipX + padX, tipY + padY + (i - 1) * lineH)
    end
    love.graphics.pop()
end

---------------------------------------------------------------------------
-- Event toast queue — shows storyteller events with stacking
---------------------------------------------------------------------------

local TOAST_DURATION = 8  -- seconds to show
local MAX_TOASTS = 3

function Renderer.drawEventToast(storyteller)
    local allEvents = storyteller.getLog and storyteller.getLog() or nil
    local now = love.timer.getTime()

    -- Fallback: single event display
    if not allEvents or #allEvents == 0 then
        local ev = storyteller.getLatestEvent()
        if not ev then return end
        allEvents = { ev }
    end

    -- Filter to active toasts (within duration)
    local active = {}
    for i = #allEvents, 1, -1 do
        local ev = allEvents[i]
        local age = now - ev.time
        if age <= TOAST_DURATION then
            active[#active + 1] = ev
        end
        if #active >= MAX_TOASTS then break end
    end

    if #active == 0 then return end

    local sw = love.graphics.getWidth()
    local font = love.graphics.getFont()
    local baseY = 50

    for idx, ev in ipairs(active) do
        local age = now - ev.time
        local alpha = age < 0.5 and (age / 0.5) or
                      age > TOAST_DURATION - 1 and ((TOAST_DURATION - age) / 1) or 1

        local text = ev.message
        local tw = font:getWidth(text)
        local tx = sw / 2 - tw / 2
        local ty = baseY + (idx - 1) * 32

        -- Background
        love.graphics.setColor(0, 0, 0, 0.7 * alpha)
        love.graphics.rectangle('fill', tx - 16, ty - 6, tw + 32, 28, 4)

        -- Border
        love.graphics.setColor(0.8, 0.6, 0.2, 0.8 * alpha)
        love.graphics.rectangle('line', tx - 16, ty - 6, tw + 32, 28, 4)

        -- Text
        love.graphics.setColor(1, 0.95, 0.8, alpha)
        love.graphics.print(text, tx, ty)
    end
end

---------------------------------------------------------------------------
-- Ambient day/night overlay — screen-space tint based on time of day
---------------------------------------------------------------------------

function Renderer.drawAmbientOverlay()
    local h = GameState.hour

    -- Compute darkness factor: 0 = full day, 1 = deep night
    local darkness = 0
    if h >= 20 or h < 6 then
        darkness = 0.35  -- night
    elseif h >= 18 then
        darkness = 0.35 * ((h - 18) / 2)  -- dusk
    elseif h < 8 then
        darkness = 0.35 * ((8 - h) / 2)   -- dawn
    end

    if darkness <= 0.001 then return end

    local sw, sh = love.graphics.getDimensions()
    -- Blue-tinted night overlay
    love.graphics.setColor(0.02, 0.03, 0.12, darkness)
    love.graphics.rectangle('fill', 0, 0, sw, sh)
end

return Renderer
