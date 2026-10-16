-- Read-only diagnostic for Create: Radars filters and CBC targeting.
-- This script does not move filters, change aim, assemble, or fire a cannon.

local monitorName = "create_radar:monitor_0"
local filtererName = "create_radar:network_filterer_block_entity_0"
local cannonName = "cannon_mount_0"

local lines = {}
local function add(value)
    lines[#lines + 1] = tostring(value)
end

local function safeCall(label, fn)
    if type(fn) ~= "function" then
        add(label .. ": method unavailable")
        return nil
    end
    local ok, result = pcall(fn)
    if not ok then
        add(label .. ": ERROR " .. tostring(result))
        return nil
    end
    return result
end

local function serialize(value)
    if value == nil then return "nil" end
    if textutils and textutils.serialize then
        local ok, result = pcall(textutils.serialize, value)
        if ok then return result end
    end
    return tostring(value)
end

add("Radar / cannon targeting diagnostic (read only)")
add("===============================================")

local monitor = peripheral.wrap(monitorName)
add("\nMonitor: " .. monitorName)
if monitor then
    local selectedId = safeCall("getSelectedTrackId", monitor.getSelectedTrackId)
    local selectedTrack = safeCall("getSelectedTrack", monitor.getSelectedTrack)
    add("Selected track ID: " .. serialize(selectedId))
    add("Selected track: " .. serialize(selectedTrack))

    local tracks = safeCall("getTracks", monitor.getTracks)
    add("Tracks:")
    if type(tracks) == "table" then
        for index, track in ipairs(tracks) do
            add("  " .. tostring(index) .. ": " .. serialize(track))
        end
        if #tracks == 0 then add("  (none)") end
    else
        add("  unavailable")
    end
else
    add("  peripheral not directly available to this computer")
end

local filterer = peripheral.wrap(filtererName)
add("\nNetwork Controller inventory: " .. filtererName)
if filterer and type(filterer.list) == "function" and type(filterer.size) == "function" then
    local contents = safeCall("list", filterer.list) or {}
    local size = safeCall("size", filterer.size) or 0
    for slot = 1, size do
        local stack = contents[slot]
        if stack then
            local detail = filterer.getItemDetail
                and safeCall("getItemDetail slot " .. slot, function()
                    return filterer.getItemDetail(slot)
                end)
            add("  Slot " .. slot .. ": " .. serialize(detail or stack))
        else
            add("  Slot " .. slot .. ": (empty)")
        end
    end
else
    add("  inventory peripheral unavailable")
end

local cannon = peripheral.wrap(cannonName)
add("\nCannon status (read only): " .. cannonName)
if cannon and type(cannon.getInfo) == "function" then
    add("  " .. serialize(safeCall("getInfo", cannon.getInfo)))
else
    add("  getInfo unavailable")
end

local report = table.concat(lines, "\n")
print(report)

local programPath = shell.getRunningProgram()
local reportPath = fs.combine(fs.getDir(programPath), "radar_target_test.txt")
local file = fs.open(reportPath, "w")
if not file then error("Could not write " .. reportPath) end
file.write(report)
file.close()
print("\nSaved to " .. reportPath)
