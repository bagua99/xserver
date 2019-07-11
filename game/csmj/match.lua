local player_mgr = require "player_mgr"
local logic = require "logic"
local room = require "room"
local skynet = require "skynet"

local M = {}

function M:init()
    self.status = "free"
    self.bank_user = 0
    self.bank_score = 0
    self.bank_count = 0
    self.count = 1
    self.total_count = 15

    self.nDissoveSeat = 0
    -- 解散开始时间
    self.nDissoveStartTime = 0
    -- 检测时间
    self.nDissoveTime = 300

    self.bBegin = false
    self.start_time = os.time()
    -- 检测开始时间
    self.nCheckStartTime = os.time()
    -- 检测时间
    self.nCheckTime = 3600
    -- 检测房间
    skynet.timeout(5*100, function() self:check_room() end)
end

-- 检测房间
function M:check_room()
    local nTime = os.time()
    -- 超过1小小时,房间解散
    if self.nCheckStartTime ~= 0 and nTime >= self.nCheckStartTime + self.nCheckTime then
        -- 超时解散
        player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 4, voteResult = {}})
        if self.bBegin then
            self:big_result_xia_zhuang()
            player_mgr:notify_big_result()
        end
        -- 解散服务
        self:big_result()
    -- 投票5分钟自动解散
    elseif self.nDissoveStartTime ~= 0 and nTime >= self.nDissoveStartTime + self.nDissoveTime then
        -- 投票结果回复
        player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 3, voteResult = {}})
        if self.bBegin then
            self:big_result_xia_zhuang()
            player_mgr:notify_big_result()
        end
        -- 解散服务
        self:big_result()
    else
        skynet.timeout(5*100, function() self:check_room() end)
    end
end

function M:getDissoveTime()
    if self.nDissoveStartTime == 0 then
        return self.nDissoveTime
    end

    return self.nDissoveStartTime + self.nDissoveTime - os.time()
end

-- 定位投票解散
function M:GameLBSVoteReq(userid, _)
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    if self.bBegin then
        return
    end

    -- 解散房间成功
    player_mgr:broadcast("protocol.GameLBSVoteAck", {})

    -- 解散服务
    self:big_result()
end

-- 离开请求
function M:GameLeaveReq(userid, _)
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    local nSeat = _player.seat
    if self.bBegin then
        return
    end

    -- 房主
    if userid == room.get_option("master_id") then
        -- 解散房间成功
        player_mgr:broadcast("protocol.GameLeaveAck", {nResult = 2, nSeat = nSeat})

        -- 解散服务
        self:big_result()
    else
        -- 给玩家发送离开
        player_mgr:broadcast("protocol.GameLeaveAck", {nResult = 1, nSeat = nSeat})

        -- 广播所有人
        player_mgr:broadcast("dgnn.GAME_PlayerLeaveAck", {nSeat = nSeat})

        -- 设置此位置未准备
        _player:setReady(false)

        -- 离开房间
        local players =
        {
            userid,
        }
        player_mgr:leave_room(players)
    end
end

-- 投票请求
function M:GameVoteReq(userid, msg)
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
        self.nDissoveStartTime = os.time()
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
    player_mgr:broadcast("protocol.GameVoteAck", {nDissoveSeat = self.nDissoveSeat, vote = tVote})

    -- 有人拒绝,info.不能解散
    if nRefuseCount >= 1 then
        self.nDissoveSeat = 0
        self.nDissoveStartTime = 0
        player_mgr:clear_vote_info()

        -- 投票结果回复
        player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 0, voteResult = tVoteResult})
    elseif nAgreeCount == nAllCount then
        self.nDissoveSeat = 0
        self.nDissoveStartTime = 0

        if self.bBegin then
            -- 投票结果回复
            player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 1, voteResult = tVoteResult})
            self:big_result_xia_zhuang()
            player_mgr:notify_big_result()
        else
            -- 投票结果回复
            player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 3, voteResult = tVoteResult})
        end
        self:big_result()
    elseif not self.bBegin and userid == room.get_option("master_id") then    -- 游戏未开始解散
        self.nDissoveSeat = 0
        self.nDissoveStartTime = 0

        -- 投票结果回复
        player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 2, voteResult = tVoteResult})
        self:big_result()
    end
end

