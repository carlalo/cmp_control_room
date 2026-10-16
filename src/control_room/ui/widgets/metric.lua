local GPU = require("drivers.directgpu")
local M = {}

function M.render(id, w, value, data, theme)
    local C, Sx, Sy, Z = theme.colors, theme.spacingX or theme.spacing,
        theme.spacingY or theme.spacing, theme.sizes
    local scaleY = w.scaleY or w.scale or 1
    local function pxY(value) return math.max(1, math.floor(value * scaleY + 0.5)) end
    GPU.panel(id, w.x, w.y, w.width, w.height, C.panel, C.edge, C.blueText)
    GPU.text(id, w.label or w.id, w.x + Sx.medium, w.y + Sy.small,
        Z.body, C.gray, false)

    local shown
    if type(value) == "number" then
        shown = string.format("%.1f", value)
    else
        shown = w.placeholder and ("— " .. (w.unit or "")) or "--"
    end
    if type(value) == "number" and w.unit then shown = shown .. " " .. w.unit end

    GPU.text(id, shown, w.x + Sx.medium, w.y + pxY(43), Z.metric, C.white, true)
    if w.placeholder and type(value) ~= "number" then
        GPU.text(id, w.placeholder, w.x + Sx.medium, w.y + w.height - pxY(20),
            Z.body, C.gray, false)
    end
end

return M
