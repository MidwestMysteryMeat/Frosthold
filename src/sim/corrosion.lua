-- corrosion.lua -- Acid atmosphere corrosion (Morvos)
-- Outdoor buildings and unsealed structures degrade over time.
-- Sealed/insulated buildings resist corrosion.
-- Only active on Morvos (planet ID check at init).

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Corrosion = {}

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

local TICK_INTERVAL = 5.0   -- process every ~5 seconds, not every tick
local OUTDOOR_RATE  = 0.1   -- durability lost per second (outdoor)
local INDOOR_RATE   = 0.03  -- durability lost per second (indoor, unsealed)
local STORM_MULT    = 2.0   -- multiplier during acid_storm or corrosion_peak

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local active     = false   -- true only on Morvos
local timer      = 0

---------------------------------------------------------------------------
-- Init -- check planet, activate only on Morvos
---------------------------------------------------------------------------

function Corrosion.init()
    active = (GameState.planet == 'morvos')
    timer = 0
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function getWeatherMultiplier()
    local wok, Weather = pcall(require, 'src.weather.weather')
    if not wok then return 1.0 end
    local current = Weather.getCurrent()
    if current == 'acid_storm' or current == 'corrosive_fog' then
        return STORM_MULT
    end
    -- Season check: corrosion_peak doubles corrosion regardless of weather
    if GameState.season == 'corrosion_peak' then
        return STORM_MULT
    end
    return 1.0
end

local function isSealed(roomId)
    if roomId == 0 then return false end
    local rok, Rooms = pcall(require, 'src.world.rooms')
    if not rok then return false end
    local info = Rooms.getRoomInfo(roomId)
    if info and info.sealed then return true end
    return false
end

---------------------------------------------------------------------------
-- Step -- called each sim tick with dt
---------------------------------------------------------------------------

function Corrosion.step(dt)
    if not active then return end

    timer = timer + dt
    if timer < TICK_INTERVAL then return end
    timer = timer - TICK_INTERVAL

    local elapsed = TICK_INTERVAL  -- effective seconds since last process
    local weatherMult = getWeatherMultiplier()

    local World
    local wok, W = pcall(require, 'src.world.tilemap')
    if wok then World = W end

    for id, comps in ECS.query('durability', 'pos') do
        local dur = comps.durability
        local pos = comps.pos

        -- Determine room: 0 = outdoors
        local roomId = 0
        if World and World.getRoom then
            roomId = World.getRoom(pos.x, pos.y, pos.depth or 0) or 0
        end

        local rate
        if roomId == 0 then
            -- Outdoor: full corrosion
            rate = OUTDOOR_RATE
        elseif isSealed(roomId) then
            -- Indoor sealed: no corrosion
            rate = 0
        else
            -- Indoor unsealed: reduced corrosion
            rate = INDOOR_RATE
        end

        if rate > 0 then
            local damage = rate * elapsed * weatherMult
            dur.current = dur.current - damage
            if dur.current < 0 then dur.current = 0 end

            -- Destroy at zero durability
            if dur.current <= 0 then
                local jok, Jobs = pcall(require, 'src.colonist.jobs')
                if jok and dur.repairTask then
                    Jobs.cancelTask(dur.repairTask)
                end

                local bok, Building = pcall(require, 'src.building.building')
                if bok and Building.remove then
                    Building.remove(pos.x, pos.y, pos.depth)
                end

                ECS.destroy(id)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Corrosion.getState()
    return {
        active = active,
        timer  = timer,
    }
end

function Corrosion.loadState(data)
    if not data then return end
    active = data.active or false
    timer  = data.timer or 0
end

return Corrosion
