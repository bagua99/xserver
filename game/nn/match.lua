local skynet = require "skynet"
local player_mgr = require "player_mgr"
local utils = require "utils"
local logic = require "logic"
local room = require "room"

local M = {}

function M:init()
    self.status = "ready"
    self.bank_user = 1
    self.count = 0
    self.total_count = 14

    self.nDissoveSeat = 0
end

-- 离开请求
function M:GAME_GameLeaveReq(userid, _)
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    local nSeat = _player.seat
    if self.count ~= 0 then
        return
    end

    -- 房主
    if userid == room:get_option("master_id") then
        -- 解散房间成功
        player_mgr:broadcast("nn.GAME_GameLeaveAck", {nResult = 2, nSeat = nSeat})

        -- 解散服务
        player_mgr:big_result()
    else
        -- 给玩家发送离开
        _player:send("nn.GAME_GameLeaveAck", {nResult = 1, nSeat = nSeat})

        -- 广播所有人
        player_mgr:broadcast("nn.GAME_PlayerLeaveAck", {nSeat = nSeat})
    end
end

-- 投票请求
function M:GAME_GameVoteReq(userid, msg)
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    local nSeat = _player.seat
    -- 已投过票
    if _player.nVoteState ~= 0 then
        return
    end

    -- 解散位置
    if self.nDissoveSeat == 0 then
        self.nDissoveSeat = nSeat
    end
    local nVoteState = msg.bAgree and 1 or 2
    _player:set_vote_state(nVoteState)
    -- 获取投票信息
    local tVoteInfo = player_mgr:get_vote_info()

    -- 总玩家数量
    local nAllCount = 0
    -- 拒绝玩家数量
    local nRefuseCount = 0
    -- 同意玩家数量
    local nAgreeCount = 0
    for _, tInfo in ipairs(tVoteInfo) do
        -- 总玩家数量
        nAllCount = nAllCount + 1
        -- 同意玩家数量
        if tInfo.nVoteState == 1 then
            nAgreeCount = nAgreeCount + 1
        -- 拒绝玩家
        elseif tInfo.nVoteState == 2 then
            nRefuseCount = nRefuseCount + 1
        end
    end

    local tVote = {}
    local tVoteResult = {}
    for _, tInfo in ipairs(tVoteInfo) do
        table.insert(tVote, {nSeat = tInfo.nSeat, nVoteState = tInfo.nVoteState})
        table.insert(tVoteResult, {nSeat = tInfo.nSeat, nVoteState = tInfo.nVoteState})
    end
    -- 投票回复
    player_mgr:broadcast("nn.GAME_GameVoteAck", {nDissoveSeat = self.nDissoveSeat, vote = tVote})

    -- 有人拒绝,不能解散
    if nRefuseCount >= 1 then
        -- 投票结果回复
        player_mgr:broadcast("nn.GAME_GameVoteResultAck", {nResult = 0, voteResult = tVoteResult})
    elseif nAgreeCount == nAllCount then
        -- 投票结果回复
        player_mgr:broadcast("nn.GAME_GameVoteResultAck", {nResult = 1, voteResult = tVoteResult})
        -- 总结算
        player_mgr:notify_big_result()
        -- 解散服务
        player_mgr:big_result()
    else
        return
    end

    self.nDissoveSeat = 0
    player_mgr:clear_vote_info()
end

function M:begin()
    self.count = self.count + 1
    self.status = "ready"
    player_mgr.status = "play"

    for _,p in pairs(player_mgr.tbl) do
        p:begin()
    end
end

function M:start()
    -- 下注状态
    self.status = "callscore"

    local zhuang_p = player_mgr:get_player_by_seat(1)
    zhuang_p.zhuang = true

    player_mgr:broadcast("nn.GAME_GameStartAck", {wBankerUser = 1})
end

function M:get_card()
    return table.remove(self.cards)
end

function M:fapai()
    self.cards = logic.shuffle()
    player_mgr:fapai(self)
end

local function cmp(p1, p2)
    return logic.compareCard(p1.cards, p2.cards)
end

function M:result()
    skynet.timeout(0, function()
        if self.count == 14 then
            self:big_result()
        else
            self:begin()
        end
    end)

    -- 玩家大小排序
    local t = {}
    for _,p in pairs(player_mgr.tbl) do
        table.insert(t, p)
        utils.print(p.cards)
    end

    table.sort(t, cmp)

    local end_msg = {infos={}}

    local bank_p
    bank_p = player_mgr:get_player_by_seat(self.bank_user)
    local bank = false
    local bank_base = bank_p:get_card_base()
    local bank_total_score = 0
    for _,p in ipairs(t) do
        if p.seat ~= self.bank_user then
            local score
            -- 比庄家大
            if bank then
                score = p:get_card_score()
            -- 比庄家小
            else
                score = -bank_base * p:get_call_score()
            end
            p:add_score(score)
            p:set_niu(p:get_card_type())
            bank_total_score = bank_total_score - score
            local info = {
                seat = p.seat,
                score = score,
                total_score = p:get_score(),
                cards = p:get_cards(),
                type = p:get_card_type()
            }
            table.insert(end_msg.infos, info)
        else
            bank = true
        end
    end

    bank_p:add_score(bank_total_score)
    bank_p:set_niu(bank_p:get_card_type())
    local info = {
        seat = bank_p.seat,
        score = bank_total_score,
        total_score = bank_p:get_score(),
        cards = bank_p:get_cards(),
        type = bank_p:get_card_type()
    }
    table.insert(end_msg.infos, info)
    player_mgr:broadcast("nn.GAME_GameEndAck", end_msg)
end

function M:big_result()
    local _ = self
    player_mgr:notify_big_result()
    player_mgr:big_result()
end

function M:change_bank()
    local _ = self
end

return M
