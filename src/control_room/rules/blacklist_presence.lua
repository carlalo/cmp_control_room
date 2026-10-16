-- Activates player targeting on detection and fires by time or proximity.
local PlayerDatabase = require("core.player_database")
local Log = require("core.log")
local Cannons = require("core.actors.cannons")
local ChatBox = require("core.actors.chat_box")

local M = {}
local logger = Log.new("rule.blacklist_presence")
local fireAfterMs = 20000
local fireDistanceBlocks = 10
local distanceWarningMarginBlocks = 20
local countdownSeconds = 3
local countdownIntervalMs = 6000
local states = {}
local enabled = true

local function playerName(id)
    local profile = PlayerDatabase.getProfile(id)
    return tostring(profile and profile.name or id)
end

local function sendWarning(id, player, message)
    local recipient = type(player) == "table" and type(player.name) == "string"
        and player.name ~= "" and player.name ~= "Unknown player"
        and player.name or playerName(id)
    local callOk, sent, err = pcall(ChatBox.sendToPlayer, recipient, message)
    if callOk and sent then
        logger.info("Private chat warning queued for " .. recipient .. ": " .. message)
    else
        local reason = callOk and err or sent
        logger.error("Could not send private chat warning to " .. recipient
            .. ": " .. tostring(reason))
    end
end

function M.loadConfig(ruleConfig)
    states = {}
    ruleConfig = ruleConfig or {}
    enabled = ruleConfig.enabled ~= false
    fireAfterMs = (ruleConfig.fireAfterSeconds or 20) * 1000
    fireDistanceBlocks = ruleConfig.fireDistanceBlocks or 10
    distanceWarningMarginBlocks = ruleConfig.distanceWarningMarginBlocks or 20
    countdownSeconds = ruleConfig.countdownSeconds or 3
    countdownIntervalMs = (ruleConfig.countdownIntervalSeconds or 6) * 1000
    ChatBox.configure(ruleConfig)
    Cannons.configure(ruleConfig)
end

function M.onSnapshot(snapshot)
    local chatOk, chatSent, chatErr = pcall(ChatBox.update, snapshot.capturedAt)
    if not chatOk then
        logger.error("Could not send queued chat warning: " .. tostring(chatSent))
    elseif chatSent == false then
        logger.error("Could not send queued chat warning: " .. tostring(chatErr))
    end
    if not enabled then return end

    local now = snapshot.capturedAt or os.epoch("utc")
    local seen = {}
    local radarOnline = false

    for _, source in pairs(snapshot.sources or {}) do
        if source.providerType == "radar" and source.data and source.data.online ~= false then
            radarOnline = true
            for _, player in ipairs(source.data.players or {}) do
                if type(player) == "table" and player.id ~= nil then
                    local id = tostring(player.id):lower()
                    local profile = PlayerDatabase.getProfile(id)
                    if profile and profile.accessStatus == "BLACKLISTED" then
                        seen[id] = player
                        local state = states[id]
                        if not state then
                            state = { since = now }
                            states[id] = state
                            logger.warn("BLACKLISTED " .. playerName(id)
                                .. " detected; sending private restricted-area warning")
                        end

                        local inWarningRange = type(player.distance) == "number"
                            and player.distance <= fireDistanceBlocks + distanceWarningMarginBlocks
                            and player.distance > fireDistanceBlocks
                            and now - state.since < fireAfterMs
                        if not state.initialWarningSent then
                            if inWarningRange then
                                state.distanceWarned = true
                                sendWarning(id, player, "You are approaching a restricted area ("
                                    .. string.format("%.1f", player.distance)
                                    .. " blocks). Leave now.")
                            else
                                sendWarning(id, player,
                                    "You are in a restricted area. Leave immediately.")
                            end
                            state.initialWarningSent = true
                        elseif inWarningRange and not state.distanceWarned then
                            state.distanceWarned = true
                            sendWarning(id, player, "You are approaching a restricted area ("
                                .. string.format("%.1f", player.distance)
                                .. " blocks). Leave now.")
                        end
                    elseif states[id] then
                        states[id] = nil
                        logger.info("Blacklist rule timer reset for " .. playerName(id))
                    end
                end
            end
        end
    end

    if not radarOnline then
        states = {}
        Cannons.stop_fire()
        Cannons.deactivate_cannons()
        return
    end

    local anyPresent = false
    local shouldFire = false
    for id, state in pairs(states) do
        local player = seen[id]
        if player then
            anyPresent = true
            local elapsedMs = now - state.since
            local distanceTriggered = type(player.distance) == "number"
                and player.distance <= fireDistanceBlocks
            local timeTriggered = elapsedMs >= fireAfterMs

            if not state.fireTriggered and not distanceTriggered and not timeTriggered then
                -- Space countdown stages by the configured Chat Box interval.
                local countdownStartMs = math.max(countdownIntervalMs,
                    fireAfterMs - countdownSeconds * countdownIntervalMs)
                local count = countdownSeconds
                    - math.floor((elapsedMs - countdownStartMs) / countdownIntervalMs)
                if elapsedMs >= countdownStartMs
                    and count <= countdownSeconds and count >= 1
                    and count ~= state.lastCountdown then
                    state.lastCountdown = count
                    local countdownMessage = "Cannons will fire soon. Countdown: "
                        .. tostring(count) .. ". Leave the area now."
                    logger.warn("Sending cannon countdown to " .. playerName(id)
                        .. ": " .. tostring(count))
                    sendWarning(id, player, countdownMessage)
                end
            end

            if distanceTriggered or timeTriggered then
                state.fireTriggered = true
            end

            if state.fireTriggered then
                shouldFire = true
                if not state.fireLogged then
                    state.fireLogged = true
                    local reason = distanceTriggered
                        and ("distance " .. string.format("%.1f", player.distance)
                            .. " blocks <= " .. tostring(fireDistanceBlocks) .. " blocks")
                        or ("presence reached " .. tostring(fireAfterMs / 1000) .. " seconds")
                    logger.warn("Fire condition reached for " .. playerName(id) .. ": " .. reason)
                end
            end
        else
            -- A confirmed absence ends this visit immediately; a later visit
            -- receives a fresh warning delay.
            states[id] = nil
        end
    end

    if not anyPresent then
        Cannons.stop_fire()
        Cannons.deactivate_cannons()
        return
    end

    local ok, err = pcall(Cannons.activate_cannons)
    if not ok then
        logger.error("Could not activate cannon targeting: " .. tostring(err))
        return
    end

    if shouldFire then
        local fireOk, fireErr = pcall(Cannons.start_fire)
        if not fireOk then logger.error("Could not start cannon fire: " .. tostring(fireErr)) end
    else
        local stopOk, stopErr = pcall(Cannons.stop_fire)
        if not stopOk then logger.error("Could not stop cannon fire: " .. tostring(stopErr)) end
    end
end

function M.shutdown()
    Cannons.deactivate_cannons()
end

return M
