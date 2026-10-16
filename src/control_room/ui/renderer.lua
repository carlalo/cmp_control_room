local GPU = require("drivers.directgpu")

local widgets = {
    metric = require("ui.widgets.metric"),
    tank = require("ui.widgets.tank"),
    status = require("ui.widgets.status"),
    error = require("ui.widgets.error"),
    progress = require("ui.widgets.progress"),
    history = require("ui.widgets.history"),
    table = require("ui.widgets.table"),
    admin_controls = require("ui.widgets.admin_controls")
}

local Renderer = {}

-- Löst einen einfachen Schlüssel in der Datentabelle auf.
local function resolve(data, key)
    if type(data) ~= "table" or type(key) ~= "string" then
        return nil
    end

    return data[key]
end

function Renderer.renderFrame(displayId, frame, theme, displayNumber, displayWidth, displayHeight)
    assert(type(frame) == "table", "Render-Frame fehlt")
    assert(type(theme) == "table", "Theme fehlt")

    GPU.clear(displayId, theme.colors.background)

    for _, item in ipairs(frame) do
        local screen = item.screen
        local data = item.data or {}
        local scale = screen.scale or 1
        local scaledTheme = { colors = theme.colors, sizes = {}, spacing = {} }
        for key, value in pairs(theme.sizes) do
            scaledTheme.sizes[key] = math.max(1, math.floor(value * scale + 0.5))
        end
        scaledTheme.spacingX, scaledTheme.spacingY = {}, {}
        for key, value in pairs(theme.spacing) do
            scaledTheme.spacingX[key] = math.max(1, math.floor(value * (screen.scaleX or scale) + 0.5))
            scaledTheme.spacingY[key] = math.max(1, math.floor(value * (screen.scaleY or scale) + 0.5))
            scaledTheme.spacing[key] = math.max(1, math.floor(value * scale + 0.5))
        end

        if screen.title then
            GPU.text(displayId,
                "CONTROL ROOM / DISPLAY " .. string.format("%02d", displayNumber or 1),
                screen.titleX,
                screen.eyebrowY, scaledTheme.sizes.body, theme.colors.blueText, false)
        end

        -- Screen-Titel zeichnen
        if screen.title then
            GPU.text(
                displayId,
                screen.title,
                screen.titleX or theme.spacing.large,
                screen.titleY or theme.spacing.medium,
                screen.titleSize or scaledTheme.sizes.title,
                theme.colors.title or theme.colors.white,
                true
            )
        end

        if screen.headerRuleY then
            local ruleY = math.floor(screen.headerRuleY)
            local left = math.floor(screen.titleX)
            local right = math.floor(screen.width - screen.titleX)
            GPU.line(displayId, left, ruleY, right, ruleY, theme.colors.edge)
            GPU.line(displayId, left, ruleY, left + math.max(8, 24 * (screen.scaleX or scale)),
                ruleY, theme.colors.redLight)
        end

        -- Widgets zeichnen
        for _, widget in ipairs(screen.widgets or {}) do
            local implementation = widgets[widget.type]

            if implementation then
                local value
                if widget.type == "history" then
                    value = data.historyByWidget
                        and data.historyByWidget[widget.id]
                        or {}
                else
                    value = resolve(data, widget.valueKey)
                end

                implementation.render(
                    displayId,
                    widget,
                    value,
                    data,
                    scaledTheme
                )
            else
                print(
                    "Unbekannter Widget-Typ: " ..
                    tostring(widget.type)
                )
            end
        end

        if screen.playerAdmin and data.profileEditor then
            require("ui.player_editor").render(displayId, displayWidth, displayHeight,
                data.profileEditor, scaledTheme)
        end
    end

    -- Compact device signature sits in the screen margin and does not affect layout.
    if displayWidth and displayHeight then
        local footerY = displayHeight - 18
        local margin = math.max(8, math.floor(displayWidth * 0.02))
        GPU.line(displayId, margin, footerY - 5, displayWidth - margin, footerY - 5,
            theme.colors.edge)
        GPU.line(displayId, margin, footerY - 5, margin + math.max(10, displayWidth * 0.12),
            footerY - 5, theme.colors.blueText)
        GPU.text(displayId, "CONTROL ROOM  //  DISPLAY " .. string.format("%02d", displayNumber or 1),
            margin, footerY, theme.sizes.body, theme.colors.blueText, true)
        local resolution = tostring(displayWidth) .. " x " .. tostring(displayHeight) .. " PX"
        local textWidth = GPU.measureText(resolution, theme.sizes.body, true)
        GPU.text(displayId, resolution, displayWidth - margin - textWidth,
            footerY, theme.sizes.body, theme.colors.blueText, true)
    end

    GPU.present(displayId)
end

function Renderer.renderError(displayId, message, theme, displayNumber, width, height)
    local Layout = require("ui.layout")
    local definition = require("screens.error")
    local bounds = {
        x = 0, y = 0,
        width = width or definition.width,
        height = height or definition.height
    }
    local screen = Layout.transform(definition, bounds)
    Renderer.renderFrame(displayId, {
        { screen = screen, data = { message = tostring(message) }, name = "display_error" }
    }, theme, displayNumber, width, height)
end

return Renderer
