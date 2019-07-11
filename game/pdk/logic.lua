local M = {}

--[[
//扑克数据
const BYTE  CGameLogic::m_cbCardData[FULL_COUNT] =
{
    0x01,     0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,       //方块 A - K
    0x11,     0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,       //梅花 A - K
    0x21,     0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,       //红桃 A - K
         0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,       //黑桃 A - K
};
--]]

local nIndexCount = 5                               -- 分析数量索引

-- 数值掩码
local MASK_COLOR = 0xF0                             -- 花色掩码
local MASK_VALUE = 0x0F                             -- 数值掩码

-- 逻辑类型
M.CT_ERROR = 0                                      -- 错误类型
M.CT_SINGLE = 1                                     -- 单牌类型
M.CT_DOUBLE = 2                                     -- 对牌类型
M.CT_THREE = 3                                      -- 三条类型
M.CT_SINGLE_LINE = 4                                -- 单连类型
M.CT_DOUBLE_LINE = 5                                -- 对连类型
M.CT_THREE_LINE = 6                                 -- 三连类型
M.CT_THREE_TAKE_ONE = 7                             -- 三带一单
M.CT_THREE_TAKE_TWO = 8                             -- 三带一对,三带2
M.CT_BOMB_CARD = 9                                  -- 炸弹类型

-- 获取数值
function M.getCardValue(nCardData)
    return nCardData & MASK_VALUE
end

-- 获取花色
function M.getCardColor(nCardData)
    return nCardData & MASK_COLOR
end

-- 逻辑数值
function M.getCardLogicValue(nCardData)
    -- 扑克属性
    local nCardColor = M.getCardColor(nCardData)
    local nCardValue = M.getCardValue(nCardData)

    if nCardValue <= 0 then
        return 0
    end

    -- 转换数值
    if nCardColor == 0x40 then
        return nCardValue + 2
    end

    if nCardValue <= 2 then
        return nCardValue + 13
    end

    return nCardValue
end

-- 打乱
function M.shuffle(tCardData)
    local nCardCount = #tCardData
    for i = 1, nCardCount do
        local j = math.random(i, nCardCount)
        if j > i then
            tCardData[i], tCardData[j] = tCardData[j], tCardData[i]
        end
    end
end

-- 排列扑克
function M.sortCard(tCardData)
    -- 数量
    local nCardCount = #tCardData

    -- 转换数值
    local tSortValue = {}
    for i=1, nCardCount do
        tSortValue[i] = M.getCardLogicValue(tCardData[i])
    end

    -- 排序操作
    local bSorted = true
    local nLast = nCardCount-1
    while (bSorted)
    do
        bSorted = false
        for i=1, nLast do
            if ((tSortValue[i]<tSortValue[i+1]) or ((tSortValue[i]==tSortValue[i+1]) and
                (tCardData[i]<tCardData[i+1]))) then
                -- 设置标志
                bSorted = true

                -- 扑克数据
                local nSwitchData = tCardData[i]
                tCardData[i] = tCardData[i+1]
                tCardData[i+1] = nSwitchData

                -- 排序权位
                nSwitchData = tSortValue[i]
                tSortValue[i] = tSortValue[i+1]
                tSortValue[i+1] = nSwitchData
            end
        end
        nLast = nLast - 1
    end
end

-- 排列扑克
function M.sortOutCardList(tCardData)
    -- 获取牌型
    local nCardType = M.getCardType(tCardData)

    if nCardType == M.CT_THREE_TAKE_ONE or nCardType == M.CT_THREE_TAKE_TWO then
        -- 分析扑克
        local tAnalyseResult = {}
        M.analysebCardData(tCardData, tAnalyseResult)

        local r = {}
        for i = #tAnalyseResult.tCardData[3], 1, -1 do
            table.insert(r, tAnalyseResult.tCardData[3][i])
        end

        for i = 4, 1, -1 do
            if i ~= 3 and tAnalyseResult.tCardData[i] then
                for _, v in ipairs(tAnalyseResult.tCardData[i]) do
                    table.insert(r, v)
                end
            end
        end

        for k, v in ipairs(r) do
            tCardData[k] = v
        end
    end
end

