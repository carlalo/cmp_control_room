local GPU = require("drivers.directgpu")
local M = {}

local fields = {
    { key = "baseLocation", label = "BASE / LOCATION" },
    { key = "party", label = "PARTY" },
    { key = "notes", label = "NOTES" },
    { key = "accessStatus", label = "ACCESS STATUS" }
}

local function geometry(width, height)
    local card = { x = width * 0.05, y = height * 0.04, w = width * 0.90, h = height * 0.92 }
    local fieldX, fieldW = width * 0.09, width * 0.82
    local fieldY, fieldH, fieldGap = height * 0.14, height * 0.07, height * 0.012
    local keyboardY, keyH = height * 0.49, height * 0.052
    local keyGap = height * 0.009
    return card, fieldX, fieldW, fieldY, fieldH, fieldGap, keyboardY, keyH, keyGap
end

function M.render(id, width, height, editor, theme)
    local C, Z = theme.colors, theme.sizes
    GPU.rect(id, 0, 0, width, height, C.background)
    local card, fieldX, fieldW, fieldY, fieldH, fieldGap, keyboardY, keyH, keyGap =
        geometry(width, height)
    GPU.panel(id, card.x, card.y, card.w, card.h, C.panel, C.edge, C.blueText)
    GPU.text(id, "EDIT PLAYER PROFILE", fieldX, height * 0.075,
        Z.title, C.white, true)
    GPU.text(id, tostring(editor.name or editor.id or "Player"), fieldX,
        height * 0.115, Z.body, C.blueText, false)

    for index, field in ipairs(fields) do
        local y = fieldY + (index - 1) * (fieldH + fieldGap)
        local active = editor.focus == field.key
        GPU.panel(id, fieldX, y, fieldW, fieldH,
            active and C.track or C.background,
            active and C.blueText or C.edge, active and C.redLight or C.blueText)
        GPU.text(id, field.label, fieldX + width * 0.012, y + height * 0.008,
            math.max(9, Z.body * 0.78), C.blueText, true)
        GPU.text(id, tostring(editor[field.key] or ""), fieldX + width * 0.012,
            y + height * 0.035, Z.body, C.white, false)
    end

    local rows = { "1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM-_" }
    local keyX, keyW = width * 0.09, width * 0.082
    for rowIndex, row in ipairs(rows) do
        local y = keyboardY + (rowIndex - 1) * (keyH + keyGap)
        for index = 1, #row do
            local x = keyX + (index - 1) * (keyW + width * 0.006)
            local label = row:sub(index, index)
            GPU.panel(id, x, y, keyW, keyH, C.background, C.edge, C.blueText)
            local labelWidth = GPU.measureText(label, Z.body, true)
            GPU.text(id, label, x + (keyW - labelWidth) / 2,
                y + (keyH - Z.body) / 2, Z.body, C.white, true)
        end
    end

    local actionY = keyboardY + 4 * (keyH + keyGap)
    local actions = {
        { label = "SPACE", x = width * 0.09, w = width * 0.24 },
        { label = "BACKSPACE", x = width * 0.35, w = width * 0.27 },
        { label = "CLEAR", x = width * 0.64, w = width * 0.27 }
    }
    for _, action in ipairs(actions) do
        GPU.panel(id, action.x, actionY, action.w, keyH, C.background, C.edge, C.blueText)
        local labelWidth = GPU.measureText(action.label, Z.body, true)
        GPU.text(id, action.label, action.x + (action.w - labelWidth) / 2,
            actionY + (keyH - Z.body) / 2, Z.body, C.white, true)
    end

    local buttonY, buttonH = height * 0.88, height * 0.055
    local buttons = {
        { label = "SAVE PROFILE", x = width * 0.09, w = width * 0.40 },
        { label = "CANCEL", x = width * 0.51, w = width * 0.40 }
    }
    for _, button in ipairs(buttons) do
        GPU.panel(id, button.x, buttonY, button.w, buttonH,
            button.label == "SAVE PROFILE" and C.blue or C.background,
            C.edge, C.blueText)
        local labelWidth = GPU.measureText(button.label, Z.body, true)
        GPU.text(id, button.label, button.x + (button.w - labelWidth) / 2,
            buttonY + (buttonH - Z.body) / 2, Z.body, C.white, true)
    end
end

function M.handleTouch(width, height, editor, x, y)
    local _, fieldX, fieldW, fieldY, fieldH, fieldGap, keyboardY, keyH, keyGap =
        geometry(width, height)
    for index, field in ipairs(fields) do
        local top = fieldY + (index - 1) * (fieldH + fieldGap)
        if x >= fieldX and x <= fieldX + fieldW and y >= top and y <= top + fieldH then
            if field.key == "accessStatus" then
                local statuses = { "UNLISTED", "WHITELISTED", "BLACKLISTED" }
                local current = editor.accessStatus or statuses[1]
                for i, status in ipairs(statuses) do
                    if status == current then
                        editor.accessStatus = statuses[i % #statuses + 1]
                        return "changed"
                    end
                end
                editor.accessStatus = statuses[1]
            else
                editor.focus = field.key
            end
            return "changed"
        end
    end

    if not editor.focus then editor.focus = "baseLocation" end
    local rowText = { "1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM-_" }
    local keyX, keyW = width * 0.09, width * 0.082
    for rowIndex, row in ipairs(rowText) do
        local top = keyboardY + (rowIndex - 1) * (keyH + keyGap)
        for index = 1, #row do
            local left = keyX + (index - 1) * (keyW + width * 0.006)
            if x >= left and x <= left + keyW and y >= top and y <= top + keyH then
                editor[editor.focus] = (editor[editor.focus] or "") .. row:sub(index, index)
                return "changed"
            end
        end
    end

    local actionY = keyboardY + 4 * (keyH + keyGap)
    if y >= actionY and y <= actionY + keyH then
        if x >= width * 0.09 and x <= width * 0.33 then
            editor[editor.focus] = (editor[editor.focus] or "") .. " "
            return "changed"
        elseif x >= width * 0.35 and x <= width * 0.62 then
            local value = editor[editor.focus] or ""
            editor[editor.focus] = value:sub(1, -2)
            return "changed"
        elseif x >= width * 0.64 and x <= width * 0.91 then
            editor[editor.focus] = ""
            return "changed"
        end
    end

    local buttonY, buttonH = height * 0.88, height * 0.055
    if y >= buttonY and y <= buttonY + buttonH then
        if x >= width * 0.09 and x <= width * 0.49 then return "save" end
        if x >= width * 0.51 and x <= width * 0.91 then return "cancel" end
    end
end

return M
