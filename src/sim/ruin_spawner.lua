-- ruin_spawner.lua — Spawns building ruins, data discs, resource crates, and graves
-- from a legacy record when redeploying to a planet with colony history.

local ECS = require('src.ecs.ecs')

local RuinSpawner = {}

---------------------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------------------

local function randomOffset(range)
    -- Returns integer offset in [-range, range]
    return math.floor(math.random() * (range * 2 + 1)) - range
end

---------------------------------------------------------------------------
-- spawnBuildingRuins
-- For each building in the list, 25% chance of total destruction.
-- Otherwise spawn as ECS entity with pos, building_ref, and durability.
---------------------------------------------------------------------------

function RuinSpawner.spawnBuildingRuins(buildings)
    buildings = buildings or {}
    for _, bld in ipairs(buildings) do
        -- 25% chance of being destroyed entirely
        if math.random() <= 0.25 then
            -- skip this building
        else
            local original_hp = bld.hp or 100
            local id = ECS.spawn()
            ECS.set(id, 'pos', {
                x     = bld.x or 0,
                y     = bld.y or 0,
                depth = bld.depth or 0,
            })
            ECS.set(id, 'building_ref', {
                defId  = bld.defId,
                isRuin = true,
            })
            ECS.set(id, 'durability', {
                hp    = math.floor(original_hp * 0.5),
                maxHp = original_hp,
            })
        end
    end
end

---------------------------------------------------------------------------
-- spawnDataDiscs
-- For each completed research: tier <= 2 = 'intact', tier > 2 = 'degraded'
-- For in-progress research: quality = 'partial', partialFraction = progress * 0.5
---------------------------------------------------------------------------

function RuinSpawner.spawnDataDiscs(completedResearch, inProgressResearch, record)
    completedResearch  = completedResearch  or {}
    inProgressResearch = inProgressResearch or {}
    local baseX = (record and record.x) or 0
    local baseY = (record and record.y) or 0

    for _, entry in ipairs(completedResearch) do
        local techId = entry.techId or entry.id or tostring(entry)
        local tier   = entry.tier or 1
        local quality = (tier <= 2) and 'intact' or 'degraded'

        local id = ECS.spawn()
        ECS.set(id, 'pos', {
            x = baseX + randomOffset(8),
            y = baseY + randomOffset(8),
        })
        ECS.set(id, 'item', {
            defId    = 'data_disc',
            name     = 'Data Disc: ' .. techId,
            dataDisc = {
                techId          = techId,
                quality         = quality,
                partialFraction = nil,
            },
        })
    end

    for _, entry in ipairs(inProgressResearch) do
        local techId   = entry.techId or entry.id or tostring(entry)
        local progress = entry.progress or 0

        local id = ECS.spawn()
        ECS.set(id, 'pos', {
            x = baseX + randomOffset(8),
            y = baseY + randomOffset(8),
        })
        ECS.set(id, 'item', {
            defId    = 'data_disc',
            name     = 'Data Disc: ' .. techId,
            dataDisc = {
                techId          = techId,
                quality         = 'partial',
                partialFraction = progress * 0.5,
            },
        })
    end
end

---------------------------------------------------------------------------
-- spawnResourceCrates
-- Salvages 30-40% of each resource and spawns a crate entity.
---------------------------------------------------------------------------

function RuinSpawner.spawnResourceCrates(resources, record)
    resources = resources or {}
    local baseX = (record and record.x) or 0
    local baseY = (record and record.y) or 0

    for resType, amount in pairs(resources) do
        if amount > 0 then
            local salvage = math.floor(amount * (0.30 + math.random() * 0.10))
            if salvage > 0 then
                local id = ECS.spawn()
                ECS.set(id, 'pos', {
                    x = baseX + randomOffset(10),
                    y = baseY + randomOffset(10),
                })
                ECS.set(id, 'item', {
                    defId    = 'salvage_crate',
                    name     = 'Salvage Crate (' .. resType .. ')',
                    resource = resType,
                    amount   = salvage,
                })
            end
        end
    end
end

---------------------------------------------------------------------------
-- spawnGraves
-- For each colonist record, spawn a grave decoration entity.
---------------------------------------------------------------------------

function RuinSpawner.spawnGraves(colonists)
    colonists = colonists or {}
    for _, col in ipairs(colonists) do
        local id = ECS.spawn()
        ECS.set(id, 'pos', {
            x     = col.deathX or 0,
            y     = col.deathY or 0,
            depth = 0,
        })
        ECS.set(id, 'decoration', {
            name        = 'Remains of ' .. (col.name or 'Unknown'),
            backstory   = col.backstory,
            isGrave     = true,
            buried      = false,
            moodRadius  = 5,
            moodEffect  = -3,
        })
    end
end

---------------------------------------------------------------------------
-- spawnFromLegacy
-- Main entry point. Calls all sub-functions with data from legacy record.
---------------------------------------------------------------------------

function RuinSpawner.spawnFromLegacy(record)
    if not record then return end
    RuinSpawner.spawnBuildingRuins(record.buildings or {})
    RuinSpawner.spawnDataDiscs(
        record.completedResearch  or {},
        record.inProgressResearch or {},
        record
    )
    RuinSpawner.spawnResourceCrates(record.resources or {}, record)
    RuinSpawner.spawnGraves(record.colonists or {})
end

---------------------------------------------------------------------------
-- getRuinPositions
-- Returns a list of {x, y} positions from record.buildings for minimap icons.
---------------------------------------------------------------------------

function RuinSpawner.getRuinPositions(record)
    local positions = {}
    if not record or not record.buildings then return positions end
    for _, bld in ipairs(record.buildings) do
        positions[#positions + 1] = { x = bld.x or 0, y = bld.y or 0 }
    end
    return positions
end

return RuinSpawner
