-- easter_eggs.lua -- rare atmospheric discovery events
-- The Markiplier easter egg (Fischbach colonist + blood rain) lives in
-- weather.lua for Erebus. On Nerthus-9 the ocean turns blood red and rises.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')

local EasterEggs = {}

local state = {}

-- Original ocean/water tile colors (stored on first activation to restore later)
local ORIGINAL_COLORS = {}

local BLOOD_OCEAN_COLORS = {
    [Tiles.OCEAN]    = {0.45, 0.05, 0.05},
    [Tiles.SHALLOWS] = {0.55, 0.1, 0.1},
    [Tiles.WATER]    = {0.5, 0.08, 0.08},
    [Tiles.SEAWEED]  = {0.35, 0.1, 0.05},
}

local BLOOD_RISE_INTERVAL = 2.0   -- seconds between flood pulses
local BLOOD_CHECK_DAY     = 2    -- check once on this game day (not recurring)
local BLOOD_RAIN_DURATION = 180  -- seconds of blood rain on non-ocean planets

local function resetState()
    state = {
        bloodOceanActive = false,
        bloodOceanFired  = false,  -- only triggers once per game
        checked          = false,  -- true after the one-time day-2 check
        riseTimer        = 0,
        -- Non-ocean planets: blood rain timer
        bloodRainTimer   = 0,
        bloodRainActive  = false,
    }
end

--- Check if any living colonist has "Fischbach" as their last name.
local function hasFischbachColonist()
    for _, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' and comps.colonist.name then
            if comps.colonist.name:match('%s[Ff]ischbach$') then
                return true
            end
        end
    end
    return false
end

--- Activate the blood ocean: change tile colors and start water rise.
local function activateBloodOcean()
    if state.bloodOceanActive then return end
    state.bloodOceanActive = true
    state.bloodOceanFired = true

    -- Store original colors and swap to blood
    for tileId, bloodColor in pairs(BLOOD_OCEAN_COLORS) do
        local props = Tiles.props[tileId]
        if props then
            ORIGINAL_COLORS[tileId] = { props.color[1], props.color[2], props.color[3] }
            props.color = bloodColor
        end
    end

    -- Alert
    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send('The Ocean Bleeds',
            'The water turns red. All of it. At once. It is rising.',
            'critical')
    end
end

--- Deactivate blood ocean (restore colors). Only happens when Fischbach
--- dies inside a submersible (diving bell or underwater hab at depth > 0).
local function deactivateBloodOcean()
    if not state.bloodOceanActive then return end
    state.bloodOceanActive = false

    for tileId, origColor in pairs(ORIGINAL_COLORS) do
        local props = Tiles.props[tileId]
        if props and origColor then
            props.color = origColor
        end
    end
    ORIGINAL_COLORS = {}

    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send('The Ocean Calms',
            'The red drains from the water. The tide recedes. Whatever it was, it is satisfied.',
            'major')
    end
end

--- Check if Fischbach died underwater (depth > 0). Called from kill/death hooks.
function EasterEggs.onColonistDeath(entityId)
    if not state.bloodOceanActive then return end
    if GameState.planet ~= 'nerthus_9' then return end

    local col = ECS.get(entityId, 'colonist')
    if not col or not col.name then return end
    if not col.name:match('%s[Ff]ischbach$') then return end

    -- Must die at depth > 0 (underwater / in submersible)
    local pos = ECS.get(entityId, 'pos')
    if pos and (pos.depth or 0) > 0 then
        deactivateBloodOcean()
    end
    -- If died on surface, ocean stays blood red forever
end

function EasterEggs.init()
    resetState()
end

