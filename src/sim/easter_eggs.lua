-- easter_eggs.lua -- rare atmospheric discovery events
-- The Markiplier easter egg (Fischbach colonist + blood rain) lives in
-- weather.lua for Erebus. On Nerthus-9 the ocean turns blood red and rises.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')

local EasterEggs = {}

local state = {}

-- Original ocean/water tile colors (stored on first activation to restore later)
local ORIGINAL_COLORS = {}

local BLOOD_OCEAN_COLORS = {
    [Tiles.OCEAN]    = {0.45, 0.05, 0.05},
    [Tiles.SHALLOWS] = {0.55, 0.1, 0.1},
    [Tiles.WATER]    = {0.5, 0.08, 0.08},
    [Tiles.SEAWEED]  = {0.35, 0.1, 0.05},
}

local BLOOD_RISE_INTERVAL = 2.0   -- seconds between flood pulses
local BLOOD_CHECK_DAY     = 2    -- check once on this game day (not recurring)
local BLOOD_RAIN_DURATION = 180  -- seconds of blood rain on non-ocean planets

local function resetState()
    state = {
        bloodOceanActive = false,
        bloodOceanFired  = false,  -- only triggers once per game
        checked          = false,  -- true after the one-time day-2 check
        riseTimer        = 0,
        -- Non-ocean planets: blood rain timer
        bloodRainTimer   = 0,
        bloodRainActive  = false,

        -- HERMES audit eggs: one-shot flavor events with specific triggers
        dreamVarianceTriggered       = false,
        cargoCultTriggered           = false,
        scannerVarianceTriggered     = false,
        automationExceptionTriggered = false,
        continuityAssetTriggered     = false,
        skyGeometryTriggered         = false,
        autopsyAddendumTriggered     = false,
        expeditionTapeTriggered      = false,
        quotaSpinTriggered           = false,
        manifestDensityTriggered     = false,
        socialContainmentTriggered   = false,
        dreamVarianceTimer       = 0,
        cargoCultTimer           = 0,
        scannerVarianceTimer     = 0,
        automationExceptionTimer = 0,
        skyGeometryTimer         = 0,
        socialContainmentTimer   = 0,
        lastSafetyNetSeen        = false,  -- edge detector for GameState._safetyNetUsed
        storyLogSeen             = 0,      -- cursor into Storyteller event log
    }
end

--- Check if any living colonist has "Fischbach" as their last name.
local function hasFischbachColonist()
    for _, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' and comps.colonist.name then
            if comps.colonist.name:match('%s[Ff]ischbach$') then
                return true
            end
        end
    end
    return false
end

--- Activate the blood ocean: change tile colors and start water rise.
local function activateBloodOcean()
    if state.bloodOceanActive then return end
    state.bloodOceanActive = true
    state.bloodOceanFired = true

    -- Store original colors and swap to blood
    for tileId, bloodColor in pairs(BLOOD_OCEAN_COLORS) do
        local props = Tiles.props[tileId]
        if props then
            ORIGINAL_COLORS[tileId] = { props.color[1], props.color[2], props.color[3] }
            props.color = bloodColor
        end
    end

    -- Alert
    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send('The Ocean Bleeds',
            'The water turns red. All of it. At once. It is rising.',
            'critical')
    end
end

--- Deactivate blood ocean (restore colors). Only happens when Fischbach
--- dies inside a submersible (diving bell or underwater hab at depth > 0).
local function deactivateBloodOcean()
    if not state.bloodOceanActive then return end
    state.bloodOceanActive = false

    for tileId, origColor in pairs(ORIGINAL_COLORS) do
        local props = Tiles.props[tileId]
        if props and origColor then
            props.color = origColor
        end
    end
    ORIGINAL_COLORS = {}

    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send('The Ocean Calms',
            'The red drains from the water. The tide recedes. Whatever it was, it is satisfied.',
            'major')
    end
end

--- Check if Fischbach died underwater (depth > 0). Called from kill/death hooks.
function EasterEggs.onColonistDeath(entityId)
    if not state.bloodOceanActive then return end
    if GameState.planet ~= 'nerthus_9' then return end

    local col = ECS.get(entityId, 'colonist')
    if not col or not col.name then return end
    if not col.name:match('%s[Ff]ischbach$') then return end

    -- Must die at depth > 0 (underwater / in submersible)
    local pos = ECS.get(entityId, 'pos')
    if pos and (pos.depth or 0) > 0 then
        deactivateBloodOcean()
    end
    -- If died on surface, ocean stays blood red forever
end

