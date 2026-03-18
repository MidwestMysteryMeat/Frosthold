-- clothing.lua — Clothing component and management
-- Manages 5 wearable slots (under, outer, head, hands, feet) on colonists.
-- Each slot holds a worn item table with current durability.
-- Protection stats scale by durability ratio (item degrades = less protection).
-- Multi-slot items (space suit) share one item reference across all listed slots.
--
-- Component 'clothing' structure:
--   { under = item|nil, outer = item|nil, head = item|nil,
--     hands = item|nil, feet  = item|nil }
--
-- Worn item structure:
--   { id, name, cold, heat, pressure, radiation, toxicity,
--     durability, maxDurability, armor, speedMod, workMod,
--     material, quality, [multiSlot], [o2MaxTank], [o2DrainRate] }

local ECS          = require('src.ecs.ecs')
local ClothingDefs = require('src.colonist.clothing_defs')

local Clothing = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local SLOTS = { 'under', 'outer', 'head', 'hands', 'feet' }

-- Passive wear: durability points lost per real second of sim time.
-- Game runs at 20 Hz; 1 game-hour ~= 180 real seconds at normal speed.
-- 0.1 / 3600 game-hours expressed in sim dt (real seconds at normal speed).
-- We treat dt as real seconds and degrade accordingly.
local DEGRADE_RATE_BASE   = 0.1 / 180   -- ~0.1 dur/game-hour
local DEGRADE_RATE_WORK   = 2 * DEGRADE_RATE_BASE

-- Durability thresholds for notifications (fraction of maxDurability)
local WARN_THRESHOLD     = 0.25
local CRITICAL_THRESHOLD = 0.10

---------------------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------------------

local function sendAlert(title, body, priority)
    local ok, Alerts = pcall(require, 'src.ui.alerts')
    if ok and Alerts.send then
        Alerts.send(title, body, priority or 'minor')
    end
end

--- Build a worn item table from a ClothingDefs entry and quality id.
--- Quality multiplies maxDurability via Quality.get(qualityId).durMult.
local function buildWornItem(clothingId, def, qualityId)
    local durMult = 1.0
    local ok, Quality = pcall(require, 'src.world.quality')
    if ok and Quality.get then
        local tier = Quality.get(qualityId or 'normal')
        durMult = tier and tier.durMult or 1.0
    end

    local maxDur = math.floor(def.maxDurability * durMult)
    local item = {
        id           = clothingId,
        name         = def.name,
        cold         = def.cold,
        heat         = def.heat,
        pressure     = def.pressure,
        radiation    = def.radiation,
        toxicity     = def.toxicity,
        durability   = maxDur,
        maxDurability = maxDur,
        armor        = def.armor,
        speedMod     = def.speedMod,
        workMod      = def.workMod,
        material     = def.material,
        quality      = qualityId or 'normal',
    }
    -- Preserve optional fields from the def
    if def.multiSlot  then item.multiSlot  = def.multiSlot  end
    if def.o2MaxTank  then item.o2MaxTank  = def.o2MaxTank  end
    if def.o2DrainRate then item.o2DrainRate = def.o2DrainRate end
    if def.carryMod   then item.carryMod   = def.carryMod   end
    if def.damageMod  then item.damageMod  = def.damageMod  end
    return item
end

--- Destroy an item in a slot and clear all affected slots.
--- Fires a notification when it happens.
local function destroyItem(entityId, clothing, slot)
    local item = clothing[slot]
    if not item then return end

    local itemName = item.name or slot
    local col = ECS.get(entityId, 'colonist')
    local colonistName = col and col.name or 'Colonist'

    if item.multiSlot then
        for _, s in ipairs(item.multiSlot) do
            clothing[s] = nil
        end
    else
        clothing[slot] = nil
    end

    sendAlert(
        itemName .. ' destroyed',
        colonistName .. "'s " .. itemName .. ' has worn out completely.',
        'minor'
    )
end

--- Check whether a worn item has crossed a warning threshold.
--- Fires at most once per threshold (tracked via flags on the item table).
local function checkWearWarnings(entityId, item, slot)
    if not item then return end
    local ratio = item.durability / item.maxDurability

    local col = ECS.get(entityId, 'colonist')
    local colonistName = col and col.name or 'Colonist'

    if not item._warnedCritical and ratio <= CRITICAL_THRESHOLD then
        item._warnedCritical = true
        sendAlert(
            item.name .. ' critical',
            colonistName .. "'s " .. item.name .. ' is nearly destroyed (' ..
            math.floor(ratio * 100) .. '% remaining).',
            'minor'
        )
    elseif not item._warnedLow and ratio <= WARN_THRESHOLD then
        item._warnedLow = true
        sendAlert(
            item.name .. ' worn',
            colonistName .. "'s " .. item.name .. ' is wearing thin (' ..
            math.floor(ratio * 100) .. '% remaining).',
            'info'
        )
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Attach an empty clothing component to an entity.
function Clothing.attach(entityId)
    if not ECS.isAlive(entityId) then return end
    ECS.set(entityId, 'clothing', {
        under = nil,
        outer = nil,
        head  = nil,
        hands = nil,
        feet  = nil,
    })
