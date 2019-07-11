
local utils = require "utils"
local define = require "define"
local CardData = require "CardData"
local AnswerData = require "AnswerData"
local KeyData = require "KeyData"

local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)

    M.init(o, ...)
    return o
end

-- 初始化
function M:init()
    self.answerDataMax = AnswerData.new()

    -- 有分顺子
	-- 一二三	 1 2 3		二七十		 2 7 10
    self.tFenShun =
    {
        {11, 12, 13, define.HUXI_123_B},			-- 	0x11, 0x12, 0x13,
		{12, 17, 20, define.HUXI_27A_B},			-- 	0x12, 0x17, 0x1A,
		{1,  2,  3,  define.HUXI_123_S},			-- 	0x01, 0x02, 0x03,
		{2,  7,  10, define.HUXI_27A_S},			-- 	0x02, 0x07, 0x0A,
    }
end

-- 获取胡牌结果
function M:getCardHuResult(cardData, answerData, nFlag)
	if cardData.nAllCount%3 == 1 then
		return
    end

	if cardData.nAllCount == 0 then
		local nMaxValue = self.answerDataMax:getValue()
		if nMaxValue == 0 or nMaxValue < answerData:getValue() then
            self.answerDataMax.nHuXi = answerData.nHuXi
            self.answerDataMax.tKeyData = utils.copy_table(answerData.tKeyData)
        end
	elseif cardData.nAllCount == 2 then
		for i=1, define.MAX_CARD do
            local nCardCount = cardData.tCardData[i]
			if nCardCount == 2 then
				local nMaxValue = self.answerDataMax:getValue()
				if nMaxValue == 0 or nMaxValue < answerData:getValue() then
					self.answerDataMax.nHuXi = answerData.nHuXi
                    self.answerDataMax.tKeyData = utils.copy_table(answerData.tKeyData)
                    local info =
                    {
                        nHuXi = 0,
                        nType = define.ACK_NULL,
                        tCardData =
                        {
                            i,
                            i,
                        },
                    }
                    local keyData = KeyData.new(info)
					self.answerDataMax:push(keyData)
                end
			elseif nCardCount > 0 then
				break
            end
		end
	else
		local nType = math.modf(nFlag/define.MAX_ANALY_NUM)
		local nIndex = math.fmod(nFlag, define.MAX_ANALY_NUM)

		-- 碰
		if nType <= define.ANALYTYPE_PENG then
		    for n=1, define.MAX_CARD do
                local nCardCount = cardData.tCardData[n]
			    if nCardCount >= 3 then
                    local info =
                    {
                        nHuXi = n>10 and define.HUXI_PENG_B or define.HUXI_PENG_S,
                        nType = define.ACK_PENG,
                        tCardData =
                        {
                            n,
                            n,
                            n,
                        },
                    }
                    local keyData = KeyData.new(info)
				    answerData:push(keyData)
				    cardData:pop(keyData)
				    self:getCardHuResult(cardData, answerData, define.ANALYTYPE_PENG*define.MAX_ANALY_NUM + n)
				    cardData:push(keyData)
				    answerData:pop()
				    break
                end
		    end
        end

		-- 有分顺子
		if nType <= define.ANALYTYPE_FENSHUN then
			if nType < define.ANALYTYPE_FENSHUN then
                nIndex = 1
            end
			for i=nIndex, 4 do
				local nNum1 = cardData.tCardData[self.tFenShun[i][1]]
				local nNum2 = cardData.tCardData[self.tFenShun[i][2]]
				local nNum3 = cardData.tCardData[self.tFenShun[i][3]]
				if nNum1 > 0 and nNum2 > 0 and nNum3 > 0 then
                    local info =
                    {
                        nHuXi = self.tFenShun[i][4],
                        nType = define.ACK_CHI,
                        tCardData =
                        {
                            self.tFenShun[i][1],
                            self.tFenShun[i][2],
                            self.tFenShun[i][3],
                        },
                    }
                    local keyData = KeyData.new(info)
					answerData:push(keyData)
					cardData:pop(keyData)
					self:getCardHuResult(cardData, answerData, define.ANALYTYPE_FENSHUN*define.MAX_ANALY_NUM + i)
					cardData:push(keyData)
					answerData:pop()
				end
			end
		end

		local nHuVal = answerData.nHuXi
		if nHuVal < define.MIN_HU_XI or self.answerDataMax.nHuXi >= nHuVal then
			return
        end

		-- 无分顺子
		if nType <= define.ANALYTYPE_SHUN then
			if nType < define.ANALYTYPE_SHUN then
                nIndex = 1
            end

			local nCor	= math.modf((nIndex-1)/10)
			local nValue = math.fmod(nIndex, 10)
			for i=nCor, 1 do
                if i > nCor then
                    nValue = 1
                end
				for j=nValue, 8 do
					local nNum1 = cardData.tCardData[i*10 + j]
					local nNum2 = cardData.tCardData[i*10 + j + 1]
					local nNum3 = cardData.tCardData[i*10 + j + 2]
					if nNum1 > 0 and nNum2 > 0 and nNum3 > 0 then
                        local info =
                        {
                            nHuXi = 0,
                            nType = define.ACK_CHI,
                            tCardData =
                            {
                                i*10 + j,
                                i*10 + j + 1,
                                i*10 + j + 2,
                            },
                        }
                        local keyData = KeyData.new(info)
						answerData:push(keyData)
						cardData:pop(keyData)
						self:getCardHuResult(cardData, answerData, define.ANALYTYPE_SHUN*define.MAX_ANALY_NUM + i*10 + j)
						cardData:push(keyData)
						answerData:pop()
					end
				end
			end
		end

        -- 大小搭
		if nType <= define.ANALYTYPE_DXD then
			if nType < define.ANALYTYPE_DXD then
                nIndex = 1
            end

			-- 大小搭
            for i = nIndex, 10 do
				local nNum1 = cardData.tCardData[10 + i]
				local nNum2 = cardData.tCardData[i]
				if nNum1 + nNum2 == 3 then
                    local info =
                    {
                        nHuXi = 0,
                        nType = define.ACK_CHI,
                        tCardData = {},
                    }
                    for _ = 1, nNum1 do
                        table.insert(info.tCardData, 10 + i)
                    end
                    for _ = 1, nNum2 do
                        table.insert(info.tCardData, i)
                    end
                    local keyData = KeyData.new(info)
					answerData:push(keyData)
					cardData:pop(keyData)
					self:getCardHuResult(cardData, answerData, define.ANALYTYPE_DXD*define.MAX_ANALY_NUM + i)
					cardData:push(keyData)
					answerData:pop()
				elseif nNum1 == 1 or nNum2 == 1 or nNum1 + nNum2 == 4 then
					break
                end
			end
		end
	end
