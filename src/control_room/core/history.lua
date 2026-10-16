
local History = {}
History.__index = History

function History.new(windowMs, intervalMs)
    return setmetatable({
        windowMs = windowMs or 3600000,
        intervalMs = intervalMs or 5000,
        points = {},
        lastSample = nil
    }, History)
end

function History:add(value, timestamp)
    if type(value) ~= "number" then
        return
    end

    timestamp = timestamp or os.epoch("utc")

    if self.lastSample
        and timestamp - self.lastSample < self.intervalMs then
        return
    end

    self.lastSample = timestamp
    self.points[#self.points + 1] = {
        time = timestamp,
        value = value
    }

    self:prune(timestamp)
end

function History:prune(now)
    now = now or os.epoch("utc")
    local cutoff = now - self.windowMs

    while #self.points > 0
        and self.points[1].time < cutoff do
        table.remove(self.points, 1)
    end
end

function History:getPoints()
    self:prune()
    return self.points
end

function History:getRate()
    local points = self:getPoints()

    if #points < 2 then
        return nil
    end

    local first = points[1]
    local last = points[#points]
    local seconds = (last.time - first.time) / 1000

    if seconds <= 0 then
        return nil
    end

    return (last.value - first.value) / seconds
end

return History
