local M = {}

-- 数值掩码
local MASK_COLOR = 0xF0         -- 花色掩码
local MASK_VALUE = 0x0F         -- 数值掩码

M.MAX_OUT_CARD      = 21        -- 最大出牌张数

M.COLOR_ERROR       = 0xF0      -- 错误花色 240
M.COLOR_CHANGEZHU   = 0x40      -- 无主 64
M.COLOR_HEI         = 0x30      -- 黑 48
M.COLOR_HONG        = 0x20      -- 红 32
M.COLOR_MEI         = 0x10      -- 梅 16
M.COLOR_FANG        = 0x00      -- 方 0

M.CT_ERROR      = 0         -- 错误牌型
M.CT_SINGLE     = 1         -- 单牌
M.CT_DUIZI      = 2         -- 对子
M.CT_TRACTOR    = 3         -- 拖拉机
M.CT_THROWN     = 4         -- 甩牌

-- // 方块  0~30
-- // 梅花  30~60
-- // 红桃  60~90
-- // 黑桃  90~120
-- // 主牌  120~
function M:init()
    self.nTLJType = 0           -- 0 默认 6688是拖拉机 常主 2 7 也有拖拉机之分 1则没有
    self.nTongSeTLJ = 6         -- 同色拖拉机
    self.nMainColor = self.COLOR_ERROR       -- 主牌颜色
    self.nSortWeight = {0, 30, 60, 90, 120}
end

-- 重置
function M:reset()
    self.nMainColor = self.COLOR_ERROR
end

function M.copy_table(t)
    if type(t) ~= "table" then
        return nil
    end

    local r = {}
    for i,v in pairs(t) do
        local v_type = type(v)
        if v_type == "table" then
            r[i] = M.copy_table(v)
        elseif v_type == "thread" then
            r[i] = v
        elseif v_type == "userdata" then
            r[i] = v
        else
            r[i] = v
        end
    end

    return r
end

-- 是否有效牌
function M:isValidCard(nCardData)
    local nColor = self:getCardColor(nCardData)
    local nValue = self:getCardValue(nCardData)
    if nColor == 78 or nValue == 79 then
        return true
    end

    if nColor <= 42 and nValue >= 1 and nValue <= 13 then
        return true
    end

    return false
end

-- 抽掉6 则是5588 拖拉机
function M:setTypeTLJ(nTLJType, bPass6) -- 0 默认 6688是拖拉机 常主 2 7 也有拖拉机之分 1则没有
    self.nTLJType = nTLJType
    self.nTongSeTLJ = bPass6 and 5 or 6
end

-- 设置最大出牌数量
function M:setMaxOutCard(nMaxOutCount)
    self.MAX_OUT_CARD = nMaxOutCount
end

-- 设置主牌
function M:setMainColor(nMainColor)
    self.nMainColor = nMainColor
end

-- 获取牌花色
function M:getCardColor(nCardData)
    local _ = self
    return nCardData & MASK_COLOR
end

-- 获取牌值
function M:getCardValue(nCardData)
    local _ = self
    return nCardData & MASK_VALUE
end

-- 转换牌花色
function M:switchToCardColor(nCardData)
    local value = self:getCardValue(nCardData)
    if nCardData == 78 or nCardData == 79 or value == 7 or value == 2 then
        return self.nMainColor
    end

    return nCardData & MASK_COLOR
end

-- /*
-- * 主牌牌值 K:13
-- * A:14
-- * 2(副):15
-- * 2(主):16
-- * 7(副):17
-- * 7(主):18
-- * 小鬼:19
-- * 大鬼:20
-- */
-- 转换牌值
function M:switchToCardValue(nCardData)
    local nColor = self:getCardColor(nCardData)
    local nValue = self:getCardValue(nCardData)

    -- 过滤掉大小鬼
    if nValue == 14 or nValue == 15 then
        return self.nSortWeight[5] + nValue + 5
    end

    -- 过滤2
    if nValue == 2 then
        if nColor == self.nMainColor then
            return self.nSortWeight[5] + 16
        end
        return self.nSortWeight[5] + 15
    end

    -- 过滤7
    if nValue == 7 then
        if nColor == self.nMainColor then
            return self.nSortWeight[5] + 18
        end
        return self.nSortWeight[5] + 17
    end

    -- A
    if nValue == 1 then
        nValue = nValue + 13
    end
    if nColor == self.nMainColor then
        return nValue + self.nSortWeight[5]
    end

    return nValue + self.nSortWeight[(nColor>>4) + 1]
