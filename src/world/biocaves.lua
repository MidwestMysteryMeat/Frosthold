-- biocaves.lua — Biological cave discovery and growth system
-- When excavating underground, colonists may break into biological caves:
--   Depth 1-2: Fungal caves (alien ecosystem, voidbloom, skitterers)
--   Depth 3-4: Precursor vaults (ruins fused with living tissue, spawnlings)
--   Depth 5+:  Organ chambers (body horror, fleshwalkers, massive rewards)
--
-- Growth is contained unless breached (adjacent open tile). Then it spreads
-- slowly, convertible floors. Insulated walls block it. Fire burns it back.
-- Growth spawns creatures over time.
--
-- Each cave discovered increases Erebus awareness, escalating raids and
-- contamination events.

local Tiles     = require('src.world.tiles')
local GameState = require('src.game_state')

local BioCaves = {}

local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

-- Discovery chance per excavation by depth layer
local DISCOVERY_CHANCE = {
    [1] = 0.05,   -- 5%
    [2] = 0.10,   -- 10%
    [3] = 0.18,   -- 18%
    [4] = 0.25,   -- 25%
}
-- Depth 5+ defaults to 0.30

local function getDiscoveryChance(depth)
    return DISCOVERY_CHANCE[depth] or 0.30
end

-- Cave tier by depth
local function getCaveTier(depth)
    if depth <= 2 then return 'fungal' end
    if depth <= 4 then return 'precursor' end
    return 'organ'
end

-- Cave tile sets per tier
local CAVE_TILES = {
    fungal = {
        floor = Tiles.FUNGAL_FLOOR,
        wall  = Tiles.FUNGAL_WALL,
    },
    precursor = {
        floor = Tiles.MEMBRANE_FLOOR,
        wall  = Tiles.MEMBRANE_WALL,
    },
    organ = {
        floor = Tiles.ORGAN_FLOOR,
        wall  = Tiles.ORGAN_WALL,
    },
}

-- Cave size ranges per tier (radius in tiles)
local CAVE_SIZE = {
    fungal    = { min = 3, max = 5 },
    precursor = { min = 4, max = 7 },
    organ     = { min = 5, max = 9 },
}

-- Loot spawned in cave (resource type, amount range)
local CAVE_LOOT = {
    fungal    = { { 'voidbloom', 2, 5 }, { 'thermalCores', 1, 2 } },
    precursor = { { 'thermalCores', 3, 6 }, { 'voidbloom', 1, 3 }, { 'components', 1, 3 } },
    organ     = { { 'thermalCores', 6, 12 }, { 'voidbloom', 3, 6 }, { 'components', 2, 4 } },
}

-- Creatures spawned on discovery
local CAVE_CREATURES = {
    fungal    = { species = 'skitterer', count = { 3, 6 } },
    precursor = { species = 'spawnling', count = { 2, 5 } },
    organ     = { species = 'fleshwalker', count = { 1, 3 } },
}

-- Growth spreading
local GROWTH_SPREAD_INTERVAL = 5.0   -- seconds between spread checks
local GROWTH_SPREAD_CHANCE   = 0.08  -- chance per adjacent open tile per check
local GROWTH_SPAWN_INTERVAL  = 60.0  -- seconds between creature spawns from growth
local GROWTH_SPAWN_CHANCE    = 0.15  -- chance per growth cluster per interval

