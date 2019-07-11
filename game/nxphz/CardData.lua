local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)

    M.init(o, ...)
    return o
end

-- 初始化
function M:init(tCardData)
	self.nAllCount = 0
    self.tCardData = {}
    for nCardData, nCardCount in ipairs(tCardData) do
        if nCardData ~= 0 then
            self.tCardData[nCardData] = nCardCount
            self.nAllCount = self.nAllCount + nCardCount
        end
    end
end

-- 增加
function M:addVal(nCardData)
    if nCardData == 0 then
        return
    end

    self.tCardData[nCardData] = self.tCardData[nCardData] + 1
    self.nAllCount = self.nAllCount + 1
end

-- 压入
function M:push(keyData)
    for _, nCardData in ipairs(keyData.tCardData) do
        if nCardData ~= 0 then
            self.tCardData[nCardData] = self.tCardData[nCardData] + 1
            self.nAllCount = self.nAllCount + 1
        end
    end
end

-- 弹出
function M:pop(keyData)
    for _, nCardData in ipairs(keyData.tCardData) do
        if nCardData ~= 0 then
            self.tCardData[nCardData] = self.tCardData[nCardData] - 1
            self.nAllCount = self.nAllCount - 1
        end
    end
end

return M
