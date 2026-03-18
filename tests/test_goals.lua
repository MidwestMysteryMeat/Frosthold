local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Colony Goals')

local function freshGoals()
    package.loaded['src.colony.goals'] = nil
    return require('src.colony.goals')
end

T.test('goals list exposes all four victory paths', function()
    H.resetAll()
    package.loaded['src.research.research'] = nil
    local Research = require('src.research.research')
    Research.init()

    local Goals = freshGoals()
    local all = Goals.getAll()
    local ids = {}
    for _, goal in ipairs(all) do ids[goal.id] = true end

    T.eq(#all, 4, 'four goal cards returned')
    T.ok(ids.mammona_signal, 'includes corporate claim')
    T.ok(ids.exodus, 'includes exodus')
    T.ok(ids.seal_deep, 'includes seal the deep')
    T.ok(ids.mammona_extraction, 'includes extraction')
end)

T.test('goal progress reflects research and endgame building state', function()
    H.resetAll()
    package.loaded['src.research.research'] = nil
    package.loaded['src.sim.endgame'] = nil

    local ECS = require('src.ecs.ecs')
    local Research = require('src.research.research')
    local Endgame = require('src.sim.endgame')
    Research.init()
    Research.complete('mammona_uplink')

    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = 12, y = 12, depth = 0 })
    ECS.set(id, 'endgame_building', {
        type = 'transmission_array',
        phase = 'charging',
        chargeProgress = Endgame.CHARGE_TIME * 0.5,
    })

    local Goals = freshGoals()
    local corporate
    for _, goal in ipairs(Goals.getAll()) do
        if goal.id == 'mammona_signal' then
            corporate = goal
            break
        end
    end

    T.notnil(corporate, 'corporate claim goal present')
    T.ok(corporate.progress > 0.5, 'goal progress moves past halfway once charging begins')
    T.eq(corporate.status, 'Charging (50%)', 'status reflects endgame charge progress')
end)
