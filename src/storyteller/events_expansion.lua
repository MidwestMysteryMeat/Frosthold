-- events_expansion.lua — Additional storyteller events
-- Social, peaceful, environmental, creature, and cult events.
-- Returns a table of event defs to merge into the main EVENTS table.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

local Events = {}

---------------------------------------------------------------------------
-- Social events
---------------------------------------------------------------------------

Events.colony_party = {
    name = 'Colony Party',
    type = 'colony',
    threatCost = -8,
    minDay = 10,
    execute = function()
        -- Requires 3+ colonists and some food to spare
        local count = 0
        for _ in ECS.query('colonist', 'needs') do count = count + 1 end
        if count < 3 then return nil end
        if (GameState.resources.food or 0) < 10 then return nil end

        local sOk, StorageNet = pcall(require, 'src.logistics.storage_network')
        if sOk then StorageNet.withdraw('food', 5, GameState.startX, GameState.startY)
        else GameState.spendResource('food', 5) end
        for id, comps in ECS.query('colonist', 'needs') do
            comps.needs.morale = math.min(100, comps.needs.morale + 10)
        end
        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then Hope.applyDelta(3, -2) end
        return 'The colonists throw a small gathering. Spirits lift.'
    end,
}

Events.wedding = {
    name = 'Wedding',
    type = 'colony',
    threatCost = -12,
    minDay = 20,
    execute = function()
        -- Find two colonists with high mutual opinion
        local sok, Social = pcall(require, 'src.colonist.social')
        if not sok then return nil end

        local colonists = {}
        for id, comps in ECS.query('colonist', 'needs') do
            if comps.colonist.state ~= 'dead' then
                colonists[#colonists + 1] = { id = id, col = comps.colonist }
            end
        end
        if #colonists < 2 then return nil end

        -- Find the pair with highest mutual opinion
        local bestPair, bestScore = nil, 60
        for i = 1, #colonists do
            for j = i + 1, #colonists do
                local a, b = colonists[i].id, colonists[j].id
                local ab = Social.getOpinion(a, b)
                local ba = Social.getOpinion(b, a)
                local mutual = math.min(ab, ba)
                if mutual > bestScore then
                    bestScore = mutual
                    bestPair = { colonists[i], colonists[j] }
                end
            end
        end
        if not bestPair then return nil end

        -- Boost morale colony-wide, extra boost for the couple
        for id, comps in ECS.query('colonist', 'needs') do
            comps.needs.morale = math.min(100, comps.needs.morale + 8)
        end
        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then Hope.applyDelta(5, -3) end

        -- Strengthen their bond
        Social.adjustOpinion(bestPair[1].id, bestPair[2].id, 20)
        Social.adjustOpinion(bestPair[2].id, bestPair[1].id, 20)

        local n1 = bestPair[1].col.name or 'A colonist'
        local n2 = bestPair[2].col.name or 'another colonist'
        return n1 .. ' and ' .. n2 .. ' hold a small ceremony. The colony celebrates.'
    end,
}

Events.funeral = {
    name = 'Memorial Service',
    type = 'colony',
    threatCost = -5,
    minDay = 8,
    execute = function()
        -- Only fires if someone has died recently (check hope state)
        local hok, Hope = pcall(require, 'src.colony.hope')
        if not hok then return nil end
        local hope = Hope.getHope()
        if hope > 40 then return nil end  -- only when morale is already low

        for id, comps in ECS.query('colonist', 'needs') do
            -- Small morale recovery from grieving together
            comps.needs.morale = math.min(100, comps.needs.morale + 5)
        end
        if hok then Hope.applyDelta(4, -2) end
        return 'The colony holds a quiet memorial. The grief is shared.'
    end,
}

Events.feast = {
    name = 'Colony Feast',
    type = 'colony',
    threatCost = -10,
    minDay = 15,
    execute = function()
        -- Requires significant food surplus
        local food = GameState.resources.food or 0
        if food < 30 then return nil end

        local sOk2, StorageNet2 = pcall(require, 'src.logistics.storage_network')
        if sOk2 then StorageNet2.withdraw('food', 15, GameState.startX, GameState.startY)
        else GameState.spendResource('food', 15) end
        for id, comps in ECS.query('colonist', 'needs') do
            comps.needs.morale = math.min(100, comps.needs.morale + 15)
            comps.needs.food = math.min(100, comps.needs.food + 30)
        end
        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then Hope.applyDelta(5, -3) end
        return 'A feast is prepared. Full stomachs and warm conversation lift the colony.'
    end,
}

---------------------------------------------------------------------------
-- Peaceful events
---------------------------------------------------------------------------

Events.art_inspiration = {
    name = 'Artistic Inspiration',
    type = 'colony',
    threatCost = -6,
    minDay = 12,
    execute = function()
        -- Pick a colonist with decent crafting skill, give them a quality boost on next craft
        local best, bestSkill = nil, 0
        for id, comps in ECS.query('colonist') do
            local col = comps.colonist
            if col.state ~= 'dead' and col.skills then
                local craft = col.skills.build or col.skills.cooking or 0
                if craft > bestSkill then
                    bestSkill = craft
                    best = { id = id, col = col }
                end
            end
        end
        if not best or bestSkill < 3 then return nil end

        -- Set an inspiration flag on the colonist (checked by production quality roll)
        local col = best.col
        col.inspired = true
        col.inspirationExpiry = GameState.day + 2  -- lasts 2 days

        local name = col.name or 'A colonist'
        return name .. ' feels a surge of creative energy. Next crafted item will be higher quality.'
    end,
}

Events.animal_self_tame = {
    name = 'Animal Self-Tame',
    type = 'colony',
    threatCost = -5,
    minDay = 6,
    execute = function()
        -- Find a wild creature near the colony and tame it
        local tok, Taming = pcall(require, 'src.creatures.taming')
        if not tok then return nil end

        local tameable = {}
        for id, comps in ECS.query('creature', 'pos') do
            local cr = comps.creature
            if cr and not cr.tamed and not cr.hostile then
                local pos = comps.pos
                local dx = pos.x - GameState.startX
                local dy = pos.y - GameState.startY
                if dx * dx + dy * dy < 30 * 30 then
                    tameable[#tameable + 1] = { id = id, creature = cr }
                end
            end
        end
        if #tameable == 0 then return nil end

        local pick = tameable[math.random(#tameable)]
        Taming.tame(pick.id)

        local species = pick.creature.species or 'creature'
        return 'A wild ' .. species .. ' wanders into the colony and refuses to leave. It seems tame.'
    end,
}

---------------------------------------------------------------------------
-- Environmental events
---------------------------------------------------------------------------

Events.meteor_strike = {
    name = 'Meteor Strike',
    type = 'colony',
    threatCost = 12,
    minDay = 10,
    execute = function()
        local World = require('src.world.tilemap')
        local Tiles = require('src.world.tiles')
        local w, h = World.width(), World.height()

        -- Pick a random surface location
        local x = math.random(10, w - 10)
        local y = math.random(10, h - 10)

        -- Deposit ore in a small radius
        for dx = -1, 1 do
            for dy = -1, 1 do
                local tx, ty = x + dx, y + dy
                if World.inBounds(tx, ty) then
                    local tile = World.getTile(tx, ty, 0)
                    if tile == Tiles.FLOOR or tile == Tiles.GROUND or tile == Tiles.SNOW then
                        World.setTile(tx, ty, 0, Tiles.ORE_VEIN)
                    end
                end
            end
        end

        -- Small resource bonus
        local Items = getItems()
        if Items then
            Items.spawn(x, y, 'metal', math.random(5, 12), nil, 0)
            Items.spawn(x, y, 'thermalCores', math.random(1, 3), nil, 0)
        else
            GameState.addResource('metal', math.random(5, 12))
            GameState.addResource('thermalCores', math.random(1, 3))
        end

        -- Shake camera
        local cok, Camera = pcall(require, 'src.render.camera')
        if cok and Camera.shake then Camera.shake(8) end

        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then Hope.applyDelta(-2, 2) end

        return 'A meteor crashes nearby! The impact leaves mineral deposits and thermal residue.'
    end,
}

Events.meltwater_surge = {
    name = 'Meltwater Surge',
    type = 'colony',
    threatCost = 15,
    minDay = 12,
    execute = function()
        -- Only during thaw season
        local sok, Seasons = pcall(require, 'src.world.seasons')
        if sok then
            local season = Seasons.getCurrentSeason()
            if season ~= 'thaw' then return nil end
        else
            return nil
        end

        -- Flood some ground tiles near rivers
        local World = require('src.world.tilemap')
        local Tiles = require('src.world.tiles')
        local w, h = World.width(), World.height()
        local flooded = 0

        for x = 1, w do
            for y = 1, h do
                local tile = World.getTile(x, y, 0)
                if tile == Tiles.WATER or tile == Tiles.FROZEN_RIVER then
                    -- Flood adjacent ground tiles
                    for dx = -1, 1 do
                        for dy = -1, 1 do
                            if (dx ~= 0 or dy ~= 0) and World.inBounds(x + dx, y + dy) then
                                local adj = World.getTile(x + dx, y + dy, 0)
                                if (adj == Tiles.GROUND or adj == Tiles.SNOW) and math.random() < 0.3 then
                                    World.setTile(x + dx, y + dy, 0, Tiles.WATER)
                                    flooded = flooded + 1
                                end
                            end
                        end
                    end
                end
                if flooded >= 15 then break end
            end
            if flooded >= 15 then break end
        end

        if flooded == 0 then return nil end

        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then Hope.applyDelta(-2, 2) end

        return 'Meltwater surges through the area. ' .. flooded .. ' tiles flooded.'
    end,
}

Events.toxic_fallout = {
    name = 'Toxic Fallout',
    type = 'colony',
    threatCost = 22,
    minDay = 18,
    execute = function()
        -- Set a toxic fallout flag on GameState for 2-4 days
        -- Outdoor colonists take slow health damage; crops take growth penalty
        GameState.toxicFallout = {
            active = true,
            endDay = GameState.day + math.random(2, 4),
        }

        for id, comps in ECS.query('colonist', 'needs') do
            comps.needs.morale = math.max(0, comps.needs.morale - 8)
        end
        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then Hope.applyDelta(-4, 4) end

        return 'A toxic cloud settles over the area. Stay indoors. Crops and outdoor work are dangerous.'
    end,
}

Events.volcanic_ash = {
    name = 'Volcanic Ash Cloud',
    type = 'colony',
    threatCost = 18,
    minDay = 15,
    execute = function()
        -- Ash cloud: reduces crop growth, lasts 1-3 days
        GameState.volcanicAsh = {
            active = true,
            endDay = GameState.day + math.random(1, 3),
        }

        for id, comps in ECS.query('colonist', 'needs') do
            comps.needs.morale = math.max(0, comps.needs.morale - 5)
        end
        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then Hope.applyDelta(-2, 2) end

        return 'Volcanic ash drifts across the sky. Crops grow slower and visibility drops.'
    end,
}

---------------------------------------------------------------------------
-- Creature events
---------------------------------------------------------------------------

Events.lurking_predator = {
    name = 'Lurking Predator',
    type = 'creature',
    threatCost = 18,
    minDay = 10,
    execute = function()
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if not cok then return nil end

        -- Spawn a high-tier predator near the colony edge
        local predators = { 'snow_ape', 'stalker', 'alpha_stalker' }
        local pick = predators[math.random(#predators)]
        local World = require('src.world.tilemap')
        local w, h = World.width(), World.height()

        -- Spawn at a distance from colony center
        local angle = math.random() * math.pi * 2
        local dist = math.random(20, 35)
        local sx = math.floor(GameState.startX + math.cos(angle) * dist)
        local sy = math.floor(GameState.startY + math.sin(angle) * dist)
        sx = math.max(2, math.min(w - 2, sx))
        sy = math.max(2, math.min(h - 2, sy))

        local id = Creatures.spawn(pick, sx, sy, 0)
        if not id then return nil end

        -- Make it hostile
        local cr = ECS.get(id, 'creature')
        if cr then cr.hostile = true end

        return 'Movement spotted at the colony perimeter. Something is watching.'
    end,
}

Events.hive_emergence = {
    name = 'Hive Emergence',
    type = 'creature',
    threatCost = 30,
    minDay = 20,
    execute = function()
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if not cok then return nil end

        local World = require('src.world.tilemap')
        local w, h = World.width(), World.height()

        -- Spawn a cluster of swarm creatures
        local swarmTypes = { 'frost_beetle', 'ice_locust', 'spawnling' }
        local pick = swarmTypes[math.random(#swarmTypes)]
        local count = math.random(4, 8)
        local angle = math.random() * math.pi * 2
        local dist = math.random(15, 30)
        local cx = math.floor(GameState.startX + math.cos(angle) * dist)
        local cy = math.floor(GameState.startY + math.sin(angle) * dist)

        local spawned = 0
        for i = 1, count do
            local sx = cx + math.random(-3, 3)
            local sy = cy + math.random(-3, 3)
            sx = math.max(2, math.min(w - 2, sx))
            sy = math.max(2, math.min(h - 2, sy))
            local id = Creatures.spawn(pick, sx, sy, 0)
            if id then
                local cr = ECS.get(id, 'creature')
                if cr then cr.hostile = true end
                spawned = spawned + 1
            end
        end

        if spawned == 0 then return nil end

        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then Hope.applyDelta(-3, 3) end

        local cok2, Camera = pcall(require, 'src.render.camera')
        if cok2 and Camera.shake then Camera.shake(5) end

        return 'The ground splits open. ' .. spawned .. ' creatures pour from a subterranean hive.'
    end,
}

---------------------------------------------------------------------------
-- Cult events
---------------------------------------------------------------------------

Events.possession = {
    name = 'Possession',
    type = 'colony',
    threatCost = 16,
    minDay = 18,
    execute = function()
        -- A colonist becomes temporarily possessed: erratic behavior, morale drop
        -- Prefer colonists with anomaly_sensitive or void_touched traits
        local candidates = {}
        local preferred = {}
        for id, comps in ECS.query('colonist', 'needs') do
            local col = comps.colonist
            if col.state ~= 'dead' then
                candidates[#candidates + 1] = { id = id, col = col, needs = comps.needs }
                if col.traits then
                    for _, t in ipairs(col.traits) do
                        if t.id == 'anomaly_sensitive' or t.id == 'void_touched' then
                            preferred[#preferred + 1] = { id = id, col = col, needs = comps.needs }
                        end
                    end
                end
            end
        end

        local pool = #preferred > 0 and preferred or candidates
        if #pool == 0 then return nil end

        local target = pool[math.random(#pool)]
        target.needs.morale = math.max(0, target.needs.morale - 20)
        target.col.possessed = {
            active = true,
            endDay = GameState.day + math.random(1, 2),
        }

        -- Nearby colonists get spooked
        for id, comps in ECS.query('colonist', 'needs') do
            if id ~= target.id then
                comps.needs.morale = math.max(0, comps.needs.morale - 5)
            end
        end

        local hok, Hope = pcall(require, 'src.colony.hope')
        if hok then Hope.applyDelta(-3, 3) end

        local name = target.col.name or 'A colonist'
        return name .. ' speaks in a voice that is not their own. Something has taken hold.'
    end,
}

---------------------------------------------------------------------------
-- Visitor events (Feature 29: Caravans & Visitors)
---------------------------------------------------------------------------

Events.diplomat_visit = {
    name = 'Diplomatic Visit',
    type = 'colony',
    threatCost = -8,
    minDay = 15,
    execute = function()
        local vok, Visitors = pcall(require, 'src.trade.visitors')
        if not vok then return nil end
        if Visitors.hasActiveVisitor('diplomat') then return nil end
        local id = Visitors.spawnDiplomat()
        if not id then return nil end
        return 'A faction diplomat has been spotted approaching the colony.'
    end,
}

Events.traveler_band = {
    name = 'Traveler Band',
    type = 'colony',
    threatCost = -5,
    minDay = 5,
    execute = function()
        local vok, Visitors = pcall(require, 'src.trade.visitors')
        if not vok then return nil end
        if Visitors.hasActiveVisitor('traveler') then return nil end
        local id = Visitors.spawnTravelers()
        if not id then return nil end
        return 'A small group of travelers is heading toward the colony.'
    end,
}

Events.hostile_scout_spotted = {
    name = 'Hostile Scout',
    type = 'creature',
    threatCost = 10,
    minDay = 12,
    execute = function()
        local vok, Visitors = pcall(require, 'src.trade.visitors')
        if not vok then return nil end
        if Visitors.hasActiveVisitor('hostile_scout') then return nil end
        local id = Visitors.spawnScout()
        if not id then return nil end
        return 'A lone figure is observed watching the colony from a distance. Kill them before they report back.'
    end,
}

Events.refugee_arrival = {
    name = 'Refugees at the Gate',
    type = 'colony',
    threatCost = -10,
    minDay = 8,
    execute = function()
        local vok, Visitors = pcall(require, 'src.trade.visitors')
        if not vok then return nil end
        if Visitors.hasActiveVisitor('refugee_group') then return nil end
        local id = Visitors.spawnRefugees()
        if not id then return nil end
        return 'A group of displaced survivors is approaching. They may be willing to stay.'
    end,
}

---------------------------------------------------------------------------
-- History-flavored events (Feature 30: Procedural History)
---------------------------------------------------------------------------

Events.history_rumor = {
    name = 'Old Stories',
    type = 'colony',
    threatCost = -3,
    minDay = 4,
    execute = function()
        local hok, Hist = pcall(require, 'src.world.history')
        if not hok then return nil end
        local fact = Hist.getRandomFact()
        if not fact then return nil end

        -- Small morale boost from shared knowledge
        for id, comps in ECS.query('colonist', 'needs') do
            comps.needs.morale = math.min(100, comps.needs.morale + 3)
        end

        return 'Someone digs up an old record: ' .. fact
    end,
}

Events.outpost_sighting = {
    name = 'Outpost Sighting',
    type = 'colony',
    threatCost = -4,
    minDay = 10,
    execute = function()
        local hok, Hist = pcall(require, 'src.world.history')
        if not hok then return nil end
        local outposts = Hist.getOutposts()
        if #outposts == 0 then return nil end
        local o = outposts[math.random(#outposts)]

        -- Small resource find from scouting the ruins
        local loot = ({ 'metal', 'components', 'fuel', 'wood' })[math.random(4)]
        local amount = math.random(2, 6)
        local Items = getItems()
        if Items then Items.spawn(GameState.startX, GameState.startY, loot, amount, nil, 0)
        else GameState.addResource(loot, amount) end

        return 'Scouts locate the remains of ' .. o.name .. '. Salvaged ' .. amount .. ' ' .. loot .. '.'
    end,
}

return Events
