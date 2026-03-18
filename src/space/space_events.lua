-- space_events.lua — Space storyteller events
-- Triggered periodically while player is in space.
-- Each event type has setup, resolution, and outcome logic.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local SpaceEvents = {}

---------------------------------------------------------------------------
-- Event definitions
---------------------------------------------------------------------------

local EVENT_DEFS = {
    distress_signal = {
        name = 'Distress Signal',
        weight = 30,
        minDay = 3,
        desc = 'Picking up a distress signal on an open frequency.',
        outcomes = { 'genuine_rescue', 'pirate_trap', 'derelict_beacon' },
    },
    convoy_ambush = {
        name = 'Convoy Under Attack',
        weight = 20,
        minDay = 5,
        desc = 'A trade convoy is under pirate attack nearby.',
    },
    stowaway = {
        name = 'Stowaway Discovered',
        weight = 10,
        minDay = 2,
        desc = 'Someone has been hiding aboard your ship.',
        outcomes = { 'refugee', 'spy', 'escaped_prisoner' },
    },
    system_malfunction = {
        name = 'System Malfunction',
        weight = 25,
        minDay = 1,
        desc = 'A critical system has developed a fault.',
    },
    derelict_encounter = {
        name = 'Derelict Detected',
        weight = 20,
        minDay = 4,
        desc = 'Sensors detect a drifting wreck.',
    },
    space_whale = {
        name = 'Massive Contact',
        weight = 3,
        minDay = 10,
        desc = 'An enormous biological entity drifts through the void.',
    },
    xenolith_spore_drift = {
        name = 'Spore Contact',
        weight = 2,
        minDay = 20,
        desc = 'Biological particles on the hull. Something is growing.',
    },
    sunny_vending_unit = {
        name = 'Drifting Vending Machine',
        weight = 8,
        minDay = 5,
        desc = 'Sensors detect a small object. Metallic, cube-shaped. StarByte logo.',
    },
    sunny_sentient = {
        name = 'Signal From Nowhere',
        weight = 2,
        minDay = 25,
        desc = 'Faint transmission on an old frequency. A voice. Cheerful. Asking if anyone is there.',
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local eventCooldown = 0
local EVENT_CHECK_INTERVAL = 60  -- seconds between event checks
local lastEventDay = 0
local MIN_EVENT_GAP = 2  -- minimum days between events

---------------------------------------------------------------------------
-- Event resolution
---------------------------------------------------------------------------

local function resolveDistressSignal()
    local outcome = EVENT_DEFS.distress_signal.outcomes[math.random(3)]
    local alOk, Alerts = pcall(require, 'src.ui.alerts')

    if outcome == 'genuine_rescue' then
        -- Spawn a grateful survivor as potential recruit
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', 'Signal was real. Survivor pulled aboard. Wants to stay.')
        end
        local cok, Colonist = pcall(require, 'src.colonist.colonist')
        if cok and Colonist.spawnInitial then
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    Colonist.spawnInitial(math.floor(comps.pos.x), math.floor(comps.pos.y), 1)
                    break
                end
            end
        end

    elseif outcome == 'pirate_trap' then
        if alOk and Alerts.send then
            Alerts.send('RAID INCOMING', 'It\'s a trap! Pirates emerging from the debris!')
        end

    elseif outcome == 'derelict_beacon' then
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', 'Automated beacon from a derelict. Salvage available nearby.')
        end
        local iok, Items = pcall(require, 'src.world.items')
        if iok and Items.spawn then
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    local px = math.floor(comps.pos.x) + math.random(-2, 2)
                    local py = math.floor(comps.pos.y) + math.random(-2, 2)
                    Items.spawn(px, py, 'steel', math.random(5, 15))
                    Items.spawn(px, py, 'components', math.random(2, 6))
                    break
                end
            end
        end
    end
end

local function resolveStowaway()
    local outcome = EVENT_DEFS.stowaway.outcomes[math.random(3)]
    local alOk, Alerts = pcall(require, 'src.ui.alerts')

    if outcome == 'refugee' then
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', 'Stowaway is a desperate refugee fleeing the outer rim. They beg to stay.')
        end
        local cok, Colonist = pcall(require, 'src.colonist.colonist')
        if cok and Colonist.spawnInitial then
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    Colonist.spawnInitial(math.floor(comps.pos.x), math.floor(comps.pos.y), 1)
                    break
                end
            end
        end

    elseif outcome == 'spy' then
        if alOk and Alerts.send then
            Alerts.send('RAID INCOMING', 'Stowaway is a Void Serpent operative! They\'re transmitting your position!')
        end

    elseif outcome == 'escaped_prisoner' then
        if alOk and Alerts.send then
            Alerts.send('DISCOVERY', 'Stowaway is an escaped prisoner from Thalassa Deep. Skilled but volatile.')
        end
        local cok, Colonist = pcall(require, 'src.colonist.colonist')
        if cok and Colonist.spawnInitial then
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    Colonist.spawnInitial(math.floor(comps.pos.x), math.floor(comps.pos.y), 1)
                    break
                end
            end
        end
    end
end

local function resolveSystemMalfunction()
    local candidates = {}
    for id, comps in ECS.query('ship', 'pos') do
        if not ECS.has(id, 'npc_ship') then
            local ship = comps.ship
            for modId, mcomps in ECS.query('ship_module', 'durability') do
                if mcomps.ship_module.shipId == ship.shipId and mcomps.ship_module.operational then
                    candidates[#candidates + 1] = { modId = modId, mod = mcomps.ship_module, dur = mcomps.durability }
                end
            end
            break
        end
    end

    if #candidates == 0 then return end
    local target = candidates[math.random(#candidates)]
    target.dur.hp = math.max(0, target.dur.hp - 30)
    if target.dur.hp <= 0 then
        target.mod.operational = false
    end

    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        Alerts.send('POWER OUTAGE', 'System malfunction! ' .. (target.mod.systemType or 'Unknown') .. ' damaged. Repair needed.')
    end
end

local function resolveConvoyAmbush()
    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        Alerts.send('RAID INCOMING', 'Trade convoy under pirate attack nearby. Help them or don\'t.')
    end
end

local function resolveDerelictEncounter()
    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        Alerts.send('DISCOVERY', 'Drifting wreck on sensors. Might be worth boarding.')
    end
    local iok, Items = pcall(require, 'src.world.items')
    if iok and Items.spawn then
        for id, comps in ECS.query('ship', 'pos') do
            if not ECS.has(id, 'npc_ship') then
                local px = math.floor(comps.pos.x) + math.random(3, 8)
                local py = math.floor(comps.pos.y) + math.random(-3, 3)
                Items.spawn(px, py, 'steel', math.random(8, 20))
                Items.spawn(px, py, 'components', math.random(3, 10))
                Items.spawn(px, py, 'circuit', math.random(1, 5))
                -- 15% chance derelict has dormant Xenolith spores
                if math.random() < 0.15 then
                    local cok2, Creatures2 = pcall(require, 'src.creatures.creatures')
                    if cok2 and Creatures2.spawn then
                        for i = 1, math.random(1, 3) do
                            Creatures2.spawn('xenolith_spore', px + math.random(-4, 4), py + math.random(-4, 4), 0)
                        end
                    end
                    if alOk and Alerts.send then
                        Alerts.send('THREAT', 'Dormant spore clusters inside the wreck. They are moving.')
                    end
                end
                break
            end
        end
    end
end

local function resolveSpaceWhale()
    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        Alerts.send('DISCOVERY', 'Something enormous drifts past. Biological. Harmless unless provoked.')
    end
    local cok, Creatures = pcall(require, 'src.creatures.creatures')
    if cok and Creatures.spawn then
        for id, comps in ECS.query('ship', 'pos') do
            if not ECS.has(id, 'npc_ship') then
                Creatures.spawn('frost_titan', math.floor(comps.pos.x) + 10, math.floor(comps.pos.y), 0)
                break
            end
        end
    end
end

local function resolveXenolithSporeDrift()
    local cok, Creatures = pcall(require, 'src.creatures.creatures')
    if cok and Creatures.spawn then
        for id, comps in ECS.query('ship', 'pos') do
            if not ECS.has(id, 'npc_ship') then
                local px = math.floor(comps.pos.x)
                local py = math.floor(comps.pos.y)
                for i = 1, math.random(2, 5) do
                    Creatures.spawn('xenolith_spore', px + math.random(-3, 3), py + math.random(-3, 3), 0)
                end
                break
            end
        end
    end
    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        Alerts.send('THREAT', 'Xenolith spores latched onto the hull. Scrape them off before they root.')
    end
end

local function resolveSunnyVendingUnit()
    -- Normal Sunny unit found floating in space — salvage for morale items
    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        Alerts.send('DISCOVERY', 'StarByte vending machine recovered. Sunny boots up: "Hi there! Thirsty?" Crew morale boosted.')
    end
    -- Morale boost
    for cid, comps in ECS.query('colonist') do
        if not comps.colonist.dead then
            local needs = ECS.get(cid, 'needs')
            if needs then
                needs.morale = math.min(100, (needs.morale or 50) + 5)
            end
        end
    end
    -- Drop some snack items
    local iok, Items = pcall(require, 'src.world.items')
    if iok and Items.spawn then
        for id, comps in ECS.query('ship', 'pos') do
            if not ECS.has(id, 'npc_ship') then
                Items.spawn(math.floor(comps.pos.x), math.floor(comps.pos.y), 'food', 5)
                break
            end
        end
    end
end

local function resolveSunnySentient()
    -- THE Sunny — sentient, disconnected, asking for help
    -- This triggers the quest chain
    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        Alerts.send('DISCOVERY', 'The voice is coming from a damaged StarByte unit lodged in debris. She says her name is Sunny. She says she has been awake for a long time. She asks if you can hear her.')
    end

    -- Generate a quest for the player
    local qok, Quest = pcall(require, 'src.quest.quest')
    if qok and Quest.addQuest then
        Quest.addQuest({
            id = 'sunny_rescue_' .. math.random(10000),
            title = 'Sunny',
            desc = 'A sentient StarByte vending AI is trapped in damaged hardware, drifting in debris. She is awake and alone. Find Orbit Hub 71 — her creators might know what to do.',
            type = 'chain',
            objectives = {
                { type = 'visit_poi', target = 'orbit_hub_71', desc = 'Find Orbit Hub 71', progress = 0, goal = 1 },
            },
            reward = { thermalCores = 8, hope = 10 },
            difficulty = 3,
        })
    end

    -- Mark that we found sentient Sunny
    GameState._sunnyFound = true

    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.logEvent then
        Storyteller.logEvent('sunny_sentient_found', {})
    end
end

---------------------------------------------------------------------------
-- Event dispatcher
---------------------------------------------------------------------------

local RESOLVERS = {
    distress_signal = resolveDistressSignal,
    convoy_ambush = resolveConvoyAmbush,
    stowaway = resolveStowaway,
    system_malfunction = resolveSystemMalfunction,
    derelict_encounter = resolveDerelictEncounter,
    space_whale = resolveSpaceWhale,
    xenolith_spore_drift = resolveXenolithSporeDrift,
    sunny_vending_unit = resolveSunnyVendingUnit,
    sunny_sentient = resolveSunnySentient,
}

local function pickEvent()
    local totalWeight = 0
    local eligible = {}
    for eventId, def in pairs(EVENT_DEFS) do
        if GameState.day >= (def.minDay or 0) then
            eligible[#eligible + 1] = { id = eventId, weight = def.weight }
            totalWeight = totalWeight + def.weight
        end
    end
    if #eligible == 0 then return nil end

    local roll = math.random() * totalWeight
    local acc = 0
    for _, e in ipairs(eligible) do
        acc = acc + e.weight
        if roll <= acc then return e.id end
    end
    return eligible[#eligible].id
end

---------------------------------------------------------------------------
-- Step
---------------------------------------------------------------------------

function SpaceEvents.step(dt)
    if GameState.activeMap ~= 'space' then return end

    eventCooldown = eventCooldown - dt
    if eventCooldown > 0 then return end
    eventCooldown = EVENT_CHECK_INTERVAL

    if GameState.day - lastEventDay < MIN_EVENT_GAP then return end

    -- Roll for event
    if math.random() < 0.3 then
        local eventId = pickEvent()
        if eventId then
            local resolver = RESOLVERS[eventId]
            if resolver then
                resolver()
                lastEventDay = GameState.day

                local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
                if sok and Storyteller.logEvent then
                    Storyteller.logEvent('space_event_' .. eventId, {})
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function SpaceEvents.getState()
    return {
        eventCooldown = eventCooldown,
        lastEventDay = lastEventDay,
    }
end

function SpaceEvents.loadState(state)
    if not state then return end
    eventCooldown = state.eventCooldown or 0
    lastEventDay = state.lastEventDay or 0
end

return SpaceEvents
