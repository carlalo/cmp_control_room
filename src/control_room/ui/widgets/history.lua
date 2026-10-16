local GPU = require("drivers.directgpu")
local M = {}

local function round(value)
    return math.floor(value + 0.5)
end

function M.render(id, w, points, data, theme)
    local C = theme.colors
    local Sx, Sy = theme.spacingX or theme.spacing, theme.spacingY or theme.spacing
    local Z = theme.sizes
    points = type(points) == "table" and points or {}

    local x, y, width, height = w.x, w.y, w.width, w.height
    GPU.panel(id, x, y, width, height, C.panel, C.edge, C.blueText)
    GPU.text(id, w.label or "HISTORY", x + Sx.medium, y + Sy.small,
        Z.heading, C.white, true)
    if w.range then
        GPU.text(id, w.range, x + width - Sx.medium - 116, y + Sy.small,
            Z.body, C.gray, false)
    end

    local axisWidth = math.max(Sx.large * 2, Z.body * 4)
    local bottomLabels = Sy.large + Z.body
    local gx = x + Sx.medium + axisWidth
    local gy = y + Sy.medium + Z.heading + Sy.small
    local gw = width - Sx.medium * 2 - axisWidth
    local gh = height - (gy - y) - bottomLabels

    local capacity = tonumber(data[w.capacityKey or "capacity"])
    for i = 0, 4 do
        local ratio = i / 4
        local lineY = gy + math.floor(gh * ratio)
        GPU.rect(id, gx, lineY, gw, 1, C.blue)
        if capacity and capacity > 0 then
            GPU.text(id, tostring(100 - i * 25) .. "%",
                x + Sx.small, math.max(gy, lineY - math.floor(Z.body / 2)),
                Z.body, C.gray, false)
        end
    end

    local durationSeconds = w.duration or 60
    local durationMs = durationSeconds * 1000
    local now = os.epoch("utc")
    local startTime = now - durationMs
    local function formatOffset(seconds)
        if seconds >= 60 and seconds % 60 == 0 then
            return tostring(math.floor(seconds / 60)) .. "m"
        end
        return tostring(seconds) .. "s"
    end
    for i = 0, 4 do
        local ratio = i / 4
        local secondsAgo = math.floor(durationSeconds * (1 - ratio) + 0.5)
        local label = secondsAgo == 0 and "now" or ("-" .. formatOffset(secondsAgo))
        local labelWidth = GPU.measureText(label, Z.body, false)
        local labelX = gx + math.floor(ratio * gw - labelWidth / 2)
        labelX = math.max(gx, math.min(gx + gw - labelWidth, labelX))
        GPU.text(id, label, labelX, gy + gh + Sy.small,
            Z.body, C.gray, false)
    end

    local valid = {}
    local minValue, maxValue
    for _, point in ipairs(points) do
        if type(point) == "table" and type(point.value) == "number"
            and type(point.time) == "number" then
            valid[#valid + 1] = point
            minValue = minValue and math.min(minValue, point.value) or point.value
            maxValue = maxValue and math.max(maxValue, point.value) or point.value
        end
    end

    if #valid == 0 then
        GPU.text(id, "Collecting history...",
            gx + Sx.small, gy + math.floor(gh / 2), Z.body, C.gray, false)
        return
    end

    if capacity and capacity > 0 then
        minValue, maxValue = 0, capacity
    elseif minValue == maxValue then
        local padding = math.max(math.abs(minValue) * 0.03, 1)
        minValue, maxValue = minValue - padding, maxValue + padding
    else
        local padding = (maxValue - minValue) * 0.08
        minValue, maxValue = minValue - padding, maxValue + padding
    end

    local plotPoints = {}
    local lastPoint

    for _, point in ipairs(valid) do
        local timeRatio = (point.time - startTime) / durationMs
        local valueRatio = (point.value - minValue) / (maxValue - minValue)
        local current = {
            gx + round(math.max(0, math.min(1, timeRatio)) * gw),
            gy + gh - round(math.max(0, math.min(1, valueRatio)) * gh)
        }
        plotPoints[#plotPoints + 1] = current
        lastPoint = current
    end

    if #plotPoints >= 2 then
        GPU.polyline(id, plotPoints, C.redLight)
    end
    if lastPoint then
        local marker = math.max(3, math.floor(Z.body * 0.45))
        GPU.rect(id, lastPoint[1] - math.floor(marker / 2),
            lastPoint[2] - math.floor(marker / 2), marker, marker, C.redLight)
    end

    if #valid < 2 then
        GPU.text(id, "Collecting history...",
            gx + Sx.small, gy + math.floor(gh / 2), Z.body, C.gray, false)
    end
end

return M
