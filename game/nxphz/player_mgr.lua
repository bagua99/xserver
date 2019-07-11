local skynet = require "skynet"
local player = require "player"
local define = require "define"
local room = require "room"

local M = {}

-- 初始化
function M:init()
    self.tbl_userinfo = {}
    self.tbl_player = {}
    self.tbl_seat = {}
    for i = 1, define.GAME_PLAYER do
        self.tbl_seat[i] = 0
    end
end

-- 增加玩家信息
function M:add_info(info)
    local nCount = 0
    for _, _ in pairs(self.tbl_userinfo) do
        nCount = nCount + 1
    end

    local player_count = room.get("player_count")
    -- 人数满了,不再允许加入
    if nCount >= player_count then
        return {result = "player full"}
    end

    self.tbl_userinfo[info.userid] = info
    return {result = "success"}
end

-- 增加玩家
function M:add(_player)
    self.tbl_player[player.id] = _player
end

-- 获取玩家
function M:get(userid)
    return self.tbl_player[userid]
end

-- 移除玩家
function M:remove(userid)
    local _player = self:get(userid)
    if not _player then
        return
    end
    local nIndex = _player.seat
    self.tbl_seat[nIndex] = 0

    self.tbl_player[userid] = nil
    self.tbl_userinfo[userid] = nil
end

-- 获取所有玩家
function M:getAll()
    return self.tbl_player
end

-- 通过位置获取玩家
function M:getInSeat(nSeat)
    for _, _player in pairs(self.tbl_player) do
        if nSeat == _player:getSeat() then
            return _player
        end
    end

    return nil
end

-- 增加玩家
function M:add_player(msg)
    local tUserInfo = self.tbl_userinfo[msg.userid]
    if not tUserInfo then
        return nil
    end

    local _player = self.tbl_player[msg.userid]
    if not _player then
        _player = player.new(tUserInfo, msg)
        self.tbl_player[msg.userid] = _player
        self:setSeat(_player)
    end

    return _player
end

-- 广播消息
function M:broadcast(name, msg)
    for _, _player in pairs(self.tbl_player) do
        _player:send(name, msg)
    end
end

-- 排除某个玩家发送消息
function M:broadcast_but(userid, name, msg)
    for id, _player in pairs(self.tbl_player) do
        if id ~= userid then
            _player:send(name, msg)
        end
    end
end

-- 发送消息
function M:send(userid, name, msg)
    local _player = self.tbl_player[userid]
    if not _player then
        return
    end
    _player:send(name, msg)
end

-- 设置玩家位置
function M:setSeat(_player)
    for nIndex, nValue in ipairs(self.tbl_seat) do
        if nValue == 0 then
            _player.seat = nIndex
            self.tbl_seat[nIndex] = _player.userid
            break
        end
    end
end

-- 通知网关断开连接
function M:big_result(game)
    local msg = {
        roomid = room.get("room_id"),
        players = {},
        game = game,
    }

    for _, _player in pairs(self.tbl_player) do
        table.insert(msg.players, _player.userid)
    end
    skynet.send("dog", "lua", "room_finish", msg)
    room.finish(msg)
    skynet.exit()
end

-- 玩家离开
function M:leave_room(players)
    local msg = {
        roomid = room.get("room_id"),
        players = players,
    }

    for _,userid in ipairs(players) do
        self:remove(userid)
    end

    skynet.send("dog", "lua", "leave_room", msg)
    room.leave(msg)
end

-- 导出数据
function M:dump()
    local t = {}
    for _, _player in pairs(self.tbl_player) do
        table.insert(t, _player:dump())
    end
    return t
end

return M
