-- hazards.lua — Space environmental hazards
-- Debris fields damage hull, radiation zones harm crew, solar flares
-- disable electronics, micrometeorite storms cause sustained damage.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Hazards = {}

---------------------------------------------------------------------------
-- Hazard state
---------------------------------------------------------------------------

local activeSolarFlare = false
local solarFlareTimer = 0
local SOLAR_FLARE_DURATION = 30   -- seconds
local SOLAR_FLARE_COOLDOWN = 300  -- seconds between flares

local microStormActive = false
local microStormTimer = 0
local MICRO_STORM_DURATION = 20

local nextFlareCheck = 0
local nextStormCheck = 0

---------------------------------------------------------------------------
-- Debris / Asteroid collision
---------------------------------------------------------------------------

local function checkTileHazards(dt)
    for id, comps in ECS.query('ship', 'pos') do
        if ECS.has(id, 'npc_ship') then goto continue end
        local pos = comps.pos
        local ship = comps.ship

        local stOk, SpaceTilemap = pcall(require, 'src.space.space_tilemap')
        if not stOk then goto continue end

        local tile = SpaceTilemap.getTile(math.floor(pos.x), math.floor(pos.y))

        if tile == 100 then  -- DEBRIS_TILE
            -- Debris damages hull slightly on contact
            if ship.velocity > 0.5 then
                ship.hullHP = math.max(0, ship.hullHP - dt * 2)
            end
        elseif tile == 99 then  -- ASTEROID_TILE
            -- Asteroid blocks movement — push ship back
            if ship.velocity > 0 then
                pos.x = pos.x - math.cos(ship.heading or 0) * ship.velocity * dt * 2
                pos.y = pos.y - math.sin(ship.heading or 0) * ship.velocity * dt * 2
                ship.velocity = 0
                ship.hullHP = math.max(0, ship.hullHP - 5)
            end
        elseif tile == 101 then  -- STAR — impassable, lethal
            pos.x = pos.x - math.cos(ship.heading or 0) * ship.velocity * dt * 3
            pos.y = pos.y - math.sin(ship.heading or 0) * ship.velocity * dt * 3
            ship.velocity = 0
            ship.hullHP = math.max(0, ship.hullHP - 20)
        elseif tile == 102 then  -- STAR_CORONA — extreme heat damage
            ship.hullHP = math.max(0, ship.hullHP - dt * 10)
            for cid in ECS.query('colonist') do
                local col = ECS.get(cid, 'colonist')
                if col and not col.dead then
                    col.health = math.max(1, (col.health or 100) - dt * 3)
                end
                break
            end
        elseif tile == 103 then  -- DYSON_INTACT — impassable structure
            if ship.velocity > 0 then
                pos.x = pos.x - math.cos(ship.heading or 0) * ship.velocity * dt * 2
                pos.y = pos.y - math.sin(ship.heading or 0) * ship.velocity * dt * 2
                ship.velocity = 0
                ship.hullHP = math.max(0, ship.hullHP - 3)
            end
        elseif tile == 104 then  -- DYSON_CRUMBLED — passable debris, minor damage
            if ship.velocity > 0.5 then
                ship.hullHP = math.max(0, ship.hullHP - dt * 1)
            end
        elseif tile == 106 then  -- GRAVITY_WELL — slows ships
            ship.velocity = math.max(0, ship.velocity * 0.95)
        end

        ::continue::
    end
end

---------------------------------------------------------------------------
-- Radiation zones (near certain POIs or nebulae)
---------------------------------------------------------------------------

local function checkRadiation(dt)
    -- Check if player ship is near a radiation source
    for id, comps in ECS.query('ship', 'pos') do
        if ECS.has(id, 'npc_ship') then goto continue end
        local pos = comps.pos

        -- Near Nemaea orbit = high radiation
        local pokGen, POIGen = pcall(require, 'src.space.poi_generator')
        if pokGen then
            local nemaeaPos = POIGen.getPlanetPosition('nemaea')
            if nemaeaPos then
                local dx = pos.x - nemaeaPos.x
                local dy = pos.y - nemaeaPos.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < 100 then
                    -- Apply radiation to crew
                    local doseRate = 0.05 * (1 - dist / 100)
                    for cid, ccomps in ECS.query('colonist', 'pos') do
                        local rad = ECS.get(cid, 'radiation')
                        if not rad then
                            ECS.set(cid, 'radiation', { dose = 0, resistance = 0 })
                            rad = ECS.get(cid, 'radiation')
                        end
                        -- Suit reduces radiation
                        local suit = ECS.get(cid, 'space_suit')
                        local reduction = suit and 0.7 or 0
                        rad.dose = (rad.dose or 0) + doseRate * dt * (1 - reduction)
                    end
                end
            end
        end

        ::continue::
    end
end

---------------------------------------------------------------------------
-- Solar flares (periodic)
---------------------------------------------------------------------------

