-- npc_ships.lua — NPC ship spawning and behavior AI
-- Spawns faction ships in space. Each has an AI state machine:
-- idle -> patrol -> detect -> chase/flee -> engage -> disengage

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local NPCShips = {}

---------------------------------------------------------------------------
-- NPC ship templates
---------------------------------------------------------------------------

local TEMPLATES = {
    utc_patrol = {
        faction = 'utc',
        name = 'UTC Ranger Patrol',
        behavior = 'patrol',
        hostility = 'neutral',  -- hail first
        speed = 2,
        hullHP = 80,
        fuel = 200,
        detectionRange = 15,
        weaponCount = 2,
    },
    mammona_patrol = {
        faction = 'mammona',
        name = 'Mammona Security Patrol',
        behavior = 'patrol',
        hostility = 'neutral',
        speed = 2,
        hullHP = 100,
        fuel = 250,
        detectionRange = 12,
        weaponCount = 3,
    },
    pirate_black_maw = {
        faction = 'black_maw',
        name = 'Black Maw Raider',
        behavior = 'hunt',
        hostility = 'hostile',
        speed = 3,
        hullHP = 60,
        fuel = 150,
        detectionRange = 10,
        weaponCount = 4,
    },
    pirate_void_serpent = {
        faction = 'void_serpents',
        name = 'Void Serpent Infiltrator',
        behavior = 'ambush',
        hostility = 'hostile',
        speed = 4,
        hullHP = 40,
        fuel = 120,
        detectionRange = 18,
        weaponCount = 1,
        stealthCapable = true,
    },
    pirate_rust_reaver = {
        faction = 'rust_reavers',
        name = 'Rust Reaver Scavenger',
        behavior = 'disable',
        hostility = 'hostile',
        speed = 2,
        hullHP = 70,
        fuel = 180,
        detectionRange = 8,
        weaponCount = 2,
    },
    caravan = {
        faction = 'independent',
        name = 'Trade Caravan',
        behavior = 'trade_route',
        hostility = 'friendly',
        speed = 1,
        hullHP = 50,
        fuel = 300,
        detectionRange = 6,
        weaponCount = 0,
        cargo = true,
    },
}

---------------------------------------------------------------------------
-- Spawn NPC ships around the player
---------------------------------------------------------------------------

local spawnCooldown = 0
local SPAWN_INTERVAL = 30  -- seconds between spawn checks
local MAX_NPC_SHIPS = 10

