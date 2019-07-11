local skynet = require "skynet"
require "skynet.manager"
local sock_mgr = require "sock_mgr"
local pbc = require "pbc"
local msg_handler = require "msg_handler"
local room_mgr = require "room_mgr"

local CMD = {}

function CMD.start(conf)
    pbc:init()
    sock_mgr:start(conf)
    msg_handler.init()
    room_mgr:init()
end

function CMD.send(userid, name, msg)
    sock_mgr:send(userid, name, msg)
end

function CMD.new_room(info)
    room_mgr:new_room(info)
end

-- 房间结束，关闭所有玩家的链接
function CMD.room_finish(msg)
    sock_mgr:close_room(msg)
end

function CMD.leave_room(msg)
    sock_mgr:leave_room(msg)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, subcmd, ...)
        if cmd == "socket" then
            sock_mgr[subcmd](sock_mgr, ...)
            return
        end

        local f = CMD[cmd]
        if not f then
            assert(f, "dog接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(subcmd, ...)))
        else
            f(subcmd, ...)
        end
    end)

    skynet.register("dog")
end)
