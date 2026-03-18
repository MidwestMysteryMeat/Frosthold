-- thermal.lua — Room-based thermal simulation (RimWorld-inspired)
-- Core principle: each enclosed room has ONE temperature.
-- Heat sources warm the room toward a target temp (power determines rate).
-- Heat loss flows through walls/doors proportional to perimeter/area ratio.
-- Wall insulation and double walls affect heat retention.
-- Doors separate rooms thermally; sealed doors insulate better.
-- Vertical heat transfer flows through stairs/shafts between depths.
-- Outdoor tiles track ambient temperature.

local Tiles     = require('src.world.tiles')
local GameState = require('src.game_state')

local Thermal = {}

local world           -- reference to tilemap module
local heatSources = {} -- { [key] = watts } — power rating (positive=heat, negative=cool)
local heatTargets = {} -- { [key] = targetTemp } — ceiling/floor temp in °C
local heatDanger  = {} -- { [key] = { radius, tempOffset } } — proximity danger zone
local heatControl = {} -- { [key] = true } — player-controllable via UI
local tileToRoom  = {} -- idx -> roomId (fast lookup)
local VENT_HEAT   = 120 -- °C output from lava vents

---------------------------------------------------------------------------
-- Tuning constants (inspired by RimWorld mechanics)
---------------------------------------------------------------------------

-- Wall/door heat transfer per segment per tick
local WALL_TRANSFER        = 0.0007
local DOOR_TRANSFER        = 0.004   -- closed door leaks ~6x a wall segment
local SEALED_DOOR_TRANSFER = 0.002   -- sealed door: better than normal door

-- Vertical heat transfer (stairs/shafts are open, floors insulate)
local VERTICAL_OPEN_TRANSFER = 0.003  -- open stair/shaft connection
local VERTICAL_FLOOR_TRANSFER = 0.0003  -- heat bleeding through floor tiles

-- How fast outdoor tiles converge to ambient
local OUTDOOR_SNAP = 0.5

-- Rooms larger than this are treated as outdoor (open areas)
local MAX_ROOM_SIZE = 400

-- How fast point heat sources (campfire, heater) warm a room per tick
-- Applied as: abs(watts) / cellCount * factor * dt
local HEAT_PUSH_FACTOR = 0.12

-- How fast generator/steam hub zones warm a room
local GEN_PUSH_FACTOR = 0.25

---------------------------------------------------------------------------
-- Room tracking
---------------------------------------------------------------------------

local rooms = {}      -- rooms[roomId] = { tiles, wallSegs, doorSegs, verticalSegs, avgTemp, cellCount, sealed }

local DIRS = { {-1,0}, {1,0}, {0,-1}, {0,1} }

local function isDoor(tileType)
    return tileType == Tiles.DOOR or tileType == Tiles.DOOR_SEALED or tileType == Tiles.DOOR_LEAD
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Thermal.init(tilemap)
    world = tilemap
    heatSources = {}
    heatTargets = {}
    heatDanger  = {}
    heatControl = {}
    rooms = {}
    tileToRoom = {}

    -- Apply planet-specific thermal constants
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then
        OUTDOOR_SNAP = Planet.get('thermal.outdoorSnap', OUTDOOR_SNAP)
    end

    -- Find natural heat sources (lava vents) on surface
    local w, h = world.width(), world.height()
    local tData = world.rawTileData()
    for vy = 0, h - 1 do
        for vx = 0, w - 1 do
            local idx = vy * w + vx + 1
            if tData[idx] == Tiles.LAVA_VENT then
                heatSources[idx] = VENT_HEAT  -- depth 0: key = 0*100000000 + idx = idx
                heatTargets[idx] = 80         -- lava vents push toward 80°C
            elseif tData[idx] == Tiles.VOLCANIC_FLOOR then
                heatSources[idx] = 15         -- warm volcanic ground, mild heat
                heatTargets[idx] = 10         -- pushes toward 10°C
            end
        end
    end
end

---------------------------------------------------------------------------
-- Heat source management
---------------------------------------------------------------------------