end

-- 初始化胡牌
function M:initCardHu(cardData, answerData, tHuCardInfo)
	-- 自己摸牌，直接插入
	if tHuCardInfo.bSelf and tHuCardInfo.nInsertCard ~= 0 then
		cardData:addVal(tHuCardInfo.nInsertCard)
    end

	-- 优先拿出4,3个的
	for i=1, define.MAX_CARD do
		if cardData.tCardData[i] == 4 then
            local info =
            {
                nHuXi = i>10 and define.HUXI_TI_B or define.HUXI_TI_S,
                nType = define.ACK_TI,
                tCardData =
                {
                    i,
                    i,
                    i,
                    i,
                },
            }
            local keyData = KeyData.new(info)
			answerData:push(keyData)
			cardData:pop(keyData)
		elseif cardData.tCardData[i] == 3 then
            local info =
            {
                nHuXi = i>10 and define.HUXI_WEI_B or define.HUXI_WEI_S,
                nType = define.ACK_WEI,
                tCardData =
                {
                    i,
                    i,
                    i,
                },
            }
            local keyData = KeyData.new(info)
			answerData:push(keyData)
			cardData:pop(keyData)
		end
	end

	-- 不是自己摸牌
	if not tHuCardInfo.bSelf and tHuCardInfo.nInsertCard ~= 0 then
		cardData:addVal(tHuCardInfo.nInsertCard)
	end
	self:getCardHuResult(cardData, answerData, 0)
    answerData.nHuXi = self.answerDataMax.nHuXi
    answerData.tKeyData = utils.copy_table(self.answerDataMax.tKeyData)

	return self.answerDataMax:getValue() > 0
end

