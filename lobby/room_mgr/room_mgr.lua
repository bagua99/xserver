local skynet = require "skynet"
local id_mgr = require "id_mgr"
local room = require "room"
local G = require "global"
local utils = require "utils"

local M = {}

function M:init()
    id_mgr:init()
    self.room_tbl = {}
    self.player_2_room = {}
end

function M:get_player_info(userid)
    local info = {}
    local roomid = self.player_2_room[userid]
    if not roomid then
        return info
    end

    local r = self.room_tbl[roomid]
    if not r then
        return info
    end

    info.roomid = roomid
    info.gameid = r.gameid
    info.ticket = r.ticket
    info.ip = r.ip
    info.port = r.port

    return info
end

function M:create(msg)
    local gameid = msg.gameid
    local g = G.game_mgr:get(gameid)
    if not g then
        return {result = "game not find"}
    end

    local server = g:get_random_server()
    if not server then
       return {result = "gameserver not find"}
    end

    -- 取得消耗房卡数量
    local costcard = G.game_mgr.get_roomcard(gameid, msg.options)
    if costcard == nil or costcard < 0 then
        return {result = "costcard fail"}
    end

    local roomcard = msg.roomcard
    if roomcard < costcard then
        return {result = "roomcard fail"}
    end

    local roomid = id_mgr:gen_id()
    local req_msg = {
        room = {
            roomid = roomid,
            gameid = gameid,
            costcard = costcard,
            options = msg.options,
        },
        player = msg.player,
    }
    local ret = skynet.call(".httpclient", "lua",
        "post", server.host, "/create_room", req_msg)
    if ret.result ~= "success" then
        return {result = ret.result}
    end

    local r = room.new({
        roomid = roomid,
        gameid = gameid,
        owner = msg.player.userid,
        server = server,
        ticket = ret.ticket
    })
    self.room_tbl[roomid] = r
    self.player_2_room[msg.player.userid] = roomid
    g:add_room(r)
    return {
        result = "success",
        roomid = roomid,
        costcard = costcard,
        ticket = ret.ticket,
        ip = server.ip,
        port = server.port,
    }
end

function M:join(msg)
    local roomid = msg.roomid
    local r = self.room_tbl[roomid]
    if not r then
        return {result = "room not find"}
    end

    local ret = skynet.call(".httpclient", "lua",
        "post", r.host, "/join_room", msg)
    if not ret then
        return {result = "join fail"}
    else
        if not ret.result then
            return {result = "join fail"}
        else
            if ret.result ~= "success" then
                return {result = ret.result}
            end
        end
    end

    -- 加入房间
    r:join(msg.player.userid)
    self.player_2_room[msg.player.userid] = roomid

    return {
        result = "success",
        gameid = r.gameid,
        ticket = r.ticket,
        ip = r.ip,
        port = r.port,
    }
end

-- 来自游戏服的消息，游戏结束
function M:game_finish(info)
    local r = self.room_tbl[info.roomid]
    if not r then
        return
    end

    local roomid = info.roomid
    -- 归还ID
    id_mgr:revert_id(roomid)
    for _, userid in pairs(r.players) do
        self.player_2_room[userid] = nil
    end
    self.room_tbl[roomid] = nil
    local g = G.game_mgr:get(r.gameid)
    if g then
        g:del_room(r)
    end
end

-- 来自游戏服的消息，玩家离开房间
function M:leave_room_result(info)
    local r = self.room_tbl[info.roomid]
    if not r then
        return
    end

    for _, userid in ipairs(info.players) do
        r:leave(userid)
        self.player_2_room[userid] = nil
    end
end

function M:get_room(room_id)
    return self.room_tbl[room_id]
end

function M:info_func()
    local t = {}
    for roomid, r in pairs(self.room_tbl) do
        t[roomid] = {}
        for _, userid in pairs(r.players) do
            table.insert(t[roomid], userid)
        end
    end
    skynet.send(".xlog", "lua", "log", "self.room_tbl="..utils.obj_serialize(t))
end

return M
