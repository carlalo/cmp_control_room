local GPU = require("drivers.directgpu")

local M = {}

local function wrapText(text, width, size)
    text = tostring(text or "")
    if width <= 0 then return { "" } end

    local lines, current = {}, ""
    local function push()
        if current ~= "" then
            lines[#lines + 1] = current
            current = ""
        end
    end

    for word in text:gmatch("%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if GPU.measureText(candidate, size, false) <= width then
            current = candidate
        else
            push()
            if GPU.measureText(word, size, false) <= width then
                current = word
            else
                local position = 1
                while position <= #word do
                    local firstByte = word:byte(position)
                    local charLength = firstByte >= 240 and 4
                        or firstByte >= 224 and 3
                        or firstByte >= 192 and 2 or 1
                    local char = word:sub(position, position + charLength - 1)
                    if current ~= "" and GPU.measureText(current .. char, size, false) > width then
                        push()
                    end
                    current = current .. char
                    position = position + charLength
                end
            end
        end
    end
    push()
    if #lines == 0 then lines[1] = "" end
    return lines
end

function M.compute(widget, rows, widths, availableHeight, baseHeight, body, smallX, smallY)
    local columns = widget.columns or {}
    local lineHeight = body + math.max(1, math.floor(smallY / 2))
    local rowLayouts, pages = {}, {}

    for rowIndex, row in ipairs(rows) do
        local cells, lineCount = {}, 1
        for columnIndex, column in ipairs(columns) do
            if column.wrap then
                local value = row[column.key]
                local lines = wrapText(value == nil and "--" or tostring(value),
                    math.max(1, widths[columnIndex] - smallX), body)
                cells[columnIndex] = lines
                lineCount = math.max(lineCount, #lines)
            end
        end
        rowLayouts[rowIndex] = {
            height = math.max(baseHeight, lineCount * lineHeight + 4),
            cells = cells
        }
    end

    local currentPage, usedHeight = {}, 0
    for rowIndex, layout in ipairs(rowLayouts) do
        if #currentPage > 0 and usedHeight + layout.height > availableHeight then
            pages[#pages + 1] = currentPage
            currentPage, usedHeight = {}, 0
        end
        currentPage[#currentPage + 1] = rowIndex
        usedHeight = usedHeight + layout.height
    end
    if #currentPage > 0 then pages[#pages + 1] = currentPage end
    if #pages == 0 then pages[1] = {} end

    return { rows = rowLayouts, pages = pages, lineHeight = lineHeight }
end

return M
