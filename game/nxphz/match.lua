local player_mgr = require "player_mgr"
local utils = require "utils"
local room = require "room"
local define = require "define"
local skynet = require "skynet"
local timer_mgr = require "timer_mgr"

local M = {}

-- 初始化
function M:init()
    -- 设置随机种子
    math.randomseed(os.time())

    -- 房间相关
    -- 游戏当前局数
    self.nGameCount = 0
    -- 游戏总局数
    self.nTotalGameCount = room.get("game_count")
    -- 玩家人数
    self.nPlayerCount = room.get("player_count")
    -- 房间ID
    self.nRoomID = room.get("room_id")
    -- 游戏状态
    self.nGameState = define.GAME_FREE
    -- 庄家
    self.nBankerSeat = 1

    -- 配置相关
    -- 底分
    self.nCellScore = 1

    -- 解散位置
    self.nDissoveSeat = 0
    -- 解散开始时间
    self.nDissoveStartTime = 0
    -- 检测时间
    self.nDissoveTime = 300
    -- 投票状态
    self.tVoteState = {}
    for i = 1, self.nPlayerCount do
        -- 投票状态
        self.tVoteState[i] = 0
    end

    -- 总结算相关
    -- 总共游戏分数
    self.tTotalGameScore = {}
    for i = 1, self.nPlayerCount do
        -- 总共游戏分数
        self.tTotalGameScore[i] = 0
    end

    self.bBegin = false
    -- 检测开始时间
    self.nCheckStartTime = os.time()
    -- 检测时间
    self.nCheckTime = 3600
    -- 检测房间
    skynet.timeout(5*100, function() self:check_room() end)

    -- 定时器管理
    self.timer_mgr = timer_mgr.new()
    -- 发牌时间
    self.nDispatchCardTime = 1000

	self.logic = (require "logic").new()

    -- 还原数据
    self:restore()
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
    --local nSeat = _player:getSeat()

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
    data.tGameScore = self.tTotalGameScore
    data.nGameCount = self.nGameCount
    data.nTotalGameCount = self.nTotalGameCount
    data.bReady = self.tReady
    data.nBankerSeat = self.nBankerSeat
	-- 发送断线重连回复
    _player:send("nxphz.GAME_GameSceneAck", data)
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
        player_mgr:broadcast("nxphz.GAME_PlayerLeaveAck", {nSeat = nSeat})

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
            self:gameEnd(define.INVALID_SEAT, define.END_DISSOLVE)
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
    player_mgr:broadcast("nxphz.GAME_ReadyAck", {nSeat = nSeat, bReady = msg.bReady})

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
    if self.nGameState ~= define.GAME_PLAY then
        return
    end

    -- 判断参数
    local nCardData = msg.nCardData
    if nCardData == nil then
        return
    end

    -- 无效牌
    if not self.logic:isValidCard(nCardData) then
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

    -- 没牌和3张以上不允许出牌
    if self.tCardData[nOutCardSeat][nCardData] <= 0 or self.tCardData[nOutCardSeat][nCardData] >= 3 then
        return
    end

    -- 检测是否有牌
    local tCardData = {nCardData}
    if not self.logic:checkRemoveCard(self.tCardData[nOutCardSeat], tCardData) then
        return
    end

    -- 移除牌
    self.logic:removeCard(self.tCardData[nOutCardSeat], tCardData)

    -- 广播所有人
    local data = {
        nCurrentSeat = nOutCardSeat,
        nCardData = msg.nCardData,
    }
    player_mgr:broadcast("nxphz.GAME_OutCardAck", data)
    table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_OutCardAck", msg = data})

    -- 臭牌记录
    self.tAbandonCard[nOutCardSeat][nCardData] = true
    self.nOutCardCount = self.nOutCardCount + 1

    -- 响应标志
    self.tResponse = {}
    -- 用户动作
    self.tUserAction = {}
    -- 吃牌类型
    self.tChiCardKind = {}
    -- 执行动作
    self.tPerformAction = {}
    for i = 1, self.nPlayerCount do
        -- 响应标志
        self.tResponse[i] = false
        -- 用户动作
        self.tUserAction[i] = define.ACK_NULL
        -- 吃牌类型
        self.tChiCardKind[i] = define.ACK_NULL
        -- 执行动作
        self.tPerformAction[i] = define.ACK_NULL
    end

    -- 设置变量
	self.bOutCard = false
	self.bDispatch = false
	self.bEstimate = false
	self.nOutCardSeat = nOutCardSeat
	self.nOutCardData = nCardData
	self.nCurrentSeat = define.INVALID_SEAT
	self.nResumeSeat = self:getNextSeat(nOutCardSeat)
	self.tPaoPai = {}
    for i = 1, self.nPlayerCount do
        self.tPaoPai[i] = false
    end

    -- 动作判断
	local nCurrentCard = (nOutCardSeat ~= define.INVALID_SEAT) and self.nOutCardData or 0
	-- 派发扑克
	if not self:estimateUserRespond(nOutCardSeat, nCurrentCard, self.bDispatch) then
		-- 杀掉发牌定时器
		if self.nDispatchCardTimerID then
            self.timer_mgr:remove(self.nDispatchCardTimerID)
            self.nDispatchCardTimerID = nil
        end
		-- 启动发牌定时器
        self.nDispatchCardTimerID = self.timer_mgr:add(self.nDispatchCardTime, 1, function() self:dispatchCard() end)
	end
end

