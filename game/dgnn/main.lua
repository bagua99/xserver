local skynet = require "skynet"
local handler = require "handler"
local player_mgr = require "player_mgr"
local room = require "room"
local match = require "match"

local CMD = {}

-- 房间创建
function CMD.create(info)
    player_mgr:init()
    room.init(info)
    match:init()
    handler.register()
    player_mgr:add_info(info.player)
end

-- 玩家连入房间
function CMD.join(info)
    -- 游戏是否已经开始
    if room.status ~= "ready" then
        return {result = "game begin"}
    end

    return player_mgr:add_info(info.player)
end

local function enter(msg)
    -- 返回信息
    local ret = {err = 0}

    -- 游戏是否已经开始
    if room.status ~= "ready" then
        ret.err = 4
        return ret
    end

    -- 创建玩家对象
    local p = player_mgr:add_player(msg)
    -- 加入失败
    if not p then
        -- 人数已满
        ret.err = 3
        return ret
    end

    return ret
end

local function reenter(msg)
    -- 返回信息
    local ret = {err = 0}

    -- 创建玩家对象
    local p = player_mgr:get(msg.userid)
    if not p then
        -- 人数已满
        ret.err = 3
        return ret
    end

    return ret
end

function CMD.enter(msg)
    if msg.reconnect then
        return reenter(msg)
    else
        return enter(msg)
    end
end

-- 玩家消息
function CMD.msg(userid, name, msg)
    handler.dispatch(userid, name, msg)
end

-- 通知玩家掉线
function CMD.offline(userid)
    local p = player_mgr:get(userid)
    if not p then
        return
    end
    p:on_offline()
    player_mgr:broadcast("protocol.UserOfflineAck", {userid=userid})
    print(p.nickname.."掉线了")
end

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "dgnn接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
end)
