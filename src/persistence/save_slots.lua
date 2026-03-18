local ECS = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Context = require('src.persistence.save_context')
local Helpers = require('src.persistence.save_helpers')

local function readManifest()
    if Context.manifest then
        return Context.manifest
    end

    local info = love.filesystem.getInfo(Context.MANIFEST_FILE)
    if info then
        local str = love.filesystem.read(Context.MANIFEST_FILE)
        if str then
            local data = Helpers.deserialize(str)
            if data then
                Context.manifest = data
                return Context.manifest
            end
        end
    end

    Context.manifest = {
        slots = {},
        settings = { autoSaveInterval = Context.DEFAULT_AUTO_INTERVAL },
        lastAutoSlot = 0,
        currentSlot = nil,
    }
    return Context.manifest
end

local function writeManifest()
    if not Context.manifest then
        return
    end
    Helpers.ensureSavesDir()
    local str = Helpers.serialize(Context.manifest)
    local ok, err = love.filesystem.write(Context.MANIFEST_FILE, str)
    if not ok then
        print('[Save] ERROR writing manifest: ' .. tostring(err))
    end
end

local function countLivingColonists()
    local n = 0
    for _, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' then
            n = n + 1
        end
    end
    return n
end

local function buildSlotMeta(displayName)
    return {
        name = displayName or ('Day ' .. GameState.day),
        colonyName = GameState.colonyName or 'Frosthold',
        day = GameState.day,
        colonists = countLivingColonists(),
        timestamp = os.time(),
    }
end

local function attach(Save)
    function Save.saveToSlot(slotId, displayName)
        local filename = Helpers.slotFilename(slotId)
        local ok = Save.save(filename)
        if ok then
            local manifest = readManifest()
            manifest.slots[slotId] = buildSlotMeta(displayName)
            if slotId:sub(1, 4) == 'slot' then
                manifest.currentSlot = slotId
                Context.currentSlot = slotId
            end
            writeManifest()
        end
        return ok
    end

    function Save.loadSlot(slotId)
        local filename = Helpers.slotFilename(slotId)
        local ok = Save.load(filename)
        if ok then
            local manifest = readManifest()
            if slotId:sub(1, 4) == 'slot' then
                manifest.currentSlot = slotId
                Context.currentSlot = slotId
            else
                manifest.currentSlot = nil
                Context.currentSlot = nil
            end
            writeManifest()
        end
        return ok
    end

    function Save.quickSave()
        local ok = Save.save(Context.QUICK_SAVE_FILE)
        if ok then
            local manifest = readManifest()
            manifest.slots.quick = buildSlotMeta('Quicksave')
            writeManifest()
        end
        return ok
    end

    function Save.quickLoad()
        return Save.load(Context.QUICK_SAVE_FILE)
    end

    function Save.autoSave()
        local manifest = readManifest()
        local nextSlot = ((manifest.lastAutoSlot or 0) % Context.MAX_AUTO_SLOTS) + 1
        local slotId = 'auto_' .. nextSlot
        local ok = Save.save(Helpers.slotFilename(slotId))
        if ok then
            manifest.slots[slotId] = buildSlotMeta('Auto-save ' .. nextSlot)
            manifest.lastAutoSlot = nextSlot
            writeManifest()
        end
        return ok
    end

    function Save.getSlotList()
        local manifest = readManifest()
        local list = {}
        for i = 1, Context.MAX_MANUAL_SLOTS do
            local id = string.format('slot_%02d', i)
            list[#list + 1] = {
                id = id,
                type = 'manual',
                index = i,
                meta = manifest.slots[id],
                current = (manifest.currentSlot == id),
            }
        end
        list[#list + 1] = {
            id = 'quick',
            type = 'quick',
            meta = manifest.slots.quick,
            current = false,
        }
        for i = 1, Context.MAX_AUTO_SLOTS do
            local id = 'auto_' .. i
            list[#list + 1] = {
                id = id,
                type = 'auto',
                index = i,
                meta = manifest.slots[id],
                current = false,
            }
        end
        return list
    end

    function Save.deleteSlot(slotId)
        local manifest = readManifest()
        if manifest.slots[slotId] then
            manifest.slots[slotId] = nil
            if Context.currentSlot == slotId then
                Context.currentSlot = nil
                manifest.currentSlot = nil
            end
            writeManifest()
        end

        local filename = Helpers.slotFilename(slotId)
        if love.filesystem.getInfo(filename) then
            love.filesystem.remove(filename)
        end
    end

    function Save.renameSlot(slotId, newName)
        local manifest = readManifest()
        if manifest.slots[slotId] then
            manifest.slots[slotId].name = newName or manifest.slots[slotId].name
            writeManifest()
        end
    end

    function Save.getAutoSaveInterval()
        return readManifest().settings.autoSaveInterval or Context.DEFAULT_AUTO_INTERVAL
    end

    function Save.setAutoSaveInterval(days)
        local manifest = readManifest()
        manifest.settings.autoSaveInterval = math.max(1, math.floor(days or Context.DEFAULT_AUTO_INTERVAL))
        writeManifest()
    end

    function Save.getCurrentSlot()
        local manifest = readManifest()
        return Context.currentSlot or manifest.currentSlot
    end

    function Save.getMostRecentSave()
        local manifest = readManifest()
        local bestId, bestTs = nil, -1
        for id, meta in pairs(manifest.slots) do
            local ts = (meta and meta.timestamp) or 0
            if ts > bestTs then
                bestId, bestTs = id, ts
            end
        end
        return bestId
    end

    function Save.exists()
        local manifest = readManifest()
        if love.filesystem.getInfo(Context.QUICK_SAVE_FILE) then
            return true
        end
        if manifest.slots.quick then
            return true
        end
        for _, meta in pairs(manifest.slots) do
            if meta then
                return true
            end
        end
        return love.filesystem.getInfo(Context.OLD_SAVE_FILE) ~= nil
    end

    function Save.migrateOldSave()
        if not love.filesystem.getInfo(Context.OLD_SAVE_FILE) then
            return false
        end
        if love.filesystem.getInfo(Context.QUICK_SAVE_FILE) then
            return false
        end

        local str = love.filesystem.read(Context.OLD_SAVE_FILE)
        if not str then
            return false
        end

        Helpers.ensureSavesDir()
        local ok = love.filesystem.write(Context.QUICK_SAVE_FILE, str)
        if not ok then
            return false
        end

        local manifest = readManifest()
        manifest.slots.quick = {
            name = 'Migrated Save',
            colonyName = 'Frosthold',
            day = 1,
            colonists = 0,
            timestamp = os.time(),
        }
        writeManifest()
        return true
    end

    function Save.refreshManifest()
        Context.manifest = nil
        readManifest()
    end

    function Save.step(dt)
        if not GameState._lastAutoSaveDay then
            GameState._lastAutoSaveDay = GameState.day
        end
        local intervalDays = Save.getAutoSaveInterval()
        local last = GameState._lastAutoSaveDay
        if GameState.day >= last + intervalDays then
            Save.autoSave()
            GameState._lastAutoSaveDay = GameState.day
            local uok, UI = pcall(require, 'src.ui.ui')
            if uok and UI.showSaveToast then
                UI.showSaveToast('Auto-Saved')
            end
        end
    end
end

return attach