-- 开始第一把
function M:begin()
    self.count = 1
    self.status = "play"

    self.bBegin = true
    -- 开始时间,创建房间50分钟，然后游戏才开始，
    -- 不然10分钟，游戏被解散，这里要重置下时间
    self.nCheckStartTime = os.time()

    -- 房主坐庄
    local fang_zu = player_mgr:get(room.get_option("master_id"))
    --[[
    msg =
    {
        head =
        {
            room_id,            房间ID
            game_id,            游戏ID
            count,              房间第几局
            start_time,         房间开始时间
            end_time,           房间结束时间
        },
        players =
        {
            {
                userid,         玩家ID
                nickname,       玩家名字
                score,          本局输赢分
                total_score,    本局结束总分
            },
        },
        game =
        {
            room = {},
            players = {},
            prepare_data = {},
            data =
            {
                {
                    time,
                    name,
                    msg,
                }
            },
        },
    }
    --]]
    -- 回放数据
    self.record =
    {
        head = {},
        players = {},
        game =
        {
            room = room.dump(),
            players = player_mgr:dump(self),
            prepare_data = {nCurrentSeat = fang_zu.seat},
            data = {},
        }
    }
    self:shang_zhuang(fang_zu.seat)

    for _,p in pairs(player_mgr.tbl) do
        p:begin()
    end

    -- 进入押注状态
    self:to_callscore()
end

-- 切换到准备状态
function M:to_ready()
    self.count = self.count + 1
    self.status = "ready"

    for _,p in pairs(player_mgr.tbl) do
        p:begin()
    end
end

-- 切换到下注状态
function M:to_callscore()
    self.status = "callscore"
    self:fapai()
    player_mgr:broadcast("dgnn.GAME_GameStartAck",{})

    -- 给庄家发牌
    local p = player_mgr:get_by_seat(self.bank_user)
    if p then
        local msg = {
            nCallScoreUser = p.seat,
            cards = p.cards,
            type = p:get_card_type()
        }
        p:send("dgnn.GAME_CallScoreAck", msg)
    end

    -- 回放
    table.insert(self.record.game.data, {time = os.time(), name = "dgnn.GAME_GameStartAck", msg = {}})
end

-- 切换到算牛状态
function M:to_suanniu()
    self.status = "suanniu"
    player_mgr:broadcast("dgnn.GAME_GameSuanNiuBeginAck", {})
    -- 回放
    table.insert(self.record.game.data, {time = os.time(), name = "dgnn.GAME_GameSuanNiuBeginAck", msg = {}})
end

-- 上庄
function M:shang_zhuang(seat)
    self.bank_user = seat
    self.bank_score = room.bank_score
    self.bank_count = 1
    local p = player_mgr:get_by_seat(seat)
    p.score = p.score - room.bank_score

    local msg = {
        bank_score = room.bank_score,
        bank_user_seat = p.seat,
        bank_user_score = p.score
    }
    player_mgr:broadcast("dgnn.GAME_GameShangZhuangAck", msg)
    -- 回放
    table.insert(self.record.game.data, {time = os.time(), name = "dgnn.GAME_GameShangZhuangAck", msg = msg})
end

-- 下庄
function M:xia_zhuang()
    local p = player_mgr:get_by_seat(self.bank_user)
    p.score = p.score + self.bank_score
    self.bank_user = 0
    self.bank_score = 0
    self.bank_count = 0
    local msg = {
        old_bank_user_seat = p.seat,
        old_bank_user_score = p.score
    }
    player_mgr:broadcast("dgnn.GAME_GameXiaZhuangAck", msg)
    -- 回放
    table.insert(self.record.game.data, {time = os.time(), name = "dgnn.GAME_GameXiaZhuangAck", msg = msg})
end

-- 起牌
function M:get_card()
    return table.remove(self.cards)
end

function M:fapai()
    self.cards = logic.shuffle(room.has_face_card())
    player_mgr:fapai(self)
end


function M:result()
    self:score_result()
    if self:zhuang_result() then
        self:to_ready()
    else
        player_mgr:notify_big_result()
        self:big_result()
    end
end

-- 处理分不够，换庄
function M:zhuang_result()
    -- 当庄局数有上限
    if self.bank_score > 0 and self.bank_count < room.max_bank_count then
        self.bank_count = self.bank_count + 1
        return true
    end

    local old_bank_user = self.bank_user
    self:xia_zhuang()

    return self:next_zhuang(old_bank_user)
end

function M:next_zhuang(old_bank_user)
    local next_zhuang
    -- 找接庄的人
    for i=1,4 do
        local seat = old_bank_user + i
        if seat > room.max then
            break
        end
        local p = player_mgr:get_by_seat(seat)
        if p and p.score >= room.bank_score then
            next_zhuang = p.seat
            break
        end
    end

    print("获取下个庄家", old_bank_user, next_zhuang)
    if next_zhuang then
        self:shang_zhuang(next_zhuang)
        return true
    end
    return false