-- 用户操作
function M:GAME_OperateCardReq(userid, msg)
    -- 不在游戏状态
    if self.nGameState ~= define.GAME_PLAY then
        return
    end

    -- 取得玩家
    local _player = player_mgr:get(userid)
    if _player == nil then
        return
    end

    -- 取得玩家位置
    local nOperateCardSeat = _player:getSeat()
	-- 效验用户
	if self.nCurrentSeat ~= define.INVALID_SEAT then
        skynet.call("xlog", "lua", "log", "nRoomID="..self.nRoomID..",nCurrentSeat="..self.nCurrentSeat)
		return
    end

    local nOperate = msg.nOperate
    local nChiKind = msg.nChiKind
	-- 效验状态
	if self.tResponse[nOperateCardSeat] or
        (nOperate ~= define.ACK_NULL and (self.tUserAction[nOperateCardSeat] & nOperate) == 0) then
        skynet.call("xlog", "lua", "log", string.format(
            "nRoomID=%d,tResponse[%d]=%s",
            self.nRoomID,
            nOperateCardSeat,
            utils.table_2_str(self.tResponse[nOperateCardSeat])))
		return
	end

    local nCardData = self.nOutCardData

	-- 验证吃
    local bCheck = true
	while bCheck do
		-- 不是吃
		if (nOperate & define.ACK_CHI) == 0 then
			break
		end

		-- 是吃，但发错误吃操作码
		if nChiKind <= 0 then
            skynet.call("xlog", "lua", "log", "nRoomID="..self.nRoomID..",nChiKind <= 0")
			return
		end

		local nColor = 0xFF
		-- 吃类型
		local nTempChiKind = nChiKind
		-- 需要牌
		local tChiCardData = {}
		-- 最多吃3个，遍历int中3个字节可以了
		for i = 1, 3 do
			local nKin = nTempChiKind & nColor
			if nKin == 0 then
				-- 第一个吃数据居然无值,肯定错误了
				if i == 1 then
                    skynet.call("xlog", "lua", "log", "nKin == 0, i == 1 error nRoomID="..self.nRoomID)
					return
				end

				break
			end

			-- 加入吃牌数据
            local bChi, tCard = self:chiPaiMustCard(nKin, nCardData, i == 1)
			if not bChi then
                skynet.call("xlog", "lua", "log", string.format(
                    "ChiPaiMustCard error nRoomID=%d,nKin=%d,i=%d",
                    self.nRoomID,
                    nKin,
                    i))
				return
			end
            for _, v in ipairs(tCard) do
                tChiCardData[v] = (tChiCardData[v] or 0) + 1
            end

			-- 移位字节数
			nTempChiKind = nTempChiKind >> 8
		end

		-- 玩家可吃手上牌数
		local nTotalCardCount = 0
		for i = 1, define.MAX_CARD do
			if self.tCardData[nOperateCardSeat][i] < 3 then
				nTotalCardCount = nTotalCardCount + self.tCardData[nOperateCardSeat][i]
			end
		end
        -- 吃牌需要数量
		local nMustCardCount = 0
        for _, nCardCount in pairs(tChiCardData) do
            nMustCardCount = nMustCardCount + nCardCount
        end

		-- 要把手牌吃完，不能让他吃
		if nMustCardCount >= nTotalCardCount then
            skynet.call("xlog", "lua", "log", string.format(
                "ChiPaiMustCard error nRoomID=%d,nTotalCardCount=%d,nMustCardCount=%d",
                self.nRoomID,
                nTotalCardCount,
                nMustCardCount))
			return
		end

        -- 吃了还有剩余
        if tChiCardData[nCardData] and self.tCardData[nOperateCardSeat][nCardData] > tChiCardData[nCardData] then
            skynet.call("xlog", "lua", "log", string.format(
                "ChiPaiMustCard error nRoomID=%d,tCardData[%d][%d]=%d,tChiCardData[%d]=%d",
                self.nRoomID,
                nOperateCardSeat,
                nCardData,
                self.tCardData[nOperateCardSeat][nCardData],
                nCardData,
                tChiCardData[nCardData]))
            return
        end

        -- 还有多余张数
        if not tChiCardData[nCardData] and self.tCardData[nOperateCardSeat][nCardData] > 0 then
            skynet.call("xlog", "lua", "log", string.format(
                "ChiPaiMustCard error nRoomID=%d,tCardData[%d][%d]=%d",
                self.nRoomID,
                nOperateCardSeat,
                nCardData,
                self.tCardData[nOperateCardSeat][nCardData]))
            return
        end
        for nCard, nCount in pairs(tChiCardData) do
            if self.tCardData[nOperateCardSeat][nCard] >= 3 then
                skynet.call("xlog", "lua", "log", string.format(
                    "ChiPaiMustCard error nRoomID=%d,nChiKind=%d,nOperateCardSeat=%d,nCard=%d",
                    self.nRoomID,
                    nChiKind,
                    nOperateCardSeat,
                    nCard))
                return
            end

            if nCount > self.tCardData[nOperateCardSeat][nCard] then
                skynet.call("xlog", "lua", "log", string.format(
                    "ChiPaiMustCard error nRoomID=%d,nChiKind=%d,nOperateCardSeat=%d,nCard=%d,nCount=%d",
                    self.nRoomID,
                    nChiKind,
                    nOperateCardSeat,
                    nCard,
                    nCount))
                return
            end
        end

        bCheck = false
   end

	-- 执行判断
	local nTempCurrentSeat = (self.nOutCardSeat ~= define.INVALID_SEAT) and self.nOutCardSeat or self.nResumeSeat
	-- 不是当前操作玩家，且可以胡，强制胡
	if nOperateCardSeat ~= nTempCurrentSeat and (self.tUserAction[nOperateCardSeat] & define.ACK_CHIHU) ~= 0 then
		nOperate = define.ACK_CHIHU
	end

	-- 变量定义
	local nTargetSeat = (nOperate == define.ACK_NULL) and define.INVALID_SEAT or nOperateCardSeat

	-- 设置变量
	self.tResponse[nOperateCardSeat] = true
	self.tChiCardKind[nOperateCardSeat] = nChiKind
	self.tPerformAction[nOperateCardSeat] = nOperate

	-- 优先处理
	if nOperate ~= define.ACK_NULL and (self.tUserAction[nOperateCardSeat] & define.ACK_CHI_EX) ~= 0 then
		self.tPerformAction[nOperateCardSeat] = self.tPerformAction[nOperateCardSeat] | define.ACK_CHI_EX
    end

	-- 执行判断
	local nFirstCurrentSeat = (self.nOutCardSeat ~= define.INVALID_SEAT) and self.nOutCardSeat or self.nResumeSeat
    skynet.call("xlog", "lua", "log", string.format(
        "OnUserOperateCard nRoomID=%d,nOutCardSeat=%d,nResumeSeat=%d,nFirstCurrentSeat=%d",
        self.nRoomID,
        self.nOutCardSeat,
        self.nResumeSeat,
        nFirstCurrentSeat))

	-- 最大动作玩家
	local nMaxTargetSeat = nFirstCurrentSeat
	-- 最大动作
	local nMaxTargetAction = define.ACK_NULL
	-- 找出最大动作玩家
    for i = nFirstCurrentSeat, nFirstCurrentSeat + (self.nPlayerCount - 1) do
        local nSeat = self:getNextSeat(i)

		-- 玩家未操作
		if not self.tResponse[nSeat] then
			if self.tUserAction[nSeat] >= nMaxTargetAction then
				-- 有胡，设置成胡
				if (self.tUserAction[nSeat] & define.ACK_CHIHU) ~= 0 then
					nMaxTargetSeat = nSeat
					nMaxTargetAction = define.ACK_CHIHU
					break
				else
					nMaxTargetSeat = nSeat
					nMaxTargetAction = self.tUserAction[nSeat]
				end
			end
		else
			if self.tPerformAction[nSeat] >= nMaxTargetAction then
				nMaxTargetSeat = nSeat
				nMaxTargetAction = self.tPerformAction[nSeat]

				-- 胡牌最大，找到直接跳出即可
				if (nMaxTargetAction & define.ACK_CHIHU) ~= 0 then
					break
				end
			end
		end
	end

	-- 最大玩家还没响应
	if nMaxTargetAction ~= define.ACK_NULL and
        nMaxTargetSeat ~= nTargetSeat and
        not self.tResponse[nMaxTargetSeat] then
        skynet.call("xlog", "lua", "log", string.format(
            "nRoomID=%d,nOperateCardSeat=%d,nTargetSeat=%d,nMaxTargetSeat=%d,nMaxTargetAction=%d,tResponse[%d]=%s",
            self.nRoomID,
            nOperateCardSeat,
            nTargetSeat,
            nMaxTargetSeat,
            nMaxTargetAction,
            nMaxTargetSeat,
            utils.table_2_str(self.tResponse[nMaxTargetSeat])))
		return
	end
	-- 设置最大动作玩家
	local nTargetAction = self.tPerformAction[nMaxTargetSeat]
	nTargetSeat = nMaxTargetSeat
    skynet.call("xlog", "lua", "log", string.format(
        "OnUserOperateCard nRoomID=%d,nMaxTargetSeat=%d,nTargetAction=%d",
        self.nRoomID,
        nMaxTargetSeat,
        nTargetAction))

	-- 如果是过
	if nTargetAction == define.ACK_NULL then
		-- 等摸牌玩家胡状态
		if self.bWaitSendUserHu then
			-- 用户动作
			local tUserAction =
            {
                define.ACK_NULL,
                define.ACK_NULL,
                define.ACK_NULL,
            }
			local bFindHu = false
            for i = 1, self.nPlayerCount do
				-- 排除摸牌且摸牌玩家提和偎也不操作
				if not (i == self.nOutCardSeat or self.bSendNotify) then
                    -- 胡牌判断
                    local tHuCardInfo =
                    {
                        bSelf = false,
                        nInsertCard = self.nOutCardData,
                        nHuXi = self.tHuXi[i],
                        tCardData = self.tCardData[i],
                    }
                    if self.logic:getHuCardInfo(tHuCardInfo) then
                        -- 设置玩家可胡
                        tUserAction[i] = define.ACK_CHIHU
                        -- 发现胡
                        bFindHu = true
                    end
                end
			end

            local strMsg = ""
            for i = 1, self.nPlayerCount do
                strMsg = ",tUserAction["..i.."]="..tUserAction[i]
            end
            skynet.call("xlog", "lua", "log", string.format(
                "nRoomID=%d,bWaitSendUserHu=%s,nOutCardSeat=%d,nOutCardData=%d,bFindHu=%s,%s",
                self.nRoomID,
                utils.table_2_str(self.bWaitSendUserHu),
                self.nOutCardSeat,
                self.nOutCardData,
                utils.table_2_str(bFindHu),
                strMsg))
			-- 发现胡
			if bFindHu then
                -- 动作变量
                -- 响应标志
                self.tResponse = {}
                -- 用户动作
                self.tUserAction = {}
                -- 吃牌类型
                self.tChiCardKind = {}
                -- 执行动作
                self.tPerformAction = {}
                for i = 1, self.nPlayerCount do
                    -- 响应标志
                    self.tResponse[i] = false
                    -- 用户动作
                    self.tUserAction[i] = define.ACK_NULL
                    -- 吃牌类型
                    self.tChiCardKind[i] = define.ACK_NULL
                    -- 执行动作
                    self.tPerformAction[i] = define.ACK_NULL
                end
                -- 设置等待发牌玩家胡牌
                self.bWaitSendUserHu = false

				-- 复制玩家动作
                for k, v in ipairs(tUserAction) do
                    self.tUserAction[k] = v
                end

				-- 设置用户
				self.bEstimate = true
				-- 当前操作玩家
				self.nCurrentSeat = define.INVALID_SEAT

                for i = 1, self.nPlayerCount do
                    -- 发送数据
                    local tData =
                    {
                        nCurrentSeat = self.nOutCardSeat,
                        nCardData = self.nOutCardData,
                        nOperate = self.tUserAction[i],
                    }
                    -- 回放数据
                    table.insert(self.record.game.data, {
                        time = os.time(),
                        name = "nxphz.GAME_OperateCardAck",
                        msg = tData})
                    local p = player_mgr:getInSeat(i)
                    if p then
                        p:send("nxphz.GAME_OperateCardAck", tData)
                    end
                end

				return
			end

			-- 动作判断
			local bUserAction = self:estimateUserRespond(self.nOutCardSeat, self.nOutCardData, self.bDispatch)
			-- 出牌提示
			if not bUserAction then
				-- 发送出牌提示
				self:sendOutCardNotify(self.nOutCardSeat, false)
			end
			-- 设置非等摸牌玩家胡状态
			self.bWaitSendUserHu = false

			return
		else
			local bFindHu = false
			for i = 1, self.nPlayerCount do
				if (self.tUserAction[i] & define.ACK_CHIHU) ~= 0 then
					bFindHu = true
					break
				end
			end

            skynet.call("xlog", "lua", "log", string.format(
                "NULL nRoomID=%d,bWaitSendUserHu=%s,nOutCardSeat=%d,nOutCardData=%d,bFindHu=%s",
                self.nRoomID,
                utils.table_2_str(self.bWaitSendUserHu),
                self.nOutCardSeat,
                self.nOutCardData,
                utils.table_2_str(bFindHu)))
			-- 玩家是吃胡放弃的
			if bFindHu then
				local nCurrentHuSeat = self.nOutCardSeat
                if self.nOutCardSeat == define.INVALID_SEAT then
                    nCurrentHuSeat = self.nResumeSeat
                end
                skynet.call("xlog", "lua", "log", string.format(
                    "NULL nRoomID=%d,nOutCardSeat=%d,nOutCardData=%d,nResumeSeat=%d,tPaoPai[%d]=%s,bTiCard=%s",
                    self.nRoomID,
                    self.nOutCardSeat,
                    self.nOutCardData,
                    self.nResumeSeat,
                    nCurrentHuSeat,
                    utils.table_2_str(self.tPaoPai[nCurrentHuSeat]),
                    utils.table_2_str(self.bTiCard)))
				-- 是跑牌或者提牌
				if self.tPaoPai[nCurrentHuSeat] or self.bTiCard then
					-- 发送出牌提示
					self:sendOutCardNotify(nCurrentHuSeat, self:isAllowOutCard(nCurrentHuSeat))
				else
					-- 庄家还未操作牌,点放弃了胡,让庄家出牌
					if not self.bBankOperateCard then
						-- 发送庄家出牌提示
						self:sendOutCardNotify(self.nBankerSeat, true)
					else
                        skynet.call("xlog", "lua", "log", string.format(
                            "nOperate == NULL DiHu nRoomID=%d,nOutCardSeat=%d,nOutCardData=%d,nCurrentHuSeat=%d,"..
                            "nSendCardCount=%d,nOutCardCount=%d",
                            self.nRoomID,
                            self.nOutCardSeat,
                            self.nOutCardData,
                            nCurrentHuSeat,
                            self.nSendCardCount,
                            self.nOutCardCount))
						-- 玩家地胡放弃
						if self.nSendCardCount == 1 and self.nOutCardCount == 1 then
							-- 动作判断
							local nCurrentCard = (self.nOutCardSeat ~= define.INVALID_SEAT) and self.nOutCardData or 0
							local bUserAction = self:estimateUserRespond(nCurrentHuSeat, nCurrentCard, self.bDispatch)
                            skynet.call("xlog", "lua", "log", string.format(
                                "NULL DiHu nRoomID=%d,nOutCardSeat=%d,nOutCardData=%d,nCurrentHuSeat=%d,"..
                                "bDispatch=%s,bUserAction=%s",
                                self.nRoomID,
                                self.nOutCardSeat,
                                self.nOutCardData,
                                nCurrentHuSeat,
                                utils.table_2_str(self.bDispatch),
                                utils.table_2_str(bUserAction)))
							-- 派发扑克
							if not bUserAction then
                                -- 杀掉发牌定时器
                                if self.nDispatchCardTimerID then
                                    self.timer_mgr:remove(self.nDispatchCardTimerID)
                                    self.nDispatchCardTimerID = nil
                                end
                                -- 启动发牌定时器
                                self.nDispatchCardTimerID = self.timer_mgr:add(self.nDispatchCardTime, 1, function()
                                    self:dispatchCard()
                                    end)
							end
						else
							-- 动作判断
							local bUserAction = self:estimateUserRespond(nCurrentHuSeat,
                                self.nOutCardData, self.bDispatch)
                            skynet.call("xlog", "lua", "log", string.format(
                                "nOperate == NULL nRoomID=%d,nOutCardSeat=%d,nOutCardData=%d,nCurrentHuSeat=%d,"..
                                "bDispatch=%s,bUserAction=%s",
                                self.nRoomID,
                                self.nOutCardSeat,
                                self.nOutCardData,
                                nCurrentHuSeat,
                                utils.table_2_str(self.bDispatch),
                                utils.table_2_str(bUserAction)))
							-- 出牌提示
							if not bUserAction then
								-- 发送出牌提示
								self:sendOutCardNotify(nCurrentHuSeat, false)
							end
						end
					end
				end

				return
			end
		end
	end

	-- 臭牌记录
    for i = 1, self.nPlayerCount do
        if self.tUserAction[i] > nTargetAction and nTargetAction ~= define.ACK_NULL and i ~= nTargetSeat then
            self.tAbandonCard[i][self.nOutCardData] = true
        end
    end

    -- 设置状态
    -- 响应标志
    self.tResponse = {}
    -- 用户动作
    self.tUserAction = {}
    -- 执行动作
    self.tPerformAction = {}
    for i = 1, self.nPlayerCount do
        -- 响应标志
        self.tResponse[i] = false
        -- 用户动作
        self.tUserAction[i] = define.ACK_NULL
        -- 执行动作
        self.tPerformAction[i] = define.ACK_NULL
    end
    -- 设置等待发牌玩家胡牌
    self.bWaitSendUserHu = false

	-- 吃牌操作
	if (nTargetAction & define.ACK_CHI) ~= 0 then
        skynet.call("xlog", "lua", "log", "ACK_CHI nRoomID="..self.nRoomID..",nTargetAction="..nTargetAction)
        local nColor = 0xFF
		-- 吃类型
		local nTempChiKind = self.tChiCardKind[nTargetSeat]
		-- 需要牌
		local tChiCardData = {}
		-- 最多吃3个，遍历int中3个字节可以了
		for _ = 1, 3 do
			local nKin = nTempChiKind & nColor
			if nKin == 0 then
				break
			end

			-- 加入吃牌数据提取
			self:chiPaiMustCardTiQu(nKin, self.nOutCardData, tChiCardData)

			-- 移位1字节
			nTempChiKind = nTempChiKind >> 8
		end
        local nChiCardCount = #tChiCardData
		if nChiCardCount == 0 or (nChiCardCount%3) ~= 0 then
            skynet.call("xlog", "lua", "log", "nRoomID="..self.nRoomID..",nChiCardCount="..nChiCardCount)
			return
		end

		-- 结果牌数量
		local nResultCount = nChiCardCount / 3
		for i = 1, nResultCount do
            local nCardData1 = tChiCardData[(i-1)*3 + 1]
            local nCardData2 = tChiCardData[(i-1)*3 + 2]
            local nCardData3 = tChiCardData[(i-1)*3 + 3]
            -- 设置组合
            local tWeave =
            {
                nWeaveKind = define.ACK_CHI,
                nCenterCard = self.nOutCardData,
                tCardData = {nCardData1, nCardData2, nCardData3},
            }
            table.insert(self.tWeaveItemArray[nTargetSeat], tWeave)

			-- 删除扑克
			if i ~= 1 then		-- 第一个打的牌不处理
				self.tCardData[nTargetSeat][nCardData1] = self.tCardData[nTargetSeat][nCardData1] - 1
			end
            self.tCardData[nTargetSeat][nCardData2] = self.tCardData[nTargetSeat][nCardData2] - 1
            self.tCardData[nTargetSeat][nCardData3] = self.tCardData[nTargetSeat][nCardData3] - 1
		end

		-- 更新胡息
		self:updateHuXi(nTargetSeat)

        -- 发送数据
        local tData =
        {
            nCurrentSeat = nTargetSeat,
            tCardData = tChiCardData,
        }
        -- 回放数据
        table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_ChiCardAck", msg = tData})
        player_mgr:broadcast("nxphz.GAME_ChiCardAck", tData)

		-- 设置变量
		self.nOutCardSeat = define.INVALID_SEAT
        -- 设置出牌值
        self.nOutCardData = 0
		-- 出牌提示
		self:sendOutCardNotify(nTargetSeat, true)

		return
	end

	-- 碰牌操作
    if (nTargetAction & define.ACK_PENG) ~= 0 then
		skynet.call("xlog", "lua", "log", "ACK_PENG nRoomID="..self.nRoomID..",nTargetAction="..nTargetAction)
		-- 设置扑克
		self.tCardData[nTargetSeat][self.nOutCardData] = 0

        -- 设置组合
        local tWeave =
        {
            nWeaveKind = define.ACK_PENG,
            nCenterCard = self.nOutCardData,
            tCardData = {self.nOutCardData, self.nOutCardData, self.nOutCardData},
        }
        table.insert(self.tWeaveItemArray[nTargetSeat], tWeave)

        -- 更新胡息
		self:updateHuXi(nTargetSeat)

        -- 发送数据
        local tData =
        {
            nCurrentSeat = nTargetSeat,
            nCardData = self.nOutCardData,
        }
        -- 回放数据
        table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_PengCardAck", msg = tData})
        player_mgr:broadcast("nxphz.GAME_PengCardAck", tData)

		-- 设置变量
		self.nOutCardSeat = define.INVALID_SEAT
        -- 设置出牌值
        self.nOutCardData = 0
		-- 出牌提示
		self:sendOutCardNotify(nTargetSeat, true)

		return
	end

	-- 吃胡操作
    if (nTargetAction & define.ACK_CHIHU) ~= 0 then
        skynet.call("xlog", "lua", "log", "ACK_CHIHU nRoomID="..self.nRoomID..",nTargetAction="..nTargetAction)
		-- 结束游戏
        self:gameEnd(nTargetSeat, define.END_NORMAL)
		return
	end

	-- 动作判断
	local bUserAction = false
	if not self.bEstimate then
		local nCurrentCard = (self.nOutCardSeat ~= define.INVALID_SEAT) and self.nOutCardData or 0
		bUserAction = self:estimateUserRespond(self.nOutCardSeat, nCurrentCard, self.bDispatch)
	end

    skynet.call("xlog", "lua", "log", "ACK_CHIHU nRoomID="..self.nRoomID..
        ",bUserAction="..utils.table_2_str(bUserAction))
	-- 派发扑克
	if not bUserAction then
		-- 杀掉发牌定时器
        if self.nDispatchCardTimerID then
            self.timer_mgr:remove(self.nDispatchCardTimerID)
            self.nDispatchCardTimerID = nil
        end
        -- 启动发牌定时器
        self.nDispatchCardTimerID = self.timer_mgr:add(self.nDispatchCardTime, 1, function() self:dispatchCard() end)
	end
