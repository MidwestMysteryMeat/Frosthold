local StorageDefs = {}

StorageDefs.BUILDINGS = {
    crate = {
        name = 'Crate', cost = { wood = 10 }, w = 1, h = 1,
        slots = 4, maxSlotWeight = 200,
        protection = { weather = false, cold = false, heat = false, radiation = false, pressure = false },
        powerDraw = 0,
    },
    locker = {
        name = 'Locker', cost = { metal = 8 }, w = 1, h = 1,
        slots = 8, maxSlotWeight = 200,
        protection = { weather = true, cold = true, heat = false, radiation = false, pressure = false },
        powerDraw = 0,
    },
    shelf = {
        name = 'Shelf', cost = { wood = 8, metal = 2 }, w = 2, h = 1,
        slots = 6, maxSlotWeight = 150,
        protection = { weather = false, cold = false, heat = false, radiation = false, pressure = false },
        powerDraw = 0,
    },
    chest = {
        name = 'Chest', cost = { metal = 12, stone = 5 }, w = 1, h = 1,
        slots = 12, maxSlotWeight = 250,
        protection = { weather = true, cold = true, heat = true, radiation = false, pressure = false },
        powerDraw = 0,
    },
    cold_storage = {
        name = 'Cold Storage Unit', cost = { steel = 8, components = 3, circuit = 1 }, w = 2, h = 2,
        slots = 8, maxSlotWeight = 200,
        protection = { weather = true, cold = true, heat = true, radiation = false, pressure = false },
        powerDraw = 20, keepsFrozen = true,
    },
    lead_vault = {
        name = 'Lead-lined Vault', cost = { lead = 15, steel = 5 }, w = 2, h = 2,
        slots = 6, maxSlotWeight = 300,
        protection = { weather = true, cold = true, heat = true, radiation = true, pressure = false },
        powerDraw = 0,
    },
    bulk_silo = {
        name = 'Bulk Silo', cost = { steel = 20, stone = 15, components = 5 }, w = 3, h = 3,
        slots = 30, maxSlotWeight = 900,
        protection = { weather = true, cold = true, heat = true, radiation = false, pressure = false },
        powerDraw = 0, singleCategory = true,
    },
}

function StorageDefs.get(buildingType)
    return StorageDefs.BUILDINGS[buildingType]
end

return StorageDefs
