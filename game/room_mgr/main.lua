local skynet = require "skynet"
require "skynet.manager"
local room_mgr = require "room_mgr"

local GAME_ADDR = skynet.getenv("GAME_ADDR")
local GAME_PORT = skynet.getenv("GAME_PORT")
local LOBBY_HOST = skynet.getenv("LOBBY_HOST")

local CMD = {}

function CMD.start()
    room_mgr:init()
end

function CMD.create_room(info)
    info.room.roomid = math.floor(info.room.roomid)
    local r = room_mgr:create_room(info)
    local msg = {
        roomid = info.room.roomid,
        addr = r:get_addr()
    }
    skynet.send("dog", "lua", "new_room", msg)
    return {
        result = "success",
        ip = GAME_ADDR,
        port = GAME_PORT,
        ticket = r.ticket
    }
end

function CMD.join_room(info)
    local r = room_mgr:join_room(info)
    if not r then
        return {result = "join fail"}
    else
        if not r.result then
            return {result = "join fail"}
        else
            if r.result ~= "success" then
                return {result = r.result}
            end
        end
    end
    return {
        result = "success",
        ip = GAME_ADDR,
        port = GAME_PORT,
        ticket = r.ticket
    }
end

function CMD.game_finish(info)
    skynet.send("httpclient", "lua", "post", LOBBY_HOST, "/game_finish", info)
    room_mgr:finish_room(info)
end

function CMD.leave_room_result(info)
    room_mgr:leave_room(info)
    skynet.send("httpclient", "lua", "post", LOBBY_HOST, "/leave_room_result", info)
end

function CMD.room_list()
    local info = room_mgr:room_list()
    skynet.send("httpclient", "lua", "post", LOBBY_HOST, "/server_room_list", info)
end

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

    skynet.register("room_mgr")
end)
