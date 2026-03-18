local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Easter Eggs')

local function initTilemap()
    local Tilemap = require('src.world.tilemap')
    Tilemap.init(128, 128)
    return Tilemap
end

local function initStory()
    local Storyteller = require('src.storyteller.storyteller')
    Storyteller.init('steady')
    return Storyteller
end

T.test('dream variance logs for exhausted stimulant-fueled night crew', function()
    H.resetAll()
    initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local Schedule = require('src.colonist.schedule')
    local ECS = require('src.ecs.ecs')

    local a = H.spawnTestColonist(10, 10, { rest = 20, name = 'Night One' })
    local b = H.spawnTestColonist(11, 10, { rest = 24, name = 'Night Two' })
    ECS.set(a, 'schedule', Schedule.nightShift())
    ECS.set(b, 'schedule', Schedule.nightShift())
    ECS.set(a, 'addictions', { spike = { activeEffect = 60 } })
    ECS.set(b, 'addictions', { stim = { activeEffect = 60 } })

    EasterEggs.init()
    EasterEggs.step(18)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'HERMES Audit: Dream Variance', 'dream variance event logged')
    T.ok(latest.message:find('dreaming') ~= nil, 'message keeps the intended tone')
end)

T.test('cargo cult conveyor logs after long unproductive belt line', function()
    H.resetAll()
    local Tilemap = initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local Conveyors = require('src.logistics.conveyors')

    Conveyors.init()
    for x = 10, 33 do
        Conveyors.place(x, 20, 'E')
        Tilemap.setTemp(x, 20, 0)
    end

    EasterEggs.init()
    EasterEggs.step(30)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'Logistics Note: Conveyor Devotion', 'conveyor easter egg logged')
    T.ok(latest.message:find('religion') ~= nil, 'message mentions the conveyor cult angle')
end)

T.test('scanner variance logs for low-sanity multi-drug colonist', function()
    H.resetAll()
    initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local ECS = require('src.ecs.ecs')

    local id = H.spawnTestColonist(12, 12, { morale = 25, name = 'Scramble Badge' })
    local col = ECS.get(id, 'colonist')
    col.sanity = 35
    ECS.set(id, 'addictions', {
        spike = { activeEffect = 60 },
        stim = { activeEffect = 60 },
    })

    EasterEggs.init()
    EasterEggs.step(10)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'HERMES Audit: Scanner Variance', 'scanner-inspired audit event logged')
    T.ok(latest.message:find('same person') ~= nil, 'message carries the identity-fracture angle')
end)

T.test('automation exception logs for frozen splitter network that still holds throughput', function()
    H.resetAll()
    local Tilemap = initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local Conveyors = require('src.logistics.conveyors')

    Conveyors.init()
    for x = 10, 23 do
        if x == 14 or x == 19 then
            Conveyors.placeSplitter(x, 30, 'E')
        else
            Conveyors.place(x, 30, 'E')
        end
        Tilemap.setTemp(x, 30, -25)
    end
    Conveyors.insertItem(10, 30, 'metal_ingot')

    EasterEggs.init()
    EasterEggs.step(20)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'Improvised Automation Exception', 'automation easter egg logged')
    T.ok(latest.message:find('efficient') ~= nil, 'message keeps the scuffed machine tone')
end)

T.test('continuity asset logs when safety net is consumed', function()
    H.resetAll()
    initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local GameState = require('src.game_state')

    EasterEggs.init()
    EasterEggs.step(0.1)
    GameState._safetyNetUsed = true
    EasterEggs.step(0.1)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'Crew Continuity Asset', 'safety-net follow-up logged')
    T.ok(latest.message:find('third crate') ~= nil, 'message implies the missing crate')
end)

T.test('sky geometry logs during severe anomaly aurora', function()
    H.resetAll()
    initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local Weather = require('src.weather.weather')
    local Anomaly = require('src.sim.anomaly')

    Weather.init()
    Weather.force('aurora', 120)
    Anomaly.restoreState({ level = 65 })

    EasterEggs.init()
    EasterEggs.step(12)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'Impossible Constellations', 'aurora anomaly event logged')
    T.ok(latest.message:find('aurora') ~= nil, 'message references the sky condition')
end)

T.test('autopsy addendum logs when both human and creature remains are present', function()
    H.resetAll()
    initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local GameState = require('src.game_state')

    GameState.resources.corpse_human = 1
    GameState.resources.corpse_creature = 1
    GameState.resources.organ_heart = 1

    EasterEggs.init()
    EasterEggs.step(0.1)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'Autopsy Addendum', 'corpse-mix autopsy note logged')
    T.ok(latest.message:find('wrong specimen') ~= nil, 'message nods to the horror setup')
