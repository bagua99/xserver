local player_mgr = require "player_mgr"
local utils = require "utils"
local logic = require "logic"
local room = require "room"
local define = require "define"
local skynet = require "skynet"

local M = {}

-- 初始化
function M:init()
    -- 设置随机种子
    math.randomseed(os.time())

    -- 房间相关
    -- 游戏人数
    self.nPlayerCount = room.get("player_count")
    -- 游戏当前局数
    self.nGameCount = 0
    -- 游戏总局数
    self.nTotalGameCount = room.get("game_count")
    -- 游戏状态
    self.nGameState = define.game_free
    -- 庄家
    self.nBankerSeat = 1

    -- 配置相关
    -- 底分
    self.nCellScore = 1

    -- 初始化逻辑类
    logic:init()

    -- 还原数据
    self:restore()

    -- 解散位置
    self.nDissoveSeat = 0
    -- 解散开始时间
    self.nDissoveStartTime = 0
    -- 检测时间
    self.nDissoveTime = 300
    -- 投票信息
    self.tVoteState = {}

    -- 总结算相关
    -- 总共游戏分数
    self.tTotalGameScore = {}
    -- 当庄次数
    self.tBankerCount = {}
    -- 当局最高得分
    self.tMaxScore = {}
    -- 最佳攻庄分
    self.tMaxBankerScore = {}
    -- 赢局数
    self.tWinCount = {}

    for i = 1, self.nPlayerCount do
        self.tVoteState[i] = 0
        self.tTotalGameScore[i] = 0
        self.tBankerCount[i] = 0
        self.tMaxScore[i] = 0
        self.tMaxBankerScore[i] = 0
        self.tWinCount[i] = 0
    end

    self.bBegin = false
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
        -- 解散服务
        self:big_result()
    -- 投票5分钟自动解散
    elseif self.nDissoveStartTime ~= 0 and nTime >= self.nDissoveStartTime + self.nDissoveTime then
        -- 投票结果回复
        player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 3, voteResult = {}})
        -- 解散服务
        self:big_result()
    else
        skynet.timeout(5*100, function() self:check_room() end)
    end
end

function M:big_result()
    local ack_msg =
    {
        masterid = room.get("master_id"),
        costcard = room.get("cost_card"),
        gameid = room.get("game_id"),
        roomid = room.get("room_id"),
    }
    if self.bBegin then
        ack_msg = nil
    end
    -- 解散服务
    player_mgr:big_result(ack_msg)
end

