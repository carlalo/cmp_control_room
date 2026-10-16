-- Read-only probe for Create Big Cannons / CC cannon peripherals.
-- This script only lists peripheral types and exposed methods. It does not call them.
local lines = {
    "Cannon Peripheral Report",
    "========================",
    ""
}

local function add(line)
    lines[#lines + 1] = line
end

local names = peripheral.getNames()
table.sort(names)

if #names == 0 then
    add("No peripherals found.")
end

for _, name in ipairs(names) do
    local types = { peripheral.getType(name) }
    local methods = peripheral.getMethods(name) or {}
    table.sort(methods)

    add("Peripheral: " .. tostring(name))
    add("  Types: " .. (#types > 0 and table.concat(types, ", ") or "unknown"))
    add("  Methods:")
    for _, method in ipairs(methods) do
        add("    " .. tostring(method))
    end

    local wrapped = peripheral.wrap(name)
    if wrapped and type(wrapped.isWireless) == "function"
        and type(wrapped.getNamesRemote) == "function" then
        local remoteOk, remoteNames = pcall(wrapped.getNamesRemote)
        add("  Wired network remote peripherals:")
        if remoteOk and type(remoteNames) == "table" and #remoteNames > 0 then
            table.sort(remoteNames)
            for _, remoteName in ipairs(remoteNames) do
                local typeResults = { pcall(wrapped.getTypeRemote, remoteName) }
                local typeOk = table.remove(typeResults, 1)
                local methodsOk, remoteMethods = pcall(wrapped.getMethodsRemote, remoteName)
                local remoteTypes = typeOk and typeResults or {}
                remoteMethods = methodsOk and remoteMethods or {}
                table.sort(remoteMethods)
                add("    " .. tostring(remoteName))
                add("      Types: " .. (#remoteTypes > 0
                    and table.concat(remoteTypes, ", ") or "unknown"))
                add("      Methods: " .. (#remoteMethods > 0
                    and table.concat(remoteMethods, ", ") or "none"))
            end
        elseif not remoteOk then
            add("    Could not list remotes: " .. tostring(remoteNames))
        else
            add("    None")
        end
    end
    add("")
end

local report = table.concat(lines, "\n")
local programPath = shell.getRunningProgram()
local reportPath = fs.combine(fs.getDir(programPath), "cannon_peripheral_report.txt")
local file = fs.open(reportPath, "w")
if not file then error("Could not write " .. reportPath) end
file.write(report)
file.close()

print(report)
print("\nSaved to " .. reportPath)