function M:getHuCardInfo(tHuCardInfo)
	-- 初始化
	self.answerDataMax:init()

    local cardData = CardData.new(tHuCardInfo.tCardData)
    local answerData = AnswerData.new()
    -- 加上外面胡息
    answerData.nHuXi = answerData.nHuXi + tHuCardInfo.nHuXi

    local r = {}
    if self:initCardHu(cardData, answerData, tHuCardInfo) then
        for _, tKeyData in ipairs(answerData.tKeyData) do
            local tWeave =
            {
                nWeaveKind = tKeyData.nType,
                nCenterCard = tKeyData.tCardData[1],
                tCardData = utils.copy_table(tKeyData.tCardData),
            }
            table.insert(r, tWeave)
        end

        return true, r
    end

    return false, r
end

-- 打乱
function M:shuffle(tCardData)
    local _ = self
    local nCardCount = #tCardData
    for i=1, nCardCount do
        local j = math.random(i, nCardCount)
        if j > i then
            tCardData[i], tCardData[j] = tCardData[j], tCardData[i]
        end
    end
end

-- 是否有效扑克
function M:isValidCard(nCardData)
    local _ = self
    return nCardData >= 1 and nCardData <= define.MAX_CARD
end

-- 扑克数目
function M:getCardCount(tCardData)
    local _ = self
    local nCount = 0
    for _, v in pairs(tCardData) do
        nCount = nCount + v
    end
    return nCount
end

-- 检测删除扑克
function M:checkRemoveCard(tCardData, tRemoveCard)
    local _ = self
    local tTempCardData = {}
    for k, v in ipairs(tCardData) do
        tTempCardData[k] = v
    end

    local nDeleteCount = 0
    -- 置零扑克
    for _, nCardData in ipairs(tRemoveCard) do
        if tTempCardData[nCardData] > 0 then
            nDeleteCount = nDeleteCount + 1
            tTempCardData[nCardData] = tTempCardData[nCardData] - 1
        else
            return false    -- 不够直接返回false
        end
    end

    return nDeleteCount == #tRemoveCard
end

-- 删除扑克
function M:removeCard(tCardData, tRemoveCard)
    local _ = self
    for _, nCardData in ipairs(tRemoveCard) do
        if tCardData[nCardData] > 0 then
            tCardData[nCardData] = tCardData[nCardData] - 1
        end
    end
end

-- 提牌判断
function M:getAcitonTiCard(tCardData)
    local _ = self
    local r = {}
    for i=1, define.MAX_CARD do
        if tCardData[i] == 4 then
            table.insert(r, i)
        end
    end

    return r
end

-- 畏牌判断
function M:getActionWeiCard(tCardData)
    local _ = self
    local r = {}
    for i=1, define.MAX_CARD do
        if tCardData[i] == 3 then
            table.insert(r, i)
        end
    end

    return r
end

