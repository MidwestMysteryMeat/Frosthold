local Tuning = {}

local DEFAULTS = {
    elastic = {
        smoothing_alpha = 0.15,
        history_window = 20,
        tick_interval = 5.0,
        trend_delta = 0.08,
        damage_decay = 0.85,
        death_decay = 0.05,
        food_low_penalty = 0.1,
        active_raid_penalty = 0.15,
    },
    weather = {
        harshness_min = 0.5,
        harshness_max = 2.0,
        severe_bias_per_harshness = 0.9,
        severe_suppression_per_harshness = 1.0,
        calm_suppression_per_harshness = 0.55,
        calm_bias_per_harshness = 0.8,
        lightning_interval_min = 8,
        lightning_interval_max = 25,
        transition_rate = 0.1,
        wind_angle_drift = 0.3,
        wind_speed_response = 0.05,
        napalm_rain_decay = 1.25,
        napalm_snow_decay = 1.35,
        napalm_severe_decay = 1.15,
        napalm_wind_decay = 0.18,
        cloud_rain_decay = 1.08,
        cloud_snow_decay = 1.12,
        cloud_severe_decay = 1.15,
        cloud_wind_decay = 0.35,
        fallout_rain_decay = 1.03,
        fallout_snow_decay = 1.06,
        fallout_severe_decay = 1.08,
        fallout_wind_decay = 0.12,
    },
    quotas = {
        cycle_length = 4,
        delivery_delay = 1,
    },
    raids = {
        budget_base = 30,
        budget_per_day = 2,
        budget_per_raid_survived = 5,
        heat_signature_divisor = 100,
        warning_base = 15,
        warning_swarm = 120,
        timeout_after_warning = 300,
        swarm_chance_scale = 1.0,
        thermovore_chance_scale = 1.0,
        containment_reclamation_chance = 0.34,
        pale_moon_chance = 0.2,
        coordinated_chance = 0.25,
        human_chance_scale = 1.0,
        fallback_activity_weight = 1.0,
        fallback_heat_weight = 1.0,
        fallback_wealth_weight = 1.0,
        fallback_depth_weight = 1.1,
        fallback_containment_weight = 1.35,
        fallback_humanoid_weight = 1.08,
        fallback_swarm_weight = 0.82,
    },
    ordnance = {
        hazard_step_interval = 0.5,
        default_fire_duration = 20,
        default_nuclear_fire_duration = 45,
        fallout_min_duration = 90,
        fallout_duration_mult = 3,
        fallout_base_dose = 0.04,
        fallout_dose_per_radius = 0.01,
    },
}

local overrides = {}

local function deepCopy(value)
    if type(value) ~= 'table' then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deepCopy(v)
    end
    return out
end

local function resolvePath(root, path)
    if not path or path == '' then
        return root
    end
    local cursor = root
    for part in tostring(path):gmatch('[^%.]+') do
        if type(cursor) ~= 'table' then
            return nil
        end
        cursor = cursor[part]
        if cursor == nil then
            return nil
        end
    end
    return cursor
end

local function setPath(root, path, value)
    local cursor = root
    local parts = {}
    for part in tostring(path):gmatch('[^%.]+') do
        parts[#parts + 1] = part
    end
    if #parts == 0 then
        return
    end
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(cursor[part]) ~= 'table' then
            cursor[part] = {}
        end
        cursor = cursor[part]
    end
    cursor[parts[#parts]] = deepCopy(value)
end

local function clearPath(root, path)
    local cursor = root
    local parts = {}
    for part in tostring(path):gmatch('[^%.]+') do
        parts[#parts + 1] = part
    end
    if #parts == 0 then
        return
    end
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(cursor[part]) ~= 'table' then
            return
        end
        cursor = cursor[part]
    end
    cursor[parts[#parts]] = nil
end

local function deepMerge(dst, src)
    for k, v in pairs(src or {}) do
        if type(v) == 'table' then
            local child = dst[k]
            if type(child) ~= 'table' then
                child = {}
                dst[k] = child
            end
            deepMerge(child, v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function applyRecursive(prefix, tbl)
    for k, v in pairs(tbl or {}) do
        local path = prefix and (prefix .. '.' .. k) or k
        if type(v) == 'table' then
            applyRecursive(path, v)
        else
            setPath(overrides, path, v)
        end
    end
end

function Tuning.get(path, fallback)
    local value = resolvePath(overrides, path)
    if value ~= nil then
        return deepCopy(value)
    end
    value = resolvePath(DEFAULTS, path)
    if value ~= nil then
        return deepCopy(value)
    end
    return fallback
end

function Tuning.getSection(path)
    local base = resolvePath(DEFAULTS, path)
    local merged = type(base) == 'table' and deepCopy(base) or {}
    local override = resolvePath(overrides, path)
    if type(override) == 'table' then
        deepMerge(merged, override)
    elseif override ~= nil then
        return override
    end
    return merged
end

function Tuning.setOverride(path, value)
    if not path or path == '' then return end
    setPath(overrides, path, value)
end

function Tuning.applyOverrides(tbl, prefix)
    if type(tbl) ~= 'table' then return end
    applyRecursive(prefix, tbl)
end

function Tuning.clearOverrides(path)
    if path and path ~= '' then
        clearPath(overrides, path)
        return
    end
    overrides = {}
end

function Tuning.getOverrides()
    return deepCopy(overrides)
end

function Tuning.replaceOverrides(tbl)
    overrides = deepCopy(tbl or {})
end

function Tuning.getDefaults()
    return deepCopy(DEFAULTS)
end

return Tuning
