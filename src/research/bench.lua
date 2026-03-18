-- bench.lua — Research bench machine
-- Colonists assigned to a research bench generate research points based on
-- their research skill: (1 + skill * 0.5) points/s.
-- Points feed into the colony-wide Research module.
-- Completing a node fires a storyteller toast via Storyteller.logEvent.
-- Research benches draw 10W from the power grid.

local ECS        = require('src.ecs.ecs')
local Power      = require('src.sim.power')
local Research   = require('src.research.research')
local GameState  = require('src.game_state')

local Bench = {}

---------------------------------------------------------------------------
-- Machine definition
---------------------------------------------------------------------------

local BENCH_DEF = {
    name      = 'Research Bench',
    size      = { 2, 1 },
    cost      = { lumber = 10, metal_ingot = 5, glass = 2 },
    powerDraw = 10,
}

Bench.DEFINITION = BENCH_DEF

---------------------------------------------------------------------------
-- Placement
---------------------------------------------------------------------------

function Bench.place(x, y)
    local id = ECS.spawn()

    ECS.set(id, 'pos', { x = x, y = y })

    ECS.set(id, 'machine', {
        type       = 'research_bench',
        name       = BENCH_DEF.name,
        recipe     = nil,
        inputBuf   = {},
        outputBuf  = {},
        progress   = 0,
        active     = false,
        powered    = false,
        assignee   = nil,
    })

    ECS.set(id, 'research_bench', {
        pointsGenerated = 0,  -- lifetime points produced (stat tracking)
    })

    Power.addConsumer(id, BENCH_DEF.powerDraw, x, y)

    return id
end

function Bench.remove(entityId)
    Power.removeConsumer(entityId)
    ECS.destroy(entityId)
end

---------------------------------------------------------------------------
-- System — ticks each sim step
---------------------------------------------------------------------------

local function benchSystem(dt, id, comps)
    local machine = comps.machine
    local bench   = comps.research_bench

    -- Must be powered
    if not machine.powered then
        machine.active = false
        return
    end

    -- Must have a colonist assigned
    if not machine.assignee then
        machine.active = false
        return
    end

    -- Must have a research target selected
    local currentNode = Research.getCurrent()
    if not currentNode then
        machine.active = false
        return
    end

    -- Colonist must be alive
    local col = ECS.get(machine.assignee, 'colonist')
    if not col or col.state == 'dead' then
        machine.active = false
        return
    end

    machine.active = true

    -- Calculate research speed: base 1 + skill * 0.5
    local researchSkill = 1
    if col.skills and col.skills.research then
        researchSkill = col.skills.research
    end
    local pointsPerSec = 1 + researchSkill * 0.5

    -- Scholar mastery: research 25% faster
    local skOk, Skills = pcall(require, 'src.colonist.skills')
    if skOk and Skills.hasMastery(machine.assignee, 'scholar') then
        local eff = Skills.getMasteryEffect(machine.assignee, 'scholar')
        if eff and eff.researchMult then
            pointsPerSec = pointsPerSec * eff.researchMult
        end
    end

    -- Trait bonuses
    if col.traits then
        for _, t in ipairs(col.traits) do
            if t.researchMod then
                pointsPerSec = pointsPerSec * (1 + t.researchMod)
            end
        end
    end

    -- Faction ally research bonus (Rim Runners)
    local fok, Factions = pcall(require, 'src.colony.factions')
    if fok then
        pointsPerSec = pointsPerSec * (1 + Factions.getResearchBonus())
    end

    local points = pointsPerSec * dt
    bench.pointsGenerated = bench.pointsGenerated + points

    -- Feed points into colony research
    local done, finishedNode = Research.addPoints(points)

    -- Award research XP to assignee
    if skOk then Skills.addXp(machine.assignee, 'research', dt * 2) end

    if done and finishedNode then
        -- Innovator mastery: chance to skip research tier (apply retroactively)
        if skOk and Skills.hasMastery(machine.assignee, 'innovator') then
            local eff = Skills.getMasteryEffect(machine.assignee, 'innovator')
            if eff and eff.skipChance and math.random() < eff.skipChance then
                local nextNodeId = Research.getCurrent()
                if nextNodeId then
                    local nextNode = Research.getNode(nextNodeId)
                    Research.addPoints(nextNode and nextNode.cost or 999999)
                end
            end
        end

        -- Fire discovery event via storyteller log
        local Storyteller = require('src.storyteller.storyteller')
        local msg = string.format(
            'Research complete: %s - %s',
            finishedNode.name,
            finishedNode.desc
        )
        Storyteller.logEvent('Research Discovery', msg)

        -- Notify quest system
        local qok2, QuestMod = pcall(require, 'src.quest.quest')
        if qok2 and QuestMod.onResearchComplete then
            QuestMod.onResearchComplete(finishedNode.id)
        end

        -- Refresh build menu to show newly unlocked buildings
        local bmOk, BuildMenu = pcall(require, 'src.ui.build_menu')
        if bmOk and BuildMenu.onResearchComplete then
            BuildMenu.onResearchComplete()
        end
    end
end

function Bench.registerSystems()
    ECS.addSystem('research_bench', { 'machine', 'research_bench' }, benchSystem, 17)
end

Bench.registerSystems()

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Bench.getAll()
    local result = {}
    for id, comps in ECS.query('machine', 'research_bench', 'pos') do
        result[#result + 1] = {
            id      = id,
            pos     = comps.pos,
            machine = comps.machine,
            bench   = comps.research_bench,
        }
    end
    return result
end

function Bench.count()
    return ECS.countWith('research_bench')
end

function Bench.getTotalPointsGenerated()
    local total = 0
    for id, comps in ECS.query('research_bench') do
        total = total + comps.research_bench.pointsGenerated
    end
    return total
end

return Bench
