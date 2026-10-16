local GPU = require("drivers.directgpu")
local TableLayout = require("ui.table_layout")
local M = {}

local function formatValue(value, format, unit)
    if value == nil or value == "" then return "--" end
    if format == "distance" and type(value) == "number" then
        return string.format("%.1f %s", value, unit or "m")
    end
    if format == "duration" and type(value) == "number" then
        local seconds = math.max(0, math.floor(value))
        if seconds >= 3600 then
            return string.format("%dh %02dm", math.floor(seconds / 3600),
                math.floor(seconds % 3600 / 60))
        elseif seconds >= 60 then
            return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
        end
        return tostring(seconds) .. "s"
    end
    if format == "age" and type(value) == "number" then
        local seconds = math.max(0, math.floor((os.epoch("utc") - value) / 1000))
        if seconds < 60 then return "now" end
        if seconds < 3600 then return tostring(math.floor(seconds / 60)) .. "m ago" end
        if seconds < 86400 then return tostring(math.floor(seconds / 3600)) .. "h ago" end
        return tostring(math.floor(seconds / 86400)) .. "d ago"
    end
    if format == "time" and type(value) == "number" then
        return os.date("%Y-%m-%d %H:%M:%S", math.floor(value / 1000))
    end
    return tostring(value)
end

local function fit(text, width, size, bold)
    text = tostring(text)
    if width <= 0 then return "" end
    if GPU.measureText(text, size, bold) <= width then return text end

    local suffix = "..."
    while #text > 0 and GPU.measureText(text .. suffix, size, bold) > width do
        text = text:sub(1, -2)
    end
    if #text == 0 and GPU.measureText(suffix, size, bold) > width then return "" end
    return text .. suffix
end

local function cellColor(row, column, colors)
    if column.color then return colors[column.color] or colors.white end
    if column.key == "level" then
        if row.level == "ERROR" then return colors.redLight end
        if row.level == "WARN" then return colors.title end
        if row.level == "INFO" then return colors.blueText end
        if row.level == "DEBUG" then return colors.gray end
    end
    if column.key == "accessStatus" or column.key == "status" then
        if row.accessStatus == "BLACKLISTED" or row.status == "LEFT" then
            return colors.redLight
        elseif row.accessStatus == "WHITELISTED" or row.status == "IN BASE" then
            return colors.green
        elseif row.status == "UNKNOWN" then
            return colors.gray
        end
    end
    return colors.white
end

