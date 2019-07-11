local skynet = require "skynet"
local utils = require "utils"

local RECORD_HOST = skynet.getenv("RECORD_HOST")

local M = {}

-- cost_card 消耗房卡数量,游戏未开始,解散房间,返还此消耗
function M.init(info)
    M.roomid = info.room.roomid
    M.options = {}
    M.max = 5
    M.status = "ready"   -- 准备状态
    M.bank_score = 50
    M.init_score = 200

    M.min_call_score = 3 -- 最少3分，才能下注
    M.min_bank_count = 3
    M.max_bank_count = 15

    local tOptions = {}

    -- 设置房间信息
    for _, tData in pairs(info.room.options) do
        tOptions[tData.key] = tData.snvalue
    end
    -- 房主ID
    tOptions["master_id"] = info.player.userid
    tOptions["game_id"] = info.room.gameid
    tOptions["room_id"] = info.room.roomid

    print("房间参数")
    M.tOptions = tOptions
    utils.print(tOptions)
end

function M.get_owner()
    return M.tOptions.master_id
end

function M.has_face_card()
    return M.tOptions.face_card == 1
end

function M.set_status(status)
    M.status = status
end

function M.get_status()
    return M.status
end

function M.get_option(key)
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
