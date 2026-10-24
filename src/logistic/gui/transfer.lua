local M = {}

function M.getTransfers(logger, palette)
    local transfers = logger:getLastByType(24, "TRANSFER")
    local items = {}
    for i, transfer in ipairs(transfers) do
        local source, address = table.unpack(transfer[3])
        table.insert(items,
            {
                text = "Transfer from '" .. source .. "' to '" .. address .. "'",
                value = i,
                fg = palette.lava
            })
    end
    return items
end

function M.addTransferFields(transfer, logger, palette)
    local list = transfer:addList({
        x = 2,
        y = 2,
        width = 53,
        height = 24,
        scrollbar = "hidden",
        items = M.getTransfers(logger, palette),
        background = palette.bg
    })

    return list
end

return M