-- Add a heat source. watts = power rating. targetTemp = ceiling/floor temp.
-- danger = { radius, tempOffset } for proximity hazard zones.
-- controllable = true for player-adjustable targets (electric heaters/coolers).
function Thermal.addHeatSource(x, y, watts, depth, targetTemp, danger, controllable)
    if not world or not world.inBounds then return end
    if not world.inBounds(x, y) then return end
    local idx = world.rawIndex(x, y)
    local key = (depth or 0) * 100000000 + idx
    heatSources[key] = (heatSources[key] or 0) + watts
    if targetTemp then
        heatTargets[key] = targetTemp
    end
    if danger then
        heatDanger[key] = danger
    end
    if controllable then
        heatControl[key] = true
    end
end

function Thermal.removeHeatSource(x, y, watts, depth)
    if not world or not world.inBounds then return end
    if not world.inBounds(x, y) then return end
    local idx = world.rawIndex(x, y)
    local key = (depth or 0) * 100000000 + idx
    if not heatSources[key] then return end
    heatSources[key] = heatSources[key] - (watts or heatSources[key])
    if heatSources[key] <= 0 or (watts and math.abs(heatSources[key]) < 0.01) then
        heatSources[key] = nil
        heatTargets[key] = nil
        heatDanger[key] = nil
        heatControl[key] = nil
    end
end

function Thermal.getHeatAt(x, y, depth)
    if not world or not world.inBounds then return 0 end
    if not world.inBounds(x, y) then return 0 end
    local key = (depth or 0) * 100000000 + world.rawIndex(x, y)
    return heatSources[key] or 0
end

-- UI control: set target temperature on a controllable heat source
function Thermal.setHeatTarget(x, y, target, depth)
    if not world or not world.inBounds then return false end
    if not world.inBounds(x, y) then return false end
    local key = (depth or 0) * 100000000 + world.rawIndex(x, y)
    if not heatControl[key] then return false end
    heatTargets[key] = target
    return true
end

function Thermal.getHeatTarget(x, y, depth)
    if not world.inBounds(x, y) then return nil end
    local key = (depth or 0) * 100000000 + world.rawIndex(x, y)
    return heatTargets[key]
end

function Thermal.isControllable(x, y, depth)
    if not world.inBounds(x, y) then return false end
    local key = (depth or 0) * 100000000 + world.rawIndex(x, y)
    return heatControl[key] == true
end

---------------------------------------------------------------------------
-- Room detection — flood fill, doors act as room boundaries
---------------------------------------------------------------------------

local roomDetectCooldown = 0
local ROOM_DETECT_INTERVAL = 5  -- seconds between room recalcs