end

--- Equip a clothing item on an entity.
--- @param entityId  number   ECS entity id
--- @param clothingId string  Key in ClothingDefs.ITEMS
--- @param quality   string   Quality tier id (default 'normal')
--- @return boolean  true on success, false if slot occupied or item unknown
function Clothing.equip(entityId, clothingId, quality)
    if not ECS.isAlive(entityId) then return false end
    local clothing = ECS.get(entityId, 'clothing')
    if not clothing then return false end

    local def = ClothingDefs.get(clothingId)
    if not def then return false end

    if def.multiSlot then
        -- All slots in the multiSlot list must be empty
        for _, s in ipairs(def.multiSlot) do
            if clothing[s] ~= nil then return false end
        end
        local item = buildWornItem(clothingId, def, quality)
        for _, s in ipairs(def.multiSlot) do
            clothing[s] = item
        end
    else
        local slot = def.slot
        if clothing[slot] ~= nil then return false end
        clothing[slot] = buildWornItem(clothingId, def, quality)
    end

    return true
end

--- Unequip clothing from a slot.
--- If the item occupies multiple slots (space suit), all are cleared.
--- @param entityId  number
--- @param slot      string  One of: under, outer, head, hands, feet
--- @return table|nil  The worn item data that was removed, or nil
function Clothing.unequip(entityId, slot)
    if not ECS.isAlive(entityId) then return nil end
    local clothing = ECS.get(entityId, 'clothing')
    if not clothing then return nil end

    local item = clothing[slot]
    if not item then return nil end

    if item.multiSlot then
        for _, s in ipairs(item.multiSlot) do
            clothing[s] = nil
        end
    else
        clothing[slot] = nil
    end

    return item
end

--- Sum protection across all worn items, scaled by durability ratio.
--- @param entityId number
--- @return table { cold, heat, pressure, radiation, toxicity, armor, speedMod, workMod }
function Clothing.getProtection(entityId)
    local prot = { cold = 0, heat = 0, pressure = 0, radiation = 0,
                   toxicity = 0, armor = 0, speedMod = 0, workMod = 0 }

    local clothing = ECS.get(entityId, 'clothing')
    if not clothing then return prot end

    -- Track already-counted items so multiSlot items aren't double-counted.
    local counted = {}
    for _, slot in ipairs(SLOTS) do
        local item = clothing[slot]
        if item and not counted[item] then
            counted[item] = true
            local ratio = item.durability / item.maxDurability
            prot.cold     = prot.cold     + item.cold     * ratio
            prot.heat     = prot.heat     + item.heat     * ratio
            prot.pressure = prot.pressure + item.pressure * ratio
            prot.radiation = prot.radiation + item.radiation * ratio
            prot.toxicity = prot.toxicity + item.toxicity * ratio
            prot.armor    = prot.armor    + item.armor    * ratio
            prot.speedMod = prot.speedMod + item.speedMod * ratio
            prot.workMod  = prot.workMod  + item.workMod  * ratio
        end
    end

    return prot
end

--- Return the raw clothing component table, or nil.
function Clothing.getComponent(entityId)
    return ECS.get(entityId, 'clothing')
end

--- Passive wear degradation called each sim tick.
--- isWorking: boolean — degrades at 2x rate when colonist is working.
function Clothing.degradeWear(entityId, dt, isWorking)
    local clothing = ECS.get(entityId, 'clothing')
    if not clothing then return end

    local rate = isWorking and DEGRADE_RATE_WORK or DEGRADE_RATE_BASE
    local counted = {}

    for _, slot in ipairs(SLOTS) do
        local item = clothing[slot]
        if item and not counted[item] then
            counted[item] = true

            item.durability = item.durability - rate * dt
            if item.durability <= 0 then
                item.durability = 0
                destroyItem(entityId, clothing, slot)
            else
                checkWearWarnings(entityId, item, slot)
            end
        end
    end
end

--- Combat hit reduces durability of a specific slot's item.
--- damage is the raw hit value; actual durability loss is 5-15 scaled by damage.
function Clothing.degradeCombat(entityId, slot, damage)
    local clothing = ECS.get(entityId, 'clothing')
    if not clothing then return end
    local item = clothing[slot]
    if not item then return end

    local loss = 5 + math.min(10, damage or 0)
    item.durability = math.max(0, item.durability - loss)

    if item.durability <= 0 then
        destroyItem(entityId, clothing, slot)
    else
        checkWearWarnings(entityId, item, slot)
    end
