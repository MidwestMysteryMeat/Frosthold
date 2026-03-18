-- caverns.lua — DF-style cavern layer generation
-- Three major cavern layers at fixed depths (3, 6, 9), each covering 40-60%
-- of the map with interconnected chambers and tunnels.
-- Cavern tiers: fungal (depth 3), precursor (depth 6), organ (depth 9).
-- Generated on first access of each depth. Breach events on first excavation
-- into a cavern tile. Underground water bodies use tile_fluids for lakes/rivers.
-- Separate from biocaves.lua (pocket caves between cavern layers).

local Tiles     = require('src.world.tiles')
local GameState = require('src.game_state')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

local Caverns = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

-- Fixed depths for the three cavern layers
Caverns.CAVERN_DEPTHS = { 3, 6, 9 }

-- Cavern tier definitions by depth
local CAVERN_TIERS = {
    [3] = {
        name       = 'Fungal Cavern',
        floorTile  = Tiles.FUNGAL_FLOOR,
        wallTile   = Tiles.FUNGAL_WALL,
        creatures  = { 'skitterer', 'spawnling' },
        creatureCount = { 8, 15 },
        loot       = { voidbloom = {2, 5}, thermalCores = {1, 3} },
        waterChance = 0.3,       -- chance of underground lake
        awareness  = 15,
        hopeHit    = -5,
    },
    [6] = {
        name       = 'Precursor Vault',
        floorTile  = Tiles.MEMBRANE_FLOOR,
        wallTile   = Tiles.MEMBRANE_WALL,
        creatures  = { 'spawnling', 'fleshwalker' },
        creatureCount = { 5, 10 },
        loot       = { thermalCores = {3, 6}, components = {2, 5}, circuit = {0, 2} },
        waterChance = 0.5,
        awareness  = 25,
        hopeHit    = -8,
    },
    [9] = {
        name       = 'Organ Chamber',
        floorTile  = Tiles.ORGAN_FLOOR,
        wallTile   = Tiles.ORGAN_WALL,
        creatures  = { 'fleshwalker', 'stalker' },
        creatureCount = { 3, 6 },
        loot       = { thermalCores = {5, 12}, components = {3, 6}, circuit = {1, 3}, void_crystal = {1, 2} },
        waterChance = 0.4,
        awareness  = 40,
        hopeHit    = -10,
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

-- Which cavern layers have been generated (depth -> true)
local generated = {}

-- Which cavern layers have been breached by the player (depth -> true)
local breached = {}

-- Creature replenishment timers per cavern
local replenishTimers = {}  -- { [depth] = ticksRemaining }
local REPLENISH_INTERVAL = 12000  -- ~10 minutes at 20Hz

-- Per-cavern creature cap (don't respawn beyond this)
local MAX_CREATURES_PER_CAVERN = 20

---------------------------------------------------------------------------
-- Cavern generation
---------------------------------------------------------------------------

--- Check if a depth is a cavern layer depth
function Caverns.isCavernDepth(depth)
    return CAVERN_TIERS[depth] ~= nil
end

--- Generate cavern structure on a layer's tile data.
--- Called from tilemap.ensureLayer() when the depth matches a cavern depth.
--- Writes directly into the layer's tiles[] and water[] arrays.
function Caverns.generateCavern(depth, tileData, waterData, w, h, seed)
    if generated[depth] then return end
    local tier = CAVERN_TIERS[depth]
    if not tier then return end

    generated[depth] = true

    local caveSeed = seed + depth * 7919  -- unique seed per cavern

    -- Pass 1: Perlin noise to create initial cave mask
    -- Target 40-60% open space
    local mask = {}
    local openCount = 0
    local size = w * h
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local idx = y * w + x + 1
            local nx, ny = x / w, y / h
            -- Two octaves of noise for organic shape
            local n1 = love.math.noise(nx * 6 + caveSeed, ny * 6 + caveSeed)
            local n2 = love.math.noise(nx * 12 + caveSeed + 500, ny * 12 + caveSeed + 500) * 0.5
            local combined = n1 + n2

            -- Threshold: deeper caverns are slightly more open
            local threshold = 0.85 - depth * 0.01
            if combined > threshold then
                mask[idx] = true
                openCount = openCount + 1
            else
                mask[idx] = false
            end
        end
    end

    -- Pass 2: Cellular automata smoothing (3 iterations)
    -- B5678/S45678 variant: creates smooth, connected chambers
    for iteration = 1, 3 do
        local newMask = {}
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                local neighbors = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local nx, ny = x + dx, y + dy
                            if nx >= 0 and nx < w and ny >= 0 and ny < h then
                                if mask[ny * w + nx + 1] then
                                    neighbors = neighbors + 1
                                end
                            else
                                -- Map edges count as walls
                                neighbors = neighbors + 1
                            end
                        end
                    end
                end

                if mask[idx] then
                    -- Stay open if 4+ neighbors are open
                    newMask[idx] = neighbors >= 3
                else
                    -- Become open if 5+ neighbors are open
                    newMask[idx] = neighbors >= 6
                end
            end
        end
        mask = newMask
    end

    -- Pass 3: Find largest connected region via flood fill
    local visited = {}
    local regions = {}

    local function floodFill(startIdx)
        local region = {}
        local queue = { startIdx }
        visited[startIdx] = true
        local head = 1
        while head <= #queue do
            local idx = queue[head]
            head = head + 1
            region[#region + 1] = idx

            local x = (idx - 1) % w
            local y = math.floor((idx - 1) / w)
            local dirs = { {-1,0}, {1,0}, {0,-1}, {0,1} }
            for _, d in ipairs(dirs) do
                local nx, ny = x + d[1], y + d[2]
                if nx >= 0 and nx < w and ny >= 0 and ny < h then
                    local ni = ny * w + nx + 1
                    if mask[ni] and not visited[ni] then
                        visited[ni] = true
                        queue[#queue + 1] = ni
                    end
                end
            end
        end
        return region
    end

    for idx = 1, size do
        if mask[idx] and not visited[idx] then
            regions[#regions + 1] = floodFill(idx)
        end
    end

    -- Keep the largest region as the main cavern
    local largestRegion = {}
    for _, region in ipairs(regions) do
        if #region > #largestRegion then
            largestRegion = region
        end
    end

    -- Create a set for fast lookup
    local cavernTiles = {}
    for _, idx in ipairs(largestRegion) do
        cavernTiles[idx] = true
    end

    -- Pass 4: Write cavern tiles into the layer
    for idx = 1, size do
        if cavernTiles[idx] then
            tileData[idx] = tier.floorTile
        else
            -- Check if this solid tile borders the cavern (wall tile)
            local x = (idx - 1) % w
            local y = math.floor((idx - 1) / w)
            local bordersOpen = false
            local dirs = { {-1,0}, {1,0}, {0,-1}, {0,1} }
            for _, d in ipairs(dirs) do
                local nx, ny = x + d[1], y + d[2]
                if nx >= 0 and nx < w and ny >= 0 and ny < h then
                    if cavernTiles[ny * w + nx + 1] then
                        bordersOpen = true
                        break
                    end
                end
            end
            if bordersOpen then
                tileData[idx] = tier.wallTile
                -- Ore veins along cave walls (richer at depth)
                local oreNoise = love.math.noise(x / w * 14 + caveSeed + 800, y / h * 14 + caveSeed + 800)
                if oreNoise > 0.8 - depth * 0.02 then
                    tileData[idx] = Tiles.ORE_VEIN
                end
            end
        end
    end

    -- Pass 5: Underground water bodies
    if waterData and math.random() < tier.waterChance then
        -- Use secondary noise as "elevation" within cavern
        local waterSeed = caveSeed + 3000
        for _, idx in ipairs(largestRegion) do
            local x = (idx - 1) % w
            local y = math.floor((idx - 1) / w)
            local elevNoise = love.math.noise(x / w * 5 + waterSeed, y / h * 5 + waterSeed)
            -- Low elevation = underwater
            if elevNoise < 0.3 then
                waterData[idx] = 7  -- full water
            elseif elevNoise < 0.38 then
                waterData[idx] = 4  -- shallow edge
            end
        end
    end

    -- Pass 6: Natural shafts connecting to adjacent cavern layers
    local shaftCount = 2 + math.random(0, 1)
    local shaftsPlaced = 0
    local attempts = 0
    while shaftsPlaced < shaftCount and attempts < 50 do
        attempts = attempts + 1
        local randIdx = largestRegion[math.random(#largestRegion)]
        -- Don't place shafts in water
        if (waterData[randIdx] or 0) == 0 then
            tileData[randIdx] = Tiles.STAIR_BOTH
            shaftsPlaced = shaftsPlaced + 1
        end
    end

    -- Notify tile_fluids about generated water so it enters the sim
    if waterData then
        local tfOk, TileFluids = pcall(require, 'src.sim.tile_fluids')
        if tfOk and TileFluids.markLayerDirty then
            TileFluids.markLayerDirty(depth)
        end
    end

    return #largestRegion
end

---------------------------------------------------------------------------
-- Cavern breach event
---------------------------------------------------------------------------

--- Called when a player first mines into a cavern layer tile.
--- Triggers dramatic reveal, creature alert, and storyteller event.
function Caverns.onBreach(depth)
    if breached[depth] then return end
    breached[depth] = true

    local tier = CAVERN_TIERS[depth]
    if not tier then return end

    -- Hope impact
    local hOk, Hope = pcall(require, 'src.colony.hope')
    if hOk then
        Hope.applyDelta(tier.hopeHit, 0)
    end

    -- Erebus awareness
    local bcOk, BioCaves = pcall(require, 'src.world.biocaves')
    if bcOk and BioCaves.addAwareness then
        BioCaves.addAwareness(tier.awareness)
    end

    -- Grant loot
    if tier.loot then
        local Items = getItems()
        for resource, range in pairs(tier.loot) do
            local amount = range[1] + math.random(0, range[2] - range[1])
            if amount > 0 then
                if Items then Items.spawn(GameState.startX, GameState.startY, resource, amount, nil, depth)
                else GameState.addResource(resource, amount) end
            end
        end
    end

    -- Spawn creatures
    Caverns.spawnCavernCreatures(depth, tier, false)

    -- Start replenishment timer
    replenishTimers[depth] = REPLENISH_INTERVAL

    -- Log event
    local hisOk, History = pcall(require, 'src.world.history')
    if hisOk and History.addEvent then
        History.addEvent('cavern_breach', {
            depth = depth,
            name  = tier.name,
            day   = GameState.day,
        })
    end

    -- Storyteller notification
    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk and Storyteller.onCavernBreach then
        Storyteller.onCavernBreach(depth, tier.name)
    end
end

--- Spawn cavern creatures at valid floor tiles
function Caverns.spawnCavernCreatures(depth, tier, isReplenish)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end
    local cOk, Creatures = pcall(require, 'src.creatures.creatures')
    if not cOk then return end

    local w = World.width()
    local h = World.height()
    local tileData = World.rawTileData(depth)
    local waterData = World.rawWaterData(depth)
    if not tileData then return end

    -- Collect valid spawn positions (cavern floor, no water)
    local spawnPositions = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local idx = y * w + x + 1
            local tile = tileData[idx]
            if tile == tier.floorTile and (not waterData or (waterData[idx] or 0) == 0) then
                spawnPositions[#spawnPositions + 1] = { x = x, y = y }
            end
        end
    end

    if #spawnPositions == 0 then return end

    -- Determine count
    local minC, maxC = tier.creatureCount[1], tier.creatureCount[2]
    if isReplenish then
        -- Replenish spawns fewer
        minC = math.floor(minC * 0.3)
        maxC = math.floor(maxC * 0.3)
    end
    local count = minC + math.random(0, math.max(0, maxC - minC))

    for i = 1, count do
        if #spawnPositions == 0 then break end
        local posIdx = math.random(#spawnPositions)
        local pos = spawnPositions[posIdx]
        local species = tier.creatures[math.random(#tier.creatures)]
        if Creatures.spawn then
            Creatures.spawn(species, pos.x, pos.y, depth)
        end
        -- Remove used position
        spawnPositions[posIdx] = spawnPositions[#spawnPositions]
        spawnPositions[#spawnPositions] = nil
    end
end

---------------------------------------------------------------------------
-- Step — creature replenishment
---------------------------------------------------------------------------

function Caverns.step(dt)
    for depth, remaining in pairs(replenishTimers) do
        replenishTimers[depth] = remaining - 1
        if replenishTimers[depth] <= 0 then
            replenishTimers[depth] = REPLENISH_INTERVAL

            local tier = CAVERN_TIERS[depth]
            if tier and breached[depth] then
                -- Count existing creatures at this depth
                local ECS = require('src.ecs.ecs')
                local count = 0
                for _, comps in ECS.query('creature', 'pos') do
                    if (comps.pos.depth or 0) == depth then
                        count = count + 1
                    end
                end
                -- Only replenish if below cap
                if count < MAX_CREATURES_PER_CAVERN then
                    Caverns.spawnCavernCreatures(depth, tier, true)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Caverns.isGenerated(depth) return generated[depth] == true end
function Caverns.isBreached(depth)  return breached[depth] == true end

function Caverns.getTier(depth)
    return CAVERN_TIERS[depth]
end

function Caverns.getBreachedDepths()
    local result = {}
    for depth in pairs(breached) do
        result[#result + 1] = depth
    end
    table.sort(result)
    return result
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Caverns.getState()
    return {
        generated       = generated,
        breached        = breached,
        replenishTimers = replenishTimers,
    }
end

function Caverns.loadState(state)
    if not state then
        generated = {}
        breached = {}
        replenishTimers = {}
        return
    end
    generated       = state.generated or {}
    breached        = state.breached or {}
    replenishTimers = state.replenishTimers or {}
end

return Caverns
