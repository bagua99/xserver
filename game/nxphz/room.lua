local skynet = require "skynet"
local define = require "define"

local RECORD_HOST = skynet.getenv("RECORD_HOST")

local M = {}

-- 代理可以直接创建房间,其他玩家不可以解散代理开的房,这里记录房主ID

function M.init(info)
    local tOptions = {}
    -- 设置房间信息
    for _, tData in pairs(info.room.options) do
        tOptions[tData.key] = tData.snvalue or 0
    end
    -- 房主ID
    tOptions["master_id"] = info.player.userid
    tOptions["room_id"] = info.room.roomid
    tOptions["game_id"] = info.room.gameid

    -- 局数
    if tOptions.room_card == 0 then
        tOptions["game_count"] = 6
    else
        tOptions["game_count"] = tOptions.room_card * 6
    end

    tOptions.player_count = define.GAME_PLAYER

    M.tOptions = tOptions
end

-- cost_card    消耗房卡数量,游戏未开始,解散房间,返还此消耗
-- room_id      房间ID
-- master_id    房主ID
-- game_id      游戏ID
-- room_card    房卡
-- game_count   游戏局数
-- player_count 玩家数量
-- limit_base
function M.get(key)
    return M.tOptions[key]
end

function M.dump()
    local ret = {}
    for key, nValue in pairs(M.tOptions) do
        table.insert(ret, {key=key, nValue=nValue})
    end
    return ret
end

function M.finish(msg)
    skynet.send("room_mgr", "lua", "game_finish", msg)
end

function M.leave(msg)
    skynet.send("room_mgr", "lua", "leave_room_result", msg)
end

function M.add_record_list(msg)
    skynet.send("httpclient", "lua", "post", RECORD_HOST, "/add_record_list", msg)
end

return M
