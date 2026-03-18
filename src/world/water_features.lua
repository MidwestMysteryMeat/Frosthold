-- water_features.lua — Natural water feature mechanics
-- Frozen rivers (ice fishing), geysers (periodic heat + steam), hot springs (morale).
-- Thaw season: frozen rivers become water tiles; refreeze in deep winter.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')

local WaterFeatures = {}

---------------------------------------------------------------------------
-- Geyser eruption state: { [tileKey] = { timer, erupting, eruptTimer } }
---------------------------------------------------------------------------

local geysers = {}
local GEYSER_INTERVAL_MIN = 60   -- seconds between eruptions
local GEYSER_INTERVAL_MAX = 180
local GEYSER_ERUPT_DURATION = 8  -- seconds of eruption

---------------------------------------------------------------------------
-- Hot spring visitor tracking
---------------------------------------------------------------------------

local SPRING_MORALE_RATE = 0.3   -- morale per second while adjacent
local SPRING_HEAL_RATE   = 0.05  -- HP per second while adjacent

---------------------------------------------------------------------------
-- Ice fishing
---------------------------------------------------------------------------

local ICE_FISH_DURATION = 5.0    -- seconds to fish
local ICE_FISH_MIN      = 1
local ICE_FISH_MAX      = 3

---------------------------------------------------------------------------
-- Tile key helper
---------------------------------------------------------------------------

local function tileKey(x, y)
    return y * 10000 + x
end

---------------------------------------------------------------------------
-- Init — scan map for geysers, set up eruption timers
---------------------------------------------------------------------------

function WaterFeatures.init()
    geysers = {}
    local wok, World = pcall(require, 'src.world.tilemap')
    if not wok then return end

    local w = GameState.mapWidth
    local h = GameState.mapHeight
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local tile = World.getTile(x, y, 0)
            if tile == Tiles.GEYSER then
                local key = tileKey(x, y)
                geysers[key] = {
                    x = x, y = y,
                    timer      = GEYSER_INTERVAL_MIN + math.random(GEYSER_INTERVAL_MAX - GEYSER_INTERVAL_MIN),
                    erupting   = false,
                    eruptTimer = 0,
                }
            end
        end
    end
end

---------------------------------------------------------------------------
-- Step — geyser eruptions, hot spring effects, seasonal river thaw/freeze
---------------------------------------------------------------------------

local seasonCheckTimer = 0
local SEASON_CHECK_INTERVAL = 30  -- check thaw/freeze every 30 seconds

