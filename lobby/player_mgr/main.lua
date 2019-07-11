local skynet = require "skynet"
require "skynet.manager"
local player_mgr = require "player_mgr"
local handler = require "handler"

local CMD = {}

-- 获取玩家房间信息
function CMD.login_lobby(msg)
    return handler.login_lobby(msg)
end

-- 房间信息-创建房间
function CMD.create_room(msg)
    return handler.create_room(msg)
end

-- 房间消息-游戏加入房间
function CMD.join_room(msg)
    return handler.join_room(msg)
end

-- 房间消息-结束房间
function CMD.finish_room(msg)
    return handler.finish_room(msg)
end

function CMD.add_usercard(userid, count)
    local pGet = player_mgr:get(userid)
    if not pGet then
        -- 数据库查询
        local _player = skynet.call(".mysql", "lua", "load_player", userid)
        if not _player then
            return
        end

        -- 赠卡玩家
        _player.roomcard = _player.roomcard + count
        skynet.call(".mysql", "lua", "save_player", _player)
    else
        -- 给赠送玩家增加
        pGet.roomcard = pGet.roomcard + count
        skynet.call(".mysql", "lua", "save_player", pGet)
    end
end

function CMD.send_card(msg)
    return handler.send_card(msg)
end

function CMD.update_userinfo(msg)
    return handler.update_userinfo(msg)
end

skynet.start(function()
    player_mgr:init()

    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "player_mgr接收到非法lua消息: "..cmd)
            return
        end

        if session == 0 then
            f(...)
        else
            skynet.ret(skynet.pack(f(...)))
        end
    end)

    skynet.register(".player_mgr")
end)
