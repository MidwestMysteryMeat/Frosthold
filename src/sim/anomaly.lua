-- anomaly.lua — Anomaly escalation system
-- Drilling, exploring precursor sites, and eldritch node growth raise the anomaly level.
-- Higher anomaly = stranger storyteller events, eldritch creature spawns, reality distortion.
-- At level 80+, That Which Sleeps can awaken.
-- Defeating it clears anomaly, enabling Mammona extraction as the true win condition.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Anomaly = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local state = {
    level            = 0,     -- 0-100 anomaly intensity
    totalAccumulated = 0,     -- lifetime anomaly points (never decreases)
    bossAwakened     = false, -- That Which Sleeps has been summoned
    bossDefeated     = false, -- boss killed, anomaly cleared
    extractionReady  = false, -- Mammona extraction win condition unlocked
    bossEntityId     = nil,   -- ECS entity ID of the boss (if spawned)
    lastEventDay     = 0,     -- cooldown: day of last anomaly event
}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

-- Anomaly source rates (per occurrence)
local DRILL_ANOMALY     = 0.3   -- per deep drill cycle completed
local EXPLORE_ANOMALY   = 2.0   -- per expedition to precursor site
local NODE_GROWTH       = 0.1   -- per eldritch node stage gain
local ARTIFACT_ANOMALY  = 3.0   -- per precursor artifact activated

-- Thresholds for escalating effects
local THRESHOLD_MILD     = 20   -- mild disturbances begin
local THRESHOLD_MODERATE = 40   -- creature spawns increase
local THRESHOLD_SEVERE   = 60   -- reality tears, weather anomalies
local THRESHOLD_CRITICAL = 80   -- That Which Sleeps can awaken

-- Natural decay per game day (anomaly slowly fades without stimulus)
local DAILY_DECAY = 0.5

-- Event cooldown
local EVENT_COOLDOWN_DAYS = 2

---------------------------------------------------------------------------
-- Anomaly modification
---------------------------------------------------------------------------

function Anomaly.addAnomaly(amount, source)
    if state.bossDefeated then return end  -- anomaly cleared after boss kill

    state.level = math.min(100, state.level + amount)
    state.totalAccumulated = state.totalAccumulated + amount

    -- Notify alerts at threshold crossings
    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        if state.level >= THRESHOLD_CRITICAL and state.level - amount < THRESHOLD_CRITICAL then
            Alerts.send('Anomaly Critical',
                'The ground trembles. Something vast stirs beneath the ice.',
                'critical')
        elseif state.level >= THRESHOLD_SEVERE and state.level - amount < THRESHOLD_SEVERE then
            Alerts.send('Anomaly Surge',
                'Reality feels thin. Colonists report visual distortions.',
                'major')
        elseif state.level >= THRESHOLD_MODERATE and state.level - amount < THRESHOLD_MODERATE then
            Alerts.send('Anomaly Rising',
                'Strange readings from underground. The ice hums.',
                'minor')
        end
    end
end

function Anomaly.getLevel()
    return state.level
end

function Anomaly.getTier()
    if state.level >= THRESHOLD_CRITICAL then return 'critical' end
    if state.level >= THRESHOLD_SEVERE then return 'severe' end
    if state.level >= THRESHOLD_MODERATE then return 'moderate' end
    if state.level >= THRESHOLD_MILD then return 'mild' end
    return 'none'
end

---------------------------------------------------------------------------
-- Deep drill hook — called from deep_drill.lua on cycle complete
---------------------------------------------------------------------------

function Anomaly.onDrillCycle()
    Anomaly.addAnomaly(DRILL_ANOMALY, 'drill')
end

---------------------------------------------------------------------------
-- Expedition hook — called when returning from precursor sites
---------------------------------------------------------------------------

function Anomaly.onPrecursorExploration()
    Anomaly.addAnomaly(EXPLORE_ANOMALY, 'expedition')
end

---------------------------------------------------------------------------
-- Eldritch node hook — called when a node gains a growth stage
---------------------------------------------------------------------------

function Anomaly.onNodeGrowth()
    Anomaly.addAnomaly(NODE_GROWTH, 'node')
end

---------------------------------------------------------------------------
-- Artifact activation hook
---------------------------------------------------------------------------

function Anomaly.onArtifactActivated()
    Anomaly.addAnomaly(ARTIFACT_ANOMALY, 'artifact')
end

---------------------------------------------------------------------------
-- Boss awakening — That Which Sleeps
---------------------------------------------------------------------------

function Anomaly.canAwakenBoss()
    return state.level >= THRESHOLD_CRITICAL
       and not state.bossAwakened
       and not state.bossDefeated
end

function Anomaly.awakenBoss()
    if not Anomaly.canAwakenBoss() then return false end

    state.bossAwakened = true

    -- Spawn That Which Sleeps at map center
    local bok, Bosses = pcall(require, 'src.creatures.bosses')
    if bok and Bosses.spawn then
        local cx = math.floor((GameState.mapWidth or 128) / 2)
        local cy = math.floor((GameState.mapHeight or 128) / 2)
        local bossId = Bosses.spawn('that_which_sleeps_boss', cx, cy)
        state.bossEntityId = bossId
    end

    -- Alert
    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send('THAT WHICH SLEEPS AWAKENS',
            'The ice splits. Something ancient rises from beneath the permafrost. The colony must fight or fall.',
            'critical',
            math.floor((GameState.mapWidth or 128) / 2),
            math.floor((GameState.mapHeight or 128) / 2))
    end

    return true