---------------------------------------------------------------------------
-- HERMES audit eggs
---------------------------------------------------------------------------

local function logEgg(name, message)
    local ok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if ok and Storyteller.logEvent then
        Storyteller.logEvent(name, message)
    end
end

local function fireOnce(triggeredField, name, message)
    if state[triggeredField] then return end
    state[triggeredField] = true
    logEgg(name, message)
end

--- Timer egg: condition must hold for `threshold` seconds, then fires once.
local function advanceTimerEgg(dt, condition, timerField, threshold, triggeredField, name, message)
    if state[triggeredField] then return end
    if not condition then
        state[timerField] = 0
        return
    end
    state[timerField] = state[timerField] + dt
    if state[timerField] >= threshold then
        fireOnce(triggeredField, name, message)
    end
end

local function countActiveDrugs(entityId)
    local addictions = ECS.get(entityId, 'addictions')
    if not addictions then return 0 end
    local n = 0
    for _, drug in pairs(addictions) do
        if type(drug) == 'table' and (drug.activeEffect or 0) > 0 then
            n = n + 1
        end
    end
    return n
end

--- Night crew (asleep at noon marks a night-shift schedule), exhausted, on stimulants.
local function countDreamVarianceCrew()
    local n = 0
    for id, comps in ECS.query('colonist', 'needs', 'schedule') do
        local col, needs, sched = comps.colonist, comps.needs, comps.schedule
        if col.state ~= 'dead' and (needs.rest or 100) < 30
           and sched[12] == 'sleep' and countActiveDrugs(id) > 0 then
            n = n + 1
        end
    end
    return n
end

local function hasScannerVarianceColonist()
    for id, comps in ECS.query('colonist') do
        local col = comps.colonist
        if col.state ~= 'dead' and (col.sanity or 100) < 40
           and countActiveDrugs(id) >= 2 then
            return true
        end
    end
    return false
end

local function countMentalBreaks()
    local n = 0
    for _, comps in ECS.query('colonist') do
        if comps.colonist.state == 'mental_break' then n = n + 1 end
    end
    return n
end

--- Survey the belt network once for both conveyor eggs.
--- Cargo cult: a long belt line that carries nothing.
--- Automation exception: a frozen splitter network that still holds cargo.
local function conveyorNetworkConditions()
    local ok, Conveyors = pcall(require, 'src.logistics.conveyors')
    if not ok then return false, false end
    local wok, Tilemap = pcall(require, 'src.world.tilemap')
    local count, items, splitters, frozen = 0, 0, 0, 0
    for k, belt in pairs(Conveyors.allBelts()) do
        count = count + 1
        if belt.item then items = items + 1 end
        if belt.splitter then splitters = splitters + 1 end
        if belt.frozen then
            frozen = frozen + 1
        elseif wok then
            local x, y = Conveyors.keyToXY(k)
            if (Tilemap.getTemp(x, y) or 0) < -20 then frozen = frozen + 1 end
        end
    end
    local cargoCult = count >= 20 and items == 0
    local automation = frozen >= 10 and splitters >= 1 and items >= 1
    return cargoCult, automation
end

local function skyGeometryCondition()
    local wok, Weather = pcall(require, 'src.weather.weather')
    local aok, Anomaly = pcall(require, 'src.sim.anomaly')
    if not (wok and aok) then return false end
    return Weather.getCurrent() == 'aurora' and Anomaly.getLevel() >= 50
end