-- 检测删除扑克
function M.checkRemoveCard(tCardData, tRemoveCard)
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
function M.removeCard(tCardData, tRemoveCard)
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

-- 获取类型
function M.getCardType(tCardData)
    local nCardCount = #tCardData
    -- 排列扑克
    M.sortCard(tCardData)

    -- 简单牌型
    if nCardCount == 0 then
        return M.CT_ERROR
    elseif nCardCount == 1 then
        return M.CT_SINGLE
    elseif nCardCount == 2 then
        if (M.getCardLogicValue(tCardData[1]) == M.getCardLogicValue(tCardData[2])) then
            return M.CT_DOUBLE
        end

        return M.CT_ERROR
    end

    -- 分析扑克
    local tAnalyseResult = {}
    M.analysebCardData(tCardData, tAnalyseResult)

    -- 四牌判断
    if tAnalyseResult.tBlockCount[4] ~= nil and tAnalyseResult.tBlockCount[4] > 0 then
        -- 牌型判断
        if tAnalyseResult.tBlockCount[4] == 1 and nCardCount == 4 then
            return M.CT_BOMB_CARD
        end

        return M.CT_ERROR
    end

    -- 三牌判断
    if tAnalyseResult.tBlockCount[3] ~= nil and tAnalyseResult.tBlockCount[3] > 0 then

        local nMaxLineCount = 1
        local nLineCount = 1
        -- 连牌判断
        if tAnalyseResult.tBlockCount[3] > 1 then
            -- 连牌判断
            for i=1, tAnalyseResult.tBlockCount[3] do
                -- 变量定义
                local nCardData = tAnalyseResult.tCardData[3][i*3]
                local nFirstLogicValue = M.getCardLogicValue(nCardData)

                -- 错误过虑
                if nFirstLogicValue >= 15 then
                    nLineCount = 1
                else
                    local nNextIndex = i+1
                    if nNextIndex > tAnalyseResult.tBlockCount[3] then
                        break
                    end

                    nCardData = tAnalyseResult.tCardData[3][nNextIndex*3]
                    if nFirstLogicValue == M.getCardLogicValue(nCardData) + 1 then
                        nLineCount = nLineCount + 1
                        -- 设置最大
                        if nLineCount >= nMaxLineCount then
                            nMaxLineCount = nLineCount
                        end
                    else
                        nLineCount = 1
                    end
                end
            end

            if nMaxLineCount == 1 then
                return M.CT_ERROR
            end

            -- 牌形判断
            if nMaxLineCount * 3 == nCardCount then
                return M.CT_THREE_LINE
            elseif nMaxLineCount * 4 == nCardCount then
                return M.CT_THREE_TAKE_ONE
            elseif nMaxLineCount * 5 == nCardCount then
                return M.CT_THREE_TAKE_TWO
            else
                -- 比如3个777，888，999，带个单，可以当888，999带4个出，
                -- 严谨还要判断-2，-3，这种先不处理
                if (nMaxLineCount - 1) * 5 == nCardCount then
                    return M.CT_THREE_TAKE_TWO
                else
                    return M.CT_ERROR
                end
            end
        elseif nCardCount == 3 then
            return M.CT_THREE
        end

        -- 牌形判断
        if nMaxLineCount*3 == nCardCount then
            return M.CT_THREE_LINE
        elseif nMaxLineCount*4==nCardCount then
            return M.CT_THREE_TAKE_ONE
        elseif nMaxLineCount*5==nCardCount then
            return M.CT_THREE_TAKE_TWO
        end

        return M.CT_ERROR
    end

    -- 两张类型
    if tAnalyseResult.tBlockCount[2] ~= nil and tAnalyseResult.tBlockCount[2] >= 2 then
        -- 变量定义
        local nCardData = tAnalyseResult.tCardData[2][1]
        local nFirstLogicValue = M.getCardLogicValue(nCardData)

        -- 错误过虑
        if nFirstLogicValue >= 15 then
            return M.CT_ERROR
        end

        -- 连牌判断
        for i=1, tAnalyseResult.tBlockCount[2] do
            local nCardData1 = tAnalyseResult.tCardData[2][(i-1)*2+1]
            if nFirstLogicValue ~= M.getCardLogicValue(nCardData1) + (i-1) then
                return M.CT_ERROR
            end
        end

        -- 二连判断
        if tAnalyseResult.tBlockCount[2]*2 == nCardCount then
            return M.CT_DOUBLE_LINE
        end

        return M.CT_ERROR
    end

    -- 单张判断
    if tAnalyseResult.tBlockCount[1] ~= nil and tAnalyseResult.tBlockCount[1] >= 5 and
       tAnalyseResult.tBlockCount[1] == nCardCount then
        -- 变量定义
        local nCardData = tAnalyseResult.tCardData[1][1]
        local nFirstLogicValue = M.getCardLogicValue(nCardData)

        -- 错误过虑
        if nFirstLogicValue >= 15 then
            return M.CT_ERROR
        end

        -- 连牌判断
        for i=1, tAnalyseResult.tBlockCount[1] do
            local nCardData1 = tAnalyseResult.tCardData[1][i]
            if nFirstLogicValue ~= M.getCardLogicValue(nCardData1) + (i-1) then
                return M.CT_ERROR
            end
        end

        return M.CT_SINGLE_LINE
    end

    return M.CT_ERROR
