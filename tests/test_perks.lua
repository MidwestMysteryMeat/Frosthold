-- test_perks.lua -- Perk pool regression tests

local T = require('tests.test_framework')

T.suite('Perks')

local Perks = require('src.colony.perks')

T.test('archived perks do not appear in generated choices', function()
    Perks.init()

    for i = 1, 10 do
        local choices = Perks.generateChoices(5)
        for _, perk in ipairs(choices) do
            T.neq(perk.id, 'vehicle_expert', 'archived vehicle perk hidden from choices')
        end
    end
end)
