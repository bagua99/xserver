local skynet = require "skynet"
local utils = require "utils"
local player = require "player"
local room = require "room"
local M = {}

function M:init()
    self.tbl = {}
    self.info_tbl = {}
    self.seats = {0,0,0,0,0,0,0,0}
    self.dissolve = {}
end

function M:add_info(info)
    print("add_info", info.userid)
    self.info_tbl[info.userid] = info
end

function M:get(userid)
    return self.tbl[userid]
end

function M:get_player_by_seat(seat)
    for _, p in pairs(self.tbl) do
        if p.seat == seat then
            return p
        end
    end
end

function M:seat(p)
    for i,v in ipairs(self.seats) do
        if v == 0 then
            p.seat = i
            self.seats[i] = p.userid
            break
        end
    end
end

function M:add_player(msg)
    print("add_player", msg.userid)
    utils.print(self.info_tbl)
    local info = self.info_tbl[msg.userid]
    if not info then
        return
    end

    local p = self.tbl[msg.userid]
    if not p then
        p = player.new(info)
        self.tbl[msg.userid] = p
        self:seat(p)
    end

    return p
end

function M:broadcast(name, msg)
    for _,p in pairs(self.tbl) do
        p:send(name, msg)
    end
end

function M:broadcast_but(userid, name, msg)
    for _,p in pairs(self.tbl) do
        if p.userid ~= userid then
            p:send(name, msg)
        end
    end
end

function M:dump()
    local t = {}
    for _,p in pairs(self.tbl) do
        table.insert(t, p:dump())
    end
    return t
end

function M:checkReady()
    for _,p in pairs(self.tbl) do
        if not p.ready then
            return false
        end
    end

    return true
end

function M:check_call_score()
    for _,p in pairs(self.tbl) do
        if not p.call_score and not p.zhuang then
            return false
        end
    end

    return true
end

function M:fapai(match)
    for _,p in pairs(self.tbl) do
        local cards = {}
        for _=1,5 do
            table.insert(cards, match:get_card())
        end
        print("发牌",p.nickname)
        utils.print(cards)
        p:set_cards(cards)
    end
end

function M:notify_big_result()
    self.status = "bigfinish"
    local msg = {infos={}}
    for _,p in pairs(self.tbl) do
        local info = p:dump_big_result()
        table.insert(msg.infos, info)
    end
    self:broadcast("nn.GAME_GameTotalEndAck", msg)
end

-- 通知网关断开连接
function M:big_result()
    local msg = {
        roomid = room.roomid,
        players = {}
    }

    for _,p in pairs(self.tbl) do
        table.insert(msg.players, p.userid)
    end
    skynet.send("dog", "lua", "room_finish", msg)
    skynet.send("room_mgr", "lua", "room_finish", msg)
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

return M