function M.render(id, widget, rows, data, theme)
    local C, Sx, Sy, Z = theme.colors, theme.spacingX or theme.spacing,
        theme.spacingY or theme.spacing, theme.sizes
    rows = type(rows) == "table" and rows or {}

    local x, y, width, height = widget.x, widget.y, widget.width, widget.height
    GPU.panel(id, x, y, width, height, C.panel, C.edge, C.blueText)
    GPU.text(id, widget.label or widget.id or "TABLE", x + Sx.medium, y + Sy.small,
        Z.heading, C.white, true)

    if widget.requiresOnline and data.online == false then
        GPU.text(id, widget.offlineText or "Data source offline",
            x + Sx.medium, y + Sy.large, Z.body, C.redLight, false)
        return
    end

    local columns = widget.columns or {}
    if #columns == 0 then
        GPU.text(id, "No columns configured", x + Sx.medium, y + Sy.large,
            Z.body, C.gray, false)
        return
    end

    local innerX = x + Sx.medium
    local innerWidth = width - Sx.medium * 2
    local headerY = y + Sy.small + Z.heading + Sy.small
    if widget.hint then
        GPU.text(id, widget.hint, innerX, headerY, Z.body, C.gray, false)
        headerY = headerY + Z.body + Sy.small
    end
    local rowScale = widget.scaleY or widget.scale or 1
    local rowHeight = math.max(18, math.floor(
        (widget.rowHeight or (Z.body + Sy.small)) * rowScale + 0.5))
    local rowsY = headerY + Z.body + Sy.small
    local footerReserve = widget.scrollable and (Z.body + Sy.small * 2) or 0
    local availableHeight = y + height - Sy.small - rowsY - footerReserve
    local visibleCount = math.max(0, math.floor(availableHeight / rowHeight))
    if widget.maxRows then visibleCount = math.min(visibleCount, widget.maxRows) end
    if availableHeight <= 0 or (visibleCount == 0 and not widget.autoRowHeight) then
        GPU.text(id, "Increase table height", innerX, rowsY,
            Z.body, C.gray, false)
        return
    end

    local totalWeight = 0
    for _, column in ipairs(columns) do
        totalWeight = totalWeight + (tonumber(column.weight) or 1)
    end
    if totalWeight <= 0 then totalWeight = #columns end

    local xPosition = innerX
    local widths = {}
    for index, column in ipairs(columns) do
        local weight = tonumber(column.weight) or 1
        local columnWidth = index == #columns
            and (innerX + innerWidth - xPosition)
            or (innerWidth * weight / totalWeight)
        widths[index] = columnWidth

        GPU.text(id, fit(string.upper(column.label or column.key or ""),
            columnWidth - Sx.small, Z.body, true),
            xPosition, headerY, Z.body, C.blueText, true)
        xPosition = xPosition + columnWidth
    end

    GPU.line(id, innerX, rowsY - Sy.small, innerX + innerWidth,
        rowsY - Sy.small, C.edge)

    local autoLayout
    if widget.autoRowHeight then
        autoLayout = TableLayout.compute(widget, rows, widths, availableHeight,
            rowHeight, Z.body, Sx.small, Sy.small)
    end
    local pageCount = autoLayout and #autoLayout.pages
        or (visibleCount > 0 and math.max(1, math.ceil(#rows / visibleCount)) or 1)
    local page = 1
    local selectedIndex = math.max(1, math.min(#rows, data.selectedIndex or 1))
    if autoLayout and widget.scrollable then
        local offsets = data.tableOffsets or {}
        page = math.max(1, math.min(pageCount, (offsets[widget.id] or 0) + 1))
    elseif widget.selectable and widget.scrollable and #rows > visibleCount then
        page = math.floor((selectedIndex - 1) / visibleCount) + 1
    elseif widget.scrollable and #rows > visibleCount then
        local offsets = data.tableOffsets or {}
        page = math.max(1, math.min(pageCount, (offsets[widget.id] or 0) + 1))
    end
    local pageRows
    if autoLayout then
        pageRows = autoLayout.pages[page] or {}
    else
        pageRows = {}
        local first = (page - 1) * visibleCount + 1
        local last = math.min(#rows, first + visibleCount - 1)
        for rowIndex = first, last do pageRows[#pageRows + 1] = rowIndex end
    end
    local firstRow = pageRows[1] or 0
    local lastRow = pageRows[#pageRows] or 0

    local rowY = rowsY
    for visibleIndex, rowIndex in ipairs(pageRows) do
        local row = rows[rowIndex]
        if type(row) == "table" then
            local layout = autoLayout and autoLayout.rows[rowIndex]
            local currentRowHeight = layout and layout.height or rowHeight
            local isSelected = widget.selectable and rowIndex == selectedIndex
            if isSelected then
                GPU.rect(id, innerX, rowY - 2, innerWidth, currentRowHeight - 2, C.track or C.blue)
            end
            local cellX = innerX
            for columnIndex, column in ipairs(columns) do
                local cellWidth = widths[columnIndex]
                local value = row[column.key]
                local shown = formatValue(value, column.format, column.unit)
                local cellColorValue = isSelected and C.blueText or cellColor(row, column, C)
                if column.wrap and layout then
                    local lines = layout.cells[columnIndex] or { shown }
                    local textY = rowY + math.max(0,
                        (currentRowHeight - #lines * autoLayout.lineHeight) / 2)
                    for lineIndex, line in ipairs(lines) do
                        GPU.text(id, line, cellX, textY + (lineIndex - 1) * autoLayout.lineHeight,
                            Z.body, cellColorValue, false)
                    end
                else
                    local textY = rowY + math.max(0, (currentRowHeight - Z.body) / 2)
                    GPU.text(id, fit(shown, cellWidth - Sx.small, Z.body, false),
                        cellX, textY, Z.body, cellColorValue, false)
                end
                cellX = cellX + cellWidth
            end
            rowY = rowY + currentRowHeight
            if visibleIndex < #pageRows then
                local lineY = rowY - 2
                GPU.line(id, innerX, lineY, innerX + innerWidth, lineY, C.track or C.edge)
            end
        end
    end

    if #rows == 0 then
        GPU.text(id, widget.emptyText or "No entries",
            innerX, rowsY + Sy.small, Z.body, C.gray, false)
    elseif pageCount > 1 then
        local buttonWidth = math.max(26, Z.body * 2)
        local buttonHeight = Z.body + Sy.small
        local buttonY = y + height - Sy.small - buttonHeight
        local leftX = innerX
        local rightX = innerX + innerWidth - buttonWidth
        GPU.panel(id, leftX, buttonY, buttonWidth, buttonHeight,
            C.background, C.edge, C.blueText)
        GPU.panel(id, rightX, buttonY, buttonWidth, buttonHeight,
            C.background, C.edge, C.blueText)
        local arrowY = buttonY + (buttonHeight - Z.body) / 2
        GPU.text(id, "<", leftX + (buttonWidth - GPU.measureText("<", Z.body, true)) / 2,
            arrowY, Z.body, C.white, true)
        GPU.text(id, ">", rightX + (buttonWidth - GPU.measureText(">", Z.body, true)) / 2,
            arrowY, Z.body, C.white, true)
        local footer = tostring(firstRow) .. "-" .. tostring(lastRow)
            .. " / " .. tostring(#rows)
        local footerWidth = GPU.measureText(footer, Z.body, false)
        GPU.text(id, footer, x + (width - footerWidth) / 2,
            buttonY + (buttonHeight - Z.body) / 2, Z.body, C.gray, false)
    end
end

return M
