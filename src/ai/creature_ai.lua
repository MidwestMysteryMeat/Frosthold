-- creature_ai.lua — Creature AI behavior system (split from creatures.lua)
-- Handles idle wander, flee, chase, attack, breaching, lure, ranged kiting,
-- fear aura, night hunting, director-biased movement, and tamed creature AI.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Pathfind  = require('src.util.pathfind')
local Occupancy = require('src.util.occupancy')

local CreatureAI = {}

-- Lazy-loaded modules: avoids circular require and keeps pcall out of hot path
local SPECIES = nil
local _World, _LOS, _Ranged, _Equipment, _Body, _Wounds
local _Hope, _Social, _ElasticD, _Items, _Tiles, _Director, _ColMod

local function getSpecies()
    if not SPECIES then
        local Creatures = require('src.creatures.creatures')
        SPECIES = Creatures.SPECIES
    end
    return SPECIES
end

local function lazyLoad()
    if _World then return end
    _World = require('src.world.tilemap')
    local ok
    ok, _LOS       = pcall(require, 'src.sim.line_of_sight')
    if not ok then _LOS = nil end
    ok, _Ranged     = pcall(require, 'src.combat.ranged')
    if not ok then _Ranged = nil end
    ok, _Equipment  = pcall(require, 'src.colonist.equipment')
    if not ok then _Equipment = nil end
    ok, _Body       = pcall(require, 'src.combat.body')
    if not ok then _Body = nil end
    ok, _Wounds     = pcall(require, 'src.combat.wounds')
    if not ok then _Wounds = nil end
    ok, _Hope       = pcall(require, 'src.colony.hope')
    if not ok then _Hope = nil end
    ok, _Social     = pcall(require, 'src.colonist.social')
    if not ok then _Social = nil end
    ok, _ElasticD   = pcall(require, 'src.sim.elastic_difficulty')
    if not ok then _ElasticD = nil end
    ok, _Items      = pcall(require, 'src.world.items')
    if not ok then _Items = nil end
    ok, _Tiles      = pcall(require, 'src.world.tiles')
    if not ok then _Tiles = nil end
    ok, _Director   = pcall(require, 'src.ai.director')
    if not ok then _Director = nil end
    ok, _ColMod     = pcall(require, 'src.colonist.colonist')
    if not ok then _ColMod = nil end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function distSq(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return dx * dx + dy * dy
end

-- Per-tick colonist position cache: avoids O(creatures * colonists) ECS queries
local _colonistCache = {}   -- { {id, x, y, depth, state, needs} ... }
local _colonistCacheTick = -1

local function rebuildColonistCache()
    local tick = GameState.tick or 0
    if tick == _colonistCacheTick then return end
    _colonistCacheTick = tick
    local cache = _colonistCache
    local n = 0
    for cid, ccomps in ECS.query('pos', 'colonist') do
        local ccol = ccomps.colonist
        if ccol.state ~= 'dead' then
            n = n + 1
            local entry = cache[n]
            if not entry then
                entry = {}
                cache[n] = entry
            end
            entry.id = cid
            entry.x = ccomps.pos.x
            entry.y = ccomps.pos.y
            entry.depth = ccomps.pos.depth
            entry.needs = ccomps.needs
        end
    end
    -- Trim stale entries
    for i = n + 1, #cache do
        cache[i] = nil
    end
end

---------------------------------------------------------------------------
-- Creature AI system
---------------------------------------------------------------------------

local function creatureAI(dt, id, comps)
    local cr   = comps.creature
    local pos  = comps.pos
    local path = comps.path

    if cr.state == 'dead' then return end

    -- Tamed creatures use simplified AI: idle wander near pen/tamer
    if ECS.has(id, 'tamed') then
        pos.prevX = pos.x
        pos.prevY = pos.y
        -- Just idle wander (taming system handles role behavior)
        if not (path.nodes and path.index <= #path.nodes) then
            cr.state = 'idle'
            if math.random() < 0.005 then
                lazyLoad()
                local wx = pos.x + math.random(-3, 3)
                local wy = pos.y + math.random(-3, 3)
                local pd = pos.depth or 0
                if _World.inBounds(wx, wy) and _World.isWalkable(wx, wy, pd) then
                    local route = Pathfind.find(pos.x, pos.y, wx, wy, _World, id, pd, pd)
                    if route then
                        cr.state = 'wander'
                        path.nodes = route
                        path.index = 1
                        path.moveTimer = 0
                    end
                end
            end
        else
            -- Continue moving along path
            path.moveTimer = path.moveTimer + dt * cr.speed
            while path.moveTimer >= 1 and path.nodes and path.index <= #path.nodes do
                local node = path.nodes[path.index]
                path.moveTimer = path.moveTimer - 1
                Occupancy.release(pos.x, pos.y, id, pos.depth)
                pos.x = node.x
                pos.y = node.y
                pos.depth = node.depth or 0
                Occupancy.reserve(pos.x, pos.y, id, pos.depth)
                path.index = path.index + 1
            end
            if path.nodes and path.index > #path.nodes then
                path.nodes = nil
                path.index = 1
            end
        end
        return
    end

    -- Store prev for interpolation
    pos.prevX = pos.x
    pos.prevY = pos.y

    -- Movement along path
    if path.nodes and path.index <= #path.nodes then
        path.moveTimer = path.moveTimer + dt * cr.speed
        while path.moveTimer >= 1 and path.nodes and path.index <= #path.nodes do
            local node = path.nodes[path.index]
            local nodeDepth = node.depth or 0
            if Occupancy.isOccupiedBy(node.x, node.y, id, nodeDepth) then
                path.nodes = nil
                path.index = 1
                path.moveTimer = 0
                break
            end
            path.moveTimer = path.moveTimer - 1
            Occupancy.release(pos.x, pos.y, id, pos.depth)
            -- Update facing from movement direction
            local mdx = node.x - pos.x
            local mdy = node.y - pos.y
            if mdx ~= 0 or mdy ~= 0 then
                cr.facing = math.atan2(mdy, mdx)
            end
            pos.x = node.x
            pos.y = node.y
            pos.depth = nodeDepth
            Occupancy.reserve(pos.x, pos.y, id, pos.depth)
            path.index = path.index + 1
        end
        if path.nodes and path.index > #path.nodes then
            path.nodes = nil
            path.index = 1
        end
        -- Don't re-evaluate AI while moving
        return
    end

    lazyLoad()
    local species = getSpecies()

    -- Find nearest colonist (vision cone + LOS aware) using per-tick cache
    rebuildColonistCache()
    local creatureFov = _LOS and (cr.hostile and _LOS.CREATURE_FOV or _LOS.PREY_FOV) or math.pi * 2
    local creatureHalfFov = creatureFov / 2
    local facing = cr.facing or 0

    local nearestId, nearestDist = nil, math.huge
    for i = 1, #_colonistCache do
        local c = _colonistCache[i]
        local d = distSq(pos.x, pos.y, c.x, c.y)
        if d < nearestDist then
            if _LOS then
                if _LOS.canSee(pos.x, pos.y, c.x, c.y, facing, creatureHalfFov, math.sqrt(d) + 1) then
                    nearestDist = d
                    nearestId = c.id
                end
            else
                nearestDist = d
                nearestId = c.id
            end
        end
    end
    local nearDist = math.sqrt(nearestDist)

    -- Night hunter: doubled aggro range at night (hour 20-6)
    local sp = species[cr.species]
    local effectiveAggro = cr.aggroRange
    if sp and sp.nightHunter then
        local h = GameState.hour or 12
        if h >= 20 or h < 6 then
            effectiveAggro = cr.aggroRange * 2
        end
    end

    -- Fear aura: drain morale of nearby colonists (uses cached positions)
    if sp and sp.fearAura and sp.fearAura > 0 then
        local fearRangeSq = sp.fearAura * sp.fearAura
        local moraleDrain = 0.1 * dt
        for i = 1, #_colonistCache do
            local c = _colonistCache[i]
            if c.needs and distSq(pos.x, pos.y, c.x, c.y) <= fearRangeSq then
                c.needs.morale = math.max(0, c.needs.morale - moraleDrain)
            end
        end
    end

    if cr.hostile and effectiveAggro > 0 then
        -- Hostile creature: chase if in aggro range
        if nearestId and nearDist <= effectiveAggro then
            cr.state = 'chase'
            cr.target = nearestId
            -- Face toward target
            local tpos = ECS.get(nearestId, 'pos')
            if tpos then
                cr.facing = math.atan2(tpos.y - pos.y, tpos.x - pos.x)
            end

            -- Ranged attack: fire projectile if in range but not adjacent
            if sp and sp.rangedDamage and nearDist > 1.5 and nearDist <= (sp.rangedRange or 6) then
                cr.attackCooldown = cr.attackCooldown - dt
                if cr.attackCooldown <= 0 then
                    cr.attackCooldown = sp.rangedCooldown or 2.0
                    if _Ranged and _Ranged.creatureFire then
                        _Ranged.creatureFire(id, nearestId, sp.rangedDamage, sp.rangedAccuracy or 0.5)
                    end
                end
                -- Kite: if target is closing in, back away
                if tpos and nearDist < (sp.rangedRange or 6) * 0.4 then
                    local dx = pos.x - tpos.x
                    local dy = pos.y - tpos.y
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 0 then dx, dy = dx / len, dy / len end
                    local kx = math.floor(pos.x + dx * 3)
                    local ky = math.floor(pos.y + dy * 3)
                    kx = math.max(1, math.min(_World.width() - 2, kx))
                    ky = math.max(1, math.min(_World.height() - 2, ky))
                    local pd = pos.depth or 0
                    if _World.isWalkable(kx, ky, pd) then
                        local route = Pathfind.find(pos.x, pos.y, kx, ky, _World, id, pd, pd)
                        if route then
                            path.nodes = route
                            path.index = 1
                            path.moveTimer = 0
                        end
                    end
                end
                return
            end

            -- Attack if adjacent
            if nearDist < 1.5 then
                cr.attackCooldown = cr.attackCooldown - dt
                if cr.attackCooldown <= 0 then
                    cr.attackCooldown = 1.0
                    local tCol = ECS.get(nearestId, 'colonist')
                    if tCol then
                        -- Phase 5: armor reduction, body part damage, wound application
                        local finalDmg = cr.damage
                        if _Equipment then
                            finalDmg = math.max(1, finalDmg - _Equipment.getArmorReduction(nearestId))
                        end

                        if _Body then
                            local partName = _Body.randomPart()
                            local killed = _Body.damagePart(nearestId, partName, finalDmg)
                            if _Wounds then
                                local severity = math.min(1.0, finalDmg / 25)
                                _Wounds.apply(nearestId, partName, 'cut', severity)
                            end
                            if killed then
                                if _ColMod then
                                    _ColMod.kill(nearestId)
                                else
                                    tCol.health = 0
                                    tCol.state = 'dead'
                                    tCol.deathTime = GameState.day
                                    tCol.task = nil
                                end
                                return
                            end
                        end

                        tCol.health = tCol.health - finalDmg
                        if _ElasticD then _ElasticD.onDamageTaken(finalDmg) end
                        if tCol.health <= 0 and tCol.state ~= 'dead' then
                            if _ColMod then
                                _ColMod.kill(nearestId)
                            else
                                tCol.state = 'dead'
                                tCol.deathTime = GameState.day
                                tCol.task = nil
                            end
                        end
                    end
                end
                return
            end

            -- Path toward target
            local tPos = ECS.get(nearestId, 'pos')
            if tPos then
                local pd = pos.depth or 0
                local route = Pathfind.find(pos.x, pos.y, tPos.x, tPos.y, _World, id, pd, tPos.depth or 0)
                if route and #route > 0 then
                    -- Only take a few steps at a time (re-evaluate frequently)
                    local trimmed = {}
                    for i = 1, math.min(5, #route) do trimmed[i] = route[i] end
                    path.nodes = trimmed
                    path.index = 1
                    path.moveTimer = 0
                elseif sp and sp.breacher then
                    -- Breacher: no path found — attack adjacent wall/door tiles
                    cr.attackCooldown = cr.attackCooldown - dt
                    if cr.attackCooldown <= 0 then
                        cr.attackCooldown = 1.5
                        local dirs = { {0,-1}, {0,1}, {-1,0}, {1,0} }
                        for _, d in ipairs(dirs) do
                            local bx, by = pos.x + d[1], pos.y + d[2]
                            if _World.inBounds(bx, by) then
                                local bpd = pos.depth or 0
                                local tile = _World.getTile(bx, by, bpd)
                                if _Tiles and (_Tiles.isSolid(tile) or tile == _Tiles.DOOR or tile == _Tiles.DOOR_SEALED) then
                                    _World.setTile(bx, by, _Tiles.DEBRIS, bpd)
                                    cr.state = 'chase'
                                    break
                                end
                            end
                        end
                    end
                end
            end
            return
        end

        -- Lure attraction: bait lure traps set lureX/lureY on nearby hostiles
        if cr.lureX and cr.lureY then
            local lureDist = distSq(pos.x, pos.y, cr.lureX, cr.lureY)
            if lureDist > 1 then
                local pd = pos.depth or 0
                local route = Pathfind.find(pos.x, pos.y, cr.lureX, cr.lureY, _World, id, pd, pd)
                if route then
                    cr.state = 'chase'
                    path.nodes = route
                    path.index = 1
                    path.moveTimer = 0
                    return
                end
            end
            -- Clear lure once reached or unreachable
            cr.lureX = nil
            cr.lureY = nil
        end

        -- Leash check: return home if too far.
        -- The retry MUST be throttled. An out-of-leash creature whose den is
        -- unreachable (walled off, buried, across water) used to re-run a full
        -- A* every single tick; the search exhausts the whole MAX_NODES budget
        -- before failing, and with a map full of creatures this alone burned
        -- ~1100 failed searches and 3.3 million node expansions every 15
        -- seconds, dragging the sim from ~250 to ~17 ticks/second. After a few
        -- failures the creature simply adopts its current spot as home — a
        -- wild animal's territory is allowed to move.
        if pos.homeX and distSq(pos.x, pos.y, pos.homeX, pos.homeY) > cr.leashRange * cr.leashRange then
            cr.state = 'returning'
            cr._homeRetryCd = (cr._homeRetryCd or 0) - dt
            if cr._homeRetryCd <= 0 then
                local pd = pos.depth or 0
                local route = Pathfind.find(pos.x, pos.y, pos.homeX, pos.homeY, _World, id, pd, pd)
                if route then
                    path.nodes = route
                    path.index = 1
                    path.moveTimer = 0
                    cr._homeFails = nil
                else
                    cr._homeRetryCd = 5.0
                    cr._homeFails = (cr._homeFails or 0) + 1
                    if cr._homeFails >= 3 then
                        pos.homeX, pos.homeY = pos.x, pos.y
                        cr._homeFails = nil
                    end
                end
            end
            return
        end
    elseif cr.fleeRange > 0 then
        -- Passive creature: flee from nearby colonists
        if nearestId and nearDist <= cr.fleeRange then
            cr.state = 'flee'
            local tPos = ECS.get(nearestId, 'pos')
            if tPos then
                -- Run away from colonist
                local dx = pos.x - tPos.x
                local dy = pos.y - tPos.y
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 0 then
                    dx, dy = dx / len, dy / len
                end
                local fleeX = math.floor(pos.x + dx * 8)
                local fleeY = math.floor(pos.y + dy * 8)
                fleeX = math.max(1, math.min(_World.width() - 2, fleeX))
                fleeY = math.max(1, math.min(_World.height() - 2, fleeY))
                local pd = pos.depth or 0
                if _World.isWalkable(fleeX, fleeY, pd) then
                    local route = Pathfind.find(pos.x, pos.y, fleeX, fleeY, _World, id, pd, pd)
                    if route then
                        path.nodes = route
                        path.index = 1
                        path.moveTimer = 0
                    end
                end
            end
            return
        end
    end

    -- Idle wander — dual-brain: director-biased + random fallback
    cr.state = 'idle'
    if math.random() < 0.01 then
        local wx, wy

        -- Brain 2 (Director): ask for a biased wander target
        if cr.hostile and _Director then
            local hx, hy, strength = _Director.getHint(pos.x, pos.y, cr.aggroRange * 3)
            if hx and strength and strength > 1.0 then
                wx, wy = hx, hy
                cr._investigating = true
            end
        end

        -- Fallback: random wander if no director hint
        if not wx then
            wx = pos.x + math.random(-6, 6)
            wy = pos.y + math.random(-6, 6)
            cr._investigating = false
        end

        local pd = pos.depth or 0
        if _World.inBounds(wx, wy) and _World.isWalkable(wx, wy, pd) then
            local route = Pathfind.find(pos.x, pos.y, wx, wy, _World, id, pd, pd)
            if route then
                cr.state = 'wander'
                path.nodes = route
                path.index = 1
                path.moveTimer = 0
            end
        end
    end
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

function CreatureAI.registerSystems()
    ECS.addSystem('creature_ai', { 'creature', 'pos', 'path' }, creatureAI, 25)
end

CreatureAI.registerSystems()

return CreatureAI
