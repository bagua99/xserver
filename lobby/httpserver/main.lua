local skynet = require "skynet"
local socket = require "skynet.socket"

skynet.start(function()
    local agent = {}
    for i = 1, 10 do
        agent[i] = skynet.newservice("httpagent")
    end
    local balance = 1
    local port = skynet.getenv("LOBBY_WEB_PORT")
    skynet.send("xlog", "lua", "log", "Listen web port "..port)
    local id = socket.listen("0.0.0.0", port)
    socket.start(id , function(_id, _)
        skynet.send(agent[balance], "lua", _id)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)
end)
