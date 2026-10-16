local Log = require("core.log")

local Logs = {}
Logs.__index = Logs

function Logs.new(options)
    options = options or {}
    return setmetatable({ limit = options.limit or 500 }, Logs)
end

function Logs:read()
    return {
        online = true,
        logs = Log.getEntries(self.limit)
    }
end

return Logs
