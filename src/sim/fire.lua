-- fire.lua — Fire spread, heat emission, and CO2 generation
-- Fire starts from: incendiary traps, meltdowns, overheated machines, campfires
-- Fire spreads to adjacent flammable tiles (wood structures).
-- Fire emits heat (warms the tile) + CO2 (fills the room).
-- Colonists auto-create firefighting tasks. Rain/snow suppresses spread.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Fire = {}

---------------------------------------------------------------------------
-- Per-tile fire state: { [tileKey] = { x, y, depth, intensity, fuel, source } }
---------------------------------------------------------------------------

local activeFires = {}
local fireTimer   = 0
local FIRE_TICK   = 0.5  -- seconds between fire spread checks

-- Tile flammability: how easily a tile catches fire
local FLAMMABILITY = {
    -- Tile type IDs from tiles.lua (we check by name pattern)
    wood  = 1.0,   -- wood walls/floors burn easily
    stone = 0.1,   -- stone barely burns
    metal = 0.05,  -- metal doesn't really burn
    ice   = 0.0,   -- ice doesn't burn (but melts)
    dirt  = 0.2,   -- organic debris
}

-- Constants
local SPREAD_CHANCE_BASE = 0.15   -- 15% per adjacent tile per tick
local FIRE_HEAT_OUTPUT   = 30     -- degrees C heat per burning tile
local FIRE_CO2_RATE      = 0.3    -- CO2 emitted per second per fire
local FIRE_DAMAGE_RATE   = 5      -- HP damage per second to entities on fire tiles
local RAIN_SUPPRESS      = 0.7    -- rain reduces spread chance by 70%
local SNOW_SUPPRESS      = 0.5    -- snow reduces by 50%
local FIRE_BURNOUT_TIME  = 30     -- seconds before fire runs out of fuel

local function tileKey(x, y, depth)
    return (depth or 0) * 100000000 + y * 10000 + x
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Fire.init()
    activeFires = {}
    fireTimer = 0
end

---------------------------------------------------------------------------
-- Ignite a tile
---------------------------------------------------------------------------

function Fire.ignite(x, y, source, depth)
    depth = depth or 0
    local World = require('src.world.tilemap')
    if not World.inBounds(x, y) then return false end

    local k = tileKey(x, y, depth)
    if activeFires[k] then return false end  -- already burning

    -- Check foam suppression (ordnance foam blocks ignition)
    local ook, OrdMod = pcall(require, 'src.combat.ordnance')
    if ook and OrdMod.isFoamed and OrdMod.isFoamed(x, y, depth) then return false end

    -- Check if tile is flammable
    local Tiles = require('src.world.tiles')
    local tileType = World.getTile(x, y, depth)
    local tileProps = Tiles.get(tileType)
    local tileName = tileProps and tileProps.name or ''
    local flam = 0.3  -- default base flammability
    for matName, f in pairs(FLAMMABILITY) do
        if tileName:find(matName) then
            flam = f
            break
        end
    end

    if flam <= 0 then return false end  -- non-flammable

    activeFires[k] = {
        x = x, y = y,
        depth = depth,
        intensity = flam,
        fuel = FIRE_BURNOUT_TIME * flam,  -- more flammable = burns longer
        source = source or 'unknown',
    }

    -- Register heat source once on ignition (not per-tick)
    local tok, Thermal = pcall(require, 'src.sim.thermal')
    if tok then Thermal.addHeatSource(x, y, FIRE_HEAT_OUTPUT * flam, depth) end

    -- Register light source (fire glows)
    local lok, Lighting = pcall(require, 'src.sim.lighting')
    if lok then Lighting.addLightCustom(x, y, 5, 0.9 * flam) end

    -- Register CO2 emitter
    local aok, Atmosphere = pcall(require, 'src.sim.atmosphere')
    if aok then
        local roomId = World.getRoom(x, y, depth)
        if roomId and roomId > 0 then
            Atmosphere.addCO2Emitter(k, roomId, FIRE_CO2_RATE * flam)
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Extinguish a tile
---------------------------------------------------------------------------

