local Logger = { file = nil, log_table = {}, filepath = "" }
Logger.__index = Logger

local levels = {
    WARN = "WARN",
    CRIT = "CRIT",
    INFO = "INFO"
}
Logger.levels = levels

function Logger:new(filepath)
    local logger = {}
    logger.log_table = {}
    logger.filepath = filepath

    if fs.exists(logger.filepath) then
        logger.file = fs.open(logger.filepath, "r+")
        repeat
            local line = logger.file.readLine()
            if line then
                table.insert(logger.log_table, textutils.unserialise(line))
            end
        until line == nil
    else
        logger.file = fs.open(filepath, "w+")
    end

    return setmetatable(logger, self)
end

function Logger:log(level, type, message)
    assert(levels[level], "invalid log level")
    local new_entry = table.pack(levels[level], type, message)
    table.insert(self.log_table, new_entry)
    if #self.log_table >= 200 then
        local lenght = #self.log_table
        table.move(self.log_table, 151, lenght, 1)
        for i = lenght - 149, lenght do
            self.log_table[i] = nil
        end
        self.file.close()
        self.file = fs.open(self.filepath, "w+")
        for _, entry in ipairs(self.log_table) do
            self.file.writeLine(textutils.serialise(entry))
        end
    else
        self.file.writeLine(textutils.serialise(new_entry, { compact = true }))
        self.file.flush()
    end
end

local function getLinesOfType(targettype, log_table)
    local lines = {}
    for line, content in ipairs(log_table) do
        local level, type, message = table.unpack(content)
        if type == targettype then
            table.insert(lines, line)
        end
    end
    return lines
end


local function getLinesOfLevel(targetlevel, log_table)
    local lines = {}
    for line, content in ipairs(log_table) do
        local level, type, message = table.unpack(content)
        if level == targetlevel then
            table.insert(lines, line)
        end
    end
    return lines
end

function Logger:getAllByType(type)
    if type then
        local lines = getLinesOfType(type, self.log_table)
        local returnTable = {}
        for _, line_number in ipairs(lines) do
            table.insert(returnTable, self.log_table[line_number])
        end
        return returnTable
    else
        return self.log_table
    end
end

function Logger:getAllByLevel(level)
    if type then
        local lines = getLinesOfLevel(level, self.log_table)
        local returnTable = {}
        for _, line_number in ipairs(lines) do
            table.insert(returnTable, self.log_table[line_number])
        end
        return returnTable
    else
        return self.log_table
    end
end

function Logger:getLastByType(amount, type)
    local filteredTable = self:getAllByType(type)
    local goal = math.max(1, #filteredTable - amount)
    local returnTable = {}
    for i = #filteredTable, goal, -1 do
        table.insert(returnTable, filteredTable[i])
    end
    return returnTable
end

function Logger:getLastByLevel(amount, level)
    local filteredTable = self:getAllByLevel(level)
    local goal = math.max(1, #filteredTable - amount)
    local returnTable = {}
    for i = #filteredTable, goal, -1 do
        table.insert(returnTable, filteredTable[i])
    end
    return returnTable
end

function Logger:clearEntriesByLines(lines)
    for _, line in ipairs(lines) do
        table.remove(self.log_table, line)
    end
    self.file.close()
    self.file = fs.open(self.filepath, "w+")
    for _, entry in ipairs(self.log_table) do
        self.file.writeLine(textutils.serialise(entry))
    end
end

function Logger:clearEntriesByType(type)
    assert(type, "cant clear nil by type")
    local lines = getLinesOfType(type, self.log_table)
    self.clearEntriesByLines(lines)
end

function Logger:clear()
    self.file.close()
    self.log_table = {}
    self.file = fs.open(self.filepath, "w")
end

function Logger:close()
    self.file.close()
end

return Logger