local function stepHermesEggs(dt)
    -- Continuity asset: fires when the emergency safety net is first consumed
    local netUsed = GameState._safetyNetUsed == true
    if netUsed and not state.lastSafetyNetSeen then
        fireOnce('continuityAssetTriggered', 'Crew Continuity Asset',
            'Emergency manifest reconciled: two crates logged, two consumed. There was never a third crate. Do not requisition the third crate.')
    end
    state.lastSafetyNetSeen = netUsed

    local cargoCult, automationException = conveyorNetworkConditions()

    advanceTimerEgg(dt, countDreamVarianceCrew() >= 2,
        'dreamVarianceTimer', 15, 'dreamVarianceTriggered',
        'HERMES Audit: Dream Variance',
        'Sleep telemetry flags the night crew as dreaming the same dream. HERMES recommends no further stimulants pending review.')

    advanceTimerEgg(dt, cargoCult,
        'cargoCultTimer', 25, 'cargoCultTriggered',
        'Logistics Note: Conveyor Devotion',
        'The long belt line has moved nothing for days, yet the crew keeps it powered and leaves small offerings. HERMES declines to classify this as religion.')

    advanceTimerEgg(dt, hasScannerVarianceColonist(),
        'scannerVarianceTimer', 8, 'scannerVarianceTriggered',
        'HERMES Audit: Scanner Variance',
        'One badge, three biometric profiles. HERMES cannot confirm they are the same person. Ticket closed as hardware fault.')

    advanceTimerEgg(dt, automationException,
        'automationExceptionTimer', 15, 'automationExceptionTriggered',
        'Improvised Automation Exception',
        'A frozen splitter network continues to hold throughput. The arrangement is unsanctioned, out of spec, and measurably more efficient than the approved design.')

    advanceTimerEgg(dt, skyGeometryCondition(),
        'skyGeometryTimer', 10, 'skyGeometryTriggered',
        'Impossible Constellations',
        'Navigation cross-check failed during the aurora: the sky overhead matches no catalogued geometry. HERMES recommends not looking up.')

    advanceTimerEgg(dt, countMentalBreaks() >= 2,
        'socialContainmentTimer', 6, 'socialContainmentTriggered',
        'HERMES Advisory: Social Containment',
        'Multiple colonists are experiencing synchronized breakdowns. Advisory: install additional walls between them.')

    -- Immediate manifest checks
    local res = GameState.resources or {}
    if (res.corpse_human or 0) >= 1 and (res.corpse_creature or 0) >= 1 then
        fireOnce('autopsyAddendumTriggered', 'Autopsy Addendum',
            'Post-mortem inventory reconciled human and creature remains. Addendum: the heart on file came from the wrong specimen.')
    end
    if (res.food or 0) >= 250 then
        fireOnce('manifestDensityTriggered', 'Manifest Density Exception',
            'A single pallet of rations exceeds rated cargo density. HERMES recommends counting them twice.')
    end

    -- Reactions to new story-log entries
    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.getLog then
        local log = Storyteller.getLog()
        if (state.storyLogSeen or 0) > #log then state.storyLogSeen = #log end
        local sawRecovery, sawQuotaReview = false, false
        for i = (state.storyLogSeen or 0) + 1, #log do
            if log[i].name == 'Expedition Recovery' then sawRecovery = true end
            if log[i].name == 'Quota Review' then sawQuotaReview = true end
        end
        state.storyLogSeen = #log
        if sawRecovery then
            fireOnce('expeditionTapeTriggered', 'Recovered Tape 03',
                'Every crew member on the recovered tape describes the expedition returning through different doors. All of them are on camera. None of the doors are.')
        end
        if sawQuotaReview then
            local qok, Quotas = pcall(require, 'src.sim.quotas')
            local last = qok and Quotas.getLastQuota and Quotas.getLastQuota()
            if last and last.status == 'failed' then
                fireOnce('quotaSpinTriggered', 'Corporate Optics Memo',
                    'Corporate has reframed the missed shipment as a strategic reserve posture. Compliance thanks you for your continued discretion.')
            end
        end
    end
end

function EasterEggs.init()
    resetState()
end

