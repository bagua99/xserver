local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

-- 停止服务
function CMD.close_service()
    -- 停止创建房间
    skynet.send(".httpclient", "lua", "close_service")
end

-- 马上关服
function CMD.close_now()
    skynet.send(".httpclient", "lua", "notify_close")
end

skynet.start(function()
    skynet.dispatch(function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "monitor接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)

    skynet.register(".monitor")
end)
