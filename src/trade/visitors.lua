-- visitors.lua — Non-merchant visitors: diplomats, travelers, hostile scouts
-- Each visitor type arrives at map edge, walks to colony, does their thing, leaves.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

local Visitors = {}

---------------------------------------------------------------------------
-- Visitor type definitions
---------------------------------------------------------------------------

local VISITOR_TYPES = {
    diplomat = {
        name = 'Faction Diplomat',
        stayDuration = 90,
        minDay = 15,
    },
    traveler = {
        name = 'Traveler Band',
        stayDuration = 60,
        minDay = 5,
    },
    hostile_scout = {
        name = 'Hostile Scout',
        stayDuration = 45,
        minDay = 12,
    },
    refugee_group = {
        name = 'Refugee Group',
        stayDuration = 120,
        minDay = 8,
    },
}

Visitors.VISITOR_TYPES = VISITOR_TYPES

---------------------------------------------------------------------------
-- Module state
---------------------------------------------------------------------------

local activeVisitors = {}  -- { [entityId] = visitorData }
local log = {}
local MAX_LOG = 15

local function logMsg(msg)
    log[#log + 1] = {
        msg  = msg,
        day  = GameState.day,
        hour = GameState.hour,
    }
    while #log > MAX_LOG do table.remove(log, 1) end
end

---------------------------------------------------------------------------
-- Spawn helpers
---------------------------------------------------------------------------

local function pickEdgePosition()
    local World = require('src.world.tilemap')
    local w = World.width()
    local h = World.height()
    local side = math.random(4)
    local x, y

    if side == 1 then
        x = math.random(5, w - 5); y = 2
    elseif side == 2 then
        x = math.random(5, w - 5); y = h - 3
    elseif side == 3 then
        x = 2; y = math.random(5, h - 5)
    else
        x = w - 3; y = math.random(5, h - 5)
    end

    if not World.isWalkable(x, y, 0) then
        for dx = -2, 2 do
            for dy = -2, 2 do
                if World.isWalkable(x + dx, y + dy, 0) then
                    return x + dx, y + dy
                end
            end
        end
    end
    return x, y
end

local function spawnVisitorEntity(x, y, visitorType, data)
    local id = ECS.spawn()
    ECS.set(id, 'pos', {
        x = x, y = y, prevX = x, prevY = y,
        targetX = nil, targetY = nil,
    })
    ECS.set(id, 'visitor', {
        type       = visitorType,
        arrived    = false,
        departing  = false,
        stayTimer  = VISITOR_TYPES[visitorType].stayDuration,
        spawnX     = x,
        spawnY     = y,
        data       = data or {},
        resolved   = false,
    })
    ECS.set(id, 'path', { nodes = nil, index = 1, moveTimer = 0 })
    activeVisitors[id] = true
    return id
end

---------------------------------------------------------------------------
-- Diplomat: offers alliance quest or rep boost
---------------------------------------------------------------------------

