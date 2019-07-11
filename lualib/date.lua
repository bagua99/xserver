local SECONDS_OF_HOUR = 3600
local SECONDS_OF_DAY = 3600 * 24
local WEEK_OFFSET = 3600 * 24 * 4  --(1970年,星期4)
local SECONDS_OF_WEEK = 3600 * 24 * 7
local TIME_ZONE = 8

local M = {}

function M.get_time_zone_seconds(time_zone)
    if time_zone then
        return time_zone * SECONDS_OF_HOUR
    end

    return TIME_ZONE * SECONDS_OF_HOUR
end

-- 检查两个时间是否是同一天
function M.is_same_day(t1, t2, time_zone)
    local offset_seconds = M.get_time_zone_seconds(time_zone)

    local day_num1 = math.floor((t1 - offset_seconds) / SECONDS_OF_DAY)
    local day_num2 = math.floor((t2 - offset_seconds) / SECONDS_OF_DAY)

    return day_num1 == day_num2
end

-- 获取本周开始的时间，第一天按
function M.get_begin_of_week(t)
    local offset_seconds = M.get_time_zone_seconds(time_zone)
    t = t + offset_seconds
    t = math.floor((t - WEEK_OFFSET)/SECONDS_OF_WEEK)*SECONDS_OF_WEEK + WEEK_OFFSET

    return t
end

-- 检查两个时间是否是同一个星期
function M.is_same_week(t1, t2, time_zone)
    local offset_seconds = M.get_time_zone_seconds(time_zone)
    t1 = t1 + offset_seconds - WEEK_OFFSET
    t2 = t2 + offset_seconds - WEEK_OFFSET
    local week_num1 = math.floor(t1/SECONDS_OF_WEEK)
    local week_num2 = math.floor(t2/SECONDS_OF_WEEK)
    return week_num1 == week_num2
end

-- 检查两个时间是否是同一个月
function M.is_same_month(t1, t2, time_zone)
end

-- 检查两个时间是否是同一年
function M.is_same_year(t1, t2, time_zone)

end

-- 计算两个时间相差多少天，同天为0
function M.diff_days(t1, t2, time_zone)

end

return M