end

-- 分数结算
function M:score_result()
    -- 玩家大小排序
    local t = {}
    for _,p in pairs(player_mgr.tbl) do
        if p.suanniu then
            table.insert(t, p)
        end
    end

    local function cmp(p1, p2)
        return logic.compareCard(p2.cards, p1.cards, true)
    end

    table.sort(t, cmp)

    local end_msg = {infos={}}

    local bank_p = player_mgr:get_by_seat(self.bank_user)
    local bank_base = bank_p:get_card_base()
    local old_bank_score = self.bank_score

    self:loser_result(t, bank_base, end_msg)
    self:winer_result(t, end_msg)
    bank_p:set_niu(bank_p:get_card_type())
    local info = {
        seat = bank_p.seat,
        score = self.bank_score - old_bank_score,
        total_score = bank_p:get_score(),
        cards = bank_p:get_cards(),
        type = bank_p:get_card_type()
    }
    table.insert(end_msg.infos, info)

    for _,p in pairs(player_mgr.tbl) do
        if not p.out then
            local out
            if p.seat == self.bank_user then
                if self.bank_score <= 0 and p.score < room.min_call_score then
                    out = true
                end
            else
                if p.score < room.min_call_score then
                    out = true
                end
            end

            if out then
                p.out = true
                player_mgr:broadcast(
                    "dgnn.GAME_GameOutAck",
                    {seat=p.seat})
            end
        end
    end

    end_msg.bank_score = self.bank_score
    end_msg.bank_count = self.bank_count
    player_mgr:broadcast("dgnn.GAME_GameEndAck", end_msg)
    -- 回放
    table.insert(self.record.game.data, {time = os.time(), name = "dgnn.GAME_GameEndAck", msg = end_msg})
    if not player_mgr:check_out() then
        self:big_result_xia_zhuang()
        player_mgr:notify_big_result()
        self:big_result()
    end
end

-- 计算比庄家小的分数
function M:loser_result(t, bank_base, end_msg)
    for _,p in ipairs(t) do
        if p.seat == self.bank_user then
            break
        end

        local score = bank_base * p:get_call_score()
        p:sub_score(score)
        p:set_niu(p:get_card_type())
        self.bank_score = self.bank_score + score
        local info = {
            seat = p.seat,
            score = -score,
            total_score = p:get_score(),
            cards = p:get_cards(),
            type = p:get_card_type(),
            stake = p:get_call_score()
        }
        table.insert(end_msg.infos, info)
   end
end

-- 计算比庄家大的分数
function M:winer_result(t, end_msg)
    for i=#t,1,-1 do
        local p = t[i]
        if p.seat == self.bank_user then
            break
        end

        local score = p:get_card_base() * p:get_call_score()
        if self.bank_score == 0 then
            score = 0
        elseif self.bank_score < score then
            score = self.bank_score
        end
        self.bank_score = self.bank_score - score
        p:add_score(score)
        p:set_niu(p:get_card_type())
        local info = {
            seat = p.seat,
            score = score,
            total_score = p:get_score(),
            cards = p:get_cards(),
            type = p:get_card_type(),
            stake = p:get_call_score()
        }
        table.insert(end_msg.infos, info)
    end
end

function M:big_result_xia_zhuang()
    if self.bank_user <= 0 then
        return
    end

    local p = player_mgr:get_by_seat(self.bank_user)
    p.score = p.score + self.bank_score
    self.bank_user = 0
    self.bank_score = 0
    self.bank_count = 0
end

-- 大结算
function M:big_result()
    local ack_msg =
    {
        masterid = room.get_option("master_id"),
        costcard = room.get_option("cost_card"),
        gameid = room.get_option("game_id"),
        roomid = room.get_option("room_id"),
    }
    if self.bBegin then
        ack_msg = nil

        -- 回放
        table.insert(self.record.game.data, {
            time = os.time(),
            name = "dgnn.GAME_GameTotalEndAck",
            msg = player_mgr:get_notify_big_result()}
        )
        self.record.head =
        {
            room_id = room.get_option("room_id"),
            game_id = room.get_option("game_id"),
            count = 1,
            start_time = self.start_time,
            end_time = os.time(),
        }
        for _,p in pairs(player_mgr.tbl) do
            table.insert(self.record.players, {
            userid = p.userid,
            nickname = p.nickname,
            score = p:get_score(),
            total_score = p:get_score()}
            )
        end
        -- 发送回放
        room.add_record_list(self.record)
    end
    -- 解散服务
    player_mgr:big_result(ack_msg)
end

return M
