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
    -- 第一局当庄必出牌(黑桃3)
    self.nBankCard = 0x33
    -- 积分输赢翻倍牌(红桃A)
    self.nCodeCard = 0x2A

    -- 还原数据
    self:restore()

    -- 解散位置
    self.nDissoveSeat = 0
    -- 解散开始时间
    self.nDissoveStartTime = 0
    -- 检测时间
    self.nDissoveTime = 300
    self.tVoteState = {}

    -- 总结算相关
    -- 总共炸弹数量
    self.tAllBombCount = {}
    -- 总共游戏分数
    self.tTotalGameScore = {}
    -- 最大分数
    self.tMaxScore = {}
    -- 赢局数
    self.tWinCount = {}

    for i = 1, self.nPlayerCount do
        self.tVoteState[i] = 0
        self.tAllBombCount[i] = 0
        self.tTotalGameScore[i] = 0
        self.tMaxScore[i] = 0
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
    data.nLastOutSeat = self.nTurnSeat
    data.nCurrentSeat = self.nCurrentSeat
    data.nCardData = self.tCardData[nSeat]
    data.nCardCount = {define.card_count, define.card_count, define.card_count}
    local show_card = room.get("show_card")
    if show_card == 1 then
        for nIndex, tCard in ipairs(self.tCardData) do
            data.nCardCount[nIndex] = #tCard
        end
    end
    data.nTurnCardData = self.tTurnCardData
	-- 发送断线重连回复
    _player:send("pdk.GAME_GameSceneAck", data)
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
        player_mgr:broadcast("pdk.GAME_PlayerLeaveAck", {nSeat = nSeat})

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
    -- 不在游戏状态
    if self.nGameState == define.game_play then
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
    player_mgr:broadcast("pdk.GAME_ReadyAck", {nSeat = nSeat, bReady = msg.bReady})

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
    local nOutCardSeat = _player:getSeat()
    -- 不是当前玩家操作
    if nOutCardSeat ~= self.nCurrentSeat then
        return
    end

    -- 判断参数
    if msg.nCardData == nil or type(msg.nCardData) ~= "table" then
        return
    end

    utils.print(msg.nCardData)
    local tOutCardData = msg.nCardData
    local nOutCardCount = #tOutCardData

    -- 操作玩家牌
    if nOutCardCount > #self.tCardData[nOutCardSeat] then
        return
    end

    -- 首局必出当庄牌
    local first_out = room.get("first_out")
    if first_out == 1 and self.nPlayerCount == 3 and self.nGameCount == 1 then
        if #self.tTurnCardData == 0 and #self.tCardData[nOutCardSeat] == define.card_count then
            local bFind = false
            -- 判断出的牌是否含有黑桃3
            for _, nValue in pairs(tOutCardData) do
                if nValue == self.nBankCard then
                    bFind = true
                    break
                end
            end
            if not bFind then
                _player:send("pdk.GAME_PromptAck", {szPrompt = "首局庄家必须出带黑桃3!"})
                return
            end
        end
    end

    local nNextSeat = self:getNextSeat(self.nCurrentSeat)
    -- 下手玩家只剩1张
    if nOutCardCount == 1 and #self.tCardData[nNextSeat] == 1 then
		local tSearchCardResult = {}
		logic.searchOutCard(self.tCardData[nOutCardSeat], tOutCardData, tSearchCardResult)
		-- 有大牌，必须大
		if tSearchCardResult.nSearchCount > 0 then
            _player:send("pdk.GAME_PromptAck", {szPrompt = "下家报单,需从最大出起!"})
			return
		end
	end

    -- 排序
    logic.sortCard(tOutCardData)
    -- 取得牌型
    local nCardType = logic.getCardType(tOutCardData)
    if nCardType == logic.CT_ERROR then
	    -- 是否错误牌型
	    local bError = true
        while bError do
            -- 分析扑克
		    local tAnalyseResult = {}
		    logic.analysebCardData(tOutCardData, tAnalyseResult)
		    -- 不是连牌
		    if tAnalyseResult.tBlockCount[3] == nil or tAnalyseResult.tBlockCount[3] <= 1 then
			    break
		    end

            -- 变量定义
		    local nCardData = tAnalyseResult.tCardData[3][1]
		    local nFirstLogicValue = logic.getCardLogicValue(nCardData)
		    local nLianPaiCount = 0
            local nLianPaiMaxCount = 0
		    -- 连牌判断
		    for i=1, tAnalyseResult.tBlockCount[3] do
			    local nCardData1 = tAnalyseResult.tCardData[3][i * 3]
			    if (nFirstLogicValue ~= (logic.getCardLogicValue(nCardData1) + nLianPaiCount)) then

                    if nLianPaiCount > nLianPaiMaxCount then
                        nLianPaiMaxCount = nLianPaiCount
                    end

                    local nCardData2 = tAnalyseResult.tCardData[3][i * 3]
                    nFirstLogicValue = logic.getCardLogicValue(nCardData2)
                    nLianPaiCount = 1
			    else
                    nLianPaiCount = nLianPaiCount + 1

                    -- 错误过虑
		            if nFirstLogicValue >= 15 then
                        if nLianPaiCount > nLianPaiMaxCount then
                            nLianPaiMaxCount = nLianPaiCount
                        end
                        local nCardData2 = tAnalyseResult.tCardData[3][i * 3]
                        nFirstLogicValue = logic.getCardLogicValue(nCardData2)
                        nLianPaiCount = 1
                    end
			    end
		    end
            if nLianPaiCount > nLianPaiMaxCount then
                nLianPaiMaxCount = nLianPaiCount
            end
		    if nLianPaiMaxCount == 0 then
			    break
		    end

		    -- 出的牌比连牌都少
		    if nOutCardCount <= nLianPaiMaxCount * 3 then
			    break
		    end

		    -- 比如555，666 带1,2,3张都可以出
		    if nOutCardCount - nLianPaiMaxCount * 3 > nLianPaiMaxCount * 2 then
			    break
		    end

		    -- 设置未错误类型
		    bError = false
        end

        -- 错误牌型
        if bError then
            _player:send("pdk.GAME_PromptAck", {szPrompt = "错误牌型!"})
            return
        end
    end

    -- 第一手牌
	if #self.tTurnCardData == 0 then
		-- 第一个人出牌时，必须手牌只剩这几张，才能出此类型的
		if nCardType == logic.CT_ERROR or nCardType == logic.CT_THREE or nCardType == logic.CT_THREE_TAKE_ONE then
			-- 出的牌不等于手牌数量
			if #self.tCardData[nOutCardSeat] ~= nOutCardCount then
                _player:send("pdk.GAME_PromptAck", {szPrompt = "手上只剩这几张牌时才能这样出!"})
				return
			end
		end
	elseif logic.compareCard(self.tTurnCardData, tOutCardData) == false then
        _player:send("pdk.GAME_PromptAck", {szPrompt = "必须大过上家牌才可出!"})
		return
	end

    -- 检测删除扑克
	if not logic.checkRemoveCard(self.tCardData[nOutCardSeat], tOutCardData) then
		return
    end
    -- 移除扑克
    logic.removeCard(self.tCardData[nOutCardSeat], tOutCardData)

	-- 出牌记录
    self.tTurnCardData = tOutCardData
    self.tLastCardData = tOutCardData

    utils.print(tOutCardData)

	-- 是炸弹
	if nCardType == logic.CT_BOMB_CARD then
		self.nBombSeat = nOutCardSeat
    end

    -- 切换用户
	self.nTurnSeat = nOutCardSeat
    local nCardCount = #self.tCardData[nOutCardSeat]
	if nCardCount ~= 0 then
		self.nCurrentSeat = self:getNextSeat(self.nCurrentSeat)
	else
		self.nCurrentSeat = define.invalid_seat
    end

    -- 广播所有人
    local data = {
        nOutCardSeat = nOutCardSeat,
        nCurrentSeat = self.nCurrentSeat,
        nCardData = tOutCardData,
        bLeftOne = (nCardCount == 1),
    }
    player_mgr:broadcast("pdk.GAME_OutCardAck", data)
    table.insert(self.record.game.data, {time = os.time(), name = "pdk.GAME_OutCardAck", msg = data})

	-- 结束判断
	if self.nCurrentSeat == define.invalid_seat then
		-- 有炸弹
		if self.nBombSeat <= define.player_count then
			self.tBombCount[self.nBombSeat] = self.tBombCount[self.nBombSeat] + 1
        end

		self:gameEnd(nOutCardSeat, define.end_normal)
	end
