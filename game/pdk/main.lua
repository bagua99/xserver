local skynet = require "skynet"
local handler = require "handler"
local room = require "room"
local player_mgr = require "player_mgr"
local match = require "match"

local CMD = {}

-- 房间创建
function CMD.create(info)
    -- 注册事件
    handler.register()

    -- 初始化房间信息
    room.init(info)

    -- 初始化玩家管理信息
    player_mgr:init()
    player_mgr:add_info(info.player)

    -- 比赛初始化
    match:init()
end

-- 玩家连入房间
function CMD.join(info)
    -- 游戏是否已经开始
    if match.nGameCount ~= 0 then
        return {result = "game begin"}
    end

    return player_mgr:add_info(info.player)
end

-- 进入游戏
local function enter(msg)
    -- 返回信息
    local ret =
    {
        err = 0,
    }

    -- 创建玩家对象
    local _player = player_mgr:add_player(msg)
    -- 加入失败
    if not _player then
        -- 人数已满
        ret.err = 3
        return ret
    end

    -- 游戏是否已经开始
    if match.nGameCount ~= 0 then
        ret.err = 4
        return ret
    end

    return ret
end

-- 重进游戏
local function reenter(msg)
    -- 返回信息
    local ret =
    {
        err = 0,
    }

    -- 创建玩家对象
    local _player = player_mgr:get(msg.userid)
    if not _player then
        -- 人数已满
        ret.err = 3
        return ret
    end

    return ret
end

-- 进入游戏
function CMD.enter(msg)
    if msg.reconnect then
        return reenter(msg)
    else
        return enter(msg)
    end
end

-- 通知玩家掉线
function CMD.offline(userid)
    local _player = player_mgr:get(userid)
    if not _player then
        return
    end

    -- 设置断线
    _player:on_offline()

    -- 广播玩家离开
    player_mgr:broadcast_but(userid, "protocol.UserOfflineAck", {userid = userid})
end

-- 玩家消息
function CMD.msg(userid, name, msg)
    handler.dispatch(userid, name, msg)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "pdk接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
end)
