local Profiler = {}

local enabled = false
local samples = {}
local registrations = {}
local budgets = {}
local historyLimit = 90
local FRAME_ROOT_NAME = 'Sim Tick'
local lastFrameSummary = nil
local currentFrame = {
    totalMs = 0,
    sampleTotals = {},
    categoryTotals = {},
    overBudget = {},
}

local unpackFn = table.unpack or unpack

local function pack(...)
    return { n = select('#', ...), ... }
end

local function now()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

local function shallowCopy(src)
    local out = {}
    if not src then return out end
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

local function listCopy(src)
    local out = {}
    if not src then return out end
    for i = 1, #src do
        out[i] = src[i]
    end
    return out
end

local function inferCategory(name)
    local reg = registrations[name]
    if reg and reg.category then return reg.category end

    local lname = (name or ''):lower()
    if lname:find('render', 1, true) or lname:find('particles', 1, true) or lname:find('overlay', 1, true) then
        return 'render'
    end
    if lname:find('ui', 1, true) or lname:find('hud', 1, true) or lname:find('panel', 1, true)
        or lname:find('menu', 1, true) or lname:find('minimap', 1, true) then
        return 'ui'
    end
    if lname:find('raid', 1, true) or lname:find('director', 1, true) or lname:find('story', 1, true)
        or lname:find('quest', 1, true) or lname:find('advisor', 1, true) or lname:find('recruit', 1, true)
        or lname:find('social', 1, true) or lname:find('colonist', 1, true) or lname:find('strange moods', 1, true) then
        return 'ai'
    end
    if lname:find('ordnance', 1, true) or lname:find('fire', 1, true) or lname:find('wound', 1, true)
        or lname:find('weapon', 1, true) or lname:find('combat', 1, true) or lname:find('trap', 1, true)
        or lname:find('defense', 1, true) then
        return 'combat'
    end
    if lname:find('conveyor', 1, true) or lname:find('pipe', 1, true) or lname:find('item', 1, true)
        or lname:find('production', 1, true) or lname:find('merchant', 1, true) or lname:find('trade', 1, true)
        or lname:find('research', 1, true) or lname:find('building', 1, true) then
        return 'economy'
    end
    if lname:find('weather', 1, true) or lname:find('thermal', 1, true) or lname:find('power', 1, true)
        or lname:find('atmosphere', 1, true) or lname:find('lighting', 1, true) or lname:find('visibility', 1, true)
        or lname:find('room', 1, true) or lname:find('containment', 1, true) or lname:find('hermes', 1, true)
        or lname:find('quota', 1, true) or lname:find('pollution', 1, true) or lname:find('radiation', 1, true)
        or lname:find('fluid', 1, true) or lname:find('gas', 1, true) or lname:find('snow', 1, true)
        or lname:find('flood', 1, true) or lname:find('struct', 1, true) or lname:find('cavern', 1, true)
        or lname:find('biocaves', 1, true) or lname:find('season', 1, true) then
        return 'world'
    end
    return 'sim'
end

local function getBudget(name)
    local reg = registrations[name]
    if reg and reg.budgetMs ~= nil then return reg.budgetMs end
    return budgets[name]
end

local function trimHistory(history)
    while #history > historyLimit do
        table.remove(history, 1)
    end
end

local function ensureSample(name)
    local sample = samples[name]
    if sample then return sample end
    sample = {
        name = name,
        calls = 0,
        totalMs = 0,
        lastMs = 0,
        avgMs = 0,
        maxMs = 0,
        category = inferCategory(name),
        budgetMs = getBudget(name),
        overBudget = false,
        history = {},
    }
    samples[name] = sample
    return sample
end

