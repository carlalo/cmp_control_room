local modem = peripheral.find("modem")
local index_manager = require("index")
local commands = require("commands")
local index = index_manager.create()



local function hasEmptySlots(inventoryName)
    local size = modem.callRemote(inventoryName, "size")

    for slot = 1, size do
        local item = modem.callRemote(
            inventoryName,
            "getItemDetail",
            slot
        )

        if item == nil then
            return true -- An empty slot was found
        end
    end

    return false -- No empty slots
end


local function transferItem(address, source, slot)
    local receiver = index_manager.getReceiver(index, address)
    if receiver == nil then
        return
    end

    if hasEmptySlots(receiver) then
        modem.callRemote(source, "pushItems", receiver, slot)
        print("Transferred from " .. source .. " to " .. address)
    else
        print("No empty slots available in receiver " .. address)
    end
end

local function check_sender(sender)
    for slot, item in pairs(modem.callRemote(sender, "list")) do
        if item == nil then
            goto continue
        end
        local details = modem.callRemote(sender, "getItemDetail", slot)
        local package = details.package
        if package == nil then
            transferItem("MainItem", sender, slot)
        else
            local address = package.getAddress()
            if address ~= nil then
                transferItem(address, sender, slot)
            else
                print("No address found for item in slot " .. slot .. " of sender " .. sender)
            end
        end
        ::continue::
    end
end

local function logisticsLoop()
    while true do
        local senders = index_manager.getAllSenders(index)
        if #senders == 0 then
            print("No senders found in index.")
            sleep(5)
            break
        end
        for k, sender in ipairs(senders) do
            check_sender(sender)
        end
    end
end

if #arg > 0 then
    if arg[1] == "mapping" then
        print("Mapping")
        commands.processCommandLoop(index);
    end
end
print("Transferring")
logisticsLoop()
