local skynet = require "skynet"

local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)

    M.init(o, ...)
    return o
end

-- 初始化
function M:init(info, msg)
    self.userid = info.userid
    self.nickname = info.nickname
    self.sex = info.sex
    self.headimgurl = info.headimgurl
    self.score = info.score
    self.offline = 0
    self.latitude = msg.latitude or ""
    self.longitude = msg.longitude or ""
    self.adds = msg.adds or ""
end

-- 发送消息
function M:send(name, msg)
    skynet.send("dog", "lua", "send", self.userid, name, msg)
end

-- 设置位置
function M:setSeat(seat)
    self.seat = seat
end

-- 取得位置
function M:getSeat()
    return self.seat
end

-- 设置分数
function M:setScore(score)
    self.score = score
end

-- 获取分数
function M:getScore()
    return self.score
end

-- 上线
function M:online()
    self.offline_time = 0
end

-- 设置断线
function M:on_offline()
    self.offline_time = os.time()
end

-- 是否断线
function M:is_online()
    return self.offline_time ~= 0
end

-- 导出数据
function M:dump()
    return {
        userid = self.userid,
        nickname = self.nickname,
        sex = self.sex,
        headimgurl = self.headimgurl,
        score = self.score,
        ip = "127.0.0.1",
        seat = self.seat,
        offline = self:is_online(),
        latitude = self.latitude,
        longitude = self.longitude,
        adds = self.adds,
    }
end

return M
