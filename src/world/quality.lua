-- quality.lua -- Item quality tier system
-- 8 tiers from awful to legendary. Crafter skill determines roll distribution.
-- Quality multiplies item stats (damage, armor, beauty, value, durability).
-- Legendary requires inspiration event or skill 17+.

local Quality = {}

---------------------------------------------------------------------------
-- Tier definitions
---------------------------------------------------------------------------

local TIERS = {
    { id = 'awful',      name = 'Awful',      index = 1, statMult = 0.50, beautyMult = 0.30, valueMult = 0.40, durMult = 0.50 },
    { id = 'shoddy',     name = 'Shoddy',     index = 2, statMult = 0.70, beautyMult = 0.50, valueMult = 0.60, durMult = 0.70 },
    { id = 'poor',       name = 'Poor',       index = 3, statMult = 0.85, beautyMult = 0.70, valueMult = 0.80, durMult = 0.85 },
    { id = 'normal',     name = 'Normal',     index = 4, statMult = 1.00, beautyMult = 1.00, valueMult = 1.00, durMult = 1.00 },
    { id = 'good',       name = 'Good',       index = 5, statMult = 1.15, beautyMult = 1.30, valueMult = 1.50, durMult = 1.20 },
    { id = 'excellent',  name = 'Excellent',  index = 6, statMult = 1.30, beautyMult = 1.80, valueMult = 2.50, durMult = 1.50 },
    { id = 'masterwork', name = 'Masterwork', index = 7, statMult = 1.50, beautyMult = 2.50, valueMult = 4.00, durMult = 2.00 },
    { id = 'legendary',  name = 'Legendary',  index = 8, statMult = 1.80, beautyMult = 4.00, valueMult = 8.00, durMult = 3.00 },
}

Quality.TIERS = TIERS

-- Lookup by id
local BY_ID = {}
for _, t in ipairs(TIERS) do BY_ID[t.id] = t end
Quality.BY_ID = BY_ID

---------------------------------------------------------------------------
-- Roll weights per skill bracket
---------------------------------------------------------------------------
-- Each row: {awful, shoddy, poor, normal, good, excellent, masterwork, legendary}
-- Bracket = floor((skill-1)/4)+1, clamped 1-5

local WEIGHTS = {
    { 30, 30, 25, 10,  5,  0,  0,  0 },  -- skill 1-4
    {  5, 10, 20, 30, 25,  8,  2,  0 },  -- skill 5-8
    {  0,  2,  5, 15, 30, 30, 15,  3 },  -- skill 9-12
    {  0,  0,  0,  5, 10, 25, 40, 20 },  -- skill 13-16
    {  0,  0,  0,  0,  5, 15, 35, 45 },  -- skill 17-20
}

---------------------------------------------------------------------------
-- Quality roll
---------------------------------------------------------------------------

--- Roll a quality tier for a crafted item.
--- @param skillLevel number Crafter's relevant skill (1-20)
--- @param passionLevel number 0=none, 1=interested, 2=passionate
--- @param hasInspiration boolean Guaranteed legendary if true
--- @return table Quality tier from TIERS
function Quality.roll(skillLevel, passionLevel, hasInspiration)
    if hasInspiration then return TIERS[8] end

    local bracket = math.min(5, math.floor((skillLevel - 1) / 4) + 1)
    local weights = WEIGHTS[bracket]

    -- Passion shifts weights toward higher tiers
    local adjusted = {}
    for i = 1, 8 do adjusted[i] = weights[i] end

    if passionLevel == 2 then
        -- Passionate: shift weight up by 1 tier
        for i = 8, 2, -1 do
            local shift = math.floor(adjusted[i - 1] * 0.15)
            adjusted[i] = adjusted[i] + shift
            adjusted[i - 1] = adjusted[i - 1] - shift
        end
    elseif passionLevel == 1 then
        -- Interested: smaller shift
        for i = 8, 2, -1 do
            local shift = math.floor(adjusted[i - 1] * 0.08)
            adjusted[i] = adjusted[i] + shift
            adjusted[i - 1] = adjusted[i - 1] - shift
        end
    end

    -- Legendary gate: only possible at skill 12+ (unless inspiration)
    if skillLevel < 12 then adjusted[8] = 0 end

    -- Weighted random selection
    local total = 0
    for i = 1, 8 do total = total + adjusted[i] end
    if total <= 0 then return TIERS[4] end

    local roll = math.random() * total
    local cumulative = 0
    for i = 1, 8 do
        cumulative = cumulative + adjusted[i]
        if roll <= cumulative then return TIERS[i] end
    end
    return TIERS[4] -- fallback: normal
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Get tier by id string
function Quality.get(qualityId)
    return BY_ID[qualityId] or TIERS[4]
end

--- Get tier by index (1-8)
function Quality.getByIndex(index)
    return TIERS[index] or TIERS[4]
end

function Quality.getRank(qualityId)
    local tier = BY_ID[qualityId]
    return tier and tier.index or TIERS[4].index
end

--- Get display color for quality tier (r, g, b)
function Quality.getColor(qualityId)
    local colors = {
        awful      = { 0.50, 0.35, 0.35 },
        shoddy     = { 0.60, 0.50, 0.40 },
        poor       = { 0.65, 0.60, 0.55 },
        normal     = { 0.75, 0.75, 0.75 },
        good       = { 0.40, 0.70, 0.40 },
        excellent  = { 0.30, 0.60, 0.90 },
        masterwork = { 0.70, 0.50, 0.90 },
        legendary  = { 0.95, 0.80, 0.20 },
    }
    return colors[qualityId] or colors.normal
end

--- Format item name with quality prefix
--- Normal quality returns name unchanged.
function Quality.formatName(baseName, qualityId)
    if qualityId == 'normal' then return baseName end
    local tier = BY_ID[qualityId]
    if not tier then return baseName end
    return tier.name .. ' ' .. baseName
end

--- Get stat multiplier for a quality tier
function Quality.getStatMult(qualityId)
    local tier = BY_ID[qualityId]
    return tier and tier.statMult or 1.0
end

--- Get beauty multiplier for a quality tier
function Quality.getBeautyMult(qualityId)
    local tier = BY_ID[qualityId]
    return tier and tier.beautyMult or 1.0
end

--- Get value multiplier for a quality tier
function Quality.getValueMult(qualityId)
    local tier = BY_ID[qualityId]
    return tier and tier.valueMult or 1.0
end

--- Get durability multiplier for a quality tier
function Quality.getDurMult(qualityId)
    local tier = BY_ID[qualityId]
    return tier and tier.durMult or 1.0
end

--- Categories of items that receive quality rolls
Quality.QUALITY_CATEGORIES = {
    equipment = true,
    weapon    = true,
    armor     = true,
    furniture = true,
    clothing  = true,
    art       = true,
}

--- Check if an item category should receive a quality roll
function Quality.appliesTo(category)
    return Quality.QUALITY_CATEGORIES[category] or false
end

return Quality
