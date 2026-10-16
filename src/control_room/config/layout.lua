local radarPlayerDatabase = {
    sampleIntervalSeconds = 30,
    stationaryIntervalSeconds = 300,
    minMoveBlocks = 4,
    maxObservations = 2000
}

return {
    providers = {
        radar_1 = {
            type = "radar",
            peripheral = "create_radar:radar_bearing_10",
            origin = { x = -3139, z = 3480 },
            playerDatabase = radarPlayerDatabase
        },
        system_logs = {
            type = "logs",
            limit = 500
        }
    },

    displays = {
        {
            id = 0,
            mode = "fullscreen",
            instances = {
                {
                    name = "radar_1",
                    screen = "visitors",
                    title = "VISITOR RADAR",
                    provider = "radar_1"
                }
            }
        },
        {
            id = 1,
            mode = "fullscreen",
            instances = {
                {
                    name = "player_database_1",
                    screen = "player_admin",
                    title = "PLAYER DATABASE",
                    provider = "radar_1"
                }
            }
        },
        {
            id = 2,
            mode = "fullscreen",
            instances = {
                {
                    name = "system_logs_1",
                    screen = "logs",
                    title = "SYSTEM LOG",
                    provider = "system_logs"
                }
            }
        }
    }
}
