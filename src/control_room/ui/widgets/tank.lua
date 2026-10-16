local GPU = require("drivers.directgpu")
local M = {}

local function formatAmount(value)
    value = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
    local text = tostring(value)
    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
    return formatted
end

function M.render(id, w, amount, data, theme)
    local C, Sx, Sy, Z = theme.colors, theme.spacingX or theme.spacing,
        theme.spacingY or theme.spacing, theme.sizes
    local x, y, width, height = w.x, w.y, w.width, w.height
    local scaleX, scaleY = w.scaleX or w.scale or 1, w.scaleY or w.scale or 1
    local function pxX(value) return math.max(1, math.floor(value * scaleX + 0.5)) end
    local function pxY(value) return math.max(1, math.floor(value * scaleY + 0.5)) end
    local insetX, insetY = Sx.medium, Sy.medium

    GPU.panel(id, x, y, width, height, C.panel, C.edge, C.redLight)
    GPU.text(id, w.label, x + insetX, y + Sy.small, Z.body, C.gray, false)

    local amountText = type(amount) == "number" and formatAmount(amount) or "--"
    GPU.text(id, amountText, x + insetX, y + pxY(42), Z.metric + pxX(3), C.white, true)
    local capacityText = "/ " .. formatAmount(data[w.capacityKey] or 0)
        .. " " .. (w.unit or "")
    local amountWidth = GPU.measureText(amountText, Z.metric + pxX(3), true)
    GPU.text(id, capacityText, x + insetX + amountWidth + pxX(12),
        y + pxY(51), Z.body + pxX(2), C.gray, false)

    local percent = math.max(0, math.min(100, tonumber(data[w.percentKey]) or 0))
    GPU.text(id, string.format("%.1f%%", percent), x + insetX, y + height - pxY(62),
        Z.heading + 3, C.redLight, true)
    local rightLabel = "TANK CAPACITY"
    GPU.text(id, rightLabel, x + width - insetX - pxX(116), y + height - pxY(60),
        Z.body, C.gray, false)

    local barX, barY = x + insetX, y + height - pxY(30)
    local barWidth = width - insetX * 2
    local barHeight = math.max(4, Sy.small)
    GPU.rect(id, barX, barY, barWidth, barHeight, C.track)
    local filled = math.floor(barWidth * percent / 100)
    if filled > 0 then GPU.rect(id, barX, barY, filled, barHeight, C.redLight) end
end

return M