local function record(name, elapsedMs)
    local sample = ensureSample(name)
    sample.calls = sample.calls + 1
    sample.totalMs = sample.totalMs + elapsedMs
    sample.lastMs = elapsedMs
    sample.maxMs = math.max(sample.maxMs, elapsedMs)
    sample.category = inferCategory(name)
    sample.budgetMs = getBudget(name)
    sample.overBudget = sample.budgetMs ~= nil and elapsedMs > sample.budgetMs
    if sample.calls == 1 then
        sample.avgMs = elapsedMs
    else
        sample.avgMs = sample.avgMs * 0.85 + elapsedMs * 0.15
    end
    sample.history[#sample.history + 1] = elapsedMs
    trimHistory(sample.history)

    if name ~= FRAME_ROOT_NAME then
        currentFrame.totalMs = currentFrame.totalMs + elapsedMs
        currentFrame.sampleTotals[name] = (currentFrame.sampleTotals[name] or 0) + elapsedMs
        currentFrame.categoryTotals[sample.category] = (currentFrame.categoryTotals[sample.category] or 0) + elapsedMs
        if sample.overBudget then
            currentFrame.overBudget[#currentFrame.overBudget + 1] = {
                name = name,
                elapsedMs = elapsedMs,
                budgetMs = sample.budgetMs,
            }
        end
    else
        local hottestName, hottestMs = nil, -1
        for sampleName, totalMs in pairs(currentFrame.sampleTotals) do
            if totalMs > hottestMs then
                hottestName = sampleName
                hottestMs = totalMs
            end
        end
        lastFrameSummary = {
            frameName = name,
            frameMs = elapsedMs,
            innerMs = currentFrame.totalMs,
            sampleTotals = shallowCopy(currentFrame.sampleTotals),
            categoryTotals = shallowCopy(currentFrame.categoryTotals),
            overBudget = listCopy(currentFrame.overBudget),
            hottest = hottestName and { name = hottestName, elapsedMs = hottestMs } or nil,
        }
        currentFrame.totalMs = 0
        currentFrame.sampleTotals = {}
        currentFrame.categoryTotals = {}
        currentFrame.overBudget = {}
    end
end

function Profiler.setEnabled(value)
    enabled = value == true
end

function Profiler.isEnabled()
    return enabled
end

function Profiler.toggle()
    enabled = not enabled
    return enabled
end

function Profiler.reset()
    samples = {}
    lastFrameSummary = nil
    currentFrame = {
        totalMs = 0,
        sampleTotals = {},
        categoryTotals = {},
        overBudget = {},
    }
end

function Profiler.setHistoryLimit(limit)
    historyLimit = math.max(10, math.floor(limit or historyLimit))
    for _, sample in pairs(samples) do
        trimHistory(sample.history)
    end
end

function Profiler.register(name, opts)
    if not name then return end
    registrations[name] = {
        category = opts and opts.category or nil,
        budgetMs = opts and opts.budgetMs or nil,
    }
    local sample = samples[name]
    if sample then
        sample.category = inferCategory(name)
        sample.budgetMs = getBudget(name)
    end
end

function Profiler.setBudget(name, ms)
    if not name then return end
    budgets[name] = ms
    local sample = samples[name]
    if sample then
        sample.budgetMs = ms
        sample.overBudget = ms ~= nil and sample.lastMs > ms
    end
end

function Profiler.begin(name)
    if not enabled then return nil end
    return { name = name, startedAt = now() }
end

function Profiler.finish(token)
    if not token then return 0 end
    local elapsedMs = (now() - token.startedAt) * 1000
    record(token.name, elapsedMs)
    return elapsedMs
end

function Profiler.call(name, fn, ...)
    if type(fn) ~= 'function' then return nil end
    if not enabled then
        return fn(...)
    end
    local token = Profiler.begin(name)
    local results = pack(fn(...))
    Profiler.finish(token)
    return unpackFn(results, 1, results.n)
end

function Profiler.getEntries()
    local entries = {}
    for _, sample in pairs(samples) do
        entries[#entries + 1] = {
            name = sample.name,
            calls = sample.calls,
            totalMs = sample.totalMs,
            lastMs = sample.lastMs,
            avgMs = sample.avgMs,
            maxMs = sample.maxMs,
            category = sample.category,
            budgetMs = sample.budgetMs,
            overBudget = sample.overBudget,
        }
    end
    table.sort(entries, function(a, b)
        if a.avgMs == b.avgMs then
            return a.name < b.name
        end
        return a.avgMs > b.avgMs
    end)
    return entries
end

function Profiler.getEntry(name)
    local sample = samples[name]
    if not sample then return nil end
    return {
        name = sample.name,
        calls = sample.calls,
        totalMs = sample.totalMs,
        lastMs = sample.lastMs,
        avgMs = sample.avgMs,
        maxMs = sample.maxMs,
        category = sample.category,
        budgetMs = sample.budgetMs,
        overBudget = sample.overBudget,
    }
end

function Profiler.getHistory(name)
    local sample = samples[name]
    if not sample then return {} end
    return listCopy(sample.history)
end

function Profiler.getCategorySummaries()
    local buckets = {}
    for _, sample in pairs(samples) do
        local category = sample.category or 'sim'
        local bucket = buckets[category]
        if not bucket then
            bucket = {
                category = category,
                calls = 0,
                totalMs = 0,
                avgMs = 0,
                maxMs = 0,
                entries = 0,
            }
            buckets[category] = bucket
        end
        bucket.calls = bucket.calls + sample.calls
        bucket.totalMs = bucket.totalMs + sample.totalMs
        bucket.avgMs = bucket.avgMs + sample.avgMs
        bucket.maxMs = math.max(bucket.maxMs, sample.maxMs)
        bucket.entries = bucket.entries + 1
    end

    local summaries = {}
    for _, bucket in pairs(buckets) do
        summaries[#summaries + 1] = {
            category = bucket.category,
            calls = bucket.calls,
            totalMs = bucket.totalMs,
            avgMs = bucket.entries > 0 and (bucket.avgMs / bucket.entries) or 0,
            maxMs = bucket.maxMs,
            entries = bucket.entries,
        }
    end

    table.sort(summaries, function(a, b)
        if a.avgMs == b.avgMs then
            return a.category < b.category
        end
        return a.avgMs > b.avgMs
    end)
    return summaries
end

function Profiler.getFrameSummary()
    if not lastFrameSummary then return nil end
    return {
        frameName = lastFrameSummary.frameName,
        frameMs = lastFrameSummary.frameMs,
        innerMs = lastFrameSummary.innerMs,
        sampleTotals = shallowCopy(lastFrameSummary.sampleTotals),
        categoryTotals = shallowCopy(lastFrameSummary.categoryTotals),
        overBudget = listCopy(lastFrameSummary.overBudget),
        hottest = lastFrameSummary.hottest and {
            name = lastFrameSummary.hottest.name,
            elapsedMs = lastFrameSummary.hottest.elapsedMs,
        } or nil,
    }
end

return Profiler
