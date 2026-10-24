local basalt = require("lib/basalt")

local M = {}

local palette = basalt.use("theme").applyPreset("basalt")

function M.addComputerGUI(index, logger)
    local main = basalt.getMainFrame()
    local width, height = main:getSize()


    local panelWidth = math.min(47, width - 4)
    local panelHeight = math.min(18, height - 2)

    local panel = main:addFrame({
        x = math.floor((width - panelWidth) / 2) + 1,
        y = math.floor((height - panelHeight) / 2) + 1,
        width = panelWidth,
        height = panelHeight,
        background = palette.surface,
    })

    panel:addLabel({
        x = 2,
        y = 2,
        text = "Index Mapper",
        foreground = palette.lava,
    })

    panel:addButton({
        x = panelWidth - 8,
        y = 2,
        width = 8,
        height = 1,
        text = "Exit",
    }):onClick(function()
        basalt.stop()
    end)

    local tabs = panel:addTabControl({
        x = 2,
        y = 4,
        width = panelWidth - 4,
        height = 40,
        background = palette.surface,
        activeForeground = palette.surface,
        activeBackground = palette.lava,
    })

    local receiver = tabs:addTab("Receiver")
    local receiverFunctions = require("gui/receiver")
    receiverFunctions.addReceiverFields(receiver, palette, index, logger)
    local sender = tabs:addTab("Sender")
    local senderFunctions = require("gui/sender")
    senderFunctions.addSenderFields(sender, palette, index)


    local focusTargets = {
        receiver:getChildren()[1],
        sender:getChildren()[1],
    }

    tabs:onChange(function(_, index, title)
        if focusTargets[index] then focusTargets[index]:focus() end
    end)

    receiver:getChildren()[1]:focus()
end

function M.addMonitorGUI(logger)
    local monitorName = "monitor"
    local monitor = assert(peripheral.find(monitorName), "monitor missing")
    monitor.setTextScale(0.5)

    local frame = basalt.createFrame(monitor)
    frame.background = palette.surface
    local width, height = frame:getSize()

    local tabs = frame:addTabControl({
        x = 2,
        y = 2,
        width = width - 3,
        height = height - 2,
        background = palette.surface,
        activeForeground = palette.surface,
        activeBackground = palette.lava
    })


    frame:addButton({
        x = 44,
        y = 2,
        width = 11,
        height = 1,
        text = "Clear Log",
    }):onClick(function()
        logger:clear()
    end)

    local transfer = tabs:addTab("Transfer")
    local transferFunctions = require("gui/transfer")
    local list = transferFunctions.addTransferFields(transfer, logger, palette)

    local critical = tabs:addTab("Critical")
    local criticalFunctions = require("gui/critical")
    local criticals = criticalFunctions.addCriticalFields(critical, logger, palette)

    local address = tabs:addTab("Address_404")
    local addressFunctions = require("gui/address")
    local addresses = addressFunctions.getAddressFields(address, logger, palette)

    basalt.schedule(function()
        while true do
            list.items = transferFunctions.getTransfers(logger, palette)
            os.sleep(4)
        end
    end)

    local focusTargets = {
        transfer:getChildren()[1],
        critical:getChildren()[1],
        address:getChildren()[1],
    }

    tabs:onChange(function(_, index, title)
        if focusTargets[index] then focusTargets[index]:focus() end
        criticals.items = criticalFunctions.getCriticals(logger, palette)
        addresses.items = addressFunctions.get404s(logger, palette)
    end)

    transfer:getChildren()[1]:focus()
end

-- Start Basalt's event loop. This call blocks until basalt.stop() is called.
function M.startGUI()
    basalt.run()
end

return M
