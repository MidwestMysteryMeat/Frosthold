local Context = require('src.persistence.save_context')
local Helpers = require('src.persistence.save_helpers')

local function attach(Save)
    function Save.save(filename)
        filename = filename or Context.QUICK_SAVE_FILE

        local str = Helpers.serialize(Helpers.buildSaveData())
        Helpers.ensureSavesDir()
        local ok, err = love.filesystem.write(filename, str)
        if not ok then
            print('[Save] ERROR writing save file: ' .. tostring(err))
            return false
        end

        print('[Save] Saved to ' .. filename .. ' (' .. #str .. ' bytes)')
        return true
    end
end

return attach