end)

T.test('recovered tape logs when expedition recovery event appears', function()
    H.resetAll()
    initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')

    EasterEggs.init()
    Storyteller.logEvent('Expedition Recovery', 'Containment cargo returned.')
    EasterEggs.step(0.1)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'Recovered Tape 03', 'expedition recovery spawns contradictory tape')
    T.ok(latest.message:find('different doors') ~= nil, 'message describes conflicting testimony')
end)

T.test('corporate optics memo logs after a failed quota review', function()
    H.resetAll()
    initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local Quotas = require('src.sim.quotas')

    Quotas.restoreState({
        lastQuota = {
            processedDay = 3,
            dueDay = 3,
            target = { food = 4 },
            shipped = { food = 1 },
            ratio = 0.25,
            status = 'failed',
            responseMult = 0.35,
        },
    })

    EasterEggs.init()
    Storyteller.logEvent('Quota Review', 'Quota failed.')
    EasterEggs.step(0.1)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'Corporate Optics Memo', 'failed quota triggers spin memo')
    T.ok(latest.message:find('strategic reserve posture') ~= nil, 'message frames failure as corporate spin')
end)

T.test('manifest density exception logs for oversized food stock', function()
    H.resetAll()
    initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local GameState = require('src.game_state')

    GameState.resources.food = 260

    EasterEggs.init()
    EasterEggs.step(0.1)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'Manifest Density Exception', 'massive food pallet logs manifest anomaly')
    T.ok(latest.message:find('rations') ~= nil, 'message stays on the cargo-manifest theme')
end)

T.test('social containment logs during multi-colonist mental break', function()
    H.resetAll()
    initTilemap()
    local Storyteller = initStory()
    local EasterEggs = require('src.sim.easter_eggs')
    local ECS = require('src.ecs.ecs')

    local a = H.spawnTestColonist(40, 40, { morale = 12, name = 'Spiral One' })
    local b = H.spawnTestColonist(41, 40, { morale = 15, name = 'Spiral Two' })
    ECS.get(a, 'colonist').state = 'mental_break'
    ECS.get(b, 'colonist').state = 'mental_break'

    EasterEggs.init()
    EasterEggs.step(8)

    local latest = Storyteller.getLatestEvent()
    T.eq(latest.name, 'HERMES Advisory: Social Containment', 'mental break cluster logs social containment')
    T.ok(latest.message:find('additional walls') ~= nil, 'message keeps the dry HERMES tone')
end)

T.test('state restores triggered flags and timers', function()
    H.resetAll()
    initTilemap()
    initStory()
    local EasterEggs = require('src.sim.easter_eggs')

    EasterEggs.init()
    EasterEggs.restoreState({
        dreamVarianceTriggered = true,
        cargoCultTriggered = false,
        continuityAssetTriggered = true,
        skyGeometryTriggered = false,
        scannerVarianceTriggered = true,
        expeditionTapeTriggered = true,
        autopsyAddendumTriggered = true,
        automationExceptionTriggered = true,
        manifestDensityTriggered = true,
        socialContainmentTriggered = true,
        quotaSpinTriggered = true,
        dreamVarianceTimer = 9,
        cargoCultTimer = 17,
        skyGeometryTimer = 5,
        scannerVarianceTimer = 7,
        automationExceptionTimer = 13,
        socialContainmentTimer = 4,
        lastSafetyNetSeen = true,
        storyLogSeen = 12,
    })

    local saved = EasterEggs.getState()
    T.eq(saved.dreamVarianceTriggered, true, 'trigger flag restored')
    T.eq(saved.continuityAssetTriggered, true, 'continuity flag restored')
    T.eq(saved.scannerVarianceTriggered, true, 'scanner flag restored')
    T.eq(saved.quotaSpinTriggered, true, 'quota flag restored')
    T.eq(saved.dreamVarianceTimer, 9, 'dream timer restored')
    T.eq(saved.cargoCultTimer, 17, 'cargo timer restored')
    T.eq(saved.automationExceptionTimer, 13, 'automation timer restored')
    T.eq(saved.lastSafetyNetSeen, true, 'safety-net marker restored')
    T.eq(saved.storyLogSeen, 12, 'story-log cursor restored')
end)