end

-- 打乱
function M:shuffle(tCardData)
    local _ = self
    local nCardCount = #tCardData
    for i = 1, nCardCount do
        local j = math.random(i, nCardCount)
        if j > i then
            tCardData[i], tCardData[j] = tCardData[j], tCardData[i]
        end
    end
end

-- 检测删除扑克
function M:checkRemoveCard(tCardData, tRemoveCard)
    local _ = self
    -- 数量
    local nCardCount = #tCardData
    local nRemoveCount = #tRemoveCard
    -- 检验数据
    if nCardCount < nRemoveCount then
        return false
    end

    local tTempCardData = {}
    for index, value in pairs(tCardData) do
        tTempCardData[index] = value
    end

    local nDeleteCount = 0
    -- 置零扑克
    for _,v in ipairs(tRemoveCard) do
        for j,v1 in ipairs(tTempCardData) do
            if v == v1 then
                nDeleteCount = nDeleteCount + 1
                tTempCardData[j] = 0
                break
            end
        end
    end

    return nDeleteCount == nRemoveCount
end

-- 删除扑克
function M:removeCard(tCardData, tRemoveCard)
    local _ = self
    -- 检验数据
    if #tCardData < #tRemoveCard then
        return
    end

    local tDelete = {}
    for _,v in ipairs(tRemoveCard) do
        for j,v1 in ipairs(tCardData) do
            if v == v1 then
                tCardData[j] = 0
                table.insert(tDelete, j)
                break
            end
        end
    end

    table.sort(tDelete)
    for i=#tDelete, 1, -1 do
        table.remove(tCardData, tDelete[i])
    end
end

-- 判断两个值是否相连
function M:isNeighbor(nCardData1, nCardData2)
    local nValue1 = self:getCardValue(nCardData1)
    local nValue2 = self:getCardValue(nCardData2)
    local nColor1 = self:getCardColor(nCardData1)
    local nColor2 = self:getCardColor(nCardData2)

    if self.nTLJType == 0 then
        -- 特殊 6688相连
        if (nValue1 == self.nTongSeTLJ and nValue2 == 8 and nColor1 == nColor2)
        or (nValue1 == 8 and nValue2 == self.nTongSeTLJ and nColor1 == nColor2) then
            return true
        end
    end

    -- 无主 只有大小鬼是拖拉机
    if self.nMainColor == 64
    and self.nMainColor == self:switchToCardColor(nCardData1)
    and self.nMainColor == self:switchToCardColor(nCardData2) then
        if (nCardData1 == 78 and nCardData2 == 79)
        or (nCardData1 == 79 and nCardData2 == 78) then
            return true
        end
        return false
    end
    if self.nTLJType == 1 then
        if nValue1 == 2 or nValue1 == 7 or nValue2 == 2 or nValue2 == 7 then
            return false
        end
    end

    return math.abs(self:switchToCardValue(nCardData1) - self:switchToCardValue(nCardData2)) == 1
end

-- 是否同花色
function M:isSameColor(nCardData1, nCardData2)
    local nColor1 = self:switchToCardColor(nCardData1)
    local nColor2 = self:switchToCardColor(nCardData2)
    if nColor1 == M.COLOR_ERROR or nColor2 == M.COLOR_ERROR then
        return false
    end

    return nColor1 == nColor2
end

-- 分析牌
function M:analysisCards(tCardData)
    local nCardCount = #tCardData
    if nCardCount > self.MAX_OUT_CARD then
        return self.CT_ERROR
    end

    if nCardCount == 1 then
        return self.CT_SINGLE
    end

    local nDoubleCount = 0
    for i = 1, nCardCount - 1 do
        if not self:isSameColor(tCardData[i], tCardData[i+1]) then
            return self.CT_ERROR
        end
        if tCardData[i] == tCardData[i+1] then
            nDoubleCount = nDoubleCount + 1
        end
    end
    if nDoubleCount * 2 == nCardCount then
        if nDoubleCount == 1 then
            return self.CT_DUIZI
        end
        for i = 1, nCardCount - 2, 2 do
            if not self:isNeighbor(tCardData[i], tCardData[i+2]) then
                return self:switchToCardColor(tCardData[i]) == self.nMainColor
                        and self.CT_THROWN or self.CT_ERROR
            end
        end
        return self.CT_TRACTOR
    end

    return self:switchToCardColor(tCardData[1]) == self.nMainColor and self.CT_THROWN or self.CT_ERROR
end

