local skynet = require "skynet"
require "skynet.manager"
local G = require "global"
local room_mgr = require "room_mgr"
local game_mgr = require "game_mgr"

local function init()
    G.room_mgr = room_mgr
    G.game_mgr = game_mgr
    G.game_mgr:init()
    G.room_mgr:init()
end

local CMD = {}

-- 获取玩家房间信息
function CMD.get_player_info(userid)
    return G.room_mgr:get_player_info(userid)
end

function CMD.create_room(msg)
    return G.room_mgr:create(msg)
end

function CMD.join_room(msg)
    return G.room_mgr:join(msg)
end

function CMD.server_heartbeat(info)
    local g = G.game_mgr:get(info.gameid)
    if not g then
        skynet.send("xlog", "lua", "log",
            "游戏服务器注册找不到游戏类型gameid="..info.gameid)
        return
    end
    return g:heartbeat(info)
end

function CMD.server_room_list(info)
    local g = G.game_mgr:get(info.gameid)
    if not g then
        return
    end
    g:room_list(info)
end

function CMD.server_stop_newroom(info)
    local g = G.game_mgr:get(info.gameid)
    if not g then
        return
    end
    g:stop_newroom(info)
end

function CMD.server_close(info)
    local g = G.game_mgr:get(info.gameid)
    if not g then
        return
    end
    g:server_close(info)
end

-- 房间消息-游戏结束
function CMD.game_finish(info)
    G.room_mgr:game_finish(info)
end

-- 房间信息-离开房间成功
function CMD.leave_room_result(info)
    G.room_mgr:leave_room_result(info)
end

skynet.info_func(function()
    G.room_mgr:info_func()
end)

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "room_mgr接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)

    init()

    skynet.register("room_mgr")
end)