function NPCShips.spawnNearPlayer(dt)
    if GameState.activeMap ~= 'space' then return end

    spawnCooldown = spawnCooldown - dt
    if spawnCooldown > 0 then return end
    spawnCooldown = SPAWN_INTERVAL

    -- Count existing NPC ships
    local npcCount = 0
    for _ in ECS.query('npc_ship') do
        npcCount = npcCount + 1
    end
    if npcCount >= MAX_NPC_SHIPS then return end

    -- Find player ship position
    local playerX, playerY = 0, 0
    for id, comps in ECS.query('ship', 'pos') do
        if not ECS.has(id, 'npc_ship') then
            playerX = comps.pos.x
            playerY = comps.pos.y
            break
        end
    end

    -- Pick a random template weighted by location
    local templateKeys = {}
    for k, _ in pairs(TEMPLATES) do
        templateKeys[#templateKeys + 1] = k
    end
    local templateKey = templateKeys[math.random(#templateKeys)]
    local template = TEMPLATES[templateKey]

    -- Spawn at edge of sensor range
    local angle = math.random() * math.pi * 2
    local dist = 20 + math.random(10)
    local sx = playerX + math.cos(angle) * dist
    local sy = playerY + math.sin(angle) * dist

    local npcId = ECS.spawn()
    ECS.set(npcId, 'pos', { x = sx, y = sy })
    ECS.set(npcId, 'ship', {
        shipId = npcId,
        tier = 'npc',
        velocity = 0,
        heading = math.atan2(playerY - sy, playerX - sx),
        fuel = template.fuel,
        hullHP = template.hullHP,
    })
    ECS.set(npcId, 'npc_ship', {
        factionId = template.faction,
        behavior = template.behavior,
        hostility = template.hostility,
        templateId = templateKey,
        name = template.name,
        aiState = 'idle',
        targetId = nil,
        speed = template.speed,
        detectionRange = template.detectionRange,
        weaponCount = template.weaponCount,
        stealthCapable = template.stealthCapable or false,
        cargo = template.cargo or false,
        patrolAngle = math.random() * math.pi * 2,
    })
end

---------------------------------------------------------------------------
-- AI state machine (runs per NPC ship)
---------------------------------------------------------------------------

local function tickNPCAI(dt, id, comps)
    local npc = comps.npc_ship
    local ship = comps.ship
    local pos = comps.pos
    if not npc or not ship or not pos then return end

    -- Find player ship
    local playerX, playerY, playerFound = 0, 0, false
    for pid, pcomps in ECS.query('ship', 'pos') do
        if not ECS.has(pid, 'npc_ship') then
            playerX = pcomps.pos.x
            playerY = pcomps.pos.y
            playerFound = true
            break
        end
    end

    local dx = playerX - pos.x
    local dy = playerY - pos.y
    local distToPlayer = math.sqrt(dx * dx + dy * dy)

    -- State machine
    if npc.aiState == 'idle' then
        -- Transition to patrol after brief pause
        npc.aiState = 'patrol'

    elseif npc.aiState == 'patrol' then
        -- Move in patrol pattern
        npc.patrolAngle = (npc.patrolAngle or 0) + dt * 0.1
        ship.heading = npc.patrolAngle
        ship.velocity = npc.speed * 0.5

        -- Detect player
        if playerFound and distToPlayer < npc.detectionRange then
            if npc.hostility == 'hostile' then
                npc.aiState = 'chase'
                npc.targetId = nil  -- will find player each tick
            elseif npc.hostility == 'neutral' then
                npc.aiState = 'hail'
            end
            -- friendly ships ignore player
        end

    elseif npc.aiState == 'chase' then
        -- Move toward player
        if playerFound then
            ship.heading = math.atan2(dy, dx)
            ship.velocity = npc.speed

            if distToPlayer < 3 then
                npc.aiState = 'engage'
            elseif distToPlayer > npc.detectionRange * 2 then
                npc.aiState = 'disengage'
            end
        else
            npc.aiState = 'patrol'
        end

    elseif npc.aiState == 'engage' then
        -- In combat range — hold position, fire weapons
        ship.velocity = npc.speed * 0.3
        if playerFound then
            ship.heading = math.atan2(dy, dx)
        end

        -- Disengage if player escapes
        if distToPlayer > npc.detectionRange then
            npc.aiState = 'disengage'
        end

        -- Faction-specific combat behavior
        if npc.behavior == 'hunt' then
            -- Black Maw: aggressive, full speed pursuit
            ship.velocity = npc.speed
        elseif npc.behavior == 'ambush' then
            -- Void Serpents: try to circle behind
            ship.heading = ship.heading + math.pi * 0.1 * dt
        elseif npc.behavior == 'disable' then
            -- Rust Reavers: close in slowly for boarding
            ship.velocity = npc.speed * 0.2
        end

    elseif npc.aiState == 'hail' then
        -- Neutral ships: stop and attempt communication
        ship.velocity = 0

        -- For now, just transition back to patrol after a delay
        -- Full hailing UI is Phase 4 (combat)
        npc.aiState = 'patrol'

    elseif npc.aiState == 'flee' then
        -- Run away from player
        if playerFound then
            ship.heading = math.atan2(-dy, -dx)
            ship.velocity = npc.speed
        end
        if distToPlayer > npc.detectionRange * 3 then
            npc.aiState = 'despawn'
        end

    elseif npc.aiState == 'disengage' then
        -- Lost interest, return to patrol
        npc.aiState = 'patrol'

    elseif npc.aiState == 'despawn' then
        -- Too far from player, clean up
        ECS.destroy(id)
        return
    end

    -- Move the ship
    if ship.velocity > 0 then
        pos.x = pos.x + math.cos(ship.heading) * ship.velocity * dt
        pos.y = pos.y + math.sin(ship.heading) * ship.velocity * dt
    end

    -- Despawn if too far from player regardless of state
    if playerFound and distToPlayer > 60 then
        ECS.destroy(id)
    end
end

---------------------------------------------------------------------------
-- ECS System Registration
---------------------------------------------------------------------------

function NPCShips.registerSystems()
    ECS.addSystem('npc_ship_ai', {'npc_ship', 'ship', 'pos'}, tickNPCAI)
end

---------------------------------------------------------------------------
-- Step (called from main update loop)
---------------------------------------------------------------------------

function NPCShips.step(dt)
    NPCShips.spawnNearPlayer(dt)
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function NPCShips.getState()
    return {
        spawnCooldown = spawnCooldown,
    }
end

function NPCShips.loadState(state)
    if not state then return end
    spawnCooldown = state.spawnCooldown or 0
end

return NPCShips
