-- Discovers the two configured filter items at startup, then swaps them safely.
local M = {}

local function slots(inventory, slot)
    local contents = inventory.list()
    return contents and contents[slot] or nil
end

local function filterAt(inventory, slot, expectedName)
    local stack = slots(inventory, slot)
    if not stack then return nil end
    assert(stack.name == expectedName,
        "Unexpected item in filter slot " .. tostring(slot) .. ": " .. tostring(stack.name))
    assert((stack.count or 1) == 1, "Expected exactly one filter in slot " .. tostring(slot))
    local nbt = stack.nbt
    if not nbt and type(inventory.getItemDetail) == "function" then
        local detail = inventory.getItemDetail(slot)
        nbt = type(detail) == "table" and detail.nbt or nil
    end
    assert(nbt ~= nil, "Could not read NBT data for filter in slot " .. tostring(slot))
    return { name = stack.name, nbt = nbt }
end

local function controllerFilterAt(inventory, slot, playerName, projectileName)
    local stack = slots(inventory, slot)
    if not stack then return nil end
    assert(stack.name == playerName or stack.name == projectileName,
        "Unexpected item in controller target slot: " .. tostring(stack.name))
    assert((stack.count or 1) == 1, "Expected exactly one filter in controller target slot")
    local nbt = stack.nbt
    if not nbt and type(inventory.getItemDetail) == "function" then
        local detail = inventory.getItemDetail(slot)
        nbt = type(detail) == "table" and detail.nbt or nil
    end
    assert(nbt ~= nil, "Could not read NBT data for controller target filter")
    return { name = stack.name, nbt = nbt }
end

local function matches(inventory, slot, expected)
    local stack = slots(inventory, slot)
    if not stack then return false end
    if stack.name ~= expected.name then return false end
    if expected.nbt and stack.nbt ~= expected.nbt then return false end
    return (stack.count or 1) == 1
end

local function empty(inventory, slot)
    return slots(inventory, slot) == nil
end

local function move(source, sourceName, sourceSlot, destination, destinationName, destinationSlot, expected)
    assert(matches(source, sourceSlot, expected), "Unexpected item in source slot " .. sourceSlot)
    assert(empty(destination, destinationSlot), "Destination slot " .. destinationSlot .. " is not empty")
    local moved = destination.pullItems(sourceName, sourceSlot, 1, destinationSlot)
    assert(moved == 1, "Inventory transfer moved " .. tostring(moved) .. " items")
    assert(matches(destination, destinationSlot, expected), "Moved item did not match expected filter")
    assert(empty(source, sourceSlot), "Source slot was not emptied")
end

local function wrap(name)
    local inventory = peripheral.wrap(name)
    assert(inventory, "Inventory peripheral not found: " .. tostring(name))
    assert(type(inventory.list) == "function" and type(inventory.pullItems) == "function",
        "Peripheral is not a compatible inventory: " .. tostring(name))
    return inventory
end

-- Learn each filter's NBT from its configured chest slot, or from the
-- controller when that filter is currently installed there.
function M.discover(config)
    assert(type(config) == "table", "Target filter configuration is required")
    local controllerName = assert(config.controllerPeripheral, "controllerPeripheral is required")
    local storageName = assert(config.storagePeripheral, "storagePeripheral is required")
    local controllerSlot = assert(config.controllerTargetSlot, "controllerTargetSlot is required")
    local playerSlot = assert(config.playerFilterSlot, "playerFilterSlot is required")
    local projectileSlot = assert(config.projectileBufferSlot, "projectileBufferSlot is required")
    local playerName = assert(config.playerFilter and config.playerFilter.name, "playerFilter.name is required")
    local projectileName = assert(config.projectileFilter and config.projectileFilter.name,
        "projectileFilter.name is required")
    local controller = wrap(controllerName)
    local storage = wrap(storageName)

    local playerFilter = filterAt(storage, playerSlot, playerName)
    local projectileFilter = filterAt(storage, projectileSlot, projectileName)
    local controllerFilter = controllerFilterAt(controller, controllerSlot, playerName, projectileName)

    assert(playerFilter or projectileFilter,
        "No filters found in the configured chest slots; cannot discover filter NBT")

    if playerFilter and projectileFilter then
        assert(not controllerFilter,
            "Both chest filter slots and the controller target slot are occupied; filter roles are ambiguous")
    elseif playerFilter then
        assert(controllerFilter, "Projectile filter is missing from its chest slot and the controller")
        assert(controllerFilter.name == projectileName,
            "Expected the projectile filter in the controller target slot")
        projectileFilter = controllerFilter
    elseif projectileFilter then
        assert(controllerFilter, "Player filter is missing from its chest slot and the controller")
        assert(controllerFilter.name == playerName,
            "Expected the player filter in the controller target slot")
        playerFilter = controllerFilter
    end

    assert(playerFilter.nbt ~= projectileFilter.nbt,
        "Player and projectile filters have identical NBT; cannot distinguish their settings")

    config.playerFilter.nbt = playerFilter.nbt
    config.projectileFilter.nbt = projectileFilter.nbt
    return config
end

-- desired=true puts the player filter in the controller. false restores the
-- projectile filter. Intermediate states can be resumed after an interruption.
function M.setPlayerTargeting(config, desired)
    assert(type(config) == "table", "Target filter configuration is required")
    local controllerName = assert(config.controllerPeripheral, "controllerPeripheral is required")
    local storageName = assert(config.storagePeripheral, "storagePeripheral is required")
    local controllerSlot = assert(config.controllerTargetSlot, "controllerTargetSlot is required")
    local playerSlot = assert(config.playerFilterSlot, "playerFilterSlot is required")
    local projectileSlot = assert(config.projectileBufferSlot, "projectileBufferSlot is required")
    local player = assert(config.playerFilter, "playerFilter is required")
    local projectile = assert(config.projectileFilter, "projectileFilter is required")
    local controller = wrap(controllerName)
    local storage = wrap(storageName)

    local function at(inventory, slot, filter) return matches(inventory, slot, filter) end
    local function isEmpty(inventory, slot) return empty(inventory, slot) end

    if desired then
        if at(controller, controllerSlot, player)
            and at(storage, projectileSlot, projectile)
            and isEmpty(storage, playerSlot) then return end

        if at(controller, controllerSlot, projectile)
            and at(storage, playerSlot, player)
            and isEmpty(storage, projectileSlot) then
            move(controller, controllerName, controllerSlot, storage, storageName, projectileSlot, projectile)
        end

        if isEmpty(controller, controllerSlot)
            and at(storage, playerSlot, player)
            and at(storage, projectileSlot, projectile) then
            move(storage, storageName, playerSlot, controller, controllerName, controllerSlot, player)
            return
        end
        error("Filter inventories are not in a safe state for player targeting")
    end

    if at(controller, controllerSlot, projectile)
        and at(storage, playerSlot, player)
        and isEmpty(storage, projectileSlot) then return end

    if at(controller, controllerSlot, player)
        and isEmpty(storage, playerSlot)
        and at(storage, projectileSlot, projectile) then
        move(controller, controllerName, controllerSlot, storage, storageName, playerSlot, player)
    end

    if isEmpty(controller, controllerSlot)
        and at(storage, playerSlot, player)
        and at(storage, projectileSlot, projectile) then
        move(storage, storageName, projectileSlot, controller, controllerName, controllerSlot, projectile)
        return
    end
    error("Filter inventories are not in a safe state for projectile targeting")
end

return M
