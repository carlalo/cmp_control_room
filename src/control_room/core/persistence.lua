-- Persists provider observations and visit intervals in the UUID-keyed database.
local PlayerDatabase = require("core.player_database")

local M = {}
local visitorSourceName
local leaveGraceSeconds = 5

function M.loadConfig(config)
    visitorSourceName = nil
    local providerDefinitions = config.providers or {}
    for _, display in ipairs(config.displays or {}) do
        for _, instance in ipairs(display.instances or {}) do
            local provider = type(instance.provider) == "string"
                and providerDefinitions[instance.provider] or instance.provider or {}
            if provider.type == "radar" and instance.screen == "visitors"
                and not visitorSourceName then
                visitorSourceName = instance.name
                leaveGraceSeconds = provider.leaveGraceSeconds or 5
            end
        end
    end
end

function M.onSnapshot(snapshot)
    local capturedAt = snapshot.capturedAt or os.epoch("utc")
    local playersById = {}
    local databaseOptions

    for name, source in pairs(snapshot.sources or {}) do
        local data = source.data or {}
        if source.providerType == "radar" and data.online ~= false then
            databaseOptions = databaseOptions or source.databaseOptions or {}
            for _, player in ipairs(data.players or {}) do
                if type(player) == "table" and player.id ~= nil then
                    playersById[tostring(player.id):lower()] = player
                end
            end
        end

    end

    local players = {}
    for _, player in pairs(playersById) do players[#players + 1] = player end
    if #players > 0 then
        PlayerDatabase.observe(players, capturedAt, databaseOptions or {})
    end

    -- Visit intervals are stored on each UUID profile in the player database.
    local visitSource = visitorSourceName and snapshot.sources
        and snapshot.sources[visitorSourceName]
    if visitSource and visitSource.data and visitSource.data.online ~= false then
        PlayerDatabase.updateVisits(visitSource.data.players, capturedAt, leaveGraceSeconds)
    end
end

function M.getVisitorRows(instanceName, now, sensorOnline)
    if instanceName ~= visitorSourceName then return {} end
    return PlayerDatabase.getVisitorRows(now, sensorOnline)
end

return M
