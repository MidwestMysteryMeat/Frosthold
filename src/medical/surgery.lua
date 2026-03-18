-- surgery.lua — Elective surgery system
-- Operations: install prosthetics/bionics, harvest organs, amputate.
-- Surgery table is a machine. Doctor operates on patient (colonist/prisoner/legacy slave entity).
-- Risk scales inversely with medical skill. Failure can wound or kill.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local _StorageNet
local function getStorageNet()
    if _StorageNet == nil then
        local ok, mod = pcall(require, 'src.logistics.storage_network')
        _StorageNet = ok and mod or false
    end
    return _StorageNet or nil
end

local Surgery = {}

---------------------------------------------------------------------------
-- Prosthetic / bionic stat effects
---------------------------------------------------------------------------

local IMPLANT_STATS = {
    peg_leg          = { slot = 'leg',  moveMult = 0.70, label = 'Peg Leg' },
    wooden_arm       = { slot = 'arm',  workMult = 0.70, label = 'Wooden Arm' },
    prosthetic_leg   = { slot = 'leg',  moveMult = 0.85, label = 'Prosthetic Leg' },
    prosthetic_arm   = { slot = 'arm',  workMult = 0.85, label = 'Prosthetic Arm' },
    bionic_leg       = { slot = 'leg',  moveMult = 1.15, label = 'Bionic Leg' },
    bionic_arm       = { slot = 'arm',  workMult = 1.15, label = 'Bionic Arm' },
    bionic_eye       = { slot = 'eye',  accuracyBonus = 0.15, label = 'Bionic Eye' },
}

Surgery.IMPLANT_STATS = IMPLANT_STATS

---------------------------------------------------------------------------
-- Organ definitions (harvestable from living subjects)
---------------------------------------------------------------------------

local ORGANS = {
    { id = 'organ_heart',  part = 'torso', vital = true,  label = 'Heart' },
    { id = 'organ_lung',   part = 'torso', vital = false, label = 'Lung' },
    { id = 'organ_kidney', part = 'torso', vital = false, label = 'Kidney' },
    { id = 'organ_liver',  part = 'torso', vital = false, label = 'Liver' },
    { id = 'organ_eye',    part = 'head',  vital = false, label = 'Eye' },
}

Surgery.ORGANS = ORGANS

---------------------------------------------------------------------------
-- Operation definitions
---------------------------------------------------------------------------

local OPERATIONS = {
    -- Install prosthetics / bionics
    install_peg_leg        = { type = 'install', item = 'peg_leg',        targetPart = nil, duration = 20, minSkill = 3,  label = 'Install Peg Leg' },
    install_wooden_arm     = { type = 'install', item = 'wooden_arm',     targetPart = nil, duration = 20, minSkill = 3,  label = 'Install Wooden Arm' },
    install_prosthetic_leg = { type = 'install', item = 'prosthetic_leg', targetPart = nil, duration = 30, minSkill = 5,  label = 'Install Prosthetic Leg' },
    install_prosthetic_arm = { type = 'install', item = 'prosthetic_arm', targetPart = nil, duration = 30, minSkill = 5,  label = 'Install Prosthetic Arm' },
    install_bionic_leg     = { type = 'install', item = 'bionic_leg',     targetPart = nil, duration = 45, minSkill = 8,  label = 'Install Bionic Leg' },
    install_bionic_arm     = { type = 'install', item = 'bionic_arm',     targetPart = nil, duration = 45, minSkill = 8,  label = 'Install Bionic Arm' },
    install_bionic_eye     = { type = 'install', item = 'bionic_eye',     targetPart = nil, duration = 50, minSkill = 10, label = 'Install Bionic Eye' },

    -- Organ harvesting
    harvest_heart  = { type = 'harvest', organ = 'organ_heart',  vital = true,  duration = 40, minSkill = 8,  label = 'Harvest Heart' },
    harvest_lung   = { type = 'harvest', organ = 'organ_lung',   vital = false, duration = 30, minSkill = 6,  label = 'Harvest Lung' },
    harvest_kidney = { type = 'harvest', organ = 'organ_kidney', vital = false, duration = 25, minSkill = 5,  label = 'Harvest Kidney' },
    harvest_liver  = { type = 'harvest', organ = 'organ_liver',  vital = false, duration = 30, minSkill = 6,  label = 'Harvest Liver' },
    harvest_eye    = { type = 'harvest', organ = 'organ_eye',    vital = false, duration = 20, minSkill = 4,  label = 'Harvest Eye' },

    -- Amputation
    amputate_arm   = { type = 'amputate', targetPart = nil, duration = 15, minSkill = 3, label = 'Amputate Arm' },
    amputate_leg   = { type = 'amputate', targetPart = nil, duration = 15, minSkill = 3, label = 'Amputate Leg' },
}