-- 游戏场景重连
function M:onGameScene(userid, _)
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end
    local nSeat = _player:getSeat()

    local vote = {}
    for i = 1, self.nPlayerCount do
        table.insert(vote, {nSeat = i, nVoteState = self.tVoteState[i]})
    end

    local surrenderVote = {}
    for i = 1, self.nPlayerCount do
        surrenderVote[i] = false
    end
    for k, v in pairs(self.tSurrenderVote) do
        surrenderVote[k] = v
    end

    local data = {}
	data.nGameStatus = self.nGameState
	data.nCellScore = self.nCellScore
    data.nDissoveSeat = self.nDissoveSeat
    data.nDissoveTime = self.nDissoveStartTime == 0 and self.nDissoveTime or
                        (self.nDissoveStartTime + self.nDissoveTime) - os.time()
    data.vote = vote
    data.nGameScore = self.tTotalGameScore
    data.nGameCount = self.nGameCount
    data.nTotalGameCount = self.nTotalGameCount
    data.bReady = self.tReady
    data.nBankerSeat = self.nBankerSeat
    data.nCurrentSeat = self.nCurrentSeat
    data.nCardData = self.tCardData[nSeat]
    data.nCallScore = self.nCallScore
    data.nMainCard = self.nMainCard
    data.nPickScore = self.nPickScore
    data.surrenderVote = surrenderVote
	-- 发送断线重连回复
    _player:send("yzbp.GAME_GameSceneAck", data)
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

    local nSeat = _player:getSeat()
    if self.bBegin then
        return
    end

    -- 房主
    if userid == room.get("master_id") then
        -- 解散房间成功
        player_mgr:broadcast("protocol.GameLeaveAck", {nResult = 2, nSeat = nSeat})

        -- 解散服务
        self:big_result()
    else
        -- 给玩家发送离开
        player_mgr:broadcast("protocol.GameLeaveAck", {nResult = 1, nSeat = nSeat})

        -- 广播所有人
        player_mgr:broadcast("yzbp.GAME_PlayerLeaveAck", {nSeat = nSeat})

        -- 设置此位置未准备
        self.tReady[nSeat] = false

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
    local nSeat = _player:getSeat()

    -- 已投过票
    if self.tVoteState[nSeat] ~= 0 then
        return
    end

    -- 解散位置
    if self.nDissoveSeat == 0 then
        self.nDissoveSeat = nSeat
        self.nDissoveStartTime = os.time()
    end
    self.tVoteState[nSeat] = msg.bAgree and 1 or 2

    -- 拒绝玩家数量
    local nRefuseCount = 0
    -- 同意玩家数量
    local nAgreeCount = 0
    for i = 1, self.nPlayerCount do
        -- 同意玩家数量
        if self.tVoteState[i] == 1 then
            nAgreeCount = nAgreeCount + 1
        -- 拒绝玩家
        elseif self.tVoteState[i] == 2 then
            nRefuseCount = nRefuseCount + 1
        end
    end

    local tVote = {}
    local tVoteResult = {}
    for i = 1, #self.tVoteState do
        table.insert(tVote, {nSeat = i, nVoteState = self.tVoteState[i]})
        table.insert(tVoteResult, {nSeat = i, nVoteState = self.tVoteState[i]})
    end
    -- 投票回复
    player_mgr:broadcast("protocol.GameVoteAck", {nDissoveSeat = self.nDissoveSeat, vote = tVote})

    -- 有人拒绝,不能解散
    if nRefuseCount >= 1 then
        -- 投票结果回复
        player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 0, voteResult = tVoteResult})

        self.nDissoveSeat = 0
        self.nDissoveStartTime = 0
        for i = 1, self.nPlayerCount do
            self.tVoteState[i] = 0
        end
    elseif nAgreeCount == self.nPlayerCount then
        self.nDissoveSeat = 0
        self.nDissoveStartTime = 0

        if self.bBegin then
            -- 投票结果回复
            player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 1, voteResult = tVoteResult})
            -- 游戏结束
            self:gameEnd(define.invalid_seat, define.end_dissolve)
        else
            -- 投票结果回复
            player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 3, voteResult = tVoteResult})
        end
        -- 解散服务
        self:big_result()
    elseif not self.bBegin and userid == room.get("master_id") then    -- 游戏未开始解散
        self.nDissoveSeat = 0
        self.nDissoveStartTime = 0

        -- 投票结果回复
        player_mgr:broadcast("protocol.GameVoteResultAck", {nResult = 2, voteResult = tVoteResult})
        -- 解散服务
        self:big_result()
    end
end

-- 准备请求
function M:GAME_ReadyReq(userid, msg)
    -- 不在休闲状态
    if self.nGameState ~= define.game_free then
        return
    end

    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    -- 取得玩家位置
    local nSeat = _player:getSeat()
    if self.tReady[nSeat] == msg.bReady then
        return
    end

    self.tReady[nSeat] = msg.bReady
    -- 广播所有人
    player_mgr:broadcast("yzbp.GAME_ReadyAck", {nSeat = nSeat, bReady = msg.bReady})

    -- 判断是否所有人都准备了
    local nReadyCount = 0
    for i = 1, self.nPlayerCount do
        if self.tReady[i] then
            nReadyCount = nReadyCount + 1
        end
    end
    if nReadyCount ~= self.nPlayerCount then
        return
    end

    -- 游戏开始
    self:gameBegin()
end

-- 叫分请求
function M:GAME_CallScoreReq(userid, msg)
    -- 不在叫分状态
    if self.nGameState ~= define.game_score then
        return
    end

    -- 取得玩家
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    -- 取得玩家位置
    local nSeat = _player:getSeat()
    -- 不是当前玩家操作
    if nSeat ~= self.nCurrentSeat then
        return
    end

    -- 叫过
    if msg.nCallScore == 0 then
        -- 当前没人叫分
        if self.nCallScore == 0 then
            -- 最低叫80分
            msg.nCallScore = define.min_call_score
            self.nCallScore = msg.nCallScore
        end
    else
        -- 比当前叫分少,或者超过最大叫分
        if self.nCallScore ~= 0 and (msg.nCallScore < self.nCallScore or msg.nCallScore > define.max_call_score) then
            return
        end

        -- 设置当前叫分
        self.nCallScore = msg.nCallScore
    end

    -- 记录玩家叫分
    self.tUserCallScore[nSeat] = msg.nCallScore

    -- 获取下一个叫分
    local nNextCallScore = define.invalid_seat
    for i = nSeat, nSeat + self.nPlayerCount do
        -- 获取下个玩家
        local nNextSeat = self:getNextSeat(i)
        -- 玩家没有过
        if self.tUserCallScore[nNextSeat] ~= 0 then
            -- 设置下个叫分玩家
            nNextCallScore = nNextSeat
            break
        end
    end
    -- 最后叫分人数
    local nLastCallCount = 0
    for _, v in pairs(self.tUserCallScore) do
        if v ~= 0 then
            nLastCallCount = nLastCallCount + 1
        end
    end
    -- 只剩1个叫分
    if nLastCallCount == 1 then
        self.nCurrentSeat = nNextCallScore
        nNextCallScore = define.invalid_seat
    end

    -- 广播所有人
    local data = {
        nCurrentSeat = nSeat,
        nCallScore = msg.nCallScore,
        nNextCallScore = nNextCallScore,
        nBankerSeat = self.nCurrentSeat,
        nBankerScore = self.nCallScore,
    }
    player_mgr:broadcast("yzbp.GAME_CallScoreAck", data)
    table.insert(self.record.game.data, {time = os.time(), name = "yzbp.GAME_CallScoreAck", msg = data})

    -- 只剩1个叫分，开始叫主
    if nNextCallScore == define.invalid_seat then
        -- 设置庄家
        self.nBankerSeat = self.nCurrentSeat
        -- 设置叫主状态
        self.nGameState = define.game_main_card
    else
        -- 设置叫分玩家
        self.nCurrentSeat = nNextCallScore
    end