function Thermal.detectRooms()
    local w, h = world.width(), world.height()

    -- Reset room map but preserve old atmo-relevant data via stable IDs
    rooms = {}
    tileToRoom = {}

    -- Detect rooms on each depth layer
    for depth, layer in world.allLayers() do
        local tData = layer.tiles
        local rData = layer.rooms
        local tempData = layer.temps

        for i = 1, w * h do
            rData[i] = 0
        end

        local visited = {}

        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                local tile = tData[idx]

                -- Flood fill only enters non-solid, non-door tiles
                if not visited[idx] and not Tiles.isSolid(tile) and not isDoor(tile) then
                    local queue = { { x = x, y = y } }
                    local head = 1
                    local roomTiles = {}
                    local touchesEdge = false

                    while head <= #queue do
                        local cur = queue[head]
                        head = head + 1
                        local ci = cur.y * w + cur.x + 1

                        if not visited[ci] then
                            visited[ci] = true
                            local cTile = tData[ci]

                            if Tiles.isSolid(cTile) or isDoor(cTile) then
                                -- boundary
                            else
                                roomTiles[#roomTiles + 1] = ci

                                if cur.x <= 0 or cur.x >= w - 1
                                   or cur.y <= 0 or cur.y >= h - 1 then
                                    touchesEdge = true
                                end

                                for _, d in ipairs(DIRS) do
                                    local nx, ny = cur.x + d[1], cur.y + d[2]
                                    if nx >= 0 and nx < w and ny >= 0 and ny < h then
                                        local ni = ny * w + nx + 1
                                        if not visited[ni] then
                                            local nTile = tData[ni]
                                            if not Tiles.isSolid(nTile) and not isDoor(nTile) then
                                                queue[#queue + 1] = { x = nx, y = ny }
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    -- Underground layers are never outdoor (no edge exposure)
                    local isOutdoor = (depth == 0 and touchesEdge) or #roomTiles >= MAX_ROOM_SIZE
                    local rid = 0

                    if not isOutdoor and #roomTiles > 0 then
                        -- Stable room ID: use min tile index + depth offset
                        local minTi = roomTiles[1]
                        for _, ti in ipairs(roomTiles) do
                            if ti < minTi then minTi = ti end
                        end
                        rid = depth * 100000000 + minTi

                        local tempSum = 0
                        for _, ti in ipairs(roomTiles) do
                            tempSum = tempSum + tempData[ti]
                        end

                        rooms[rid] = {
                            tiles     = roomTiles,
                            wallSegs  = {},
                            doorSegs  = {},
                            verticalSegs = {},
                            avgTemp   = tempSum / #roomTiles,
                            cellCount = #roomTiles,
                            sealed    = true,
                            depth     = depth,
                            neighborRooms = {},
                        }
                    end

                    for _, ti in ipairs(roomTiles) do
                        rData[ti] = rid
                        -- tileToRoom uses depth-qualified key for cross-depth lookups
                        tileToRoom[depth * 100000000 + ti] = rid
                    end
                end
            end
        end

        -- Second pass: wall and door segments for rooms on this layer
        for rid, room in pairs(rooms) do
            if room.depth ~= depth then goto nextRoom end

            local wallSeen = {}
            local doorSeen = {}

            for _, ti in ipairs(room.tiles) do
                local ty = math.floor((ti - 1) / w)
                local tx = (ti - 1) % w

                for _, d in ipairs(DIRS) do
                    local nx, ny = tx + d[1], ty + d[2]
                    if nx >= 0 and nx < w and ny >= 0 and ny < h then
                        local ni = ny * w + nx + 1
                        local nTile = tData[ni]

                        if Tiles.isSolid(nTile) and not wallSeen[ni] then
                            wallSeen[ni] = true
                            local nProps = Tiles.get(nTile)

                            local bx, by = nx + d[1], ny + d[2]
                            local doubleWall = false
                            if bx >= 0 and bx < w and by >= 0 and by < h then
                                doubleWall = Tiles.isSolid(tData[by * w + bx + 1])
                            end

                            local otherRoomId = nil
                            if not doubleWall and bx >= 0 and bx < w and by >= 0 and by < h then
                                local bi = by * w + bx + 1
                                local orid = tileToRoom[depth * 100000000 + bi]
                                if orid and orid > 0 and orid ~= rid then
                                    otherRoomId = orid
                                end
                            end

                            room.wallSegs[#room.wallSegs + 1] = {
                                insulation = nProps.insulation,
                                doubleWall = doubleWall,
                                otherRoom  = otherRoomId,
                            }

                        elseif isDoor(nTile) and not doorSeen[ni] then
                            doorSeen[ni] = true

                            local otherRoomId = nil
                            for _, d2 in ipairs(DIRS) do
                                local ox, oy = nx + d2[1], ny + d2[2]
                                if ox >= 0 and ox < w and oy >= 0 and oy < h then
                                    local oi = oy * w + ox + 1
                                    local orid = tileToRoom[depth * 100000000 + oi]
                                    if orid and orid > 0 and orid ~= rid then
                                        otherRoomId = orid
                                        break
                                    end
                                end
                            end

                            room.doorSegs[#room.doorSegs + 1] = {
                                tileType  = nTile,
                                otherRoom = otherRoomId,
                            }

                            if otherRoomId then
                                room.neighborRooms[#room.neighborRooms + 1] = otherRoomId
                            end
                        end
                    end
                end
            end

            -- Vertical neighbors: connect rooms across depth levels
            -- (shafts, stairs, ramps — any tile with connects_up or connects_down)
            local vertSeen = {}
            for _, ti in ipairs(room.tiles) do
                local ty = math.floor((ti - 1) / w)
                local tx = (ti - 1) % w
                local tileType = tData[ti]
                if Tiles.connectsVertical(tileType) then
                    local upDepth, downDepth = world.getVerticalTargets(tx, ty, depth)
                    for _, targetDepth in pairs({ upDepth, downDepth }) do
                        if targetDepth then
                            local otherRid = tileToRoom[targetDepth * 100000000 + ti]
                            if otherRid and otherRid > 0 and otherRid ~= rid and not vertSeen[otherRid] then
                                vertSeen[otherRid] = true
                                room.neighborRooms[#room.neighborRooms + 1] = otherRid
                                -- Track as vertical segment for heat transfer
                                room.verticalSegs[#room.verticalSegs + 1] = {
                                    otherRoom = otherRid,
                                    open = true,  -- stairs/shafts are open connections
                                }
                            end
                        end
                    end
                end
            end

            ::nextRoom::
        end
    end
end

---------------------------------------------------------------------------
-- Thermal step — called each sim tick
---------------------------------------------------------------------------

function Thermal.step(dt)
    local w, h = world.width(), world.height()
    local tData = world.rawTileData()     -- surface (depth 0) for backward compat
    local tempData = world.rawTempData()  -- surface temps
    local rData = world.rawRoomData()     -- surface rooms
    local ambient = GameState.getEffectiveTemp()

    -- Periodic room detection
    roomDetectCooldown = roomDetectCooldown - dt
    if roomDetectCooldown <= 0 then
        Thermal.detectRooms()
        roomDetectCooldown = ROOM_DETECT_INTERVAL
        -- Refresh vent/emitter room IDs after room topology changes
        local atok, Atmo = pcall(require, 'src.sim.atmosphere')
        if atok and Atmo.refreshRoomIds then Atmo.refreshRoomIds() end
    end

    -- Blackout protocol reduces warmth output
    local warmthMult = 1.0
    local polOk, Policies = pcall(require, 'src.colony.policies')
    if polOk and Policies.getWarmthMult then
        warmthMult = Policies.getWarmthMult()
    end

    -------------------------------------------------------------------
    -- Phase 1: Heat input from point sources (campfire, heater, vents)
    -- Each source pushes its room toward its own target temperature.
    -- Power (watts) determines how fast it gets there.
    -- Multiple sources in the same room stack their push rates.
    -- Target temp caps how far the source can push (a heater targeting
    -- 21°C won't heat past 21°C no matter how powerful).
    -------------------------------------------------------------------
    for key, power in pairs(heatSources) do
        local rid = tileToRoom[key] or 0
        if rid <= 0 then goto next_source end
        local room = rooms[rid]
        if not room then goto next_source end

        local target = heatTargets[key] or (power < 0 and 0 or math.abs(power))
        local absPower = math.abs(power) * warmthMult
        local rate = absPower / room.cellCount * HEAT_PUSH_FACTOR * dt

        if power > 0 then
            -- Heating: push up toward target, stop at ceiling
            if room.avgTemp < target then
                room.avgTemp = math.min(target, room.avgTemp + rate)
            end
        elseif power < 0 then
            -- Cooling: push down toward target, stop at floor
            if room.avgTemp > target then
                room.avgTemp = math.max(target, room.avgTemp - rate)
            end
        end

        ::next_source::
    end

    -------------------------------------------------------------------
    -- Phase 2: Generator/steam hub heat zones
    -- Sample room tiles for generator heat bonus, push toward target.
    -------------------------------------------------------------------
    local genOk, Generator = pcall(require, 'src.sim.generator')
    if genOk and Generator.getHeatBonus then
        for rid, room in pairs(rooms) do
            local sampleStep = math.max(1, math.floor(room.cellCount / 16))
            local genSum, sampleCount = 0, 0
            for i = 1, #room.tiles, sampleStep do
                local ti = room.tiles[i]
                local ty = math.floor((ti - 1) / w)
                local tx = (ti - 1) % w
                local bonus = Generator.getHeatBonus(tx, ty)
                genSum = genSum + bonus
                sampleCount = sampleCount + 1
            end
            if sampleCount > 0 and genSum > 0 then
                local avgBonus = genSum / sampleCount * warmthMult
                local target = ambient + avgBonus
                if room.avgTemp < target then
                    room.avgTemp = math.min(target,
                        room.avgTemp + avgBonus * GEN_PUSH_FACTOR * dt)
                end
            end
        end
    end

    -------------------------------------------------------------------
    -- Phase 2.5: Geothermal warmth for underground rooms
    -- Underground tiles are naturally insulated by the earth above.
    -- Rooms with >50% underground tiles get a warmth floor of -10C
    -- instead of ambient (which can be -40C or worse).
    -------------------------------------------------------------------
    local UNDERGROUND_FLOOR_TEMP = -10
    for rid, room in pairs(rooms) do
        if room.sealed and room.cellCount > 0 then
            local layerTileData = world.rawTileData(room.depth or 0)
            if not layerTileData then goto nextGeothermalRoom end
            local undergroundCount = 0
            for _, ti in ipairs(room.tiles) do
                local tType = layerTileData[ti]
                if tType == Tiles.UNDERGROUND_FLOOR or tType == Tiles.SHAFT_ENTRANCE
                    or tType == Tiles.STAIR_DOWN or tType == Tiles.STAIR_UP
                    or tType == Tiles.STAIR_BOTH or tType == Tiles.RAMP_UP then
                    undergroundCount = undergroundCount + 1
                end
            end
            if undergroundCount > room.cellCount * 0.5 then
                -- Underground rooms don't drop below geothermal floor
                if room.avgTemp < UNDERGROUND_FLOOR_TEMP then
                    room.avgTemp = room.avgTemp + (UNDERGROUND_FLOOR_TEMP - room.avgTemp) * 0.1 * dt
                end
            end
            ::nextGeothermalRoom::
        end
    end

    -------------------------------------------------------------------
    -- Phase 3: Heat loss through walls, doors, and vertical connections
    --
    -- Each wall segment transfers heat based on:
    --   (otherTemp - roomTemp) * (1 - insulation) * WALL_TRANSFER
    -- Divided by cellCount (larger rooms = more thermal mass).
    -- Double walls halve transfer rate.
    -- Doors transfer at a higher rate than walls.
    -- Vertical connections (stairs/shafts) transfer between floors.
    -------------------------------------------------------------------
    for rid, room in pairs(rooms) do
        local cellCount = room.cellCount
        local scaledDt = dt * 20  -- normalize for 20Hz tick rate

        -- Wall segments
        for _, seg in ipairs(room.wallSegs) do
            local otherTemp = ambient
            if seg.otherRoom and rooms[seg.otherRoom] then
                otherTemp = rooms[seg.otherRoom].avgTemp
            end
            local transfer = (1 - seg.insulation) * WALL_TRANSFER
            if seg.doubleWall then
                transfer = transfer * 0.5
            end
            room.avgTemp = room.avgTemp +
                (otherTemp - room.avgTemp) * transfer * scaledDt / cellCount
        end

        -- Door segments
        for _, seg in ipairs(room.doorSegs) do
            local otherTemp = ambient
            if seg.otherRoom and rooms[seg.otherRoom] then
                otherTemp = rooms[seg.otherRoom].avgTemp
            end
            local rate = DOOR_TRANSFER
            if seg.tileType == Tiles.DOOR_SEALED or seg.tileType == Tiles.DOOR_LEAD then
                rate = SEALED_DOOR_TRANSFER
            end
            room.avgTemp = room.avgTemp +
                (otherTemp - room.avgTemp) * rate * scaledDt / cellCount
        end

        -- Vertical segments (stairs/shafts between floors)
        for _, seg in ipairs(room.verticalSegs) do
            local otherRoom = rooms[seg.otherRoom]
            if otherRoom then
                local rate = seg.open and VERTICAL_OPEN_TRANSFER or VERTICAL_FLOOR_TRANSFER
                room.avgTemp = room.avgTemp +
                    (otherRoom.avgTemp - room.avgTemp) * rate * scaledDt / cellCount
            end
        end

        -- Wind chill: additional loss through walls when wind is harsh
        if GameState.windChill and GameState.windChill < -5 then
            local wallCount = #room.wallSegs
            if wallCount > 0 then
                local insSum = 0
                for _, seg in ipairs(room.wallSegs) do
                    insSum = insSum + seg.insulation
                end
                local avgIns = insSum / wallCount
                local windFactor = math.abs(GameState.windChill) / 40
                local windLeak = windFactor * (1 - avgIns) * 0.015 * dt
                room.avgTemp = room.avgTemp +
                    (ambient - room.avgTemp) * windLeak
            end
        end
    end

    -------------------------------------------------------------------
    -- Phase 4: Write room temps to per-tile tempData (for rendering)
    -- All tiles in a room share the room's temperature.
    -- Must write to the correct depth layer's tempData.
    -------------------------------------------------------------------
    for rid, room in pairs(rooms) do
        local layerTempData = world.rawTempData(room.depth)
        if layerTempData then
            for _, ti in ipairs(room.tiles) do
                layerTempData[ti] = room.avgTemp
            end
        end
    end

    -------------------------------------------------------------------
    -- Phase 4.5: Danger zone tile offsets
    -- Extreme heat/cold sources affect nearby tiles directly.
    -- This creates localized hot/cold spots within a room:
    -- the room stays at target temp, but tiles near a nuclear reactor
    -- or cryogenic cooler are hotter/colder — dangerous to colonists.
    -------------------------------------------------------------------
    for key, danger in pairs(heatDanger) do
        if not heatSources[key] then goto next_danger end
        local dDepth = math.floor(key / 100000000)
        local idx = key - dDepth * 100000000
        local cy = math.floor((idx - 1) / w)
        local cx = (idx - 1) % w
        local layerTempData = world.rawTempData(dDepth)
        if layerTempData then
            for dy2 = -danger.radius, danger.radius do
                for dx2 = -danger.radius, danger.radius do
                    local nx, ny = cx + dx2, cy + dy2
                    if world.inBounds(nx, ny) then
                        -- Fall off with distance
                        local dist = math.max(math.abs(dx2), math.abs(dy2))
                        local falloff = 1.0 - (dist / (danger.radius + 1))
                        local ni = ny * w + nx + 1
                        layerTempData[ni] = layerTempData[ni] + danger.tempOffset * falloff
                    end
                end
            end
        end
        ::next_danger::
    end

    -------------------------------------------------------------------
    -- Phase 5: Outdoor tiles — snap toward ambient
    -- Point heat sources on outdoor tiles still warm locally.
    -- Generator zones provide diminished outdoor warmth.
    -- Only surface (depth 0) has outdoor tiles.
    -------------------------------------------------------------------
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local idx = y * w + x + 1
            if rData[idx] == 0 then
                local cur = tempData[idx]

                -- Point heat sources on outdoor tiles (surface = depth 0, key = idx)
                local hs = heatSources[idx]  -- depth-0 key: 0*100000000+idx = idx
                if hs then
                    local effectiveWatts = math.abs(hs) * warmthMult
                    local target = heatTargets[idx] or (ambient + effectiveWatts * 0.3)
                    if hs > 0 and cur < target then
                        cur = cur + effectiveWatts * dt * 0.1
                        if cur > target then cur = target end
                    elseif hs < 0 and cur > target then
                        cur = cur - effectiveWatts * dt * 0.1
                        if cur < target then cur = target end
                    end
                end

                -- Bleed toward ambient
                cur = cur + (ambient - cur) * OUTDOOR_SNAP * dt * 20
                tempData[idx] = cur
            end
        end
    end

    -- Generator heat on outdoor tiles (radius-based, diminished)
    if genOk and Generator.getHeatBonus then
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                if rData[idx] == 0 then
                    local bonus = Generator.getHeatBonus(x, y) * warmthMult
                    if bonus > 0 then
                        local target = ambient + bonus * 0.5
                        if tempData[idx] < target then
                            tempData[idx] = tempData[idx] + bonus * dt * 0.2
                            if tempData[idx] > target then
                                tempData[idx] = target
                            end
                        end
                    end
                end
            end
        end
    end

    -- Underground layers: unroomed tiles converge to geothermal baseline
    local pok2, Planet2 = pcall(require, 'src.world.planet')
    local UNDERGROUND_BASE_TEMP = -20
    if pok2 then
        UNDERGROUND_BASE_TEMP = Planet2.get('thermal.undergroundBaseTemp', -20)
    end
    for depth, layer in world.allLayers() do
        if depth > 0 then
            local uTemp = layer.temps
            local uRoom = layer.rooms
            for i = 1, w * h do
                if uRoom[i] == 0 then
                    uTemp[i] = uTemp[i] + (UNDERGROUND_BASE_TEMP - uTemp[i]) * 0.1 * dt
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Thermal.getRooms()
    return rooms
end

function Thermal.getRoomTemp(roomId)
    if rooms[roomId] then
        return rooms[roomId].avgTemp
    end
    return GameState.getEffectiveTemp()
end

function Thermal.getTileTemp(x, y)
    return world.getTemp(x, y)
end

return Thermal
