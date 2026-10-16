
local FluidTank = {}
FluidTank.__index = FluidTank

local function offline(peripheralName, reason)
    return {
        online = false,
        peripheral = peripheralName,
        error = reason,
        capacity = 0,
        amount = 0,
        percent = 0,
        fluids = {}
    }
end

function FluidTank.new(peripheralName)
    assert(
        type(peripheralName) == "string",
        "Peripheral-Name fehlt"
    )

    return setmetatable({
        peripheralName = peripheralName,
        peripheral = nil
    }, FluidTank)
end

-- Verbindung herstellen oder erneut versuchen.
function FluidTank:connect()
    local p = peripheral.wrap(self.peripheralName)

    if not p then
        self.peripheral = nil
        return false
    end

    self.peripheral = p
    return true
end

function FluidTank:read()
    if not self.peripheral and not self:connect() then
        return offline(self.peripheralName, "Peripheral not found")
    end

    local ok, info, tanks = pcall(function()
        return self.peripheral.info(), self.peripheral.tanks()
    end)

    if not ok then
        if tostring(info) == "Terminated" then error(info, 0) end
        self.peripheral = nil
        return offline(self.peripheralName, "Tank peripheral stopped responding")
    end

    if type(info) ~= "table" then
        self.peripheral = nil
        return offline(self.peripheralName, "Tank returned no information")
    end

    if type(tanks) ~= "table" then
        self.peripheral = nil
        return offline(self.peripheralName, "Tank returned no fluid data")
    end

    local capacity = info.capacity or 0
    local fluids = {}
    local amount = 0

    for _, fluid in pairs(tanks or {}) do
        local fluidAmount = fluid.amount or 0

        table.insert(fluids, {
            name = fluid.name or "unknown",
            amount = fluidAmount
        })

        amount = amount + fluidAmount
    end

    return {
        online = true,
        peripheral = self.peripheralName,
        capacity = capacity,
        amount = amount,
        percent = capacity > 0
            and amount / capacity * 100
            or 0,
        fluids = fluids
    }
end

return FluidTank
