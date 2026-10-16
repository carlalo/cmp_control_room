-- Coordinates target-filter selection and the independent redstone fire signal.
local M = {}

local RedstoneOutput = require("core.actors.redstone_output")
local TargetFilter = require("core.actors.target_filter")

local outputPeripheral = "computer"
local outputSide = "top"
local targetFilterConfig = nil
local active = false
local firing = false

function M.configure(config)
    config = config or {}
    outputPeripheral = config.fireOutputPeripheral or "computer"
    outputSide = config.fireOutputSide or "top"
    targetFilterConfig = config.targetFilter
    RedstoneOutput.setOutput(outputPeripheral, outputSide, false)
    active = false
    firing = false
    TargetFilter.discover(targetFilterConfig)
    TargetFilter.setPlayerTargeting(targetFilterConfig, false)
end

function M.activate_cannons()
    if active then return true end
    M.stop_fire()
    TargetFilter.setPlayerTargeting(targetFilterConfig, true)
    active = true
    return true
end

function M.start_fire()
    assert(active, "Cannons must be activated before firing")
    if firing then return true end
    RedstoneOutput.setOutput(outputPeripheral, outputSide, true)
    firing = true
    return true
end

function M.stop_fire()
    if not firing then return true end
    RedstoneOutput.setOutput(outputPeripheral, outputSide, false)
    firing = false
    return true
end

function M.deactivate_cannons()
    if not active and not firing then return true end
    M.stop_fire()
    TargetFilter.setPlayerTargeting(targetFilterConfig, false)
    active = false
    return true
end

return M