end

-- 过牌请求
function M:GAME_PassCardReq(userid, _)
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
    local nOutCardSeat = _player:getSeat()
    -- 不是当前玩家操作
    if nOutCardSeat ~= self.nCurrentSeat then
        return
    end

	-- 最大出牌玩家,不允许pass
	if #self.tTurnCardData == 0 then
		return
    end

	-- 打得起必须压牌
    local press_card = room.get("press_card")
	if press_card == 1 then
		local tSearchCardResult = {}
		logic.searchOutCard(self.tCardData[nOutCardSeat], self.tTurnCardData, tSearchCardResult)
		-- 有大牌，必须大
		if tSearchCardResult.nSearchCount > 0 then
            _player:send("pdk.GAME_PromptAck", {szPrompt = "管得起,必须管!"})
			return
		end
	end

    utils.print(self.tCardData[nOutCardSeat])

	local nNextSeat = self:getNextSeat(self.nCurrentSeat)
	-- 当前玩家是最大牌玩家，新一轮
	if nNextSeat == self.nTurnSeat then
		-- 有炸弹
		if self.nBombSeat ~= define.invalid_seat then
			self.tBombCount[self.nBombSeat] = self.tBombCount[self.nBombSeat] + 1
		end

		self.tTurnCardData = {}
		self.nBombSeat = define.invalid_seat
	end

    -- 设置操作玩家
    self.nCurrentSeat = nNextSeat
    -- 是否新一轮
    local bNewTurn = #self.tTurnCardData == 0

    -- 广播所有人
    local data = {
        bNewTurn = bNewTurn,
        nPassSeat = nOutCardSeat,
        nCurrentSeat = self.nCurrentSeat
    }
    player_mgr:broadcast("pdk.GAME_PassCardAck", data)
    table.insert(self.record.game.data, {time = os.time(), name = "pdk.GAME_PassCardAck", msg = data})
