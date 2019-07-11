local skynet = require "skynet"
local logic = require "logic"

local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)
    M.init(o, ...)
    return o
end

function M:init(info)
    self.userid = info.userid
    self.nickname = info.nickname
    self.sex = info.sex
    self.headimgurl = info.headimgurl
    self.score = info.score
    self.fangka = info.fangka
    self.seat = 0
    self.zhuang = false
    self.callscore = 0

    self.ready = false
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
    self.score = self.score - score
    if self.score < 0 then
        self.score = 0
    end
end

function M:get_score()
    return self.score
end

function M:set_niu(niu)
    table.insert(self.nius, niu)
end

function M:dump()
    return {
        userid = self.userid,
        nickname = self.nickname,
        sex = self.sex,
        headimgurl = self.headimgurl,
        score = self.score,
        ip = "127.0.0.1",
        seat = self.seat,
    }
end

function M:send(name, msg)
    skynet.send("dog", "lua", "send", self.userid, name, msg)
end

function M:begin()
    self.ready = false
    self.callscore = nil
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

return M
