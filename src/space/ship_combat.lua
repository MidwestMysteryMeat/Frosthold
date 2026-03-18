-- ship_combat.lua — FTL-style ship-to-ship combat
-- Each weapon mount independently targets an enemy ship system.
-- Damage: accuracy roll -> shields absorb -> hull damage -> system damage.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local ShipCombat = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local BASE_ACCURACY   = 0.6
local SKILL_BONUS     = 0.03  -- per combat skill level
local DISTANCE_PENALTY = 0.02 -- per tile distance
local SHIELD_ABSORB   = 0.8   -- shields absorb 80% of damage
local BASE_DAMAGE     = 15
local CRITICAL_CHANCE = 0.05
local CRITICAL_MULT   = 3.0
local FIRE_COOLDOWN   = 3.0   -- seconds between shots

---------------------------------------------------------------------------
-- Weapon type stats (override defaults when weapon has a type)
---------------------------------------------------------------------------

local WEAPON_STATS = {
    railgun       = { damage = 45, range = 30, fireRate = 8.0, accuracy = 0.7,  penetration = 0.9 },
    laser         = { damage = 12, range = 20, fireRate = 1.5, accuracy = 0.85, penetration = 0.3 },
    missile       = { damage = 35, range = 25, fireRate = 5.0, accuracy = 0.75, ammo = 12 },
    heavy_warhead = { damage = 60, range = 20, fireRate = 10.0, accuracy = 0.6, ammo = 6, areaDamage = 20 },
    emp_missile   = { damage = 5,  range = 22, fireRate = 6.0, accuracy = 0.7,  ammo = 8, empDuration = 15 },
    emp_mine      = { damage = 3,  range = 5,  fireRate = 10.0, ammo = 6, empDuration = 20, deployable = true },
    nano_dump     = { damage = 8,  range = 12, fireRate = 8.0, accuracy = 0.9,  ammo = 4, ignoresShields = true, systemDamageMult = 3.0 },
    point_defense = { damage = 5,  range = 8,  fireRate = 0.5, accuracy = 0.9,  interceptor = true },
}

local function getWeaponStats(wm)
    local wtype = wm.weaponType
    if wtype and WEAPON_STATS[wtype] then
        return WEAPON_STATS[wtype], wtype
    end
    return nil, nil
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local combatActive = false
local engagedPairs = {}  -- { [attackerId] = targetId }

---------------------------------------------------------------------------
-- Engage / disengage
---------------------------------------------------------------------------

function ShipCombat.engage(attackerId, targetId)
    engagedPairs[attackerId] = targetId
    combatActive = true
end

function ShipCombat.disengage(attackerId)
    engagedPairs[attackerId] = nil
    combatActive = next(engagedPairs) ~= nil
end

function ShipCombat.isInCombat()
    return combatActive
end

---------------------------------------------------------------------------
-- Assign weapon target (FTL-style: per-weapon targeting)
---------------------------------------------------------------------------

function ShipCombat.assignWeaponTarget(weaponEntityId, targetSystemType, targetShipId)
    local wm = ECS.get(weaponEntityId, 'weapon_mount')
    if not wm then return false end
    wm.targetSystemType = targetSystemType
    wm.targetEntityId = targetShipId
    return true
end

---------------------------------------------------------------------------
-- Find ship modules by type on a target ship
---------------------------------------------------------------------------

local function findModuleOnShip(shipEntityId, systemType)
    local shipComp = ECS.get(shipEntityId, 'ship')
    if not shipComp then return nil end
    local targetShipId = shipComp.shipId

    for modId, comps in ECS.query('ship_module', 'pos') do
        local mod = comps.ship_module
        if mod.shipId == targetShipId and mod.systemType == systemType then
            return modId, mod
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Get shield strength of a ship (0-1, 0 = no shields/depleted)
---------------------------------------------------------------------------

local function getShieldStrength(shipEntityId)
    local shipComp = ECS.get(shipEntityId, 'ship')
    if not shipComp then return 0 end

    for modId, comps in ECS.query('ship_module') do
        local mod = comps.ship_module
        if mod.shipId == shipComp.shipId and mod.systemType == 'shield_generator' then
            if mod.operational then
                return mod.efficiency or 1.0
            end
        end
    end
    return 0
end

---------------------------------------------------------------------------
-- Fire weapons (called per tick)
---------------------------------------------------------------------------

