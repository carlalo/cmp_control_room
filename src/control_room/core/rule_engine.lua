-- Loads every rule module from rules/ and forwards snapshots to each one.
local Log = require("core.log")
local blacklistPresence = require("rules.blacklist_presence")

local M = {}
local logger = Log.new("rule_engine")
local rules = {}

-- Register each rule explicitly with a regular require.
local registeredRules = {
    { name = "blacklist_presence", module = blacklistPresence }
}

function M.loadConfig(rulesConfig)
    rules = {}
    for _, entry in ipairs(registeredRules) do
        local name = entry.name
        local rule = entry.module
        if type(rule) ~= "table" then
            logger.error("Rule '" .. name .. "' must return a table")
        else
            local configured, err = true, nil
            if type(rule.loadConfig) == "function" then
                configured, err = pcall(rule.loadConfig, (rulesConfig or {})[name])
            end
            if configured then
                rules[#rules + 1] = { name = name, module = rule }
                logger.info("Loaded rule '" .. name .. "'")
            else
                logger.error("Could not configure rule '" .. name .. "': " .. tostring(err))
            end
        end
    end
end

function M.onSnapshot(snapshot)
    for _, entry in ipairs(rules) do
        local ok, err = pcall(entry.module.onSnapshot or function() end, snapshot)
        if not ok then
            logger.error("Rule '" .. entry.name .. "' failed: " .. tostring(err))
        end
    end
end

function M.shutdown()
    for _, entry in ipairs(rules) do
        if type(entry.module.shutdown) == "function" then
            local ok, err = pcall(entry.module.shutdown)
            if not ok then
                logger.error("Rule '" .. entry.name .. "' shutdown failed: " .. tostring(err))
            end
        end
    end
end

return M