end

-- 分析扑克
function M.analysebCardData(tCardData, tAnalyseResult)
    -- 数量
    local nCardCount = #tCardData
    -- 扑克分析
    local nCardCountIndex = 1
    for _=1, nCardCount do

        if nCardCountIndex > nCardCount then
            break
        end
        -- 变量定义
        local nSameCount = 1
        local nLogicValue = M.getCardLogicValue(tCardData[nCardCountIndex])

        -- 搜索同牌
        for j=nCardCountIndex+1, nCardCount do
            -- 获取扑克
            if M.getCardLogicValue(tCardData[j]) ~= nLogicValue then
                break
            end

            -- 设置变量
            nSameCount = nSameCount + 1
        end

        -- 设置结果
        if tAnalyseResult.tBlockCount == nil then
            tAnalyseResult.tBlockCount = {}
        end
        if tAnalyseResult.tCardData == nil then
            tAnalyseResult.tCardData = {}
        end
        if tAnalyseResult.tCardData[nSameCount] == nil then
            tAnalyseResult.tCardData[nSameCount] = {}
        end
        if tAnalyseResult.tBlockCount[nSameCount] == nil then
            tAnalyseResult.tBlockCount[nSameCount] = 1
        else
            tAnalyseResult.tBlockCount[nSameCount] = tAnalyseResult.tBlockCount[nSameCount] + 1
        end
        local nIndex = tAnalyseResult.tBlockCount[nSameCount] - 1
        for j=1, nSameCount do
            tAnalyseResult.tCardData[nSameCount][nIndex*nSameCount+j] = tCardData[nCardCountIndex+j-1]
        end

        -- 设置索引
        nCardCountIndex = nCardCountIndex + nSameCount
    end
end

-- 对比扑克
function M.compareCard(tFirstCard, tNextCard)
    local nFirstCount = #tFirstCard
    local nNextCount = #tNextCard
    -- 获取类型
    local nNextType = M.getCardType(tNextCard)
    local nFirstType = M.getCardType(tFirstCard)

    -- 类型判断
    if nNextType == M.CT_ERROR then
        return false
    end

    -- 炸弹判断
    if nFirstType ~= M.CT_BOMB_CARD and nNextType == M.CT_BOMB_CARD then
        return true
    end
    if nFirstType == M.CT_BOMB_CARD and nNextType ~= M.CT_BOMB_CARD then
        return false
    end

    -- 规则判断
    if nFirstType ~= nNextType or nFirstCount ~= nNextCount then
        return false
    end

    local compare1 = (function(tCard1, tCard2)
        -- 获取数值
        local nFirstLogicValue = M.getCardLogicValue(tCard1[1])
        local nNextLogicValue = M.getCardLogicValue(tCard2[1])

        -- 对比扑克
        return nFirstLogicValue < nNextLogicValue
    end)

    local compare2 = (function(tCard1, tCard2)
        -- 分析扑克
        local tFirstResult = {}
        local tNextResult = {}
        M.analysebCardData(tCard1, tFirstResult)
        M.analysebCardData(tCard2, tNextResult)

        if tFirstResult.tCardData[3][1] == nil or tNextResult.tCardData[3][1] == nil then
            return false
        end

        -- 获取数值
        local nFirstLogicValue = M.getCardLogicValue(tFirstResult.tCardData[3][1])
        local nNextLogicValue = M.getCardLogicValue(tNextResult.tCardData[3][1])

        -- 对比扑克
        return nFirstLogicValue < nNextLogicValue
    end)

    local compareWwitch =
    {
        [M.CT_SINGLE]             = compare1,
        [M.CT_DOUBLE]             = compare1,
        [M.CT_THREE]              = compare1,
        [M.CT_SINGLE_LINE]        = compare1,
        [M.CT_DOUBLE_LINE]        = compare1,
        [M.CT_THREE_LINE]         = compare1,
        [M.CT_BOMB_CARD]          = compare1,
        [M.CT_THREE_TAKE_ONE]     = compare2,
        [M.CT_THREE_TAKE_TWO]     = compare2,
    }
    local func = compareWwitch[nNextType]
    if func ~= nil then
        local nResult = func(tFirstCard, tNextCard)
        return nResult
    end

    return false