-- Erebus awareness
local awareness = 0  -- increases with each cave discovered
local AWARENESS_PER_CAVE = {
    fungal    = 5,
    precursor = 10,
    organ     = 20,
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local growthTimer = 0
local spawnTimer  = 0
-- Track growth tiles for spreading: { [depthKey] = true }
local growthTiles = {}
-- Track discovered caves for persistence
local discoveredCaves = 0

---------------------------------------------------------------------------
-- Cave generation — called when excavation hits a biological pocket
---------------------------------------------------------------------------

local function generateCave(cx, cy, depth, tier)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end

    local w, h = World.width(), World.height()
    local tData = World.rawTileData(depth)
    if not tData then return end

    local tiles = CAVE_TILES[tier]
    local sizeRange = CAVE_SIZE[tier]
    local radius = math.random(sizeRange.min, sizeRange.max)

    -- Carve irregular cave shape using noise
    local seed = cx * 1000 + cy * 100 + depth * 10
    local carved = {}

    for dy = -radius, radius do
        for dx = -radius, radius do
            local nx, ny = cx + dx, cy + dy
            if World.inBounds(nx, ny) then
                local dist = math.sqrt(dx * dx + dy * dy)
                -- Irregular shape via noise
                local noise = love.math.noise(nx * 0.3 + seed, ny * 0.3 + seed)
                local effectiveRadius = radius * (0.6 + noise * 0.5)

                if dist <= effectiveRadius then
                    local idx = ny * w + nx + 1
                    local existing = tData[idx]

                    -- Only carve through solid underground tiles
                    if existing == Tiles.UNDERGROUND_ROCK or existing == Tiles.DEEP_ROCK then
                        -- Edge tiles become bio walls, interior becomes bio floor
                        local isEdge = false
                        if dist > effectiveRadius - 1.5 then
                            isEdge = true
                        end

                        if isEdge then
                            tData[idx] = tiles.wall
                        else
                            tData[idx] = tiles.floor
                            carved[#carved + 1] = { x = nx, y = ny }
                        end
                    end
                end
            end
        end
    end

    return carved
end

---------------------------------------------------------------------------
-- Discovery — called from terraform when excavating underground
---------------------------------------------------------------------------

function BioCaves.onExcavation(x, y, depth)
    if not depth or depth < 1 then return false end

    local chance = getDiscoveryChance(depth)
    if math.random() > chance then return false end

    local tier = getCaveTier(depth)
    local carved = generateCave(x, y, depth, tier)
    if not carved or #carved == 0 then return false end

    -- Grant loot
    local lootTable = CAVE_LOOT[tier]
    if lootTable then
        local Items = getItems()
        for _, entry in ipairs(lootTable) do
            local res, lo, hi = entry[1], entry[2], entry[3]
            local amount = math.random(lo, hi)
            if Items then Items.spawn(x, y, res, amount, nil, depth)
            else GameState.addResource(res, amount) end
        end
    end

    -- Spawn creatures
    local creatureInfo = CAVE_CREATURES[tier]
    if creatureInfo and #carved > 0 then
        local cOk, Creatures = pcall(require, 'src.creatures.creatures')
        if cOk and Creatures.spawn then
            local count = math.random(creatureInfo.count[1], creatureInfo.count[2])
            for i = 1, count do
                local spot = carved[math.random(#carved)]
                Creatures.spawn(creatureInfo.species, spot.x, spot.y, depth)
            end
        end
    end

    -- Register growth tiles for spreading
    local wOk, World = pcall(require, 'src.world.tilemap')
    if wOk then
        local w = World.width()
        local tData = World.rawTileData(depth)
        if tData then
            for y2 = 0, World.height() - 1 do
                for x2 = 0, World.width() - 1 do
                    local idx = y2 * w + x2 + 1
                    local tile = tData[idx]
                    local props = Tiles.get(tile)
                    if props and props.containsGrowth then
                        growthTiles[depth * 100000000 + idx] = true
                    end
                end
            end
        end
    end

    -- Increase Erebus awareness
    awareness = awareness + (AWARENESS_PER_CAVE[tier] or 10)
    discoveredCaves = discoveredCaves + 1

    -- Contamination: disease risk for nearby colonists
    local ECS = require('src.ecs.ecs')
    for id, comps in ECS.query('colonist', 'pos') do
        local pos = comps.pos
        if (pos.depth or 0) == depth then
            local dist = math.abs(pos.x - x) + math.abs(pos.y - y)
            if dist <= 15 then
                -- Spore exposure
                local dOk, Disease = pcall(require, 'src.sim.disease')
                if dOk and Disease.infect then
                    if math.random() < 0.3 then
                        Disease.infect(id, 'frostlung')
                    end
                end
            end
        end
    end

    -- Hope event
    local hOk, Hope = pcall(require, 'src.colony.hope')
    if hOk then
        Hope.addHope(-2, 'biological cave discovered')
    end

    -- Storyteller event
    local sOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sOk and Storyteller.logEvent then
        Storyteller.logEvent('biocave_discovered', {
            x = x, y = y, depth = depth,
            tier = tier, tiles = #carved,
        })
    end

    return true, tier
end

---------------------------------------------------------------------------
-- Growth spreading step — biological growth breaches containment
-- Growth only spreads from bio walls adjacent to open (non-solid) tiles.
-- Spreads onto walkable tiles, converting them to GROWTH_CREEP.
-- Insulated walls and metal walls block growth entirely.
-- Fire burns growth back (GROWTH_CREEP is flammable).
---------------------------------------------------------------------------

local DIRS = { {-1,0}, {1,0}, {0,-1}, {0,1} }

local function isGrowthBlocker(tileType)
    return tileType == Tiles.WALL_INSULATED
        or tileType == Tiles.WALL_METAL
        or tileType == Tiles.DOOR_SEALED
end

function BioCaves.step(dt)
    -- Growth spreading
    growthTimer = growthTimer + dt
    if growthTimer >= GROWTH_SPREAD_INTERVAL then
        growthTimer = 0

        local wOk, World = pcall(require, 'src.world.tilemap')
        if wOk then
            local w, h = World.width(), World.height()
            local newGrowth = {}

            for depthKey, _ in pairs(growthTiles) do
                local depth = math.floor(depthKey / 100000000)
                local tileIdx = depthKey - depth * 100000000
                local ty = math.floor((tileIdx - 1) / w)
                local tx = (tileIdx - 1) % w

                local tData = World.rawTileData(depth)
                if tData then
                    for _, d in ipairs(DIRS) do
                        local nx, ny = tx + d[1], ty + d[2]
                        if World.inBounds(nx, ny) then
                            local ni = ny * w + nx + 1
                            local nTile = tData[ni]

                            -- Only spread onto walkable non-biological tiles
                            if not isGrowthBlocker(nTile) and Tiles.isWalkable(nTile)
                               and not Tiles.get(nTile).biological then
                                if math.random() < GROWTH_SPREAD_CHANCE then
                                    tData[ni] = Tiles.GROWTH_CREEP
                                    newGrowth[depth * 100000000 + ni] = true
                                end
                            end
                        end
                    end
                end
            end

            -- Growth creep tiles also spread
            for dk, _ in pairs(newGrowth) do
                growthTiles[dk] = true
            end
        end
    end

    -- Creature spawning from growth clusters
    spawnTimer = spawnTimer + dt
    if spawnTimer >= GROWTH_SPAWN_INTERVAL then
        spawnTimer = 0

        local wOk, World = pcall(require, 'src.world.tilemap')
        if not wOk then return end
        local w = World.width()

        -- Count growth tiles per depth, pick random spawn points
        local depthCounts = {}
        local depthTiles = {}
        for depthKey, _ in pairs(growthTiles) do
            local depth = math.floor(depthKey / 100000000)
            local tileIdx = depthKey - depth * 100000000

            -- Verify tile is still growth
            local tData = World.rawTileData(depth)
            if tData and (tData[tileIdx] == Tiles.GROWTH_CREEP
                       or Tiles.get(tData[tileIdx]).containsGrowth) then
                depthCounts[depth] = (depthCounts[depth] or 0) + 1
                if not depthTiles[depth] then depthTiles[depth] = {} end
                depthTiles[depth][#depthTiles[depth] + 1] = tileIdx
            else
                -- Growth was burned or removed
                growthTiles[depthKey] = nil
            end
        end

        -- Spawn creatures from large growth clusters
        local cOk, Creatures = pcall(require, 'src.creatures.creatures')
        if cOk and Creatures.spawn then
            for depth, count in pairs(depthCounts) do
                if count >= 8 and math.random() < GROWTH_SPAWN_CHANCE then
                    local tiles = depthTiles[depth]
                    local pick = tiles[math.random(#tiles)]
                    local sy = math.floor((pick - 1) / w)
                    local sx = (pick - 1) % w

                    -- Deeper = nastier creatures
                    local species = 'skitterer'
                    if depth >= 5 then species = 'spawnling'
                    elseif depth >= 3 then species = 'skitterer' end

                    Creatures.spawn(species, sx, sy, depth)
                end
            end
        end
    end

    -- Infiltrator check: growth that has been spreading uncontested for long
    -- enough can mimic a colonist. The Thing-style replacement.
    -- Requires: large growth cluster (20+ tiles), no colonist nearby, awareness 15+
    BioCaves.checkInfiltration(dt)

    -- Update active mimics (sabotage, detection)
    BioCaves.updateMimics(dt)
end

---------------------------------------------------------------------------
-- Infiltrator system — Erebus mimics colonists
-- Growth that spreads uncontested can produce a mimic: a hostile entity
-- that looks and acts like a colonist until detected or triggered.
-- Detection: anomaly_sensitive colonists get a mood warning near mimics.
-- Blood tests (medical skill 6+) can identify them.
-- If undetected, mimic sabotages: opens doors to growth, disables pumps,
-- starts fires, poisons food. Eventually attacks at night.
---------------------------------------------------------------------------

local infiltratorTimer = 0
local INFILTRATOR_CHECK_INTERVAL = 120.0  -- 2 minutes between infiltration attempts
local INFILTRATOR_GROWTH_REQUIRED = 20    -- growth tiles needed
local INFILTRATOR_AWARENESS_MIN   = 15    -- awareness threshold
local INFILTRATOR_CHANCE           = 0.10 -- 10% per check when conditions met

-- Active mimics: { [entityId] = { revealed, sabotageTimer, targetId } }
local activeMimics = {}

function BioCaves.checkInfiltration(dt)
    infiltratorTimer = infiltratorTimer + dt
    if infiltratorTimer < INFILTRATOR_CHECK_INTERVAL then return end
    infiltratorTimer = 0

    if awareness < INFILTRATOR_AWARENESS_MIN then return end

    -- Count total growth tiles
    local totalGrowth = 0
    for _ in pairs(growthTiles) do
        totalGrowth = totalGrowth + 1
    end
    if totalGrowth < INFILTRATOR_GROWTH_REQUIRED then return end

    if math.random() > INFILTRATOR_CHANCE then return end

    -- Spawn a mimic colonist
    BioCaves.spawnMimic()
end

function BioCaves.spawnMimic()
    local ECS = require('src.ecs.ecs')
    local aOk, Adlib = pcall(require, 'src.util.adlib')
    if not aOk then return end

    -- Find an edge or underground area to "arrive" from
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end

    -- Spawn near colony center (mimics wander in like a refugee)
    local sx = GameState.startX + math.random(-8, 8)
    local sy = GameState.startY + math.random(-8, 8)

    -- Find walkable tile near spawn
    for attempt = 1, 20 do
        local tx = sx + math.random(-3, 3)
        local ty = sy + math.random(-3, 3)
        if World.inBounds(tx, ty) and World.isWalkable(tx, ty, 0) then
            sx, sy = tx, ty
            break
        end
    end

    local id = ECS.spawn()
    local identity = Adlib.generateColonistIdentity()

    ECS.set(id, 'pos', {
        x = sx, y = sy,
        prevX = sx, prevY = sy,
        targetX = nil, targetY = nil,
        depth = 0,
    })

    -- Looks like a normal colonist
    local skills = {}
    for _, s in ipairs({ 'mining', 'building', 'cooking', 'hunting', 'research', 'medical' }) do
        skills[s] = math.random(2, 7)
    end

    ECS.set(id, 'colonist', {
        name      = identity.name,
        backstory = identity.backstory,
        traits    = identity.traits,
        skills    = skills,
        skillXp   = {},
        health    = 100,
        maxHealth = 100,
        sanity    = 100,
        age       = 20 + math.random(30),
        task      = nil,
        state     = 'idle',
        facing    = math.random() * math.pi * 2,
        _isMimic  = true,          -- hidden flag, not visible to player
    })

    ECS.set(id, 'needs', {
        warmth = 80, food = 80, rest = 80, morale = 70,
    })
    ECS.set(id, 'path', { nodes = nil, index = 1, moveTimer = 0 })
    local sOkSch, Schedule = pcall(require, 'src.colonist.schedule')
    ECS.set(id, 'schedule', sOkSch and Schedule.default() or {})
    local jOkWP, JobsMod = pcall(require, 'src.colonist.jobs')
    ECS.set(id, 'workPriority', jOkWP and JobsMod.defaultPriorities and JobsMod.defaultPriorities() or {})
    ECS.set(id, 'inventory', {})

    activeMimics[id] = { revealed = false, sabotageTimer = 0 }

    -- Storyteller event
    local sOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sOk and Storyteller.logEvent then
        Storyteller.logEvent('wanderer_arrived', {
            name = identity.name,
            x = sx, y = sy,
        })
    end
end

---------------------------------------------------------------------------
-- Mimic behavior — runs each biocave step
-- Mimics act normally (work, eat, sleep) but periodically sabotage.
-- Detection methods:
--   1. Anomaly-sensitive colonists get uneasy near mimics
--   2. Medical exam (doctor skill 6+) reveals them
--   3. Mimic caught in the act of sabotage
-- When revealed: mimic goes hostile, attacks nearest colonist, then flees
---------------------------------------------------------------------------

function BioCaves.updateMimics(dt)
    local ECS = require('src.ecs.ecs')

    local toRemove = {}
    for mimicId, state in pairs(activeMimics) do
        local col = ECS.get(mimicId, 'colonist')
        local pos = ECS.get(mimicId, 'pos')
        if not col or not pos or col.state == 'dead' then
            toRemove[#toRemove + 1] = mimicId
            goto nextMimic
        end

        if state.revealed or col._mimicRevealed then
            -- Already revealed — handled by combat AI
            goto nextMimic
        end

        -- Sabotage timer
        state.sabotageTimer = state.sabotageTimer + dt
        if state.sabotageTimer >= 300 then  -- every 5 real minutes
            state.sabotageTimer = 0

            -- Pick a sabotage action
            local action = math.random(4)
            if action == 1 then
                -- Spread growth near colony (pick a nearby walkable tile)
                local wOk, World = pcall(require, 'src.world.tilemap')
                if wOk then
                    local gx = pos.x + math.random(-2, 2)
                    local gy = pos.y + math.random(-2, 2)
                    local gd = pos.depth or 0
                    if World.inBounds(gx, gy) then
                        local tile = World.getTile(gx, gy, gd)
                        if Tiles.isWalkable(tile) and not (Tiles.get(tile) or {}).biological then
                            World.setTile(gx, gy, Tiles.GROWTH_CREEP, gd)
                            local w2 = World.width()
                            growthTiles[gd * 100000000 + (gy * w2 + gx + 1)] = true
                        end
                    end
                end
            elseif action == 2 then
                -- Poison food supply
                local sOkMim, SNetMim = pcall(require, 'src.logistics.storage_network')
                local mimAmt = math.random(3, 8)
                if sOkMim and SNetMim.withdraw then SNetMim.withdraw('food', mimAmt, pos.x, pos.y)
                else GameState.spendResource('food', mimAmt) end
            elseif action == 3 then
                -- Start a small fire nearby
                local fOk, Fire = pcall(require, 'src.sim.fire')
                if fOk then
                    local fx = pos.x + math.random(-2, 2)
                    local fy = pos.y + math.random(-2, 2)
                    Fire.ignite(fx, fy, 'sabotage', pos.depth)
                end
            elseif action == 4 then
                -- Morale damage: colonists near mimic feel uneasy
                local hOk, Hope = pcall(require, 'src.colony.hope')
                if hOk then Hope.addHope(-1, 'something feels wrong') end
            end
        end

        -- Anomaly-sensitive colonists detect mimics nearby
        for otherId, otherComps in ECS.query('colonist', 'pos') do
            if state.revealed then goto nextMimic end  -- already detected this tick
            if otherId ~= mimicId and otherComps.colonist.state ~= 'dead' then
                local oPos = otherComps.pos
                local dist = math.abs(oPos.x - pos.x) + math.abs(oPos.y - pos.y)
                if dist <= 5 then
                    local traits = otherComps.colonist.traits
                    if traits then
                        for _, t in ipairs(traits) do
                            if t.id == 'anomaly_sensitive' then
                                if math.random() < 0.02 * dt then
                                    BioCaves.revealMimic(mimicId)
                                    state.revealed = true
                                    goto nextMimic
                                end
                                break
                            end
                        end
                    end
                end
            end
        end

        ::nextMimic::
    end

    for _, id in ipairs(toRemove) do
        activeMimics[id] = nil
    end
end

function BioCaves.revealMimic(mimicId)
    local ECS = require('src.ecs.ecs')
    local col = ECS.get(mimicId, 'colonist')
    if not col then return end

    local mimicName = col.name
    local pos = ECS.get(mimicId, 'pos')
    local px, py, pd = pos and pos.x, pos and pos.y, pos and pos.depth

    -- Drop the disguise: spawn a hostile creature in its place
    if px then
        local cOk, Creatures = pcall(require, 'src.creatures.creatures')
        if cOk and Creatures.spawn then
            Creatures.spawn('fleshwalker', px, py, pd)
        end
    end

    -- Destroy the fake colonist entity
    local occOk, Occupancy = pcall(require, 'src.util.occupancy')
    if occOk and px then Occupancy.release(px, py, mimicId, pd) end
    ECS.destroy(mimicId)

    -- Colony-wide panic
    local hOk, Hope = pcall(require, 'src.colony.hope')
    if hOk then Hope.addHope(-8, 'infiltrator revealed') end

    activeMimics[mimicId] = nil

    local sOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sOk and Storyteller.logEvent then
        Storyteller.logEvent('mimic_revealed', {
            name = mimicName,
            x = px, y = py,
        })
    end
end

-- Medical exam can detect mimics (called from medical task system)
function BioCaves.examineForMimic(doctorId, patientId)
    local ECS = require('src.ecs.ecs')
    local col = ECS.get(patientId, 'colonist')
    if not col or not col._isMimic then return false end

    -- Doctor skill check
    local doctorCol = ECS.get(doctorId, 'colonist')
    if not doctorCol then return false end
    local medSkill = doctorCol.skills and doctorCol.skills.medical or 1
    if medSkill >= 6 then
        -- Detected!
        BioCaves.revealMimic(patientId)
        return true
    end
    return false
end

-- Query if an entity is a mimic (for systems that need to know)
function BioCaves.isMimic(entityId)
    return activeMimics[entityId] ~= nil
end

-- Clean up growth tracking when a biological tile is mined, demolished, or replaced
function BioCaves.onTileRemoved(x, y, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end
    local w = World.width()
    local idx = y * w + x + 1
    growthTiles[(depth or 0) * 100000000 + idx] = nil
end

---------------------------------------------------------------------------
-- Fire interaction — burning growth creep
---------------------------------------------------------------------------

function BioCaves.onTileBurned(x, y, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end

    local tile = World.getTile(x, y, depth)
    if tile == Tiles.GROWTH_CREEP then
        World.setTile(x, y, Tiles.UNDERGROUND_FLOOR, depth)
        local w = World.width()
        local idx = y * w + x + 1
        growthTiles[(depth or 0) * 100000000 + idx] = nil
    end
end

-- Burn all growth in a radius (napalm/flamethrower)
function BioCaves.burnGrowth(cx, cy, depth, radius)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0 end

    local w = World.width()
    local burned = 0

    for dy = -radius, radius do
        for dx = -radius, radius do
            if math.abs(dx) + math.abs(dy) <= radius then
                local nx, ny = cx + dx, cy + dy
                if World.inBounds(nx, ny) then
                    local tile = World.getTile(nx, ny, depth)
                    if tile == Tiles.GROWTH_CREEP then
                        World.setTile(nx, ny, Tiles.UNDERGROUND_FLOOR, depth)
                        local idx = ny * w + nx + 1
                        growthTiles[depth * 100000000 + idx] = nil
                        burned = burned + 1
                    end
                end
            end
        end
    end

    return burned
end

---------------------------------------------------------------------------
-- Erebus awareness queries
---------------------------------------------------------------------------

function BioCaves.getAwareness()
    return awareness
end

-- Raid budget multiplier from awareness (1.0 = no effect)
function BioCaves.getRaidBudgetMult()
    return 1.0 + awareness * 0.01  -- +1% per awareness point
end

-- Swarm day threshold reduction from awareness
function BioCaves.getSwarmDayReduction()
    return math.floor(awareness * 0.2)  -- each 5 awareness = 1 day earlier
end

function BioCaves.getDiscoveredCount()
    return discoveredCaves
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function BioCaves.getState()
    -- Convert growthTiles to a list for serialization
    local growthList = {}
    for dk, _ in pairs(growthTiles) do
        growthList[#growthList + 1] = dk
    end
    -- Serialize active mimics: { entityId, sabotageTimer }
    local mimicList = {}
    for id, state in pairs(activeMimics) do
        if not state.revealed then
            mimicList[#mimicList + 1] = {
                id = id,
                sabotageTimer = state.sabotageTimer or 0,
            }
        end
    end
    return {
        awareness = awareness,
        discoveredCaves = discoveredCaves,
        growthTiles = growthList,
        activeMimics = mimicList,
        infiltratorTimer = infiltratorTimer,
    }
end

function BioCaves.loadState(state)
    if not state then return end
    awareness = state.awareness or 0
    discoveredCaves = state.discoveredCaves or 0
    infiltratorTimer = state.infiltratorTimer or 0
    growthTiles = {}
    if state.growthTiles then
        for _, dk in ipairs(state.growthTiles) do
            growthTiles[dk] = true
        end
    end
    activeMimics = {}
    if state.activeMimics then
        for _, m in ipairs(state.activeMimics) do
            activeMimics[m.id] = {
                revealed = false,
                sabotageTimer = m.sabotageTimer or 0,
            }
        end
    end
end

return BioCaves
