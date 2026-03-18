-- space_economy.lua — Shipping contracts, bounties, and credit rewards
-- Generates procedural contracts at stations. Tracks active contracts.

local GameState = require('src.game_state')

local SpaceEconomy = {}

---------------------------------------------------------------------------
-- Contract types
---------------------------------------------------------------------------

local CONTRACT_TYPES = {
    delivery = {
        name = 'Delivery',
        desc = 'Transport cargo from one station to another.',
        rewardBase = 100,
        timeLimit = 20,  -- game days
    },
    bounty = {
        name = 'Bounty',
        desc = 'Eliminate a hostile ship in the target area.',
        rewardBase = 200,
        timeLimit = 30,
    },
    salvage = {
        name = 'Salvage Run',
        desc = 'Retrieve materials from a derelict.',
        rewardBase = 80,
        timeLimit = 15,
    },
    escort = {
        name = 'Escort',
        desc = 'Protect a caravan along its route.',
        rewardBase = 150,
        timeLimit = 10,
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local availableContracts = {}  -- contracts available at stations
local activeContracts = {}     -- contracts the player has accepted
local completedCount = 0
local nextContractId = 1

---------------------------------------------------------------------------
-- Contract generation
---------------------------------------------------------------------------

local function generateContractsForStation(poiId)
    local poi = GameState.discoveredPOIs and GameState.discoveredPOIs[poiId]
    if not poi then return end

    local contracts = {}
    local count = math.random(2, 4)

    for i = 1, count do
        local typeKeys = {}
        for k in pairs(CONTRACT_TYPES) do typeKeys[#typeKeys + 1] = k end
        local typeId = typeKeys[math.random(#typeKeys)]
        local def = CONTRACT_TYPES[typeId]

        -- Scale reward by distance and difficulty
        local diffMult = 1.0 + math.random() * 0.5
        local reward = math.floor(def.rewardBase * diffMult)

        local id = 'contract_' .. nextContractId
        nextContractId = nextContractId + 1

        contracts[#contracts + 1] = {
            id = id,
            type = typeId,
            name = def.name,
            desc = def.desc,
            reward = reward,
            timeLimit = def.timeLimit,
            stationId = poiId,
            accepted = false,
            completed = false,
            dayAccepted = nil,
        }
    end

    availableContracts[poiId] = contracts
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

function SpaceEconomy.getContractsAtStation(poiId)
    if not availableContracts[poiId] then
        generateContractsForStation(poiId)
    end
    return availableContracts[poiId] or {}
end

function SpaceEconomy.acceptContract(contractId)
    -- Find the contract
    for stationId, contracts in pairs(availableContracts) do
        for i, contract in ipairs(contracts) do
            if contract.id == contractId and not contract.accepted then
                contract.accepted = true
                contract.dayAccepted = GameState.day
                activeContracts[#activeContracts + 1] = contract
                table.remove(contracts, i)
                return true
            end
        end
    end
    return false
end

function SpaceEconomy.completeContract(contractId)
    for i, contract in ipairs(activeContracts) do
        if contract.id == contractId then
            GameState.credits = GameState.credits + contract.reward
            contract.completed = true
            completedCount = completedCount + 1
            table.remove(activeContracts, i)

            local alOk, Alerts = pcall(require, 'src.ui.alerts')
            if alOk and Alerts.send then
                Alerts.send('DISCOVERY', 'Contract complete! +' .. contract.reward .. ' credits.')
            end
            return true
        end
    end
    return false
end

function SpaceEconomy.getActiveContracts()
    return activeContracts
end

function SpaceEconomy.getCompletedCount()
    return completedCount
end

---------------------------------------------------------------------------
-- Check for expired contracts
---------------------------------------------------------------------------

function SpaceEconomy.checkExpiry()
    local expired = {}
    for i = #activeContracts, 1, -1 do
        local contract = activeContracts[i]
        if contract.dayAccepted and GameState.day - contract.dayAccepted > (contract.timeLimit or 30) then
            expired[#expired + 1] = contract
            table.remove(activeContracts, i)
        end
    end
    if #expired > 0 then
        local alOk, Alerts = pcall(require, 'src.ui.alerts')
        if alOk and Alerts.send then
            Alerts.send('IDLE COLONISTS', #expired .. ' contract(s) expired.')
        end
    end
end

---------------------------------------------------------------------------
-- Refresh station contracts (called periodically)
---------------------------------------------------------------------------

function SpaceEconomy.refreshContracts()
    for stationId in pairs(availableContracts) do
        generateContractsForStation(stationId)
    end
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function SpaceEconomy.getState()
    return {
        availableContracts = availableContracts,
        activeContracts = activeContracts,
        completedCount = completedCount,
        nextContractId = nextContractId,
    }
end

function SpaceEconomy.loadState(state)
    if not state then return end
    availableContracts = state.availableContracts or {}
    activeContracts = state.activeContracts or {}
    completedCount = state.completedCount or 0
    nextContractId = state.nextContractId or 1
end

return SpaceEconomy
