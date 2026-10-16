
local Layout = {}

local function copyWidget(widget)
    local result = {}

    for key, value in pairs(widget) do
        result[key] = value
    end

    return result
end

-- Berechnet die Skalierung fÃ¼r ein einzelnes Screen-Layout.
function Layout.fullscreen(screen, width, height)
    local referenceWidth = screen.width or 800
    local referenceHeight = screen.height or 450

    local scale = math.min(
        width / referenceWidth,
        height / referenceHeight
    )

    return {
        scale = scale,
        offsetX = (width - referenceWidth * scale) / 2,
        offsetY = (height - referenceHeight * scale) / 2,
        width = referenceWidth,
        height = referenceHeight
    }
end

-- Transformiert Widgets in Display-Koordinaten.
function Layout.transform(screen, bounds)
    assert(bounds.width > 0 and bounds.height > 0,
    "Layout-Bounds mÃ¼ssen grÃ¶ÃŸer als 0 sein")

    local referenceWidth = screen.width or 800
    local referenceHeight = screen.height or 450

    local scaleX = bounds.width / referenceWidth
    local scaleY = bounds.height / referenceHeight
    local fontScale = math.min(scaleX, scaleY)
    local offsetX, offsetY = bounds.x, bounds.y

    local result = {
    title = screen.title,
    playerAdmin = screen.playerAdmin,
    eyebrow = nil,
    titleX = offsetX + 24 * scaleX,
    eyebrowY = offsetY + 8 * scaleY,
    titleY = offsetY + 32 * scaleY,
    titleSize = (screen.titleSize or 25) * fontScale,
    headerRuleY = offsetY + 76 * scaleY,
    widgets = {},
    scale = fontScale,
    scaleX = scaleX,
    scaleY = scaleY,
    width = bounds.width,
    height = bounds.height
}

    for _, widget in ipairs(screen.widgets or {}) do
        local item = copyWidget(widget)

        item.x = offsetX + (widget.x or 0) * scaleX
        item.y = offsetY + (widget.y or 0) * scaleY
        item.width = (widget.width or 0) * scaleX
        item.height = (widget.height or 0) * scaleY
        item.scale = fontScale
        item.scaleX = scaleX
        item.scaleY = scaleY

        -- Renderer erhÃ¤lt skalierte SchriftgrÃ¶ÃŸen, sofern gesetzt.
        if widget.fontSize then
            item.fontSize = widget.fontSize * fontScale
        end

        table.insert(result.widgets, item)
    end

    return result
end

-- Teilt ein Display in gleich groÃŸe Kacheln auf.
function Layout.grid(width, height, count, columns, gap, padding)
    assert(count >= 1, "Grid benÃ¶tigt mindestens eine Kachel")

    columns = math.max(1, math.min(columns or 2, count))
    gap = gap or 16
    padding = padding or 16
    local rows = math.ceil(count / columns)

    assert(width > 0 and height > 0, "Display resolution must be positive")
    assert(
        width - 2 * padding - (columns - 1) * gap > 0
            and height - 2 * padding - (rows - 1) * gap > 0,
        "Grid spacing is too large for the display"
    )

    local availableWidth =
        width - 2 * padding - (columns - 1) * gap

    local availableHeight =
        height - 2 * padding - (rows - 1) * gap

    local cellWidth = availableWidth / columns
    local cellHeight = availableHeight / rows

    local result = {}

    for i = 1, count do
        local column = (i - 1) % columns
        local row = math.floor((i - 1) / columns)

        result[i] = {
            x = padding + column * (cellWidth + gap),
            y = padding + row * (cellHeight + gap),
            width = cellWidth,
            height = cellHeight
        }
    end

    return result
end

return Layout
