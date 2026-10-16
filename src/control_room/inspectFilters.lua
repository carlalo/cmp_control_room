-- Read-only inventory report for the Network Controller and filter storage.
local controllerName = "create_radar:network_filterer_block_entity_0"
local storageName = "minecraft:chest_0"

local function serialize(value)
    if textutils and textutils.serialize then
        local ok, result = pcall(textutils.serialize, value)
        if ok then return result end
    end
    return tostring(value)
end

local function describeInventory(name)
    local inventory = peripheral.wrap(name)
    if not inventory then
        return { name = name, error = "Peripheral not found" }
    end
    if type(inventory.list) ~= "function" or type(inventory.size) ~= "function" then
        return { name = name, error = "Peripheral is not an inventory" }
    end

    local contents = inventory.list()
    local slots = {}
    for slot = 1, inventory.size() do
        local stack = contents[slot]
        if stack then
            local detail = inventory.getItemDetail
                and inventory.getItemDetail(slot) or stack
            slots[#slots + 1] = {
                slot = slot,
                stack = stack,
                detail = detail
            }
        end
    end

    return {
        name = name,
        size = inventory.size(),
        slots = slots
    }
end

local report = {
    title = "Read-only filter inventory report",
    inventories = {
        describeInventory(controllerName),
        describeInventory(storageName)
    }
}

local output = serialize(report)
print(output)

local programPath = shell.getRunningProgram()
local reportPath = fs.combine(fs.getDir(programPath), "filter_inventory_report.txt")
local file = fs.open(reportPath, "w")
if not file then error("Could not write " .. reportPath) end
file.write(output)
file.close()
print("\nSaved to " .. reportPath)