end

-- 游戏开始
function M:gameBegin()
    if self.nGameState == define.game_play then
        return
    end

    self.bBegin = true
    -- 开始时间,创建房间50分钟，然后游戏才开始，
    -- 不然10分钟，游戏被解散，这里要重置下时间
    self.nCheckStartTime = os.time()

    -- 增加游戏局数
    self.nGameCount = self.nGameCount + 1
    -- 设置游戏状态
    self.nGameState = define.game_play
    -- 开始时间
    self.start_time = os.time()

    -- 洗牌
    local tAllCard = {
        0x01,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,
        0x11,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,
        0x21,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,
        0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D
    }
    -- 打乱
    logic.shuffle(tAllCard)

    self.tCardData = {}
    for nIndex, nValue in ipairs(tAllCard) do
        local nPlayerIndex = math.modf((nIndex - 1) / define.card_count) + 1
        if self.tCardData[nPlayerIndex] == nil then
            self.tCardData[nPlayerIndex] = {}
        end
        table.insert(self.tCardData[nPlayerIndex], nValue)
    end
    utils.print(self.tCardData)

    -- 2人第一局,随机庄家
    if self.nPlayerCount == 2 then
        if self.nGameCount == 1 then
            self.nBankerSeat = math.random(1, self.nPlayerCount)
        end
    else
        if self.nGameCount == 1 then
            -- 3人第一局,黑桃3当庄
            local nBanker = 0
            for nIndex, tCard in pairs(self.tCardData) do
                -- 已找到
                if nBanker ~= 0 then
                    break
                end
                for _, nCardValue in pairs(tCard) do
                    if nCardValue == self.nBankCard then
                        nBanker = nIndex
                    end
                end
            end
            if nBanker > 0 then
                self.nBankerSeat = nBanker
            else
                self.nBankerSeat = math.random(1, self.nPlayerCount)
            end
        end
    end

    local code_card = room.get("code_card")
    if code_card == 1 then
        -- 找到红桃10玩家
        local nHongTenSeat = define.invalid_seat
        for nIndex, tCard in pairs(self.tCardData) do
            -- 已找到
            if nHongTenSeat ~= define.invalid_seat then
                break
            end
            for _, nCardValue in pairs(tCard) do
                if nCardValue == self.nCodeCard then
                    nHongTenSeat = nIndex
                end
            end
        end
        if nHongTenSeat ~= define.invalid_seat then
            self.nHongTenSeat = nHongTenSeat
        end
    end

    self.nCurrentSeat = self.nBankerSeat
    self.nTurnSeat = self.nBankerSeat

    -- 给所有人发送游戏开始
    for i = 1, self.nPlayerCount do
        local _player = player_mgr:getInSeat(i)
        if _player then
            -- 设置玩家分数
            _player:setScore(self.tTotalGameScore[i])
            _player:send("pdk.GAME_GameStartAck", {nCurrentSeat = self.nCurrentSeat, nCardData = self.tCardData[i]})
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

        -- 设置庄家
		self.nBankerSeat = nSeat

		local tGameEnd =
        {
            nGameScore = {},
            nTotalScore = {},
            nBombCount = {},
            card = {},
        }

        for i = 1, self.nPlayerCount do
            tGameEnd.nGameScore[i] = 0
            tGameEnd.nTotalScore[i] = 0
            tGameEnd.nBombCount[i] = 0
        end

		-- 计算炸弹分
		local tBombScore = {}
		for i = 1, self.nPlayerCount do
			-- 记录玩家总炸弹数
			self.tAllBombCount[i] = self.tAllBombCount[i] + self.tBombCount[i]

			tBombScore[i] = self.tBombCount[i] * (self.nPlayerCount - 1) * define.bomb_score

			for j = 1, self.nPlayerCount do
				if i ~= j then
					tBombScore[i] = tBombScore[i] - self.tBombCount[j] * define.bomb_score
				end
			end
		end

		-- 计算手上牌分
		for i = 1, self.nPlayerCount do
			-- 赢家不处理
			if i ~= nSeat then
			    -- 只剩一张牌，保本
                local nCardCount = #self.tCardData[i]
			    if nCardCount == 1 then
				    tGameEnd.nGameScore[i] = 0
                -- 全关双倍
			    elseif nCardCount == define.card_count then
					tGameEnd.nGameScore[i] = -nCardCount * self.nCellScore * 2
				else
					tGameEnd.nGameScore[i] = -nCardCount * self.nCellScore
				end
            end
		end

		-- 红桃10扎鸟
        local code_card = room.get("code_card")
        if code_card == 1 then
			if self.nHongTenSeat ~= define.invalid_seat and self.nHongTenSeat <= self.nPlayerCount then
				-- 是赢家
				if nSeat == self.nHongTenSeat then
					for i = 1, self.nPlayerCount do
						if i ~= nSeat then
							-- 输家翻倍
						    tGameEnd.nGameScore[i] = tGameEnd.nGameScore[i] * 2
                        end
                    end
				else
					-- 输家翻倍
					tGameEnd.nGameScore[self.nHongTenSeat] = tGameEnd.nGameScore[self.nHongTenSeat] * 2
				end
			end
		end

        -- 加上炸弹分
        for i = 1, self.nPlayerCount do
            -- 赢家不处理
			if i ~= nSeat then
                tGameEnd.nGameScore[i] = tGameEnd.nGameScore[i] + tBombScore[i]
            end
        end

		-- 计算赢家分数
		for i = 1, self.nPlayerCount do
			-- 赢家不处理
			if i ~= nSeat then
				tGameEnd.nGameScore[nSeat] = tGameEnd.nGameScore[nSeat] - tGameEnd.nGameScore[i]
			end
		end

		-- 计算总分数
		for i = 1, self.nPlayerCount do
			self.tTotalGameScore[i] = self.tTotalGameScore[i] + tGameEnd.nGameScore[i]
		end
        tGameEnd.nTotalScore = self.tTotalGameScore
        tGameEnd.nBombCount = self.tBombCount

        for _, tCard in ipairs(self.tCardData) do
            table.insert(tGameEnd.card, {nCardData = tCard})
        end

		-- 计算最大分数
		for i = 1, self.nPlayerCount do
			if tGameEnd.nGameScore[i] >= self.tMaxScore[i] then
			    self.tMaxScore[i] = tGameEnd.nGameScore[i]
            end
		end
		-- 设置赢的局数
		self.tWinCount[nSeat] = self.tWinCount[nSeat] + 1

        -- 游戏结束消息广播
        player_mgr:broadcast("pdk.GAME_GameEndAck", tGameEnd)

        -- 回放
        table.insert(self.record.game.data, {time = os.time(), name = "pdk.GAME_GameEndAck", msg = tGameEnd})
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

		-- 输出总分数
		for i = 1, self.nPlayerCount do
			print("i, nGameScore, nBombCount, nCardCount",
            i, tGameEnd.nGameScore[i], tGameEnd.nBombCount[i], #tGameEnd.card[i].nCardData)
		end

        if self.nGameCount >= self.nTotalGameCount then
            -- 游戏总结算消息广播
            player_mgr:broadcast("pdk.GAME_GameTotalEndAck", {
                nTotalScore = self.tTotalGameScore,
                nMaxScore = self.tMaxScore,
                nAllBombCount = self.tAllBombCount,
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
            nBombCount = {},
            card = {},
        }

		for i = 1, self.nPlayerCount do
            tGameEnd.nGameScore[i] = 0
            tGameEnd.nTotalScore[i] = 0
            tGameEnd.nBombCount[i] = 0
        end

        for _, tCard in ipairs(self.tCardData) do
            table.insert(tGameEnd.card, {nCardData = tCard})
        end

        -- 游戏结束消息广播
        player_mgr:broadcast("pdk.GAME_GameEndAck", tGameEnd)

        -- 游戏总结算消息广播
        player_mgr:broadcast("pdk.GAME_GameTotalEndAck", {
            nTotalScore = self.tTotalGameScore,
            nMaxScore = self.tMaxScore,
            nAllBombCount = self.tAllBombCount,
            nWinCount = self.tWinCount
        })

        -- 解散服务
        self:big_result()
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
    -- 红十玩家
    self.nHongTenSeat = define.invalid_seat
    -- 准备状态
    self.tReady = {}
    -- 玩家牌
    self.tCardData = {}
    -- 出牌玩家
    self.nTurnSeat = define.invalid_seat
    -- 最大出牌
    self.tTurnCardData = {}
    -- 最后出牌
    self.tLastCardData = {}
    -- 炸弹位置
    self.nBombSeat = define.invalid_seat
    -- 炸弹信息
    self.tBombCount = {}
    for i = 1, self.nPlayerCount do
        self.tReady[i] = false
        self.tBombCount[i] = 0
    end
end

-- 获取下个位置
function M:getNextSeat(nSeat)
    local nIndex = (nSeat + (self.nPlayerCount - 1)) % self.nPlayerCount
    return nIndex ~= 0 and nIndex or self.nPlayerCount
end

return M
