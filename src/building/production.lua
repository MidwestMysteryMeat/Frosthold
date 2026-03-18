-- production.lua - Facade for shared production data and runtime systems

local Production = {}
local defs = require('src.building.production_defs')

Production.ITEMS = defs.ITEMS
Production.RECIPES = defs.RECIPES
Production.MACHINES = defs.MACHINES
Production.ITEM_TO_RES = defs.ITEM_TO_RES
Production.DRUG_EFFECTS = defs.DRUG_EFFECTS
Production.FOOD_QUALITY = defs.FOOD_QUALITY

require('src.building.production_runtime')(Production, defs)
Production.registerSystems()

return Production
