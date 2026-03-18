local T = require('tests.test_framework')

T.suite('Util: Profiler')

local function reloadProfiler()
    package.loaded['src.util.profiler'] = nil
    return require('src.util.profiler')
end

T.test('records timed calls when enabled', function()
    local Profiler = reloadProfiler()
    Profiler.reset()
    Profiler.setEnabled(true)

    local value = Profiler.call('sample', function(a, b)
        return a + b
    end, 2, 3)

    T.eq(value, 5, 'call returns wrapped function result')
    local entry = Profiler.getEntry('sample')
    T.notnil(entry, 'sample entry recorded')
    T.eq(entry.calls, 1, 'one call recorded')
    T.gte(entry.lastMs, 0, 'timing captured')
end)

T.test('disabled profiler does not retain samples', function()
    local Profiler = reloadProfiler()
    Profiler.reset()
    Profiler.setEnabled(false)
    Profiler.call('disabled', function() return true end)
    T.isnil(Profiler.getEntry('disabled'), 'disabled capture does not record samples')
end)

T.test('retains rolling history, categories, and budgets', function()
    local Profiler = reloadProfiler()
    Profiler.reset()
    Profiler.setEnabled(true)
    Profiler.register('Budgeted', { category = 'ui', budgetMs = 0.0001 })

    Profiler.call('Budgeted', function()
        local sum = 0
        for i = 1, 50000 do
            sum = sum + i
        end
        return sum
    end)

    local entry = Profiler.getEntry('Budgeted')
    T.eq(entry.category, 'ui', 'registered category preserved')
    T.eq(entry.budgetMs, 0.0001, 'registered budget preserved')

    local history = Profiler.getHistory('Budgeted')
    T.eq(#history, 1, 'history recorded')
    T.gte(history[1], 0, 'history stores elapsed ms')
end)

T.test('captures last frame summary from sim tick root', function()
    local Profiler = reloadProfiler()
    Profiler.reset()
    Profiler.setEnabled(true)

    local token = Profiler.begin('Sim Tick')
    Profiler.call('Subsystem A', function() return true end)
    Profiler.call('Subsystem B', function() return true end)
    Profiler.finish(token)

    local frame = Profiler.getFrameSummary()
    T.notnil(frame, 'frame summary captured')
    T.notnil(frame.sampleTotals['Subsystem A'], 'subsystem total recorded')
    T.notnil(frame.sampleTotals['Subsystem B'], 'second subsystem total recorded')
    T.notnil(frame.hottest, 'hottest sample selected')

    local categories = Profiler.getCategorySummaries()
    T.ok(#categories > 0, 'category summaries returned')
end)
