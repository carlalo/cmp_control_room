return {
    blacklist_presence = {
        enabled = true,
        fireAfterSeconds = 20,
        fireDistanceBlocks = 10,
        distanceWarningMarginBlocks = 20,
        countdownSeconds = 3,
        countdownIntervalSeconds = 2,
        chatMessageIntervalSeconds = 2,
        chatBoxPeripheral = "chat_box_0",
        chatPrefix = "CONTROL ROOM",
        fireOutputPeripheral = "redstone_relay_0",
        fireOutputSide = "top",
        targetFilter = {
            controllerPeripheral = "create_radar:network_filterer_block_entity_0",
            storagePeripheral = "minecraft:chest_84",
            -- Inventory slots are 1-based: player filter in slot 1, projectile in slot 2.
            -- Either filter may instead be installed in controllerTargetSlot at startup.
            controllerTargetSlot = 3,
            playerFilterSlot = 1,
            projectileBufferSlot = 2,
            playerFilter = {
                name = "create_radar:target_filter_item"
            },
            projectileFilter = {
                name = "create_radar:target_filter_item"
            }
        }
    }
}
