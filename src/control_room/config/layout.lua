return {
    displays = {
        {
            id = 0,
            mode = "fullscreen",
            instances = {
                {
                    name = "lava_1",
                    screen = "fluid_tank",
                    title = "LAVA RESERVOIR",
                    provider = {
                        type = "fluid_tank",
                        peripheral = "create:fluid_tank_2"
                    }
                }
            }
        },
        {
            id = 1,
            mode = "fullscreen",
            instances = {
                {
                    name = "radar_1",
                    screen = "visitors",
                    title = "VISITOR RADAR",
                    provider = {
                        type = "radar",
                        peripheral = "create_radar:radar_bearing_1",
                        origin = { x = -886, z = -1010 },
                        playerDatabase = {
                            sampleIntervalSeconds = 30,
                            stationaryIntervalSeconds = 300,
                            minMoveBlocks = 4,
                            maxObservations = 2000
                        }
                    }
                }
            }
        },
        {
            id = 2,
            mode = "fullscreen",
            instances = {
                {
                    name = "player_database_1",
                    screen = "player_admin",
                    title = "PLAYER DATABASE",
                    provider = {
                        type = "radar",
                        peripheral = "create_radar:radar_bearing_1",
                        origin = { x = -886, z = -1010 },
                        playerDatabase = {
                            sampleIntervalSeconds = 30,
                            stationaryIntervalSeconds = 300,
                            minMoveBlocks = 4,
                            maxObservations = 2000
                        }
                    }
                }
            }
        },
        {
            id = 3,
            mode = "fullscreen",
            instances = {
                {
                    name = "system_logs_1",
                    screen = "logs",
                    title = "SYSTEM LOG",
                    provider = {
                        type = "logs",
                        limit = 500
                    }
                }
            }
        }
    }
}
