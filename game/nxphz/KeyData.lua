
local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)

    M.init(o, ...)
    return o
end

-- 初始化
function M:init(info)
    self.nHuXi = info.nHuXi
    self.nType = info.nType

    self.tCardData = {}
    for k, v in ipairs(info.tCardData) do
        self.tCardData[k] = v
    end
end

return M