end

-- 构造扑克
function M.makeCardData(nValueIndex, nColorIndex)
    return nColorIndex << 4 + nValueIndex
end

-- 分析分布
function M.analysebDistributing(tCardData, t)
    local nCardCount = #tCardData
    -- 设置变量
    for i=1, nCardCount do
        if tCardData[i] ~= 0 then
            -- 获取属性
            local nCardColor = M.getCardColor(tCardData[i])
            local nCardValue = M.getCardValue(tCardData[i])

            if t.nCardCount == nil then
                t.nCardCount = 0
            end
            -- 分布信息
            t.nCardCount = t.nCardCount + 1;

            if t.tDistributing == nil then
                t.tDistributing = {}
            end
            if t.tDistributing[nCardValue] == nil then
                t.tDistributing[nCardValue] = {}
            end
            if t.tDistributing[nCardValue][nIndexCount] == nil then
                t.tDistributing[nCardValue][nIndexCount] = 0
            end
            t.tDistributing[nCardValue][nIndexCount] = t.tDistributing[nCardValue][nIndexCount] + 1
            -- 从1开始
            local nColorIndex = nCardColor >> 4 + 1
            --local nColorIndex = bit.rshift(nCardColor,4) + 1
            if t.tDistributing[nCardValue][nColorIndex] == nil then
                t.tDistributing[nCardValue][nColorIndex] = 0
            end
            t.tDistributing[nCardValue][nColorIndex] = t.tDistributing[nCardValue][nColorIndex] + 1
        end
    end
end

