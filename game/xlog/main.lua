local skynet = require "skynet"
require "skynet.manager"
local file
local log_num = 0
local GAME_ID = skynet.getenv("GAME_ID")
local SERVER_ID = skynet.getenv("SERVER_ID")

local function create_log()
    local name = string.format(
        "log/game.%d.%d.%s.log",
        GAME_ID,
        SERVER_ID,
        os.date("%m_%d_%H%M%S"))
    file = io.open(name, "a+")
    print("file", file)
end

local function close_log()
    if file then
        file:flush()
        io.close(file)
        file = nil
    end
    log_num = 0
end

local CMD = {}

function CMD.start()
    print("cmd start")
    create_log()
end

function CMD.log(str)
    log_num = log_num + 1
    if log_num == 50000 then
        close_log()
        create_log()
        log_num = 0
    end
    local strlog = os.date("%m-%d#%H:%M:%S#")..str.."\n"
    file:write(strlog)
    file:flush()
end

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "xlog接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)

    skynet.register(".xlog")
end)
