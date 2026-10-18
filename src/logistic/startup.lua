local modem = peripheral.find("modem")
local index_manager = require("index")

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
    while true do
        local command = mysplit(read(), " ")
        if command[1] == "map" then
            if command[2] == "sender" then
                index_manager.addSender(index, command[3])
            end
            if command[2] == "receiver" then
                index_manager.addReceiver(index, command[4], command[3])
            end
        end
    end
end

local function transferItem(address, source, slot)
    local receiver = index_manager.getReceiver(index, address)
    if hasEmptySlots(receiver) then
        modem.callRemote(source, "pushItems", receiver, slot)
        print("Transferred from " .. source .. " to " .. address)
    end
end

local function logisticsLoop()
    while true do
        for k, sender in ipairs(index_manager.getAllSenders(index)) do
            for slot, item in pairs(modem.callRemote(sender, "list")) do
                local address = modem.callRemote(sender, "getItemDetail", slot).package.getAddress()
                if item ~= nil then
                    transferItem(address, sender, slot)
                end
            end
        end
    end
end

if #arg > 0 then
    if arg[1] == mapping then
        print("Mapping")
        processCommandLoop()
    end
end
print("Transferring")
logisticsLoop()
