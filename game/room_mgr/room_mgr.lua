local skynet = require "skynet"
local room = require "room"

local GAME_ID = skynet.getenv("GAME_ID")
local SERVER_ID = skynet.getenv("SERVER_ID")

-- 房间管理器
local M = {}

function M:init()
    self.tbl = {}
    self.tbl_game = {
        [1] = "pdk",
        [2] = "nn",
        [3] = "dgnn",
        [4] = "nxphz",
        [5] = "csmj",
        [6] = "yzbp",
    }
end

function M:get(id)
    return self.tbl[id]
end

function M:remove(obj)
    self.tbl[obj.id] = nil
end

function M:create_room(info)
    local game = self.tbl_game[info.room.gameid]
    local addr = skynet.newservice(game)
    local r = room.new(info, addr)
    self.tbl[r.roomid] = r
    skynet.call(addr, "lua", "create", info)
    return r
end

function M:join_room(info)
    local r = self.tbl[info.roomid]
    if not r then
        return {result = "room not find"}
    end
    local ret = skynet.call(r.addr, "lua", "join", info)
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
    -- 加入玩家
    r:add_player(info.player)

    return {
        result = "success",
        ticket = r.ticket
    }
end

function M:finish_room(info)
    self.tbl[info.roomid] = nil
end

function M:leave_room(info)
    local r = self.tbl[info.roomid]
    if not r then
        return
    end

    for _, userid in ipairs(info.players) do
        -- 移除玩家
        r:remove_player(userid)
    end
end

function M:get_room_addr(roomid)
    local r = self.tbl[roomid]
    return r.addr
end

function M:room_list()
    local gameid = tonumber(GAME_ID)
    local serverid = tonumber(SERVER_ID)
    local msg =
    {
        gameid = gameid,
        serverid = serverid,
        room_tbl = {},
    }
    for roomid, r in pairs(self.tbl) do
        local info =
        {
            roomid = roomid,
            gameid = gameid,
            owner = r.owner,
            ticket = r.ticket,
            players = {},
        }
        for userid, _ in pairs(r.tbl_player) do
            table.insert(info.players, userid)
        end
        table.insert(msg.room_tbl, info)
    end

    return msg
end

return M
