local root = arg and arg[0] and (arg[0]:match('(.-)tools[/\\]') or './') or './'
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path

if not love then
    pcall(require, 'tests.mock_love')
end

local Benchmark = require('src.util.benchmark')

local function printScenario(result)
    local frame = result.frame or {}
    local hottest = frame.hottest and string.format('%s %.3fms', frame.hottest.name, frame.hottest.elapsedMs or 0) or 'n/a'
    print(string.format('%s | frame %.3fms | inner %.3fms | hottest %s', result.name, frame.frameMs or 0, frame.innerMs or 0, hottest))
    print('  ' .. (result.quotaSummary or 'No quota summary'))
    if (result.subjectInterest or 0) > 0 then
        print(string.format('  containment interest %d', result.subjectInterest))
    end
    for _, cat in ipairs(result.categories or {}) do
        print(string.format('  cat %-7s avg %.3f total %.3f entries %d', cat.category, cat.avgMs or 0, cat.totalMs or 0, cat.entries or 0))
    end
end

for _, name in ipairs(Benchmark.getScenarioNames()) do
    local result, err = Benchmark.runScenario(name)
    if not result then
        io.stderr:write(name .. ': ' .. tostring(err) .. '\n')
    else
        printScenario(result)
        local soak = assert(Benchmark.runSoak(name, { iterations = 5 }))
        print(string.format('  soak average %.3fms across %d runs', soak.averageFrameMs or 0, soak.iterations or 0))
    end
end
