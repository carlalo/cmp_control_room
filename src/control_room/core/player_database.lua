-- Persistent player profiles and sampled radar observations.
-- Profile fields baseLocation, party, and notes are user-maintained via setProfile().

local M = {}
local profiles = {}
local dirty = false
local lastSavedAt = 0
local saveIntervalMs = 5000
local databasePath

local function prettyJson(json)
    local output = {}
    local indent = 0
    local inString = false
    local escaped = false
    local index = 1

    while index <= #json do
        local character = json:sub(index, index)
        if inString then
            output[#output + 1] = character
            if escaped then
                escaped = false
            elseif character == "\\" then
                escaped = true
            elseif character == '"' then
                inString = false
            end
        elseif character == '"' then
            inString = true
            output[#output + 1] = character
        elseif character == "{" or character == "[" then
            local closing = character == "{" and "}" or "]"
            output[#output + 1] = character
            if json:sub(index + 1, index + 1) == closing then
                output[#output + 1] = closing
                index = index + 1
            else
                indent = indent + 1
                output[#output + 1] = "\n" .. string.rep("  ", indent)
            end
        elseif character == "}" or character == "]" then
            indent = math.max(0, indent - 1)
            output[#output + 1] = "\n" .. string.rep("  ", indent) .. character
        elseif character == "," then
            output[#output + 1] = ",\n" .. string.rep("  ", indent)
        elseif character == ":" then
            output[#output + 1] = ": "
        else
            output[#output + 1] = character
        end
        index = index + 1
    end

    return table.concat(output)
end

local function normalizeId(id)
    if id == nil then return nil end
    return tostring(id):lower()
end

local function copyPosition(position)
    if type(position) ~= "table"
        or type(position.x) ~= "number"
        or type(position.y) ~= "number"
        or type(position.z) ~= "number" then
        return nil
    end
    return { x = position.x, y = position.y, z = position.z }
end

local function distance(a, b)
    if not a or not b then return math.huge end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function load()
    local program = shell.getRunningProgram()
    databasePath = fs.combine(fs.getDir(program), "player_database.json")
    if not fs.exists(databasePath) then return end

    local file = fs.open(databasePath, "r")
    if not file then return end
    local contents = file.readAll()
    file.close()
    if not textutils or type(textutils.unserializeJSON) ~= "function" then return end

    local ok, saved = pcall(textutils.unserializeJSON, contents)
    if ok and type(saved) == "table" then
        for id, profile in pairs(saved) do
            if type(id) == "string" and type(profile) == "table" then
                if profile.id ~= nil then
                    profile.id = nil
                    dirty = true
                end
                profile.names = type(profile.names) == "table" and profile.names or {}
                profile.observations = type(profile.observations) == "table"
                    and profile.observations or {}
                profile.visits = type(profile.visits) == "table" and profile.visits or {}
                for _, visit in ipairs(profile.visits) do
                    if type(visit) == "table" and visit.id ~= nil then
                        visit.id = nil
                        dirty = true
                    end
                end
                if type(profile.activeVisit) == "table" and profile.activeVisit.id ~= nil then
                    profile.activeVisit.id = nil
                    dirty = true
                end
                profiles[id] = profile
            end
        end
    end
end

local function save(now)
    if not textutils or type(textutils.serializeJSON) ~= "function" then return end
    local ok, contents = pcall(textutils.serializeJSON, profiles)
    if not ok then return end
    contents = prettyJson(contents)
    local file = fs.open(databasePath, "w")
    if not file then return end
    file.write(contents)
    file.close()
    dirty = false
    lastSavedAt = now
end

load()

function M.observe(players, now, options)
    now = now or os.epoch("utc")
    options = options or {}
    local sampleInterval = (options.sampleIntervalSeconds or 30) * 1000
    local stationaryInterval = (options.stationaryIntervalSeconds or 300) * 1000
    local minMove = options.minMoveBlocks or 4
    local maxObservations = options.maxObservations or 2000

    for _, player in ipairs(type(players) == "table" and players or {}) do
        if type(player) == "table" and player.id ~= nil then
            local id = normalizeId(player.id)
            local profile = profiles[id]
            if not profile then
                profile = {
                    name = nil,
                    names = {},
                    firstSeen = now,
                    lastSeen = now,
                    baseLocation = "",
                    party = "",
                    notes = "",
                    observations = {},
                    visits = {}
                }
                profiles[id] = profile
                dirty = true
            end

            profile.firstSeen = profile.firstSeen or now
            profile.lastSeen = now
            profile.accessStatus = profile.accessStatus or "UNLISTED"

            local name = type(player.name) == "string" and player.name or nil
            if name and name ~= tostring(player.id) then
                if profile.name ~= name then
                    profile.name = name
                    local known = false
                    for _, entry in ipairs(profile.names) do
                        if entry.name == name then
                            entry.lastSeen = now
                            known = true
                            break
                        end
                    end
                    if not known then
                        profile.names[#profile.names + 1] = { name = name, firstSeen = now, lastSeen = now }
                    end
                    dirty = true
                else
                    local latest = profile.names[#profile.names]
                    if latest and latest.name == name then latest.lastSeen = now end
                end
            end

            local position = copyPosition(player.position)
            if position then
                profile.lastPosition = position
                profile.lastPositionAt = now
                local lastObservation = profile.observations[#profile.observations]
                local elapsed = lastObservation and now - lastObservation.time or math.huge
                local moved = lastObservation and distance(position, lastObservation) or math.huge
                if not lastObservation
                    or (elapsed >= sampleInterval and moved >= minMove)
                    or elapsed >= stationaryInterval then
                    profile.observations[#profile.observations + 1] = {
                        time = now,
                        x = position.x,
                        y = position.y,
                        z = position.z
                    }
                    while #profile.observations > maxObservations do
                        table.remove(profile.observations, 1)
                    end
                    dirty = true
                end
            end
            dirty = true -- Persist lastSeen at the normal save interval.
        end
    end

    if dirty and now - lastSavedAt >= saveIntervalMs then save(now) end
end

function M.updateVisits(players, now, leaveGraceSeconds)
    now = now or os.epoch("utc")
    local graceMs = math.max(0, (leaveGraceSeconds or 5) * 1000)

    -- End stale visits first so a returning player starts a fresh visit.
    for id, profile in pairs(profiles) do
        local visit = profile.activeVisit
        if type(visit) == "table"
            and now - (visit.lastSeen or visit.firstSeen or now) >= graceMs then
            profile.visits = type(profile.visits) == "table" and profile.visits or {}
            local firstSeen = visit.firstSeen or now
            local lastSeen = visit.lastSeen or now
            profile.visits[#profile.visits + 1] = {
                firstSeen = firstSeen,
                lastSeen = lastSeen,
                leftAt = now,
                duration = math.max(0, (lastSeen - firstSeen) / 1000),
                status = "LEFT"
            }
            profile.activeVisit = nil
            dirty = true
        end
    end

    for _, player in ipairs(type(players) == "table" and players or {}) do
        if type(player) == "table" and player.id ~= nil then
            local id = normalizeId(player.id)
            local profile = profiles[id]
            if profile then
                if type(profile.activeVisit) ~= "table" then
                    profile.activeVisit = { firstSeen = now, lastSeen = now }
                else
                    profile.activeVisit.lastSeen = now
                end
                dirty = true
            end
        end
    end

    if dirty and now - lastSavedAt >= saveIntervalMs then save(now) end
end

function M.getVisitorRows(now, sensorOnline)
    now = now or os.epoch("utc")
    local rows = {}
    for id, profile in pairs(profiles) do
        for _, visit in ipairs(profile.visits or {}) do
            rows[#rows + 1] = {
                id = id,
                name = profile.name or id,
                party = profile.party or "",
                baseLocation = profile.baseLocation or "",
                accessStatus = profile.accessStatus or "UNLISTED",
                firstSeen = visit.firstSeen,
                lastSeen = visit.lastSeen,
                leftAt = visit.leftAt,
                duration = visit.duration,
                status = visit.status or "LEFT"
            }
        end

        local visit = profile.activeVisit
        if type(visit) == "table" then
            local endTime = sensorOnline == false and (visit.lastSeen or now) or now
            rows[#rows + 1] = {
                id = id,
                name = profile.name or id,
                party = profile.party or "",
                baseLocation = profile.baseLocation or "",
                accessStatus = profile.accessStatus or "UNLISTED",
                firstSeen = visit.firstSeen,
                lastSeen = visit.lastSeen,
                duration = math.max(0, (endTime - (visit.firstSeen or endTime)) / 1000),
                status = sensorOnline == false and "UNKNOWN" or "IN BASE"
            }
        end
    end
    table.sort(rows, function(a, b)
        return (a.firstSeen or 0) > (b.firstSeen or 0)
    end)
    return rows
end

function M.getProfile(id)
    local key = normalizeId(id)
    return key and profiles[key] or nil
end

function M.getProfiles()
    return profiles
end

function M.setProfile(id, fields)
    local key = normalizeId(id)
    assert(key, "Player UUID fehlt")
    assert(type(fields) == "table", "Profile fields must be a table")

    local profile = profiles[key]
    if not profile then
        profile = {
            name = fields.name and tostring(fields.name) or nil,
            names = {},
            observations = {},
            visits = {},
            baseLocation = "",
            party = "",
            notes = "",
            accessStatus = "UNLISTED"
        }
        profiles[key] = profile
    end

    for _, field in ipairs({ "baseLocation", "party", "notes" }) do
        if fields[field] ~= nil then profile[field] = tostring(fields[field]) end
    end
    if fields.name ~= nil then profile.name = tostring(fields.name) end
    if fields.accessStatus ~= nil then
        local status = tostring(fields.accessStatus):upper()
        assert(status == "UNLISTED" or status == "WHITELISTED" or status == "BLACKLISTED",
            "accessStatus must be UNLISTED, WHITELISTED, or BLACKLISTED")
        profile.accessStatus = status
    end
    profile.accessStatus = profile.accessStatus or "UNLISTED"
    dirty = true
    save(os.epoch("utc"))
    return profile
end

return M