-- 吃牌判断
function M:getActionChiCard(tCardData, nCurrentCard)
    local r = {}
    -- 效验扑克
    if not self:isValidCard(nCurrentCard) then
        return r
    end

    -- 牌数判断(会加入吃的牌,所以最多3个吃)
    if tCardData[nCurrentCard] >= 3 then
        return r
    end

    --大小搭吃
    local nReverseCard = nCurrentCard > 10 and nCurrentCard - 10 or nCurrentCard + 10
    if tCardData[nCurrentCard] >= 1 and tCardData[nReverseCard] >= 1 and tCardData[nReverseCard] <= 2 then
        -- 构造扑克
        local tTempCardData = {}
        for k, v in ipairs(tCardData) do
            tTempCardData[k] = v
        end

        --删除扑克
        tTempCardData[nCurrentCard] = tTempCardData[nCurrentCard] - 1
        tTempCardData[nReverseCard] = tTempCardData[nReverseCard] - 1

        --提取判断
        local data = {}
        table.insert(data, {
            nCenterCard = nCurrentCard,
            nChiKind = nCurrentCard <= 10 and define.CK_XXD or define.CK_XDD,
            tCardData =
            {
                nCurrentCard,
                nCurrentCard,
                nReverseCard,
            },
        })

        while tTempCardData[nCurrentCard] > 0 do
            local tTakeOut = self:takeOutChiCard(tTempCardData,nCurrentCard)
            if tTakeOut.nChiKind ~= define.CK_NULL then
                table.insert(data, tTakeOut)
            else
                break
            end
        end

        if tTempCardData[nCurrentCard] == 0 then
            for _, v in pairs(data) do
                table.insert(r, v)
            end
        end
    end

    --大小搭吃
    if tCardData[nReverseCard] == 2 then
        -- 构造扑克
        local tTempCardData = {}
        for k, v in ipairs(tCardData) do
            tTempCardData[k] = v
        end

        --删除扑克
        tTempCardData[nReverseCard] = tTempCardData[nReverseCard] - 2

        --提取判断
        local data = {}
        table.insert(data, {
            nCenterCard = nCurrentCard,
            nChiKind = nCurrentCard <= 10 and define.CK_XDD or define.CK_XXD,
            tCardData =
            {
                nCurrentCard,
                nReverseCard,
                nReverseCard,
            },
        })

        while tTempCardData[nCurrentCard] > 0 do
            local tTakeOut = self:takeOutChiCard(tTempCardData,nCurrentCard)
            if tTakeOut.nChiKind ~= define.CK_NULL then
                table.insert(data, tTakeOut)
            else
                break
            end
        end

        if tTempCardData[nCurrentCard] == 0 then
            for _, v in pairs(data) do
                table.insert(r, v)
            end
        end
    end

    -- 二七十吃
    local nCardValue = nCurrentCard
    if nCardValue > 10 then
        nCardValue = nCurrentCard - 10
    end
    if nCardValue == 2 or nCardValue == 7 or nCardValue == 10 then
        --变量定义
        local tExcursion = {2,7,10}
        local nInceptIndex = 0
        if nCurrentCard > 10 then
            nInceptIndex = 10
        end

        --类型判断
        local nExcursionIndex = 1
        for i=1, #tExcursion  do
            local nIndex = nInceptIndex + tExcursion[i]
            if nIndex ~= nCurrentCard and (tCardData[nIndex] == 0 or tCardData[nIndex] >= 3) then
                break
            end
            nExcursionIndex = i
        end

        -- 提取判断
        if nExcursionIndex == #tExcursion then
            -- 构造扑克
            local tTempCardData = {}
            for k, v in ipairs(tCardData) do
                tTempCardData[k] = v
            end

            --删除扑克
            for j=1 , #tExcursion do
                local nIndex = nInceptIndex + tExcursion[j]
                if nIndex ~= nCurrentCard then
                    tTempCardData[nIndex] = tTempCardData[nIndex] - 1
                end
            end

            --提取判断
            local data = {}
            table.insert(data, {
                nCenterCard = nCurrentCard,
                nChiKind = define.CK_EQS,
                tCardData =
                {
                    nInceptIndex+tExcursion[1],
                    nInceptIndex+tExcursion[2],
                    nInceptIndex+tExcursion[3],
                },
            })

            while tTempCardData[nCurrentCard] > 0 do
                local tTakeOut = self:takeOutChiCard(tTempCardData,nCurrentCard)
                if tTakeOut.nChiKind ~= define.CK_NULL then
                    table.insert(data, tTakeOut)
                else
                    break
                end
            end

            if tTempCardData[nCurrentCard] == 0 then
                for _, v in pairs(data) do
                    table.insert(r, v)
                end
            end
        end
    end

    --顺子类型
    local tExcursion = {1,2,3}
    for i=1, #tExcursion do
        local nValueIndex = nCurrentCard
        if nCurrentCard > 10 then
            nValueIndex = nCurrentCard - 10
        end

        if nValueIndex >= tExcursion[i] and nValueIndex - tExcursion[i] <= 7 then
            --索引定义
            local nFirstIndex = nCurrentCard - tExcursion[i]
            --吃牌判断
            local nExcursionIndex = 0
            for j=1, 3 do
                local nIndex = nFirstIndex + j
                if nIndex ~= nCurrentCard and (tCardData[nIndex] == 0 or tCardData[nIndex] >= 3) then
                    break
                end
                nExcursionIndex = j
            end

            --提取判断
            if nExcursionIndex == #tExcursion then
                -- 构造扑克
                local tTempCardData = {}
                for k, v in ipairs(tCardData) do
                    tTempCardData[k] = v
                end

                --删除扑克
                for j=1, 3 do
                    local nIndex = nFirstIndex + j
                    if nIndex ~= nCurrentCard then
                        tTempCardData[nIndex] = tTempCardData[nIndex] - 1
                    end
                end

                local nChiKind ={define.CK_LEFT, define.CK_CENTER, define.CK_RIGHT}
                --提取判断
                local data = {}
                table.insert(data, {
                    nCenterCard = nCurrentCard,
                    nChiKind = nChiKind[i],
                    tCardData =
                    {
                        nFirstIndex+1,
                        nFirstIndex+2,
                        nFirstIndex+3,
                    },
                })

                while tTempCardData[nCurrentCard] > 0 do
                    local tTakeOut = self:takeOutChiCard(tTempCardData,nCurrentCard)
                    if tTakeOut.nChiKind ~= define.CK_NULL then
                        table.insert(data, tTakeOut)
                    else
                        break
                    end
                end

                if tTempCardData[nCurrentCard] == 0 then
                    for _, v in pairs(data) do
                        table.insert(r, v)
                    end
                end
            end
        end
    end

    return r
