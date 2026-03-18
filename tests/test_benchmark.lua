require('tests.mock_love')

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Util: Benchmark')

local function reloadModule(name)
    package.loaded[name] = nil
    return require(name)
end

T.test('lists deterministic benchmark scenarios', function()
    H.resetAll()
    local Benchmark = reloadModule('src.util.benchmark')
    local names = Benchmark.getScenarioNames()

    T.eq(names[1], 'early_colony', 'scenario list is sorted')
    T.eq(names[2], 'late_colony_containment', 'late containment scenario present')
    T.eq(names[3], 'mid_colony_logistics', 'mid logistics scenario present')
end)

T.test('runs early colony benchmark and returns profiler output', function()
    H.resetAll()
    local Benchmark = reloadModule('src.util.benchmark')

    local result, err = Benchmark.runScenario('early_colony', { frames = 3, seed = 7 })
    T.notnil(result, 'benchmark run succeeds')
    T.isnil(err, 'no benchmark error returned')
    T.notnil(result.frame, 'frame summary returned')
    T.notnil(result.frame.hottest, 'hottest sample captured')
    T.ok(#result.entries > 0, 'sample entries recorded')
    T.eq(type(result.quotaSummary), 'string', 'quota summary returned')
end)

T.test('soak runs restore tuning overrides after execution', function()
    H.resetAll()
    local Tuning = reloadModule('src.sim.tuning')
    local Benchmark = reloadModule('src.util.benchmark')

    local soak, err = Benchmark.runSoak('late_colony_containment', {
        iterations = 2,
        frames = 3,
        tuningOverrides = {
            quotas = { cycle_length = 2 },
            raids = { warning_swarm = 40 },
        },
    })

    T.notnil(soak, 'soak run succeeds')
    T.isnil(err, 'no soak error returned')
    T.eq(soak.iterations, 2, 'iteration count preserved')
    T.eq(#soak.runs, 2, 'each soak run recorded')
    T.gte(soak.averageFrameMs, 0, 'average frame time reported')
    T.eq(Tuning.get('quotas.cycle_length'), 4, 'quota override restored after soak')
    T.eq(Tuning.get('raids.warning_swarm'), 120, 'raid override restored after soak')
end)

T.test('soak summary computes hotspots and warning flags', function()
    H.resetAll()
    local Benchmark = reloadModule('src.util.benchmark')

    local summary = Benchmark.summarizeSoak({
        name = 'sample',
        iterations = 2,
        averageFrameMs = 9.5,
        runs = {
            {
                day = 5,
                frame = {
                    frameMs = 11.0,
                    innerMs = 8.0,
                    hottest = { name = 'Raids:Pick', elapsedMs = 4.0 },
                },
                categories = {
                    { category = 'sim', maxMs = 6.5 },
                    { category = 'ai', maxMs = 2.1 },
                },
            },
            {
                day = 6,
                frame = {
                    frameMs = 7.0,
                    innerMs = 5.0,
                    hottest = { name = 'Raids:Pick', elapsedMs = 3.0 },
                },
                categories = {
                    { category = 'sim', maxMs = 5.5 },
                    { category = 'ui', maxMs = 1.2 },
                },
            },
        },
    }, {
        budgets = {
            averageFrameMs = 8.0,
            peakFrameMs = 10.0,
        },
    })

    T.eq(summary.status, 'WARN', 'summary warns when budgets are exceeded')
    T.eq(summary.hottest.name, 'Raids:Pick', 'top hotspot is counted')
    T.eq(summary.hottest.count, 2, 'hotspot count is aggregated')
    T.eq(summary.categoryList[1].key, 'sim', 'highest category peak sorts first')
    T.eq(#summary.flags, 2, 'average and peak budget warnings recorded')
end)

T.test('suite runner returns per-scenario summaries', function()
    H.resetAll()
    local Benchmark = reloadModule('src.util.benchmark')

    local suite, err = Benchmark.runSuite({
        scenarios = { 'early_colony', 'mid_colony_logistics' },
        iterations = 2,
        frames = 2,
        seed = 17,
        budgets = {
            averageFrameMs = 100,
            peakFrameMs = 100,
        },
    })

    T.notnil(suite, 'suite run succeeds')
    T.isnil(err, 'suite returns no error')
    T.eq(suite.status, 'PASS', 'suite passes with loose budgets')
    T.eq(#suite.reports, 2, 'suite returns both scenario reports')
    T.eq(suite.reports[1].name, 'early_colony', 'report preserves scenario order')
    T.notnil(suite.reports[1].summary.hottestList, 'summary is attached to each report')
end)
