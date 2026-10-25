local M = {}

function M.get404s(logger, palette)
    local addresses = logger:getLastByType(24, "ADDRESS_404")

    local hash = {}
    local items = {}
    for i, entry in ipairs(addresses) do
        local msg = entry[3] .. " nicht gefunden!"
        if (not hash[msg]) then
            table.insert(items,
                {
                    text = msg,
                    value = i,
                    fg = palette.lava
                })
            hash[msg] = true
        end
    end
    return items
end

function M.getAddressFields(address, logger, palette)
    local list = address:addList({
        x = 2,
        y = 2,
        width = 53,
        height = 24,
        scrollbar = "hidden",
        items = M.get404s(logger, palette),
        background = palette.bg,
        selectable = false
    })

    return list
end

return M
