local Building = {}

Building.defs = require('src.building.building_defs')

local State = require('src.building.building_state')

require('src.building.building_placement')(Building, State)
require('src.building.building_inspection')(Building, State)

return Building
