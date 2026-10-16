local Radar = {}
Radar.__index = Radar

local PlayerNames = require("core.player_names")

local function offline(peripheralName, reason)
    return {
        online = false,
        peripheral = peripheralName,
        error = reason,
        players = {},
        tracks = {}
    }
end

local function isPlayer(track)
    return type(track) == "table"
        and (track.category == "PLAYER" or track.entityType == "entity.minecraft.player")
end

local function readOptional(peripheral, method)
    if type(peripheral[method]) ~= "function" then return nil end
    local ok, value = pcall(peripheral[method])
    if not ok then
        if tostring(value) == "Terminated" then error(value, 0) end
        return nil
    end
    return value
end

function Radar.new(peripheralName, options)
    options = options or {}
    assert(type(peripheralName) == "string" and peripheralName ~= "",
        "Radar-Peripheral-Name fehlt")

    return setmetatable({
        peripheralName = peripheralName,
        origin = options.origin,
        peripheral = nil
    }, Radar)
end

function Radar:connect()
    self.peripheral = peripheral.wrap(self.peripheralName)
    return self.peripheral ~= nil
end

function Radar:read()
    if not self.peripheral and not self:connect() then
        return offline(self.peripheralName, "Peripheral not found")
    end

    if type(self.peripheral.getTracks) ~= "function" then
        self.peripheral = nil
        return offline(self.peripheralName, "Radar does not expose getTracks()")
    end

    local ok, tracks = pcall(self.peripheral.getTracks)
    if not ok then
        if tostring(tracks) == "Terminated" then error(tracks, 0) end
        self.peripheral = nil
        return offline(self.peripheralName, "Radar stopped responding: " .. tostring(tracks))
    end
    if type(tracks) ~= "table" then
        self.peripheral = nil
        return offline(self.peripheralName, "Radar returned no track list")
    end

    local radarPosition = readOptional(self.peripheral, "getPosition")
    local distanceOrigin = type(radarPosition) == "table" and radarPosition or self.origin
    local players = {}
    for _, track in pairs(tracks) do
        if isPlayer(track) then
            local id = track.id
            local name = id and tostring(id) or "Unknown player"
            if id then
                local nameOk, resolvedName = pcall(PlayerNames.getName, tostring(id))
                if not nameOk and tostring(resolvedName) == "Terminated" then
                    error(resolvedName, 0)
                end
                if nameOk and type(resolvedName) == "string" then name = resolvedName end
            end

            local position = track.position
            local distance
            if type(position) == "table" and type(distanceOrigin) == "table"
                and type(position.x) == "number" and type(position.z) == "number"
                and type(distanceOrigin.x) == "number" and type(distanceOrigin.z) == "number" then
                local dx = position.x - distanceOrigin.x
                local dz = position.z - distanceOrigin.z
                distance = math.sqrt(dx * dx + dz * dz)
            end

            players[#players + 1] = {
                id = id,
                name = name,
                position = position,
                velocity = track.velocity,
                distance = distance,
                scannedTime = track.scannedTime,
                entityType = track.entityType,
                category = track.category
            }
        end
    end

    table.sort(players, function(a, b)
        return tostring(a.id or a.name) < tostring(b.id or b.name)
    end)

    return {
        online = true,
        peripheral = self.peripheralName,
        players = players,
        tracks = tracks,
        position = radarPosition,
        range = readOptional(self.peripheral, "getRange"),
        rotation = readOptional(self.peripheral, "getRotation"),
        rotationSpeed = readOptional(self.peripheral, "getRotationSpeed"),
        dishCount = readOptional(self.peripheral, "getDishCount"),
        speed = readOptional(self.peripheral, "getSpeed"),
        kind = readOptional(self.peripheral, "getKind"),
        overstressed = readOptional(self.peripheral, "isOverstressed")
    }
end

return Radar