end

-- 游戏开始
function M:gameBegin()
    if self.nGameState == define.GAME_PLAY then
        return
    end

    self.bBegin = true
    -- 开始时间,创建房间50分钟，然后游戏才开始，
    -- 不然10分钟，游戏被解散，这里要重置下时间
    self.nCheckStartTime = os.time()

    -- 增加游戏局数
    self.nGameCount = self.nGameCount + 1
    -- 设置游戏状态
    self.nGameState = define.GAME_PLAY
    -- 开始时间
    self.start_time = os.time()

    -- 洗牌
    self.tRepertoryCard =
    {
        1,  2,  3,  4,  5,  6,  7,  8,  9,  10,
        1,  2,  3,  4,  5,  6,  7,  8,  9,  10,
        1,  2,  3,  4,  5,  6,  7,  8,  9,  10,
        1,  2,  3,  4,  5,  6,  7,  8,  9,  10,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    }
    -- 打乱
    self.logic:shuffle(self.tRepertoryCard)

    for i = 1, self.nPlayerCount do
        for _ = 1, define.MAX_COUNT-1 do
            local nCardData = self.tRepertoryCard[1]
            table.remove(self.tRepertoryCard, 1)
            self.tCardData[i][nCardData] = self.tCardData[i][nCardData] + 1
        end
    end

    local nBankCard = self.tRepertoryCard[1]
    table.remove(self.tRepertoryCard, 1)
    self.tCardData[self.nBankerSeat][nBankCard] = self.tCardData[self.nBankerSeat][nBankCard] + 1
    utils.print(self.tCardData)

    -- 设置变量
	self.bOutCard = false
	self.nCurrentSeat = self.nBankerSeat
	self.nOutCardSeat = self.nBankerSeat
	self.nOutCardData = 0

    -- 给所有人发送游戏开始
    for i = 1, self.nPlayerCount do
        local _player = player_mgr:getInSeat(i)
        if _player then
            -- 设置玩家分数
            _player:setScore(self.tTotalGameScore[i])
            _player:send("nxphz.GAME_GameStartAck", {nCurrentSeat = self.nCurrentSeat, nCardData = self.tCardData[i]})
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
    if nEndMode == define.END_NORMAL then
        local tGameEnd =
        {
            tGameScore = {},
            tTotalScore = {},
            card = {},
            weaveInfo = {},
            tRepertoryCard = self.tRepertoryCard,
            nHuCard = (self.nOutCardSeat ~= define.INVALID_SEAT) and self.nOutCardData or 0,
            nWinSeat = nSeat,
            nBankSeat = self.nBankerSeat,
            huPaiInfo =
            {
                options = {},
            },
        }
        for i = 1, self.nPlayerCount do
            -- 本局分数
            tGameEnd.tGameScore[i] = 0
            -- 总分
            tGameEnd.tTotalScore[i] = 0
            -- 设置手牌
            table.insert(tGameEnd.card, {tCardData = self.tCardData[i]})
            -- 组合
            tGameEnd.weaveInfo[i] = {}
            tGameEnd.weaveInfo[i].options = self.tWeaveItemArray[i]
        end

        if nSeat ~= define.INVALID_SEAT then
            -- 玩家跑和提了,牌要胡牌传入要置0
            local nHuCard = tGameEnd.nHuCard
            if self.bSendNotify or self.tPaoPai[nSeat] then
                nHuCard = 0
            end
            -- 执行判断
			local nTempCurrentSeat = (self.nOutCardSeat ~= define.INVALID_SEAT) and self.nOutCardSeat or self.nResumeSeat
            -- 胡牌判断
            local tHuCardInfo =
            {
                bSelf = nTempCurrentSeat == nSeat,
                nInsertCard = nHuCard,
                nHuXi = self.tHuXi[nSeat],
                tCardData = self.tCardData[nSeat],
            }
            local _, tWeaveItemArray = self.logic:getHuCardInfo(tHuCardInfo)
            for _, tWeave in ipairs(tWeaveItemArray) do
                table.insert(tGameEnd.weaveInfo[nSeat].options, tWeave)
            end

            -- 计算胡息
            local nHuXi = 0
            for _, tWeave in ipairs(tGameEnd.weaveInfo[nSeat].options) do
                nHuXi = nHuXi + self.logic:getWeaveHuXi(tWeave)
            end

            -- 胡牌倍数(名堂)
            local nBase, tHuPaiType = self:huPaiBase(tGameEnd.weaveInfo[nSeat].options)
            -- 有上限
            if room.get("limit_base") == 1 then
                if nBase > define.LIMIT_BASE then
                    nBase = define.LIMIT_BASE
                end
            end
            -- 不是大胡,需要设置倍数
            if nBase <= 0 then
                nBase = 1
            end
            tGameEnd.huPaiInfo.options = utils.copy_table(tHuPaiType)

            -- 计算积分
			local nScore = math.floor((nHuXi - define.MIN_HU_XI)/3 + 1) * self.nCellScore * nBase
            skynet.call("xlog", "lua", "log", string.format(
                "END_NORMAL nRoomID=%d,nScore=%d,nHuXi=%d,nCellScore=%d,nBase=%d",
                self.nRoomID,
                nScore,
                nHuXi,
                self.nCellScore,
                nBase))

            -- 统计积分
            for i = 1, self.nPlayerCount do
                if i == nSeat then
                    tGameEnd.tGameScore[i] = (self.nPlayerCount - 1) * nScore
                else
                    tGameEnd.tGameScore[i] = -nScore
                end
                -- 总分
                self.tTotalGameScore[i] = self.tTotalGameScore[i] + tGameEnd.tGameScore[i]
                tGameEnd.tTotalScore[i] = self.tTotalGameScore[i]
            end

            -- 设置庄家
            self.nBankerSeat = nSeat
        else
            -- 设置庄家
            self.nBankerSeat = self:getNextSeat(self.nBankerSeat)
        end

        -- 游戏结束消息广播
        player_mgr:broadcast("nxphz.GAME_GameEndAck", tGameEnd)

        -- 回放
        table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_GameEndAck", msg = tGameEnd})
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
                    score = tGameEnd.tGameScore[i],
                    total_score = self.tTotalGameScore[i]}
                )
        end
        -- 发送回放
        room.add_record_list(self.record)

		-- 输出总分数
        local szLog = ""
		for i = 1, self.nPlayerCount do
            szLog = szLog.."tGameScore["..i.."]="..tGameEnd.tGameScore[i]..
                ",tTotalScore["..i.."]="..tGameEnd.tTotalScore[i]
		end
        skynet.call("xlog", "lua", "log", szLog)

        if self.nGameCount >= self.nTotalGameCount then
            -- 游戏总结算消息广播
            player_mgr:broadcast("nxphz.GAME_GameTotalEndAck", {
                tTotalScore = self.tTotalGameScore,
            })

            -- 解散服务
            self:big_result()
        end
    -- 解散结束
    elseif nEndMode == define.END_DISSOLVE then
        local tGameEnd =
        {
            tGameScore = {},
            tTotalScore = {},
            card = {},
            weaveInfo = {},
            tRepertoryCard = self.tRepertoryCard,
            nHuCard = 0,
            nWinSeat = nSeat,
            nBankSeat = self.nBankerSeat,
            huPaiInfo =
            {
                options = {},
            },
        }
         for i = 1, self.nPlayerCount do
            -- 本局分数
            tGameEnd.tGameScore[i] = 0
            -- 总分
            tGameEnd.tTotalScore[i] = 0
            -- 设置手牌
            table.insert(tGameEnd.card, {tCardData = self.tCardData[i]})
            -- 组合
            tGameEnd.weaveInfo[i] = {}
            tGameEnd.weaveInfo[i].options = self.tWeaveItemArray[i]
        end

        -- 游戏结束消息广播
        player_mgr:broadcast("nxphz.GAME_GameEndAck", tGameEnd)

        -- 游戏总结算消息广播
        player_mgr:broadcast("nxphz.GAME_GameTotalEndAck", {
            tTotalScore = self.tTotalGameScore,
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
    self.nGameState = define.GAME_FREE

    -- 游戏变量
    -- 当前操作玩家
    self.nCurrentSeat = define.INVALID_SEAT

    -- 玩家胡息
    self.tHuXi = {}
    -- 玩家牌索引
    self.tCardData = {}
    -- 组合扑克
    self.tWeaveItemArray = {}
    for i = 1, self.nPlayerCount do
        -- 玩家胡息
        self.tHuXi[i] = 0
        -- 玩家牌索引
        self.tCardData[i] =
        {
            0,0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,0,
        }
        -- 组合扑克
        self.tWeaveItemArray[i] = {}
    end

    -- 标志变量
    -- 出牌标志
    self.bOutCard = false
    -- 判断标志
    self.bEstimate = false
    -- 派发标志
    self.bDispatch = false

    -- 提偎变量
    -- 提牌标志
    self.bTiCard = false
    -- 发送提示
    self.bSendNotify = false

    -- 辅助变量
    -- 还原用户
	self.nResumeSeat = define.INVALID_SEAT
    -- 出牌用户
	self.nOutCardSeat = define.INVALID_SEAT
    -- 出牌扑克
	self.nOutCardData = 0

	-- 发牌信息
    -- 库存扑克
    self.tRepertoryCard = {}
    -- 发牌数量
	self.nSendCardCount = 0
    -- 出牌数量
	self.nOutCardCount = 0

	-- 用户状态
    -- 玩家准备
    self.tReady = {}
    -- 响应标志
    self.tResponse = {}
    -- 用户动作
    self.tUserAction = {}
    -- 吃牌类型
    self.tChiCardKind = {}
    -- 执行动作
    self.tPerformAction = {}
    for i = 1, self.nPlayerCount do
        -- 玩家准备
        self.tReady[i] = false
        -- 响应标志
        self.tResponse[i] = false
        -- 用户动作
        self.tUserAction[i] = define.ACK_NULL
        -- 吃牌类型
        self.tChiCardKind[i] = define.ACK_NULL
        -- 执行动作
        self.tPerformAction[i] = define.ACK_NULL
    end
    -- 等摸牌玩家胡状态
    self.bWaitSendUserHu = false

	-- 限制状态
    -- 跑牌标志
    self.tPaoPai = {}
    -- 放弃扑克
    self.tAbandonCard = {}
    for i = 1, self.nPlayerCount do
         -- 跑牌标志
        self.tPaoPai[i] = false
        -- 放弃扑克
        self.tAbandonCard[i] = {}
    end
end

-- 获取下个位置
function M:getNextSeat(nSeat)
    local nIndex = (nSeat + (self.nPlayerCount - 1)) % self.nPlayerCount
    return nIndex ~= 0 and nIndex or self.nPlayerCount
end

-- 继续命令
function M:onContinueCard(nCurrentSeat)
	-- 效验数据
	if nCurrentSeat ~= self.nCurrentSeat or self.bOutCard then
		return
	end

	-- 还原用户
	self.nResumeSeat = self:getNextSeat(nCurrentSeat)
    -- 杀掉发牌定时器
    if self.nDispatchCardTimerID then
        self.timer_mgr:remove(self.nDispatchCardTimerID)
        self.nDispatchCardTimerID = nil
    end
    -- 启动发牌定时器
    self.nDispatchCardTimerID = self.timer_mgr:add(self.nDispatchCardTime, 1, function() self:dispatchCard() end)
end

-- 发牌
function M:dispatchCard()
    -- 置空发牌定时器ID,真正删除timer_mgr已包装
    self.nDispatchCardTimerID = nil

    local nCurrentSeat = self.nResumeSeat
    if nCurrentSeat == define.INVALID_SEAT then
        return
    end

    -- 无牌,结束
    if #self.tRepertoryCard == 0 then
        self:gameEnd(define.INVALID_SEAT, define.END_NORMAL)
        return
    end

    -- 有出牌玩家,记录玩家出牌
	if self.nOutCardSeat ~= define.INVALID_SEAT and self.logic:isValidCard(self.nOutCardData) then
		-- 自己臭牌记录
		self.tAbandonCard[self.nOutCardSeat][self.nOutCardData] = true
		-- 下家臭牌记录
		self.tAbandonCard[self:getNextSeat(self.nOutCardSeat)][self.nOutCardData] = true
	end

    -- 发送扑克
    local nSendCardData = self.tRepertoryCard[1]
    table.remove(self.tRepertoryCard, 1)
    -- 发牌数量增加
    self.nSendCardCount = self.nSendCardCount + 1

    -- 为了防止作弊,提,偎类型其他玩家不发牌数据
	local bPerformAction = false
	-- 提牌判断
	if self.logic:isTiPaoCard(self.tCardData[nCurrentSeat], nSendCardData) then
		bPerformAction = true
	end
	-- 偎牌变提
	if not bPerformAction then
        for _, tWeave in pairs(self.tWeaveItemArray[nCurrentSeat]) do
            -- 变量定义
			local nWeaveKind = tWeave.nWeaveKind
			local nWeaveCard = tWeave.tCardData[1]

			-- 转换判断
			if not (nSendCardData ~= nWeaveCard or nWeaveKind ~= define.ACK_WEI) then
                bPerformAction = true
                break
			end
        end
	end

	-- 偎牌判断
	if not bPerformAction and self.logic:isWeiPengCard(self.tCardData[nCurrentSeat], nSendCardData) then
		bPerformAction = true
	end

	-- 发送数据
	local tData =
    {
        nCurrentSeat = nCurrentSeat,
        nCardData = nSendCardData,
        nOutCardSeat = self.nOutCardSeat,
        nOutCardData = self.nOutCardData,
    }
    table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_SendCardAck", msg = tData})
	for i = 1, self.nPlayerCount do
		-- 有提,偎操作
		if bPerformAction then
			if i == nCurrentSeat then
				tData.nCardData = nSendCardData
			else
				tData.nCardData = 0
			end
		end
        local _player = player_mgr:getInSeat(i)
        if _player then
            _player:send("nxphz.GAME_SendCardAck", tData)
        end
	end

	-- 动作变量
    -- 响应标志
    self.tResponse = {}
    -- 用户动作
    self.tUserAction = {}
    -- 吃牌类型
    self.tChiCardKind = {}
    -- 执行动作
    self.tPerformAction = {}
    for i = 1, self.nPlayerCount do
        -- 响应标志
        self.tResponse[i] = false
        -- 用户动作
        self.tUserAction[i] = define.ACK_NULL
        -- 吃牌类型
        self.tChiCardKind[i] = define.ACK_NULL
        -- 执行动作
        self.tPerformAction[i] = define.ACK_NULL
    end

	-- 设置变量
    self.bOutCard = false
	self.bDispatch = true
	self.bEstimate = false
	self.nOutCardSeat = nCurrentSeat
	self.nOutCardData = nSendCardData
	self.nCurrentSeat = nCurrentSeat
	self.nResumeSeat = self:getNextSeat(nCurrentSeat)
	self.tPaoPai = {}
    for i = 1, self.nPlayerCount do
        self.tPaoPai[i] = false
    end

	-- 派发扑克
	if not self:estimateUserRespond(nCurrentSeat, nSendCardData, self.bDispatch) then
		-- 发送出牌提示
		self:sendOutCardNotify(nCurrentSeat, false)
	end
end

-- 出牌提示
function M:sendOutCardNotify(nCurrentSeat, bOutCard)
	-- 效验参数
	if nCurrentSeat == define.INVALID_SEAT then
		return
	end

	-- 过牌判断
	if bOutCard then
		for i = 1, define.MAX_CARD do
			if self.tCardData[nCurrentSeat][i] > 0 and self.tCardData[nCurrentSeat][i] < 3 then
				break
            else
                if i == define.MAX_CARD then
                    bOutCard = false
                    break
                end
			end
		end
	end

	-- 设置变量
	self.bTiCard = false
	self.bSendNotify = false

	-- 设置变量
	self.bOutCard = bOutCard
	self.nCurrentSeat = nCurrentSeat

	-- 构造数据
	local tData =
    {
        nCurrentSeat = nCurrentSeat,
		bOutCard = bOutCard,
    }
    player_mgr:broadcast("nxphz.GAME_OutCardNotifyAck", tData)
    -- 回放数据
    table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_OutCardNotifyAck", msg = tData})

	-- 不用出牌
	if not bOutCard then
		-- 继续下个操作
		self:onContinueCard(nCurrentSeat)
	end
end

-- 响应判断
function M:estimateUserRespond(nCenterSeat, nCenterCard, bDispatch)
    local strMsg = ""
    for i = 1, self.nPlayerCount do
        strMsg = ",nHuXi["..i.."]="..self.tHuXi[i]
    end
    skynet.call("xlog", "lua", "log", string.format(
            "nRoomID=%d,bEstimate=%s,nCenterSeat=%d,nCenterCard=%d,bDispatch=%s,%s",
            self.nRoomID,
            utils.table_2_str(self.bEstimate),
            nCenterSeat,
            nCenterCard,
            utils.table_2_str(bDispatch),
            strMsg))

	-- 执行变量
	local bPerformAction = false
	-- 提牌判断
	if not self.bEstimate and bDispatch and self.logic:isTiPaoCard(self.tCardData[nCenterSeat], nCenterCard) then
		-- 设置组合
        local tWeave =
        {
            nWeaveKind = define.ACK_TI,
            nCenterCard = nCenterCard,
            tCardData = {nCenterCard, nCenterCard, nCenterCard, nCenterCard},
        }
        table.insert(self.tWeaveItemArray[nCenterSeat], tWeave)

		-- 更新胡息
		self:updateHuXi(nCenterSeat)

		-- 发送数据
        local tData =
        {
            nCurrentSeat = nCenterSeat,
            nCardData = nCenterCard,
            nRemoveCount = self.tCardData[nCenterSeat][nCenterCard],
            bWeiToTi = false,
        }
        -- 回放数据
        table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_TiCardAck", msg = tData})
        for i = 1, self.nPlayerCount do
            if i == nCenterSeat then
				tData.nCardData = nCenterCard
			else
				tData.nCardData = 0
			end
            local _player = player_mgr:getInSeat(i)
            if _player then
                _player:send("nxphz.GAME_TiCardAck", tData)
            end
        end

        -- 删除扑克
		self.tCardData[nCenterSeat][nCenterCard] = 0

		-- 设置变量
		nCenterCard = 0
		bPerformAction = true
		self.nResumeSeat = nCenterSeat
		self.nOutCardSeat = define.INVALID_SEAT
		self.nOutCardData = 0

		-- 出牌提示
		self.bTiCard = true
		self.bSendNotify = true
	end

    skynet.call("xlog", "lua", "log", string.format(
        "Ti nRoomID=%d,bPerformAction=%s,bEstimate=%s,bDispatch=%s",
        self.nRoomID,
        utils.table_2_str(bPerformAction),
        utils.table_2_str(self.bEstimate),
        utils.table_2_str(bDispatch)))
	-- 偎牌变提
	if not bPerformAction and not self.bEstimate and bDispatch then
        for _, tWeave in pairs(self.tWeaveItemArray[nCenterSeat]) do
			-- 转换判断
			if not (nCenterCard ~= tWeave.nWeaveCard or tWeave.nWeaveKind ~= define.ACK_WEI) then
                -- 设置组合
                tWeave.nWeaveKind = define.ACK_TI
                table.insert(tWeave.tCardData, nCenterCard)

                -- 更新胡息
                self:updateHuXi(nCenterSeat)

                -- 发送数据
                local tData =
                {
                    nCurrentSeat = nCenterSeat,
                    nCardData = nCenterCard,
                    nRemoveCount = 0,
                    bWeiToTi = true,
                }
                -- 回放数据
                table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_TiCardAck", msg = tData})
                for i = 1, self.nPlayerCount do
                    if i == nCenterSeat then
                        tData.nCardData = nCenterCard
                    else
                        tData.nCardData = 0
                    end
                    local _player = player_mgr:getInSeat(i)
                    if _player then
                        _player:send("nxphz.GAME_TiCardAck", tData)
                    end
                end

                -- 设置变量
                nCenterCard = 0
                bPerformAction = true
                self.nResumeSeat = nCenterSeat
                self.nOutCardSeat = define.INVALID_SEAT
                self.nOutCardData = 0

                -- 出牌提示
                self.bTiCard = true
                self.bSendNotify = true
                break
            end
		end
	end

    skynet.call("xlog", "lua", "log", string.format(
        "wei nRoomID=%d,bPerformAction=%s,bEstimate=%s,bDispatch=%s",
        self.nRoomID,
        utils.table_2_str(bPerformAction),
        utils.table_2_str(self.bEstimate),
        utils.table_2_str(bDispatch)))
	-- 偎牌判断
	if not bPerformAction and not self.bEstimate and bDispatch and
        self.logic:isWeiPengCard(self.tCardData[nCenterSeat], nCenterCard) then
		-- 设置扑克
		self.tCardData[nCenterSeat][nCenterCard] = 0

        -- 设置组合
        local tWeave =
        {
            nWeaveKind = define.ACK_WEI,
            nCenterCard = nCenterCard,
            tCardData = {nCenterCard, nCenterCard, nCenterCard},
        }
        table.insert(self.tWeaveItemArray[nCenterSeat], tWeave)

		-- 更新胡息
		self:updateHuXi(nCenterSeat)

        -- 发送数据
        local tData =
        {
            nCurrentSeat = nCenterSeat,
            nCardData = nCenterCard,
            bChouWei = self.tAbandonCard[nCenterSeat][nCenterCard],
        }
        -- 回放数据
        table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_WeiCardAck", msg = tData})
        for i = 1, self.nPlayerCount do
            if i == nCenterSeat then
                tData.nCardData = nCenterCard
            else
                tData.nCardData = 0
            end
            local _player = player_mgr:getInSeat(i)
            if _player then
                _player:send("nxphz.GAME_WeiCardAck", tData)
            end
        end

		-- 设置变量
		nCenterCard = 0
		bPerformAction = true
		self.nResumeSeat = nCenterSeat
		self.nOutCardSeat = define.INVALID_SEAT
        self.nOutCardData = 0

		-- 出牌提示
		self.bTiCard = false
		self.bSendNotify = true
	end

    skynet.call("xlog", "lua", "log", string.format(
        "send Hu nRoomID=%d,bPerformAction=%s,bEstimate=%s,bDispatch=%s,bWaitSendUserHu=%s",
        self.nRoomID,
        utils.table_2_str(bPerformAction),
        utils.table_2_str(self.bEstimate),
        utils.table_2_str(bDispatch),
        utils.table_2_str(self.bWaitSendUserHu)))
	-- 是发的牌，且非等摸牌玩家胡状态，要判断摸的牌能不能胡，不能胡才能走跑的流程
	if not bPerformAction and not self.bEstimate and bDispatch and not self.bWaitSendUserHu then
		-- 胡牌判断
        local tHuCardInfo =
        {
            bSelf = true,
            nInsertCard = nCenterCard,
            nHuXi = self.tHuXi[nCenterSeat],
            tCardData = self.tCardData[nCenterSeat],
        }
		if self.logic:getHuCardInfo(tHuCardInfo) then
            -- 动作变量
            -- 响应标志
            self.tResponse = {}
            -- 用户动作
            self.tUserAction = {}
            -- 吃牌类型
            self.tChiCardKind = {}
            -- 执行动作
            self.tPerformAction = {}
            for i = 1, self.nPlayerCount do
                -- 响应标志
                self.tResponse[i] = false
                -- 用户动作
                self.tUserAction[i] = define.ACK_NULL
                -- 吃牌类型
                self.tChiCardKind[i] = define.ACK_NULL
                -- 执行动作
                self.tPerformAction[i] = define.ACK_NULL
            end
            -- 设置等待发牌玩家胡牌
			self.bWaitSendUserHu = false

			-- 设置摸牌玩家可胡
			self.tUserAction[nCenterSeat] = define.ACK_CHIHU
			-- 设置等待发牌玩家胡牌
			self.bWaitSendUserHu = true

			-- 设置用户
			self.bEstimate = true
			-- 当前操作玩家
			self.nCurrentSeat = define.INVALID_SEAT
			-- 设置出牌玩家
			self.nOutCardSeat = nCenterSeat
			-- 设置出牌数据
			self.nOutCardData = nCenterCard

            for i = 1, self.nPlayerCount do
                -- 发送数据
                local tData =
                {
                    nCurrentSeat = nCenterSeat,
                    nCardData = nCenterCard,
                    nOperate = self.tUserAction[i],
                }
                -- 回放数据
                table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_OperateCardAck", msg = tData})
                local _player = player_mgr:getInSeat(i)
                if _player then
                    _player:send("nxphz.GAME_OperateCardAck", tData)
                end
            end

			return true
		end
	end

    skynet.call("xlog", "lua", "log", string.format(
        "Hu nRoomID=%d,bEstimate=%s,bDispatch=%s",
        self.nRoomID,
        utils.table_2_str(self.bEstimate),
        utils.table_2_str(bDispatch)))
	-- 胡牌判断
	if not self.bEstimate and bDispatch then
		-- 动作变量
        -- 响应标志
        self.tResponse = {}
        -- 用户动作
        self.tUserAction = {}
        -- 吃牌类型
        self.tChiCardKind = {}
        -- 执行动作
        self.tPerformAction = {}
        for i = 1, self.nPlayerCount do
            -- 响应标志
            self.tResponse[i] = false
            -- 用户动作
            self.tUserAction[i] = define.ACK_NULL
            -- 吃牌类型
            self.tChiCardKind[i] = define.ACK_NULL
            -- 执行动作
            self.tPerformAction[i] = define.ACK_NULL
        end
        -- 设置等待发牌玩家胡牌
        self.bWaitSendUserHu = false

		-- 玩家有提，偎，需要判断改玩家能不能胡
		if bPerformAction then
            -- 胡牌判断
            local tHuCardInfo =
            {
                bSelf = true,   -- 插入的是0，随便值都可以
                nInsertCard = 0,
                nHuXi = self.tHuXi[nCenterSeat],
                tCardData = self.tCardData[nCenterSeat],
            }
            if self.logic:getHuCardInfo(tHuCardInfo) then
				self.tUserAction[nCenterSeat] = self.tUserAction[nCenterSeat] | define.ACK_CHIHU
			end
		else
			-- 胡牌判断
			for i = 1, self.nPlayerCount do
				-- 用户过滤
				if not (not bDispatch and i == nCenterSeat) then
                    -- 胡牌判断
                    local tHuCardInfo =
                    {
                        bSelf = false,
                        nInsertCard = nCenterCard,
                        nHuXi = self.tHuXi[i],
                        tCardData = self.tCardData[i],
                    }
                    if self.logic:getHuCardInfo(tHuCardInfo) then
                        self.tUserAction[i] = self.tUserAction[i] | define.ACK_CHIHU
                    end
                end
			end
		end

		-- 响应处理
        local bAction = false
		for i = 1, self.nPlayerCount do
            if self.tUserAction[i] ~= define.ACK_NULL then
                bAction = true
                break
            end
        end
		if bAction then
			-- 设置用户
			self.bEstimate = true
			-- 当前用户
			self.nCurrentSeat = define.INVALID_SEAT

            local strActionMsg = ""
            for i = 1, self.nPlayerCount do
                strActionMsg = ",tUserAction["..i.."]="..self.tUserAction[i]
            end
            skynet.call("xlog", "lua", "log", string.format(
                "nRoomID=%d,nCenterSeat=%d,nCenterCard=%d,%s",
                self.nRoomID,
                nCenterSeat,
                nCenterCard,
                strActionMsg))

			-- 发送消息
            for i = 1, self.nPlayerCount do
                -- 发送数据
                local tData =
                {
                    nCurrentSeat = nCenterSeat,
                    nCardData = nCenterCard,
                    nOperate = self.tUserAction[i],
                }
                -- 回放数据
                table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_OperateCardAck", msg = tData})
                local _player = player_mgr:getInSeat(i)
                if _player then
                    _player:send("nxphz.GAME_OperateCardAck", tData)
                end
            end

			return true
		end
	end

    skynet.call("xlog", "lua", "log", string.format(
        "bSendNotify nRoomID=%d,nCenterSeat=%d,bSendNotify=%s,bTiCard=%s",
        self.nRoomID,
        nCenterSeat,
        utils.table_2_str(self.bSendNotify),
        utils.table_2_str(self.bTiCard)))
	-- 出牌提示
	if self.bSendNotify then
		-- 设置标志
		self.bEstimate = true

		-- 发送消息
		if not self.bTiCard then
			self:sendOutCardNotify(self.nResumeSeat, true)
		else
			self:sendOutCardNotify(self.nResumeSeat, self:isAllowOutCard(self.nResumeSeat))
		end

		-- 设置变量
		self.bTiCard = false
		self.bSendNotify = false

		return true
	end

    skynet.call("xlog", "lua", "log", "shoupai pao nRoomID="..self.nRoomID)
	-- 跑牌判断
	for i = 1, self.nPlayerCount do
		-- 用户过滤或玩家已经在跑牌状态了
		if i ~= nCenterSeat and not self.tPaoPai[i] then
            -- 跑牌判断
            if self.logic:isTiPaoCard(self.tCardData[i], nCenterCard) then
                -- 变量定义
                local nActionSeat = i

                -- 设置组合
                local tWeave =
                {
                    nWeaveKind = define.ACK_PAO,
                    nCenterCard = nCenterCard,
                    tCardData = {nCenterCard, nCenterCard, nCenterCard, nCenterCard},
                }
                table.insert(self.tWeaveItemArray[nActionSeat], tWeave)

                -- 设置跑牌
                self.tPaoPai[nActionSeat] = true

                -- 更新胡息
                self:updateHuXi(nActionSeat)

                -- 构造数据
                local tData =
                {
                    nCurrentSeat = nActionSeat,
                    nCardData = nCenterCard,
                    nRemoveCount = self.tCardData[nActionSeat][nCenterCard],
                    bWeiToPao = false,
                }
                player_mgr:broadcast("nxphz.GAME_PaoCardAck", tData)
                -- 回放数据
                table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_PaoCardAck", msg = tData})

                -- 删除扑克
                self.tCardData[nActionSeat][nCenterCard] = 0

                skynet.call("xlog", "lua", "log", string.format(
                    "nRoomID=%d,nCenterSeat=%d,nActionSeat=%d,bDispatch=%s",
                    self.nRoomID,
                    nCenterSeat,
                    nActionSeat,
                    utils.table_2_str(bDispatch)))
                -- 是发牌
                if bDispatch then
                    -- 胡牌判断
                    local tHuCardInfo =
                    {
                        bSelf = true,   -- 插入的是0，随便值都可以
                        nInsertCard = 0,
                        nHuXi = self.tHuXi[nActionSeat],
                        tCardData = self.tCardData[nActionSeat],
                    }
                    if self.logic:getHuCardInfo(tHuCardInfo) then
                        -- 动作变量
                        -- 响应标志
                        self.tResponse = {}
                        -- 用户动作
                        self.tUserAction = {}
                        -- 吃牌类型
                        self.tChiCardKind = {}
                        -- 执行动作
                        self.tPerformAction = {}
                        for j = 1, self.nPlayerCount do
                            -- 响应标志
                            self.tResponse[j] = false
                            -- 用户动作
                            self.tUserAction[j] = define.ACK_NULL
                            -- 吃牌类型
                            self.tChiCardKind[j] = define.ACK_NULL
                            -- 执行动作
                            self.tPerformAction[j] = define.ACK_NULL
                        end
                        -- 设置等待发牌玩家胡牌
                        self.bWaitSendUserHu = false

                        -- 设置摸牌玩家可胡
                        self.tUserAction[nActionSeat] = define.ACK_CHIHU

                        skynet.call("xlog", "lua", "log", string.format(
                            "PAO_HU nRoomID=%d,nCenterSeat=%d,nActionSeat=%d,bDispatch=%s,tUserAction[%d]=%d,bHu=%s",
                            self.nRoomID,
                            nCenterSeat,
                            nActionSeat,
                            utils.table_2_str(bDispatch),
                            nActionSeat,
                            self.tUserAction[nActionSeat],
                            utils.table_2_str(self.bWaitSendUserHu)))

                        -- 设置用户
                        self.bEstimate = true
                        -- 当前操作玩家
                        self.nCurrentSeat = define.INVALID_SEAT
                        -- 设置出牌玩家
                        self.nOutCardSeat = nActionSeat
                        -- 设置出牌数据
                        self.nOutCardData = 0

                        -- 发送消息
                        for j = 1, self.nPlayerCount do
                            -- 发送数据
                            local tOperateCardData =
                            {
                                nCurrentSeat = nActionSeat,
                                nCardData = nCenterCard,
                                nOperate = self.tUserAction[j],
                            }
                            -- 回放数据
                            table.insert(self.record.game.data, {
                                time = os.time(),
                                name = "nxphz.GAME_OperateCardAck",
                                msg = tOperateCardData})
                            local _player = player_mgr:getInSeat(j)
                            if _player then
                                _player:send("nxphz.GAME_OperateCardAck", tOperateCardData)
                            end
                        end

                        return true
                    end
                end

                -- 设置标志
                self.bEstimate = true
                -- 设置变量
                self.nOutCardSeat = define.INVALID_SEAT
                -- 设置出牌值
                self.nOutCardData = 0
                -- 出牌提示
                self:sendOutCardNotify(nActionSeat, self:isAllowOutCard(nActionSeat))

                return true
            end
        end
	end

    skynet.call("xlog", "lua", "log", "paidun pao nRoomID="..self.nRoomID)
	-- 跑牌转换
	for i = 1, self.nPlayerCount do
		-- 玩家已经在跑牌状态了
		if not self.tPaoPai[i] then
            for _, tWeaveItem in pairs(self.tWeaveItemArray[i]) do
                -- 转换判断
                local bChangeWeave = false
                if nCenterCard == tWeaveItem.nCenterCard then
                    if tWeaveItem.nWeaveKind == define.ACK_WEI then
                        bChangeWeave = true
                    elseif tWeaveItem.nWeaveKind == define.ACK_PENG and bDispatch then
                        bChangeWeave = true
                    end
                end

                if bChangeWeave then
                     -- 变量定义
                    local nActionSeat = i

                    local nWeaveKind = define.ACK_PAO
                    if nCenterSeat == i and tWeaveItem.nWeaveKind == define.ACK_WEI then
                        nWeaveKind = define.ACK_TI
                    end
                    -- 设置组合
                    tWeaveItem.nWeaveKind = nWeaveKind
                    tWeaveItem.nCenterCard = nCenterCard
                    table.insert(tWeaveItem.tCardData, nCenterCard)

                    if nWeaveKind == define.ACK_PAO then
                        -- 设置跑牌
                        self.tPaoPai[nActionSeat] = true
                    end

                    -- 更新胡息
                    self:updateHuXi(nActionSeat)

                    -- 发送数据
                    if nWeaveKind == define.ACK_TI then
                        -- 发送数据
                        local tData =
                        {
                            nCurrentSeat = nActionSeat,
                            nCardData = nCenterCard,
                            nRemoveCount = 0,
                            bWeiToTi = true,
                        }
                        -- 回放数据
                        table.insert(self.record.game.data, {
                            time = os.time(),
                            name = "nxphz.GAME_TiCardAck",
                            msg = tData})
                        for j = 1, self.nPlayerCount do
                            if j == nActionSeat then
                                tData.nCardData = nCenterCard
                            else
                                tData.nCardData = 0
                            end
                            local _player = player_mgr:getInSeat(j)
                            if _player then
                                _player:send("nxphz.GAME_TiCardAck", tData)
                            end
                        end
                    else
                        -- 构造数据
                        local tData =
                        {
                            nCurrentSeat = nActionSeat,
                            nCardData = nCenterCard,
                            nRemoveCount = 0,
                            bWeiToPao = tWeaveItem.nWeaveKind == define.ACK_WEI,
                        }
                        player_mgr:broadcast("nxphz.GAME_PaoCardAck", tData)
                        -- 回放数据
                        table.insert(self.record.game.data, {
                            time = os.time(),
                            name = "nxphz.GAME_PaoCardAck",
                            msg = tData})
                    end

                    -- 是发牌
                    if bDispatch then
                        -- 胡牌判断
                        local tHuCardInfo =
                        {
                            bSelf = true,   -- 插入的是0，随便值都可以
                            nInsertCard = 0,
                            nHuXi = self.tHuXi[nActionSeat],
                            tCardData = self.tCardData[nActionSeat],
                        }
                        if self.logic:getHuCardInfo(tHuCardInfo) then
                            -- 动作变量
                            -- 响应标志
                            self.tResponse = {}
                            -- 用户动作
                            self.tUserAction = {}
                            -- 吃牌类型
                            self.tChiCardKind = {}
                            -- 执行动作
                            self.tPerformAction = {}
                            for j = 1, self.nPlayerCount do
                                -- 响应标志
                                self.tResponse[j] = false
                                -- 用户动作
                                self.tUserAction[j] = define.ACK_NULL
                                -- 吃牌类型
                                self.tChiCardKind[j] = define.ACK_NULL
                                -- 执行动作
                                self.tPerformAction[j] = define.ACK_NULL
                            end
                            -- 设置等待发牌玩家胡牌
                            self.bWaitSendUserHu = false

                            -- 设置摸牌玩家可胡
                            self.tUserAction[nActionSeat] = define.ACK_CHIHU

                            skynet.call("xlog", "lua", "log", string.format(
                                "PAO_HU change nRoomID=%d,nCenterSeat=%d,nActionSeat=%d,tUserAction[%d]=%d,bHu=%s",
                                self.nRoomID,
                                nCenterSeat,
                                nActionSeat,
                                nActionSeat,
                                self.tUserAction[nActionSeat],
                                utils.table_2_str(self.bWaitSendUserHu)))

                            -- 设置用户
                            self.bEstimate = true
                            -- 当前操作玩家
                            self.nCurrentSeat = define.INVALID_SEAT
                            -- 设置出牌玩家
                            self.nOutCardSeat = nActionSeat
                            -- 设置出牌数据
                            self.nOutCardData = 0

                            -- 发送消息
                            for j = 1, self.nPlayerCount do
                                 local tData =
                                {
                                    nCurrentSeat = nActionSeat,
                                    nCardData = nCenterCard,
                                    nOperate = self.tUserAction[j],
                                }
                                -- 回放数据
                                table.insert(self.record.game.data, {
                                    time = os.time(),
                                    name = "nxphz.GAME_OperateCardAck",
                                    msg = tData})
                                local _player = player_mgr:getInSeat(j)
                                if _player then
                                    _player:send("nxphz.GAME_OperateCardAck", tData)
                                end
                            end

                            return true
                        end
                    end

                    -- 设置标志
                    self.bEstimate = true
                    -- 设置变量
                    self.nOutCardSeat = define.INVALID_SEAT
                    -- 设置出牌值
                    self.nOutCardData = 0
                    -- 出牌提示
                    self:sendOutCardNotify(nActionSeat, self:isAllowOutCard(nActionSeat))

                    return true
                end
            end
        end
	end

	-- 动作变量
    -- 响应标志
    self.tResponse = {}
    -- 用户动作
    self.tUserAction = {}
    -- 吃牌类型
    self.tChiCardKind = {}
    -- 执行动作
    self.tPerformAction = {}
    for i = 1, self.nPlayerCount do
        -- 响应标志
        self.tResponse[i] = false
        -- 用户动作
        self.tUserAction[i] = define.ACK_NULL
        -- 吃牌类型
        self.tChiCardKind[i] = define.ACK_NULL
        -- 执行动作
        self.tPerformAction[i] = define.ACK_NULL
    end
    -- 设置等待发牌玩家胡牌
    self.bWaitSendUserHu = false

	-- 有人跑了,就不允许吃,碰了
	local bFindPaoPai = false
	for i = 1, self.nPlayerCount do
		if self.tPaoPai[i] then
			bFindPaoPai = true
			break
		end
	end
	-- 没跑才允许吃和碰
	if not bFindPaoPai then
		-- 吃碰判断
		for i = 1, self.nPlayerCount do
			-- 用户过滤
			if not (not bDispatch and i == nCenterSeat) then
                -- 吃了以后没牌可出，不准吃碰
                local nTotalCardCount = 0
                for nCardData = 1, define.MAX_CARD do
                    if self.tCardData[i][nCardData] < 3 then
                        nTotalCardCount = nTotalCardCount + self.tCardData[i][nCardData]
                    end
                end
                if nTotalCardCount ~= 2 then
                    -- 吃碰判断
                    if not self.tAbandonCard[i][nCenterCard] then
                        -- 碰牌判断
                        if self.logic:isWeiPengCard(self.tCardData[i], nCenterCard) then
                            self.tUserAction[i] = self.tUserAction[i] | define.ACK_PENG
                        end

                        -- 吃牌判断
                        local nEatSeat = self:getNextSeat(nCenterSeat)
                        -- 吃牌需要数量
                        local bEat, tEatCardData = self.logic:isChiCard(self.tCardData[i], nCenterCard)
                        -- 吃牌需要的牌要比手牌少
                        if (nEatSeat == i or nCenterSeat == i) and bEat and #tEatCardData*3 - 1 < nTotalCardCount then
                            self.tUserAction[i] = self.tUserAction[i] | define.ACK_CHI
                            if i == nCenterSeat then
                                self.tUserAction[i] = self.tUserAction[i] | define.ACK_CHI_EX
                            end
                        end
                    end
                end
            end
		end
	end

    local strActionMsg = ""
    for i = 1, self.nPlayerCount do
        strActionMsg = ",tUserAction["..i.."]="..self.tUserAction[i]
    end
    skynet.call("xlog", "lua", "log", string.format(
        "nRoomID=%d,nCenterSeat=%d,nCenterCard=%d,%s",
        self.nRoomID,
        nCenterSeat,
        nCenterCard,
        strActionMsg))

    -- 响应处理
    local bAction = false
    for i = 1, self.nPlayerCount do
        if self.tUserAction[i] ~= define.ACK_NULL then
            bAction = true
            break
        end
    end
	-- 响应处理
	if bAction then
		-- 设置标志
		self.bEstimate = true
		-- 设置用户
		self.nCurrentSeat = define.INVALID_SEAT

        -- 发送消息
        for i = 1, self.nPlayerCount do
            -- 发送数据
            local tData =
            {
                nCurrentSeat = self.nResumeSeat,
                nCardData = nCenterCard,
                nOperate = self.tUserAction[i],
            }
            -- 回放数据
            table.insert(self.record.game.data, {time = os.time(), name = "nxphz.GAME_OperateCardAck", msg = tData})
            local _player = player_mgr:getInSeat(i)
            if _player then
                _player:send("nxphz.GAME_OperateCardAck", tData)
            end
        end

		return true
	end

    skynet.call("xlog", "lua", "log", "nRoomID="..self.nRoomID..",nCenterSeat="..nCenterSeat)
	return false
end

-- 出牌判断
function M:isAllowOutCard(nCurrentSeat)
	-- 跑提数量
	local nTiPaoCount = 0
    -- 组合找
	for _, tWeave in pairs(self.tWeaveItemArray[nCurrentSeat]) do
		if #tWeave.tCardData == 4 then
			nTiPaoCount = nTiPaoCount + 1
		end
	end

    -- 手上找
    for i = 1, define.MAX_CARD do
        if self.tCardData[nCurrentSeat][i] == 4 then
            nTiPaoCount = nTiPaoCount + 1
        end
    end

	return nTiPaoCount <= 1
end

-- 更新胡息
function M:updateHuXi(nCurrentSeat)
	-- 胡息计算
	local nHuXi = 0
	for _, tWeave in pairs(self.tWeaveItemArray[nCurrentSeat]) do
        nHuXi = nHuXi + self.logic:getWeaveHuXi(tWeave)
    end
	-- 设置胡息
	self.tHuXi[nCurrentSeat] = nHuXi
end

-- 吃牌需要牌
function M:chiPaiMustCard(nChiKin, nOutCard, bFilterOutCard)
    local _ = self
    local tCardData = {}
	-- 不过滤出牌
	if not bFilterOutCard then
        table.insert(tCardData, nOutCard)
	end

    -- 大小搭(小小大)
    if nChiKin == define.CK_XXD then
        --大小搭吃
        local nReverseCard = nOutCard > 10 and nOutCard - 10 or nOutCard + 10
        -- 是小牌
        if nOutCard <= 10 then
            table.insert(tCardData, nOutCard)
            table.insert(tCardData, nReverseCard)
        else
            table.insert(tCardData, nReverseCard)
            table.insert(tCardData, nReverseCard)
        end
    -- 大小搭(小大大)
    elseif nChiKin == define.CK_XDD then
         --大小搭吃
        local nReverseCard = nOutCard > 10 and nOutCard - 10 or nOutCard + 10
        -- 是小牌
        if nOutCard <= 10 then
            table.insert(tCardData, nReverseCard)
            table.insert(tCardData, nReverseCard)
        else
            table.insert(tCardData, nOutCard)
            table.insert(tCardData, nReverseCard)
        end
    -- 二七十
    elseif nChiKin == define.CK_EQS then
        local tTempCardData = {2, 7, 10}
        -- 是大牌
        if nOutCard > 10 then
            for k, _ in ipairs(tTempCardData) do
                tTempCardData[k] = tTempCardData[k] + 10
            end
        end

        local bFind = false
        for _, v in ipairs(tTempCardData) do
            if v == nOutCard then
                bFind = true
                break
            end
        end
        if not bFind then
            return false, nil
        end

        for _, v in ipairs(tTempCardData) do
            if v ~= nOutCard then
                table.insert(tCardData, v)
            end
        end
    -- 左吃
    elseif nChiKin == define.CK_LEFT then
        -- 左吃,比如吃小1，小2+小3吃小1就是左吃
        local nSmallCardData = nOutCard > 10 and nOutCard - 10 or nOutCard
        if nSmallCardData > 8 then
            return false, nil
        end

        table.insert(tCardData, nOutCard + 1)
        table.insert(tCardData, nOutCard + 2)
    -- 中吃
    elseif nChiKin == define.CK_CENTER then
        -- 中吃,比如吃小3，小2+小4吃小3就是中吃
        local nSmallCardData = nOutCard > 10 and nOutCard - 10 or nOutCard
        if nSmallCardData < 2 or nSmallCardData > 9 then
            return false, nil
        end

        table.insert(tCardData, nOutCard - 1)
        table.insert(tCardData, nOutCard + 1)
    -- 右吃
    elseif nChiKin == define.CK_RIGHT then
        -- 右吃,比如吃小10，小8+小9吃小10就是右吃
        local nSmallCardData = nOutCard > 10 and nOutCard - 10 or nOutCard
        if nSmallCardData < 3 then
            return false, nil
        end

        table.insert(tCardData, nOutCard - 1)
        table.insert(tCardData, nOutCard - 2)
    else
        return false, nil
    end

	return true, tCardData
end

-- 吃牌需要牌提取
function M:chiPaiMustCardTiQu(nChiKin, nOutCard, tCardData)
    local _ = self
    table.insert(tCardData, nOutCard)

    -- 大小搭(小小大)
    if nChiKin == define.CK_XXD then
        --大小搭吃
        local nReverseCard = nOutCard > 10 and nOutCard - 10 or nOutCard + 10
        -- 是小牌
        if nOutCard <= 10 then
            table.insert(tCardData, nOutCard)
            table.insert(tCardData, nReverseCard)
        else
            table.insert(tCardData, nReverseCard)
            table.insert(tCardData, nReverseCard)
        end
    -- 大小搭(小大大)
    elseif nChiKin == define.CK_XDD then
         --大小搭吃
        local nReverseCard = nOutCard > 10 and nOutCard - 10 or nOutCard + 10
        -- 是小牌
        if nOutCard <= 10 then
            table.insert(tCardData, nReverseCard)
            table.insert(tCardData, nReverseCard)
        else
            table.insert(tCardData, nOutCard)
            table.insert(tCardData, nReverseCard)
        end
    -- 二七十
    elseif nChiKin == define.CK_EQS then
        local tTempCardData = {2, 7, 10}
        -- 是大牌
        if nOutCard > 10 then
            for k, _ in ipairs(tTempCardData) do
                tTempCardData[k] = tTempCardData[k] + 10
            end
        end

        local bFind = false
        for _, v in ipairs(tTempCardData) do
            if v == nOutCard then
                bFind = true
                break
            end
        end
        if bFind then
            for _, v in ipairs(tTempCardData) do
                if v ~= nOutCard then
                    table.insert(tCardData, v)
                end
            end
        end
    -- 左吃
    elseif nChiKin == define.CK_LEFT then
        -- 左吃,比如吃小1，小2+小3吃小1就是左吃
        local nSmallCardData = nOutCard > 10 and nOutCard - 10 or nOutCard
        if nSmallCardData > 8 then
            return false, nil
        end

        table.insert(tCardData, nOutCard + 1)
        table.insert(tCardData, nOutCard + 2)
    -- 中吃
    elseif nChiKin == define.CK_CENTER then
        -- 中吃,比如吃小3，小2+小4吃小3就是中吃
        local nSmallCardData = nOutCard > 10 and nOutCard - 10 or nOutCard
        if nSmallCardData < 2 or nSmallCardData > 9 then
            return false, nil
        end

        table.insert(tCardData, nOutCard - 1)
        table.insert(tCardData, nOutCard + 1)
    -- 右吃
    elseif nChiKin == define.CK_RIGHT then
        -- 右吃,比如吃小10，小8+小9吃小10就是右吃
        local nSmallCardData = nOutCard > 10 and nOutCard - 10 or nOutCard
        if nSmallCardData < 3 then
            return false, nil
        end

        table.insert(tCardData, nOutCard - 1)
        table.insert(tCardData, nOutCard - 2)
    end
end

-- 胡牌倍数
function M:huPaiBase(tWeaveItemArray)
	local nBase = 0
	local r = {}

	-- 天胡
    if self.nSendCardCount == 0 and self.nOutCardCount == 0 then
        local nTempBase = define.tHuPaiType["TianHu"]
        nBase = nBase + nTempBase
        local t = {key = "TianHu",  nValue = nTempBase}
        table.insert(r, t)
    end

    -- 地胡
    if self.nSendCardCount == 1 and self.nOutCardCount == 1 then
        local nTempBase = define.tHuPaiType["TianHu"]
        nBase = nBase + nTempBase
        local t = {key = "DiHu",  nValue = nTempBase}
        table.insert(r, t)
    end

	-- 碰碰胡
    -- 组合中没有吃，就是碰碰胡
    local bPengPengHu = true
    for _, tWeave in ipairs(tWeaveItemArray) do
        if tWeave.nWeaveKind == define.ACK_CHI then
            bPengPengHu = false
            break
        end
    end
    -- 是碰碰胡
    if bPengPengHu then
        local nTempBase = define.tHuPaiType["PengPengHu"]
        nBase = nBase + nTempBase
        local t = {key = "PengPengHu",  nValue = nTempBase}
        table.insert(r, t)
    end

	-- 红黑，大小名堂
    -- 黑牌数量
    local nHeiPaiCount = 0
    -- 红牌数量
    local nHongPaiCount = 0
    -- 大牌数量
    local nDaPaiCount = 0
    -- 小牌数量
    local nXiaoPaiCount = 0
    -- 牌索引数量
    local tCardData = {}
    for i = 1, define.MAX_CARD do
        tCardData[i] = 0
    end
    local szCard = ""
    for _, tWeave in ipairs(tWeaveItemArray) do
        for _, nCardData in ipairs(tWeave.tCardData) do
            -- 牌索引数量
            tCardData[nCardData] = tCardData[nCardData] + 1
            -- 牌值
            local nCardValue = nCardData > 10 and (nCardData - 10) or nCardData
            -- 是二，七，十
            if nCardValue == 2 or nCardValue == 7 or nCardValue == 10 then
                nHongPaiCount = nHongPaiCount + 1
            else
                nHeiPaiCount = nHeiPaiCount + 1
            end

            -- 大小牌
            if nCardData > 10 then
                nDaPaiCount = nDaPaiCount + 1
            else
                nXiaoPaiCount = nXiaoPaiCount + 1
            end
            szCard = szCard..nCardData..","
        end
    end
    skynet.call("xlog", "lua", "log", "huPaiBase nRoomID="..self.nRoomID..",szCard="..szCard)
    skynet.call("xlog", "lua", "log", string.format(
        "huPaiBase nRoomID=%d,nHeiPaiCount=%d,nHongPaiCount=%d,nDaPaiCount=%d,nXiaoPaiCount=%d",
        self.nRoomID,
        nHeiPaiCount,
        nHongPaiCount,
        nDaPaiCount,
        nXiaoPaiCount))

    -- 黑胡
    if nHongPaiCount == 0 then
        local nTempBase = define.tHuPaiType["HeiHu"]
        nBase = nBase + nTempBase
        local t = {key = "HeiHu",  nValue = nTempBase}
        table.insert(r, t)
    end

    -- 十红
    if nHongPaiCount >= 10 then
        local nTempBase = define.tHuPaiType["ShiHong"] + (nHongPaiCount - 10)
        nBase = nBase + nTempBase
        local t = {key = "ShiHong",  nValue = nTempBase}
        table.insert(r, t)
    end

    -- 一点红
    if nHongPaiCount == 1 then
        local nTempBase = define.tHuPaiType["YiDianHong"]
        nBase = nBase + nTempBase
        local t = {key = "YiDianHong",  nValue = nTempBase}
        table.insert(r, t)
    end

    -- 十八大
    if nDaPaiCount >= 18 then
        local nTempBase = define.tHuPaiType["ShiBaDa"] + (nDaPaiCount - 18)
        nBase = nBase + nTempBase
        local t = {key = "ShiBaDa",  nValue = nTempBase}
        table.insert(r, t)
    end

    -- 十八小
    if nXiaoPaiCount >= 18 then
        local nTempBase = define.tHuPaiType["ShiBaXiao"] + (nXiaoPaiCount - 18)
        nBase = nBase + nTempBase
        local t = {key = "ShiBaXiao",  nValue = nTempBase}
        table.insert(r, t)
    end

    -- 二比胡，双飘胡
    if nHongPaiCount == 2 then
        -- 是一对红字
        if tCardData[2] == 2 or tCardData[7] == 2 or tCardData[10] == 2 or
           tCardData[12] == 2 or tCardData[17] == 2 or tCardData[20] == 2 then
            local nTempBase = define.tHuPaiType["ErBi"]
            nBase = nBase + nTempBase
            local t = {key = "ErBi",  nValue = nTempBase}
            table.insert(r, t)
        end

        -- 双飘胡
        local nTempBase = define.tHuPaiType["ShuangPiao"]
        nBase = nBase + nTempBase
        local t = {key = "ShuangPiao",  nValue = nTempBase}
        table.insert(r, t)
    -- 三比胡
    elseif nHongPaiCount == 3 then
        -- 是一坎红字
        if tCardData[2] == 3 or tCardData[7] == 3 or tCardData[10] == 3 or
           tCardData[12] == 3 or tCardData[17] == 3 or tCardData[20] == 3 then
            local nTempBase = define.tHuPaiType["SanBi"]
            nBase = nBase + nTempBase
            local t = {key = "SanBi",  nValue = nTempBase}
            table.insert(r, t)
        end
    -- 四比胡
    elseif nHongPaiCount == 4 then
        -- 是一条龙红字
        if tCardData[2] == 4 or tCardData[7] == 4 or tCardData[10] == 4 or
           tCardData[12] == 4 or tCardData[17] == 4 or tCardData[20] == 4 then
            local nTempBase = define.tHuPaiType["SiBi"]
            nBase = nBase + nTempBase
            local t = {key = "SiBi",  nValue = nTempBase}
            table.insert(r, t)
        end
    end

	return nBase, r
end

return M