function Fire.extinguish(x, y, depth)
    local k = tileKey(x, y, depth)
    local fire = activeFires[k]
    if fire then
        -- Clean up heat source, CO2 emitter, and light
        local tok, Thermal = pcall(require, 'src.sim.thermal')
        if tok then Thermal.removeHeatSource(fire.x, fire.y, FIRE_HEAT_OUTPUT * fire.intensity, fire.depth or 0) end
        local aok, Atmosphere = pcall(require, 'src.sim.atmosphere')
        if aok then Atmosphere.removeCO2Emitter(k) end
        local lok, Lighting = pcall(require, 'src.sim.lighting')
        if lok then Lighting.removeLight(fire.x, fire.y) end
        activeFires[k] = nil
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Fire.step(dt)
    if not next(activeFires) then return end

    fireTimer = fireTimer + dt
    if fireTimer < FIRE_TICK then return end
    fireTimer = 0

    local World = require('src.world.tilemap')

    -- Weather suppression (surface only, but apply globally for simplicity)
    local suppressMult = 1.0
    local wok, Weather = pcall(require, 'src.weather.weather')
    if wok then
        local _, wdef = Weather.getCurrent()
        if wdef then
            if wdef.rain then suppressMult = suppressMult * (1 - RAIN_SUPPRESS) end
            if wdef.snow then suppressMult = suppressMult * (1 - SNOW_SUPPRESS) end
        end
    end

    local toRemove = {}
    local toSpread = {}

    for k, fire in pairs(activeFires) do
        local fireDepth = fire.depth or 0

        local tgOk, TileGas = pcall(require, 'src.sim.tile_gas')
        if tgOk and TileGas.addGas then
            TileGas.addGas(fire.x, fire.y, 1, TileGas.TYPE_SMOKE, fireDepth)
        end

        -- Burn down fuel
        fire.fuel = fire.fuel - FIRE_TICK
        if fire.fuel <= 0 then
            toRemove[#toRemove + 1] = k
            goto continue
        end

        -- Damage entities on this tile (must match depth)
        local fireDead = {}
        for id, comps in ECS.query('pos') do
            local pos = comps.pos
            if pos.x == fire.x and pos.y == fire.y and (pos.depth or 0) == fireDepth then
                local col = ECS.get(id, 'colonist')
                local slave = ECS.get(id, 'slave')
                local creature = ECS.get(id, 'creature')
                if col and col.state ~= 'dead' then
                    col.health = col.health - FIRE_DAMAGE_RATE * FIRE_TICK
                    -- Apply burning status effect
                    local sfxOk, StatusFx = pcall(require, 'src.sim.status_effects')
                    if sfxOk then StatusFx.apply(id, 'burning', 0.3) end
                    if col.health <= 0 then
                        col.health = 0
                        fireDead[#fireDead + 1] = { id = id, name = col.name, type = 'colonist' }
                    end
                elseif slave and slave.state ~= 'dead' then
                    slave.health = slave.health - FIRE_DAMAGE_RATE * FIRE_TICK
                    if slave.health <= 0 then
                        slave.health = 0
                        slave.state = 'dead'
                        GameState.resources.corpse_human = (GameState.resources.corpse_human or 0) + 1
                        fireDead[#fireDead + 1] = { id = id, type = 'slave' }
                    end
                elseif creature and (creature.health or 0) > 0 then
                    creature.health = creature.health - FIRE_DAMAGE_RATE * FIRE_TICK
                    if creature.health <= 0 then
                        creature.health = 0
                        fireDead[#fireDead + 1] = { id = id, type = 'creature' }
                    end
                end
            end
        end
        -- Process fire deaths outside the query loop
        for _, dead in ipairs(fireDead) do
            if dead.type == 'colonist' then
                local cOk, ColMod = pcall(require, 'src.colonist.colonist')
                if cOk then ColMod.kill(dead.id) end
            elseif dead.type == 'creature' then
                -- Use Creatures.kill() to notify raid system and drop loot
                local cok, CreaturesMod = pcall(require, 'src.creatures.creatures')
                if cok then
                    CreaturesMod.kill(dead.id)
                else
                    ECS.destroy(dead.id)
                end
            else
                ECS.destroy(dead.id)
            end
        end

        -- Spread to adjacent tiles (same depth only)
        local dirs = { {1,0},{-1,0},{0,1},{0,-1} }
        for _, d in ipairs(dirs) do
            local nx, ny = fire.x + d[1], fire.y + d[2]
            local nk = tileKey(nx, ny, fireDepth)
            if World.inBounds(nx, ny) and not activeFires[nk] then
                -- Weather only suppresses surface fires
                local sMult = fireDepth == 0 and suppressMult or 1.0
                local spreadChance = SPREAD_CHANCE_BASE * fire.intensity * sMult
                if math.random() < spreadChance then
                    toSpread[#toSpread + 1] = { x = nx, y = ny, depth = fireDepth, source = 'spread' }
                end
            end
        end

        ::continue::
    end

    -- Remove burned-out fires
    for _, k in ipairs(toRemove) do
        local fire = activeFires[k]
        if fire then
            local fireDepth = fire.depth or 0
            -- Clean up heat source, CO2 emitter, and light
            local tok, Thermal = pcall(require, 'src.sim.thermal')
            if tok then Thermal.removeHeatSource(fire.x, fire.y, FIRE_HEAT_OUTPUT * fire.intensity, fire.depth or 0) end
            local aok, Atmosphere = pcall(require, 'src.sim.atmosphere')
            if aok then Atmosphere.removeCO2Emitter(k) end
            local lok, Lighting = pcall(require, 'src.sim.lighting')
            if lok then Lighting.removeLight(fire.x, fire.y) end

            -- Notify biocave system if growth is burning
            local bcOk, BioCaves = pcall(require, 'src.world.biocaves')
            if bcOk and BioCaves.onTileBurned then
                BioCaves.onTileBurned(fire.x, fire.y, fireDepth)
            end

            -- Fire burns tile to debris
            World.setTile(fire.x, fire.y, require('src.world.tiles').DEBRIS, fireDepth)
        end
        activeFires[k] = nil
    end

    -- Spread fires
    for _, s in ipairs(toSpread) do
        Fire.ignite(s.x, s.y, s.source, s.depth)
    end

    -- Create firefighting tasks for colonists
    local jok, Jobs = pcall(require, 'src.colonist.jobs')
    if jok and next(activeFires) then
        -- Ensure extinguish job type is registered
        if not Jobs.TYPES.extinguish then
            Jobs.TYPES.extinguish = {
                name     = 'Extinguish',
                skill    = nil,
                priority = 'building',
                duration = 3.0,
            }
        end
        for k, fire in pairs(activeFires) do
            if not fire._taskCreated then
                local taskId = Jobs.createTask('extinguish', fire.x, fire.y, {
                    fireKey = k,
                    depth = fire.depth or 0,
                })
                if taskId then
                    fire._taskCreated = true
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Fire.isOnFire(x, y, depth)
    return activeFires[tileKey(x, y, depth)] ~= nil
end

function Fire.getFireCount()
    local count = 0
    for _ in pairs(activeFires) do count = count + 1 end
    return count
end

function Fire.getActiveFires()
    return activeFires
end

function Fire.getFirstFirePos()
    local key = next(activeFires)
    if not key then return nil, nil end
    local d   = math.floor(key / 100000000)
    local rem = key - d * 100000000
    local fx  = rem % 10000
    local fy  = math.floor(rem / 10000)
    return fx, fy
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Fire.getState()
    -- Serialize activeFires as a list (keys are large integers)
    local list = {}
    for k, fire in pairs(activeFires) do
        list[#list + 1] = {
            x = fire.x, y = fire.y,
            depth = fire.depth or 0,
            intensity = fire.intensity,
            fuel = fire.fuel,
            source = fire.source,
            _taskCreated = fire._taskCreated or false,
        }
    end
    return { fires = list }
end

function Fire.loadState(state)
    activeFires = {}
    fireTimer = 0
    if not state or not state.fires then return end

    local Tiles = require('src.world.tiles')
    for _, f in ipairs(state.fires) do
        local k = tileKey(f.x, f.y, f.depth)
        activeFires[k] = {
            x = f.x, y = f.y,
            depth = f.depth or 0,
            intensity = f.intensity,
            fuel = f.fuel,
            source = f.source or 'unknown',
            _taskCreated = f._taskCreated or false,
        }
        -- Re-register heat, light, CO2 side effects
        local tok, Thermal = pcall(require, 'src.sim.thermal')
        if tok then Thermal.addHeatSource(f.x, f.y, FIRE_HEAT_OUTPUT * f.intensity, f.depth or 0) end
        local lok, Lighting = pcall(require, 'src.sim.lighting')
        if lok then Lighting.addLightCustom(f.x, f.y, 5, 0.9 * f.intensity) end
        local aok, Atmosphere = pcall(require, 'src.sim.atmosphere')
        if aok then
            local wOk, World = pcall(require, 'src.world.tilemap')
            if wOk then
                local roomId = World.getRoom(f.x, f.y, f.depth)
                if roomId and roomId > 0 then
                    Atmosphere.addCO2Emitter(k, roomId, FIRE_CO2_RATE * f.intensity)
                end
            end
        end
    end
end

return Fire
