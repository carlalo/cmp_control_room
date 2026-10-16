-- Resolves Radar player UUIDs to Minecraft profile names.

local PlayerDatabase = require("core.player_database")
local M = {}
local cache = {}
local retryAfter = {}
local failureRetryMs = 60000
local apiBase = "https://api.minecraftservices.com/minecraft/profile/lookup/"

local function normalizeUuid(uuid)
    if type(uuid) ~= "string" then return nil end
    local compact = uuid:gsub("%-", "")
    if #compact ~= 32 or not compact:match("^%x+$") then return nil end
    return compact:lower()
end

local function databaseName(uuid, normalized)
    local hyphenated = normalized:sub(1, 8) .. "-" .. normalized:sub(9, 12)
        .. "-" .. normalized:sub(13, 16) .. "-" .. normalized:sub(17, 20)
        .. "-" .. normalized:sub(21)
    local profile = PlayerDatabase.getProfile(uuid)
        or PlayerDatabase.getProfile(hyphenated)
        or PlayerDatabase.getProfile(normalized)
    return profile and type(profile.name) == "string" and profile.name or nil
end

local function lookup(uuid)
    if type(http) ~= "table" or type(http.get) ~= "function"
        or type(textutils) ~= "table"
        or type(textutils.unserializeJSON) ~= "function" then
        return nil
    end

    local ok, response = pcall(http.get, apiBase .. uuid)
    if not ok then
        if tostring(response) == "Terminated" then error(response, 0) end
        return nil
    end
    if not response then return nil end

    local responseOk, status, body = pcall(function()
        local code = response.getResponseCode and response.getResponseCode() or nil
        local content = response.readAll()
        response.close()
        return code, content
    end)
    if not responseOk then
        if tostring(status) == "Terminated" then error(status, 0) end
        pcall(response.close)
        return nil
    end
    if status ~= 200 then return nil end

    local decoded, profile = pcall(textutils.unserializeJSON, body)
    if not decoded or type(profile) ~= "table" or type(profile.name) ~= "string" then
        return nil
    end
    return profile.name
end

-- Names persist with the player profile; only API retry state is process-local.
function M.getName(uuid)
    local normalized = normalizeUuid(uuid)
    if not normalized then return tostring(uuid or "Unknown player") end
    local stored = databaseName(uuid, normalized)
    if stored then
        cache[normalized] = stored
        return stored
    end
    if cache[normalized] then return cache[normalized] end

    local now = os.epoch("utc")
    if retryAfter[normalized] and now < retryAfter[normalized] then
        return uuid
    end

    local name = lookup(normalized)
    if not name then
        retryAfter[normalized] = now + failureRetryMs
        return uuid
    end

    cache[normalized] = name
    retryAfter[normalized] = nil
    return name
end

function M.getCachedName(uuid)
    local normalized = normalizeUuid(uuid)
    if not normalized then return nil end
    return databaseName(uuid, normalized) or cache[normalized]
end

return M
