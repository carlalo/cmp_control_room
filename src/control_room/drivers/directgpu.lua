local theme = require("config.theme")


local M = {}


local gpu
local font = theme.font

local function pixel(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

function M.init()
    gpu = peripheral.find("directgpu")
    if not gpu then
        error("DirectGPU nicht gefunden")
    end

    local displays = gpu.listDisplays()
    if type(displays) ~= "table" then
        error("DirectGPU liefert keine Display-Liste")
    end

    return displays
end

function M.getDisplays()
    assert(gpu, "DirectGPU wurde noch nicht initialisiert")
    local displays = gpu.listDisplays()
    assert(type(displays) == "table", "DirectGPU liefert keine Display-Liste")
    return displays
end

-- Erstellt Displays nur auf expliziten Aufruf. Die App ruft das nur auf,
-- wenn die GPU aktuell gar keine Displays besitzt.
function M.createDisplays(count)
    assert(gpu, "DirectGPU wurde noch nicht initialisiert")
    assert(type(count) == "number" and count >= 1,
        "Anzahl der Displays muss mindestens 1 sein")

    if type(gpu.autoDetectAndCreateDisplays) == "function" then
        gpu.autoDetectAndCreateDisplays(count)
    elseif type(gpu.autoDetectAndCreateDisplay) == "function" then
        for _ = 1, count do
            local before = M.getDisplays()
            local known = {}
            for _, id in ipairs(before) do known[id] = true end
            gpu.autoDetectAndCreateDisplay()
            local after = M.getDisplays()
            local added = false
            for _, id in ipairs(after) do
                if not known[id] then added = true break end
            end
            if not added then break end
        end
    else
        error("DirectGPU unterstützt keine automatische Display-Erkennung")
    end
    return M.getDisplays()
end

function M.shutdown()
    if not gpu then return end

    local displays = gpu.listDisplays()
    if type(displays) ~= "table" then
        print("DirectGPU Shutdown: Display-Liste konnte nicht gelesen werden")
        return
    end

    for _, displayId in ipairs(displays) do
        local ok, result = pcall(gpu.removeDisplay, displayId)
        if not ok or result == false then
            print("DirectGPU Shutdown: Display " .. tostring(displayId)
                .. " konnte nicht entfernt werden: " .. tostring(result))
        else
            print("DirectGPU Shutdown: Display " .. tostring(displayId) .. " entfernt")
        end
    end
end

function M.setFont(value)
    font = value or theme.font
end

function M.clear(id, color)
    gpu.clear(id, color[1], color[2], color[3])
end

function M.rect(id, x, y, w, h, color)
    local left, top = pixel(x), pixel(y)
    local right, bottom = pixel(x + w), pixel(y + h)
    gpu.fillRect(id, left, top, math.max(1, right - left), math.max(1, bottom - top),
        color[1], color[2], color[3])
end

-- Futuristic panel with clipped corners and colored edge accents.
function M.panel(id, x, y, w, h, fill, edge, accent)
    M.rect(id, x, y, w, h, fill)
    if w < 8 or h < 8 then return end
    edge, accent = edge or {12, 62, 91}, accent or theme.colors.blueText
    local cut = math.max(4, math.min(14, math.floor(math.min(w, h) * 0.08)))
    M.line(id, x + cut, y, x + w - cut, y, edge)
    M.line(id, x + w, y + cut, x + w, y + h - cut, edge)
    M.line(id, x + w - cut, y + h, x + cut, y + h, edge)
    M.line(id, x, y + h - cut, x, y + cut, edge)
    M.line(id, x + cut, y, x, y + cut, accent)
    M.line(id, x + w - cut, y, x + w, y + cut, accent)
    M.line(id, x + w, y + h - cut, x + w - cut, y + h, accent)
    M.line(id, x + cut, y + h, x, y + h - cut, accent)
end

function M.line(id, x1, y1, x2, y2, color)
    gpu.drawLine(id, pixel(x1), pixel(y1), pixel(x2), pixel(y2),
        color[1], color[2], color[3])
end

function M.polyline(id, points, color)
    if #points < 2 then return end
    local pixelPoints = {}
    for index, point in ipairs(points) do
        pixelPoints[index] = { pixel(point[1]), pixel(point[2]) }
    end
    if type(gpu.drawPolylines) == "function" then
        gpu.drawPolylines(id, pixelPoints, color[1], color[2], color[3])
        return
    end
    for i = 2, #pixelPoints do
        local a, b = pixelPoints[i - 1], pixelPoints[i]
        M.line(id, a[1], a[2], b[1], b[2], color)
    end
end

function M.text(id, value, x, y, size, color, bold)
    gpu.drawText(
        id, tostring(value), pixel(x), pixel(y),
        color[1], color[2], color[3],
        font, math.max(1, pixel(size)), bold and "bold" or "plain"
    )
end

function M.measureText(value, size, bold)
    local text = tostring(value)
    if type(gpu.measureText) == "function" then
        local ok, measured = pcall(
            gpu.measureText, text, font, size, bold and "bold" or "plain"
        )
        if ok and type(measured) == "table" and type(measured.width) == "number" then
            return measured.width
        end
        if not ok and tostring(measured) == "Terminated" then error(measured, 0) end
    end
    -- Fallback, falls diese DirectGPU-Version measureText nicht bereitstellt.
    return #text * size * 0.6
end

function M.present(id)
    gpu.updateDisplay(id)
end

function M.hasEvents(id)
    return type(gpu.hasEvents) == "function" and gpu.hasEvents(id) or false
end

function M.pollEvent(id)
    if type(gpu.pollEvent) ~= "function" then return nil end
    return gpu.pollEvent(id)
end

function M.supportsTouch()
    return gpu ~= nil and type(gpu.hasEvents) == "function"
        and type(gpu.pollEvent) == "function"
end

-- Ermittelt die Pixelauflösung eines Displays.
function M.getDisplaySize(id)
    local info = gpu.getDisplayInfo(id)

    if not M._displayInfoPrinted then
        M._displayInfoPrinted = true
        print("DirectGPU getDisplayInfo(" .. tostring(id) .. "):")
        if textutils and textutils.serialize then
            print(textutils.serialize(info))
        else
            print(tostring(info))
        end
    end

    assert(
        type(info) == "table",
        "Keine Display-Informationen für ID " .. tostring(id)
    )

    -- Unterstützt übliche Feldnamen, abhängig von der API-Version.
    -- DirectGPU liefert neben Pixelmaßen auch Blockmaße (width/height).
    -- Für Layout und draw-Koordinaten müssen die Pixelwerte Vorrang haben.
    local width = info.pixelWidth or info.width
    local height = info.pixelHeight or info.height

    -- Manche APIs gruppieren die Auflösung in einer Tabelle.
    if type(info.resolution) == "table" then
        width = width or info.resolution.width
        height = height or info.resolution.height
    end

    assert(
        type(width) == "number" and type(height) == "number",
        "Display-Auflösung konnte nicht erkannt werden. " ..
        "Bitte getDisplayInfo(" .. tostring(id) .. ") prüfen."
    )

    return width, height
end

return M
