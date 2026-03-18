local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Agriculture')

local function reloadModule(name)
    package.loaded[name] = nil
    return require(name)
end

local function spawnCrop(ECS, cropType, x, y, depth)
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth or 0 })
    ECS.set(id, 'crop', {
        type = cropType,
        name = cropType,
        growth = 0,
        mature = false,
        wilted = false,
        growTime = 100,
    })
    return id
end

T.test('fungal crop CO2 bonus uses tile depth', function()
    H.resetAll()

    local ECS = require('src.ecs.ecs')
    local World = require('src.world.tilemap')
    local Lighting = require('src.sim.lighting')
    local Atmosphere = require('src.sim.atmosphere')
    local Seasons = require('src.world.seasons')

    reloadModule('src.building.agriculture')

    local origGetTemp = World.getTemp
    local origGetLightAt = Lighting.getLightAt
    local origGetTileCO2 = Atmosphere.getTileCO2
    local origGetGrowthMult = Seasons.getGrowthMult

    local ok, err = pcall(function()
        World.getTemp = function()
            return 10
        end
        Lighting.getLightAt = function()
            return 1
        end
        Atmosphere.getTileCO2 = function(_, _, depth)
            if depth == 1 then
                return 40
            end
            return 0
        end
        Seasons.getGrowthMult = function()
            return 1
        end

        local surfaceId = spawnCrop(ECS, 'alien_fungus', 5, 5, 0)
        local undergroundId = spawnCrop(ECS, 'alien_fungus', 5, 5, 1)

        ECS.update(10)

        local surfaceCrop = ECS.get(surfaceId, 'crop')
        local undergroundCrop = ECS.get(undergroundId, 'crop')

        T.notnil(surfaceCrop, 'surface crop still exists')
        T.notnil(undergroundCrop, 'underground crop still exists')
        T.near(surfaceCrop.growth, 10, 0.01, 'surface crop gets baseline growth')
        T.near(undergroundCrop.growth, 14, 0.01, 'underground crop gets its depth CO2 bonus')
        T.gt(undergroundCrop.growth, surfaceCrop.growth, 'underground crop grows faster with CO2')
    end)

    World.getTemp = origGetTemp
    Lighting.getLightAt = origGetLightAt
    Atmosphere.getTileCO2 = origGetTileCO2
    Seasons.getGrowthMult = origGetGrowthMult

    if not ok then
        error(err, 0)
    end
end)
