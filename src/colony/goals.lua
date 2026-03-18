-- goals.lua -- Early-facing colony victory path progress
-- Exposes the four endgame routes as structured goal cards for UI.

local Goals = {}

local GOAL_DEFS = {
    {
        id = 'mammona_signal',
        title = 'Corporate Claim',
        desc = 'Prove the colony can hold and transmit clean claim data back to Mammona.',
        researchId = 'mammona_uplink',
        researchLabel = 'Mammona Uplink Protocol',
        buildingType = 'transmission_array',
        buildingLabel = 'Transmission Array',
    },
    {
        id = 'exodus',
        title = 'Exodus',
        desc = 'Build a launch pad and leave Erebus before the colony collapses.',
        researchId = 'shuttle_engineering',
        researchLabel = 'Shuttle Engineering',
        buildingType = 'launch_pad',
        buildingLabel = 'Launch Pad',
    },
    {
        id = 'seal_deep',
        title = 'Seal The Deep',
        desc = 'Reconstruct precursor sealing tech and shut the deeper system down.',
        researchId = 'precursor_sealing',
        researchLabel = 'Precursor Sealing Tech',
        buildingType = 'sealing_apparatus',
        buildingLabel = 'Sealing Apparatus',
    },
    {
        id = 'mammona_extraction',
        title = 'Mammona Extraction',
        desc = 'Defeat That Which Sleeps, then call Mammona for the full extraction ending.',
        researchId = 'mammona_extraction',
        researchLabel = 'Mammona Extraction Protocol',
        buildingType = 'extraction_beacon',
        buildingLabel = 'Extraction Beacon',
    },
}

local function safeRequire(path)
    local ok, mod = pcall(require, path)
    return ok and mod or nil
end

local function getCurrentResearchProgress(Research, researchId)
    if not Research or not Research.getCurrent then return 0 end
    local current = Research.getCurrent()
    if current ~= researchId or not Research.getProgressPercent then
        return 0
    end
    return Research.getProgressPercent()
end

local function getEndgameBuilding(Endgame, buildingType)
    if not Endgame or not Endgame.getBuildings then return nil end
    for _, info in ipairs(Endgame.getBuildings()) do
        if info.eg and info.eg.type == buildingType then
            return info
        end
    end
    return nil
end

local function getChargeProgress(Endgame, building)
    if not Endgame or not building or not Endgame.getChargePercent then return 0 end
    return math.max(0, math.min(1, (Endgame.getChargePercent(building.id) or 0) / 100))
end

local function pushStep(steps, done, label, progress)
    local stepProgress = progress
    if done and (stepProgress == nil or stepProgress <= 0) then
        stepProgress = 1
    elseif stepProgress == nil then
        stepProgress = done and 1 or 0
    end
    steps[#steps + 1] = {
        done = done == true,
        label = label,
        progress = math.max(0, math.min(1, stepProgress)),
    }
end

local function getStepSummary(steps)
    local completed = 0
    local progress = 0
    for _, step in ipairs(steps) do
        if step.done then
            completed = completed + 1
        end
        progress = progress + (step.progress or 0)
    end
    if #steps == 0 then
        return 0, 0
    end
    return completed, progress / #steps
end

local function buildGoal(def)
    local Research = safeRequire('src.research.research')
    local Endgame = safeRequire('src.sim.endgame')
    local Anomaly = safeRequire('src.sim.anomaly')

    local researchDone = Research and Research.isCompleted and Research.isCompleted(def.researchId) or false
    local canResearch = Research and Research.canResearch and Research.canResearch(def.researchId) or false
    local researchProgress = getCurrentResearchProgress(Research, def.researchId)
    local building = getEndgameBuilding(Endgame, def.buildingType)
    local phase = building and building.eg and building.eg.phase or 'idle'
    local chargeProgress = getChargeProgress(Endgame, building)
    local anomalyLevel = Anomaly and Anomaly.getLevel and Anomaly.getLevel() or 0
    local extractionReady = Anomaly and Anomaly.isExtractionReady and Anomaly.isExtractionReady() or false
    local bossAwake = Anomaly and Anomaly.isBossAwakened and Anomaly.isBossAwakened() or false

    local steps = {}
    pushStep(steps, researchDone, 'Complete ' .. def.researchLabel, researchProgress)
    pushStep(steps, building ~= nil, 'Build ' .. def.buildingLabel)

    if def.id == 'mammona_extraction' then
        local anomalyProgress = extractionReady and 1 or math.min(1, anomalyLevel / 80)
        local anomalyLabel = bossAwake
            and 'Defeat That Which Sleeps'
            or 'Disturb the deep until the anomaly reaches 80'
        pushStep(steps, extractionReady, anomalyLabel, anomalyProgress)
    end

    pushStep(steps,
        building ~= nil and phase ~= 'idle',
        'Start charging the structure',
        building and phase == 'charging' and chargeProgress or nil)
    pushStep(steps,
        building ~= nil and (phase == 'ready' or phase == 'activating' or phase == 'complete'),
        'Activate when ready',
        building and (phase == 'ready' or phase == 'activating' or phase == 'complete') and 1 or nil)

    local completedSteps, progress = getStepSummary(steps)
    local status
    if not researchDone then
        if researchProgress > 0 then
            status = string.format('Researching %s (%d%%)', def.researchLabel, math.floor(researchProgress * 100 + 0.5))
        elseif canResearch then
            status = 'Research available now'
        else
            status = 'Blocked by research prerequisites'
        end
    elseif not building then
        status = 'Research complete. Build ' .. def.buildingLabel
    elseif def.id == 'mammona_extraction' and not extractionReady then
        if bossAwake then
            status = 'That Which Sleeps is awake'
        else
            status = string.format('Anomaly %d/80', math.floor(anomalyLevel + 0.5))
        end
    elseif phase == 'charging' then
        status = string.format('Charging (%d%%)', math.floor(chargeProgress * 100 + 0.5))
    elseif phase == 'ready' then
        status = 'Ready to activate'
    elseif phase == 'activating' then
        status = 'Activation in progress'
    elseif phase == 'complete' then
        status = 'Completed'
    else
        status = 'Idle'
    end

    return {
        id = def.id,
        title = def.title,
        desc = def.desc,
        researchId = def.researchId,
        buildingType = def.buildingType,
        phase = phase,
        status = status,
        completedSteps = completedSteps,
        totalSteps = #steps,
        progress = progress,
        steps = steps,
    }
end

function Goals.getAll()
    local result = {}
    for _, def in ipairs(GOAL_DEFS) do
        result[#result + 1] = buildGoal(def)
    end
    return result
end

return Goals
