local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local string = string
local cjson = require "cjson"
local utils = require "utils"

local function response(id, code, msg, ...)
    skynet.call(".xlog", "lua", "log", "返回大厅http消息"..utils.table_2_str(msg))
    local ok, err = httpd.write_response(sockethelper.writefunc(id), code, msg, ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

local function create_room(id, body)
    local msg = cjson.decode(body)
    local ret = skynet.call(".room_mgr", "lua", "create_room", msg)
    response(id, 200, cjson.encode(ret))
end

local function join_room(id, body)
    local msg = cjson.decode(body)
    local ret = skynet.call(".room_mgr", "lua", "join_room", msg)
    response(id, 200, cjson.encode(ret))
end

local function handle(id)
    socket.start(id)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, _, _, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    if code then
        if code ~= 200 then
            response(id, code)
        else
            local path, query = urllib.parse(url)
            skynet.call(".xlog", "lua", "log", path.." "..query.." "..body)
            if path == "/create_room" then
                create_room(id, body)
            elseif path == "/join_room" then
                join_room(id, body)
            else
                socket.close(id)
            end
        end
    else
        if url == sockethelper.socket_error then
            skynet.error("socket closed")
        else
            skynet.error(url)
        end
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
