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

M.selectedName = nil

function M.addSenderFields(sender, palette, index)
    M.status = sender:addLabel({
        x = 2,
        y = 10,
        width = 40,
        height = 1,
        text = "Booted",
        foreground = palette.lava
    })

    sender:addLabel({
        x = 2,
        y = 3,
        text = "CC Name",
        foreground = palette.lava
    })


    M.nameComboBox = sender:addComboBox({
        x = 2,
        y = 4,
        width = 24,
        text = "Name...",
        autoComplete = true,
        dropHeight = 7,
        items = logistic.getUnassignedInterfaces(index)
    })

    M.nameComboBox:onChange(function(self)
        M.selectedName = self.text
        M.status.text = ""
    end)


    M.nameComboBox:onSelect(function(_, _, item)
        M.selectedName = item.text
        M.status.text = ""
    end)


    sender:addButton({
        x = 32,
        y = 4,
        width = 8,
        height = 1,
        text = "Update",
    }):onClick(function()
        M.nameComboBox.items = logistic.getUnassignedInterfaces(index)
    end)

    sender:addButton({
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

        index_manager.addSender(index, M.selectedName)
        M.status.text = M.selectedName .. " als Sender gemappt!"
        M.nameComboBox.items = logistic.getUnassignedInterfaces(index)
        M.selectedName = nil
    end)
end

return M
