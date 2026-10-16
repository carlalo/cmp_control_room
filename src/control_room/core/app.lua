local GPU = require("drivers.directgpu")
local theme = require("config.theme")
local manager = require("core.screen_manager")
local DataManager = require("core.data_manager")
local SnapshotBus = require("core.snapshot_bus")
local Persistence = require("core.persistence")
local RuleEngine = require("core.rule_engine")
local logger = require("core.log").new("app")

local App = {}

local function waitForNextUpdate()
    local timer = os.startTimer(0.05)
    while true do
        local event, eventTimer = os.pullEventRaw()
        if event == "terminate" then
            return false
        end
        if event == "key" then
            manager.handleEvent(event, eventTimer)
            return true
        end
        if event == "timer" and eventTimer == timer then
            return true
        end
    end
end

function App.start()
    print("CONTROL ROOM: Strg+T-Behandlung aktiv")
    logger.info("Control Room starting")
    local cleanupDisplaysOnExit = false
    local terminationRequested = false
    local ok, err = pcall(function()
        local availableDisplays = GPU.init()
        if not GPU.supportsTouch() then
            print("DirectGPU-Touch-Events fehlen; Touch-Bedienung ist nicht verfuegbar.")
        end
        local config = require("config.layout")
        local rulesConfig = require("config.rules")
        local required = #(config.displays or {})
        assert(required > 0, "Keine Displays in config/layout.lua konfiguriert")

        if #availableDisplays < required then
            local missing = required - #availableDisplays
            print("DirectGPU-Displays: " .. #availableDisplays .. "/" .. required
                .. ". Erstelle " .. missing .. " weiteres Display(s)...")
            availableDisplays = GPU.createDisplays(missing)
        end

        if #availableDisplays < required then
            local ids = {}
            for _, id in ipairs(availableDisplays) do
                ids[#ids + 1] = tostring(id)
            end
            error("Es sind " .. #availableDisplays .. " von " .. required
                .. " benötigten DirectGPU-Displays verfügbar (IDs: "
                .. (#ids > 0 and table.concat(ids, ", ") or "keine")
                .. "). Prüfe, ob beide Monitore am selben GPU-Block erkannt werden.")
        end

        -- Vorhandene IDs bleiben erhalten, wenn sie zur Konfiguration passen.
        local availableSet = {}
        for _, id in ipairs(availableDisplays) do availableSet[id] = true end
        local configuredIdsExist = true
        for _, display in ipairs(config.displays) do
            if not availableSet[display.id] then
                configuredIdsExist = false
                break
            end
        end
        if not configuredIdsExist then
            for index, display in ipairs(config.displays) do
                display.id = availableDisplays[index]
            end
        end

        manager.loadConfig(config)
        DataManager.loadConfig(config)
        Persistence.loadConfig(config)
        RuleEngine.loadConfig(rulesConfig)
        local snapshots = SnapshotBus.new()
        snapshots:subscribe("persistence", Persistence.onSnapshot)
        snapshots:subscribe("rule_engine", RuleEngine.onSnapshot)
        snapshots:subscribe("screen_manager", manager.onSnapshot)
        cleanupDisplaysOnExit = true

        local context = { theme = theme }
        local running = true
        while running do
            DataManager.update(snapshots)
            manager.update(context)
            running = waitForNextUpdate()
        end
        terminationRequested = true
    end)

    -- Displays werden bei regulärem Betrieb auch nach Ctrl+T entfernt.
    -- Bei fehlgeschlagener Einrichtung bleiben vorhandene Displays erhalten.
    -- Convert a caught CC:Tweaked termination into a clean shutdown.
    if not ok and tostring(err) == "Terminated" then
        terminationRequested = true
        ok = true
    end

    -- De-energize rule-controlled outputs on normal exit and caught errors.
    RuleEngine.shutdown()

    if cleanupDisplaysOnExit then
        if terminationRequested then
            print("CONTROL ROOM: Strg+T erkannt; beende Programm...")
            logger.info("Control Room stopping")
        end
        GPU.shutdown()
    end

    if not ok then
        error(err, 0)
    end
end

return App