function M:sortCard(tCardData)
    local nCardCount = #tCardData
    local tTempCardData = {}
    for i = 1, nCardCount do
        tTempCardData[i] = self:switchToCardValue(tCardData[i])
    end
    for i = 1, nCardCount - 1 do
        for j = i + 1, nCardCount do
            if tTempCardData[i] < tTempCardData[j]
            or (tTempCardData[i] == tTempCardData[j]
            and tCardData[i] < tCardData[j]) then
                -- 交换牌值
                local nTemp = tCardData[i]
                tCardData[i] = tCardData[j]
                tCardData[j] = nTemp

                -- 交换排序权重值
                nTemp = tTempCardData[i]
                tTempCardData[i] = tTempCardData[j]
                tTempCardData[j] = nTemp
            end
        end
    end
end

-- 返回参数牌副牌张数
function M:deputyCardCount(tCardData)
    local nCount = 0
    for i = 1, #tCardData do
        local nColor = self:switchToCardColor(tCardData[i])
        if nColor ~= self.nMainColor then
            nCount = nCount + 1
        end
    end

    return nCount
end

-- 比对牌大小(注: 必须保证card_1 card_2都是排好序的数组) return true:card_1大  false:card_2大
function M:compareCards(tCardData1, tCardData2)
    local nCardCount1 = #tCardData1
    local nCardCount2 = #tCardData2
    if nCardCount1 ~= nCardCount2 or nCardCount1 <= 0 then
        return true
    end
    self:sortCard(tCardData1, nCardCount1)
    self:sortCard(tCardData2, nCardCount2)

    local nCardType1 = self:analysisCards(tCardData1)
    if nCardType1 <= 3 then -- 单牌 对子 拖拉机
        local nCardType2 = self:analysisCards(tCardData2)
        if nCardType1 ~= nCardType2 then
            return true
        end
        local card_value_1 = self:switchToCardValue(tCardData1[1])
        local card_color_1 = self:switchToCardColor(tCardData1[1])
        local card_value_2 = self:switchToCardValue(tCardData2[1])
        local card_color_2 = self:switchToCardColor(tCardData2[1])
        if card_color_1 == card_color_2 then
            if card_value_2 > card_value_1 then
                return false
            end
        else
            if card_color_2 == self.nMainColor then
                return false
            end
        end
    end

    return true
end

-- 检查手中是否存在outcards牌
function M:checkExistCards(tHandCard, tOutCard)
    local nHandCardCount = #tHandCard
    local nOutCardCount = #tOutCard
    if nOutCardCount > nHandCardCount then
        return false
    end
    local tInitCard = {}
    for i = 1, self.MAX_OUT_CARD do
        tInitCard[i] = 0
    end
    local tTempCard = tInitCard
    for i, v in ipairs(tHandCard) do
        tTempCard[i] = v
    end

    local nCount = 0
    for i = 1, nOutCardCount do
        for j = 1, nHandCardCount do
            if tOutCard[i] == tTempCard[j] then
                nCount = nCount + 1
                tTempCard[j] = 0
                break
            end
        end
    end

    return nCount == nOutCardCount
end

