local skynet = require "skynet"

local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)
    M.init(o, ...)
    return o
end

function M:init()
    self.tbl = {}
    self.id = 0
end

-- 时间间隔以毫秒为单位,count=-1表示无限次
function M:add(interval, count, func)
    self.id = self.id + 1
    local id = self.id
    local timer = {interval = math.ceil(interval/10), count = count, func = func}
    self.tbl[id] = timer

    skynet.timeout(timer.interval, function () self:on_timer(id) end)

    return id
end

function M:on_timer(id)
    local timer = self.tbl[id]
    if not timer then
        return
    end

    if timer.count > 0 then
        timer.count = timer.count - 1
    end

    if timer.count ~= 0 then
        skynet.timeout(timer.interval, function() self:on_timer(id) end)
    end

    timer.func()
end

function M:remove(id)
    self.tbl[id] = nil
end

return M
