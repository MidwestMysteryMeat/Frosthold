-- pressure.lua — Underwater pressure system (Nerthus-9)
-- Depth-based water pressure affects colonists and structures.
-- Sealed rooms (airlocks, pressure domes) negate pressure.
-- Diving suits provide partial pressure resistance.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Pressure = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local PRESSURE_PER_DEPTH    = 1.0   -- pressure units per depth level
local PRESSURE_DAMAGE_RATE  = 0.15  -- HP/sec per unit of unresisted pressure
local PRESSURE_MOVE_PENALTY = 0.08  -- movement slow per unit of unresisted pressure
local CRUSH_THRESHOLD       = 4.0   -- pressure above this = rapid death
local CRUSH_DAMAGE_RATE     = 2.0   -- HP/sec when above crush threshold

-- Whether pressure is active (only on ocean worlds)
local pressureActive = false

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Pressure.init()
    pressureActive = false
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then
        local pid = Planet.getId()
        -- Pressure system only active on Nerthus-9
        if pid == 'nerthus_9' then
            pressureActive = true
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

--- Returns the water pressure at a given depth. 0 at surface, scales linearly.
function Pressure.atDepth(depth)
    if not pressureActive then return 0 end
    if not depth or depth <= 0 then return 0 end
    return depth * PRESSURE_PER_DEPTH
end

--- Returns true if a room at the given depth is sealed against pressure.
--- A sealed room has no water (water level 0 in all tiles) and is enclosed.
function Pressure.isRoomSealed(x, y, depth)
    if not pressureActive or not depth or depth <= 0 then return true end

    local wok, World = pcall(require, 'src.world.tilemap')
    if not wok then return true end

    -- Check if tile's room is sealed (room ID > 0 means enclosed)
    local roomId = World.getRoom(x, y, depth)
    if not roomId or roomId == 0 then return false end -- outdoor = not sealed

    -- Check water level at this tile
    local water = World.getWater(x, y, depth)
    if water and water > 0.5 then return false end -- flooded room = not sealed

    return true
end

--- Returns the effective pressure on an entity (0 if in sealed room or on surface).
function Pressure.getEffectivePressure(x, y, depth)
    if not pressureActive then return 0 end
    if not depth or depth <= 0 then return 0 end
    if Pressure.isRoomSealed(x, y, depth) then return 0 end
    return Pressure.atDepth(depth)
end

--- Returns pressure resistance (0-1) for an entity from clothing.
function Pressure.getSuitResist(entityId)
    local cok, Clothing = pcall(require, 'src.colonist.clothing')
    if cok and Clothing.getProtection then
        local prot = Clothing.getProtection(entityId)
        if prot and prot.pressure then
            return prot.pressure / 100  -- clothing uses 0-100, pressure uses 0-1
        end
    end
    return 0
end

---------------------------------------------------------------------------
-- Step — apply pressure effects to colonists
---------------------------------------------------------------------------

function Pressure.step(dt)
    if not pressureActive then return end

    for id, comps in ECS.query('colonist', 'pos') do
        if comps.colonist.state == 'dead' then goto continue end

        local pos = comps.pos
        local depth = pos.depth or 0
        if depth <= 0 then goto continue end

        local pressure = Pressure.getEffectivePressure(pos.x, pos.y, depth)
        if pressure <= 0 then goto continue end

        -- Suit reduces pressure
        local suitResist = Pressure.getSuitResist(id)
        local effectivePressure = pressure * (1 - suitResist)

        if effectivePressure <= 0 then goto continue end

        -- Apply pressure damage
        local damageRate = PRESSURE_DAMAGE_RATE * effectivePressure
        if effectivePressure > CRUSH_THRESHOLD then
            damageRate = CRUSH_DAMAGE_RATE * effectivePressure
        end

        local needs = comps.needs
        if needs and needs.health then
            needs.health = needs.health - damageRate * dt
            if needs.health <= 0 then
                comps.colonist.state = 'dead'
                comps.colonist.causeOfDeath = 'pressure_crush'
            end
        end

        ::continue::
    end
end

---------------------------------------------------------------------------
-- State (save/load)
---------------------------------------------------------------------------

function Pressure.getState()
    return { active = pressureActive }
end

function Pressure.loadState(state)
    if state then
        pressureActive = state.active or false
    end
end

return Pressure
