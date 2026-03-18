-- production_runtime.lua - Runtime hooks and ECS systems for production

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

-- Lazy-loaded modules for production system tick (avoid pcall in hot path)
local _Research, _WorkOrders, _Quality, _Skills, _Hope
local function lazyLoadProduction()
    if _Research ~= nil then return end
    local ok
    ok, _Research = pcall(require, 'src.research.research')
    if not ok then _Research = false end
    ok, _WorkOrders = pcall(require, 'src.building.work_orders')
    if not ok then _WorkOrders = false end
    ok, _Quality = pcall(require, 'src.world.quality')
    if not ok then _Quality = false end
    ok, _Skills = pcall(require, 'src.colonist.skills')
    if not ok then _Skills = false end
    ok, _Hope = pcall(require, 'src.colony.hope')
    if not ok then _Hope = false end
end

return function(Production, defs)
    local RECIPES = defs.RECIPES
    local MACHINES = defs.MACHINES
    local ITEM_TO_RES = defs.ITEM_TO_RES
    function Production.placeMachine(machineId, x, y)
        local def = MACHINES[machineId]
        if not def then return nil end

        local id = ECS.spawn()

        ECS.set(id, 'pos', { x = x, y = y })

        ECS.set(id, 'machine', {
            type       = machineId,
            name       = def.name,
            recipe     = nil,         -- currently set recipe ID
            inputBuf   = {},          -- { [itemId] = count }
            outputBuf  = {},          -- { [itemId] = count }
            progress   = 0,           -- 0 to recipe.time
            active     = false,       -- currently processing?
            powered    = true,        -- has power?
            assignee   = nil,         -- colonist entity ID assigned to operate
        })

        return id
    end

    -- Get all recipes available for a machine type (filtered by research)
    function Production.getRecipesForMachine(machineType)
        lazyLoadProduction()
        local result = {}
        -- Advanced machines inherit recipes from their base machine type
        local machineDef = MACHINES[machineType]
        local baseType = machineDef and machineDef.baseMachine or nil
        local researchReady = _Research and _Research.isInitialized and _Research.isInitialized()
        for recipeId, recipe in pairs(RECIPES) do
            if recipe.machine == machineType or (baseType and recipe.machine == baseType) then
                -- Only show recipes unlocked by research (or if research system unavailable)
                if not recipe.hidden and (not researchReady or _Research.isRecipeUnlocked(recipeId)) then
                    result[#result + 1] = { id = recipeId, recipe = recipe }
                end
            end
        end
        return result
    end

    function Production.getRecipeName(recipeId)
        local recipe = RECIPES[recipeId]
        return recipe and recipe.name or recipeId
    end

    ---------------------------------------------------------------------------
    -- Production system — ticks each sim step
    ---------------------------------------------------------------------------

    local function productionSystem(dt, id, comps)
        local machine = comps.machine

        -- Bill system: if no recipe set, consult the bill queue
        if not machine.recipe then
            lazyLoadProduction()
            if _WorkOrders then
                local bill = _WorkOrders.getActiveBill(id)
                if bill then
                    machine.recipe = bill.recipeId
                    machine._activeBillId = bill.id
                end
            end
        end

        if not machine.recipe then return end

        local recipe = RECIPES[machine.recipe]
        if not recipe then return end

        -- Check power
        if recipe.power > 0 and not machine.powered then
            machine.active = false
            return
        end

        -- Check inputs
        local hasInputs = true
        for itemId, needed in pairs(recipe.inputs) do
            if (machine.inputBuf[itemId] or 0) < needed then
                hasInputs = false
                break
            end
        end

        if not hasInputs then
            machine.active = false
            return
        end

        -- Process
        if not machine.active then
            -- Consume inputs, start crafting
            for itemId, needed in pairs(recipe.inputs) do
                machine.inputBuf[itemId] = machine.inputBuf[itemId] - needed
                if machine.inputBuf[itemId] <= 0 then machine.inputBuf[itemId] = nil end
            end
            machine.active = true
            machine.progress = 0
        end

        -- Advance progress (machine tier bonus + skill bonus from assignee)
        local machineDef = MACHINES[machine.type]
        local speedMult = machineDef and machineDef.speedMult or 1.0
        if machine.assignee and ECS.isAlive(machine.assignee) then
            local col = ECS.get(machine.assignee, 'colonist')
            if col and col.skills and recipe.skill then
                local skillLevel = col.skills[recipe.skill] or 1
                speedMult = 1.0 + (skillLevel - 1) * 0.08
                -- Trait bonuses
                if col.traits then
                    for _, t in ipairs(col.traits) do
                        if t.workSpeed then speedMult = speedMult + t.workSpeed end
                        if t.craftMod then speedMult = speedMult + t.craftMod end
                    end
                end
            end
        end

        machine.progress = machine.progress + dt * speedMult

        if machine.progress >= recipe.time then
            -- Roll quality tier for crafted output
            lazyLoadProduction()
            local rolledQuality = 'normal'
            if machine.assignee and ECS.isAlive(machine.assignee) then
                local col = ECS.get(machine.assignee, 'colonist')
                if col and col.skills and recipe.skill then
                    local sl = col.skills[recipe.skill] or 1

                    -- Master smith mastery: lock quality to masterwork
                    local masterSmith = _Skills and _Skills.hasMastery(machine.assignee, 'master_smith')
                    if masterSmith then
                        rolledQuality = 'masterwork'
                    elseif _Quality then
                        local passion = _Skills and _Skills.getPassion(machine.assignee, recipe.skill) or 0
                        -- Trait qualityBonus: careful +1 effective skill for quality roll
                        local qualitySl = sl
                        if col.traits then
                            for _, t in ipairs(col.traits) do
                                if t.qualityBonus then qualitySl = qualitySl + t.qualityBonus end
                            end
                        end
                        -- Art inspiration: bump quality roll by +4 effective skill
                        local inspired = col.inspired and col.inspirationExpiry and col.inspirationExpiry >= GameState.day
                        if inspired then qualitySl = qualitySl + 4 end

                        local tier = _Quality.roll(qualitySl, passion, false)
                        rolledQuality = tier.id

                        -- Consume inspiration after use
                        if inspired then
                            col.inspired = nil
                            col.inspirationExpiry = nil
                        end
                    end

                    -- Award XP and mark skill used
                    if _Skills then
                        _Skills.onTaskComplete(machine.assignee, 'build')
                        _Skills.markUsed(machine.assignee, recipe.skill)
                    end
                end
            end

            -- Store quality on machine for output tracking
            machine.lastQuality = rolledQuality

            -- Produce outputs (quality tier stored, amount stays base)
            for itemId, amount in pairs(recipe.outputs) do
                machine.outputBuf[itemId] = (machine.outputBuf[itemId] or 0) + amount
            end
            -- Track quality per output item for when items are pushed to storage
            if not machine.outputQuality then machine.outputQuality = {} end
            for itemId in pairs(recipe.outputs) do
                machine.outputQuality[itemId] = rolledQuality
            end
            machine.active = false
            machine.progress = 0

            -- Dark recipe: colony morale penalty (butchering humans, etc.)
            if recipe.dark then
                if _Hope and _Hope.onDarkAction then
                    _Hope.onDarkAction('butcher_human')
                end
                for cid, ccomps in ECS.query('colonist', 'needs') do
                    ccomps.needs.morale = math.max(0, ccomps.needs.morale - 15)
                end
            end

            -- Award crafting XP to assignee
            if machine.assignee then
                if _Skills and recipe.skill then
                    _Skills.addXp(machine.assignee, recipe.skill, 15)
                end
            end

            -- Notify bill system that an item was produced
            do
                if _WorkOrders then
                    _WorkOrders.onItemProduced(id, machine.recipe)
                    -- Check if the active bill is now complete; if so, clear the recipe
                    local bill = _WorkOrders.getActiveBill(id)
                    if not bill or bill.recipeId ~= machine.recipe then
                        machine.recipe = nil
                        machine._activeBillId = nil
                    end
                end
            end

            -- Cycle complete — exit to prevent same-tick restart
            return
        end
    end

    ---------------------------------------------------------------------------
    -- Item-to-resource mapping (used by auto-stock and work order stockpile checks)
    ---------------------------------------------------------------------------

    local ITEM_TO_RES = {
        raw_wood = 'wood', raw_stone = 'stone', raw_ore = 'metal',
        raw_meat = 'food', raw_hide = 'raw_hide', thermal_core = 'thermalCores',
        coal = 'fuel', water = 'water', components = 'components',
        steel = 'steel', circuit = 'circuit',
        -- Intermediate processed materials
        metal_ingot = 'metal', lumber = 'wood', cut_stone = 'cut_stone',
        leather = 'hide', cloth = 'cloth', insulation = 'insulation',
        pipe = 'pipe', glass = 'glass', charcoal = 'charcoal',
        medicinal_herb = 'medicinal_herb',
        lead_ore = 'lead', lead = 'lead',
        -- Corpses & dark processing
        corpse_creature = 'corpse_creature', corpse_human = 'corpse_human',
        human_meat = 'human_meat', human_leather = 'human_leather',
        -- Drug crop materials
        psychoid_leaf = 'psychoid_leaf', smokeleaf_leaf = 'smokeleaf_leaf', hops = 'hops',
        -- Organs
        organ_heart = 'organ_heart', organ_lung = 'organ_lung',
        organ_kidney = 'organ_kidney', organ_liver = 'organ_liver', organ_eye = 'organ_eye',
        -- Prosthetics
        peg_leg = 'peg_leg', wooden_arm = 'wooden_arm',
        prosthetic_leg = 'prosthetic_leg', prosthetic_arm = 'prosthetic_arm',
        bionic_leg = 'bionic_leg', bionic_arm = 'bionic_arm', bionic_eye = 'bionic_eye',
        -- Drugs (input for recipes that consume drugs, e.g. Surge needs Spike)
        spike = 'spike', stardust = 'stardust', drift = 'drift', smog = 'smog',
        rotgut = 'rotgut', shards = 'shards', glimpse = 'glimpse', surge = 'surge', thaw = 'thaw',
        voidbloom = 'voidbloom',
        -- Medical
        bandage = 'bandage', medicine = 'medicine', revivify_serum = 'revivify_serum',
        -- Eldritch
        eldritch_ichor = 'eldritch_ichor', raw_fat = 'raw_fat',
        chitin_plate = 'chitin_plate', void_crystal = 'void_crystal',
        raw_fur = 'raw_fur', caustic_liquid = 'caustic_liquid',
        serpent_venom = 'serpent_venom', fang = 'fang',
        -- Ammo (as recipe inputs for fire arrows, etc.)
        ammo_arrow = 'ammo_arrow', ammo_fire_arrow = 'ammo_fire_arrow',
        ammo_bolt = 'ammo_bolt', ammo_bullet = 'ammo_bullet',
        ammo_shell = 'ammo_shell', ammo_rocket = 'ammo_rocket',
        ammo_mortar_shell = 'ammo_mortar_shell', ammo_thermal = 'ammo_thermal',
        -- Thermal weapons
        weapon_thermal_lance = 'weapon_thermal_lance',
        weapon_thermal_blade = 'weapon_thermal_blade',
        cryo_grenade = 'cryo_grenade',
        napalm_fuel = 'napalm_fuel', foam_canister = 'foam_canister',
        gas_canister = 'gas_canister', acid_canister = 'acid_canister', poison_darts = 'poison_darts',
        -- Throwables
        grenade = 'grenade', ied = 'ied', molotov = 'molotov', pipe_bomb = 'pipe_bomb',
        -- Ordnance
        placed_charge = 'placed_charge', timed_bomb = 'timed_bomb', tripwire_bomb = 'tripwire_bomb',
        napalm_grenade = 'napalm_grenade', napalm_bomb = 'napalm_bomb',
        bio_grenade = 'bio_grenade', bio_bomb = 'bio_bomb',
        foam_grenade = 'foam_grenade', foam_bomb = 'foam_bomb',
        c4_charge = 'c4_charge', emp_charge = 'emp_charge', emp_grenade = 'emp_grenade',
        briefcase_nuke = 'briefcase_nuke', nuclear_core = 'nuclear_core',
        -- Missiles
        missile_he = 'missile_he', missile_napalm = 'missile_napalm',
        missile_bio = 'missile_bio', missile_foam = 'missile_foam',
        missile_bunker = 'missile_bunker', missile_nuke = 'missile_nuke',
        -- Physical item IDs (inputs to processing recipes)
        iron_ore = 'metal', copper_ore = 'metal', uranium_ore = 'metal',
        stone_chunk = 'stone', logs = 'wood', ice_block = 'stone',
        iron_ingot = 'metal', lead_ingot = 'lead', copper_ingot = 'metal',
        fuel = 'fuel',
    }

    Production.ITEM_TO_RES = ITEM_TO_RES

    ---------------------------------------------------------------------------
    -- Auto-stock: machines pull inputs from GameState.resources, push outputs back
    -- Runs every few seconds to connect the production chain to colony economy.
    ---------------------------------------------------------------------------

    local autoStockTimer = 0
    local AUTO_STOCK_INTERVAL = 3.0

    local function autoStockSystem(dt)
        autoStockTimer = autoStockTimer + dt
        if autoStockTimer < AUTO_STOCK_INTERVAL then return end
        autoStockTimer = 0

        -- Output items to resource keys
        local OUTPUT_TO_RES = {
            raw_meat = 'food', raw_hide = 'raw_hide', lumber = 'wood', lead = 'lead',
            cut_stone = 'cut_stone', metal_ingot = 'metal', leather = 'hide',
            cooked_meat = 'food',
            stew = 'food', jerky = 'food', bread = 'food', ration = 'food', feast = 'food',
            steel = 'steel', circuit = 'circuit', components = 'components',
            charcoal = 'charcoal', fuel_cell = 'fuel', water = 'water', coal = 'fuel',
            raw_ore = 'metal',
            cloth = 'cloth', insulation = 'insulation', pipe = 'pipe', glass = 'glass',
            -- Dark processing
            human_meat = 'human_meat', human_leather = 'human_leather',
            -- Drugs
            spike = 'spike', stardust = 'stardust', drift = 'drift', smog = 'smog',
            rotgut = 'rotgut', shards = 'shards', glimpse = 'glimpse', surge = 'surge', thaw = 'thaw',
            voidbloom = 'voidbloom', berserker = 'berserker', stim = 'stim',
            -- Medical
            bandage = 'bandage', medicine = 'medicine', advanced_medicine = 'advanced_medicine',
            revivify_serum = 'revivify_serum',
            -- Prosthetics
            peg_leg = 'peg_leg', wooden_arm = 'wooden_arm',
            prosthetic_leg = 'prosthetic_leg', prosthetic_arm = 'prosthetic_arm',
            bionic_leg = 'bionic_leg', bionic_arm = 'bionic_arm', bionic_eye = 'bionic_eye',
            -- Organs
            organ_heart = 'organ_heart', organ_lung = 'organ_lung',
            organ_kidney = 'organ_kidney', organ_liver = 'organ_liver', organ_eye = 'organ_eye',
            -- Eldritch node outputs
            eldritch_ichor = 'eldritch_ichor', raw_fat = 'raw_fat',
            chitin_plate = 'chitin_plate', void_crystal = 'void_crystal',
            raw_fur = 'raw_fur', thermal_core = 'thermalCores',
            caustic_liquid = 'caustic_liquid', serpent_venom = 'serpent_venom',
            fang = 'fang',
            -- Ammo outputs
            ammo_arrow = 'ammo_arrow', ammo_fire_arrow = 'ammo_fire_arrow',
            ammo_bolt = 'ammo_bolt', ammo_bullet = 'ammo_bullet',
            ammo_shell = 'ammo_shell', ammo_rocket = 'ammo_rocket',
            ammo_mortar_shell = 'ammo_mortar_shell', ammo_thermal = 'ammo_thermal',
            napalm_fuel = 'napalm_fuel', foam_canister = 'foam_canister',
            gas_canister = 'gas_canister', acid_canister = 'acid_canister',
            poison_darts = 'poison_darts',
            -- Throwable outputs
            grenade = 'grenade', ied = 'ied', molotov = 'molotov', pipe_bomb = 'pipe_bomb',
            -- Ordnance outputs
            placed_charge = 'placed_charge', timed_bomb = 'timed_bomb', tripwire_bomb = 'tripwire_bomb',
            napalm_grenade = 'napalm_grenade', napalm_bomb = 'napalm_bomb',
            bio_grenade = 'bio_grenade', bio_bomb = 'bio_bomb',
            foam_grenade = 'foam_grenade', foam_bomb = 'foam_bomb',
            c4_charge = 'c4_charge', emp_charge = 'emp_charge', emp_grenade = 'emp_grenade',
            briefcase_nuke = 'briefcase_nuke', nuclear_core = 'nuclear_core',
            missile_he = 'missile_he', missile_napalm = 'missile_napalm',
            missile_bio = 'missile_bio', missile_foam = 'missile_foam',
            missile_bunker = 'missile_bunker', missile_nuke = 'missile_nuke',
            -- Physical item processing outputs
            iron_ingot = 'metal', lead_ingot = 'lead', copper_ingot = 'metal',
            planks = 'wood', enriched_uranium = 'metal', depleted_uranium = 'metal',
            -- Weapon outputs (stored as colony resources for auto-equip)
            weapon_club = 'weapon_club', weapon_shiv = 'weapon_shiv',
            weapon_pipe_wrench = 'weapon_pipe_wrench', weapon_torch = 'weapon_torch',
            weapon_knife = 'weapon_knife', weapon_hatchet = 'weapon_hatchet',
            weapon_machete = 'weapon_machete', weapon_spear = 'weapon_spear',
            weapon_axe = 'weapon_axe', weapon_sword = 'weapon_sword',
            weapon_shortbow = 'weapon_shortbow', weapon_bow = 'weapon_bow',
            weapon_crossbow = 'weapon_crossbow',
            weapon_revolver = 'weapon_revolver', weapon_pistol = 'weapon_pistol',
            weapon_sawed_off = 'weapon_sawed_off', weapon_pump_shotgun = 'weapon_pump_shotgun',
            weapon_bolt_action = 'weapon_bolt_action',
            weapon_assault_rifle = 'weapon_assault_rifle',
            weapon_battle_rifle = 'weapon_battle_rifle',
            weapon_thermal_lance = 'weapon_thermal_lance',
            weapon_thermal_blade = 'weapon_thermal_blade',
            cryo_grenade = 'cryo_grenade',
        }

        for mid, mcomps in ECS.query('machine') do
            local machine = mcomps.machine

            -- Pull inputs from colony resources if machine has a recipe and buffer is low
            if machine.recipe then
                local recipe = RECIPES[machine.recipe]
                if recipe then
                    for itemId, needed in pairs(recipe.inputs) do
                        local current = machine.inputBuf[itemId] or 0
                        if current < needed * 3 then  -- stock up to 3 batches
                            local resKey = ITEM_TO_RES[itemId]
                            if resKey and GameState.resources[resKey] ~= nil then
                                local available = GameState.resources[resKey]
                                local toTransfer = math.min(needed, available)
                                if toTransfer > 0 then
                                    GameState.resources[resKey] = GameState.resources[resKey] - toTransfer
                                    machine.inputBuf[itemId] = current + toTransfer
                                end
                            end
                        end
                    end
                end
            end

            -- Push outputs to colony resources (skip machines at underwater depths —
            -- those require inserter/conveyor connection or manual hauling)
            local skipAutoFlush = false
            local mpos = ECS.get(mid, 'pos')
            if mpos and (mpos.depth or 0) > 0 then
                -- Check if this is an underwater planet (flooded depths)
                local pOk3, Planet3 = pcall(require, 'src.world.planet')
                if pOk3 and Planet3.getId() == 'nerthus_9' then
                    skipAutoFlush = true
                end
            end

            if not skipAutoFlush then
                for itemId, count in pairs(machine.outputBuf) do
                    if count > 0 then
                        local resKey = OUTPUT_TO_RES[itemId]
                        if resKey and GameState.resources[resKey] ~= nil then
                            GameState.resources[resKey] = GameState.resources[resKey] + count
                            machine.outputBuf[itemId] = 0
                        end
                    end
                end
            end
        end
    end

    Production.autoStock = autoStockSystem

    function Production.registerSystems()
        ECS.addSystem('production', { 'machine' }, productionSystem, 15)
    end
end

