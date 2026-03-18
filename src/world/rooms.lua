-- rooms.lua — Room type detection, quality scoring, temperature comfort
-- Identifies room types based on furniture contents (beds, stoves, workbenches).
-- Temperature comfort tiers affect colonist morale, work speed, rest quality.
-- Impressiveness uses RimWorld-style minimum-stat bottleneck formula.

local ECS        = require('src.ecs.ecs')
local Thermal    = require('src.sim.thermal')
local Tiles      = require('src.world.tiles')

local Rooms = {}

---------------------------------------------------------------------------
-- Temperature comfort tiers (RimWorld-style)
-- morale: flat morale modifier for colonists in this room
-- workMult: work speed multiplier
-- restMult: rest quality multiplier (how fast rest need recovers)
---------------------------------------------------------------------------

Rooms.TEMP_TIERS = {
    { name = 'freezing',    maxTemp = -10, morale = -5, workMult = 0.6,  restMult = 0.7 },
    { name = 'cold',        maxTemp = 5,   morale = -3, workMult = 0.8,  restMult = 0.85 },
    { name = 'cool',        maxTemp = 15,  morale = -1, workMult = 0.9,  restMult = 0.95 },
    { name = 'comfortable', maxTemp = 25,  morale = 2,  workMult = 1.0,  restMult = 1.0 },
    { name = 'warm',        maxTemp = 35,  morale = 1,  workMult = 1.0,  restMult = 1.05 },
    { name = 'hot',         maxTemp = 999, morale = -2, workMult = 0.9,  restMult = 0.9 },
}