end

-- 提取吃牌
function M:takeOutChiCard(tCardData, nCurrentCard)
    local r =
    {
        nChiKind = define.CK_NULL,
        nCenterCard = nCurrentCard,
        tCardData = {},
    }
    -- 效验扑克
    if not self:isValidCard(nCurrentCard) then
        return r
    end

    -- 牌数判断(会加入吃的牌,所以最多3个吃)
    if tCardData[nCurrentCard] >= 4 then
        return r
    end

    -- 大小搭吃
    local nReverseCard = nCurrentCard > 10 and nCurrentCard - 10 or nCurrentCard + 10
    if tCardData[nCurrentCard] >= 2 and tCardData[nReverseCard] >= 1 and tCardData[nReverseCard] <= 2 then
        -- 删除扑克
        tCardData[nCurrentCard] = tCardData[nCurrentCard] - 2
        tCardData[nReverseCard] = tCardData[nReverseCard] - 1

        -- 设置结果
        r.nChiKind = nCurrentCard <= 10 and define.CK_XXD or define.CK_XDD
        r.tCardData =
        {
            nCurrentCard,
            nCurrentCard,
            nReverseCard,
        }
        return r
    end

    -- 大小搭吃
    if tCardData[nReverseCard] == 2 and tCardData[nCurrentCard] >= 1 and tCardData[nCurrentCard] <= 2 then
        --删除扑克
        tCardData[nCurrentCard] = tCardData[nCurrentCard] - 1
        tCardData[nReverseCard] = tCardData[nReverseCard] - 2

         -- 设置结果
        r.nChiKind = nCurrentCard <= 10 and define.CK_XDD or define.CK_XXD
        r.tCardData =
        {
            nCurrentCard,
            nReverseCard,
            nReverseCard,
        }
        return r
    end

    -- 二七十吃
    local nCardValue = nCurrentCard
    if nCardValue > 10 then
        nCardValue = nCurrentCard - 10
    end
    if nCardValue == 2 or nCardValue == 7 or nCardValue == 10 then
        --变量定义
        local tExcursion = {2,7,10}
        local nInceptIndex = 0
        if nCurrentCard > 10 then
            nInceptIndex = 10
        end

        --类型判断
        local nExcursionIndex = 1
        for i=1, #tExcursion  do
            local nIndex = nInceptIndex + tExcursion[i]
            if tCardData[nIndex] == 0 or (nIndex ~= nCurrentCard and tCardData[nIndex] >= 3) then
                break
            end
            nExcursionIndex = i
        end

        --成功判断
        if nExcursionIndex == #tExcursion then
            --删除扑克
            tCardData[nInceptIndex+tExcursion[1]] = tCardData[nInceptIndex+tExcursion[1]] - 1
            tCardData[nInceptIndex+tExcursion[2]] = tCardData[nInceptIndex+tExcursion[2]] - 1
            tCardData[nInceptIndex+tExcursion[3]] = tCardData[nInceptIndex+tExcursion[3]] - 1

            -- 设置结果
            r.nChiKind = define.CK_EQS
            r.tCardData =
            {
                nInceptIndex+tExcursion[1],
                nInceptIndex+tExcursion[2],
                nInceptIndex+tExcursion[3],
            }
            return r
        end
    end

    --顺子判断
    local tExcursion = {1,2,3}
    for i=1, #tExcursion do
        local nValueIndex = nCurrentCard
        if nCurrentCard > 10 then
            nValueIndex = nCurrentCard - 10
        end
        if nValueIndex >= tExcursion[i] and nValueIndex - tExcursion[i] <= 7 then
            --索引定义
            local nFirstIndex = nCurrentCard - tExcursion[i] + 1

            local bFind = true
            if tCardData[nFirstIndex] == 0 or (nFirstIndex ~= nCurrentCard and tCardData[nFirstIndex] >= 3) then
                bFind = false
            end
            if tCardData[nFirstIndex+1] == 0 or (nFirstIndex+1 ~= nCurrentCard and tCardData[nFirstIndex+1] >= 3) then
                bFind = false
            end
            if tCardData[nFirstIndex+2] == 0 or (nFirstIndex+2 ~= nCurrentCard and tCardData[nFirstIndex+2] >= 3) then
                bFind = false
            end

            if bFind then
                --删除扑克
                tCardData[nFirstIndex] = tCardData[nFirstIndex] - 1
                tCardData[nFirstIndex+1] = tCardData[nFirstIndex+1] - 1
                tCardData[nFirstIndex+2] = tCardData[nFirstIndex+2] - 1

                local nChiKind ={define.CK_LEFT, define.CK_CENTER, define.CK_RIGHT}
                -- 设置结果
                r.nChiKind = nChiKind[i]
                r.tCardData =
                {
                    nFirstIndex,
                    nFirstIndex+1,
                    nFirstIndex+2,
                }
                return r
            end
        end
    end

    return r
