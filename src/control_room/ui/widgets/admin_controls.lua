local GPU = require("drivers.directgpu")
local M = {}

function M.render(id, widget, _, data, theme)
    local labels = { "EDIT PROFILE", "PREVIOUS", "NEXT" }
    local fractions = { 0.50, 0.22, 0.22 }
    local gaps = widget.width * 0.02
    local x = widget.x
    for index, label in ipairs(labels) do
        local width = widget.width * fractions[index]
        GPU.panel(id, x, widget.y, width, widget.height,
            index == 1 and theme.colors.blue or theme.colors.panel,
            theme.colors.edge, theme.colors.blueText)
        local textWidth = GPU.measureText(label, theme.sizes.body, true)
        GPU.text(id, label, x + (width - textWidth) / 2,
            widget.y + (widget.height - theme.sizes.body) / 2,
            theme.sizes.body, theme.colors.white, true)
        x = x + width + gaps
    end
end

return M
