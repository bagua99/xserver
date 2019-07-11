local skynet = require "skynet"

local M = {}

function M:init()
    self.ip = skynet.getenv("LOBBY_IP")
    self.port = skynet.getenv("LOBBY_PORT")
end

function M:dispatch()
    return self.ip, self.port
end

return M
