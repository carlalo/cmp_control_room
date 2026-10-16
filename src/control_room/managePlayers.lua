-- View and edit manually maintained player profile fields.
-- Run from the computer root: control_room/managePlayers.lua

local Database = require("core.player_database")

local function displayName(profile)
    return profile.name or "Unknown player"
end

local profiles = Database.getProfiles()
local ids = {}
for id in pairs(profiles) do ids[#ids + 1] = id end
table.sort(ids, function(a, b)
    return displayName(profiles[a]):lower() < displayName(profiles[b]):lower()
end)

print("Known players:")
for index, id in ipairs(ids) do
    print(string.format("%d) %s [%s]", index, displayName(profiles[id]), id))
end
print("Enter a UUID or a listed name. Leave empty to quit.")
write("Player: ")
local query = read()
if query == "" then return end

local selectedId
for id, profile in pairs(profiles) do
    if id:lower() == query:lower()
        or tostring(profile.name or ""):lower() == query:lower() then
        selectedId = id
        break
    end
end

if not selectedId then
    local compact = query:gsub("%-", "")
    if #compact == 32 and compact:match("^%x+$") then
        selectedId = query
    else
        print("Player not found. Use a known name or a 32-digit UUID.")
        return
    end
end

local current = Database.getProfile(selectedId) or {}
local function prompt(label, key)
    local existing = tostring(current[key] or "")
    write(label .. " [" .. (existing ~= "" and existing or "unset") .. "]: ")
    local value = read()
    if value == "" then return existing end
    if value == "-" then return "" end
    return value
end

local fields = {
    baseLocation = prompt("Base/location", "baseLocation"),
    party = prompt("Party/team", "party"),
    notes = prompt("Notes", "notes"),
    accessStatus = prompt("Access (UNLISTED / WHITELISTED / BLACKLISTED)", "accessStatus")
}

Database.setProfile(selectedId, fields)
print("Player profile saved.")
