-- test_framework.lua — Minimal test runner for FROSTHOLD
-- Provides assert helpers, test grouping, and summary reporting.

local T = {}

local suites = {}
local currentSuite = nil
local totalPassed = 0
local totalFailed = 0
local totalErrors = 0
local failures = {}

function T.suite(name)
    currentSuite = { name = name, tests = {}, passed = 0, failed = 0, errors = 0 }
    suites[#suites + 1] = currentSuite
end

function T.test(name, fn)
    if not currentSuite then T.suite('default') end
    local ok, err = pcall(fn)
    if ok then
        currentSuite.passed = currentSuite.passed + 1
        totalPassed = totalPassed + 1
    else
        if err and tostring(err):find('ASSERTION') then
            currentSuite.failed = currentSuite.failed + 1
            totalFailed = totalFailed + 1
            failures[#failures + 1] = {
                suite = currentSuite.name,
                test = name,
                err = tostring(err),
            }
            io.write('  FAIL: ' .. name .. '\n')
            io.write('    ' .. tostring(err) .. '\n')
        else
            currentSuite.errors = currentSuite.errors + 1
            totalErrors = totalErrors + 1
            failures[#failures + 1] = {
                suite = currentSuite.name,
                test = name,
                err = tostring(err),
            }
            io.write('  ERROR: ' .. name .. '\n')
            io.write('    ' .. tostring(err) .. '\n')
        end
    end
end

-- Assertion helpers
function T.eq(actual, expected, msg)
    if actual ~= expected then
        error('ASSERTION: ' .. (msg or '') .. ' expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

function T.neq(actual, notExpected, msg)
    if actual == notExpected then
        error('ASSERTION: ' .. (msg or '') .. ' expected not ' .. tostring(notExpected), 2)
    end
end

function T.ok(value, msg)
    if not value then
        error('ASSERTION: ' .. (msg or 'expected truthy value'), 2)
    end
end

function T.fail(msg)
    error('ASSERTION: ' .. (msg or 'explicit fail'), 2)
end

function T.gt(actual, threshold, msg)
    if not (actual > threshold) then
        error('ASSERTION: ' .. (msg or '') .. ' expected ' .. tostring(actual) .. ' > ' .. tostring(threshold), 2)
    end
end

function T.lt(actual, threshold, msg)
    if not (actual < threshold) then
        error('ASSERTION: ' .. (msg or '') .. ' expected ' .. tostring(actual) .. ' < ' .. tostring(threshold), 2)
    end
end

function T.gte(actual, threshold, msg)
    if not (actual >= threshold) then
        error('ASSERTION: ' .. (msg or '') .. ' expected ' .. tostring(actual) .. ' >= ' .. tostring(threshold), 2)
    end
end

function T.near(actual, expected, tolerance, msg)
    if math.abs(actual - expected) > (tolerance or 0.01) then
        error('ASSERTION: ' .. (msg or '') .. ' expected ~' .. tostring(expected) .. ' (±' .. tostring(tolerance) .. '), got ' .. tostring(actual), 2)
    end
end

function T.isnil(value, msg)
    if value ~= nil then
        error('ASSERTION: ' .. (msg or '') .. ' expected nil, got ' .. tostring(value), 2)
    end
end

function T.notnil(value, msg)
    if value == nil then
        error('ASSERTION: ' .. (msg or 'expected non-nil'), 2)
    end
end

function T.tablelen(tbl, expected, msg)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    if n ~= expected then
        error('ASSERTION: ' .. (msg or '') .. ' table length expected ' .. tostring(expected) .. ', got ' .. tostring(n), 2)
    end
end

function T.has_key(tbl, key, msg)
    if tbl[key] == nil then
        error('ASSERTION: ' .. (msg or '') .. ' table missing key: ' .. tostring(key), 2)
    end
end

-- Error-catching test helper
function T.throws(fn, msg)
    local ok, err = pcall(fn)
    if ok then
        error('ASSERTION: ' .. (msg or 'expected function to throw'), 2)
    end
end

function T.no_throw(fn, msg)
    local ok, err = pcall(fn)
    if not ok then
        error('ASSERTION: ' .. (msg or 'unexpected throw') .. ': ' .. tostring(err), 2)
    end
end

-- Summary
function T.summary()
    io.write('\n========================================\n')
    io.write('TEST RESULTS\n')
    io.write('========================================\n')
    for _, s in ipairs(suites) do
        local total = s.passed + s.failed + s.errors
        local status = (s.failed + s.errors) == 0 and 'PASS' or 'FAIL'
        io.write(string.format('  [%s] %s: %d/%d passed', status, s.name, s.passed, total))
        if s.failed > 0 then io.write(string.format(', %d failed', s.failed)) end
        if s.errors > 0 then io.write(string.format(', %d errors', s.errors)) end
        io.write('\n')
    end
    io.write('----------------------------------------\n')
    local total = totalPassed + totalFailed + totalErrors
    io.write(string.format('TOTAL: %d/%d passed, %d failed, %d errors\n', totalPassed, total, totalFailed, totalErrors))
    if #failures > 0 then
        io.write('\nFAILURE DETAILS:\n')
        for i, f in ipairs(failures) do
            io.write(string.format('  %d) [%s] %s\n     %s\n', i, f.suite, f.test, f.err))
        end
    end
    io.write('========================================\n')
    return totalFailed + totalErrors
end

-- Reset state between test files
function T.reset()
    suites = {}
    currentSuite = nil
    totalPassed = 0
    totalFailed = 0
    totalErrors = 0
    failures = {}
end

return T
