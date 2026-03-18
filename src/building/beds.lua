-- beds.lua — Bed entity system
-- Beds are ECS entities with pos + bed components.
-- Colonists are assigned to beds for sleep recovery.

local ECS = require('src.ecs.ecs')

local Beds = {}

local BED_QUALITY = {
    comfort  = 2,
    hospital = 3,
}

function Beds.place(x, y, depth, bedQuality)
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth or 0 })
    ECS.set(id, 'bed', {
        owner    = nil,   -- assigned colonist entity ID
        quality  = BED_QUALITY[bedQuality] or 1,  -- 1=basic, 2=comfort, 3=hospital
        occupied = false,
        bedType  = bedQuality,  -- nil for basic, 'comfort', 'hospital'
    })
    return id
end

function Beds.assign(bedId, colonistId)
    if not bedId or not ECS.isAlive(bedId) then return false end
    local bed = ECS.get(bedId, 'bed')
    if not bed then return false end

    if bed.owner and bed.owner ~= colonistId then
        local prev = ECS.get(bed.owner, 'colonist')
        if prev and prev._bedId == bedId then
            prev._bedId = nil
        end
    end

    -- Unassign from any previous bed
    Beds.unassignColonist(colonistId)
    bed.owner = colonistId

    local colonist = ECS.get(colonistId, 'colonist')
    if colonist then
        colonist._bedId = bedId
    end
    return true
end

function Beds.unassign(bedId)
    if not bedId or not ECS.isAlive(bedId) then return end
    local bed = ECS.get(bedId, 'bed')
    if not bed then return end

    if bed.owner then
        local colonist = ECS.get(bed.owner, 'colonist')
        if colonist and colonist._bedId == bedId then
            colonist._bedId = nil
        end
    end

    bed.owner = nil
    bed.occupied = false
end

function Beds.unassignColonist(colonistId)
    local colonist = ECS.get(colonistId, 'colonist')
    if colonist then
        colonist._bedId = nil
    end

    for id, comps in ECS.query('bed') do
        if comps.bed.owner == colonistId then
            comps.bed.owner = nil
            comps.bed.occupied = false
        end
    end
end

function Beds.findForColonist(colonistId)
    -- First check owned bed
    for id, comps in ECS.query('pos', 'bed') do
        if comps.bed.owner == colonistId then
            return id, comps.pos, comps.bed
        end
    end
    -- Find an available bed without claiming it until the caller confirms use
    for id, comps in ECS.query('pos', 'bed') do
        if not comps.bed.owner then
            return id, comps.pos, comps.bed
        end
    end
    return nil
end

function Beds.getAll()
    local result = {}
    for id, comps in ECS.query('pos', 'bed') do
        result[#result + 1] = { id = id, pos = comps.pos, bed = comps.bed }
    end
    return result
end

return Beds
