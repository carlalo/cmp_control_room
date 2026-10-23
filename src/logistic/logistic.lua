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

local function transferItem(address, source, slot, index)
    local receiver, realAddress = index_manager.getReceiver(index, address)
    if receiver == nil then
        return
    end

    if hasEmptySlots(receiver) then
        modem.callRemote(source, "pushItems", receiver, slot)
        print("Transferred from " .. source .. " to " .. realAddress)
    else
        print("No empty slots available in receiver " .. realAddress)
    end
end

local function check_sender(sender, index)
    for slot, item in pairs(modem.callRemote(sender, "list")) do
        if not (string.find(item.name, "create:cardboard_package")) then
            transferItem("MainItem", sender, slot, index)
            goto continue
        end
        local details = modem.callRemote(sender, "getItemDetail", slot)
        local address = details.package.getAddress()
        transferItem(address, sender, slot, index)
        ::continue::
    end
end

function Logistic.logisticsLoop(index)
    parallel.waitForAny(read, function()
        while true do
            local senders = index_manager.getAllSenders(index)
            if #senders == 0 then
                print("No senders found in index.")
                sleep(5)
                break
            end
            local funcs = {}
            for k, sender in ipairs(senders) do
                table.insert(funcs, function()
                    local status, err = pcall(check_sender, sender, index)
                    if not status then
                        print(err)
                    end
                end)
            end
            parallel.waitForAll(table.unpack(funcs))
        end
    end)
end

return Logistic