end

-- 是否吃牌
function M:isChiCard(tCardData, nCurrentCard)
    local r = {}
    -- 效验扑克
    if not self:isValidCard(nCurrentCard) then
        return false, r
    end

    -- 构造扑克
    local tTempCardData = {}
    for k, v in ipairs(tCardData) do
        tTempCardData[k] = v
    end

    --插入扑克
    tTempCardData[nCurrentCard] = tTempCardData[nCurrentCard] + 1

    --提取判断
    while tTempCardData[nCurrentCard] > 0 do
        local tTakeOut = self:takeOutChiCard(tTempCardData, nCurrentCard)
        if tTakeOut.nChiKind == define.CK_NULL then
            break
        end
        table.insert(r, tTakeOut.tCardData)
    end

    if tTempCardData[nCurrentCard] == 0 then
        return true, r
    end

    return false, r
end

-- 是否提跑
function M:isTiPaoCard(tCardData, nCurrentCard)
    -- 效验扑克
    if not self:isValidCard(nCurrentCard) then
        return false
    end

    if tCardData[nCurrentCard] == 3 then
        return true
    end

    return false
end

-- 是否偎碰
function M:isWeiPengCard(tCardData, nCurrentCard)
    -- 效验扑克
    if not self:isValidCard(nCurrentCard) then
        return false
    end

    --跑偎判断
    if tCardData[nCurrentCard] == 2 then
        return true
    end

    return false
end

-- 获取胡息
function M:getWeaveHuXi(tWeave)
    local _ = self
    local nWeaveKind = tWeave.nWeaveKind
    if nWeaveKind == define.ACK_TI then
        return tWeave.tCardData[1] > 10 and define.HUXI_TI_B or define.HUXI_TI_S
    elseif nWeaveKind == define.ACK_PAO then
        return tWeave.tCardData[1] > 10 and define.HUXI_PAO_B or define.HUXI_PAO_S
    elseif nWeaveKind == define.ACK_WEI then
        return tWeave.tCardData[1] > 10 and define.HUXI_WEI_B or define.HUXI_WEI_S
    elseif nWeaveKind == define.ACK_PENG then
        return tWeave.tCardData[1] > 10 and define.HUXI_PENG_B or define.HUXI_PENG_S
    elseif nWeaveKind == define.ACK_CHI then
        -- 获取数值
        local nValue1 = tWeave.tCardData[1] > 10 and tWeave.tCardData[1] - 10 or tWeave.tCardData[1]
        local nValue2 = tWeave.tCardData[2] > 10 and tWeave.tCardData[2] - 10 or tWeave.tCardData[2]
        local nValue3 = tWeave.tCardData[3] > 10 and tWeave.tCardData[3] - 10 or tWeave.tCardData[3]

        local tCardData =
        {
            [nValue1] = true,
            [nValue2] = true,
            [nValue3] = true,
        }
        -- 一二三吃
        if tCardData[1] and tCardData[2] and tCardData[3] then
            return tWeave.tCardData[1] > 10 and define.HUXI_123_B or define.HUXI_123_S
        end

        -- 二七十吃
        if tCardData[2] and tCardData[7] and tCardData[10] then
            return tWeave.tCardData[1] > 10 and define.HUXI_27A_B or define.HUXI_27A_S
        end

        return 0
    end

	return 0
end

return M