function WaterFeatures.step(dt)
    local wok, World = pcall(require, 'src.world.tilemap')
    if not wok then return end

    -- Geyser eruption cycle
    for key, g in pairs(geysers) do
        if g.erupting then
            g.eruptTimer = g.eruptTimer - dt
            -- Heat nearby tiles during eruption
            local heatRadius = 6
            local heatPower = 40
            for dy = -heatRadius, heatRadius do
                for dx = -heatRadius, heatRadius do
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist <= heatRadius then
                        local tx, ty = g.x + dx, g.y + dy
                        if World.inBounds(tx, ty) then
                            local falloff = 1 - (dist / heatRadius)
                            local temp = World.getTemp(tx, ty, 0) or -40
                            local boost = heatPower * falloff * dt * 0.5
                            World.setTemp(tx, ty, temp + boost, 0)
                        end
                    end
                end
            end
            -- Noise for AI director
            local dok, Dir = pcall(require, 'src.ai.director')
            if dok then Dir.onNoise(g.x, g.y, 1.5) end

            if g.eruptTimer <= 0 then
                g.erupting = false
                g.timer = GEYSER_INTERVAL_MIN + math.random(GEYSER_INTERVAL_MAX - GEYSER_INTERVAL_MIN)
            end
        else
            g.timer = g.timer - dt
            if g.timer <= 0 then
                g.erupting = true
                g.eruptTimer = GEYSER_ERUPT_DURATION
            end
        end
    end

    -- Hot spring morale + healing for adjacent colonists
    for id, comps in ECS.query('colonist', 'pos', 'needs') do
        local col = comps.colonist
        if col.state ~= 'dead' then
            local pos = comps.pos
            -- Check 4 adjacent tiles for hot springs
            for _, d in ipairs({{0,0},{1,0},{-1,0},{0,1},{0,-1}}) do
                local tx, ty = pos.x + d[1], pos.y + d[2]
                if World.inBounds(tx, ty) then
                    local tile = World.getTile(tx, ty, 0)
                    if tile == Tiles.HOT_SPRING then
                        comps.needs.morale = math.min(100, comps.needs.morale + SPRING_MORALE_RATE * dt)
                        col.health = math.min(col.maxHealth or 100, col.health + SPRING_HEAL_RATE * dt)
                        break
                    end
                end
            end
        end
    end

    -- Seasonal river thaw/freeze
    seasonCheckTimer = seasonCheckTimer + dt
    if seasonCheckTimer >= SEASON_CHECK_INTERVAL then
        seasonCheckTimer = 0

        local sok, Seasons = pcall(require, 'src.world.seasons')
        if sok then
            local season = Seasons.getCurrent()
            local w = GameState.mapWidth
            local h = GameState.mapHeight

            if season == 'thaw' then
                -- Thaw: frozen rivers and lakes become water
                for y = 0, h - 1 do
                    for x = 0, w - 1 do
                        local tile = World.getTile(x, y, 0)
                        if tile == Tiles.FROZEN_RIVER or tile == Tiles.FROZEN_LAKE then
                            local temp = World.getTemp(x, y, 0) or -40
                            if temp > -5 then
                                World.setTile(x, y, Tiles.WATER, 0)
                            end
                        end
                        -- Frozen seas do NOT thaw (too deep)
                    end
                end
            elseif season == 'deep_winter' then
                -- Refreeze: water becomes frozen river again
                for y = 0, h - 1 do
                    for x = 0, w - 1 do
                        if World.getTile(x, y, 0) == Tiles.WATER then
                            local temp = World.getTemp(x, y, 0) or -40
                            if temp < -15 then
                                World.setTile(x, y, Tiles.FROZEN_RIVER, 0)
                            end
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Ice fishing — called by work_ai when colonist performs fish task
---------------------------------------------------------------------------

function WaterFeatures.attemptFish(colonistId, x, y)
    local wok, World = pcall(require, 'src.world.tilemap')
    if not wok then return nil end

    local tile = World.getTile(x, y, 0)
    if tile ~= Tiles.FROZEN_RIVER and tile ~= Tiles.FROZEN_LAKE then return nil end

    local col = ECS.get(colonistId, 'colonist')
    if not col then return nil end

    local skill = 0
    if col.skills then skill = col.skills.hunting or col.skills.cooking or 0 end

    -- Base yield + skill bonus
    local amount = math.random(ICE_FISH_MIN, ICE_FISH_MAX)
    if skill >= 5 then amount = amount + 1 end
    if skill >= 10 then amount = amount + 1 end

    -- Season bonus: thaw gives better fishing
    local sok, Seasons = pcall(require, 'src.world.seasons')
    if sok then
        local season = Seasons.getCurrent()
        if season == 'thaw' or season == 'late_winter' then
            if math.random() < 0.3 then amount = amount + 1 end
        end
    end

    return 'food', amount
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function WaterFeatures.isGeyserErupting(x, y)
    local g = geysers[tileKey(x, y)]
    return g and g.erupting or false
end

function WaterFeatures.getGeyserState(x, y)
    return geysers[tileKey(x, y)]
end

function WaterFeatures.canFish(x, y)
    local wok, World = pcall(require, 'src.world.tilemap')
    if not wok then return false end
    local tile = World.getTile(x, y, 0)
    return tile == Tiles.FROZEN_RIVER or tile == Tiles.FROZEN_LAKE
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function WaterFeatures.getState()
    return {
        geysers = geysers,
        seasonCheckTimer = seasonCheckTimer,
    }
end

function WaterFeatures.loadState(saved)
    if not saved then return end
    geysers = saved.geysers or {}
    seasonCheckTimer = saved.seasonCheckTimer or 0
end

return WaterFeatures