end

--- Repair an item in a slot up to its maxDurability.
--- crafterSkill (1-20) determines efficiency (future hook; currently full repair).
--- @param entityId    number
--- @param slot        string
--- @param crafterSkill number  Crafter skill level (unused, reserved)
--- @return number  Amount of durability restored
function Clothing.repair(entityId, slot, crafterSkill)
    local clothing = ECS.get(entityId, 'clothing')
    if not clothing then return 0 end
    local item = clothing[slot]
    if not item then return 0 end

    local restored = item.maxDurability - item.durability
    if restored <= 0 then return 0 end

    item.durability    = item.maxDurability
    item._warnedLow    = nil
    item._warnedCritical = nil
    return restored
end

---------------------------------------------------------------------------
-- ECS system registration
---------------------------------------------------------------------------

local function clothingDegradeSystem(dt, id, comps)
    local col = comps.colonist
    if col.state == 'dead' or col.state == 'away_expedition' then return end

    local isWorking = col.state ~= 'idle' and col.state ~= 'sleep'
    Clothing.degradeWear(id, dt, isWorking)

    -- O2 consumption for suits with o2MaxTank (space suit, diving suit)
    local clothing = comps.clothing
    if not clothing then return end
    -- Check outer slot (multiSlot suits live here)
    local outer = clothing.outer
    if not outer or not outer.o2MaxTank then return end
    if not outer._o2Remaining then
        outer._o2Remaining = outer.o2MaxTank  -- initialize on first tick
    end

    -- Determine if colonist needs O2 from suit
    local needsO2 = false
    local pos = ECS.get(id, 'pos')
    if pos then
        local depth = pos.depth or 0
        -- Check pressure (underwater on Nerthus-9)
        local pok, PressureMod = pcall(require, 'src.sim.pressure')
        if pok and PressureMod.getEffectivePressure then
            if PressureMod.getEffectivePressure(pos.x, pos.y, depth) > 0 then
                needsO2 = true
            end
        end
        -- Check vacuum (Nemaea: ambient O2 < 50, outdoors)
        if not needsO2 then
            local wok, World = pcall(require, 'src.world.tilemap')
            if wok and World.getRoom then
                local roomId = World.getRoom(pos.x, pos.y, depth)
                if not roomId or roomId == 0 then
                    local pok2, Planet = pcall(require, 'src.world.planet')
                    if pok2 and Planet.get then
                        local ambientO2 = Planet.get('atmosphere.ambientO2', 100)
                        if ambientO2 < 50 then needsO2 = true end
                    end
                end
            end
        end
    end

    if needsO2 then
        local drainRate = outer.o2DrainRate or outer._o2DrainRate or 1.0
        outer._o2Remaining = outer._o2Remaining - drainRate * dt
        if outer._o2Remaining <= 0 then
            outer._o2Remaining = 0
            -- Suffocating: drain health
            col.health = (col.health or col.maxHealth or 100) - 0.5 * dt
            if col.health <= 0 then
                col.state = 'dead'
                col.causeOfDeath = 'suffocation'
            end
        end
    else
        -- Not in hazardous environment — slowly recover O2 if near full
        -- (actual refill happens at O2 stations / airlocks)
    end
end

--- Get O2 remaining (seconds). Returns nil if no O2 suit worn.
function Clothing.getO2Remaining(entityId)
    local clothing = ECS.get(entityId, 'clothing')
    if not clothing or not clothing.outer then return nil end
    local outer = clothing.outer
    if not outer.o2MaxTank then return nil end
    return outer._o2Remaining or outer.o2MaxTank
end

--- Get O2 fraction (0-1). Returns nil if no O2 suit worn.
function Clothing.getO2Fraction(entityId)
    local clothing = ECS.get(entityId, 'clothing')
    if not clothing or not clothing.outer then return nil end
    local outer = clothing.outer
    if not outer.o2MaxTank then return nil end
    return (outer._o2Remaining or outer.o2MaxTank) / outer.o2MaxTank
end

--- Refill O2 tank to full. Called at airlocks / O2 stations.
function Clothing.refillO2(entityId)
    local clothing = ECS.get(entityId, 'clothing')
    if not clothing or not clothing.outer then return false end
    local outer = clothing.outer
    if not outer.o2MaxTank then return false end
    outer._o2Remaining = outer.o2MaxTank
    return true
end

--- Register the clothing degradation ECS system.
--- Called on module load AND re-called by save.lua after ECS.init() clears systems.
function Clothing.registerSystems()
    ECS.addSystem('clothing_degrade', { 'colonist', 'clothing' }, clothingDegradeSystem, 12)
end

Clothing.registerSystems()

return Clothing