-- 校验出牌是否合理(不包括首出牌) return 0:成功 非0:错误码
function M:checkOutCards(tFirstCard, tHandCard, tOutCard)
    local nOutCardCount = #tOutCard
    if nOutCardCount <= 0 then
        return -1
    end
    local nFirstCardCount = #tFirstCard
    if nFirstCardCount <= 0 then
        return 0
    end
    if nFirstCardCount ~= nOutCardCount then
        return -1
    end

    if not self:checkExistCards(tHandCard, tOutCard) then
        return -2
    end

    self:sortCard(tOutCard)
    local nFirstCardType = self:analysisCards(tFirstCard)
    local nOutCardType = self:analysisCards(tOutCard)

    local nFirstCardColor = self:switchToCardColor(tFirstCard[1])
    local nOutCardColor = self:isSameColor(tOutCard[1], tOutCard[nOutCardCount])
                            and self:switchToCardColor(tOutCard[1]) or M.COLOR_ERROR

    -- 首先过滤非甩牌但花色和牌型都相同的
    if (nFirstCardType ~= self.CT_THROWN)
    and (nFirstCardColor == nOutCardColor)
    and (nFirstCardType == nOutCardType) then
        return 0
    end

    local tInitCard = {}
    for i = 1, self.MAX_OUT_CARD do
        tInitCard[i] = 0
    end
    -- 从手牌和出牌中挑选和 first_card_color相同的牌
    local tPichHandCard = self:copy_table(tInitCard)
    local tPichOutCard = self:copy_table(tInitCard)

    local nPichHandCardCount = self:pickCardByColor(tHandCard, nFirstCardColor, tPichHandCard)
    local nPickOutCardCount = self:pickCardByColor(tOutCard, nFirstCardColor, tPichOutCard)

    --与first_card_color不同，则把该花色的牌都挑选出来比较
    if nFirstCardColor ~= nOutCardColor then
        if nPichHandCardCount == nPickOutCardCount then
            return 0
        end
        return -3
    end

    --剩下的就是花色相同，但牌型不同的情况
    if nFirstCardType == self.CT_TRACTOR then
        local tFirstTractor = self:copy_table(tInitCard)
        local nFirstTractorCount = self:pickTractor(tFirstCard, tFirstTractor)
        --拖拉机数量相同(包括0)
        local tHandDuiZi = self:copy_table(tInitCard)
        local tOutDuiZi = self:copy_table(tInitCard)
        local nHandDuiZiCount = self:pickDuizi(tPichHandCard, tHandDuiZi)
        local nOutDuiZiCount = self:pickDuizi(tPichOutCard, tOutDuiZi)
        if nHandDuiZiCount > nOutDuiZiCount then
            if nOutDuiZiCount < nFirstTractorCount then
                return -5
            end
        end
    elseif nFirstCardType == self.CT_DUIZI then
        local tHandDuiZi = self:copy_table(tInitCard)
        local tOutDuiZi = self:copy_table(tInitCard)
        local nHandDuiZiCount = self:pickDuizi(tPichHandCard, tHandDuiZi)
        local nOutDuiZiCount = self:pickDuizi(tPichOutCard, tOutDuiZi)
        if nHandDuiZiCount > nOutDuiZiCount then
            return -6
        end
    end

    return 0
end

-- 选取color色的牌 * return 牌张数
function M:pickCardByColor(tCard, nColor, tResultCard)
    local nCount = 0
    for i = 1, #tCard do
        if nColor == self:switchToCardColor(tCard[i]) then
            nCount = nCount + 1
            tResultCard[nCount] = tCard[i]
        end
    end

    return nCount
end

function M:isMainColor(nCardData)
    return self:switchToCardColor(nCardData) == self.nMainColor
end

-- /*
-- * 选取拖拉机
-- * return 几连拖
-- */
function M:pickTractor(tCardData, tCardTrator)
    local tCardDuiZi = {}
    local nDuiZiCount = self:pickDuizi(tCardData, tCardDuiZi)
    if nDuiZiCount < 2 then
        return 0
    end

    local nCount = 0
    for i = 1, nDuiZiCount-1 do
        if self:isNeighbor(tCardDuiZi[i], tCardDuiZi[i+1]) then
            if nCount <= 0 then
                nCount = nCount + 1
                tCardTrator[nCount] = tCardDuiZi[i]
            end
            nCount = nCount + 1
            tCardTrator[nCount] = tCardDuiZi[i+1]
        elseif nCount > 0 then
            break
        end
    end

    return nCount
end

-- /*
-- * 选取对子
-- * return 对子数量
-- */
function M:pickDuizi(tCardData, tCardDuiZi)
    local _ = self
    local nCardCount = #tCardData
    local nCount = 0
    for i = 1, nCardCount-1 do
        if tCardData[i] > 0 and tCardData[i] == tCardData[i+1] then
            nCount = nCount + 1
            tCardDuiZi[nCount] = tCardData[i]
        end
    end

    return nCount
end

function M:autoPichDuizi(tHandCard, card, tResultCard)
    local tInitCard = {}
    for i = 1, self.MAX_OUT_CARD do
        tInitCard[i] = 0
    end
    local nHandCardCount = #tHandCard
    local tPichHandCard = self:copy_table(tInitCard)
    local nFirstCardColor = self:switchToCardColor(card)
    self:pickCardByColor(tHandCard, nHandCardCount, nFirstCardColor, tPichHandCard)

    local pick_trator = self:copy_table(tInitCard)
    local nHandTractorCount = self:pickTractor(tPichHandCard, pick_trator)
    if nHandTractorCount > 0 then
        local nIndex = 0
        local nCount = 0
        for _, v in ipairs(pick_trator) do
            if v == card then
                nCount = nCount + 1
                if nCount >= 1 then
                    break
                end
            end
        end
        if nCount >= 1 then
            for i = 1, nHandTractorCount do
                nIndex = nIndex + 1
                tResultCard[nIndex] = pick_trator[i]
                nIndex = nIndex + 1
                tResultCard[nIndex] = pick_trator[i]
            end
            return 2*nHandTractorCount
        end
    end

    local tPickDuiZi = self:copy_table(tInitCard)
    local nHandDuiZiCount = self:pickDuizi(tPichHandCard, tPickDuiZi)
    if nHandDuiZiCount > 0 then
        for i=1,nHandDuiZiCount do
            if card == tPickDuiZi[i] then
                tResultCard[1] = tPickDuiZi[i]
                tResultCard[2] = tPickDuiZi[i]
                return 2
            end
        end
    end

    return 0
