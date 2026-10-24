local index_manager = require("index")
local logistic = require("logistic")
local Logger = require("lib/logger")
local gui = require("gui")

local index = index_manager.create()
local logger = Logger:new("/log")

gui.addComputerGUI(index, logger)
gui.addMonitorGUI(logger)
print("Transferring")

parallel.waitForAny(gui.startGUI, function()
    logistic.logisticsLoop(index, logger)
end)
logger:close()
