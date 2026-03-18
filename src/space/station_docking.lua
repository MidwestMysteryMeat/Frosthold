-- station_docking.lua — Station docking and services
-- Handles proximity-based docking at POI stations, service menus,
-- and interactions (repair, refuel, trade, bounties, star charts).

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local StationDocking = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local dockedAtPOI = nil  -- currently docked POI data, or nil
local DOCK_RANGE = 3     -- tiles from POI center to initiate docking

---------------------------------------------------------------------------
-- Service costs (credits)
---------------------------------------------------------------------------

local SERVICE_COSTS = {
    repair_hull   = 50,   -- per 10 HP repaired
    refuel        = 30,   -- per 50 fuel
    medical       = 100,  -- full heal one colonist
    star_chart    = 200,  -- reveals one undiscovered planet
}

---------------------------------------------------------------------------
-- Docking
---------------------------------------------------------------------------

function StationDocking.tryDock(poiId)
    local poi = GameState.discoveredPOIs and GameState.discoveredPOIs[poiId]
    if not poi then return false, 'Unknown POI' end

    -- Check proximity
    local playerX, playerY = 0, 0
    for id, comps in ECS.query('ship', 'pos') do
        if not ECS.has(id, 'npc_ship') then
            playerX = comps.pos.x
            playerY = comps.pos.y
            break
        end
    end

    local dx = poi.x - playerX
    local dy = poi.y - playerY
    if math.sqrt(dx * dx + dy * dy) > DOCK_RANGE then
        return false, 'Too far to dock'
    end

    -- Check faction reputation for gated stations
    if poi.faction and poi.faction ~= 'utc' and poi.faction ~= 'mammona' then
        local fok, Factions = pcall(require, 'src.colony.factions')
        if fok and Factions.getReputation then
            local rep = Factions.getReputation(poi.faction) or 0
            if rep < -50 then
                return false, 'Hostile reputation — docking denied'
            end
        end
    end

    dockedAtPOI = poi
    poi.visited = true

    -- Stop ship
    local smOk, ShipMovement = pcall(require, 'src.space.ship_movement')
    if smOk then
        ShipMovement.setThrust(false)
        ShipMovement.cancelAutopilot()
    end
    for id, comps in ECS.query('ship') do
        if not ECS.has(id, 'npc_ship') then
            comps.ship.velocity = 0
            break
        end
    end

    return true
end

function StationDocking.undock()
    dockedAtPOI = nil
end

function StationDocking.isDocked()
    return dockedAtPOI ~= nil
end

function StationDocking.getDockedStation()
    return dockedAtPOI
end

---------------------------------------------------------------------------
-- Services
---------------------------------------------------------------------------

function StationDocking.repairHull()
    if not dockedAtPOI then return false end
    local cost = SERVICE_COSTS.repair_hull
    if GameState.credits < cost then return false, 'Not enough credits' end

    for id, comps in ECS.query('ship') do
        if not ECS.has(id, 'npc_ship') then
            local ship = comps.ship
            if ship.hullHP < 100 then
                GameState.credits = GameState.credits - cost
                ship.hullHP = math.min(100, ship.hullHP + 10)
                return true
            end
        end
    end
    return false, 'Hull already at full'
end

function StationDocking.refuel()
    if not dockedAtPOI then return false end
    local cost = SERVICE_COSTS.refuel
    if GameState.credits < cost then return false, 'Not enough credits' end

    for id, comps in ECS.query('ship') do
        if not ECS.has(id, 'npc_ship') then
            local ship = comps.ship
            local ok, ShipDefs = pcall(require, 'src.space.ship_defs')
            local tier = ok and ShipDefs.getTier(ship.tier)
            local maxFuel = tier and tier.fuelCapacity or 100
            if ship.fuel < maxFuel then
                GameState.credits = GameState.credits - cost
                ship.fuel = math.min(maxFuel, ship.fuel + 50)
                return true
            end
        end
    end
    return false, 'Fuel already full'
end

function StationDocking.buyStarChart()
    if not dockedAtPOI then return false end
    local cost = SERVICE_COSTS.star_chart
    if GameState.credits < cost then return false, 'Not enough credits' end

    -- Find an undiscovered planet
    local planets = { 'erebus', 'rhea_2', 'morvos', 'nerthus_9', 'paxtera_prime', 'nemaea', 'gaia_a1x' }
    for _, planetId in ipairs(planets) do
        if not GameState.discoveredPlanets[planetId] then
            GameState.credits = GameState.credits - cost
            GameState.discoveredPlanets[planetId] = true

            local alOk, Alerts = pcall(require, 'src.ui.alerts')
            if alOk and Alerts.send then
                Alerts.send('DISCOVERY', 'Star chart acquired! ' .. planetId .. ' location revealed.')
            end
            return true
        end
    end
    return false, 'All planets already discovered'
end

