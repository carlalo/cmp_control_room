local GPU = require("drivers.directgpu")
local Layout = require("ui.layout")
local Renderer = require("ui.renderer")
local TableLayout = require("ui.table_layout")
local History = require("core.history")
local Persistence = require("core.persistence")
local logger = require("core.log").new("screen_manager")

local M = {}
local displays = {}
local instances = {}

local function editProfile(player)
    local Database = require("core.player_database")
    local profile = Database.getProfile(player.id) or {}

    print("")
    print("Edit profile: " .. tostring(player.name or player.id))
    print("Leave blank to keep a value; enter '-' to clear it.")
    local function prompt(label, key)
        local current = tostring(profile[key] or "")
        write(label .. " [" .. (current ~= "" and current or "unset") .. "]: ")
        local value = read()
        if value == "" then return current end
        if value == "-" then return "" end
        return value
    end

    local fields = {
        baseLocation = prompt("Base/location", "baseLocation"),
        party = prompt("Party/team", "party"),
        notes = prompt("Notes", "notes"),
        accessStatus = prompt("Access (UNLISTED / WHITELISTED / BLACKLISTED)", "accessStatus")
    }
    Database.setProfile(player.id, fields)
    print("Profile saved. Returning to the display...")
end

local function playerDirectoryRows(livePlayers, now)
    local Database = require("core.player_database")
    local rows = {}
    local liveById = {}
    for _, player in ipairs(livePlayers or {}) do
        if player.id ~= nil then liveById[tostring(player.id):lower()] = player end
    end
    for id, profile in pairs(Database.getProfiles()) do
        local rowId = id
        local live = liveById[tostring(rowId):lower()]
        rows[#rows + 1] = {
            id = rowId,
            name = live and live.name or profile.name or id,
            baseLocation = profile.baseLocation or "",
            party = profile.party or "",
            notes = profile.notes or "",
            accessStatus = profile.accessStatus or "UNLISTED",
            firstSeen = profile.firstSeen,
            lastSeen = live and now or profile.lastSeen,
            observationCount = #(profile.observations or {})
        }
        if live then liveById[tostring(rowId):lower()] = nil end
    end
    -- Aktuell erkannte, noch nicht gespeicherte Personen werden nur temporÃ¤r
    -- angezeigt. Sie werden erst durch "Save Profile" in die Datenbank Ã¼bernommen.
    for _, player in pairs(liveById) do
        rows[#rows + 1] = {
            id = player.id,
            name = player.name or tostring(player.id),
            baseLocation = "",
            party = "",
            notes = "",
            accessStatus = "UNLISTED",
            lastSeen = now,
            observationCount = 0
        }
    end
    table.sort(rows, function(a, b)
        local aName, bName = tostring(a.name):lower(), tostring(b.name):lower()
        if aName == bName then return tostring(a.id) < tostring(b.id) end
        return aName < bName
    end)
    return rows
end

