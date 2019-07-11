--[[
//扑克数据
const BYTE  CGameLogic::m_cbCardData[FULL_COUNT] =
{
    0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,       //方块 A - K
    0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,       //梅花 A - K
    0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,       //红桃 A - K
    0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,       //黑桃 A - K
}
--]]

-- 扑克类型
local OX_VALUE0 = 0                                         -- 混合牌型
local OX_FOUR_HUA = 11                                      -- 四花牛牛牌型
local OX_FIVE_HUA = 12                                      -- 五花牛牛牌型

-- 数值掩码
local MASK_COLOR = 0xF0                                     -- 花色掩码
local MASK_VALUE = 0x0F                                     -- 数值掩码

local MAX_COUNT = 5                                         -- 牌数量

local M = {}

function M.shuffle(hua)
    local t
    if hua then
        t = {
            0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,  --方块 A - 10
            0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,  --梅花 A - 10
            0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,  --红桃 A - 10
            0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A   --黑桃 A - 10
        }
    else
        t = {
            0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,   --方块 A - K
            0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,   --梅花 A - K
            0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,   --红桃 A - K
            0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D    --黑桃 A - K
        }
    end

    local len = #t
    for i=1,len-1 do
        local idx = math.random(i, len)
        if idx ~= i then
            local tmp = t[i]
            t[i] = t[idx]
            t[idx] = tmp
        end
    end

    return t
end

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
    local nCardValue = M.getCardValue(nCardData)
    -- 转换数值
    return nCardValue > 10 and 10 or nCardValue
end

-- 排列扑克
function M.sortCardList(tCardData)
    local function cmp(card1, card2)
        local v1 = M.getCardValue(card1)
        local v2 = M.getCardValue(card2)
        if v1 ~= v2 then
            return v1 > v2
        end
        local c1 = M.getCardColor(card1)
        local c2 = M.getCardColor(card2)
        return c1 > c2
    end
    table.sort(tCardData, cmp)
end

-- 删除扑克
function M.removeCard(tCardData, tRemoveCard)
    local idxs = {}
    for _,v in ipairs(tRemoveCard) do
        for i,v1 in ipairs(tCardData) do
            if v1 == v then
                tCardData[i] = 0
                table.insert(idxs, i)
                break
            end
        end
    end

    table.sort(idxs)
    for i=#idxs, 1, -1 do
        table.remove(tCardData, idxs[i])
    end
end

-- 获取类型
function M.getCardType(tCardData)
    local nKingCount = 0
    local nTenCount = 0
    for _,card in ipairs(tCardData) do
        local v = M.getCardValue(card)
        if v > 10 then
            nKingCount = nKingCount + 1
        elseif v == 10 then
            nTenCount = nTenCount + 1
        end
    end

    if nKingCount == MAX_COUNT then
        return OX_FIVE_HUA
    elseif nKingCount == MAX_COUNT - 1 and nTenCount == 1 then
        return OX_FOUR_HUA
    end

    local tTemp = {}
    local nSum = 0
    for _,card in ipairs(tCardData) do
        local v = M.getCardLogicValue(card)
        table.insert(tTemp, v)
        nSum = nSum + v
    end

    local num = #tCardData
    for i=1, num-1 do
        for j=i+1, num do
            if (nSum - tTemp[i] - tTemp[j]) % 10 == 0 then
                return ((tTemp[i] + tTemp[j]) > 10) and (tTemp[i] + tTemp[j] - 10) or (tTemp[i] + tTemp[j])
            end
        end
    end

    return OX_VALUE0
end

-- 获取牌倍率
function M.getCardBase(tCardData)
    local nCardType = M.getCardType(tCardData)
    if nCardType < 7 then
        return 1
    elseif nCardType >= 7 and nCardType <= 9 then
        return 2
    elseif nCardType == 10 then
        return 3
    elseif nCardType == OX_FOUR_HUA then
        return 3
    elseif nCardType == OX_FIVE_HUA then
        return 3
    end

    return 0
end

-- 获取牛牛
function M.getOxCard(tCardData)
    local nCardCount = #tCardData
    local tTemp = {}
    local nSum = 0
    for i=1, nCardCount do
        tTemp[i] = M.getCardLogicValue(tCardData[i])
        nSum = nSum + tTemp[i]
    end

    -- 查找牛牛
    for i=1, nCardCount do
        for j=i+1, nCardCount do
            if (nSum - tTemp[i] - tTemp[j]) % 10 == 0 then
                local t = {}
                for k=1, nCardCount do
                    if k ~= i and k ~= j then
                        table.insert(t, tCardData[k])
                    end
                end
                table.insert(t,tCardData[i])
                table.insert(t,tCardData[j])
                for k,v in ipairs(t) do
                    tCardData[k] = v
                end
                return true
            end
        end
    end

    return false
end

-- 对比扑克
function M.compareCard(tFirstCardData, tNextCardData, bFirstOX)
    if bFirstOX then
        -- 获取点数
        local nNextType = M.getCardType(tNextCardData)
        local nFirstType = M.getCardType(tFirstCardData)

        -- 点数判断
        if nFirstType ~= nNextType then
            return nFirstType > nNextType
        end
    end

    -- 排序大小
    local tFirstTemp = tFirstCardData
    local tNextTemp = tNextCardData
    M.sortCardList(tFirstTemp)
    M.sortCardList(tNextTemp)

    -- 比较数值
    local nNextMaxValue = M.getCardValue(tNextTemp[1])
    local nFirstMaxValue = M.getCardValue(tFirstTemp[1])
    if nNextMaxValue ~= nFirstMaxValue then
        return nFirstMaxValue > nNextMaxValue
    end

    -- 比较颜色
    return M.getCardColor(tFirstTemp[1]) > M.getCardColor(tNextTemp[1])
end

return M
