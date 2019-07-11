local utils = require "utils"

local M = {}

function M:init()
    self.room_tbl = {}
    self.addr_tbl = {}
    self.fd_2_userid = {}
    self.fd_2_addr = {}
    self.userid_2_fd = {}
end

function M:new_room(info)
    self.room_tbl[info.roomid] = info
    self.addr_tbl[info.roomid] = info.addr
end

function M:get_room_addr(roomid)
    return self.addr_tbl[roomid]
end

function M:get_userid_addr_by_fd(fd)
    return self.fd_2_userid[fd], self.fd_2_addr[fd]
end

function M:get_fd_by_userid(userid)
    return self.userid_2_fd[userid]
end

function M:attach(userid, fd, addr)
    self.fd_2_addr[fd] = addr
    self.fd_2_userid[fd] = userid
    self.userid_2_fd[userid] = fd
end

function M:detach(fd, userid)
    self.fd_2_addr[fd] = nil
    self.fd_2_userid[fd] = nil
    self.userid_2_fd[userid] = nil
    utils.print(self.fd_2_addr)
    utils.print(self.fd_2_userid)
    utils.print(self.userid_2_fd)
end

function M:get_addr_by_fd(fd)
    return self.fd_2_addr[fd]
end

function M:close_room(msg)
    self.room_tbl[msg.roomid] = nil
    self.addr_tbl[msg.roomid] = nil
    local fds = {}
    for _,userid in ipairs(msg.players) do
        local fd = self.userid_2_fd[userid]
        if fd ~= nil then
            self.fd_2_addr[fd] = nil
            self.fd_2_userid[fd] = nil
            self.userid_2_fd[userid] = nil
            table.insert(fds, fd)
        end
    end
    return fds
end

function M:leave_room(msg)
    local fds = {}
    for _,userid in ipairs(msg.players) do
        local fd = self.userid_2_fd[userid]
        if fd ~= nil then
            self.fd_2_addr[fd] = nil
            self.fd_2_userid[fd] = nil
            self.userid_2_fd[userid] = nil
            table.insert(fds, fd)
        end
    end
    return fds
end

return M
