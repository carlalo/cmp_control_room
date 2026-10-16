-- Sends private player warnings through an Advanced Peripherals Chat Box.
local M = {}

local peripheralName = "chat_box_0"
local prefix = "CONTROL ROOM"
local messageIntervalMs = 2000
local queue = {}
local nextSendAt = 0

function M.configure(config)
    config = config or {}
    peripheralName = config.chatBoxPeripheral or "chat_box_0"
    prefix = config.chatPrefix or "CONTROL ROOM"
    messageIntervalMs = (config.chatMessageIntervalSeconds or 2) * 1000
    queue = {}
    nextSendAt = 0
end

function M.sendToPlayer(playerName, message)
    assert(type(playerName) == "string" and playerName ~= "",
        "A player name is required for a private chat message")
    assert(type(message) == "string" and message ~= "",
        "A non-empty chat message is required")

    queue[#queue + 1] = { player = playerName, message = message }
    return true, "queued"
end

function M.update(now)
    if #queue == 0 then return end
    now = now or os.epoch("utc")
    if now < nextSendAt then return end

    local chatBox = peripheral.wrap(peripheralName)
    if not chatBox then
        nextSendAt = now + messageIntervalMs
        return false, "Chat Box peripheral not found: " .. tostring(peripheralName)
    end
    if type(chatBox.sendMessage) ~= "function" then
        nextSendAt = now + messageIntervalMs
        return false, "Chat Box does not provide sendMessage: " .. tostring(peripheralName)
    end

    local item = queue[1]
    local callOk, sent, err = pcall(chatBox.sendMessage, item.message, {
        player = item.player,
        prefix = prefix,
        brackets = "[]",
        bracketsColor = "&b"
    })
    if not callOk or sent ~= true then
        nextSendAt = now + messageIntervalMs
        return false, tostring(callOk and (err or "Chat Box rejected the message") or sent)
    end
    table.remove(queue, 1)
    nextSendAt = now + messageIntervalMs
    return true
end

return M
