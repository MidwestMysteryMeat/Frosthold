-- test_beds.lua -- Bed placement and assignment tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Beds')

local Beds = require('src.building.beds')
local ECS  = require('src.ecs.ecs')

T.test('place creates bed entity with pos and bed components', function()
    H.resetAll()
    local id = Beds.place(20, 30)

    T.notnil(id, 'place returns entity ID')
    T.ok(ECS.isAlive(id), 'entity is alive')

    local pos = ECS.get(id, 'pos')
    T.notnil(pos, 'has pos component')
    T.eq(pos.x, 20, 'correct x')
    T.eq(pos.y, 30, 'correct y')

    local bed = ECS.get(id, 'bed')
    T.notnil(bed, 'has bed component')
    T.isnil(bed.owner, 'no owner by default')
    T.eq(bed.quality, 1, 'default quality is 1')
    T.eq(bed.occupied, false, 'not occupied by default')
end)

T.test('assign sets owner on bed', function()
    H.resetAll()
    local bedId = Beds.place(10, 10)
    local colId = H.spawnTestColonist(64, 64, { name = 'Sleeper' })

    local ok = Beds.assign(bedId, colId)
    T.ok(ok, 'assign returns true')

    local bed = ECS.get(bedId, 'bed')
    T.eq(bed.owner, colId, 'owner is the colonist')
end)

T.test('assign returns false for non-bed entity', function()
    H.resetAll()
    local colId = H.spawnTestColonist(64, 64)

    -- colId is a colonist, not a bed
    local ok = Beds.assign(colId, colId)
    T.eq(ok, false, 'assign rejects non-bed entity')
end)

T.test('assign clears previous bed ownership', function()
    H.resetAll()
    local bed1 = Beds.place(5, 5)
    local bed2 = Beds.place(6, 6)
    local colId = H.spawnTestColonist(64, 64, { name = 'Mover' })

    Beds.assign(bed1, colId)
    T.eq(ECS.get(bed1, 'bed').owner, colId, 'colonist owns bed1')

    -- Reassign to bed2 — bed1 should lose ownership
    Beds.assign(bed2, colId)
    T.isnil(ECS.get(bed1, 'bed').owner, 'bed1 owner cleared')
    T.eq(ECS.get(bed2, 'bed').owner, colId, 'colonist now owns bed2')
end)

T.test('unassign clears bed owner', function()
    H.resetAll()
    local bedId = Beds.place(15, 15)
    local colId = H.spawnTestColonist(64, 64)

    Beds.assign(bedId, colId)
    T.eq(ECS.get(bedId, 'bed').owner, colId, 'owner set before unassign')

    Beds.unassign(bedId)
    T.isnil(ECS.get(bedId, 'bed').owner, 'owner nil after unassign')
end)

T.test('findForColonist returns owned bed first', function()
    H.resetAll()
    local bed1 = Beds.place(10, 10)
    local bed2 = Beds.place(20, 20)
    local colId = H.spawnTestColonist(64, 64, { name = 'Owner' })

    -- Assign bed2 to colonist, bed1 is unowned
    Beds.assign(bed2, colId)

    local foundId, foundPos, foundBed = Beds.findForColonist(colId)
    T.eq(foundId, bed2, 'returns owned bed, not unowned')
    T.eq(foundPos.x, 20, 'correct bed position x')
    T.eq(foundPos.y, 20, 'correct bed position y')
end)

T.test('findForColonist falls back to unowned bed', function()
    H.resetAll()
    local bed1 = Beds.place(10, 10)
    local colId = H.spawnTestColonist(64, 64, { name = 'Guest' })
    -- No bed assigned to colId

    local foundId, foundPos, foundBed = Beds.findForColonist(colId)
    T.notnil(foundId, 'found an unowned bed')
    T.isnil(foundBed.owner, 'bed is unowned')
end)

T.test('getAll returns all placed beds', function()
    H.resetAll()
    Beds.place(1, 1)
    Beds.place(2, 2)
    Beds.place(3, 3)

    local all = Beds.getAll()
    T.eq(#all, 3, 'three beds total')

    for _, entry in ipairs(all) do
        T.notnil(entry.id, 'entry has id')
        T.notnil(entry.pos, 'entry has pos')
        T.notnil(entry.bed, 'entry has bed')
    end
end)
