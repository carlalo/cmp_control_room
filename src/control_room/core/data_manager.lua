-- Polls configured providers and publishes one read-only snapshot per cycle.
local ProviderFactory = require("core.provider_factory")

local M = {}
local sources = {}

local function inlineProviderKey(config)
    local origin = config.origin or {}
    return table.concat({
        tostring(config.type or ""),
        tostring(config.peripheral or ""),
        tostring(origin.x or ""),
        tostring(origin.y or ""),
        tostring(origin.z or "")
    }, "|")
end

function M.loadConfig(config)
    sources = {}
    local providerDefinitions = config.providers or {}
    local providerInstances = {}
    for _, display in ipairs(config.displays or {}) do
        for _, instance in ipairs(display.instances or {}) do
            assert(type(instance.name) == "string" and instance.name ~= "",
                "Snapshot source requires an instance name")
            assert(not sources[instance.name],
                "Duplicate snapshot source: " .. instance.name)
            local providerConfig
            local key
            if type(instance.provider) == "string" then
                key = instance.provider
                providerConfig = providerDefinitions[key]
                assert(type(providerConfig) == "table",
                    "Unknown provider '" .. key .. "' for " .. instance.name)
            elseif type(instance.provider) == "table" then
                providerConfig = instance.provider
                key = inlineProviderKey(providerConfig)
            else
                error("Provider reference missing for " .. instance.name)
            end

            local provider = providerInstances[key]
            if not provider then
                provider = ProviderFactory.create(providerConfig)
                providerInstances[key] = provider
            end
            sources[instance.name] = {
                providerType = providerConfig.type,
                databaseOptions = providerConfig.playerDatabase or {},
                providerKey = key,
                provider = provider
            }
        end
    end
end

function M.update(bus)
    assert(bus and type(bus.publish) == "function", "Snapshot bus is required")
    local capturedAt = os.epoch("utc")
    local snapshot = {
        capturedAt = capturedAt,
        sources = {}
    }
    local reads = {}

    for name, source in pairs(sources) do
        local data = reads[source.providerKey]
        if not data then
            local ok, result = pcall(source.provider.read, source.provider)
            if not ok and tostring(result) == "Terminated" then error(result, 0) end
            if not ok then
                result = {
                    online = false,
                    peripheral = source.provider.peripheralName,
                    error = tostring(result)
                }
            elseif type(result) ~= "table" then
                result = {
                    online = false,
                    peripheral = source.provider.peripheralName,
                    error = "Provider returned no data table"
                }
            end
            reads[source.providerKey] = result
            data = result
        end

        snapshot.sources[name] = {
            providerType = source.providerType,
            databaseOptions = source.databaseOptions,
            capturedAt = capturedAt,
            data = data
        }
    end

    bus:publish(snapshot)
    return snapshot
end

return M
