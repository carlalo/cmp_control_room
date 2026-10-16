local GPU = require("drivers.directgpu")
local M = {}

local function wrap(text, limit)
    local lines, line = {}, ""
    for word in tostring(text):gmatch("%S+") do
        if #line > 0 and #line + #word + 1 > limit then
            lines[#lines + 1] = line
            line = word
        else
            line = #line == 0 and word or (line .. " " .. word)
        end
    end
    if #line > 0 then lines[#lines + 1] = line end
    return lines
end

function M.render(id, w, message, data, theme)
    local C, Sx, Sy, Z = theme.colors, theme.spacingX or theme.spacing,
        theme.spacingY or theme.spacing, theme.sizes
    GPU.panel(id, w.x, w.y, w.width, w.height, C.panel, C.edge, C.redLight)
    GPU.rect(id, w.x, w.y, math.max(3, Sx.small / 2), w.height, C.redLight)
    GPU.text(id, "THIS DISPLAY COULD NOT BE RENDERED",
        w.x + Sx.medium, w.y + Sy.medium, Z.heading, C.redLight, true)

    local maxChars = math.max(20, math.floor(w.width / math.max(1, Z.body * 0.65)))
    local lines = wrap(message or "Unknown display error", maxChars)
    for index, line in ipairs(lines) do
        if index > 10 then
            GPU.text(id, "...", w.x + Sx.medium, w.y + Sy.medium + Z.heading + index * Sy.small,
                Z.body, C.gray, false)
            break
        end
        GPU.text(id, line, w.x + Sx.medium,
            w.y + Sy.medium + Z.heading + index * (Z.body + math.max(2, Sy.small / 2)),
            Z.body, C.white, false)
    end
end

return M