-- 出牌搜索
function M.searchOutCard(tCardData, tTurnCardData, tResult)
    local nCardCount = #tCardData
    local nTurnCardCount = #tTurnCardData
    -- 变量定义
    local nResultCount = 0
    -- 临时结果数组
    local tTempSearchCardResult = {}

    -- 排列扑克
    M.sortCard(tCardData)
    -- 排列扑克
    M.sortCard(tTurnCardData)

    -- 获取类型
    local nTurnOutType = M.getCardType(tTurnCardData)

    -- 出牌分析
    -- 错误类型
    if nTurnOutType == M.CT_ERROR then

        -- 是否一手出完
        if M.getCardType(tCardData) ~= M.CT_ERROR then

            nResultCount = nResultCount + 1

            if tResult.tCardCount == nil then
                tResult.tCardCount = {}
            end
            tResult.tCardCount[nResultCount] = nCardCount

            if tResult.tResultCard == nil then
                tResult.tResultCard = {}
            end
            for i=1, nCardCount do
                tResult.tResultCard[i] = tCardData[i]
            end
        end

        tResult.nSearchCount = nResultCount
        return nResultCount
    -- 单牌类型,对牌类型,三条类型
    elseif nTurnOutType == M.CT_SINGLE or nTurnOutType == M.CT_DOUBLE or nTurnOutType == M.CT_THREE then

        -- 变量定义
        local nReferCard = tTurnCardData[1]
        local nSameCount = 1
        if nTurnOutType == M.CT_DOUBLE then
            nSameCount = 2
        elseif nTurnOutType == M.CT_THREE then
            nSameCount = 3
        end

        -- 搜索相同牌
        nResultCount = M.searchSameCard(tCardData, nReferCard, nSameCount, tResult)
    -- 单连类型,对连类型,三连类型
    elseif nTurnOutType == M.CT_SINGLE_LINE or nTurnOutType == M.CT_DOUBLE_LINE or nTurnOutType == M.CT_THREE_LINE then

        -- 变量定义
        local nBlockCount = 1
        if nTurnOutType == M.CT_DOUBLE_LINE then
            nBlockCount = 2
        elseif nTurnOutType == M.CT_THREE_LINE then
            nBlockCount = 3
        end

        local nLineCount = nTurnCardCount/nBlockCount
        -- 搜索边牌
        nResultCount = M.searchLineCardType(tCardData, tTurnCardData[1], nBlockCount, nLineCount, tResult)
    -- 三带一单,三带一对
    elseif nTurnOutType == M.CT_THREE_TAKE_ONE or nTurnOutType == M.CT_THREE_TAKE_TWO then

        if nCardCount >= nTurnCardCount then
            -- 如果是三带一或三带二
            if nTurnCardCount == 4 or nTurnCardCount == 5 then
                local nTakeCardCount = (nTurnOutType == M.CT_THREE_TAKE_ONE) and 1 or 2
                -- 搜索三带牌型
                nResultCount = M.searchTakeCardType(tCardData, tTurnCardData[3], 3, nTakeCardCount, tResult)
            else
                -- 变量定义
                local nLineCount = nTurnCardCount / ((nTurnOutType == M.CT_THREE_TAKE_ONE) and 4 or 5)
                local nTakeCardCount = nTurnOutType == M.CT_THREE_TAKE_ONE and 1 or 2

                local tTempTurnCardData = {}
                for k, v in ipairs(tTurnCardData) do
                    tTempTurnCardData[k] = v
                end
                M.sortOutCardList(tTempTurnCardData)
                -- 搜索连牌
                nResultCount = M.searchLineCardType(tCardData, tTempTurnCardData[1], 3, nLineCount, tResult)

                -- 提取带牌
                local bAllDistill = true
                for i=1, nResultCount do
                    local nResultIndex = nResultCount - i + 1

                    -- 变量定义
                    local tTempCardData = {}
                    for index, value in ipairs(tCardData) do
                        tTempCardData[index] = value
                    end

                    -- 删除连牌
                    M.removeCard(tTempCardData, tResult.tResultCard[nResultIndex])

                    -- 分析牌
                    local tTempResult = {}
                    M.analysebCardData(tTempCardData, tTempResult)

                    -- 提取牌
                    local tDistillCard = {}
                    local nDistillCount = 0
                    for j = 1, 4 do
                        if tTempResult.tBlockCount[j] ~= nil then
                            for k=1, tTempResult.tBlockCount[j] do
                                -- 从小到大
                                local nIndex = (tTempResult.tBlockCount[j] - k)*j

                                -- 这里j==1是单牌,j==2是对,j==3是3个,j==4是4个
                                if nDistillCount + j <= nTakeCardCount*nLineCount then
                                    for n=1, j do
                                        nDistillCount = nDistillCount + 1
                                        tDistillCard[nDistillCount] = tTempResult.tCardData[j][nIndex + n]
                                    end
                                else
                                    local nMustCount = nTakeCardCount*nLineCount - nDistillCount
                                    for n=1, nMustCount do
                                        nDistillCount = nDistillCount + 1
                                        tDistillCard[nDistillCount] = tTempResult.tCardData[j][nIndex + n]
                                    end
                                end

                                -- 提取完成
                                if nDistillCount == nTakeCardCount*nLineCount then
                                    break
                                end
                            end

                            -- 提取完成
                            if nDistillCount == nTakeCardCount*nLineCount then
                                break
                            end
                        end
                    end

                    -- 提取完成
                    if nDistillCount == nTakeCardCount*nLineCount then
                        -- 复制带牌
                        local nCount = tResult.tCardCount[nResultIndex]
                        for n=1,nDistillCount do
                            tResult.tResultCard[nResultIndex][nCount+n] = tDistillCard[n]
                        end
                        tResult.tCardCount[nResultIndex] = tResult.tCardCount[nResultIndex] + nDistillCount
                    -- 否则删除连牌
                    else
                        bAllDistill = false
                        tResult.tCardCount[nResultIndex] = 0
                    end
                end

                -- 整理组合
                if not bAllDistill then
                    tResult.nSearchCount = nResultCount
                    nResultCount = 0
                    for i=1, tResult.nSearchCount do
                        if tResult.tCardCount[i] ~= 0 then
                            nResultCount = nResultCount + 1
                            tTempSearchCardResult.tCardCount[nResultCount] = tResult.tCardCount[i]
                            tTempSearchCardResult.tResultCard[nResultCount] = tResult.tResultCard[i]
                        end
                    end
                    tTempSearchCardResult.nSearchCount = nResultCount
                    tResult = tTempSearchCardResult
                end
            end
        end
    end

    -- 搜索炸弹
    if nCardCount >= 4 then
        -- 变量定义
        local nReferCard = 0
        if nTurnOutType == M.CT_BOMB_CARD then
            nReferCard = tTurnCardData[1]
        end

        -- 搜索炸弹
        local nTempResultCount = M.searchSameCard(tCardData, nReferCard, 4, tTempSearchCardResult)
        for i=1, nTempResultCount do
            nResultCount = nResultCount + 1
            if tResult.tCardCount == nil then
                tResult.tCardCount = {}
            end
            if tResult.tResultCard == nil then
                tResult.tResultCard = {}
            end
            tResult.tCardCount[nResultCount] = tTempSearchCardResult.tCardCount[i];
            tResult.tResultCard[nResultCount] = tTempSearchCardResult.tResultCard[i]
        end
    end

    tResult.nSearchCount = nResultCount
    return nResultCount
