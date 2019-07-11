local skynet = require "skynet"
local player = require "player"
local room = require "room"
local M = {}

function M:init()
    self.tbl = {}
    self.info_tbl = {}
    self.seats = {0,0,0,0,0}
    self.dissolve = {}
end

function M:add_info(info)
    local nCount = 0
    for _, _ in pairs(self.info_tbl) do
        nCount = nCount + 1
    end

    -- 人数满了,不再允许加入
    if nCount >= room.max then
        return {result = "player full"}
    end

    self.info_tbl[info.userid] = info
    return {result = "success"}
end

function M:get(userid)
    return self.tbl[userid]
end

-- 移除玩家
function M:remove(userid)
    local _player = self:get(userid)
    if not _player then
        return
    end
    local nIndex = _player.seat
    self.seats[nIndex] = 0

    self.tbl[userid] = nil
	self.info_tbl[userid] = nil
end

function M:get_by_seat(seat)
    for _, p in pairs(self.tbl) do
        if p.seat == seat then
            return p
        end
    end
end

function M:seat(p)
    if p.userid == room.get_option("master_id") then
        p.ready = false
    end

    for i,v in ipairs(self.seats) do
        if v == 0 then
            p.seat = i
            self.seats[i] = p.userid
            break
        end
    end
end

function M:add_player(msg)
    local info = self.info_tbl[msg.userid]
    if not info then
        return
    end

    local nCount = 0
    for _, _ in pairs(self.tbl) do
        nCount = nCount + 1
    end

    if nCount >= room.max then
        return
    end

    local p = self.tbl[msg.userid]
    if not p then
        p = player.new(info, msg)
        self.tbl[msg.userid] = p
        self:seat(p)
    end

    return p
end

function M:broadcast(name, msg)
    for _,p in pairs(self.tbl) do
        if p:is_online() then
            p:send(name, msg)
        end
    end
end

function M:broadcast_but(userid, name, msg)
    for _,p in pairs(self.tbl) do
        if p:is_online() and p.userid ~= userid then
            p:send(name, msg)
        end
    end
end

-- 玩家离开
function M:leave_room(players)
    local msg = {
        roomid = room.roomid,
        players = players,
    }

    for _,userid in ipairs(players) do
        self:remove(userid)
    end

    skynet.send(".dog", "lua", "leave_room", msg)
    room.leave(msg)
end

function M:dump(match, userid)
    local t = {}
    for _,p in pairs(self.tbl) do
        table.insert(t, p:dump(match, p.userid==userid))
    end
    return t
end

function M:check_ready()
    for _,p in pairs(self.tbl) do
        if not p.ready and not p.out then
            return false
        end
    end

    return true
end

function M:check_begin()
    local nCount = 0
    for _, _ in pairs(self.info_tbl) do
        nCount = nCount + 1
    end
    if nCount == 1 then
        return false
    end

    local master_id = room.get_option("master_id")
    for _,p in pairs(self.tbl) do
        if not p.ready and p.userid ~= master_id then
            return false
        end
    end

    return true
end

function M:check_call_score(match)
    for _,p in pairs(self.tbl) do
        print(p.nickname, p.callscore)
        if not p.out and not p.callscore and p.seat ~= match.bank_user then
            return false
        end
    end

    return true
end

function M:check_suanniu()
    for _, p in pairs(self.tbl) do
        if not p.suanniu and not p.out then
            return false
        end
    end

    return true
end

function M:check_out()
    local not_out = 0
    for _, p in pairs(self.tbl) do
        if  not p.out then
            not_out = not_out + 1
        end
    end

    return not_out > 1
end

function M:fapai(match)
    for _,p in pairs(self.tbl) do
        local cards = {}
        for _=1,5 do
            table.insert(cards, match:get_card())
        end
        p:set_cards(cards)
    end
end

function M:notify_big_result()
    if room.status == "ready" then
        return
    end
    local msg = {infos={}}
    for _,p in pairs(self.tbl) do
        local info = p:dump_big_result()
        table.insert(msg.infos, info)
    end
    self:broadcast("dgnn.GAME_GameTotalEndAck", msg)
end

function M:get_notify_big_result()
    local msg = {infos={}}
    for _,p in pairs(self.tbl) do
        local info = p:dump_big_result()
        table.insert(msg.infos, info)
    end
    return msg
end

-- 通知网关断开连接
function M:big_result(game)
    room.status = "bigfinish"
    local msg = {
        roomid = room.roomid,
        players = {},
        game = game,
    }

    for _,p in pairs(self.tbl) do
        table.insert(msg.players, p.userid)
    end
    skynet.send(".dog", "lua", "room_finish", msg)
    room.finish(msg)
    skynet.exit()
end

-- 获取投票信息
function M:get_vote_info()
    local r = {}
    for _,p in pairs(self.tbl) do
        table.insert(r, {nSeat = p.seat, nVoteState = p.nVoteState})
    end

    return r
end

-- 清除投票信息
function M:clear_vote_info()
    for _,p in pairs(self.tbl) do
        p:set_vote_state(0)
    end
end

function M:get_vote_state()
    local r = {}
    for _,p in pairs(self.tbl) do
        table.insert(r, {nSeat = p.seat, nVoteState = p:get_vote_state()})
    end

    return r
end
return M
