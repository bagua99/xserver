local skynet = require "skynet"
local sock_mgr = require "sock_mgr"
local room_mgr = require "room_mgr"

local M = {}

-- 登录、断线重连
function M.EnterGameReq(fd, msg)
    local name = "protocol.EnterGameAck"
    local ack_msg =
    {
        err = 0,
    }

    local addr = room_mgr:get_room_addr(msg.roomid)
    print("protocol.EnterGameAck",addr)
    if not addr then
        -- 未找到房间
        ack_msg.err = 2
        sock_mgr:sendfd(fd, name, ack_msg)

        sock_mgr:close_conn(fd)
        return
    end
    local ret = skynet.call(addr, "lua", "enter", msg)
    if not ret then
        -- 进入失败
        ack_msg.err = 2
        sock_mgr:sendfd(fd, name, ack_msg)

        sock_mgr:close_conn(fd)
        return
    else
        -- 游戏返回错误
        if ret.err ~= 0 then
            ack_msg.err = ret.err
            sock_mgr:sendfd(fd, name, ack_msg)

            sock_mgr:close_conn(fd)
            return
        end
    end

    local old_fd = room_mgr:get_fd_by_userid(msg.userid)
    if old_fd then
        sock_mgr:close_conn(old_fd)
    end

    room_mgr:attach(msg.userid, fd, addr)
    sock_mgr:sendfd(fd, name, ack_msg)
    sock_mgr:on_heartbeat(fd)
end

-- 心跳
function M.HeartBeatReq(fd, msg)
    sock_mgr:sendfd(fd, "protocol.HeartBeatAck", msg)
    sock_mgr:on_heartbeat(fd)
end

function M.init()
    sock_mgr:register_callback("protocol.EnterGameReq", M.EnterGameReq)
    sock_mgr:register_callback("protocol.HeartBeatReq", M.HeartBeatReq)
end

return M
