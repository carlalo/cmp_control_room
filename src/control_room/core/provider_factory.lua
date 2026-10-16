
local M = {}

local factories = {
    fluid_tank = function(config)
        return require("providers.fluid_tank").new(
            config.peripheral
        )
    end,
    radar = function(config)
        return require("providers.radar").new(
            config.peripheral,
            config
        )
    end,
    logs = function(config)
        return require("providers.logs").new(config)
    end
}

function M.create(config)
    assert(type(config) == "table", "Provider-Konfiguration fehlt")

    local factory = factories[config.type]
    assert(factory, "Unbekannter Provider-Typ: " .. tostring(config.type))

    return factory(config)
end

return M
