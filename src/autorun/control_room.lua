-- Start Control Room from its package directory during CC Updater startup.
local runningPath = shell.getRunningProgram()
print("Running Control Room from: " .. runningPath)
local autorunDir = fs.getDir(runningPath)
local packageDir = fs.getDir(autorunDir)

local function absolute(path)
    return "/" .. tostring(path):gsub("^/+", "")
end

local file = fs.open("/config.txt", "r")
local content = file.readAll()
local config = textutils.unserialise(content)
file.close()


local candidates = {
    fs.combine(packageDir, config["autostart"])
    -- fs.combine(packageDir, "control_room"),
    -- fs.combine(packageDir, "src/control_room")
}

local appDir
for _, candidate in ipairs(candidates) do
    candidate = absolute(candidate)
    if fs.isDir(candidate) and fs.exists(fs.combine(candidate, "startup.lua")) then
        appDir = candidate
        break
    end
end

if not appDir then
    error("Control Room startup.lua not found. Checked: "
        .. table.concat(candidates, ", "))
end

shell.setDir(appDir)
shell.run("startup.lua")
