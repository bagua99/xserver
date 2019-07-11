local G = require "global"
local room = require "room"
local id_mgr = require "id_mgr"

local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)
    o:init(...)
    return o
end

function M:init()
    self.tbl = {}
    self.room_tbl = {}
end

function M:clear_server(serverid)
    local s = self.tbl[serverid]
    if not s then
        return
    end

    for _, r in pairs(s.room_tbl) do
        G.room_mgr:game_finish({roomid = r.roomid})
    end

    self.tbl[serverid] = nil
end

function M:add_server(info)
    self.tbl[info.serverid] = {
        serverid = info.serverid,
        host = info.host,
        ip = info.ip,
        port = info.port,
        room_tbl = {},
        status = info.status
    }
end

-- 服务器心跳
function M:heartbeat(info)
    -- 游戏服刚启动
    if info.status == "start" then
        -- 释放之前所有房间
        self:clear_server(info.serverid)
        -- 重新记录服务器
        self:add_server(info)
        return {result="success"}
    end

    local s = self.tbl[info.serverid]
    if info.status == "normal" then
        if not s then
            self:add_server(info)
            return {result="room_list"}
        end
        s.status = "normal"
        return {result="success"}
    end

    if s then
        s.status = "normal"
    end

    return {result = "success"}
end

-- 服务器上报所有的房间
function M:room_list(info)
    local s = self.tbl[info.serverid]
    if not s then
        return
    end

    -- 记录游戏服所有的房间
    for _,v in pairs(info.room_tbl) do
        local roomid = v.roomid
        -- 使用房间ID
        id_mgr:use_id(roomid)
        -- 记录游戏服上的房间
        if not G.room_mgr:get_room(roomid) then
            local r = room.new({
                roomid = roomid,
                gameid = v.gameid,
                owner = v.owner,
                server = s,
                ticket = v.ticket,
            })
            for _,userid in ipairs(v.players) do
                if userid ~= v.owner then
                    r:join(userid)
                end
                G.room_mgr.player_2_room[userid] = roomid
            end
            G.room_mgr.room_tbl[roomid] = r
        end
    end
end

-- 服务器停止创建房间
function M:stop_newroom(info)
    local v = self.tbl[info.serverid]
    if v then
        v.status = "stop_newroom"
    end
end

-- 服务器关闭
function M:server_close(info)
    local s = self.tbl[info.serverid]
    if not s then
        return
    end

    for _,v in pairs(s.room_tbl) do
        local r = G.room_mgr.room_tbl[v.roomid]
        G.room_mgr.room_tbl[v.roomid] = nil
        for _, p in r.players do
            if r.roomid == G.room_mgr.player_2_room[p.userid] then
                G.room_mgr.player_2_room[p.userid] = nil
            end
        end
    end
end

-- 获取一个可用的server
function M:get_random_server()
    local array = {}
    for _,server in pairs(self.tbl) do
        if server.status == "normal" then
            table.insert(array, server)
        end
    end

    if not next(array) then
        return
    end

    return array[math.random(1, #array)]
end

function M:add_room(r)
    local s = self.tbl[r.serverid]
    if not s then
        return
    end

    s.room_tbl[r.roomid] = r
end

function M:del_room(r)
    local s = self.tbl[r.serverid]
    if not s then
        return
    end

    s.room_tbl[r.roomid] = nil
end

return M
