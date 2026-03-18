-- megabeasts.lua — Procedural megabeast generation (Dwarf Fortress style)
-- Ancient creatures frozen in permafrost. Mining deep disturbs them.
-- Each is unique: random body material, attack type, name.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Creatures = require('src.creatures.creatures')
local Hope      = require('src.colony.hope')

local Megabeasts = {}

---------------------------------------------------------------------------
-- Generation tables
---------------------------------------------------------------------------

local BODY_MATERIALS = {
    { id = 'living_ice',    name = 'Living Ice',     damMult = 1.0, hpMult = 1.2, color = 'ice' },
    { id = 'obsidian',      name = 'Obsidian',       damMult = 1.3, hpMult = 1.5, color = 'black' },
    { id = 'frozen_gas',    name = 'Frozen Gas',     damMult = 0.8, hpMult = 0.9, color = 'blue' },
    { id = 'crystalized',   name = 'Crystal',        damMult = 1.1, hpMult = 1.0, color = 'purple' },
    { id = 'iron_flesh',    name = 'Iron Flesh',     damMult = 1.4, hpMult = 1.8, color = 'grey' },
    { id = 'volcanic_rock', name = 'Volcanic Stone', damMult = 1.2, hpMult = 2.0, color = 'red' },
    { id = 'bone_chitin',   name = 'Bone Chitin',    damMult = 1.1, hpMult = 1.6, color = 'white' },
    { id = 'void_matter',   name = 'Void Matter',    damMult = 1.5, hpMult = 1.3, color = 'void' },
    { id = 'permafrost',    name = 'Permafrost',     damMult = 0.9, hpMult = 2.5, color = 'frost' },
    { id = 'flesh_rot',     name = 'Rotting Flesh',  damMult = 1.2, hpMult = 0.7, color = 'green' },
}

local BODY_FORMS = {
    { id = 'serpent',    name = 'Serpent',    speedMult = 0.8, sizeMult = 1.5 },
    { id = 'spider',     name = 'Arachnid',  speedMult = 1.2, sizeMult = 1.0 },
    { id = 'titan',      name = 'Titan',      speedMult = 0.5, sizeMult = 2.0 },
    { id = 'swarm_host', name = 'Swarm Host', speedMult = 0.6, sizeMult = 1.3 },
    { id = 'crawler',    name = 'Crawler',    speedMult = 1.0, sizeMult = 1.2 },
    { id = 'leviathan',  name = 'Leviathan',  speedMult = 0.3, sizeMult = 3.0 },
    { id = 'giant',      name = 'Giant',      speedMult = 0.6, sizeMult = 2.5 },
    { id = 'stalker',    name = 'Stalker',    speedMult = 1.5, sizeMult = 1.1 },
    { id = 'colossus',   name = 'Colossus',   speedMult = 0.3, sizeMult = 3.5 },
    { id = 'wraith',     name = 'Wraith',     speedMult = 1.3, sizeMult = 0.9 },
}

local ATTACK_TYPES = {
    { id = 'frost_breath',   name = 'Frost Breath',   damBonus = 15, aoeRadius = 3, desc = 'breathes freezing fog' },
    { id = 'toxic_spores',   name = 'Toxic Spores',   damBonus = 10, aoeRadius = 4, desc = 'releases toxic spores' },
    { id = 'seismic_stomp',  name = 'Seismic Stomp',  damBonus = 25, aoeRadius = 2, desc = 'shakes the earth' },
    { id = 'acid_spray',     name = 'Acid Spray',     damBonus = 20, aoeRadius = 3, desc = 'sprays corrosive acid' },
    { id = 'void_howl',      name = 'Void Howl',      damBonus = 5,  aoeRadius = 6, desc = 'emits a maddening howl' },
    { id = 'ice_shards',     name = 'Ice Shards',     damBonus = 18, aoeRadius = 5, desc = 'hurls razor ice' },
    { id = 'nerve_rend',     name = 'Nerve Rend',     damBonus = 30, aoeRadius = 4, desc = 'area nerve damage' },
    { id = 'fear_scream',    name = 'Fear Scream',     damBonus = 8,  aoeRadius = 8, desc = 'high-volume fear effect' },
    { id = 'ground_devour',  name = 'Ground Devour',   damBonus = 22, aoeRadius = 3, desc = 'collapses terrain' },
    { id = 'blizzard_form',  name = 'Blizzard Form',   damBonus = 12, aoeRadius = 7, desc = 'generates localized blizzard' },
}

local NAME_PREFIXES = {
    'Cryo', 'Glacio', 'Perma', 'Null', 'Void', 'Abyssal', 'Stellar',
    'Shadow', 'Storm', 'Frost', 'Iron', 'Obsidian', 'Crystal', 'Dark',
    'Eldritch', 'Primordial', 'Cyclopean', 'Stygian', 'Chthonic',
    'Sightless', 'Nameless', 'Vast', 'Pallid', 'Fungal',
}

local NAME_SUFFIXES = {
    'maw', 'fang', 'claw', 'blight', 'terror', 'doom', 'wrath',
    'horror', 'dread', 'scourge', 'bane', 'fiend', 'howl', 'ruin',
    'spawn', 'thing', 'mass', 'hunger', 'voice', 'form', 'mind',
}