end

-- 系统自动搜索可以出的牌
function M:searchOutCards(tFirstCard, tHandCard, tResultCard)
    local nHandCardCount = #tHandCard
    if #tHandCard <= 0 then
        return
    end
    local tInitCard = {}
    for i = 1, self.MAX_OUT_CARD do
        tInitCard[i] = 0
    end

    local nFirstCardCount = #tFirstCard
    if nFirstCardCount <= 0 then
        -- 首出牌者 优先级 拖拉机》对子》单牌
        local tHandTractor = self:copy_table(tInitCard)
        local nHandTractorCount = self:pickTractor(tHandCard, tHandTractor)
        if nHandTractorCount > 0 then
            local nIndex = 0
            for i=1,nHandTractorCount do
                nIndex = nIndex + 1
                tResultCard[nIndex] = tHandTractor[i]
                nIndex = nIndex + 1
                tResultCard[nIndex] = tHandTractor[i]
            end
            return 2*nHandTractorCount
        end
        local tHandDuiZi = self:copy_table(tInitCard)
        local nHandDuiZiCount = self:pickDuizi(tHandCard, tHandDuiZi)
        if nHandDuiZiCount > 0 then
            tResultCard[1] = tHandDuiZi[1]
            tResultCard[2] = tHandDuiZi[1]
            return 2
        end
        -- 单牌 最后一张
        tResultCard[1] = tHandCard[nHandCardCount]
        return 1
    end

    -- 跟牌者
    local nFirstCardType = self:analysisCards(tFirstCard, nFirstCardCount)
    local nFirstCardColor = self:switchToCardColor(tFirstCard[1])
    local tPickHandCard = self:copy_table(tInitCard)
    local nPickHandCardCount = self:pickCardByColor(tHandCard, nFirstCardColor, tPickHandCard)
    if nPickHandCardCount <= nFirstCardCount then -- 同花色的牌数量不够 从其他花色补
        for i=1,nPickHandCardCount do
            tResultCard[i] = tPickHandCard[i]
        end
        if nFirstCardCount - nPickHandCardCount > 0 then
            local tTempCard = self:copy_table(tInitCard)
            for i,v in ipairs(tHandCard) do
                tTempCard[i] = v
            end
            for i=1,nPickHandCardCount do
                for j=1,nHandCardCount do
                    if tPickHandCard[i] == tTempCard[j] then
                        tTempCard[j] = 0
                        break
                    end
                end
            end
            local nIndex = nHandCardCount
            local nResultIndex = nFirstCardCount
            repeat
                if tTempCard[nIndex] > 0 then
                    tResultCard[nResultIndex] = tTempCard[nIndex]
                    nResultIndex = nResultIndex - 1
                    if nResultIndex <= nPickHandCardCount then
                        break
                    end
                end
                nIndex = nIndex - 1
            until false
        end
        return nFirstCardCount
    else -- 同花色的牌数量足够
        if nFirstCardType == self.CT_TRACTOR then
            local tFirstTractor = self:copy_table(tInitCard)
            local tHandTractor = self:copy_table(tInitCard)
            local nFirstTractorCount = self:pickTractor(tFirstCard, tFirstTractor)
            local nHandTractorCount = self:pickTractor(tPickHandCard, tHandTractor)
            if nHandTractorCount < nFirstTractorCount then
                local nIndex = 0
                for i = 1, nHandTractorCount do
                    nIndex = nIndex + 1
                    tResultCard[nIndex] = tHandTractor[i]
                    nIndex = nIndex + 1
                    tResultCard[nIndex] = tHandTractor[i]
                    local nCount = 0
                    for j = 1,nPickHandCardCount do
                        if tHandTractor[i] == tPickHandCard[j] then
                            tPickHandCard[j] = 0
                            nCount = nCount + 1
                            if nCount >= 2 then
                                break
                            end
                        end
                    end
                end
                -- 出拖拉机+对子/单牌
                local tPickDuiZi = self:copy_table(tInitCard)
                local nPickDuiZiCount = self:pickDuizi(tPickHandCard, tPickDuiZi)
                if nPickDuiZiCount > 0 then
                    for i = 1, nPickDuiZiCount do
                        nIndex = nIndex + 1
                        tResultCard[nIndex] = tPickDuiZi[i]
                        nIndex = nIndex + 1
                        tResultCard[nIndex] = tPickDuiZi[i]
                        if nIndex >= nFirstCardCount then
                            break
                        end
                        local nCount = 0
                        for j = 1, nPickHandCardCount do
                            if tPickDuiZi[i] == tPickHandCard[j] then
                                tPickHandCard[j] = 0
                                nCount = nCount + 1
                                if nCount >= 2 then
                                    break
                                end
                            end
                        end
                    end
                end
                --对子不够 单牌来凑
                local nCount = nPickHandCardCount
                local nResultIndex = nFirstCardCount
                while nIndex < nFirstCardCount  do
                    if tPickHandCard[nCount] > 0 then
                        tResultCard[nResultIndex] = tPickHandCard[nCount]
                        nResultIndex = nResultIndex - 1
                        nIndex = nIndex + 1
                    end
                    nCount = nCount - 1
                end
            else
                local nIndex = 0
                for i=1,nFirstTractorCount do
                    nIndex = nIndex + 1
                    tResultCard[nIndex] = tHandTractor[i]
                    nIndex = nIndex + 1
                    tResultCard[nIndex] = tHandTractor[i]
                end
            end
            return nFirstCardCount
        elseif nFirstCardType == self.CT_DUIZI then
            local tHandDuiZi = self:copy_table(tInitCard)
            local nHandDuiZiCount = self:pickDuizi(tPickHandCard, tHandDuiZi)
            if nHandDuiZiCount > 0 then
                tResultCard[1] = tHandDuiZi[1]
                tResultCard[2] = tHandDuiZi[1]
            else
                tResultCard[1] = tPickHandCard[nPickHandCardCount-1]
                tResultCard[2] = tPickHandCard[nPickHandCardCount]
            end
            return 2
        elseif nFirstCardType == self.CT_SINGLE then
            tResultCard[1] = tPickHandCard[nPickHandCardCount]
            return 1
        end
    end

    return 0
