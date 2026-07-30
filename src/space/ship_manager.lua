-- ship_manager.lua — Ship entity group management
-- Creates ship entities from definitions, stamps ships onto colony maps
-- for landing, and extracts them on launch.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local ShipManager = {}

---------------------------------------------------------------------------
-- Create a ship entity group from a tier + prebuilt definition
---------------------------------------------------------------------------

function ShipManager.createShip(tierId, prebuiltId)
    local ok, ShipDefs = pcall(require, 'src.space.ship_defs')
    if not ok then return nil end

    local tier = ShipDefs.getTier(tierId)
    if not tier then return nil end

    local prebuilt = prebuiltId and ShipDefs.getPrebuilt(prebuiltId)

    -- Create ship anchor entity
    local shipId = ECS.spawn()
    ECS.set(shipId, 'ship', {
        shipId   = shipId,
        tier     = tierId,
        velocity = 0,
        heading  = 0,
        fuel     = tier.fuelCapacity,
        hullHP   = 100,
    })
    ECS.set(shipId, 'pos', { x = 0, y = 0 })

    -- Place required modules as entities
    local modules = (prebuilt and prebuilt.modules) or {}
    for _, mod in ipairs(modules) do
        local modId = ECS.spawn()
        ECS.set(modId, 'pos', { x = mod.x, y = mod.y })
        ECS.set(modId, 'ship_module', {
            shipId     = shipId,
            systemType = mod.id,
            operational = true,
            efficiency = 1.0,
        })
        ECS.set(modId, 'durability', { hp = 100, maxHp = 100 })
    end

    -- Place extra buildings from prebuilt
    if prebuilt and prebuilt.extras then
        for _, extra in ipairs(prebuilt.extras) do
            local extraId = ECS.spawn()
            ECS.set(extraId, 'pos', { x = extra.x, y = extra.y })
            ECS.set(extraId, 'building_ref', { buildingId = extra.building })
            ECS.set(extraId, 'ship_module', {
                shipId     = shipId,
                systemType = extra.building,
                operational = true,
                efficiency = 1.0,
            })
            ECS.set(extraId, 'durability', { hp = 100, maxHp = 100 })
        end
    end

    return shipId
end

---------------------------------------------------------------------------
-- Component list for extraction — mirrors KNOWN_COMPONENTS in save_helpers
---------------------------------------------------------------------------

local EXTRACT_COMPONENTS = {
    'pos', 'colonist', 'needs', 'inventory', 'path',
    'schedule', 'workPriority', 'creature', 'machine',
    'bed', 'decoration', 'durability', 'building_ref',
    'merchant', 'disease', 'steam_hub', 'body', 'equipment',
    'prisoner', 'cloning_vat', 'radio_beacon', 'raid_tag', 'boss',
    'crop', 'artifact', 'sensor',
    'item', 'away', 'projectile', 'status_effects',
    'wounds', 'diseaseImmunity', 'tamed', 'suit',
    'lair', 'eldritch_growth', 'deep_drill', 'inserter', 'research_bench',
    'turret', 'trap', 'shield', 'watchtower', 'quest_board',
    'addictions', 'cover',
    'pipe_node', 'tank', 'processor',
    'battery', 'power_switch',
    'ordnance', 'stockpile', 'rival',
    'laser_fence', 'endgame_building', 'visitor', 'recreation',
    'containment_cell', 'radiation', 'miner', 'storage', 'clothing',
    'ship', 'ship_module', 'ship_crew', 'weapon_mount',
    'stealth', 'space_suit', 'npc_ship',
}

---------------------------------------------------------------------------
-- Stamp ship entities onto a colony tilemap at landing pad position
---------------------------------------------------------------------------

function ShipManager.stampOntoColony(shipSnapshot, padX, padY)
    if not shipSnapshot or not shipSnapshot.entities then return false end

    -- Find ship origin from the anchor entity's pos
    local originX, originY = 0, 0
    for _, ent in ipairs(shipSnapshot.entities) do
        if ent.ship then
            originX = ent.pos and ent.pos.x or 0
            originY = ent.pos and ent.pos.y or 0
            break
        end
    end

    -- Spawn ship entities with translated positions
    for _, ent in ipairs(shipSnapshot.entities) do
        local id = ECS.spawn()
        for compName, compData in pairs(ent) do
            if compName == '_savedId' then
                -- skip
            elseif compName == 'pos' then
                ECS.set(id, 'pos', {
                    x = padX + (compData.x - originX),
                    y = padY + (compData.y - originY),
                })
            else
                ECS.set(id, compName, compData)
            end
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Extract ship entities from colony tilemap on launch
---------------------------------------------------------------------------

function ShipManager.extractFromColony(padX, padY, shipW, shipH)
    local snapshot = { entities = {} }

    local toRemove = {}
    for id, comps in ECS.query('pos') do
        local pos = comps.pos
        if pos.x >= padX and pos.x < padX + shipW
           and pos.y >= padY and pos.y < padY + shipH then
            local ent = { _savedId = id }
            for _, c in ipairs(EXTRACT_COMPONENTS) do
                local data = ECS.get(id, c)
                if data then
                    if c == 'pos' then
                        ent.pos = {
                            x = data.x - padX,
                            y = data.y - padY,
                        }
                    else
                        ent[c] = data
                    end
                end
            end
            snapshot.entities[#snapshot.entities + 1] = ent
            toRemove[#toRemove + 1] = id
        end
    end

    for _, id in ipairs(toRemove) do
        ECS.destroy(id)
    end

    return snapshot
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function ShipManager.getShipAnchor()
    local firstShip = ECS.query('ship')
    local id, comps = firstShip()
    return id, comps and comps.ship or nil
end

function ShipManager.getShipModules(shipId)
    local modules = {}
    for id, comps in ECS.query('ship_module') do
        if comps.ship_module.shipId == shipId then
            modules[#modules + 1] = {
                entityId = id,
                systemType = comps.ship_module.systemType,
                operational = comps.ship_module.operational,
                efficiency = comps.ship_module.efficiency,
            }
        end
    end
    return modules
end

return ShipManager