Surgery.OPERATIONS = OPERATIONS

---------------------------------------------------------------------------
-- Surgery queue on surgery_table machines
-- Each surgery_table has a 'surgery_queue' component:
-- { queue = { { opId, patientId, doctorId, progress } }, ... }
---------------------------------------------------------------------------

function Surgery.queueOperation(tableEntityId, opId, patientId, targetPart)
    local machine = ECS.get(tableEntityId, 'machine')
    if not machine or machine.type ~= 'surgery_table' then
        return false, 'Not a surgery table'
    end

    local op = OPERATIONS[opId]
    if not op then return false, 'Unknown operation' end

    -- Check item availability for installs
    if op.type == 'install' then
        if not GameState.resources[op.item] or GameState.resources[op.item] < 1 then
            return false, 'Missing item: ' .. op.item
        end
    end

    if not machine._surgeryQueue then
        machine._surgeryQueue = {}
    end

    machine._surgeryQueue[#machine._surgeryQueue + 1] = {
        opId      = opId,
        patientId = patientId,
        targetPart = targetPart,
        progress  = 0,
    }

    return true
end

---------------------------------------------------------------------------
-- Failure risk: base 15%, reduced by medical skill
-- At skill 1: 15% fail. At skill 10: 3%. At skill 20: 0.5%.
---------------------------------------------------------------------------

local function failureChance(skillLevel)
    return math.max(0.005, 0.15 - (skillLevel - 1) * 0.013)
end

---------------------------------------------------------------------------
-- Execute a completed surgery
---------------------------------------------------------------------------

local function completeSurgery(entry, doctorId, doctorSkill)
    local op = OPERATIONS[entry.opId]
    if not op then return end

    local patientId = entry.patientId
    if not ECS.isAlive(patientId) then return end

    -- Roll for failure
    local chance = failureChance(doctorSkill)
    -- Surgeon mastery: halve failure chance
    local skOk, Skills = pcall(require, 'src.colonist.skills')
    if skOk and Skills.hasMastery(doctorId, 'surgeon') then
        chance = chance * 0.5
    end

    local failed = math.random() < chance

    if failed then
        -- Surgery failed: wound the patient
        local bok, Body = pcall(require, 'src.combat.body')
        if bok then
            local part = entry.targetPart or 'torso'
            Body.damagePart(patientId, part, 15)
        end
        local wok, Wounds = pcall(require, 'src.combat.wounds')
        if wok then
            Wounds.apply(patientId, entry.targetPart or 'torso', 'cut', 0.4)
        end
        return
    end

    -- Surgery succeeded
    if op.type == 'install' then
        -- Consume item
        if GameState.resources[op.item] ~= nil then
            local tPos = ECS.get(entry.tableId, 'pos')
            local tx = tPos and tPos.x or GameState.startX
            local ty = tPos and tPos.y or GameState.startY
            local SNet = getStorageNet()
            if SNet then SNet.withdraw(op.item, 1, tx, ty)
            else GameState.spendResource(op.item, 1) end
        end

        -- Restore the destroyed part first
        local bok, Body = pcall(require, 'src.combat.body')
        if bok then
            local body = ECS.get(patientId, 'body')
            if body then
                local partName = entry.targetPart
                local part = partName and body.parts[partName]
                if part and part.status == 'destroyed' then
                    part.hp = part.maxHp
                    part.status = 'healthy'
                end
            end
        end

        -- Record implant on colonist/prisoner
        local col = ECS.get(patientId, 'colonist')
        local prisoner = ECS.get(patientId, 'prisoner')
        local slave = ECS.get(patientId, 'slave')
        local target = col or prisoner or slave
        if target then
            if not target.implants then target.implants = {} end
            target.implants[#target.implants + 1] = {
                item = op.item,
                part = entry.targetPart,
                stats = IMPLANT_STATS[op.item],
            }
        end

    elseif op.type == 'harvest' then
        -- Produce the organ item
        if GameState.resources[op.organ] ~= nil then
            GameState.resources[op.organ] = GameState.resources[op.organ] + 1
        end

        -- Harvesting a vital organ kills the patient
        if op.vital then
            local cOk, ColMod = pcall(require, 'src.colonist.colonist')
            if cOk then ColMod.kill(patientId) end
        else
            -- Non-vital: wound the patient, destroy the part
            local bok, Body = pcall(require, 'src.combat.body')
            if bok then
                local organDef = nil
                for _, o in ipairs(ORGANS) do
                    if o.id == op.organ then organDef = o; break end
                end
                if organDef then
                    Body.damagePart(patientId, organDef.part, 999)
                end
            end
        end

        -- Massive morale and hope penalty for organ harvesting
        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then
            Hope.onDarkAction('organ_harvest')
        end
        -- Morale hit to all colonists who witness (colony-wide for simplicity)
        for cid, comps in ECS.query('colonist', 'needs') do
            if cid ~= patientId then
                comps.needs.morale = math.max(0, comps.needs.morale - 20)
            end
        end

    elseif op.type == 'amputate' then
        local bok, Body = pcall(require, 'src.combat.body')
        if bok and entry.targetPart then
            Body.damagePart(patientId, entry.targetPart, 999)
        end
    end

    -- Award medical XP
    if skOk then
        Skills.addXp(doctorId, 'medical', 30)
    end