end

-- 同牌搜索
function M.searchSameCard(tHandCardData, nReferCard, nSameCardCount, tResult)
    -- 设置结果
    local nResultCount = 0

    -- 构造扑克
    local tCardData = tHandCardData

    -- 排列扑克
    M.sortCard(tCardData)

    -- 分析扑克
    local tAnalyseResult = {}
    M.analysebCardData(tCardData, tAnalyseResult)

    local nReferLogicValue = (nReferCard == 0) and 0 or M.getCardLogicValue(nReferCard)
    for nBlockIndex = nSameCardCount, 4 do
        if tAnalyseResult.tBlockCount ~= nil and tAnalyseResult.tBlockCount[nBlockIndex] ~= nil then
            for i=1, tAnalyseResult.tBlockCount[nBlockIndex] do

                local nIndex = (tAnalyseResult.tBlockCount[nBlockIndex] - i)*nBlockIndex
                if M.getCardLogicValue(tAnalyseResult.tCardData[nBlockIndex][nIndex+1]) > nReferLogicValue then
                    -- 复制扑克
                    nResultCount = nResultCount + 1

                    if tResult.tResultCard == nil then
                        tResult.tResultCard = {}
                    end
                    if tResult.tCardCount == nil then
                        tResult.tCardCount = {}
                    end
                    if tResult.tResultCard[nResultCount] == nil then
                        tResult.tResultCard[nResultCount] = {}
                    end
                    for n=1, nSameCardCount do
                        tResult.tResultCard[nResultCount][n] = tAnalyseResult.tCardData[nBlockIndex][nIndex+n]
                    end
                    tResult.tCardCount[nResultCount] = nSameCardCount
                end
            end
        end
    end

    tResult.nSearchCount = nResultCount
    return nResultCount
end

