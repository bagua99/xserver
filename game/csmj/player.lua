local skynet = require "skynet"
local logic = require "logic"
local room = require "room"

local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)
    M.init(o, ...)
    return o
end

function M:init(info, msg)
    self.userid = info.userid
    self.nickname = info.nickname
    self.sex = info.sex
    self.headimgurl = info.headimgurl
    self.score = room.init_score
    self.fangka = info.fangka
    self.seat = 0
    self.zhuang = false
    self.callscore = 0
    self.offline_time = 0
    self.latitude = msg.latitude
    self.longitude = msg.longitude
    self.adds = msg.adds

    self.out = false
    self.ready = true
    self.suanniu = false
    self.nius = {}
    self.nVoteState = 0
end

function M:set_cards(cards)
    self.cards = cards
end

function M:get_cards()
    return self.cards
end

function M:get_card_type()
    return logic.getCardType(self.cards)
end

function M:get_card_base()
    return logic.getCardBase(self.cards)
end

function M:get_card_score()
    return logic.getCardBase(self.cards) * (self.callscore or 0)
end

function M:add_score(score)
    self.score = self.score + score
end

function M:sub_score(score)
    self.score = self.score - score
end

function M:get_score()
    return self.score
end

function M:set_niu(niu)
    table.insert(self.nius, niu)
end

function M:dump(match, me)
    local t = {
        userid = self.userid,
        nickname = self.nickname,
        sex = self.sex,
        headimgurl = self.headimgurl,
        score = self.score,
        ip = "127.0.0.1",
        seat = self.seat,
        ready = self.ready,
        latitude = self.latitude,
        longitude = self.longitude,
        adds = self.adds,
        online = self:is_online(),
    }

    if match.status == "callscore" or match.status == "suanniu" then
        t.callscore = self.callscore

        if  t.callscore ~= nil and t.callscore > 0 and me then
            t.cards = self.cards
        end

        if match.bank_user == self.seat and me then
            t.cards = self.cards
        end
    end

    if match.status == "suanniu" then
        t.suanniu = self.suanniu
        if self.suanniu or me then
            t.cards = self.cards
        end
        if self.suanniu then
            t.type = self:get_card_type()
        end
    end

    return t
end

function M:send(name, msg)
    skynet.send("dog", "lua", "send", self.userid, name, msg)
end

-- 上线
function M:online()
    self.offline_time = 0
end

function M:on_offline()
    self.offline_time = os.time()
end

-- 是否断线
function M:is_online()
    return self.offline_time == 0
end

function M:begin()
    self.ready = false
    self.callscore = nil
    self.suanniu = false
    self.cards = nil
end

function M:setReady(ready)
    self.ready = ready
end

function M:call_score(score)
    self.callscore = score
end

function M:get_call_score()
    return self.callscore
end

function M:suan_niu()
    if self.out then
        return false
    end

    if self.suanniu then
        return true
    end
    self.suanniu = true

    return true
end

function M:dump_big_result()
    local info = {
        seat = self.seat,
        total_count = self.score,
        niu_array = self.nius,
    }
    return info
end

function M:set_vote_state(nVoteState)
    self.nVoteState = nVoteState
end

function M:get_vote_state()
    return self.nVoteState
end

return M