end

-- 叫主请求
function M:GAME_MainCardReq(userid, msg)
    -- 不在叫主状态
    if self.nGameState ~= define.game_main_card then
        return
    end

    -- 取得玩家
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    -- 取得玩家位置
    local nSeat = _player:getSeat()
    -- 不是庄家操作
    if nSeat ~= self.nBankerSeat then
        return
    end

    -- 设置埋底状态
    self.nGameState = define.game_bury_card
    -- 设置叫主
    self.nMainCard = msg.nCardData
    -- 设置主牌
    logic:setMainColor(msg.nCardData)

    -- 广播所有人叫主结果
    local main_card_data = {
        nCurrentSeat = nSeat,
        nCardData = msg.nCardData,
    }
    player_mgr:broadcast("yzbp.GAME_MainCardAck", main_card_data)
    table.insert(self.record.game.data, {time = os.time(), name = "yzbp.GAME_MainCardAck", msg = main_card_data})

    -- 庄家增加底牌
    for _, v in pairs(self.tBackCard) do
        table.insert(self.tCardData[nSeat], v)
    end

    -- 向庄家发送底牌
    local data = {
        nCurrentSeat = self.nCurrentSeat,
        nCardData = self.tBackCard,
    }
    _player:send("yzbp.GAME_SendBackCardAck", data)
    table.insert(self.record.game.data, {time = os.time(), name = "yzbp.GAME_SendBackCardAck", msg = data})
end

-- 投降
function M:GAME_SurrenderReq(userid, _)
    -- 不在埋底状态
    if self.nGameState ~= define.game_bury_card then
        return
    end

    -- 取得玩家
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    -- 取得玩家位置
    local nSeat = _player:getSeat()
    -- 不是庄家操作
    if nSeat ~= self.nBankerSeat then
        return
    end

    -- 设置投降状态
    self.nGameState = define.game_surrender
    -- 初始化投降投票
    self.tSurrenderVote = {}

    -- 广播所有人投降
    local data = {
        nCurrentSeat =nSeat,
    }
    player_mgr:broadcast("yzbp.GAME_SurrenderAck", data)
end

-- 投降投票
function M:GAME_SurrenderVoteReq(userid, msg)
     -- 不在投降状态
     if self.nGameState ~= define.game_surrender then
        return
    end

    -- 取得玩家
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    -- 取得玩家位置
    local nSeat = _player:getSeat()
    -- 是庄家操作
    if nSeat == self.nBankerSeat then
        return
    end

    -- 已投票
    if self.tSurrenderVote[nSeat] then
        return
    end

    -- 设置投票
    self.tSurrenderVote[nSeat] = msg.bAgree

    -- 广播所有人投降
    local data = {
        nCurrentSeat = nSeat,
        bAgree = msg.bAgree,
    }
    player_mgr:broadcast("yzbp.GAME_SurrenderVoteAck", data)

    -- 同意数量
    local nAgreeCount = 0
    -- 不同意位置
    local nDisAgreeIndex = 0
    for k, v in pairs(self.tSurrenderVote) do
        if not v then
            nDisAgreeIndex = k
            break
        else
            nAgreeCount = nAgreeCount + 1
        end
    end

    if nDisAgreeIndex ~= 0 then
        -- 设置埋底状态
        self.nGameState = define.game_bury_card

        -- 广播所有人投降结果投票
        local result_data = {
            nCurrentSeat = nDisAgreeIndex,  -- (0全部同意,不为0表示拒绝位置)
        }
        player_mgr:broadcast("yzbp.GAME_SurrenderVoteResultAck", result_data)
    elseif nAgreeCount == self.nPlayerCount - 1 then
        -- 设置埋底状态
        self.nGameState = define.game_bury_card

        -- 广播所有人投降结果投票
        local result_data = {
            nCurrentSeat = 0,   -- (0全部同意,不为0表示拒绝位置)
        }
        player_mgr:broadcast("yzbp.GAME_SurrenderVoteResultAck", result_data)

        -- 投降结束
        self:gameEnd(define.invalid_seat, define.end_surrender)
    end
