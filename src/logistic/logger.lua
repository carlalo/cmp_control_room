local Logger = { file = nil, log_table = {} }
Logger.__index = Logger

function Logger:new(filepath)
    local logger = {}
    logger.file = filepath

    if fs.exists(logger.file) then
        logger.file = fs.open(logger.file, "rw")
        local content = logger.file.readAll()
        logger.log_table = textutils.unserialise(content)
    else
        logger.log_table = {}
        local content = textutils.serialise(logger.log_table)
        logger.file = fs.open("/disk/index", "rw")
        logger.file.write(content)
    end

    return setmetatable(logger, self)
end

function Logger:close()
    self.file.close()
end

return Logger
