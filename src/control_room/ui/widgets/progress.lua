local GPU = require("drivers.directgpu")
local M = {}

function M.render(id, w, value, data, theme)
    local C = theme.colors

    local minValue = w.min or 0
    local maxValue = w.max or 100

    if maxValue <= minValue then
        error("Progress: max muss größer als min sein")
    end

    local percent = tonumber(value) or 0
    percent = math.max(minValue, math.min(maxValue, percent))

    local ratio = (percent - minValue) / (maxValue - minValue)

    local labelWidth = 72
    local barWidth = math.max(0, w.width - labelWidth - 8)
    local barHeight = math.max(1, w.height)

    GPU.text(
        id,
        w.label or "",
        w.x,
        w.y - theme.sizes.body - 4,
        theme.sizes.body,
        C.white,
        true
    )

    GPU.rect(
        id,
        w.x,
        w.y,
        barWidth,
        barHeight,
        C.panel
    )

    local filled = math.floor(barWidth * ratio)

    if filled > 0 then
        GPU.rect(
            id,
            w.x,
            w.y,
            filled,
            barHeight,
            w.color or C.redLight
        )
    end

    GPU.text(
        id,
        string.format("%.1f%%", percent),
        w.x + barWidth + 8,
        w.y,
        theme.sizes.body,
        C.white,
        true
    )
end

return M