function ShipCombat.fireWeapons(dt)
    if GameState.activeMap ~= 'space' then return end

    for weaponId, comps in ECS.query('weapon_mount', 'pos') do
        local wm = comps.weapon_mount
        if not wm.targetEntityId or not wm.targetSystemType then goto continue end
        if not ECS.isAlive(wm.targetEntityId) then
            wm.targetEntityId = nil
            goto continue
        end

        -- Get weapon-type-specific stats
        local wStats, wType = getWeaponStats(wm)
        local wDamage   = wStats and wStats.damage or BASE_DAMAGE
        local wRange    = wStats and wStats.range or 999
        local wFireRate = wStats and wStats.fireRate or FIRE_COOLDOWN
        local wAccuracy = wStats and wStats.accuracy or BASE_ACCURACY

        -- Ammo check (missiles, mines, warheads, nano dumps)
        if wStats and wStats.ammo then
            wm._ammo = wm._ammo or wStats.ammo
            if wm._ammo <= 0 then goto continue end
        end

        -- Cooldown
        wm._cooldown = (wm._cooldown or 0) - dt
        if wm._cooldown > 0 then goto continue end
        wm._cooldown = wFireRate

        -- Calculate accuracy
        local weaponPos = comps.pos
        local targetPos = ECS.get(wm.targetEntityId, 'pos')
        if not targetPos then goto continue end

        local dx = targetPos.x - weaponPos.x
        local dy = targetPos.y - weaponPos.y
        local dist = math.sqrt(dx * dx + dy * dy)

        -- Range check
        if dist > wRange then goto continue end

        local accuracy = wAccuracy - (dist * DISTANCE_PENALTY)

        -- Gunner skill bonus
        local gunnerSkill = 0
        for cid, ccomps in ECS.query('ship_crew') do
            if ccomps.ship_crew.role == 'gunner' then
                local col = ECS.get(cid, 'colonist')
                if col and col.skills and col.skills.combat then
                    gunnerSkill = col.skills.combat
                end
                break
            end
        end
        accuracy = accuracy + (gunnerSkill * SKILL_BONUS)
        accuracy = math.max(0.1, math.min(0.95, accuracy))

        -- Roll to hit
        if math.random() > accuracy then goto continue end

        -- Consume ammo
        if wm._ammo then
            wm._ammo = wm._ammo - 1
        end

        -- Damage calculation
        local damage = wDamage
        local isCritical = math.random() < CRITICAL_CHANCE
        if isCritical then damage = damage * CRITICAL_MULT end

        -- Railgun penetration: partially bypasses shields
        local penetration = wStats and wStats.penetration or 0

        -- Shield absorption (unless weapon ignores shields)
        local shieldStr = getShieldStrength(wm.targetEntityId)
        if shieldStr > 0 and not (wStats and wStats.ignoresShields) then
            local shieldEffect = SHIELD_ABSORB * shieldStr * (1 - penetration)
            local absorbed = damage * shieldEffect
            damage = damage - absorbed

            local targetShip = ECS.get(wm.targetEntityId, 'ship')
            if targetShip then
                for modId2, mcomps in ECS.query('ship_module') do
                    local mod = mcomps.ship_module
                    if mod.shipId == targetShip.shipId and mod.systemType == 'shield_generator' then
                        mod.efficiency = math.max(0, (mod.efficiency or 1) - 0.05)
                        if mod.efficiency <= 0 then mod.operational = false end
                        break
                    end
                end
            end
        end

        -- EMP weapons: disable systems instead of destroying them
        if wStats and wStats.empDuration and wStats.empDuration > 0 then
            local targetModId2, targetMod2 = findModuleOnShip(wm.targetEntityId, wm.targetSystemType)
            if targetModId2 and targetMod2 then
                targetMod2._empDisabled = true
                targetMod2._empTimer = wStats.empDuration
                targetMod2.operational = false
            end
            goto continue  -- EMP does minimal hull damage, skip normal damage path
        end

        -- Apply hull damage
        local targetShip = ECS.get(wm.targetEntityId, 'ship')
        if targetShip then
            targetShip.hullHP = math.max(0, targetShip.hullHP - damage * 0.3)
        end

        -- Apply system damage to targeted system
        local sysDamageMult = wStats and wStats.systemDamageMult or 1.0
        local targetModId, targetMod = findModuleOnShip(wm.targetEntityId, wm.targetSystemType)
        if targetModId and targetMod then
            local dur = ECS.get(targetModId, 'durability')
            if dur then
                dur.hp = math.max(0, dur.hp - damage * 0.7 * sysDamageMult)
                if dur.hp <= 0 then
                    targetMod.operational = false
                    targetMod.efficiency = 0
                end
            end
        end

        -- Area damage (heavy warheads): damage adjacent modules too
        if wStats and wStats.areaDamage and targetShip then
            for modId3, mcomps in ECS.query('ship_module', 'durability') do
                if mcomps.ship_module.shipId == targetShip.shipId then
                    mcomps.durability.hp = math.max(0, mcomps.durability.hp - wStats.areaDamage * 0.3)
                    if mcomps.durability.hp <= 0 then
                        mcomps.ship_module.operational = false
                    end
                end
            end
        end

        -- System damage consequences
        if targetShip and targetMod and not targetMod.operational then
            local sysType = wm.targetSystemType
            if sysType == 'engine' or sysType == 'engine_bay' then
                targetShip.velocity = 0
            end
        end

        -- Ship destruction check
        if targetShip and targetShip.hullHP <= 0 then
            ShipCombat.destroyShip(wm.targetEntityId)
        end

        ::continue::
    end
