local GPU = require("drivers.directgpu")
local M = {}

function M.render(id, w, online, data, theme)
    local C, Sx, Sy, Z = theme.colors, theme.spacingX or theme.spacing,
        theme.spacingY or theme.spacing, theme.sizes
    local scaleY = w.scaleY or w.scale or 1
    local function pxY(value) return math.max(1, math.floor(value * scaleY + 0.5)) end
    GPU.panel(id, w.x, w.y, w.width, w.height, C.panel, C.edge,
        online == true and C.blueText or C.redLight)
    GPU.text(id, w.label or "STATUS", w.x + Sx.medium, w.y + Sy.small,
        Z.body, C.gray, false)

    local isOnline = online == true
    GPU.text(id, isOnline and "ONLINE" or "OFFLINE",
        w.x + Sx.medium, w.y + pxY(41), Z.metric, isOnline and C.green or C.redLight, true)
    local caption = isOnline and "Sensor connected"
        or (data.error and ("Offline: " .. tostring(data.error)) or "Sensor unavailable")
    local maxChars = math.max(12,
        math.floor((w.width - Sx.medium * 2) / math.max(1, Z.body * 0.65)))
    if #caption > maxChars then caption = caption:sub(1, maxChars - 3) .. "..." end
    GPU.text(id, caption,
        w.x + Sx.medium, w.y + w.height - pxY(20), Z.body, C.gray, false)
end

return M