function Rooms.getTempTier(temp)
    for _, tier in ipairs(Rooms.TEMP_TIERS) do
        if temp <= tier.maxTemp then
            return tier
        end
    end
    return Rooms.TEMP_TIERS[#Rooms.TEMP_TIERS]
end

---------------------------------------------------------------------------
-- Room type definitions
---------------------------------------------------------------------------

Rooms.TYPES = {
    private_bedroom = {
        name     = 'Private Bedroom',
        requires = { bed = 1 },
        maxBeds  = 1,
        minSize  = 4,
        maxSize  = 12,
        morale   = 3,
    },
    hospital = {
        name     = 'Hospital',
        requires = { med_bench = 1, bed = 1 },
        minSize  = 8,
        morale   = 0,
        healMult = 1.3,
    },
    lab = {
        name     = 'Laboratory',
        requires = { drug_lab = 1 },
        minSize  = 10,
        morale   = 0,
    },
    kitchen = {
        name     = 'Kitchen',
        requires = { kitchen = 1 },
        minSize  = 8,
        morale   = 0,
    },
    dining_hall = {
        name         = 'Dining Hall',
        requires     = { decoration = 1 },
        minSize      = 12,
        minFurniture = 3,
        morale       = 2,
    },
    rec_room = {
        name     = 'Recreation Room',
        requires = { decoration = 2 },
        minSize  = 10,
        morale   = 4,
    },
    workshop = {
        name     = 'Workshop',
        requires = { workbench = 1 },
        minSize  = 9,
        morale   = 0,
    },
    barracks = {
        name     = 'Barracks',
        requires = { bed = 1 },
        minSize  = 6,
        morale   = 0,
    },
    containment_lab = {
        name     = 'Containment Lab',
        requires = { containment_cell = 1 },
        minSize  = 6,
        morale   = -1,
    },
}

-- Classification priority: more specific types first
local CLASSIFY_ORDER = {
    'containment_lab', 'private_bedroom', 'hospital', 'lab', 'kitchen',
    'dining_hall', 'rec_room', 'workshop', 'barracks',
}

-- Cached room classifications: { [roomId] = { type, quality, tempTier, ... } }
local roomInfo = {}

local detectCooldown = 0
local DETECT_INTERVAL = 3

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function countContents(roomTiles, mapW)
    local tileSet = {}
    for _, idx in ipairs(roomTiles) do
        tileSet[idx] = true
    end

    local contents = { bed = 0, furniture = 0, decoration = 0, beauty = 0 }
    local machineTypes = {}

    for _, comps in ECS.query('pos', 'bed') do
        local px, py = comps.pos.x, comps.pos.y
        local idx = py * mapW + px + 1
        if tileSet[idx] then
            contents.bed = contents.bed + 1
            contents.furniture = contents.furniture + 1
        end
    end

    for _, comps in ECS.query('pos', 'machine') do
        local px, py = comps.pos.x, comps.pos.y
        local idx = py * mapW + px + 1
        if tileSet[idx] then
            local mType = comps.machine.type
            machineTypes[mType] = (machineTypes[mType] or 0) + 1
            contents.furniture = contents.furniture + 1
        end
    end

    for _, comps in ECS.query('pos', 'decoration') do
        local px, py = comps.pos.x, comps.pos.y
        local idx = py * mapW + px + 1
        if tileSet[idx] then
            contents.decoration = contents.decoration + 1
            contents.furniture = contents.furniture + 1
            contents.beauty = contents.beauty + (comps.decoration.beauty or 1)
        end
    end

    for _, comps in ECS.query('pos', 'containment_cell') do
        local px, py = comps.pos.x, comps.pos.y
        local idx = py * mapW + px + 1
        if tileSet[idx] then
            contents.containment_cell = (contents.containment_cell or 0) + 1
            contents.furniture = contents.furniture + 1
        end
    end

    for mType, count in pairs(machineTypes) do
        contents[mType] = count
    end

    return contents
end

local function classifyRoom(contents, tileCount)
    for _, typeId in ipairs(CLASSIFY_ORDER) do
        local def = Rooms.TYPES[typeId]
        if tileCount >= def.minSize then
            if def.maxSize and tileCount > def.maxSize then
                goto continue
            end
            if def.maxBeds and contents.bed > def.maxBeds then
                goto continue
            end
            if def.minFurniture and contents.furniture < def.minFurniture then
                goto continue
            end
            local meetsReqs = true
            for reqKey, reqCount in pairs(def.requires) do
                if (contents[reqKey] or 0) < reqCount then
                    meetsReqs = false
                    break
                end
            end
            if meetsReqs then
                return typeId
            end
        end
        ::continue::
    end
    return nil
end

local function scoreFloors(roomTiles, tData)
    local score = 0
    for _, idx in ipairs(roomTiles) do
        local tile = tData[idx]
        if tile == Tiles.FLOOR_INSULATED then
            score = score + 4
        elseif tile == Tiles.FLOOR_STONE or tile == Tiles.FLOOR_METAL then
            score = score + 3
        elseif tile == Tiles.FLOOR_WOOD then
            score = score + 2
        elseif tile == Tiles.DOOR or tile == Tiles.DOOR_SEALED then
            score = score + 1
        end
    end
    return score / math.max(1, #roomTiles)
end

-- RimWorld-style impressiveness: ((avg + min) / 2) * scale
-- A single bad factor drags down the whole room
local function calcImpressiveness(factors)
    local sum = 0
    local minF = factors[1]
    for _, f in ipairs(factors) do
        sum = sum + f
        if f < minF then minF = f end
    end
    local avg = sum / #factors
    return ((avg + minF) / 2) * 10
end

---------------------------------------------------------------------------
-- Classify all rooms
---------------------------------------------------------------------------

function Rooms.classify()
    local World = require('src.world.tilemap')
    local thermalRooms = Thermal.getRooms()
    local mapW = World.width()
    local tData = World.rawTileData()

    roomInfo = {}

    for rid, room in pairs(thermalRooms) do
        local contents = countContents(room.tiles, mapW)
        local roomType = classifyRoom(contents, #room.tiles)

        local sizeScore = math.min(10, #room.tiles / 4)
        local floorScore = scoreFloors(room.tiles, tData)

        -- Temperature comfort tier
        local tempTier = Rooms.getTempTier(room.avgTemp)
        local tempScore
        if     tempTier.name == 'comfortable' then tempScore = 3
        elseif tempTier.name == 'warm'        then tempScore = 2.5
        elseif tempTier.name == 'cool'        then tempScore = 1.5
        elseif tempTier.name == 'cold'        then tempScore = 0.5
        elseif tempTier.name == 'hot'         then tempScore = 1
        else                                       tempScore = 0
        end

        local furnitureScore = math.min(5, contents.furniture)

        -- Air quality
        local airScore = 2
        local ok, Atmosphere = pcall(require, 'src.sim.atmosphere')
        if ok and Atmosphere.getRoomO2 then
            local o2 = Atmosphere.getRoomO2(rid)
            if o2 > 80 then     airScore = 3
            elseif o2 > 50 then airScore = 1
            else                airScore = 0
            end
        end

        -- Beauty from decorations, scaled by room size
        local beautyScore = math.min(3, contents.beauty / math.max(1, #room.tiles) * 10)

        -- Cleanliness (filth drags down room quality)
        local cleanScore = 3
        local filthOk, FilthMod = pcall(require, 'src.sim.filth')
        if filthOk and FilthMod.getRoomFilth then
            local avgFilth = FilthMod.getRoomFilth(room.tiles)
            if     avgFilth < 5  then cleanScore = 3
            elseif avgFilth < 15 then cleanScore = 2
            elseif avgFilth < 30 then cleanScore = 1
            else                      cleanScore = 0
            end
        end

        local impressiveness = calcImpressiveness({
            sizeScore, floorScore, tempScore, furnitureScore, airScore, beautyScore, cleanScore,
        })

        local typeDef = roomType and Rooms.TYPES[roomType] or nil

        roomInfo[rid] = {
            type           = roomType,
            typeName       = typeDef and typeDef.name or 'Room',
            quality        = sizeScore + floorScore + tempScore + furnitureScore + airScore,
            impressiveness = impressiveness,
            contents       = contents,
            size           = #room.tiles,
            sealed         = room.sealed,
            avgTemp        = room.avgTemp,
            tempTier       = tempTier,
            typeMorale     = typeDef and typeDef.morale or 0,
        }
    end
end

---------------------------------------------------------------------------
-- Step — periodic reclassification
---------------------------------------------------------------------------

function Rooms.step(dt)
    detectCooldown = detectCooldown - dt
    if detectCooldown <= 0 then
        Rooms.classify()
        detectCooldown = DETECT_INTERVAL
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Rooms.getRoomInfo(roomId)
    return roomInfo[roomId]
end

function Rooms.getAllRoomInfo()
    return roomInfo
end

function Rooms.getRoomType(roomId)
    local info = roomInfo[roomId]
    return info and info.type or nil
end

function Rooms.getRoomQuality(roomId)
    local info = roomInfo[roomId]
    return info and info.quality or 0
end

-- Temperature comfort tier for a room (colonist needs use this)
function Rooms.getRoomTempTier(roomId)
    local info = roomInfo[roomId]
    if info and info.tempTier then
        return info.tempTier
    end
    local GameState = require('src.game_state')
    return Rooms.getTempTier(GameState.getEffectiveTemp())
end

-- Combined morale from room type + temperature comfort + beauty
function Rooms.getRoomMorale(roomId)
    local info = roomInfo[roomId]
    if not info then return 0 end
    local baseMorale = (info.typeMorale or 0) + (info.tempTier and info.tempTier.morale or 0)
    -- Beauty bonus: impressiveness / 5 → up to +2 morale from a well-decorated room
    local beautyMorale = math.min(2, (info.impressiveness or 0) / 5)
    return baseMorale + beautyMorale
end

-- Work speed multiplier from room temperature
function Rooms.getRoomWorkMult(roomId)
    local info = roomInfo[roomId]
    if info and info.tempTier then
        return info.tempTier.workMult
    end
    return 1.0
end

-- Rest quality multiplier from room temperature
function Rooms.getRoomRestMult(roomId)
    local info = roomInfo[roomId]
    if info and info.tempTier then
        return info.tempTier.restMult
    end
    return 1.0
end

-- Hospital check for healing speed bonus
function Rooms.isHospital(roomId)
    local info = roomInfo[roomId]
    return info and info.type == 'hospital'
end

-- Heal multiplier: hospital bonus, cold penalty
function Rooms.getHealMult(roomId)
    local info = roomInfo[roomId]
    if not info then return 1.0 end
    local base = 1.0
    if info.type == 'hospital' then
        base = Rooms.TYPES.hospital.healMult
    end
    if info.tempTier then
        if     info.tempTier.name == 'freezing' then base = base * 0.5
        elseif info.tempTier.name == 'cold'     then base = base * 0.7
        end
    end
    return base
end

return Rooms