end

-- 埋底
function M:GAME_BuryCardReq(userid, msg)
    -- 不在埋底状态
    if self.nGameState ~= define.game_bury_card then
        return
    end

    -- 取得玩家
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    -- 取得玩家位置
    local nSeat = _player:getSeat()
    -- 不是当前玩家操作
    if nSeat ~= self.nBankerSeat then
        return
    end

    -- 底牌数量不对
    if #msg.nCardData ~= define.back_card_count then
        return
    end
    -- 检测牌数据
    if not logic:checkRemoveCard(self.tCardData[nSeat], msg.nCardData) then
        utils.print(self.tCardData[nSeat])
        utils.print(msg.nCardData)
        return
    end
    -- 移除牌
    logic:removeCard(self.tCardData[nSeat], msg.nCardData)

    -- 底牌设置埋底牌
    self.tBackCard = {}
    for _, v in ipairs(msg.nCardData) do
        table.insert(self.tBackCard, v)
    end

    -- 设置游戏状态
    self.nGameState = define.game_play

    -- 向庄家发送埋牌(回放)
    local record_data = {
        nCurrentSeat = self.nBankerSeat,
        nCardData = msg.nCardData,
    }
    table.insert(self.record.game.data, {time = os.time(), name = "yzbp.GAME_BuryCardAck", msg = record_data})
    -- 向玩家发送埋牌结果
    for i = 1, self.nPlayerCount do
        local data
        if i == self.nBankerSeat then
            data = {
                nCurrentSeat = nSeat,
                nCardData = msg.nCardData,
            }
        else
            data = {
                nCurrentSeat = nSeat,
                nCardData = {0,0,0,0,0,0,0,0},
            }
        end
        local player = player_mgr:getInSeat(i)
        if player then
            player:send("yzbp.GAME_BuryCardAck", data)
        end
    end
end

