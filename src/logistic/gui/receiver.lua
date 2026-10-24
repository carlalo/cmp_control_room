local logistic = require("logistic")
local index_manager = require("index")
local M = {}


function M.getUnassignedInterfaces(index)
    local names = {}
    for i, name in ipairs(logistic.getUnassignedInterfaces(index)) do
        table.insert(names, { text = name, value = i })
    end
    return names
end

function M.getUnassignedAddress(logger)
    local entries = logger:getLastByType(5, "ADDRESS_404")
    local all = {}
    for _, entry in ipairs(entries) do
        table.insert(all, entry[3])
    end
    local hash = {}
    local res = {}
    for _, v in ipairs(all) do
        if (not hash[v]) then
            res[#res + 1] = v -- you could print here instead of saving to result table if you wanted
            hash[v] = true
        end
    end
    return res
end

M.selectedName = nil
M.selectedAddress = nil

function M.addReceiverFields(receiver, palette, index, logger)
    M.status = receiver:addLabel({
        x = 2,
        y = 10,
        width = 40,
        height = 1,
        text = "Booted",
        foreground = palette.lava
    })

    receiver:addLabel({
        x = 2,
        y = 3,
        text = "CC Name",
        foreground = palette.lava
    })


    M.receiverDropdown = receiver:addDropdown({
        x = 2,
        y = 4,
        width = 24,
        text = "Name...",
        dropHeight = 7,
        items = M.getUnassignedInterfaces(index)
    })

    M.receiverDropdown:onSelect(function(_, _, item)
        M.selectedName = item.text
        M.status.text = ""
    end)

    receiver:addLabel({
        x = 2,
        y = 6,
        text = "Adresse",
        foreground = palette.lava,
    })

    M.addressesComboBox = receiver:addComboBox({
        x = 2,
        y = 7,
        width = 24,
        placeholder = "Adresse...",
        dropHeight = 7,
        autoComplete = true,
        items = M.getUnassignedAddress(logger)
    })


    M.addressesComboBox:onSelect(function(_, _, item)
        M.selectedAddress = item.text
        M.status.text = ""
    end)

    M.addressesComboBox:onChange(function(self)
        M.selectedAddress = self.text
        M.status.text = ""
    end)


    receiver:addButton({
        x = 32,
        y = 4,
        width = 8,
        height = 1,
        text = "Update",
    }):onClick(function()
        M.receiverDropdown.items = M.getUnassignedInterfaces(index)
        M.addressesComboBox.items = M.getUnassignedAddress(logger)
    end)

    receiver:addButton({
        x = 32,
        y = 7,
        width = 8,
        height = 1,
        text = "Map!",
    }):onClick(function()
        if M.selectedName == nil then
            M.status.text = "Waehle ein Name aus!"
            return
        end
        if M.selectedAddress == nil then
            M.status.text = "Waehle eine Adresse aus!"
            return
        end

        index_manager.addReceiver(index, M.selectedName, M.selectedAddress)
        M.status.text = M.selectedName .. " auf Adresse '" .. M.selectedAddress .. "' gemappt!"
        M.receiverDropdown.items = M.getUnassignedInterfaces(index)
        M.addressesComboBox.items = M.getUnassignedAddress(logger)
        M.selectedName = nil
        M.selectedAddress = nil
    end)
end

return M