end

---------------------------------------------------------------------------
-- ECS system: process surgery queues on surgery_table machines
---------------------------------------------------------------------------

local function surgerySystem(dt, id, comps)
    local machine = comps.machine
    if machine.type ~= 'surgery_table' then return end

    local queue = machine._surgeryQueue
    if not queue or #queue == 0 then return end

    -- Need an assigned doctor
    local doctorId = machine.assignee
    if not doctorId or not ECS.isAlive(doctorId) then return end

    local col = ECS.get(doctorId, 'colonist')
    if not col then return end
    local doctorSkill = col.skills and col.skills.medical or 1

    -- Process first entry in queue
    local entry = queue[1]
    if not ECS.isAlive(entry.patientId) then
        table.remove(queue, 1)
        return
    end

    local op = OPERATIONS[entry.opId]
    if not op then
        table.remove(queue, 1)
        return
    end

    -- Check doctor meets minimum skill — release so a qualified doctor can claim
    if doctorSkill < op.minSkill then
        machine.assignee = nil
        return
    end

    local speedMult = 1.0 + (doctorSkill - 1) * 0.1
    entry.progress = entry.progress + dt * speedMult

    if entry.progress >= op.duration then
        completeSurgery(entry, doctorId, doctorSkill)
        table.remove(queue, 1)
    end
end

---------------------------------------------------------------------------
-- Query: get implant stat modifiers for an entity
---------------------------------------------------------------------------

function Surgery.getMoveMultiplier(entityId)
    local col = ECS.get(entityId, 'colonist') or ECS.get(entityId, 'slave')
    if not col or not col.implants then return 1.0 end
    local mult = 1.0
    for _, imp in ipairs(col.implants) do
        if imp.stats and imp.stats.moveMult then
            mult = mult * imp.stats.moveMult
        end
    end
    return mult
end

function Surgery.getWorkMultiplier(entityId)
    local col = ECS.get(entityId, 'colonist') or ECS.get(entityId, 'slave')
    if not col or not col.implants then return 1.0 end
    local mult = 1.0
    for _, imp in ipairs(col.implants) do
        if imp.stats and imp.stats.workMult then
            mult = mult * imp.stats.workMult
        end
    end
    return mult
end

function Surgery.getAccuracyBonus(entityId)
    local col = ECS.get(entityId, 'colonist') or ECS.get(entityId, 'slave')
    if not col or not col.implants then return 0 end
    local bonus = 0
    for _, imp in ipairs(col.implants) do
        if imp.stats and imp.stats.accuracyBonus then
            bonus = bonus + imp.stats.accuracyBonus
        end
    end
    return bonus
end

function Surgery.getImplants(entityId)
    local col = ECS.get(entityId, 'colonist') or ECS.get(entityId, 'slave')
    if not col or not col.implants then return {} end
    return col.implants
end

function Surgery.getQueueLength(tableEntityId)
    local machine = ECS.get(tableEntityId, 'machine')
    if not machine or not machine._surgeryQueue then return 0 end
    return #machine._surgeryQueue
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Surgery.registerSystems()
    ECS.addSystem('surgery', { 'machine' }, surgerySystem, 17)
end

Surgery.registerSystems()

return Surgery
