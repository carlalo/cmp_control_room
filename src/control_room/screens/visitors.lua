return {
    title = "BASE VISITORS",
    width = 900,
    height = 600,
    widgets = {
        {
            type = "table",
            id = "current_visitors",
            label = "CURRENTLY IN BASE",
            valueKey = "players",
            emptyText = "No players detected",
            requiresOnline = true,
            offlineText = "Radar offline",
            scrollable = true,
            rowHeight = 26,
            x = 24, y = 94, width = 852, height = 205,
            columns = {
                { key = "name", label = "PLAYER", weight = 2.1 },
                { key = "distance", label = "DISTANCE", format = "distance", unit = "blocks", weight = 1.1 },
                { key = "accessStatus", label = "ACCESS", weight = 1.2 },
                { key = "party", label = "PARTY", weight = 1.1 },
                { key = "baseLocation", label = "BASE", weight = 1.3 }
            }
        },
        {
            type = "table",
            id = "visitor_history",
            label = "VISITOR HISTORY",
            valueKey = "visitorHistory",
            emptyText = "No visitors recorded",
            scrollable = true,
            rowHeight = 25,
            x = 24, y = 318, width = 852, height = 256,
            columns = {
                { key = "name", label = "PLAYER", weight = 1.8 },
                { key = "party", label = "PARTY", weight = 0.9 },
                { key = "duration", label = "VISIT DURATION", format = "duration", weight = 1.1 },
                { key = "lastSeen", label = "LAST SEEN", format = "age", weight = 1.1 },
                { key = "status", label = "STATUS", weight = 0.9 }
            }
        }
    }
}
