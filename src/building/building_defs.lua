local defs = {}

local function merge(chunk)
    for defId, def in pairs(chunk) do
        defs[defId] = def
    end
end

merge(require('src.building.building_defs_core'))
merge(require('src.building.building_defs_industry'))
merge(require('src.building.building_defs_defense'))
merge(require('src.building.building_defs_networks'))
merge(require('src.building.building_defs_misc'))
merge(require('src.building.building_defs_space'))
merge(require('src.building.building_defs_water'))

return defs