local function checkSolarFlares(dt)
    if activeSolarFlare then
        solarFlareTimer = solarFlareTimer - dt
        if solarFlareTimer <= 0 then
            activeSolarFlare = false
            nextFlareCheck = SOLAR_FLARE_COOLDOWN

            local alOk, Alerts = pcall(require, 'src.ui.alerts')
            if alOk and Alerts.send then
                Alerts.send('DISCOVERY', 'Solar flare subsided. Systems coming back online.')
            end
        else
            -- During flare: disable shields and sensors
            for modId, comps in ECS.query('ship_module') do
                local mod = comps.ship_module
                if mod.systemType == 'shield_generator' or mod.systemType == 'sensor_array' then
                    mod._flareSuppressed = true
                    mod.efficiency = 0
                end
            end
        end
    else
        nextFlareCheck = nextFlareCheck - dt
        if nextFlareCheck <= 0 then
            -- Check for flare (higher chance near Rhea-2)
            local chance = 0.1
            local pokGen, POIGen = pcall(require, 'src.space.poi_generator')
            if pokGen then
                for id, comps in ECS.query('ship', 'pos') do
                    if not ECS.has(id, 'npc_ship') then
                        local rheaPos = POIGen.getPlanetPosition('rhea_2')
                        if rheaPos then
                            local dx = comps.pos.x - rheaPos.x
                            local dy = comps.pos.y - rheaPos.y
                            if math.sqrt(dx * dx + dy * dy) < 200 then
                                chance = 0.3
                            end
                        end
                        break
                    end
                end
            end

            if math.random() < chance then
                activeSolarFlare = true
                solarFlareTimer = SOLAR_FLARE_DURATION

                local alOk, Alerts = pcall(require, 'src.ui.alerts')
                if alOk and Alerts.send then
                    Alerts.send('POWER OUTAGE', 'Solar flare! Shields and sensors offline!')
                end
            end
            nextFlareCheck = SOLAR_FLARE_COOLDOWN
        end
    end
end

---------------------------------------------------------------------------
-- Micrometeorite storms (random event)
---------------------------------------------------------------------------

local function checkMicroStorms(dt)
    if microStormActive then
        microStormTimer = microStormTimer - dt
        if microStormTimer <= 0 then
            microStormActive = false
            nextStormCheck = 120

            local alOk, Alerts = pcall(require, 'src.ui.alerts')
            if alOk and Alerts.send then
                Alerts.send('DISCOVERY', 'Micrometeorite storm has passed.')
            end
        else
            -- Sustained hull damage
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    comps.ship.hullHP = math.max(0, comps.ship.hullHP - dt * 1.5)
                    break
                end
            end
            -- EVA crew take injury
            for cid, ccomps in ECS.query('colonist', 'space_suit') do
                local col = ccomps.colonist
                if col and not col.dead then
                    col.health = math.max(1, (col.health or 100) - dt * 0.5)
                end
            end
        end
    else
        nextStormCheck = nextStormCheck - dt
        if nextStormCheck <= 0 then
            if math.random() < 0.15 then
                microStormActive = true
                microStormTimer = MICRO_STORM_DURATION

                local alOk, Alerts = pcall(require, 'src.ui.alerts')
                if alOk and Alerts.send then
                    Alerts.send('FIRE', 'Micrometeorite storm! Take shelter inside the hull!')
                end
            end
            nextStormCheck = 120
        end
    end
end

---------------------------------------------------------------------------
-- Restore suppressed modules after flare
---------------------------------------------------------------------------

local function restoreFlareSuppressed()
    if not activeSolarFlare then
        for modId, comps in ECS.query('ship_module') do
            local mod = comps.ship_module
            if mod._flareSuppressed then
                mod._flareSuppressed = nil
                if mod.operational then
                    mod.efficiency = 1.0
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Hazards.step(dt)
    if GameState.activeMap ~= 'space' then return end
    checkTileHazards(dt)
    checkRadiation(dt)
    checkSolarFlares(dt)
    checkMicroStorms(dt)
    restoreFlareSuppressed()
end

function Hazards.isSolarFlareActive()
    return activeSolarFlare
end

function Hazards.isMicroStormActive()
    return microStormActive
end

function Hazards.getState()
    return {
        activeSolarFlare = activeSolarFlare,
        solarFlareTimer = solarFlareTimer,
        microStormActive = microStormActive,
        microStormTimer = microStormTimer,
        nextFlareCheck = nextFlareCheck,
        nextStormCheck = nextStormCheck,
    }
end

function Hazards.loadState(state)
    if not state then return end
    activeSolarFlare = state.activeSolarFlare or false
    solarFlareTimer = state.solarFlareTimer or 0
    microStormActive = state.microStormActive or false
    microStormTimer = state.microStormTimer or 0
    nextFlareCheck = state.nextFlareCheck or 0
    nextStormCheck = state.nextStormCheck or 0
end

return Hazards
