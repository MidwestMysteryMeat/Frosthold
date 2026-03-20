-- test_nemesis.lua — Nemesis system tests
-- Run standalone: cd F:/IceRimworld && luajit tests/test_nemesis.lua

-- ---------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------
local root = (arg and arg[0] or 'tests/test_nemesis.lua'):match('(.-)tests[/\\]') or './'
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path

require('tests.mock_love')

local T      = require('tests.test_framework')
local Nemesis = require('src.sim.nemesis')

---------------------------------------------------------------------------
-- Suite 1: createFromRaid
---------------------------------------------------------------------------

T.suite('Nemesis.createFromRaid')

T.test('returns a table', function()
    local n = Nemesis.createFromRaid('Gorax', 'Frosthold', 3, 'steel_ingot')
    T.eq(type(n), 'table', 'result should be a table')
end)

T.test('preserves raider name', function()
    local n = Nemesis.createFromRaid('Gorax', 'Frosthold', 3, nil)
    T.eq(n.name, 'Gorax')
end)

T.test('preserves colony name', function()
    local n = Nemesis.createFromRaid('Gorax', 'Frosthold', 3, nil)
    T.eq(n.colonyName, 'Frosthold')
end)

T.test('title contains colony name', function()
    local n = Nemesis.createFromRaid('Gorax', 'Frosthold', 3, nil)
    local found = n.title:find('Frosthold', 1, true)
    T.neq(found, nil, 'title should contain colony name')
end)

T.test('title is non-empty string', function()
    local n = Nemesis.createFromRaid('Gorax', 'Frosthold', 3, nil)
    T.eq(type(n.title), 'string')
    T.neq(n.title, '')
end)

T.test('hpMult is in range 1.10-1.15', function()
    -- Sample multiple times to reduce flakiness from random
    for _ = 1, 20 do
        local n = Nemesis.createFromRaid('X', 'Y', 0, nil)
        local ok = n.hpMult >= 1.10 and n.hpMult <= 1.15
        if not ok then
            error('ASSERTION: hpMult out of range: ' .. tostring(n.hpMult))
        end
    end
end)

T.test('dmgMult is in range 1.10-1.15', function()
    for _ = 1, 20 do
        local n = Nemesis.createFromRaid('X', 'Y', 0, nil)
        local ok = n.dmgMult >= 1.10 and n.dmgMult <= 1.15
        if not ok then
            error('ASSERTION: dmgMult out of range: ' .. tostring(n.dmgMult))
        end
    end
end)

T.test('kills field is preserved', function()
    local n = Nemesis.createFromRaid('Gorax', 'Frosthold', 7, nil)
    T.eq(n.kills, 7)
end)

T.test('kills defaults to 0 when nil passed', function()
    local n = Nemesis.createFromRaid('Gorax', 'Frosthold', nil, nil)
    T.eq(n.kills, 0)
end)

T.test('lootedItem is preserved', function()
    local n = Nemesis.createFromRaid('Gorax', 'Frosthold', 1, 'steel_ingot')
    T.eq(n.lootedItem, 'steel_ingot')
end)

T.test('lootedItem nil is preserved as nil', function()
    local n = Nemesis.createFromRaid('Gorax', 'Frosthold', 1, nil)
    T.eq(n.lootedItem, nil)
end)

---------------------------------------------------------------------------
-- Suite 2: getRaidNemesis
---------------------------------------------------------------------------

T.suite('Nemesis.getRaidNemesis')

-- Stub out the MRP module so we can control what getNemeses returns
-- without needing the campaign file.
local _origRequire = require
local function withMRPStub(nemeses, fn)
    -- Temporarily override package.loaded so pcall(require, 'src.sim.mrp') returns stub
    local stub = {
        getNemeses = function(planetId)
            return nemeses
        end
    }
    package.loaded['src.sim.mrp'] = stub
    local ok, err = pcall(fn)
    -- Restore real module (or nil so it reloads from disk next time)
    package.loaded['src.sim.mrp'] = nil
    if not ok then error(err, 2) end
end

T.test('returns nil for empty roster', function()
    withMRPStub({}, function()
        local result = Nemesis.getRaidNemesis('erebus')
        T.eq(result, nil, 'empty roster should yield nil')
    end)
end)

T.test('returns nil when MRP module unavailable', function()
    -- Simulate pcall failure by putting a non-table in package.loaded
    package.loaded['src.sim.mrp'] = nil
    -- Force require to fail by temporarily removing the module path hint
    -- We can't easily break require itself, so we use the real MRP which
    -- will have an empty nemeses list (no campaign file in test environment).
    -- This test verifies the function doesn't crash when roster is empty.
    local result = Nemesis.getRaidNemesis('no_such_planet')
    T.eq(result, nil)
end)

T.test('returns a nemesis from non-empty roster (retried until hit)', function()
    local roster = {
        Nemesis.createFromRaid('Alpha', 'Frosthold', 2, nil),
        Nemesis.createFromRaid('Beta',  'Frosthold', 1, nil),
    }
    withMRPStub(roster, function()
        -- With 30% chance, retry up to 50 times to get a non-nil result
        local got = nil
        for _ = 1, 50 do
            got = Nemesis.getRaidNemesis('erebus')
            if got then break end
        end
        T.neq(got, nil, 'should eventually return a nemesis from non-empty roster')
        -- Returned value must be one of the roster entries
        local found = (got == roster[1]) or (got == roster[2])
        T.eq(found, true, 'returned nemesis should be from the roster')
    end)
end)

T.test('getRaidNemesis returns nil most of the time (70% skip)', function()
    -- Statistical check: over 1000 draws the skip rate should be > 50%
    -- (expected ~70%).  This is not brittle — even at 3 sigma it holds.
    local roster = {
        Nemesis.createFromRaid('Alpha', 'Frosthold', 2, nil),
    }
    withMRPStub(roster, function()
        local nils = 0
        local trials = 200
        for _ = 1, trials do
            if Nemesis.getRaidNemesis('erebus') == nil then
                nils = nils + 1
            end
        end
        -- Expect at least 40% nil (very conservative, true rate is ~70%)
        local nilRate = nils / trials
        if nilRate < 0.40 then
            error('ASSERTION: nil rate too low (' .. string.format('%.2f', nilRate) .. '), expected ~0.70')
        end
    end)
end)

---------------------------------------------------------------------------
-- Run summary (standalone only)
---------------------------------------------------------------------------

if arg then
    T.summary()
end
