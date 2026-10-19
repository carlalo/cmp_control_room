local index_manager = require("index")

local Function_table = {}

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

local commands = {
    map = function(command, index)
        if command[2] == "sender" then
            index_manager.addSender(index, command[3])
        end
        if command[2] == "receiver" then
            index_manager.addReceiver(index, command[3], command[4])
        end
    end,
    list = function(command, index)
        print("Senders:")
        print(textutils.serialise(index_manager.getAllSenders(index)))
        print("Receivers:")
        print(textutils.serialise(index_manager.getAllReceivers(index)))
    end,
    search = function(command, index)
        local name = command[3]

        if command[2] == "sender" then
            local sender = index_manager.getAllSenders(index)[command[3]]
            if sender == nil then
                print("Sender not found: " .. command[3])
            else
                print("Sender found: " .. command[3])
            end
        elseif command[2] == "receiver" then
            local receiver = index_manager.getReceiver(index, command[3])
            if receiver == nil then
                print("Receiver not found: " .. command[3])
            else
                print("Receiver found: " .. command[3])
            end
        else
            print("Unknown search type: " .. command[2])
        end
    end,
    exit = function(command, index)
        print("Exiting...")
        return false;
    end,
    help = function(command, index)
        print("Available commands:")
        print("map sender <name> - Add a sender to the index")
        print(
            "map receiver <name> <address> - Add a receiver to the index (backup will consume all packages if no other receiver is found)")
        print("list - List all senders and receivers")
        print("search sender <name> - Search for a sender by name")
        print("search receiver <address> - Search for a receiver by address")
        print("exit - Exit the program")
    end
}

function Function_table.processCommandLoop(index)
    while true do
        local command = mysplit(read(), " ")
        if commands[command[1]] == nil then
            print("Unknown command: " .. command[1])
        else
            local returnCode = commands[command[1]](command, index)
            if returnCode == false then
                break
            end
        end
    end
end

return Function_table
