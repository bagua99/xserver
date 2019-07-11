local skynet = require "skynet"
local socket = require "skynet.socket"

skynet.start(function()
    local agent = {}
    for i = 1, 20 do
        agent[i] = skynet.newservice("base_web")
    end
    local balance = 1
    local port = skynet.getenv("BASE_WEB_PORT")
    local id = socket.listen("0.0.0.0", port)
    skynet.send("xlog", "lua", "log", "lobby listen client web port "..port)
    socket.start(id , function(_id, _)
        skynet.send(agent[balance], "lua", _id)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)
end)
