local modem = peripheral.find("modem")
local index_manager = require("index")

local Logistic = {}


local function hasEmptySlots(inventoryName)
    local size = modem.callRemote(inventoryName, "size")
    local used_slots = #modem.callRemote(inventoryName, "list")
    if used_slots < size then
        return true
    end
    return false -- No empty slots
end

local function transferItem(address, source, slot, index, logger)
    local receiver, realAddress = index_manager.getReceiver(index, address, logger)
    if receiver == nil then
        return
    end

    if hasEmptySlots(receiver) then
        modem.callRemote(source, "pushItems", receiver, slot)
        logger:log(logger.levels.INFO, "TRANSFER", { source, realAddress })
    else
        logger:log(logger.levels.INFO, "NO_SLOTS", realAddress)
    end
end

local function check_sender(sender, index, logger)
    for slot, item in pairs(modem.callRemote(sender, "list")) do
        if not (string.find(item.name, "create:cardboard_package")) then
            transferItem("MainItem", sender, slot, index)
            goto continue
        end
        local details = modem.callRemote(sender, "getItemDetail", slot)
        local address = details.package.getAddress()
        transferItem(address, sender, slot, index, logger)
        ::continue::
    end
end

local function keepOnlySingles(t)
    local count = {}
    for _, v in pairs(t) do
        count[v] = (count[v] or 0) + 1
    end

    local result = {}
    for _, v in pairs(t) do
        if count[v] == 1 then
            table.insert(result, v)
        end
    end
    return result
end

-- Source - https://stackoverflow.com/a/664611
-- Posted by Norman Ramsey
-- Retrieved 2026-10-24, License - CC BY-SA 2.5

function table.copy(t)
    local u = {}
    for k, v in pairs(t) do u[k] = v end
    return setmetatable(u, getmetatable(t))
end

function Logistic.getUnassignedInterfaces(index)
    local names = modem.getNamesRemote()
    local assigned = table.copy(index_manager.getAllSenders(index))
    for address, name in pairs(index_manager.getAllReceivers(index)) do
        table.insert(assigned, name)
    end
    for _, name in pairs(names) do
        table.insert(assigned, name)
    end
    local uniques = keepOnlySingles(assigned)
    local res = {}
    for k, name in pairs(uniques) do
        table.insert(res, name)
    end
    return res
end

function Logistic.logisticsLoop(index, logger)
    parallel.waitForAny(read, function()
        while true do
            local senders = index_manager.getAllSenders(index)
            if #senders == 0 then
                print("No senders found in index.")
                logger:log(logger.levels.CRIT, "EMPTY", "No senders found in Index")
                sleep(5)
                break
            end
            local funcs = {}
            for k, sender in ipairs(senders) do
                table.insert(funcs, function()
                    local status, err = pcall(check_sender, sender, index, logger)
                    if not status then
                        logger:log(logger.levels.CRIT, "PCALL", err)
                    end
                end)
            end
            parallel.waitForAll(table.unpack(funcs))
        end
    end)
end

return Logistic
