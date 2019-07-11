local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local string = string
local cjson = require "cjson"
local utils = require "utils"
local crc32 = require "crc32"

local function response(id, code, msg, ...)
    skynet.send("xlog", "lua", "log", "base_web返回"..utils.table_2_str(msg))
    msg = utils.base64encode(msg)
    local ok, err = httpd.write_response(sockethelper.writefunc(id), code, msg, ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

local function login_lobby(id, body)
    skynet.send("xlog", "lua", "log", "login_lobby请求"..body)
    local msg = cjson.decode(body)
    local ret = skynet.call("player_mgr", "lua", "login_lobby", msg)

    response(id, 200, cjson.encode(ret))
end

-- 玩家加入房间成功
local function create_room(id, body)
    skynet.send("xlog", "lua", "log", "create_room请求"..body)
    local msg = cjson.decode(body)
    local ret = skynet.call("player_mgr", "lua", "create_room", msg)
    response(id, 200, cjson.encode(ret))
end

local function join_room(id, body)
    skynet.send("xlog", "lua", "log", "join_room请求"..body)
    local msg = cjson.decode(body)
    local ret = skynet.call("player_mgr", "lua", "join_room", msg)
    response(id, 200, cjson.encode(ret))
end

local function send_card(id, body)
    skynet.send("xlog", "lua", "log", "send_card"..body)
    local msg = cjson.decode(body)
    local ret = skynet.call("player_mgr", "lua", "send_card", msg)
    response(id, 200, cjson.encode(ret))
end

local function update_userinfo(id, body)
    skynet.send("xlog", "lua", "log", "update_userinfo"..body)
    local msg = cjson.decode(body)
    local ret = skynet.call("player_mgr", "lua", "update_userinfo", msg)
    response(id, 200, cjson.encode(ret))
end

local function handle(id)
    socket.start(id)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, _, _, _ = httpd.read_request(sockethelper.readfunc(id), 2048)
    if code ~= 200 then
        skynet.send("xlog", "lua", "log", "base_web请求状态异常code="..code)
        socket.close(id)
        return
    end

    local path, query = urllib.parse(url)
    if not path or not query then
        socket.close(id)
        print("urllib.parse wrong")
        return
    end
    local q = urllib.parse_query(query)
    local data = q.data
    if not data then
        print("query没有data字段")
        socket.close(id)
        return
    end
    local sign = string.sub(data,2,9)
    local content = string.sub(data,11)
    if sign ~= crc32.hash(content) then
        skynet.error("request签名不对")
        socket.close(id)
        return
    end
    content = utils.base64decode(content)
    print(path, query, content)
    if path == "/login_lobby" then
        login_lobby(id, content)
    elseif path == "/create_room" then
        create_room(id, content)
    elseif path == "/join_room" then
        join_room(id, content)
    elseif path == "/send_card" then
        send_card(id, content)
    elseif path == "/update_userinfo" then
        update_userinfo(id, content)
    else
        skynet.send("xlog", "lua", "log", "base_web请求path异常"..path)
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
