local M = {}

function M.getCriticals(logger, palette)
    local criticals = logger:getLastByLevel(24, logger.levels.CRIT)
    local items = {}
    for i, entry in ipairs(criticals) do
        local msg = entry[3]
        table.insert(items,
            {
                text = msg,
                value = i,
                fg = palette.lava
            })
    end
    return items
end

function M.addCriticalFields(critical, logger, palette)
    local list = critical:addList({
        x = 2,
        y = 2,
        width = 53,
        height = 24,
        scrollbar = "hidden",
        items = M.getCriticals(logger, palette),
        background = palette.bg,
        selectable = false
    })

    return list
end

return M