function EasterEggs.step(dt)
    stepHermesEggs(dt)

    -- One-time Fischbach check on day 2
    if not state.checked then
        if GameState.day >= BLOOD_CHECK_DAY then
            state.checked = true
            if not state.bloodOceanFired and hasFischbachColonist() then
                if GameState.planet == 'nerthus_9' then
                    -- Ocean planet: permanent blood ocean
                    activateBloodOcean()
                else
                    -- Other planets: trigger blood rain + flooding for limited time
                    state.bloodRainActive = true
                    state.bloodRainTimer = BLOOD_RAIN_DURATION
                    state.bloodOceanFired = true
                    local wOk, Weather = pcall(require, 'src.weather.weather')
                    if wOk and Weather.force then
                        Weather.force('blood_rain', BLOOD_RAIN_DURATION)
                    end
                    local aok, Alerts = pcall(require, 'src.ui.alerts')
                    if aok and Alerts.send then
                        Alerts.send('Blood Rain',
                            'The sky turns red. It is raining something that is not water.',
                            'major')
                    end
                end
            end
        else
            return
        end
    end

    -- Non-ocean blood rain countdown
    if state.bloodRainActive then
        state.bloodRainTimer = state.bloodRainTimer - dt
        if state.bloodRainTimer <= 0 then
            state.bloodRainActive = false
        end
    end

    -- Nerthus-9 only below this point
    if GameState.planet ~= 'nerthus_9' then return end
    if not state.bloodOceanActive then return end

    -- Blood ocean rising: inject water into surface tiles periodically
    if state.bloodOceanActive then
        state.riseTimer = state.riseTimer + dt
        if state.riseTimer >= BLOOD_RISE_INTERVAL then
            state.riseTimer = state.riseTimer - BLOOD_RISE_INTERVAL

            local wok, World = pcall(require, 'src.world.tilemap')
            if wok then
                local w, h = World.width(), World.height()
                local samples = math.min(w * h, 60)
                for _ = 1, samples do
                    local rx = math.random(0, w - 1)
                    local ry = math.random(0, h - 1)
                    local tile = World.getTile(rx, ry, 0)
                    if tile and not Tiles.isSolid(tile) then
                        local tfOk, TileFluids = pcall(require, 'src.sim.tile_fluids')
                        if tfOk and TileFluids.addWater then
                            TileFluids.addWater(rx, ry, 1, 0)
                        end
                    end
                end
            end
        end
    end

    -- Fischbach submersible curse: if Mark is inside a submersible,
    -- it degrades and leaks blood water into the sealed room
    for id, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.name and col.name:match('%s[Ff]ischbach$') then
            local pos = comps.pos
            if pos and (pos.depth or 0) > 0 then
                -- Check if standing on a submersible tile (SEALED_FLOOR placed by submersible)
                local wok2, World2 = pcall(require, 'src.world.tilemap')
                if wok2 then
                    local bOk, Building = pcall(require, 'src.building.building')
                    if bOk and Building.getAt then
                        local bld = Building.getAt(pos.x, pos.y, pos.depth)
                        if bld and bld.defId == 'submersible' then
                            -- Degrade the submersible's durability
                            if bld.entityId then
                                local dur = ECS.get(bld.entityId, 'durability')
                                if dur then
                                    dur.current = dur.current - 0.15 * dt
                                    if dur.current < 0 then dur.current = 0 end
                                end
                            end
                            -- Leak blood water into the submersible's tiles
                            local tfOk, TileFluids = pcall(require, 'src.sim.tile_fluids')
                            if tfOk and TileFluids.addWater then
                                TileFluids.addWater(pos.x, pos.y, 1, pos.depth)
                            end
                        end
                    end
                end
            end
        end
    end
end

function EasterEggs.isBloodOcean()
    return state.bloodOceanActive
end

-- HERMES egg fields persisted through save/load
local HERMES_FLAGS = {
    'dreamVarianceTriggered', 'cargoCultTriggered', 'scannerVarianceTriggered',
    'automationExceptionTriggered', 'continuityAssetTriggered', 'skyGeometryTriggered',
    'autopsyAddendumTriggered', 'expeditionTapeTriggered', 'quotaSpinTriggered',
    'manifestDensityTriggered', 'socialContainmentTriggered', 'lastSafetyNetSeen',
}
local HERMES_TIMERS = {
    'dreamVarianceTimer', 'cargoCultTimer', 'scannerVarianceTimer',
    'automationExceptionTimer', 'skyGeometryTimer', 'socialContainmentTimer',
    'storyLogSeen',
}

function EasterEggs.getState()
    local saved = {
        bloodOceanActive = state.bloodOceanActive,
        bloodOceanFired  = state.bloodOceanFired,
        checked          = state.checked,
        bloodRainActive  = state.bloodRainActive,
        bloodRainTimer   = state.bloodRainTimer,
    }
    for _, k in ipairs(HERMES_FLAGS)  do saved[k] = state[k] end
    for _, k in ipairs(HERMES_TIMERS) do saved[k] = state[k] end
    return saved
end

function EasterEggs.restoreState(saved)
    resetState()
    if saved then
        state.bloodOceanFired = saved.bloodOceanFired or false
        state.bloodOceanActive = saved.bloodOceanActive or false
        state.checked = saved.checked or false
        state.bloodRainActive = saved.bloodRainActive or false
        state.bloodRainTimer = saved.bloodRainTimer or 0
        for _, k in ipairs(HERMES_FLAGS)  do state[k] = saved[k] or false end
        for _, k in ipairs(HERMES_TIMERS) do state[k] = saved[k] or 0 end
        -- Re-apply blood colors if active
        if state.bloodOceanActive then
            for tileId, bloodColor in pairs(BLOOD_OCEAN_COLORS) do
                local props = Tiles.props[tileId]
                if props then
                    ORIGINAL_COLORS[tileId] = { props.color[1], props.color[2], props.color[3] }
                    props.color = bloodColor
                end
            end
        end
    end
end

resetState()

return EasterEggs
