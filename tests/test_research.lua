-- test_research.lua -- Research tree system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Research')

local Research = require('src.research.research')
local ResearchPanel = require('src.ui.research_panel')

T.test('NODES table has research nodes across 5 tiers', function()
    Research.init()
    T.gte(Research.getTotalNodes(), 25, 'at least 25 nodes')

    for tier = 1, 5 do
        local nodes = Research.getNodesByTier(tier)
        T.ok(#nodes > 0, 'tier ' .. tier .. ' has at least one node')
    end
end)

T.test('all tier 1 nodes have no prerequisites', function()
    Research.init()
    local tier1 = Research.getNodesByTier(1)
    for _, node in ipairs(tier1) do
        T.eq(#node.prereqs, 0, node.id .. ' has no prereqs')
    end
end)

T.test('tier 1 nodes are available at game start', function()
    Research.init()
    local available = Research.getAvailable()
    T.ok(#available >= 5, 'at least 5 available at start')

    -- All should be tier 1
    for _, node in ipairs(available) do
        T.eq(node.tier, 1, node.id .. ' is tier 1')
    end
end)

T.test('setCurrent starts research and addPoints completes it', function()
    Research.init()
    local ok = Research.setCurrent('basic_survival')
    T.ok(ok, 'setCurrent succeeds for tier 1 node')

    local cur, prog = Research.getCurrent()
    T.eq(cur, 'basic_survival', 'current is basic_survival')
    T.eq(prog, 0, 'progress starts at 0')

    -- Cost is 40 for basic_survival; add partial points
    local done = Research.addPoints(20)
    T.eq(done, false, 'not complete at 20/40')
    T.near(Research.getProgressPercent(), 0.5, 0.01, 'progress is 50%')

    -- Finish it
    local completed, node = Research.addPoints(25)
    T.ok(completed, 'research completes when points exceed cost')
    T.eq(node.id, 'basic_survival', 'completed node is correct')
    T.ok(Research.isCompleted('basic_survival'), 'node marked completed')

    -- Current should be cleared after completion
    local cur2, _ = Research.getCurrent()
    T.isnil(cur2, 'no active research after completion')
end)

T.test('cannot research node with unmet prerequisites', function()
    Research.init()
    -- advanced_materials requires basic_construction + basic_smelting
    T.eq(Research.canResearch('advanced_materials'), false, 'prereqs not met')
    T.eq(Research.setCurrent('advanced_materials'), false, 'setCurrent rejects locked node')
end)

T.test('completing prereqs unlocks dependent nodes', function()
    Research.init()

    -- Complete both prereqs for advanced_materials
    Research.setCurrent('basic_construction')
    Research.addPoints(999)
    Research.setCurrent('basic_smelting')
    Research.addPoints(999)

    T.ok(Research.isCompleted('basic_construction'), 'prereq 1 done')
    T.ok(Research.isCompleted('basic_smelting'), 'prereq 2 done')
    T.ok(Research.canResearch('advanced_materials'), 'dependent node now available')
end)

T.test('isRecipeUnlocked and isBuildingUnlocked reflect completion', function()
    Research.init()

    T.eq(Research.isRecipeUnlocked('smelt_ore'), false, 'recipe locked before research')
    T.eq(Research.isBuildingUnlocked('smelter'), false, 'building locked before research')

    Research.setCurrent('basic_smelting')
    Research.addPoints(999)

    T.ok(Research.isRecipeUnlocked('smelt_ore'), 'recipe unlocked after research')
    T.ok(Research.isBuildingUnlocked('smelter'), 'building unlocked after research')
end)

T.test('cancelCurrent resets progress without completing', function()
    Research.init()
    Research.setCurrent('basic_tools')
    Research.addPoints(30)

    Research.cancelCurrent()
    local cur, _ = Research.getCurrent()
    T.isnil(cur, 'no current after cancel')
    T.eq(Research.isCompleted('basic_tools'), false, 'node not completed')

    local prog, cost = Research.getProgress()
    T.eq(prog, 0, 'progress reset to 0')
end)

T.test('archived cut-content nodes are not researchable or shown', function()
    Research.init()

    T.eq(Research.canResearch('conditional_circuits'), false, 'archived circuits node is hidden')
    T.eq(Research.canResearch('vehicle_construction'), false, 'archived vehicle node is hidden')

    local tier3 = Research.getNodesByTier(3)
    local seen = {}
    for _, node in ipairs(tier3) do
        seen[node.id] = true
    end

    T.isnil(seen.conditional_circuits, 'circuits node omitted from tier list')
    T.isnil(seen.vehicle_construction, 'vehicle node omitted from tier list')
end)

T.test('research panel search uses filtered counts for scroll bounds', function()
    Research.init()

    if not ResearchPanel.isVisible() then ResearchPanel.toggle() end
    ResearchPanel.mousepressed(151, 11, 1)
    ResearchPanel.textinput('basic')

    local filtered = ResearchPanel.getFilteredNodeCount()
    T.gt(filtered, 0, 'search returns at least one node')
    T.lt(filtered, Research.getTotalNodes(), 'search narrows node count')
    T.lt(ResearchPanel.getMaxScrollY(), math.max(0, Research.getTotalNodes() * 62 - 400), 'scroll bound uses filtered nodes')

    ResearchPanel.toggle() -- close / reset
end)
