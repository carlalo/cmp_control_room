return {
    title = "FLUID RESERVOIR",
    width = 900,
    height = 600,
    widgets = {
        {
            type = "tank",
            id = "lava_storage",
            label = "CURRENT STORAGE",
            valueKey = "amount",
            capacityKey = "capacity",
            percentKey = "percent",
            unit = "mB",
            x = 24, y = 94, width = 852, height = 155
        },
        {
            type = "history",
            id = "lava_history",
            label = "STORAGE HISTORY",
            range = "LAST 1 MIN",
            sourceKey = "amount",
            capacityKey = "capacity",
            duration = 60,
            sampleInterval = 0.05,
            x = 24, y = 268, width = 852, height = 200
        },
        {
            type = "metric",
            id = "lava_flow",
            label = "FLOW RATE",
            valueKey = "rate",
            unit = "mB/s",
            placeholder = "After measurement",
            x = 24, y = 484, width = 418, height = 90
        },
        {
            type = "status",
            id = "tank_status",
            label = "STATUS",
            valueKey = "online",
            x = 458, y = 484, width = 418, height = 90
        }
    }
}