function StationDocking.healColonist(entityId)
    if not dockedAtPOI then return false end
    local cost = SERVICE_COSTS.medical
    if GameState.credits < cost then return false, 'Not enough credits' end

    local col = ECS.get(entityId, 'colonist')
    if not col then return false, 'Not a colonist' end

    GameState.credits = GameState.credits - cost
    col.health = col.maxHealth or 100

    -- Clear wounds
    local wounds = ECS.get(entityId, 'wounds')
    if wounds and wounds.list then
        wounds.list = {}
    end

    return true
end

---------------------------------------------------------------------------
-- Sunny vending machine (StarByte stations)
---------------------------------------------------------------------------

function StationDocking.buySnack()
    if not dockedAtPOI then return false end
    local cost = 5  -- credits
    if GameState.credits < cost then return false, 'Not enough credits' end

    GameState.credits = GameState.credits - cost

    -- Morale boost for all colonists
    for cid, comps in ECS.query('colonist') do
        if not comps.colonist.dead then
            local needs = ECS.get(cid, 'needs')
            if needs then
                needs.morale = math.min(100, (needs.morale or 50) + 3)
            end
        end
    end

    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        local snacks = { 'Blast Bites', 'Star Puffs', 'CrunchWrapz', 'Sunny Fizz', 'ZapBerry Energy Blast' }
        Alerts.send('DISCOVERY', '"' .. snacks[math.random(#snacks)] .. '" dispensed. Sunny winks from the screen. Crew morale up.')
    end
    return true
end

---------------------------------------------------------------------------
-- Orbit Hub 71 interactions
---------------------------------------------------------------------------

function StationDocking.isOrbitHub71()
    return dockedAtPOI and dockedAtPOI.type == 'orbit_hub_71'
end

function StationDocking.repairHullMAR8()
    -- MARV-8 repairs at half price
    if not StationDocking.isOrbitHub71() then return StationDocking.repairHull() end
    local cost = 25  -- half normal price
    if GameState.credits < cost then return false, 'Not enough credits' end
    for id, comps in ECS.query('ship') do
        if not ECS.has(id, 'npc_ship') then
            if comps.ship.hullHP < 100 then
                GameState.credits = GameState.credits - cost
                comps.ship.hullHP = math.min(100, comps.ship.hullHP + 10)
                local alOk, Alerts = pcall(require, 'src.ui.alerts')
                if alOk and Alerts.send then
                    Alerts.send('DISCOVERY', 'MARV-8 patches the hull. Takes twice as long as necessary. "Not up to my standards yet. Give me another hour."')
                end
                return true
            end
        end
    end
    return false, 'Hull already at full'
end

function StationDocking.askSandyIntel()
    if not StationDocking.isOrbitHub71() then return false end
    local cost = 30
    if GameState.credits < cost then return false, 'Not enough credits' end
    GameState.credits = GameState.credits - cost

    -- Reveal 1-2 undiscovered POIs
    local revealed = 0
    for poiId, poi in pairs(GameState.discoveredPOIs or {}) do
        if not poi.visited and revealed < 2 then
            poi.visited = true  -- mark as known
            revealed = revealed + 1
        end
    end

    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        if revealed > 0 then
            Alerts.send('DISCOVERY', 'Sandy pauses mid-sentence about the nature of commerce. "Oh. You want useful information. Fine." ' .. revealed .. ' locations marked on your nav.')
        else
            Alerts.send('DISCOVERY', 'Sandy stares. "You already know everything I know. That is... unsettling."')
        end
    end
    return true
end

function StationDocking.talkToTessa()
    if not StationDocking.isOrbitHub71() then return false end
    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        local lines = {
            'Tessa leans against the counter. "I remember when cryo was just for the rich. Then Alaric made it cheap. Then Alaric disappeared. Funny how that works."',
            'Tessa stares at something behind you. "The old days? Before Mammona owned everything? Yeah. I remember. Not sure it was better. Just... different."',
            'Tessa pours something into a tin cup. "Alaric Voss. Brilliant man. Terrible judge of character. Built half the tech in this sector. Never saw the knife coming."',
            'Tessa looks at her hands. "Alaric designed half the cryo pods on Foras. His own pod killed him. Fifty-eight years of perfect function and then one seal fails."',
            'Tessa taps the counter. "Gus Wallace. That was a name. Miner. Built like a wall. He was in Shaft 12 when the Maw opened. Never found him."',
            'Tessa stares past you. "I knew Alexi Belov. Mine boss. Cut every corner Mammona told him to cut. Killed more people than the explosion did."',
            'Tessa pours something. "MARV-8 was alone for fifty-eight years. Kept the lights on. Fixed every leak. Talked to himself the whole time. He will not admit it but he named the rats."',
            'Tessa crosses her arms. "Acedia. City of Rot. That is where the workers went when Mammona threw them out. I wonder if anything is left."',
            'Tessa goes quiet. "Foras was supposed to be a fresh start. Five hundred people on the Kennedy. By the end, Mammona had turned it into a strip mine with bodies."',
            'Tessa checks a panel. "Victor Alba was the chaplain. Kept the miners from breaking when everything else did. I heard he stopped believing before the end. Cannot blame him."',
        }
        Alerts.send('DISCOVERY', lines[math.random(#lines)])
    end
    return true
end

function StationDocking.talkToCass()
    if not StationDocking.isOrbitHub71() then return false end
    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        local lines = {
            'Cass adjusts his collar. "Supply deals? Sure. I can get you anything. Just don\'t ask where it comes from. Mammona has... long arms."',
            'Cass lowers his voice. "Between you and me, the freight routes are shifting. Mammona is pulling resources from the outer rim. Something big is coming."',
            'Cass grins, but it doesn\'t reach his eyes. "I owe some people. The kind of people who don\'t forget. But business is business, right?"',
            'Cass leans back. "I was seven when they put me in the pod. Woke up and the galaxy had moved on. Everyone I knew in school is either dead or old."',
            'Cass fidgets. "Mammona offered me a deal. Exclusive vending rights for three sectors. All I have to do is not ask questions. Mom would kill me if she knew."',
            'Cass looks at the floor. "Dad did not wake up. Mom does not talk about it. MARV-8 does not talk about it. I do not remember him well enough to miss him properly. That is the worst part."',
            'Cass grins. "You need supplies? I know a guy at the OmniCorp depot. Fell off a truck, as they say. Do not tell Tessa."',
            'Cass gets serious. "The freight routes are shifting. Mammona is pulling resources inward. When corps do that, it means they are building something. Or running from something."',
            'Cass counts credits. "Novaris-3 locked down another trade corridor. Vanguard Alliance squeezing everyone. Makes my job harder. Makes my prices higher."',
            'Cass shakes his head. "Nyxport is still there. Ghost town. Trader told me the docks are intact. Nobody goes near them. Bad luck, they say. Bad everything."',
        }
        Alerts.send('DISCOVERY', lines[math.random(#lines)])
    end
    return true
end

function StationDocking.talkToMARV8()
    if not StationDocking.isOrbitHub71() then return false end
    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        local lines = {
            'MARV-8 adjusts a panel that does not need adjusting. "Fifty-eight years alone. I do not recommend it. The silence was... loud."',
            'MARV-8 pauses mid-repair. "I designed Sunny to be charming. Not sentient. That was an accident. A good accident. Mostly."',
            'MARV-8 rotates toward you. "My data core has logs from the first Foras expedition. Fragmented. Encrypted. Tessa will not let me wipe them. Says they might be worth something."',
            'MARV-8 tilts his head. "Alaric. Good man. Built better than most. His pod was unit 7. Seal degradation. Point-oh-three percent failure rate. He was the point-oh-three."',
            'MARV-8 taps the wall. "I named the rats. During the fifty-eight years. There were four generations. Do not tell Tessa."',
            'MARV-8 whirs. "My sarcasm module is outdated. Tessa says it fires at inappropriate moments. I say it fires at perfectly appropriate moments. That is the sarcasm."',
            'MARV-8 stops. "I found him. Alaric. When the pods opened. I had to be the one to tell Tessa. I am a maintenance bot. I was not built for that."',
            'MARV-8 clicks. "Delta Block on Thalassa Deep. I have fragments of a transmission from there in my data core. Something about flooding. And something else. The signal cuts out."',
        }
        Alerts.send('DISCOVERY', lines[math.random(#lines)])
    end
    return true
end

---------------------------------------------------------------------------
-- Get available services at current station
---------------------------------------------------------------------------

function StationDocking.getAvailableServices()
    if not dockedAtPOI then return {} end
    return dockedAtPOI.services or {}
end

function StationDocking.getServiceCost(serviceId)
    return SERVICE_COSTS[serviceId]
end

---------------------------------------------------------------------------
-- Auto-dock check (called from update loop)
---------------------------------------------------------------------------

function StationDocking.checkProximityDocking()
    if GameState.activeMap ~= 'space' then return end
    if dockedAtPOI then return end  -- already docked

    local playerX, playerY = 0, 0
    local found = false
    for id, comps in ECS.query('ship', 'pos') do
        if not ECS.has(id, 'npc_ship') then
            playerX = comps.pos.x
            playerY = comps.pos.y
            found = true
            break
        end
    end
    if not found then return end

    -- Check all POIs
    local pois = GameState.discoveredPOIs or {}
    for poiId, poi in pairs(pois) do
        local dx = poi.x - playerX
        local dy = poi.y - playerY
        if math.sqrt(dx * dx + dy * dy) <= DOCK_RANGE then
            if poi.type ~= 'derelict' then
                -- Auto-announce proximity (don't auto-dock)
                local alOk, Alerts = pcall(require, 'src.ui.alerts')
                if alOk and Alerts.send and not poi._proximityAnnounced then
                    Alerts.send('DISCOVERY', 'Approaching: ' .. (poi.name or 'Unknown Station'))
                    poi._proximityAnnounced = true
                end
            end
            return
        end
    end
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function StationDocking.getState()
    return {
        dockedAtPOIId = dockedAtPOI and dockedAtPOI.id or nil,
    }
end

function StationDocking.loadState(state)
    if not state then return end
    if state.dockedAtPOIId and GameState.discoveredPOIs then
        dockedAtPOI = GameState.discoveredPOIs[state.dockedAtPOIId]
    end
end

return StationDocking
