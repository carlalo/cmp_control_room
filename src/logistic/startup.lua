local modem = peripheral.find("modem")
local index_manager = require("index")
local commands = require("commands")
local logistic = require("logistic")
local Logger = require(fs.combine(fs.getDir(shell.getRunningProgram()), "../lib", "logger.lua"))

local logger = Logger:new("/log")
local index = index_manager.create()

if #arg > 0 then
    if arg[1] == "mapping" then
        print("Mapping")
        commands.processCommandLoop(index);
    end
end

print("Transferring")
logistic.logisticsLoop(index)
Logger:close()
