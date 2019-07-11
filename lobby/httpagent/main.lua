local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local string = string
local cjson = require "cjson"
local utils = require "utils"

local function response(id, code, msg, hide_log, ...)
    if not hide_log then
        utils.print(msg)
    end
    local ok, err = httpd.write_response(sockethelper.writefunc(id), code, msg, ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

local function server_heartbeat(id, body)
    --skynet.send(".xlog", "lua", "log", "游戏服务器心跳"..body)
    local msg = cjson.decode(body)
    local ret = skynet.call(".room_mgr", "lua", "server_heartbeat", msg)
    response(id, 200, cjson.encode(ret), true)
end

local function server_room_list(id, body)
    skynet.send(".xlog", "lua", "log", "游戏服务器上报房间列表房间"..body)
    local msg = cjson.decode(body)
    skynet.send(".room_mgr", "lua", "server_room_list", msg)

    local ret_msg = {
        err = "success"
    }
    response(id, 200, cjson.encode(ret_msg))
end

local function server_stop_newroom(id, body)
    skynet.send(".xlog", "lua", "log", "游戏服务器停止创建房间"..body)
    local msg = cjson.decode(body)
    skynet.send(".room_mgr", "lua", "server_stop_newroom", msg)

    local ret_msg = {
        err = "success"
    }
    response(id, 200, cjson.encode(ret_msg))
end

local function server_close(id, body)
    skynet.send(".xlog", "lua", "log", "游戏服务器停服"..body)
    local msg = cjson.decode(body)
    skynet.send(".room_mgr", "lua", "server_close", msg)

    local ret_msg = {
        err = "success"
    }
    response(id, 200, cjson.encode(ret_msg))
end

local function game_finish(id, body)
    local msg = cjson.decode(body)
    skynet.send(".room_mgr", "lua", "game_finish", msg)
    skynet.send(".player_mgr", "lua", "finish_room", msg)
    local ret_msg = {
        err = "success"
    }
    response(id, 200, cjson.encode(ret_msg))
end

local function leave_room_result(id, body)
    local msg = cjson.decode(body)
    skynet.send(".room_mgr", "lua", "leave_room_result", msg)
    response(id, 200, cjson.encode({err = "success"}))
end

local function handle(id)
    socket.start(id)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, _, _, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    if code ~= 200 then
        skynet.send(".xlog", "lua", "log", "大厅服务器WEB端口状态异常url="..url)
        socket.close(id)
        return
    end

    local path, query = urllib.parse(url)
    if path ~= "/server_heartbeat" then
        print(path, query, body)
    end
    if path == "/server_heartbeat" then
        server_heartbeat(id, body)
    elseif path == "/server_room_list" then
        server_room_list(id, body)
    elseif path == "/server_stop_newroom" then
        server_stop_newroom(id, body)
    elseif path == "/server_close" then
        server_close(id, body)
    elseif path == "/game_finish" then
        game_finish(id, body)
    elseif path == "/leave_room_result" then
        leave_room_result(id, body)
    else
        skynet.send(".xlog", "lua", "log", "大厅服务器WEB端口url异常"..url)
    end

    socket.close(id)
end

skynet.start(function()
    skynet.dispatch("lua", function (_, _, id)
        --handle(id)
        if not pcall(handle, id) then
            response(id, 200, "{\"msg\"=\"exception\"}")
        end
    end)
end)
