local modem = peripheral.find("modem")
local index_manager = require("index")
local logger = require("logs.Log").new("logistic")


local index = index_manager.create()

local function mysplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end



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


local function processCommandLoop()
    local commands = require("commands")
    while true do
        local command = mysplit(read(), " ")
        if commands[command[1]] == nil then
            print("Unknown command: " .. command[1])
            logger.warn("Unknown command: " .. command[1])
        else
            local returnCode = commands[command[1]](command)
            if returnCode == false then
                break
            end
        end
    end
end

local function transferItem(address, source, slot)
    local receiver = index_manager.getReceiver(index, address)
    if receiver == nil then
        logger.error("Receiver " .. address .. " not found in index.")
        return
    end

    if hasEmptySlots(receiver) then
        modem.callRemote(source, "pushItems", receiver, slot)
        logger.debug("Transferred from " .. source .. " to " .. address)
        print("Transferred from " .. source .. " to " .. address)
    else
        logger.warn("No empty slots available in receiver " .. address)
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
                logger.warn("No address found for item in slot " .. slot .. " of sender " .. sender)
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
            logger.warn("No senders found in index.")
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
        processCommandLoop()
    end
end
print("Transferring")
logisticsLoop()