end

function Anomaly.onBossDefeated()
    state.bossDefeated = true
    state.bossAwakened = false
    state.bossEntityId = nil
    state.level = 0  -- anomaly cleared

    -- Enable Mammona extraction win condition
    state.extractionReady = true

    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send('Anomaly Cleared',
            'That Which Sleeps is dead. The anomaly dissipates. Mammona extraction is now possible.',
            'major')
    end
end

function Anomaly.isBossAwakened()
    return state.bossAwakened
end

function Anomaly.isBossDefeated()
    return state.bossDefeated
end

function Anomaly.isExtractionReady()
    return state.extractionReady
end

---------------------------------------------------------------------------
-- Anomaly effects on gameplay
---------------------------------------------------------------------------

-- Creature spawn budget multiplier (raids/storyteller use this)
function Anomaly.getCreatureSpawnMult()
    if state.level < THRESHOLD_MILD then return 1.0 end
    return 1.0 + (state.level - THRESHOLD_MILD) * 0.02  -- up to 2.6x at level 100
end

-- Weather severity multiplier
function Anomaly.getWeatherMult()
    if state.level < THRESHOLD_MODERATE then return 1.0 end
    return 1.0 + (state.level - THRESHOLD_MODERATE) * 0.01  -- up to 1.6x
end

-- Eldritch mutation risk multiplier
function Anomaly.getMutationMult()
    if state.level < THRESHOLD_MILD then return 1.0 end
    return 1.0 + (state.level - THRESHOLD_MILD) * 0.015  -- up to 2.2x
end

-- Temperature instability (random temp swings)
function Anomaly.getTempInstability()
    if state.level < THRESHOLD_SEVERE then return 0 end
    return (state.level - THRESHOLD_SEVERE) * 0.5  -- up to 20 degrees swing
end

---------------------------------------------------------------------------
-- Anomaly events — triggered by storyteller based on level
---------------------------------------------------------------------------

function Anomaly.rollAnomalyEvent()
    if state.bossDefeated then return nil end
    if (GameState.day or 0) - state.lastEventDay < EVENT_COOLDOWN_DAYS then return nil end

    local tier = Anomaly.getTier()
    if tier == 'none' then return nil end

    local events = {}

    if tier == 'mild' then
        events = { 'strange_signal', 'ice_tremor', 'wildlife_agitation' }
    elseif tier == 'moderate' then
        events = { 'strange_signal', 'ice_tremor', 'wildlife_agitation',
                   'eldritch_spawn', 'precursor_ruin_emergence' }
    elseif tier == 'severe' then
        events = { 'eldritch_spawn', 'precursor_ruin_emergence',
                   'reality_tear', 'anomalous_weather' }
    elseif tier == 'critical' then
        events = { 'reality_tear', 'anomalous_weather', 'eldritch_swarm',
                   'boss_stir' }
    end

    if #events == 0 then return nil end

    -- 15% chance per check to fire an anomaly event
    if math.random() > 0.15 then return nil end

    state.lastEventDay = GameState.day or 0
    return events[math.random(#events)]
end

---------------------------------------------------------------------------
-- Step
---------------------------------------------------------------------------

local dayTracker = 0

function Anomaly.step(dt)
    -- Daily decay
    local currentDay = GameState.day or 0
    if currentDay > dayTracker then
        dayTracker = currentDay

        if not state.bossDefeated and state.level > 0 then
            state.level = math.max(0, state.level - DAILY_DECAY)
        end

        -- Check if boss should auto-awaken at critical threshold
        if Anomaly.canAwakenBoss() and state.totalAccumulated >= 200 then
            -- Boss awakens automatically once enough anomaly has accumulated
            Anomaly.awakenBoss()
        end
    end

    -- Check if spawned boss is dead
    if state.bossAwakened and state.bossEntityId then
        local creature = ECS.get(state.bossEntityId, 'creature')
        if creature and creature.state == 'dead' then
            Anomaly.onBossDefeated()
        elseif not ECS.get(state.bossEntityId, 'pos') then
            -- Entity was destroyed/removed
            Anomaly.onBossDefeated()
        end
    end
end

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

function Anomaly.getState()
    return {
        level            = state.level,
        totalAccumulated = state.totalAccumulated,
        bossAwakened     = state.bossAwakened,
        bossDefeated     = state.bossDefeated,
        extractionReady  = state.extractionReady,
        bossEntityId     = state.bossEntityId,
        lastEventDay     = state.lastEventDay,
        dayTracker       = dayTracker,
    }
end

function Anomaly.restoreState(saved)
    if not saved then return end
    state.level            = saved.level or 0
    state.totalAccumulated = saved.totalAccumulated or 0
    state.bossAwakened     = saved.bossAwakened or false
    state.bossDefeated     = saved.bossDefeated or false
    state.extractionReady  = saved.extractionReady or false
    -- Validate boss entity still exists before restoring reference
    local ECS = require('src.ecs.ecs')
    if saved.bossEntityId and ECS.isAlive(saved.bossEntityId) then
        state.bossEntityId = saved.bossEntityId
    else
        state.bossEntityId = nil
    end
    state.lastEventDay     = saved.lastEventDay or 0
    dayTracker             = saved.dayTracker or 0
end

return Anomaly
