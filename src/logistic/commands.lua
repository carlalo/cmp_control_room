local commands = {
    map = function(command)
        if command[2] == "sender" then
            index_manager.addSender(index, command[3])
        end
        if command[2] == "receiver" then
            index_manager.addReceiver(index, command[3], command[4])
        end
    end,
    list = function(command)
        print("Senders:")
        print(index_manager.listSenders(index))
        print("Receivers:")
        print(index_manager.listReceivers(index))
    end,
    search = function(command)
        local name = command[3]

        if command[2] == "sender" then
            local senders = index_manager.searchSenders(index, name)
            if #senders == 0 then
                print("No senders found with name: " .. name)
            else
                local found = false;
                for _, sender in ipairs(senders) do
                    if sender == name then
                        found = true
                        print("Sender found: " .. sender)
                    end
                end
                if not found then
                    print("No senders found with name: " .. name)
                end
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
    exit = function(command)
        print("Exiting...")
        return false;
    end,
    help = function(command)
        print("Available commands:")
        print("map sender <name> - Add a sender to the index")
        print("map receiver <name> <address> - Add a receiver to the index")
        print("list - List all senders and receivers")
        print("search sender <name> - Search for a sender by name")
        print("search receiver <address> - Search for a receiver by address")
        print("exit - Exit the program")
    end
}

return commands
