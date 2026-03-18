local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('World: History')

local function freshHistory()
    H.resetGameState()
    math.randomseed(12345)
    package.loaded['src.world.history'] = nil
    return require('src.world.history')
end

T.test('history init uses fixed Erebus canon and generates flavor layers', function()
    local History = freshHistory()
    History.init()

    local civ = History.getCivilization()
    local cat = History.getCataclysm()
    local timeline = History.getTimeline()
    local ruins = History.getRuins()
    local outposts = History.getOutposts()
    local cells = History.getMicroFactions()

    T.eq(civ.id, 'erebus_precursors', 'canon civilization should be fixed')
    T.eq(cat.id, 'erebus_shift', 'canon cataclysm should be fixed')
    T.gte(#timeline, 5, 'canon timeline should be populated')
    T.gte(#ruins, 4, 'procedural ruins should still exist')
    T.gte(#outposts, 3, 'failed outposts should still be generated')
    T.gte(#cells, 2, 'survivor-cell flavor should still be generated')
    T.ok(History.getSummary():find('living world', 1, true) ~= nil, 'summary should describe Erebus canon')
    math.randomseed(12345)
end)

T.test('legacy history state migrates to canon without losing ruins or outposts', function()
    local History = freshHistory()

    History.restoreState({
        civilization = { id = 'solari', name = 'The Solari Dominion', specialty = 'thermal' },
        cataclysm = { id = 'core_freeze', name = 'The Core Freeze' },
        timeline = { { year = -200, text = 'old random history entry' } },
        ruins = {
            {
                id = 'city_1',
                type = 'city',
                name = 'Buried City',
                loot = 'components',
                lootMin = 3,
                lootMax = 8,
                discovered = true,
                explored = false,
            },
        },
        outposts = {
            { name = 'Relay Post Needle', yearsAgo = 7, cause = 'went dark in a storm' },
        },
        microFactions = {
            { name = 'Legacy Survivors', size = 9, disposition = 'wary', specialty = 'salvaging', active = true },
        },
        relicsFound = {
            { name = 'Old Relic', from = 'Buried City', day = 2 },
        },
        yearsAgo = 600,
    })

    local civ = History.getCivilization()
    local cat = History.getCataclysm()
    local ruins = History.getRuins()
    local outposts = History.getOutposts()
    local cells = History.getMicroFactions()
    local relics = History.getRelicsFound()

    T.eq(civ.id, 'erebus_precursors', 'legacy saves should be migrated to fixed canon')
    T.eq(cat.id, 'erebus_shift', 'legacy cataclysm should be replaced with Erebus canon')
    T.eq(ruins[1].id, 'city_1', 'existing ruin records should be preserved')
    T.eq(ruins[1].discovered, true, 'ruin discovery state should survive migration')
    T.eq(outposts[1].name, 'Relay Post Needle', 'existing outpost flavor should survive migration')
    T.eq(cells[1].name, 'Legacy Survivors', 'existing survivor-cell flavor should survive migration')
    T.eq(relics[1].name, 'Old Relic', 'relic log should survive migration')
    T.ok(History.getSummary():find('Mammona', 1, true) ~= nil, 'summary should reflect the new fixed setting')
    math.randomseed(12345)
end)
