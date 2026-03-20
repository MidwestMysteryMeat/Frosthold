-- run_all.lua — Execute all FROSTHOLD test suites and report results.
-- Usage: luajit tests/run_all.lua   (from project root)

-- Set up package path for project root
local root = arg[0]:match('(.-)tests[/\\]') or './'
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path

-- Load Love2D mocks before anything else
require('tests.mock_love')

-- Load framework
local T = require('tests.test_framework')

-- Test suites in dependency order
local suites = {
    'tests.test_ecs',
    'tests.test_tiles',
    'tests.test_game_state',
    'tests.test_history',
    'tests.test_hermes',
    'tests.test_easter_eggs',
    'tests.test_profiler',
    'tests.test_tuning',
    'tests.test_benchmark',
    'tests.test_ui_hud',
    'tests.test_difficulty_axes',
    'tests.test_quotas',
    'tests.test_containment',
    'tests.test_schedule',
    'tests.test_jobs',
    'tests.test_zones',
    'tests.test_items',
    'tests.test_beds',
    'tests.test_colonist',
    'tests.test_pathfind',
    'tests.test_tile_flow',
    'tests.test_ordnance',
    'tests.test_weather',
    'tests.test_creatures',
    'tests.test_production',
    'tests.test_power',
    'tests.test_atmosphere',
    'tests.test_agriculture',
    'tests.test_rooms',
    'tests.test_body',
    'tests.test_wounds',
    'tests.test_equipment',
    'tests.test_hope',
    'tests.test_policies',
    'tests.test_doctrines',
    'tests.test_perks',
    'tests.test_conveyors',
    'tests.test_research',
    'tests.test_goals',
    'tests.test_merchants',
    'tests.test_expeditions',
    'tests.test_save',
    'tests.test_playthrough_smoke',
    'tests.test_raids',
    'tests.test_social_events',
    'tests.test_save_raids',
    'tests.test_mrp',
    'tests.test_nemesis',
}

io.write('FROSTHOLD Test Suite\n')
io.write('Running ' .. #suites .. ' test files...\n\n')

local loadErrors = {}

for _, name in ipairs(suites) do
    io.write('[' .. name .. ']\n')
    local ok, err = pcall(require, name)
    if not ok then
        io.write('  LOAD ERROR: ' .. tostring(err) .. '\n')
        loadErrors[#loadErrors + 1] = { name = name, err = tostring(err) }
    end
end

-- Print summary
local failCount = T.summary()

if #loadErrors > 0 then
    io.write('\nLOAD ERRORS (' .. #loadErrors .. '):\n')
    for i, le in ipairs(loadErrors) do
        io.write(string.format('  %d) %s\n     %s\n', i, le.name, le.err))
    end
end

local total = failCount + #loadErrors
if total > 0 then
    os.exit(1)
else
    io.write('\nAll tests passed!\n')
    os.exit(0)
end