local function refreshDirectory(instance, livePlayers, now)
    instance.data.playerProfiles = playerDirectoryRows(livePlayers, now)
    if instance.selectedId then
        for index, profile in ipairs(instance.data.playerProfiles) do
            if profile.id == instance.selectedId then
                instance.selectedIndex = index
            end
        end
    end
    instance.selectedIndex = math.max(1, math.min(
        #instance.data.playerProfiles, instance.selectedIndex or 1))
    instance.selectedId = instance.data.playerProfiles[instance.selectedIndex]
        and instance.data.playerProfiles[instance.selectedIndex].id or nil
end

local function copyProviderData(data)
    local copy = {}
    for key, value in pairs(data or {}) do copy[key] = value end
    if type(data and data.players) == "table" then
        copy.players = {}
        for index, player in ipairs(data.players) do
            local playerCopy = {}
            for key, value in pairs(player) do playerCopy[key] = value end
            copy.players[index] = playerCopy
        end
    end
    return copy
end

-- Observer callback. UI enrichment happens on a private copy so that rules
-- and other observers always see the original provider snapshot.
function M.onSnapshot(snapshot)
    local capturedAt = snapshot.capturedAt or os.epoch("utc")
    for name, instance in pairs(instances) do
        local source = snapshot.sources and snapshot.sources[name]
        local result = copyProviderData(source and source.data or {
            online = false, error = "Snapshot source missing: " .. name
        })

        instance.data = result
        if instance.providerType == "radar" then
            if result.online ~= false then
                local PlayerDatabase = require("core.player_database")
                for _, player in ipairs(result.players or {}) do
                    local profile = PlayerDatabase.getProfile(player.id)
                    if profile then
                        player.baseLocation = profile.baseLocation
                        player.party = profile.party
                        player.notes = profile.notes
                        player.accessStatus = profile.accessStatus or "UNLISTED"
                        player.firstSeen = profile.firstSeen
                        player.lastSeen = profile.lastSeen
                    else
                        player.accessStatus = "UNLISTED"
                    end
                end
            end
            refreshDirectory(instance, result.players, capturedAt)
        end

        if result.online == false then
            instance.lastError = result.error or "Peripheral offline"
            if not instance.errorLogged then
                logger.warn("Provider offline [" .. name .. "]: " .. tostring(instance.lastError))
                instance.errorLogged = true
            end
        else
            instance.lastError = nil
            if instance.errorLogged then
                logger.info("Provider wieder online [" .. name .. "]")
                instance.errorLogged = nil
            end
        end
        for _, history in pairs(instance.histories) do
            if result.online ~= false then
                history.sampler:add(result[history.sourceKey], capturedAt)
            end
        end
    end
end

function M.handleEvent(event, keyCode)
    if event ~= "key" or not keys then return end
    for _, instance in pairs(instances) do
        if instance.screen.playerAdmin then
            local players = instance.data.playerProfiles or {}
            local count = #players
            if keyCode == keys.up then
                instance.selectedIndex = math.max(1, (instance.selectedIndex or 1) - 1)
                instance.selectedId = players[instance.selectedIndex]
                    and players[instance.selectedIndex].id or instance.selectedId
            elseif keyCode == keys.down then
                instance.selectedIndex = math.min(count,
                    (instance.selectedIndex or 1) + 1)
                instance.selectedId = players[instance.selectedIndex]
                    and players[instance.selectedIndex].id or instance.selectedId
            elseif keyCode == keys.enter and count > 0 then
                local selected = players[math.max(1, math.min(count,
                    instance.selectedIndex or 1))]
                if selected then
                    instance.selectedId = selected.id
                    editProfile(selected)
                end
            end
        end
    end
end

local function profileEditorFor(player)
    local Database = require("core.player_database")
    local profile = Database.getProfile(player.id) or {}
    return {
        id = player.id,
        name = player.name or profile.name or tostring(player.id),
        persistName = profile.name == nil,
        baseLocation = profile.baseLocation or player.baseLocation or "",
        party = profile.party or player.party or "",
        notes = profile.notes or player.notes or "",
        accessStatus = profile.accessStatus or player.accessStatus or "UNLISTED",
        focus = "baseLocation"
    }
end

local function contains(x, y, box)
    return x >= box.x and y >= box.y and x <= box.x + box.width
        and y <= box.y + box.height
end

local function tableRows(instance, widget)
    if widget.valueKey == "visitorHistory" then
        return Persistence.getVisitorRows(instance.name, os.epoch("utc"),
            instance.data.online ~= false)
    end
    local rows = instance.data[widget.valueKey]
    return type(rows) == "table" and rows or {}
end

local function tableMetrics(screen, widget, rows)
    local theme = require("config.theme")
    local function scaled(value, scale)
        return math.max(1, math.floor(value * scale + 0.5))
    end
    local sx, sy = screen.scaleX or 1, screen.scaleY or 1
    local sf = screen.scale or 1
    local smallX = scaled(theme.spacing.small, sx)
    local smallY = scaled(theme.spacing.small, sy)
    local mediumX = scaled(theme.spacing.medium, sx)
    local body = scaled(theme.sizes.body, sf)
    local heading = scaled(theme.sizes.heading, sf)
    local headerY = widget.y + smallY + heading + smallY
    if widget.hint then headerY = headerY + body + smallY end
    local rowsY = headerY + body + smallY
    local rowScale = widget.scaleY or widget.scale or 1
    local rowHeight = math.max(18, math.floor(
        (widget.rowHeight or (body + smallY)) * rowScale + 0.5))
    local footer = widget.scrollable and (body + smallY * 2) or 0
    local visible = math.max(0, math.floor((widget.y + widget.height - smallY
        - rowsY - footer) / rowHeight))
    local pageCount
    if widget.autoRowHeight then
        local columns = widget.columns or {}
        local totalWeight = 0
        for _, column in ipairs(columns) do
            totalWeight = totalWeight + (tonumber(column.weight) or 1)
        end
        if totalWeight <= 0 then totalWeight = math.max(1, #columns) end
        local innerWidth = widget.width - mediumX * 2
        local widths, xPosition = {}, 0
        for index, column in ipairs(columns) do
            local weight = tonumber(column.weight) or 1
            widths[index] = index == #columns
                and (innerWidth - xPosition)
                or (innerWidth * weight / totalWeight)
            xPosition = xPosition + widths[index]
        end
        local availableHeight = widget.y + widget.height - smallY - rowsY - footer
        local layout = TableLayout.compute(widget, rows or {}, widths, availableHeight,
            rowHeight, body, smallX, smallY)
        pageCount = #layout.pages
    end
    return {
        rowsY = rowsY,
        rowHeight = rowHeight,
        visible = visible,
        smallX = smallX,
        smallY = smallY,
        body = body,
        autoRowHeight = widget.autoRowHeight == true,
        pageCount = pageCount or math.max(1, math.ceil(#(rows or {}) / math.max(1, visible)))
    }
end

function M.handleTouch(displayId, event)
    if type(event) ~= "table" then return end
    local isClick = event.type == "mouse_click"
    local isWheel = event.type == "mouse_scroll" or event.type == "mouse_wheel"
        or event.type == "mouse_wheel_scroll" or event.type == "scroll"
        or event.type == "wheel"
    if not isClick and not isWheel then return end
    local x = event.x or event.mouseX
    local y = event.y or event.mouseY
    if type(x) ~= "number" or type(y) ~= "number" then return end
    local display = displays[displayId]
    if not display then return end

    for _, instance in ipairs(display.instances) do
        if instance.renderScreen then
            local screen = instance.renderScreen
            if isClick then
                for _, widget in ipairs(screen.widgets or {}) do
                    if widget.type == "table" and widget.scrollable
                        and contains(x, y, widget) then
                        local rows = tableRows(instance, widget)
                        local metrics = tableMetrics(screen, widget, rows)
                        local visible = math.max(1, metrics.visible)
                        if (metrics.autoRowHeight and metrics.pageCount > 1)
                            or (not metrics.autoRowHeight and #rows > visible) then
                            local buttonWidth = math.max(26, metrics.body * 2)
                            local buttonHeight = metrics.body + metrics.smallY
                            local buttonY = widget.y + widget.height
                                - metrics.smallY - buttonHeight
                            local leftX = widget.x + metrics.smallX
                            local rightX = widget.x + widget.width - metrics.smallX - buttonWidth
                            if y >= buttonY and y <= buttonY + buttonHeight then
                                local step
                                if x >= leftX and x <= leftX + buttonWidth then step = -1 end
                                if x >= rightX and x <= rightX + buttonWidth then step = 1 end
                                if step then
                                    if widget.selectable then
                                        instance.selectedIndex = math.max(1, math.min(#rows,
                                            (instance.selectedIndex or 1) + step * visible))
                                        instance.selectedId = rows[instance.selectedIndex]
                                            and rows[instance.selectedIndex].id or nil
                                    else
                                        instance.tableOffsets = instance.tableOffsets or {}
                                        local maxPage = metrics.autoRowHeight
                                            and (metrics.pageCount - 1)
                                            or math.max(0, math.ceil(#rows / visible) - 1)
                                        instance.tableOffsets[widget.id] = math.max(0,
                                            math.min(maxPage, (instance.tableOffsets[widget.id]
                                                or 0) + step))
                                    end
                                    return
                                end
                            end
                        end
                    end
                end
            end
            if isWheel then
                if instance.profileEditor then return end
                local direction = event.direction or event.scrollDirection or event.delta
                    or event.scroll or event.scrollY or event.deltaY or event.dy
                    or event.wheelDelta
                local step
                if direction == "down" then step = 1
                elseif direction == "up" then step = -1
                elseif type(direction) == "number" then step = direction > 0 and 1 or -1 end
                if step then
                    for _, widget in ipairs(screen.widgets or {}) do
                        if widget.type == "table" and contains(x, y, widget) then
                            local rows = tableRows(instance, widget)
                            local metrics = tableMetrics(screen, widget, rows)
                            local visible = math.max(1, metrics.visible)
                            if widget.selectable then
                                instance.selectedIndex = math.max(1, math.min(#rows,
                                    (instance.selectedIndex or 1) + step * math.max(1,
                                        math.floor(visible / 3))))
                                instance.selectedId = rows[instance.selectedIndex]
                                    and rows[instance.selectedIndex].id or nil
                            else
                                instance.tableOffsets = instance.tableOffsets or {}
                                local maxPage = metrics.autoRowHeight
                                    and (metrics.pageCount - 1)
                                    or math.max(0, math.ceil(#rows / visible) - 1)
                                instance.tableOffsets[widget.id] = math.max(0, math.min(maxPage,
                                    (instance.tableOffsets[widget.id] or 0) + step))
                            end
                            return
                        end
                    end
                end
            end
            if isClick and instance.screen.playerAdmin then
                local editor = require("ui.player_editor")
                if instance.profileEditor then
                local action = editor.handleTouch(screen.width, screen.height,
                    instance.profileEditor, x, y)
                if action == "save" then
                    local state = instance.profileEditor
                    local ok, err = pcall(function()
                        require("core.player_database").setProfile(state.id, {
                            name = state.persistName and state.name or nil,
                            baseLocation = state.baseLocation,
                            party = state.party,
                            notes = state.notes,
                            accessStatus = state.accessStatus
                        })
                    end)
                    if ok then
                        instance.profileEditor = nil
                        refreshDirectory(instance, instance.data.players, os.epoch("utc"))
                    else
                        print("Profil konnte nicht gespeichert werden: " .. tostring(err))
                    end
                elseif action == "cancel" then
                    instance.profileEditor = nil
                end
                return
            end

            local tableWidget, controls
            for _, widget in ipairs(screen.widgets or {}) do
                if widget.id == "player_directory" then tableWidget = widget end
                if widget.id == "player_controls" then controls = widget end
            end
            if tableWidget and contains(x, y, tableWidget) then
                local metrics = tableMetrics(screen, tableWidget)
                local visible = math.max(1, metrics.visible)
                local players = instance.data.playerProfiles or {}
                local first = math.floor(math.max(0, (instance.selectedIndex or 1) - 1) / visible)
                    * visible + 1
                local index = first + math.floor((y - metrics.rowsY) / metrics.rowHeight)
                if y >= metrics.rowsY and index <= math.min(#players, first + visible - 1) then
                    instance.selectedIndex = index
                    instance.selectedId = players[index] and players[index].id
                end
                return
            end

            if controls and contains(x, y, controls) then
                local relativeX = x - controls.x
                local players = instance.data.playerProfiles or {}
                local count = #players
                if relativeX <= controls.width * 0.50 then
                    local selected = players[instance.selectedIndex or 1]
                    if selected then instance.profileEditor = profileEditorFor(selected) end
                elseif relativeX >= controls.width * 0.76 then
                    instance.selectedIndex = math.min(count, (instance.selectedIndex or 1) + 1)
                else
                    instance.selectedIndex = math.max(1, (instance.selectedIndex or 1) - 1)
                end
                instance.selectedId = players[instance.selectedIndex]
                    and players[instance.selectedIndex].id or nil
                return
            end
            end
        end
    end
end

function M.loadConfig(config)
    assert(type(config) == "table", "Layout-Konfiguration fehlt")
    displays, instances = {}, {}
    local providerDefinitions = config.providers or {}

    for displayNumber, definition in ipairs(config.displays or {}) do
        assert(definition.mode == "fullscreen" or definition.mode == "grid",
            "UngÃ¼ltiger Display-Modus: " .. tostring(definition.mode))
        assert(type(definition.id) == "number", "Display-ID muss numerisch sein")
        assert(not displays[definition.id], "Doppelte Display-ID: " .. tostring(definition.id))

        local display = {
            id = definition.id,
            number = displayNumber,
            mode = definition.mode,
            grid = definition.grid or {},
            instances = {}
        }
        displays[definition.id] = display

        local definitions = definition.instances or {}
        if definition.mode == "fullscreen" then
            assert(#definitions == 1, "Fullscreen benÃ¶tigt genau eine Instanz pro Display")
        else
            assert(#definitions > 0, "Grid benÃ¶tigt mindestens eine Instanz")
        end

        for _, instanceDefinition in ipairs(definitions) do
            assert(type(instanceDefinition.name) == "string" and instanceDefinition.name ~= "",
                "Instanzname fehlt")
            assert(not instances[instanceDefinition.name],
                "Doppelter Instanzname: " .. instanceDefinition.name)
            assert(type(instanceDefinition.screen) == "string", "Screen-Name fehlt")

            local providerConfig = type(instanceDefinition.provider) == "string"
                and providerDefinitions[instanceDefinition.provider]
                or instanceDefinition.provider
            assert(type(providerConfig) == "table",
                "Provider config/reference missing for " .. instanceDefinition.name)

            local screen = require("screens." .. instanceDefinition.screen)
            if instanceDefinition.title then
                local titledScreen = {}
                for key, value in pairs(screen) do
                    titledScreen[key] = value
                end
                titledScreen.title = instanceDefinition.title
                screen = titledScreen
            end
            local instance = {
                name = instanceDefinition.name,
                screen = screen,
                providerType = providerConfig.type,
                data = {},
                histories = {},
                lastError = nil
            }

            local historyIds = {}
            for _, widget in ipairs(screen.widgets or {}) do
                if widget.type == "history" then
                    assert(type(widget.id) == "string" and widget.id ~= "",
                        "History-Widget benÃ¶tigt eine ID")
                    assert(not historyIds[widget.id],
                        "Doppelte Widget-ID im Screen: " .. widget.id)
                    assert(type(widget.sourceKey) == "string" and widget.sourceKey ~= "",
                        "History-Widget " .. widget.id .. " benÃ¶tigt sourceKey")
                    local duration = widget.duration or 3600
                    local interval = widget.sampleInterval or 5
                    assert(type(duration) == "number" and duration > 0,
                        "History duration muss positiv sein: " .. widget.id)
                    assert(type(interval) == "number" and interval > 0,
                        "History sampleInterval muss positiv sein: " .. widget.id)

                    historyIds[widget.id] = true
                    instance.histories[widget.id] = {
                        sourceKey = widget.sourceKey,
                        sampler = History.new(duration * 1000, interval * 1000)
                    }
                end
            end

            instances[instance.name] = instance
            display.instances[#display.instances + 1] = instance
        end
    end
end

function M.update(context)
    -- DirectGPU has its own touch queue per display; drain it before redrawing.
    for displayId in pairs(displays) do
        for _ = 1, 32 do
            if not GPU.hasEvents(displayId) then break end
            local event = GPU.pollEvent(displayId)
            if not event then break end
            M.handleTouch(displayId, event)
        end
    end

    -- Fehler bei AuflÃ¶sung, Layout oder Rendering isolieren wir pro Display.
    for displayId, display in pairs(displays) do
        local renderNow = os.epoch("utc")
        if not display.lastRenderedAt or renderNow - display.lastRenderedAt >= 100 then
            display.lastRenderedAt = renderNow
            local ok, err = pcall(function()
            local width, height = GPU.getDisplaySize(displayId)
            display.lastWidth, display.lastHeight = width, height
            if display.lastReportedSize == nil
                or display.lastReportedSize.width ~= width
                or display.lastReportedSize.height ~= height then
                logger.info("Display " .. tostring(displayId) .. " erkannt: "
                    .. tostring(width) .. " x " .. tostring(height) .. " Pixel")
                display.lastReportedSize = { width = width, height = height }
            end

            local boundsList
            if display.mode == "grid" then
                boundsList = Layout.grid(width, height, #display.instances,
                    display.grid.columns or 2,
                    display.grid.gap or 16,
                    display.grid.padding or 16)
            else
                boundsList = {{ x = 0, y = 0, width = width, height = height }}
            end

            local frame = {}
            for index, instance in ipairs(display.instances) do
                local renderData = {}
                for key, value in pairs(instance.data) do
                    renderData[key] = value
                end
                renderData.historyByWidget = {}
                renderData.selectedIndex = instance.selectedIndex or 1
                renderData.profileEditor = instance.profileEditor
                renderData.tableOffsets = instance.tableOffsets or {}
                for widgetId, history in pairs(instance.histories) do
                    renderData.historyByWidget[widgetId] = history.sampler:getPoints()
                end
                if instance.providerType == "radar" then
                    renderData.visitorHistory = Persistence.getVisitorRows(
                        instance.name, os.epoch("utc"), instance.data.online ~= false)
                end

                frame[#frame + 1] = {
                    screen = Layout.transform(instance.screen, boundsList[index]),
                    data = renderData,
                    name = instance.name
                }
                instance.renderScreen = frame[#frame].screen
            end
            Renderer.renderFrame(displayId, frame, context.theme, display.number, width, height)
        end)

        if not ok and tostring(err) == "Terminated" then error(err, 0) end
        if not ok then
            display.lastError = tostring(err)
            logger.error("Render-Fehler [Display " .. tostring(displayId) .. "]: " .. display.lastError)
            local fallbackOk, fallbackError = pcall(
                Renderer.renderError, displayId, display.lastError,
                context.theme, display.number,
                display.lastWidth, display.lastHeight)
            if not fallbackOk and tostring(fallbackError) == "Terminated" then
                error(fallbackError, 0)
            end
            if not fallbackOk then
                logger.error("Fehler-Screen fehlgeschlagen [Display " .. tostring(displayId)
                    .. "]: " .. tostring(fallbackError))
            end
        elseif display.lastError then
            logger.info("Display " .. tostring(displayId) .. " rendert wieder normal")
            display.lastError = nil
            end
        end
    end
end

return M
