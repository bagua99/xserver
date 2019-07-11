local skynet = require "skynet"
local utils = require "utils"
local handler = require "handler"
local player_mgr = require "player_mgr"
local room = require "room"
local match = require "match"

local CMD = {}

-- 房间创建
function CMD.create(info)
    player_mgr:init()
    room:init(info)
    match:init()
    handler.register()
    player_mgr:add_info(info.player)
end

-- 玩家连入房间
function CMD.join(info)
    player_mgr:add_info(info.player)
end

local function enter(msg)
    -- 创建玩家对象
    local p = player_mgr:add_player(msg)
    local ret = {
        name = "nn.GAME_EnterGameAck",
        msg = {
            err = 0,
            players = player_mgr:dump(),
            room =
            {
                 options = room:dump(),
            },
        }
    }

    -- 广播
    local broad = {
        userData = p:dump()
    }
    player_mgr:broadcast_but(p.userid,"nn.GAME_PlayerEnterAck", broad)
    return ret
end

local function reenter(msg)
    -- 创建玩家对象
    local p = player_mgr:get(msg.userid)
    if not p then
        return
    end
    local ret = {
        name = "nn.GAME_EnterGameAck",
        msg = {
            err = 0,
            players = player_mgr:dump(),
            room = room.dump()
        }
    }

    -- 广播
    local broad = {
        userData = p:dump()
    }
    player_mgr:broadcast_but(p.userid,"nn.GAME_PlayerEnterAck", broad)
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
    print("nn msg: ", name)
    utils.print(msg)
    handler.dispatch(userid, name, msg)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "nn接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
end)
