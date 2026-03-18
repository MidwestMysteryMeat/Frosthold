-- work_orders.lua — Bill/work order system for production machines
-- Each machine can have an ordered list of bills. Bills define:
--   - What recipe to produce
--   - How many to produce (count target, "until X in stockpile", or forever)
--   - Material filter (restrict input materials)
--   - Quality minimum (only accept output of this quality or better)
--   - Ingredient search radius
--   - Pause/resume conditions
-- The production system checks the bill queue to decide what to craft next.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local WorkOrders = {}

---------------------------------------------------------------------------
-- Bill modes
---------------------------------------------------------------------------

WorkOrders.MODES = {
    count     = 'Make X',            -- produce exactly N items then stop
    until_x   = 'Until X in stock',  -- produce until colony has N of the output
    forever   = 'Do forever',        -- never stop
}

---------------------------------------------------------------------------
-- Bill data structure
-- Stored on machine component: machine.bills = { bill1, bill2, ... }
-- Bills are processed in order. First non-paused, non-complete bill wins.
---------------------------------------------------------------------------

local nextBillId = 1

function WorkOrders.createBill(recipeId, mode, target)
    local bill = {
        id             = nextBillId,
        recipeId       = recipeId,
        mode           = mode or 'count',     -- 'count', 'until_x', 'forever'
        target         = target or 1,          -- count target or stockpile threshold
        produced       = 0,                    -- items produced so far (for 'count' mode)
        paused         = false,
        suspended      = false,                -- auto-suspended by condition
        materialFilter = nil,                  -- { [materialId] = true } or nil = any
        qualityMin     = nil,                  -- minimum quality tier id (nil = any)
        ingredientRadius = 999,                -- search radius for ingredients (tiles)
        pauseCondition = nil,                  -- 'low_food', 'low_fuel', or nil
    }
    nextBillId = nextBillId + 1
    return bill
end

---------------------------------------------------------------------------
-- Bill management on a machine entity
---------------------------------------------------------------------------

function WorkOrders.addBill(machineId, bill)
    local machine = ECS.get(machineId, 'machine')
    if not machine then return false end
    if not machine.bills then machine.bills = {} end
    machine.bills[#machine.bills + 1] = bill
    return true
end

function WorkOrders.removeBill(machineId, billId)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return false end
    for i, bill in ipairs(machine.bills) do
        if bill.id == billId then
            table.remove(machine.bills, i)
            return true
        end
    end
    return false
end

function WorkOrders.moveBillUp(machineId, billId)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return end
    for i, bill in ipairs(machine.bills) do
        if bill.id == billId and i > 1 then
            machine.bills[i], machine.bills[i - 1] = machine.bills[i - 1], machine.bills[i]
            return
        end
    end
end

function WorkOrders.moveBillDown(machineId, billId)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return end
    for i, bill in ipairs(machine.bills) do
        if bill.id == billId and i < #machine.bills then
            machine.bills[i], machine.bills[i + 1] = machine.bills[i + 1], machine.bills[i]
            return
        end
    end
end

function WorkOrders.togglePause(machineId, billId)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return end
    for _, bill in ipairs(machine.bills) do
        if bill.id == billId then
            bill.paused = not bill.paused
            return
        end
    end
end

function WorkOrders.setBillTarget(machineId, billId, target)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return end
    for _, bill in ipairs(machine.bills) do
        if bill.id == billId then
            bill.target = math.max(1, target)
            return
        end
    end
end

function WorkOrders.setBillMode(machineId, billId, mode)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return end
    for _, bill in ipairs(machine.bills) do
        if bill.id == billId then
            if WorkOrders.MODES[mode] then
                bill.mode = mode
                bill.produced = 0
            end
            return
        end
    end
end

function WorkOrders.setBillMaterialFilter(machineId, billId, materialFilter)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return end
    for _, bill in ipairs(machine.bills) do
        if bill.id == billId then
            bill.materialFilter = materialFilter
            return
        end
    end
end

function WorkOrders.setBillQualityMin(machineId, billId, qualityMin)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return end
    for _, bill in ipairs(machine.bills) do
        if bill.id == billId then
            bill.qualityMin = qualityMin
            return
        end
    end
end

---------------------------------------------------------------------------
-- Get the active bill for a machine (first non-paused, non-complete bill)
---------------------------------------------------------------------------

function WorkOrders.getActiveBill(machineId)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return nil end

    local pOk, Production = pcall(require, 'src.building.production')

    for _, bill in ipairs(machine.bills) do
        if bill.paused then goto nextBill end

        -- Check pause conditions
        if bill.pauseCondition == 'low_food' then
            if (GameState.resources.food or 0) < 10 then
                bill.suspended = true
                goto nextBill
            end
        elseif bill.pauseCondition == 'low_fuel' then
            if (GameState.resources.fuel or 0) < 5 then
                bill.suspended = true
                goto nextBill
            end
        end
        bill.suspended = false

        -- Check completion
        if bill.mode == 'count' then
            if bill.produced >= bill.target then goto nextBill end

        elseif bill.mode == 'until_x' then
            -- Check colony stockpile of the output item
            if pOk then
                local recipe = Production.RECIPES[bill.recipeId]
                if recipe then
                    local allMet = true
                    for outputItem, _ in pairs(recipe.outputs) do
                        local ITEM_TO_RES = Production.ITEM_TO_RES
                        local resKey = ITEM_TO_RES and ITEM_TO_RES[outputItem] or outputItem
                        local current = GameState.resources[resKey] or 0
                        if current < bill.target then
                            allMet = false
                            break
                        end
                    end
                    if allMet then goto nextBill end
                end
            end
        end
        -- 'forever' never completes

        return bill

        ::nextBill::
    end

    return nil
end

---------------------------------------------------------------------------
-- Notify bill that an item was produced (called by production system)
---------------------------------------------------------------------------

function WorkOrders.onItemProduced(machineId, recipeId)
    -- Credit the active bill (first non-paused, non-complete bill matching this recipe)
    local bill = WorkOrders.getActiveBill(machineId)
    if bill and bill.recipeId == recipeId then
        bill.produced = bill.produced + 1
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function WorkOrders.getBills(machineId)
    local machine = ECS.get(machineId, 'machine')
    if not machine then return {} end
    return machine.bills or {}
end

function WorkOrders.getBillCount(machineId)
    local machine = ECS.get(machineId, 'machine')
    if not machine or not machine.bills then return 0 end
    return #machine.bills
end

---------------------------------------------------------------------------
-- Serialization — persist nextBillId counter
---------------------------------------------------------------------------

function WorkOrders.getState()
    return { nextBillId = nextBillId }
end

function WorkOrders.restoreState(saved)
    if not saved then return end
    nextBillId = saved.nextBillId or nextBillId
end

return WorkOrders
