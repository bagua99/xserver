local skynet = require "skynet"
local socket = require "skynet.socket"
local utils = require "utils"
local packer = require "packer"
local room_mgr = require "room_mgr"

local M = {
    dispatch_tbl = {},
    close_tbl = {},
    heartbeat_tbl = {},
    heartbeat_tick = 1,
    fd_2_index = {}
}

function M:start(conf)
    self.gate = skynet.newservice("gate")
    skynet.call(self.gate, "lua", "open", conf)
    skynet.error("dog listen on port "..conf.port)

    skynet.timeout(300, function() self:check_heartbeat() end)
end

-------------------处理socket消息开始--------------------
function M:open(fd, addr)
    skynet.error("New client from : " .. addr)
    skynet.call(self.gate, "lua", "accept", fd)
    self.fd_2_index[fd] = 1
end

function M:close(fd)
    self:on_close(fd)
    skynet.error("socket close "..fd)
end

function M:error(fd, msg)
    self:on_close(fd)
    skynet.error("socket error "..fd.." msg "..msg)
end

function M:warning(fd, size)
    self:on_close(fd)
    skynet.error(string.format("%dK bytes havn't send out in fd=%d", size, fd))
end

function M:data(fd, data)
    local name, msg, index = packer.unpack(data)
    local cur_index = self.fd_2_index[fd]
    -- 解包失败，非法的客户端,加入黑名单
    if name == nil or cur_index ~= index then
        self:close_and_notify_room(fd)
        return
    end
    self.fd_2_index[fd] = cur_index + 1
    if name ~= "protocol.HeartBeatReq" then
        print("recv msg", name)
        utils.print(msg)
    end
    self:dispatch(fd, name, msg)
end

function M:on_close(fd)
    -- 主动关闭的链接
    if self.close_tbl[fd] then
        return
    end

    self:close_and_notify_room(fd)
end

function M:close_and_notify_room(fd)
    self.heartbeat_tbl[fd] = nil
    local userid, addr = room_mgr:get_userid_addr_by_fd(fd)
    if not addr then
        return
    end

    -- 通知游戏房间玩家掉线
    skynet.send(addr, "lua", "offline", userid)
    room_mgr:detach(fd, userid)
    self:close_conn(fd)
end

function M:close_conn(fd)
    self.heartbeat_tbl[fd] = nil
    self.close_tbl[fd] = true
    skynet.call(self.gate, "lua", "kick", fd)
end

-------------------处理socket消息结束--------------------

-------------------网络消息回调函数开始------------------
function M:register_callback(name, func, obj)
    self.dispatch_tbl[name] = {func = func, obj = obj}
end

function M:dispatch(fd, name, params)
    local t = self.dispatch_tbl[name]
    if t then
        t.func(fd, params)
        return
    end

    local userid, addr = room_mgr:get_userid_addr_by_fd(fd)
    if addr then
        skynet.send(addr, "lua", "msg", userid, name, params)
    else
        error("sock dispatch error "..name)
    end
end

function M:send(userid, name, msg)
    local _ = self
    local fd = room_mgr:get_fd_by_userid(userid)
    if not fd then
        return
    end
    if name ~= "protocol.HeartBeatAck" then
        print("send msg: "..name)
        utils.print(msg)
    end
    socket.write(fd, packer.pack(name, msg))
end

function M:sendfd(fd, name, msg)
    local _ = self
    if name ~= "protocol.HeartBeatAck" then
        print("send msg: "..name)
        utils.print(msg)
    end
    socket.write(fd, packer.pack(name, msg))
end
-------------------网络消息回调函数结束------------------

function M:close_room(msg)
    local fds = room_mgr:close_room(msg)
    for _, fd in ipairs(fds) do
        self:close_conn(fd)
    end
end

function M:leave_room(msg)
    local fds = room_mgr:leave_room(msg)
    for _, fd in ipairs(fds) do
        self:close_conn(fd)
    end
end

function M:on_heartbeat(fd)
    self.heartbeat_tbl[fd] = self.heartbeat_tick
end

function M:check_heartbeat()
    skynet.timeout(300, function() self:check_heartbeat() end)
    local cur_tick = self.heartbeat_tick
    for fd, tick in pairs(self.heartbeat_tbl) do
        if tick + 3 < cur_tick then
            self:close_and_notify_room(fd)
        end
    end
    self.heartbeat_tick = cur_tick + 1
end

return M