function EasterEggs.step(dt)
    -- One-time Fischbach check on day 2
    if not state.checked then
        if GameState.day >= BLOOD_CHECK_DAY then
            state.checked = true
            if not state.bloodOceanFired and hasFischbachColonist() then
                if GameState.planet == 'nerthus_9' then
                    -- Ocean planet: permanent blood ocean
                    activateBloodOcean()
                else
                    -- Other planets: trigger blood rain + flooding for limited time
                    state.bloodRainActive = true
                    state.bloodRainTimer = BLOOD_RAIN_DURATION
                    state.bloodOceanFired = true
                    local wOk, Weather = pcall(require, 'src.weather.weather')
                    if wOk and Weather.force then
                        Weather.force('blood_rain', BLOOD_RAIN_DURATION)
                    end
                    local aok, Alerts = pcall(require, 'src.ui.alerts')
                    if aok and Alerts.send then
                        Alerts.send('Blood Rain',
                            'The sky turns red. It is raining something that is not water.',
                            'major')
                    end
                end
            end
        else
            return
        end
    end

    -- Non-ocean blood rain countdown
    if state.bloodRainActive then
        state.bloodRainTimer = state.bloodRainTimer - dt
        if state.bloodRainTimer <= 0 then
            state.bloodRainActive = false
        end
    end

    -- Nerthus-9 only below this point
    if GameState.planet ~= 'nerthus_9' then return end
    if not state.bloodOceanActive then return end

    -- Blood ocean rising: inject water into surface tiles periodically
    if state.bloodOceanActive then
        state.riseTimer = state.riseTimer + dt
        if state.riseTimer >= BLOOD_RISE_INTERVAL then
            state.riseTimer = state.riseTimer - BLOOD_RISE_INTERVAL

            local wok, World = pcall(require, 'src.world.tilemap')
            if wok then
                local w, h = World.width(), World.height()
                local samples = math.min(w * h, 60)
                for _ = 1, samples do
                    local rx = math.random(0, w - 1)
                    local ry = math.random(0, h - 1)
                    local tile = World.getTile(rx, ry, 0)
                    if tile and not Tiles.isSolid(tile) then
                        local tfOk, TileFluids = pcall(require, 'src.sim.tile_fluids')
                        if tfOk and TileFluids.addWater then
                            TileFluids.addWater(rx, ry, 1, 0)
                        end
                    end
                end
            end
        end
    end

    -- Fischbach submersible curse: if Mark is inside a submersible,
    -- it degrades and leaks blood water into the sealed room
    for id, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.name and col.name:match('%s[Ff]ischbach$') then
            local pos = comps.pos
            if pos and (pos.depth or 0) > 0 then
                -- Check if standing on a submersible tile (SEALED_FLOOR placed by submersible)
                local wok2, World2 = pcall(require, 'src.world.tilemap')
                if wok2 then
                    local bOk, Building = pcall(require, 'src.building.building')
                    if bOk and Building.getAt then
                        local bld = Building.getAt(pos.x, pos.y, pos.depth)
                        if bld and bld.defId == 'submersible' then
                            -- Degrade the submersible's durability
                            if bld.entityId then
                                local dur = ECS.get(bld.entityId, 'durability')
                                if dur then
                                    dur.current = dur.current - 0.15 * dt
                                    if dur.current < 0 then dur.current = 0 end
                                end
                            end
                            -- Leak blood water into the submersible's tiles
                            local tfOk, TileFluids = pcall(require, 'src.sim.tile_fluids')
                            if tfOk and TileFluids.addWater then
                                TileFluids.addWater(pos.x, pos.y, 1, pos.depth)
                            end
                        end
                    end
                end
            end
        end
    end
end

function EasterEggs.isBloodOcean()
    return state.bloodOceanActive
end

function EasterEggs.getState()
    return {
        bloodOceanActive = state.bloodOceanActive,
        bloodOceanFired  = state.bloodOceanFired,
        checked          = state.checked,
        bloodRainActive  = state.bloodRainActive,
        bloodRainTimer   = state.bloodRainTimer,
    }
end

function EasterEggs.restoreState(saved)
    resetState()
    if saved then
        state.bloodOceanFired = saved.bloodOceanFired or false
        state.bloodOceanActive = saved.bloodOceanActive or false
        state.checked = saved.checked or false
        state.bloodRainActive = saved.bloodRainActive or false
        state.bloodRainTimer = saved.bloodRainTimer or 0
        -- Re-apply blood colors if active
        if state.bloodOceanActive then
            for tileId, bloodColor in pairs(BLOOD_OCEAN_COLORS) do
                local props = Tiles.props[tileId]
                if props then
                    ORIGINAL_COLORS[tileId] = { props.color[1], props.color[2], props.color[3] }
                    props.color = bloodColor
                end
            end
        end
    end
end

resetState()

return EasterEggs