function Visitors.spawnDiplomat(factionId)
    local fOk, Factions = pcall(require, 'src.colony.factions')
    if not fOk then return nil end

    -- Pick a random non-hostile faction if not specified
    if not factionId then
        local available = Factions.getAvailableMerchantFactions()
        if #available == 0 then return nil end
        factionId = available[math.random(#available)].factionId
    end

    local def = Factions.FACTION_DEFS[factionId]
    if not def then return nil end

    local sx, sy = pickEdgePosition()
    local id = spawnVisitorEntity(sx, sy, 'diplomat', {
        factionId = factionId,
        factionName = def.name,
        questType = ({ 'alliance_offer', 'trade_request', 'intel_share' })[math.random(3)],
    })

    logMsg('A diplomat from ' .. def.name .. ' is approaching.')
    return id
end

---------------------------------------------------------------------------
-- Traveler band: rest, share intel, leave
---------------------------------------------------------------------------

function Visitors.spawnTravelers()
    local sx, sy = pickEdgePosition()
    local groupSize = math.random(2, 4)

    -- They share intel as a resource/morale bonus
    local intel = ({
        { type = 'map', desc = 'shared map data', resource = 'thermalCores', amount = math.random(1, 3) },
        { type = 'warning', desc = 'warned of approaching danger', morale = 5 },
        { type = 'story', desc = 'shared stories from the rim', morale = 8 },
    })[math.random(3)]

    local id = spawnVisitorEntity(sx, sy, 'traveler', {
        groupSize = groupSize,
        intel = intel,
    })

    logMsg('A band of ' .. groupSize .. ' travelers spotted heading this way.')
    return id
end

---------------------------------------------------------------------------
-- Hostile scout: cases the base, killing them prevents next raid
---------------------------------------------------------------------------

function Visitors.spawnScout()
    local sx, sy = pickEdgePosition()
    local id = spawnVisitorEntity(sx, sy, 'hostile_scout', {
        spotted = false,
        killed = false,
    })

    -- Scout is a creature entity with low health (killable)
    local cok, Creatures = pcall(require, 'src.creatures.creatures')
    if cok then
        -- Mark as hostile creature-like
        ECS.set(id, 'creature', {
            species = 'scout',
            hp = 30, maxHp = 30,
            hostile = true,
            attack = 5, defense = 2,
        })
    end

    logMsg('Movement detected at the colony perimeter. Could be a scout.')
    return id
end

---------------------------------------------------------------------------
-- Refugee group: request shelter, chance to join
---------------------------------------------------------------------------

function Visitors.spawnRefugees()
    local sx, sy = pickEdgePosition()
    local groupSize = math.random(1, 3)
    local id = spawnVisitorEntity(sx, sy, 'refugee_group', {
        groupSize = groupSize,
        joinChance = 0.4 + groupSize * 0.1,
    })

    logMsg(groupSize .. ' refugees spotted approaching the colony.')
    return id
end

---------------------------------------------------------------------------
-- Visitor resolution (called when visitor arrives and stay timer expires)
---------------------------------------------------------------------------

local function resolveVisitor(id)
    local visitor = ECS.get(id, 'visitor')
    if not visitor or visitor.resolved then return end
    visitor.resolved = true

    local data = visitor.data
    local hok, Hope = pcall(require, 'src.colony.hope')

    if visitor.type == 'diplomat' then
        local fOk, Factions = pcall(require, 'src.colony.factions')
        if fOk and data.factionId then
            if data.questType == 'alliance_offer' then
                Factions.modifyRep(data.factionId, 15)
                logMsg(data.factionName .. ' diplomat offers improved relations. +15 reputation.')
            elseif data.questType == 'trade_request' then
                Factions.modifyRep(data.factionId, 8)
                local Items = getItems()
                local coreAmt = math.random(3, 6)
                if Items then Items.spawn(GameState.startX, GameState.startY, 'thermalCores', coreAmt, nil, 0)
                else GameState.addResource('thermalCores', coreAmt) end
                logMsg(data.factionName .. ' diplomat brokered a trade deal. Cores received.')
            elseif data.questType == 'intel_share' then
                Factions.modifyRep(data.factionId, 5)
                -- Delay next raid by 1 day
                local rOk, Raids = pcall(require, 'src.sim.raids')
                if rOk and Raids.delayNextRaid then Raids.delayNextRaid(1 * 24 * 60) end
                logMsg(data.factionName .. ' diplomat shares threat intelligence.')
            end
        end
        if hok then Hope.applyDelta(3, -1) end

    elseif visitor.type == 'traveler' then
        local intel = data.intel
        if intel then
            if intel.resource then
                local Items = getItems()
                if Items then Items.spawn(GameState.startX, GameState.startY, intel.resource, intel.amount, nil, 0)
                else GameState.addResource(intel.resource, intel.amount) end
            end
            if intel.morale then
                for cid, comps in ECS.query('colonist', 'needs') do
                    comps.needs.morale = math.min(100, comps.needs.morale + intel.morale)
                end
            end
            logMsg('Travelers ' .. (intel.desc or 'visited') .. ' before moving on.')
        end

    elseif visitor.type == 'refugee_group' then
        local rok, Recruitment = pcall(require, 'src.colonist.recruitment')
        if rok then
            local joined = 0
            for i = 1, data.groupSize do
                if math.random() < data.joinChance then
                    Recruitment.spawnRefugees(1)
                    joined = joined + 1
                end
            end
            if joined > 0 then
                logMsg(joined .. ' refugee(s) decided to stay and join the colony.')
                if hok then Hope.applyDelta(3, -1) end
            else
                logMsg('The refugees rested and moved on.')
            end
        end
    end
end

---------------------------------------------------------------------------
-- Scout kill handler (called when scout creature dies)
---------------------------------------------------------------------------

function Visitors.onScoutKilled(entityId)
    local visitor = ECS.get(entityId, 'visitor')
    if not visitor or visitor.type ~= 'hostile_scout' then return end

    visitor.data.killed = true
    -- Delay next raid
    local rOk, Raids = pcall(require, 'src.sim.raids')
    if rOk and Raids.delayNextRaid then
        Raids.delayNextRaid(3 * 24 * 60)
        logMsg('Scout eliminated. Hostile forces will take longer to find the colony.')
    end

    activeVisitors[entityId] = nil
end

---------------------------------------------------------------------------
-- ECS system: visitor movement and lifecycle
---------------------------------------------------------------------------

local VISITOR_SPEED = 2.0

local function visitorSystem(dt, id, comps)
    local pos     = comps.pos
    local visitor = comps.visitor
    local path    = comps.path

    pos.prevX = pos.x
    pos.prevY = pos.y

    -- Walk along path
    if path.nodes and path.index <= #path.nodes then
        local World = require('src.world.tilemap')
        path.moveTimer = path.moveTimer + dt * VISITOR_SPEED
        while path.moveTimer >= 1 and path.index <= #path.nodes do
            local node = path.nodes[path.index]
            path.moveTimer = path.moveTimer - 1
            if World.inBounds(node.x, node.y) then
                pos.x = node.x
                pos.y = node.y
            end
            path.index = path.index + 1
        end
        if path.index > #path.nodes then
            path.nodes = nil
            path.index = 1
        end
    end

    local ARRIVAL_DIST = 5

    local function isNear(px, py, tx, ty, dist)
        local dx = px - tx
        local dy = py - ty
        return (dx * dx + dy * dy) <= dist * dist
    end

    local function pathTo(eid, tx, ty)
        local Pathfind = require('src.util.pathfind')
        local World = require('src.world.tilemap')
        local p = ECS.get(eid, 'pos')
        if not p then return end
        local nodes = Pathfind.find(p.x, p.y, tx, ty, World, eid)
        local pt = ECS.get(eid, 'path')
        if pt then pt.nodes = nodes; pt.index = 1; pt.moveTimer = 0 end
    end

    -- Phase: traveling to colony
    if not visitor.arrived and not visitor.departing then
        if isNear(pos.x, pos.y, GameState.startX, GameState.startY, ARRIVAL_DIST) then
            visitor.arrived = true
        elseif not path.nodes then
            pathTo(id, GameState.startX, GameState.startY)
        end
        return
    end

    -- Phase: staying
    if visitor.arrived and not visitor.departing then
        visitor.stayTimer = visitor.stayTimer - dt
        if visitor.stayTimer <= 0 then
            resolveVisitor(id)
            visitor.departing = true
            pathTo(id, visitor.spawnX, visitor.spawnY)
        end
        return
    end

    -- Phase: departing
    if visitor.departing then
        if isNear(pos.x, pos.y, visitor.spawnX, visitor.spawnY, 3) then
            activeVisitors[id] = nil
            ECS.destroy(id)
        elseif not path.nodes then
            pathTo(id, visitor.spawnX, visitor.spawnY)
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Visitors.getActiveVisitors()
    local result = {}
    for id in pairs(activeVisitors) do
        if ECS.isAlive(id) then
            local v = ECS.get(id, 'visitor')
            local p = ECS.get(id, 'pos')
            if v then
                result[#result + 1] = {
                    id = id,
                    type = v.type,
                    name = VISITOR_TYPES[v.type] and VISITOR_TYPES[v.type].name or v.type,
                    arrived = v.arrived,
                    departing = v.departing,
                    pos = p,
                }
            end
        else
            activeVisitors[id] = nil
        end
    end
    return result
end

function Visitors.getLog() return log end

function Visitors.hasActiveVisitor(vtype)
    for id in pairs(activeVisitors) do
        if ECS.isAlive(id) then
            local v = ECS.get(id, 'visitor')
            if v and v.type == vtype then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Visitors.getState()
    -- Active visitors are ECS entities; just track the IDs
    local ids = {}
    for id in pairs(activeVisitors) do
        if ECS.isAlive(id) then ids[#ids + 1] = id end
    end
    return { activeIds = ids, log = log }
end

function Visitors.restoreState(state)
    if not state then return end
    log = state.log or {}
    activeVisitors = {}
    if state.activeIds then
        for _, id in ipairs(state.activeIds) do
            if ECS.isAlive(id) then activeVisitors[id] = true end
        end
    end
end

---------------------------------------------------------------------------
-- Register ECS systems
---------------------------------------------------------------------------

function Visitors.registerSystems()
    ECS.addSystem('visitor_lifecycle', { 'pos', 'visitor', 'path' }, visitorSystem, 51)
end

Visitors.registerSystems()

return Visitors