-- 出牌请求
function M:GAME_OutCardReq(userid, msg)
    -- 不在游戏状态
    if self.nGameState ~= define.game_play then
        return
    end

    -- 取得玩家
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    -- 取得玩家位置
    local nSeat = _player:getSeat()
    -- 不是当前玩家操作
    if nSeat ~= self.nCurrentSeat then
        return
    end

    -- 判断参数
    if msg.nCardData == nil or type(msg.nCardData) ~= "table" then
        return
    end

    utils.print(msg.nCardData)
    local tOutCardData = msg.nCardData
    -- 操作玩家牌
    if #tOutCardData > #self.tCardData[nSeat] then
        return
    end

    -- 检测删除扑克
	if not logic:checkRemoveCard(self.tCardData[nSeat], tOutCardData) then
		return
    end

    -- 第一手牌
    if #self.tTurnCardData == 0 then
        local nTurnCardType = logic:analysisCards(tOutCardData)
        -- 错误牌型
        if nTurnCardType == logic.CT_ERROR then
            return
        end

        -- 甩牌
        if nTurnCardType == logic.CT_THROWN then
            -- 只能甩主牌
            for _, v in pairs(tOutCardData) do
                if not logic:isMainColor(v) then
                    return
                end
            end

            -- 其他玩家有主牌,甩牌失败
            for i = 1, self.nPlayerCount do
                if i ~= nSeat then
                    for _, v in pairs(self.tCardData[i]) do
                        if logic:isMainColor(v) then
                            _player:send("yzbp.GAME_PromptAck", {
                                szPrompt = "甩牌失败!",
                            })
                            return
                        end
                    end
                end
            end
        end

        self.tTurnCardData = tOutCardData
        self.nTurnSeat = nSeat
    else
        if logic:checkOutCards(self.tTurnCardData, self.tCardData[nSeat], tOutCardData) ~= 0 then
            _player:send("yzbp.GAME_PromptAck", {
                szPrompt = "出牌失败!",
            })
            return
        end
    end

    -- 移除扑克
    logic:removeCard(self.tCardData[nSeat], tOutCardData)
	-- 出牌记录
    self.tOutCardData[nSeat] = tOutCardData
    utils.print(tOutCardData)

    -- 得分数
    local nScore = 0
    -- 操作类型,0出牌,1新一轮
    local nType = 0
    -- 最大牌玩家
    local nBigSeat = define.invalid_seat
    -- 底牌分
    local nBuckleBottomScore = 0
    -- 扣底倍数
    local nBase = 1
    -- 出牌玩家数量
    local nOutCardUserCount = 0
    for i = 1, self.nPlayerCount do
        if self.tOutCardData[i] ~= nil and #self.tOutCardData[i] > 0 then
            nOutCardUserCount = nOutCardUserCount + 1
        end
    end
    -- 非新一轮
    if nOutCardUserCount ~= self.nPlayerCount then
        local nNextSeat = self:getNextSeat(self.nCurrentSeat)
        -- 设置当前操作玩家
        self.nCurrentSeat = nNextSeat
    else
        -- 设置新一轮
        nType = define.out_card_new_turn
        -- 获取最大玩家
        local nTempSeat = self.nTurnSeat
        for i = self.nTurnSeat, self.nPlayerCount + self.nTurnSeat - 1 do
            -- 获取下个玩家
            local nNextSeat = self:getNextSeat(i)
            -- 比牌
            if not logic:compareCards(self.tOutCardData[nTempSeat], self.tOutCardData[nNextSeat]) then
                nTempSeat = nNextSeat
            end
        end
        -- 设置当前操作玩家
        self.nCurrentSeat = nTempSeat
        -- 设置最大牌玩家
        nBigSeat = nTempSeat

        -- 不是庄家大,加分
        if self.nCurrentSeat ~= self.nBankerSeat then
            for _, tCardData in pairs(self.tOutCardData) do
                for _, v in pairs(tCardData) do
                    local nValue = logic:getCardValue(v)
                    -- 5,10,k
                    if nValue == 0x05 then
                        nScore = nScore + 5
                    elseif nValue == 0x0A or nValue == 0x0D then
                        nScore = nScore + 10
                    end
                end
            end
            self.nPickScore = self.nPickScore + nScore

            local bAllMain = true
            for _, v in pairs(self.tCardData[nTempSeat]) do
                if not logic:isMainColor(v) then
                    bAllMain = true
                    break
                end
            end
            -- 是主牌且无牌了,扣底
            if bAllMain and #self.tCardData[nTempSeat] == 0 then
                -- 设置扣底
                nType = define.out_card_buckle_bottom
                -- 牌类型
                local nCardType = logic:analysisCards(self.tOutCardData[nTempSeat])
                -- 对子
                if nCardType == logic.CT_DUIZI then
                    nBase = 2
                -- 拖拉机
                elseif nCardType == logic.CT_TRACTOR then
                    nBase = #self.tOutCardData[nTempSeat]
                end
                for _, v in pairs(self.tBackCard) do
                    local nValue = logic:getCardValue(v)
                    -- 5,10,k
                    if nValue == 0x05 then
                        nBuckleBottomScore = nBuckleBottomScore + 5*nBase
                    elseif nValue == 0x0A or nValue == 0x0D then
                        nBuckleBottomScore = nBuckleBottomScore + 10*nBase
                    end
                end
                self.nPickScore = self.nPickScore + nBuckleBottomScore
            end
        end
    end

    -- 广播所有人
    local OutCard_data = {
        nCurrentSeat = self.nCurrentSeat,
        nOutCardSeat = nSeat,
        nCardData = tOutCardData,
        nType = nType,
        nScore = nScore,
        nBigSeat = nBigSeat,
    }
    player_mgr:broadcast("yzbp.GAME_OutCardAck", OutCard_data)
    table.insert(self.record.game.data, {time = os.time(), name = "yzbp.GAME_OutCardAck", msg = OutCard_data})

    -- 非出牌(新一轮或结束)
    if nType ~= define.out_card_out then
        -- 正确牌型
        self.tTurnCardData = {}
        -- 出牌玩家
        self.nTurnSeat = define.invalid_seat
        -- 出牌
        self.tOutCardData = {}
    end

    -- 扣底
    if nType == define.out_card_buckle_bottom then
        -- 广播所有人
        local data = {
            nCardData = self.tBackCard,
            nScore = nBuckleBottomScore,
            nBase = nBase,
        }
        player_mgr:broadcast("yzbp.GAME_BuckleBottomAck", data)
        table.insert(self.record.game.data, {time = os.time(), name = "yzbp.GAME_BuckleBottomAck", msg = data})
    end

	-- 结束判断(新一轮,牌为0;或者被扣底了)
    if (nType == define.out_card_new_turn and #self.tCardData[self.nCurrentSeat] == 0)
    or nType == define.out_card_buckle_bottom then
		self:gameEnd(nSeat, define.end_normal)
	end
end

-- 游戏开始
function M:gameBegin()
    if self.nGameState ~= define.game_free then
        return
    end

    self.bBegin = true
    -- 开始时间,创建房间50分钟，然后游戏才开始，
    -- 不然10分钟，游戏被解散，这里要重置下时间
    self.nCheckStartTime = os.time()

    -- 增加游戏局数
    self.nGameCount = self.nGameCount + 1
    -- 设置游戏状态
    self.nGameState = define.game_score
    -- 开始时间
    self.start_time = os.time()

    -- 洗牌
    local tAllCard
    if room.get("pass_six") == 1 then
        tAllCard = {
            0x01,0x02,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,
            0x11,0x12,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,
            0x21,0x22,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,
            0x31,0x32,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,
            0x01,0x02,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,
            0x11,0x12,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,
            0x21,0x22,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,
            0x31,0x32,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,
            0x4E,0x4E,0x4F,0x4F,
        }
        if self.nPlayerCount == 3 then
            define.back_card_count = 9
        else
            define.back_card_count = 8
        end
    else
        tAllCard = {
            0x01,0x02,0x05,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,
            0x11,0x12,0x15,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,
            0x21,0x22,0x25,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,
            0x31,0x32,0x35,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,
            0x01,0x02,0x05,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,
            0x11,0x12,0x15,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,
            0x21,0x22,0x25,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,
            0x31,0x32,0x35,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,
            0x4E,0x4E,0x4F,0x4F,
        }
        if self.nPlayerCount == 3 then
            define.back_card_count = 9
        else
            define.back_card_count = 8
        end
    end
    -- 打乱
    logic:shuffle(tAllCard)

    -- 玩家牌数量
    local nCardCount = math.modf((#tAllCard - define.back_card_count) / self.nPlayerCount)
    -- 玩家牌
    self.tCardData = {}
    -- 玩家分牌
    for i = 1, self.nPlayerCount do
        if self.tCardData[i] == nil then
            self.tCardData[i] = {}
        end
        for j = (i-1)*nCardCount + 1, i*nCardCount do
            table.insert(self.tCardData[i], tAllCard[j])
        end
        -- 排序
        logic:sortCard(self.tCardData[i])
    end
    -- 底牌
    self.tBackCard = {}
    for j = self.nPlayerCount*nCardCount + 1, #tAllCard do
        table.insert(self.tBackCard, tAllCard[j])
    end
    utils.print(self.tCardData)
    utils.print(self.tBackCard)

    -- 第一局,随机庄家
    if self.nGameCount == 1 then
        self.nBankerSeat = math.random(1, self.nPlayerCount)
    end

    self.nCurrentSeat = self.nBankerSeat

    -- 给所有人发送游戏开始
    for i = 1, self.nPlayerCount do
        local _player = player_mgr:getInSeat(i)
        if _player then
            -- 设置玩家分数
            _player:setScore(self.tTotalGameScore[i])
            _player:send("yzbp.GAME_GameStartAck", {nCurrentSeat = self.nCurrentSeat, nCardData = self.tCardData[i]})
        end
    end

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
            players = player_mgr:dump(),
            prepare_data = {nCurrentSeat = self.nCurrentSeat, nCardData = utils.copy_table(self.tCardData)},
            data = {},
        }
    }
end

-- 游戏结束
function M:gameEnd(nSeat, nEndMode)
    -- 正常结束
    if nEndMode == define.end_normal then
		if nSeat == 0 or nSeat > self.nPlayerCount then
			return
        end

		local tGameEnd =
        {
            nGameScore = {},
            nTotalScore = {},
            nBankerSeat = self.nBankerSeat,
            nMainCard = self.nMainCard,
            nCallScore = self.nCallScore,
            nPickScore = self.nPickScore,
            bSurrender = false,
        }
        for i = 1, self.nPlayerCount do
            tGameEnd.nGameScore[i] = 0
            tGameEnd.nTotalScore[i] = 0
        end

        -- 游戏分数
        local nGameScore
        -- 计算法分数
        local nTempScore = 205 - self.nCallScore
        if self.nPickScore < nTempScore then
            -- 大光
            if self.nPickScore == 0 then
                nGameScore = 3
            -- 小光
            elseif self.nPickScore < 30 then
                nGameScore = 2
            else
                nGameScore = 1
            end
        else
            -- 减掉输局分
            nTempScore = self.nPickScore - nTempScore
            -- 判断翻水
            if nTempScore < 40 then
                nGameScore = -1
            elseif nTempScore >= 40 and nTempScore < 80 then
                nGameScore = -2
            elseif nTempScore == 80 then
                nGameScore = -3
            else
                -- 大倒后,20分加一水
                nGameScore = -3 - math.floor((nTempScore - 80)*10/200)
            end
        end

		-- 计算赢家分数
		for i = 1, self.nPlayerCount do
			-- 庄家赢
            if nGameScore > 0 then
                if i ~= self.nBankerSeat then
                    -- 闲家输分
                    tGameEnd.nGameScore[i] = tGameEnd.nGameScore[i] - nGameScore
                    -- 庄家加分
                    tGameEnd.nGameScore[self.nBankerSeat] = tGameEnd.nGameScore[self.nBankerSeat] + nGameScore
                end
            else    -- 闲家赢
                if i ~= self.nBankerSeat then
                    -- 庄家输分
                    tGameEnd.nGameScore[self.nBankerSeat] = tGameEnd.nGameScore[self.nBankerSeat] + nGameScore
                    -- 闲家加分
                    tGameEnd.nGameScore[i] = tGameEnd.nGameScore[i] - nGameScore
                end
			end
		end

		-- 计算总分数
		for i = 1, self.nPlayerCount do
			self.tTotalGameScore[i] = self.tTotalGameScore[i] + tGameEnd.nGameScore[i]
		end
        tGameEnd.nTotalScore = self.tTotalGameScore

        -- 当庄次数
        self.tBankerCount[self.nBankerSeat] = self.tBankerCount[self.nBankerSeat] + 1

		-- 当局最高得分
		for i = 1, self.nPlayerCount do
			if tGameEnd.nGameScore[i] >= self.tMaxScore[i] then
			    self.tMaxScore[i] = tGameEnd.nGameScore[i]
            end
        end

        -- 最佳攻庄分
        for i = 1, self.nPlayerCount do
            if i ~= self.nBankerSeat and self.tMaxBankerScore[i] < self.nPickScore then
                self.tMaxBankerScore[i] = self.nPickScore
            end
        end

        -- 设置赢的局数
        for i = 1, self.nPlayerCount do
            if tGameEnd.nGameScore[i] > 0 then
                self.tWinCount[i] = self.tWinCount[i] + 1
            end
        end

        -- 游戏结束消息广播
        player_mgr:broadcast("yzbp.GAME_GameEndAck", tGameEnd)

        -- 回放
        table.insert(self.record.game.data, {time = os.time(), name = "yzbp.GAME_GameEndAck", msg = tGameEnd})
        self.record.head =
        {
            room_id = room.get("room_id"),
            game_id = room.get("game_id"),
            count = self.nGameCount,
            start_time = self.start_time,
            end_time = os.time(),
        }
        for i = 1, self.nPlayerCount do
            local _player = player_mgr:getInSeat(i)
            table.insert(self.record.players, {
                    userid = _player.userid,
                    nickname = _player.nickname,
                    score = tGameEnd.nGameScore[i],
                    total_score = self.tTotalGameScore[i]}
                )
        end
        -- 发送回放
        room.add_record_list(self.record)

        if self.nGameCount >= self.nTotalGameCount then
            -- 游戏总结算消息广播
            player_mgr:broadcast("yzbp.GAME_GameTotalEndAck", {
                nTotalScore = self.tTotalGameScore,
                nBankerCount = self.tBankerCount,
                nMaxScore = self.tMaxScore,
                nMaxBankerScore = self.tMaxBankerScore,
                nWinCount = self.tWinCount,
            })

            -- 解散服务
            self:big_result()
        end
    -- 解散结束
    elseif nEndMode == define.end_dissolve then
        local tGameEnd =
        {
            nGameScore = {},
            nTotalScore = {},
            nBankerSeat = define.invalid_seat,
            nMainCard = self.nMainCard,
            nCallScore = self.nCallScore,
            nPickScore = self.nPickScore,
            bSurrender = false,
        }

		for i = 1, self.nPlayerCount do
            tGameEnd.nGameScore[i] = 0
            tGameEnd.nTotalScore[i] = 0
        end

        -- 游戏结束消息广播
        player_mgr:broadcast("yzbp.GAME_GameEndAck", tGameEnd)

        -- 游戏总结算消息广播
        player_mgr:broadcast("yzbp.GAME_GameTotalEndAck", {
            nTotalScore = self.tTotalGameScore,
            nBankerCount = self.tBankerCount,
            nMaxScore = self.tMaxScore,
            nMaxBankerScore = self.tMaxBankerScore,
            nWinCount = self.tWinCount,
        })

        -- 解散服务
        self:big_result()
    -- 投降
    elseif nEndMode == define.end_surrender then
        local tGameEnd =
        {
            nGameScore = {},
            nTotalScore = {},
            nBankerSeat = self.nBankerSeat,
            nMainCard = self.nMainCard,
            nCallScore = self.nCallScore,
            nPickScore = self.nPickScore,
            bSurrender = true,
        }
        for i = 1, self.nPlayerCount do
            tGameEnd.nGameScore[i] = 0
            tGameEnd.nTotalScore[i] = 0
        end

        local nGameScore = -1
        -- 叫过分,投降扣2分
        if self.nCallScore ~= define.min_call_score then
            nGameScore = -2
        end
		-- 计算赢家分数
		for i = 1, self.nPlayerCount do
            if i ~= self.nBankerSeat then
                -- 庄家输分
                tGameEnd.nGameScore[self.nBankerSeat] = tGameEnd.nGameScore[self.nBankerSeat] + nGameScore
                -- 闲家加分
                tGameEnd.nGameScore[i] = tGameEnd.nGameScore[i] - nGameScore
            end
		end

		-- 计算总分数
		for i = 1, self.nPlayerCount do
			self.tTotalGameScore[i] = self.tTotalGameScore[i] + tGameEnd.nGameScore[i]
		end
        tGameEnd.nTotalScore = self.tTotalGameScore

		 -- 当庄次数
         self.tBankerCount[self.nBankerSeat] = self.tBankerCount[self.nBankerSeat] + 1

         -- 当局最高得分
         for i = 1, self.nPlayerCount do
             if tGameEnd.nGameScore[i] >= self.tMaxScore[i] then
                 self.tMaxScore[i] = tGameEnd.nGameScore[i]
             end
         end

         -- 最佳攻庄分
         for i = 1, self.nPlayerCount do
             if i ~= self.nBankerSeat and self.tMaxBankerScore[i] < self.nPickScore then
                 self.tMaxBankerScore[i] = self.nPickScore
             end
         end

         -- 设置赢的局数
         for i = 1, self.nPlayerCount do
             if tGameEnd.nGameScore[i] > 0 then
                 self.tWinCount[i] = self.tWinCount[i] + 1
             end
         end

        -- 游戏结束消息广播
        player_mgr:broadcast("yzbp.GAME_GameEndAck", tGameEnd)

        -- 回放
        table.insert(self.record.game.data, {time = os.time(), name = "yzbp.GAME_GameEndAck", msg = tGameEnd})
        self.record.head =
        {
            room_id = room.get("room_id"),
            game_id = room.get("game_id"),
            count = self.nGameCount,
            start_time = self.start_time,
            end_time = os.time(),
        }
        for i = 1, self.nPlayerCount do
            local _player = player_mgr:getInSeat(i)
            table.insert(self.record.players, {
                    userid = _player.userid,
                    nickname = _player.nickname,
                    score = tGameEnd.nGameScore[i],
                    total_score = self.tTotalGameScore[i]}
                )
        end
        -- 发送回放
        room.add_record_list(self.record)

        if self.nGameCount >= self.nTotalGameCount then
            -- 游戏总结算消息广播
            player_mgr:broadcast("yzbp.GAME_GameTotalEndAck", {
                nTotalScore = self.tTotalGameScore,
                nBankerCount = self.tBankerCount,
                nMaxScore = self.tMaxScore,
                nMaxBankerScore = self.tMaxBankerScore,
                nWinCount = self.tWinCount,
            })

            -- 解散服务
            self:big_result()
        end
    end

    -- 还原数据
    self:restore()
end

-- 还原数据
function M:restore()
    -- 设置游戏状态
    self.nGameState = define.game_free
    -- 当前操作玩家
    self.nCurrentSeat = define.invalid_seat
    -- 准备状态
    self.tReady = {}
    -- 玩家牌
    self.tCardData = {}
    -- 底牌
    self.tBackCard = {}
    -- 当前叫分
    self.nCallScore = 0
    -- 玩家叫分
    self.tUserCallScore = {}
    -- 叫主
    self.nMainCard = 0
    -- 投降投票
    self.tSurrenderVote = {}
    -- 正确牌型
    self.tTurnCardData = {}
    -- 出牌玩家
    self.nTurnSeat = define.invalid_seat
    -- 出牌
    self.tOutCardData = {}
    -- 总得分
    self.nPickScore = 0
    for i = 1, self.nPlayerCount do
        self.tReady[i] = false
        self.tUserCallScore[i] = -1
    end
end

-- 获取下个位置
function M:getNextSeat(nSeat)
    local nIndex = (nSeat + (self.nPlayerCount - 1)) % self.nPlayerCount
    return nIndex ~= 0 and nIndex or self.nPlayerCount
end

return M