end

---------------------------------------------------------------------------
-- Ship destruction
---------------------------------------------------------------------------

function ShipCombat.destroyShip(shipEntityId)
    local ship = ECS.get(shipEntityId, 'ship')
    if not ship then return end

    -- Destroy all modules belonging to this ship
    local toDestroy = { shipEntityId }
    for modId, comps in ECS.query('ship_module') do
        if comps.ship_module.shipId == ship.shipId then
            toDestroy[#toDestroy + 1] = modId
        end
    end

    -- Drop loot at position
    local pos = ECS.get(shipEntityId, 'pos')
    if pos then
        local iok, Items = pcall(require, 'src.world.items')
        if iok and Items.spawn then
            Items.spawn(math.floor(pos.x), math.floor(pos.y), 'steel', math.random(5, 15))
            Items.spawn(math.floor(pos.x), math.floor(pos.y), 'components', math.random(2, 8))
        end
    end

    -- Cleanup engaged pairs
    for attacker, target in pairs(engagedPairs) do
        if target == shipEntityId then engagedPairs[attacker] = nil end
    end
    engagedPairs[shipEntityId] = nil

    -- Destroy entities
    for _, eid in ipairs(toDestroy) do
        ECS.destroy(eid)
    end

    combatActive = next(engagedPairs) ~= nil
end

---------------------------------------------------------------------------
-- Auto-engage hostile NPC ships in range
---------------------------------------------------------------------------

function ShipCombat.checkAutoEngage()
    if GameState.activeMap ~= 'space' then return end

    -- Find player ship
    local playerId, playerPos
    for id, comps in ECS.query('ship', 'pos') do
        if not ECS.has(id, 'npc_ship') then
            playerId = id
            playerPos = comps.pos
            break
        end
    end
    if not playerId or not playerPos then return end

    -- Check NPC ships
    for npcId, comps in ECS.query('npc_ship', 'ship', 'pos') do
        local npc = comps.npc_ship
        if npc.hostility == 'hostile' and npc.aiState == 'engage' then
            if not engagedPairs[npcId] then
                ShipCombat.engage(npcId, playerId)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Step
---------------------------------------------------------------------------

function ShipCombat.step(dt)
    ShipCombat.checkAutoEngage()
    ShipCombat.fireWeapons(dt)

    -- EMP recovery: re-enable systems when EMP timer expires
    for modId, comps in ECS.query('ship_module') do
        local mod = comps.ship_module
        if mod._empDisabled and mod._empTimer then
            mod._empTimer = mod._empTimer - dt
            if mod._empTimer <= 0 then
                mod._empDisabled = nil
                mod._empTimer = nil
                -- Restore if durability is still positive
                local dur = ECS.get(modId, 'durability')
                if dur and dur.hp > 0 then
                    mod.operational = true
                    mod.efficiency = 1.0
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function ShipCombat.getState()
    return {
        combatActive = combatActive,
        engagedPairs = engagedPairs,
    }
end

function ShipCombat.loadState(state)
    if not state then return end
    combatActive = state.combatActive or false
    engagedPairs = state.engagedPairs or {}
end

return ShipCombat
