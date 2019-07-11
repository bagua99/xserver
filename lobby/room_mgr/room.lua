
local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)
    M.init(o, ...)
    return o
end

function M:init(msg)
    self.roomid = msg.roomid
    self.gameid = msg.gameid
    self.owner = msg.owner
    self.serverid = msg.server.serverid
    self.host = msg.server.host
    self.ip = msg.server.ip
    self.port = msg.server.port
    self.ticket = msg.ticket
    self.players = {msg.owner}
end

function M:join(userid)
    for _,v in ipairs(self.players) do
        if v == userid then
            return
        end
    end

    table.insert(self.players, userid)
end

function M:leave(userid)
    for i,v in ipairs(self.players) do
        if v == userid then
            table.remove(self.players, i)
            break
        end
    end
end

return M
