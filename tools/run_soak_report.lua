local root = arg and arg[0] and (arg[0]:match('(.-)tools[/\\]') or './') or './'
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path

if not love then
    pcall(require, 'tests.mock_love')
end

local Benchmark = require('src.util.benchmark')

local DEFAULT_BUDGETS = {
    averageFrameMs = 8.0,
    peakFrameMs = 20.0,
}

local function printSummary(report)
    local summary = report.summary or {}
    print(string.format('%s [%s]', report.name or 'unknown', summary.status or 'WARN'))
    print(string.format('  avg frame %.3fms | min %.3f | max %.3f | avg inner %.3f | avg day %.1f',
        summary.averageFrameMs or 0,
        summary.minFrameMs or 0,
        summary.maxFrameMs or 0,
        summary.averageInnerMs or 0,
        summary.averageDay or 0))

    if summary.hottest then
        print(string.format('  top hotspot %s (%d/%d runs)',
            summary.hottest.name or 'n/a',
            summary.hottest.count or 0,
            summary.iterations or 0))
    end

    local topCategories = summary.categoryList or {}
    for i = 1, math.min(3, #topCategories) do
        local entry = topCategories[i]
        print(string.format('  cat %-10s peak %.3fms', entry.key or 'n/a', entry.value or 0))
    end

    if #(summary.flags or {}) > 0 then
        for _, flag in ipairs(summary.flags) do
            print('  WARN ' .. flag)
        end
    end
end

local suite, err = Benchmark.runSuite({
    iterations = 8,
    budgets = DEFAULT_BUDGETS,
})

if not suite then
    io.stderr:write('soak suite failed: ' .. tostring(err) .. '\n')
    os.exit(1)
end

print(string.format('FROSTHOLD soak report [%s]', suite.status))
print(string.format('budgets: avg <= %.3fms, peak <= %.3fms', DEFAULT_BUDGETS.averageFrameMs, DEFAULT_BUDGETS.peakFrameMs))
print('')

for _, report in ipairs(suite.reports or {}) do
    printSummary(report)
    print('')
end

if suite.status ~= 'PASS' then
    os.exit(2)
end
