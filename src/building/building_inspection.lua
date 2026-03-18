local function attach(Building, State)
    local key = State.key

    function Building.getAt(x, y, depth)
        return State.placed[key(x, y, depth)]
    end

    function Building.getAll()
        return State.placed
    end

    function Building.getState()
        local out = {}
        for placedKey, info in pairs(State.placed) do
            out[placedKey] = {
                x = info.x,
                y = info.y,
                depth = info.depth or 0,
                fuel = info.fuel,
                active = info.active,
                defName = info.def and info.def.name,
                heatOutput = info.def and info.def.heatOutput,
                fuelRate = info.def and info.def.fuelRate,
                ventType = info.def and info.def.ventType,
                ventKey = info.ventKey,
                subTile = info.subTile or nil,
                upgradeLevel = info.upgradeLevel or 0,
            }
        end
        return out
    end

    function Building.loadState(saved)
        if not saved then
            return
        end

        State.reset()
        local tok, Thermal = pcall(require, 'src.sim.thermal')
        for placedKey, info in pairs(saved) do
            local matchedDef = nil
            for _, def in pairs(Building.defs) do
                if def.name == info.defName then
                    matchedDef = def
                    break
                end
            end

            if matchedDef then
                local level = info.upgradeLevel or 0
                State.placed[placedKey] = {
                    def = matchedDef,
                    x = info.x,
                    y = info.y,
                    depth = info.depth or 0,
                    fuel = info.fuel or 100,
                    active = info.active or false,
                    ventKey = info.ventKey,
                    subTile = info.subTile or nil,
                    upgradeLevel = level,
                }

                if matchedDef.heatOutput and (info.active ~= false) and tok then
                    local heatOut = matchedDef.heatOutput
                    if level > 0 then
                        local uok, Upgrades = pcall(require, 'src.building.upgrades')
                        if uok then
                            heatOut = Upgrades.getEffectiveStat(State.placed[placedKey], 'heatOutput')
                        end
                    end
                    Thermal.addHeatSource(info.x, info.y, heatOut, info.depth or 0)
                end
            end
        end
    end
end

return attach