local TITLES = {
    'the Eternal', 'the Forgotten', 'the Ancient', 'the Devourer',
    'the Frozen', 'the Undying', 'the Awakened', 'the Hungering',
    'Worldbreaker', 'Icecrusher', 'Deathbringer', 'the Sleeper',
    'the Unnameable', 'That Which Waits', 'the Formless',
    'Born of Permafrost', 'the Last Dream', 'Who Remembers',
}

---------------------------------------------------------------------------
-- Procedural generation
---------------------------------------------------------------------------

local function generateName()
    local prefix = NAME_PREFIXES[math.random(#NAME_PREFIXES)]
    local suffix = NAME_SUFFIXES[math.random(#NAME_SUFFIXES)]
    local title  = TITLES[math.random(#TITLES)]
    return prefix .. suffix .. ' ' .. title
end

function Megabeasts.generate(difficulty)
    difficulty = difficulty or 1.0

    local material = BODY_MATERIALS[math.random(#BODY_MATERIALS)]
    local form     = BODY_FORMS[math.random(#BODY_FORMS)]
    local attack   = ATTACK_TYPES[math.random(#ATTACK_TYPES)]
    local name     = generateName()

    local baseHp  = 300 + GameState.day * 10
    local baseDmg = 20 + GameState.day * 2
    local baseSpd = 2

    local megabeast = {
        name      = name,
        fullTitle  = material.name .. ' ' .. form.name,
        material  = material,
        form      = form,
        attack    = attack,
        health    = math.floor(baseHp * material.hpMult * form.sizeMult * difficulty),
        damage    = math.floor(baseDmg * material.damMult * difficulty),
        speed     = baseSpd * form.speedMult,
        size      = 1.5 * form.sizeMult,
        aggroRange = 20,
        leashRange = 999,
        thermalCore = math.floor(30 * difficulty + 20),
        meat      = math.floor(20 * form.sizeMult),
        hostile   = true,
        isMegabeast = true,
    }

    return megabeast
end

---------------------------------------------------------------------------
-- Spawn a procedural megabeast on the map
---------------------------------------------------------------------------

function Megabeasts.spawn(x, y, difficulty, depth)
    depth = depth or 0
    local World = require('src.world.tilemap')
    if not World.isWalkable(x, y, depth) then
        -- Find nearby walkable tile
        local found = false
        for dx = -3, 3 do
            for dy = -3, 3 do
                if not found and World.inBounds(x + dx, y + dy) and World.isWalkable(x + dx, y + dy, depth) then
                    x, y = x + dx, y + dy
                    found = true
                end
            end
        end
        if not found then return nil end
    end

    local mega = Megabeasts.generate(difficulty)

    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth, prevX = x, prevY = y })
    ECS.set(id, 'creature', {
        species    = 'megabeast_proc',
        name       = mega.name,
        health     = mega.health,
        maxHealth  = mega.health,
        damage     = mega.damage,
        speed      = mega.speed,
        hostile    = mega.hostile,
        aggroRange = mega.aggroRange,
        leashRange = mega.leashRange,
        drops      = {
            thermalCore = mega.thermalCore,
            meat        = mega.meat,
        },
        isMegabeast = true,
        material    = mega.material.id,
        form        = mega.form.id,
        attackType  = mega.attack.id,
    })

    ECS.set(id, 'path', { nodes = nil, index = 1, moveTimer = 0 })
    ECS.set(id, 'boss', { isBoss = true, name = mega.name })

    Hope.applyDelta(-10, 10)

    local Storyteller = require('src.storyteller.storyteller')
    Storyteller.logEvent('MEGABEAST AWAKENED',
        mega.name .. ', a ' .. mega.fullTitle .. ' that ' ..
        mega.attack.desc .. '. Spotted near the colony.')

    return id, mega
end

---------------------------------------------------------------------------
-- Trigger conditions
---------------------------------------------------------------------------

-- Called when mining reaches certain depths or tile counts
local totalMined = 0
local MINE_THRESHOLD = 200  -- tiles mined before first megabeast
local MINE_INTERVAL  = 150  -- tiles between subsequent megabeasts

function Megabeasts.onTileMined()
    totalMined = totalMined + 1

    if totalMined < MINE_THRESHOLD then return end
    if (totalMined - MINE_THRESHOLD) % MINE_INTERVAL ~= 0 then return end

    -- Spawn near a random map edge
    local World = require('src.world.tilemap')
    local w, h = World.width(), World.height()
    local side = math.random(4)
    local sx, sy
    if side == 1 then     sx = 3;     sy = math.random(10, h - 10)
    elseif side == 2 then sx = w - 3; sy = math.random(10, h - 10)
    elseif side == 3 then sx = math.random(10, w - 10); sy = 3
    else                   sx = math.random(10, w - 10); sy = h - 3
    end

    local difficulty = 1.0 + (GameState.day / 30) * 0.5
    Megabeasts.spawn(sx, sy, difficulty)
end

function Megabeasts.getTotalMined()
    return totalMined
end

function Megabeasts.setTotalMined(n)
    totalMined = n or 0
end

function Megabeasts.init()
    totalMined = 0
end

return Megabeasts