-- 带牌类型搜索(三带一，四带一等)
function M.searchTakeCardType(tHandCardData, nReferCard, nSameCardCount, nTakeCardCount, tResult)
    local nHandCardCount = #tHandCardData
    -- 设置结果
    local nResultCount = 0

    -- 效验
    if nSameCardCount ~= 3 and nSameCardCount ~= 4 then
        return nResultCount
    end
    if nTakeCardCount ~= 1 and nTakeCardCount ~= 2 then
        return nResultCount
    end

    -- 长度判断
    if (nSameCardCount == 4 and nHandCardCount < nSameCardCount + nTakeCardCount*2) or
        nHandCardCount < nSameCardCount + nTakeCardCount then
        return nResultCount
    end

    -- 构造扑克
    local tCardData = tHandCardData

    -- 排列扑克
    M.sortCard(tCardData)

    -- 搜索同张
    local tSameCardResult = {}
    local nSameCardResultCount = M.searchSameCard(tCardData, nReferCard, nSameCardCount, tSameCardResult)

    if nSameCardResultCount > 0 then
        -- 分析扑克
        local tAnalyseResult = {}
        M.analysebCardData(tCardData, tAnalyseResult)
        -- 需要牌数
        local nNeedCount = nSameCardCount + nTakeCardCount;
        if nSameCardCount == 4 then
            nNeedCount = nNeedCount + nTakeCardCount
        end

        -- 提取带牌
        for i=1, nSameCardResultCount do
            local bMerge = false
            for j=1, 4 do
                if tAnalyseResult.tBlockCount[j] ~= nil then
                    for k=1, tAnalyseResult.tBlockCount[j] do
                        -- 从小到大
                        local nIndex = (tAnalyseResult.tBlockCount[j] - k)*j
                        -- 过滤相同牌
                        local nCard1 = M.getCardValue(tSameCardResult.tResultCard[i][1])
                        local nCard2 = M.getCardValue(tAnalyseResult.tCardData[j][nIndex+1])
                        if nCard1 ~= nCard2 then
                            -- 复制带牌
                            local nCount = tSameCardResult.tCardCount[i]
                            --  这里j==1是单牌,j==2是对,j==3是3个,j==4是4个
                            if nCount + j <= nNeedCount then
                                for n=1,j  do
                                    tSameCardResult.tResultCard[i][nCount+n] = tAnalyseResult.tCardData[j][nIndex+n]
                                end
                                tSameCardResult.tCardCount[i] = tSameCardResult.tCardCount[i] + j;
                            else
                                local nMustCount = nNeedCount - nCount;
                                for n=1,nMustCount  do
                                    tSameCardResult.tResultCard[i][nCount+n] = tAnalyseResult.tCardData[j][nIndex+n]
                                end
                                tSameCardResult.tCardCount[i] = tSameCardResult.tCardCount[i] + nMustCount
                            end

                            if tSameCardResult.tCardCount[i] >= nNeedCount then

                                nResultCount = nResultCount + 1

                                if tResult.tResultCard == nil then
                                    tResult.tResultCard = {}
                                end
                                if tResult.tCardCount == nil then
                                    tResult.tCardCount = {}
                                end
                                tResult.tResultCard[nResultCount] = tSameCardResult.tResultCard[i]
                                tResult.tCardCount[nResultCount] = tSameCardResult.tCardCount[i]

                                bMerge = true
                                break;
                            end
                        end
                    end

                    if bMerge then
                        break
                    end
                end
            end
        end
    end

    tResult.nSearchCount = nResultCount
    return nResultCount
end

