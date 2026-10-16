-- Interactive inventory test for the Create: Radars Network Controller.
-- The script shows the transfer first and moves exactly one item only after confirmation.
local controllerName = "create_radar:network_filterer_block_entity_0"
local controller = peripheral.wrap(controllerName)
assert(controller, "Network Controller not found: " .. controllerName)
assert(type(controller.list) == "function" and type(controller.size) == "function"
    and type(controller.pullItems) == "function",
    "Peripheral does not expose the expected inventory methods")

local function showInventory(label, inventory)
    print(label .. " (" .. tostring(inventory.size()) .. " slots):")
    local contents = inventory.list()
    local found = false
    for slot = 1, inventory.size() do
        local stack = contents[slot]
        if stack then
            found = true
            local detail = inventory.getItemDetail and inventory.getItemDetail(slot)
            print("  Slot " .. slot .. ": "
                .. tostring(detail and (detail.displayName or detail.name) or stack.name)
                .. " x" .. tostring(stack.count))
        end
    end
    if not found then print("  (empty)") end
end

local function readSlotNumber()
    local input = read()
    return tonumber(input) or tonumber(input:match("%d+"))
end

showInventory("Network Controller", controller)
print("\nAvailable source inventories:")
local sources = {}
for _, name in ipairs(peripheral.getNames()) do
    if name ~= controllerName then
        local inventory = peripheral.wrap(name)
        if inventory and type(inventory.list) == "function" then
            sources[#sources + 1] = name
            print("  " .. name)
        end
    end
end

if #sources == 0 then
    print("No other inventory with pushItems is attached.")
    return
end

print("\nPrepare an Identification Filter: hold it, open its GUI, and add a trusted test player.")
print("Names in this filter are excluded from automatic targeting (they are treated as friendly).")
print("Identification Filter belongs in controller slot 2. Keep cannon firing disabled for this test.")
write("Source inventory name: ")
local requestedSourceName = read()
local sourceName
for _, candidate in ipairs(sources) do
    if candidate == requestedSourceName then
        sourceName = candidate
        break
    end
    local shortName = candidate:match("[^:]+$")
    if shortName == requestedSourceName then
        if sourceName then error("Ambiguous short name; enter the full peripheral name") end
        sourceName = candidate
    end
end
sourceName = sourceName or requestedSourceName
local source = peripheral.wrap(sourceName)
if not source or type(source.list) ~= "function" then
    error("That source does not expose inventory methods")
end

showInventory("Selected source", source)
write("Source slot containing the item (number, e.g. 1): ")
local sourceSlot = readSlotNumber()
write("Network Controller destination slot (number, e.g. 1): ")
local destinationSlot = readSlotNumber()
assert(sourceSlot and sourceSlot >= 1 and sourceSlot <= source.size(), "Invalid source slot")
assert(destinationSlot and destinationSlot >= 1 and destinationSlot <= controller.size(),
    "Invalid destination slot")
assert(destinationSlot == 2, "Identification Filter must go into controller slot 2")

local item = source.getItemDetail and source.getItemDetail(sourceSlot)
assert(item, "Selected source slot is empty")
local itemName = item.displayName or item.name or "unknown item"
local itemIdentity = string.lower(tostring(item.name or "") .. " " .. tostring(item.displayName or ""))
assert(itemIdentity:find("ident", 1, true),
    "Selected item does not look like an Identification Filter: " .. tostring(itemName))
assert(not controller.list()[destinationSlot],
    "Destination slot is occupied; choose an empty controller slot to avoid replacing a filter")
print("\nWill pull exactly one " .. tostring(itemName) .. " from " .. sourceName
    .. " slot " .. sourceSlot .. " into controller slot " .. destinationSlot .. ".")
write("Type MOVE to perform this inventory transfer: ")
if read() ~= "MOVE" then
    print("Cancelled; no items moved.")
    return
end

local ok, moved = pcall(controller.pullItems, sourceName, sourceSlot, 1, destinationSlot)
if not ok then error("pullItems failed: " .. tostring(moved)) end
print("pullItems moved " .. tostring(moved) .. " item(s).")
showInventory("Network Controller after transfer", controller)