end

--简单的自动提示出牌
function M:autoTipOutCard(tFirstCard, tHandCard, tResultCard)
    if #tHandCard <= 0 then
        return
    end

    local tInitCard = {}
    for i = 1, self.MAX_OUT_CARD do
        tInitCard[i] = 0
    end

    local nFirstCardType = self:analysisCards(tFirstCard)
    local nFirstCardColor = self:switchToCardColor(tFirstCard[1])
    local tPichHandCard = self:copy_table(tInitCard)
    local nPickHandCardCount = self:pickCardByColor(tHandCard, nFirstCardColor, tPichHandCard)
    if nPickHandCardCount <= #tFirstCard then
        for i = 1, nPickHandCardCount do
            tResultCard[i] = tPichHandCard[i]
        end
        return nPickHandCardCount
    else
        if nFirstCardType == self.CT_TRACTOR then
            local tFirstTractor = self:copy_table(tInitCard)
            local tHandTractor = self:copy_table(tInitCard)
            local nFirstTractorCount = self:pickTractor(tFirstCard, tFirstTractor)
            local nHandTractorCount = self:pickTractor(tPichHandCard, tHandTractor)
            local tmpOUt = nHandTractorCount < nFirstTractorCount and nHandTractorCount or nFirstTractorCount
            local nIndex = 0
            for i = 1, tmpOUt do
                nIndex = nIndex + 1
                tResultCard[nIndex] = tHandTractor[i]
                nIndex = nIndex + 1
                tResultCard[nIndex] = tHandTractor[i]
            end
            return tmpOUt
        elseif nFirstCardType == self.CT_DUIZI then
            local tHandDuiZi = self:copy_table(tInitCard)
            local nHandDuiZiCount = self:pickDuizi(tPichHandCard, tHandDuiZi)
            if nHandDuiZiCount > 0 then
                tResultCard[1] = tHandDuiZi[1]
                tResultCard[2] = tHandDuiZi[1]
                return 2
            end
        end
    end

    return 0
end

return M
