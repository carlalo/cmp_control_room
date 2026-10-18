-- In-memory central log with a bounded history for the log-screen provider.
local M = {}
local records = {}
local nextId = 0
local maxRecords = 500

local levels = { DEBUG = true, INFO = true, WARN = true, ERROR = true }

function M.write(level, source, content)
    level = tostring(level or "INFO"):upper()
    if not levels[level] then level = "INFO" end

    nextId = nextId + 1
    records[#records + 1] = {
        id = nextId,
        timestamp = os.epoch("utc"),
        level = level,
        source = tostring(source or "system"),
        content = tostring(content or "")
    }
    while #records > maxRecords do table.remove(records, 1) end
end

function M.getEntries(limit)
    local result = {}
    local first = math.max(1, #records - (limit or #records) + 1)
    for index = #records, first, -1 do
        local copy = {}
        for key, value in pairs(records[index]) do copy[key] = value end
        result[#result + 1] = copy
    end
    return result
end

function M.new(source)
    source = tostring(source or "system")
    local logger = {}
    for level in pairs(levels) do
        local capturedLevel = level
        local method = capturedLevel:lower()
        logger[method] = function(content)
            M.write(capturedLevel, source, content)
        end
    end
    return logger
end

return M
