-- Controls an output either on the computer or on a wired redstone relay.
local M = {}

local validSides = {
    top = true,
    bottom = true,
    left = true,
    right = true,
    front = true,
    back = true
}

function M.setOutput(peripheralName, side, enabled)
    assert(validSides[side], "Invalid redstone output side: " .. tostring(side))
    assert(type(enabled) == "boolean", "Redstone output state must be boolean")

    if peripheralName == nil or peripheralName == "" or peripheralName == "computer" then
        redstone.setOutput(side, enabled)
        return
    end

    local relay = peripheral.wrap(peripheralName)
    assert(relay, "Redstone peripheral not found: " .. tostring(peripheralName))
    assert(type(relay.setOutput) == "function",
        "Peripheral does not provide setOutput: " .. tostring(peripheralName))
    relay.setOutput(side, enabled)
end

return M
