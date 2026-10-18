local Index = {}

local function writeIndex(index)
    local file = fs.open("/disk/index", "w")
    local content = textutils.serialise(index)
    file.write(content)
    file.close()
end

function Index.create()
    local index = {}
    if fs.exists("/disk/index") then
        local file = fs.open("/disk/index", "r")
        local content = file.readAll()
        file.close()
        index = textutils.unserialise(content)
    else
        index = { senders = {}, receivers = {} }
        local content = textutils.serialise(index)
        local file = fs.open("/disk/index", "w")
        file.write(content)
        file.close()
    end
    return index
end

function Index.getReceiver(index, address)
    if index.receivers[address] ~= nil then
        return index.receivers[address]
    else
        print("Receiver " .. address .. " war nicht belegt!")
    end
end

function Index.getAllSenders(index)
    return index.senders
end

function Index.addReceiver(index, name, address)
    index.receivers[address] = name
    writeIndex(index)
end

function Index.addSender(index, name)
    table.insert(index.senders, name)
    writeIndex(index)
end

return Index
