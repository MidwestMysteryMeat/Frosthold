-- ecs.lua — Entity Component System
-- Sparse-set ECS: entities are integer IDs, components are plain tables
-- stored in per-component-type arrays keyed by entity ID.

local ECS = {}

local unpack = unpack or rawget(table, 'unpack') -- Lua 5.1/LuaJIT vs 5.2+

local nextId     = 1
local entities   = {}       -- set of alive entity IDs: entities[id] = true
local components = {}       -- components[compName][entityId] = data
local componentCounts = {}  -- live component counts by compName
local systems    = {}       -- ordered list of { name, filter, fn }
local toDestroy  = {}       -- deferred destruction queue

local function emptyIterator()
    return nil
end

---------------------------------------------------------------------------
-- Entity lifecycle
---------------------------------------------------------------------------

function ECS.init()
    nextId     = 1
    entities   = {}
    components = {}
    componentCounts = {}
    systems    = {}
    toDestroy  = {}
end

function ECS.spawn()
    local id = nextId
    nextId = nextId + 1
    entities[id] = true
    return id
end

function ECS.destroy(id)
    toDestroy[#toDestroy + 1] = id
end

function ECS.isAlive(id)
    return entities[id] == true
end

---------------------------------------------------------------------------
-- Component access
---------------------------------------------------------------------------

function ECS.set(id, compName, data)
    if not components[compName] then
        components[compName] = {}
        componentCounts[compName] = 0
    end
    if components[compName][id] == nil then
        componentCounts[compName] = (componentCounts[compName] or 0) + 1
    end
    components[compName][id] = data or true
end

function ECS.get(id, compName)
    local store = components[compName]
    return store and store[id]
end

function ECS.remove(id, compName)
    local store = components[compName]
    if store and store[id] ~= nil then
        store[id] = nil
        componentCounts[compName] = math.max(0, (componentCounts[compName] or 0) - 1)
    end
end

function ECS.has(id, compName)
    local store = components[compName]
    return (store and store[id] ~= nil) or false
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

-- Iterate all entities that have ALL listed component names.
-- Returns iterator: for id, comps in ECS.query('pos', 'colonist') do ...
function ECS.query(...)
    local names = { ... }
    if #names == 0 then return emptyIterator, nil, nil end

    -- Use smallest component pool as driver
    local smallest, smallestName
    for _, name in ipairs(names) do
        local pool = components[name]
        if not pool then return emptyIterator, nil, nil end
        local count = componentCounts[name] or 0
        if count == 0 then return emptyIterator, nil, nil end
        if not smallest or count < smallest then
            smallest = count
            smallestName = name
        end
    end

    if not smallestName then return emptyIterator, nil, nil end

    local ids = {}
    for id in pairs(components[smallestName]) do
        ids[#ids + 1] = id
    end

    local index = 0
    local function iter()
        while true do
            index = index + 1
            local id = ids[index]
            if id == nil then return nil end

            if entities[id] then
                local comps = {}
                local match = true
                for _, name in ipairs(names) do
                    local c = components[name] and components[name][id]
                    if not c then
                        match = false
                        break
                    end
                    comps[name] = c
                end
                if match then
                    return id, comps
                end
            end
        end
    end
    return iter, nil, nil
end

-- Count entities with a specific component
function ECS.countWith(compName)
    return componentCounts[compName] or 0
end

-- Get all {entityId -> component} pairs for a component
function ECS.getAll(compName)
    local result = {}
    local store = components[compName]
    if not store then return result end
    for id, comp in pairs(store) do
        if entities[id] then result[id] = comp end
    end
    return result
end

-- Get all entity IDs with a component
function ECS.allWith(compName)
    local result = {}
    local store = components[compName]
    if not store then return result end
    for id in pairs(store) do
        if entities[id] then result[#result + 1] = id end
    end
    return result
end

---------------------------------------------------------------------------
-- Systems
---------------------------------------------------------------------------

-- Register a system. filter is a list of component names.
-- fn(dt, id, comps) called for each matching entity.
function ECS.addSystem(name, filter, fn, priority)
    systems[#systems + 1] = {
        name     = name,
        filter   = filter,
        fn       = fn,
        priority = priority or 0,
    }
    table.sort(systems, function(a, b) return a.priority < b.priority end)
end

function ECS.update(dt)
    -- Run systems
    for _, sys in ipairs(systems) do
        for id, comps in ECS.query(unpack(sys.filter)) do
            sys.fn(dt, id, comps)
        end
    end

    -- Flush deferred destroys
    for i = 1, #toDestroy do
        local id = toDestroy[i]
        entities[id] = nil
        for compName, store in pairs(components) do
            if store[id] ~= nil then
                store[id] = nil
                componentCounts[compName] = math.max(0, (componentCounts[compName] or 0) - 1)
            end
        end
    end
    if #toDestroy > 0 then
        toDestroy = {}
    end
end

return ECS