-- 连牌搜索
function M.searchLineCardType(tHandCardData, nReferCard, nBlockCount, nLineCount, tResult)
    local nHandCardCount = #tHandCardData
    -- 设置结果
    local nResultCount = 0

    -- 定义变量
    local nLessLineCount
    if nLineCount == 0 then
        if nBlockCount == 1 then
            nLessLineCount = 5
        else
            nLessLineCount = 2
        end
    else
        nLessLineCount = nLineCount
    end

    local nReferIndex = 2
    if nReferCard ~= 0 then
        nReferIndex = M.getCardLogicValue(nReferCard) - nLessLineCount + 2
    end
    -- 超过A
    if nReferIndex + nLessLineCount > 15 then
        return nResultCount
    end

    -- 长度判断
    if nHandCardCount < nLessLineCount*nBlockCount then
        return nResultCount
    end

    -- 构造扑克
    local tCardData = tHandCardData

    -- 排列扑克
    M.sortCard(tCardData)

    -- 分析扑克
    local t = {}
    M.analysebDistributing(tCardData, t)

    -- 搜索顺子
    local nTempLinkCount = 0
    -- 这里有个坑nValueIndex是属于for里面的变量,所有nLastValueIndex要重新赋值
    local nLastValueIndex = nReferIndex
    for nValueIndex=nReferIndex,13 do
        nLastValueIndex = nValueIndex
        local bContinue = true
        if t.tDistributing[nValueIndex] == nil then
            nTempLinkCount = 0
        elseif t.tDistributing[nValueIndex][nIndexCount] ~= nil then
            -- 继续判断
            if t.tDistributing[nValueIndex][nIndexCount] < nBlockCount then
                if nTempLinkCount < nLessLineCount then
                    nTempLinkCount = 0
                    bContinue = false
                else
                    nValueIndex = nValueIndex - 1
                end
            else
                nTempLinkCount = nTempLinkCount + 1
                -- 寻找最长连
                if nLineCount == 0 then
                    bContinue = false
                end
            end

            if bContinue then
                if nTempLinkCount >= nLessLineCount then
                    nResultCount = nResultCount + 1
                    -- 复制扑克
                    local nCount = 0
                    for nIndex = nValueIndex+1-nTempLinkCount, nValueIndex do
                        local nTmpCount = 0
                        for nColorIndex=1, 4 do
                            if t.tDistributing[nIndex][nColorIndex] ~= nil then
                                for _=1, t.tDistributing[nIndex][nColorIndex] do
                                    nCount = nCount + 1
                                    if tResult.tResultCard == nil then
                                        tResult.tResultCard = {}
                                    end
                                    if tResult.tResultCard[nResultCount] == nil then
                                        tResult.tResultCard[nResultCount] = {}
                                    end
                                    local nCardData = M.makeCardData(nIndex, nColorIndex-1)
                                    tResult.tResultCard[nResultCount][nCount] = nCardData
                                    nTmpCount = nTmpCount + 1
                                    if nTmpCount == nBlockCount then
                                        break
                                    end
                                end
                                if nTmpCount == nBlockCount then
                                    break
                                end
                            end
                        end
                    end

                    if tResult.tCardCount == nil then
                        tResult.tCardCount = {}
                    end
                    -- 设置变量
                    tResult.tCardCount[nResultCount] = nCount

                    if nLineCount ~= 0 then
                        nTempLinkCount = nTempLinkCount - 1
                    else
                        nTempLinkCount = 0
                    end
                end
            end
        end
    end

    -- 特殊顺子
    if nTempLinkCount >= nLessLineCount-1 and nLastValueIndex == 13 then
        if (t.tDistributing[1] ~= nil and t.tDistributing[1][nIndexCount] >= nBlockCount)
        or nTempLinkCount >= nLessLineCount then
            nResultCount = nResultCount + 1
            if tResult.tResultCard == nil then
                tResult.tResultCard = {}
            end
            if tResult.tResultCard[nResultCount] == nil then
                tResult.tResultCard[nResultCount] = {}
            end

            -- 复制扑克
            local nCount = 0
            for nIndex=nLastValueIndex-nTempLinkCount+1, 13 do
                local nTmpCount = 0
                for nColorIndex=1, 4 do
                    if t.tDistributing[nIndex][nColorIndex] ~= nil then
                        for _=1, t.tDistributing[nIndex][nColorIndex] do
                            nCount = nCount + 1
                            tResult.tResultCard[nResultCount][nCount] = M.makeCardData(nIndex, nColorIndex-1)
                            nTmpCount = nTmpCount + 1
                            if nTmpCount == nBlockCount then
                                break
                            end
                        end
                        if nTmpCount == nBlockCount then
                            break
                        end
                    end
                end
            end
            -- 复制A
            if t.tDistributing[1][nIndexCount] >= nBlockCount then
                local nTmpCount = 0
                for nColorIndex=1, 4 do
                    if t.tDistributing[1][nColorIndex] ~= nil then
                        for _=1, t.tDistributing[1][nColorIndex] do
                            nCount = nCount + 1
                            tResult.tResultCard[nResultCount][nCount] = M.makeCardData(1, nColorIndex-1)
                            nTmpCount = nTmpCount + 1
                            if nTmpCount == nBlockCount then
                                break
                            end
                        end
                        if nTmpCount == nBlockCount then
                            break
                        end
                    end
                end
            end

            if tResult.tCardCount == nil then
                tResult.tCardCount = {}
            end
            tResult.tCardCount[nResultCount] = nCount
        end
    end

    tResult.nSearchCount = nResultCount
    return nResultCount
end

return M
