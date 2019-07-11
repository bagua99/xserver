local define = require "define"

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
    self.nHuXi = 0
    self.tKeyData = {}
end

-- 压入
function M:push(keyData)
    if #self.tKeyData > define.MAX_CARD then
        return
    end

    self.nHuXi = self.nHuXi + keyData.nHuXi
    table.insert(self.tKeyData, keyData)
end

-- 弹出
function M:pop()
    local nLen = #self.tKeyData
    if nLen <= 0 then
        return
    end

    local keyData = self.tKeyData[nLen]
    self.nHuXi = self.nHuXi - keyData.nHuXi
    table.remove(self.tKeyData, nLen)
end

function M:getValue()
    if self.nHuXi < define.MIN_HU_XI then
        return 0
    end

    return (self.nHuXi - define.MIN_HU_XI) / 3 + 1
end

return M
