-- Small in-process observer bus for immutable provider snapshots.
local SnapshotBus = {}
SnapshotBus.__index = SnapshotBus
local Log = require("core.log")

function SnapshotBus.new()
    return setmetatable({ observers = {}, observerOrder = {}, sequence = 0 }, SnapshotBus)
end

function SnapshotBus:subscribe(name, callback)
    assert(type(name) == "string" and name ~= "", "Observer name is required")
    assert(type(callback) == "function", "Observer callback must be a function")
    assert(not self.observers[name], "Duplicate snapshot observer: " .. name)
    self.observers[name] = callback
    self.observerOrder[#self.observerOrder + 1] = name

    return function()
        self.observers[name] = nil
        for index, registeredName in ipairs(self.observerOrder) do
            if registeredName == name then
                table.remove(self.observerOrder, index)
                break
            end
        end
    end
end

function SnapshotBus:publish(snapshot)
    assert(type(snapshot) == "table", "Snapshot must be a table")
    self.sequence = self.sequence + 1
    snapshot.sequence = self.sequence

    for _, name in ipairs(self.observerOrder) do
        local callback = self.observers[name]
        if callback then
            local ok, err = pcall(callback, snapshot)
            if not ok then
                if tostring(err) == "Terminated" then error(err, 0) end
                Log.write("ERROR", "snapshot_bus",
                    "Observer [" .. name .. "]: " .. tostring(err))
                print("Snapshot-Observer-Fehler [" .. name .. "]: " .. tostring(err))
            end
        end
    end
end

return SnapshotBus
