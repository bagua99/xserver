local skynet = require "skynet"
local socket = require "skynet.socket"

local visitor = 0
local total_visitor = 0
local function lognum()
    skynet.timeout(60*100, function() lognum() end)
    visitor = 0
    skynet.send("xlog", "lua", "log", "http访问总次数"..total_visitor..",当前分钟次数"..visitor)
end

skynet.start(function()
    local agent = {}
    for i = 1, 20 do
        agent[i] = skynet.newservice("httpagent")
    end
    local balance = 1
    local port = skynet.getenv("LOGIN_LISTEN_PORT")
    skynet.send("xlog", "lua", "log", "Listen web port "..port)
    local id = socket.listen("0.0.0.0", port)
    socket.start(id, function(_id, _)
        total_visitor = total_visitor + 1
        visitor = visitor + 1
        skynet.send(agent[balance], "lua", _id)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)

    skynet.timeout(60*100, function() lognum() end)
end)
