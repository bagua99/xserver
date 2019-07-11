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
    if msg then
        msg = utils.base64encode(msg)
    end
    local ok, err = httpd.write_response(sockethelper.writefunc(id), code, msg, ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

local function login(id, body)
    local msg = cjson.decode(body)
    local err
    repeat
        -- 检查账号
        if type(msg.account) ~= "string" or #msg.account < 6 or #msg.account > 32 then
            err = "wrong accout)"
            break
        end

        -- 微信账号前缀
        if string.sub(msg.account, 1,4) == "wxqd" then
            err = "wrong exists"
            break
        end

        -- 检查密码
        if type(msg.password) ~= "string" or #msg.password < 6 or #msg.password > 32 then
            err = "wrong password"
            break
        end
    until(true)
    if err then
        response(id, 200, cjson.encode({msg = err}))
        return
    end

    local ret, acc = skynet.call(".login", "lua", "verify", msg)
    if ret ~= "success" then
        response(id, 200, cjson.encode({msg = ret}))
        return
    end

    response(id, 200, cjson.encode(acc))
end

-- 注册
local function register(id, body)
    local msg = cjson.decode(body)

    local err
    repeat
        -- 检查账号
        if type(msg.account) ~= "string" or #msg.account < 6 or #msg.account > 16 then
            err = "wrong accout)"
            break
        end

        -- 微信账号前缀
        if string.sub(msg.account, 1,4) == "wxqd" then
            err = "account exists"
            break
        end

        -- 检查密码
        if type(msg.password) ~= "string" or #msg.password < 6 or #msg.password > 16 then
            err = "wrong password"
            break
        end

        if msg.sex ~= 1 and msg.sex ~= 2 then
            err = "wrong sex"
            break
        end

        if type(msg.headimgurl) ~= "string" then
            err = "wrong headimgurl"
            break
        end

        if type(msg.nickname) ~= "string" or #msg.nickname < 6 or #msg.nickname > 16 then
            err = "wrong nickname"
            break
        end

    until(true)

    if err then
        response(id, 200, cjson.encode({msg = err}))
        return
    end

    local ret, acc = skynet.call(".login", "lua", "register", msg)
    if ret ~= "success" then
        response(id, 200, cjson.encode({msg = ret}))
        return
    end

    response(id, 200, cjson.encode(acc))
end

-- 游客登录
local function guest(id, _)
    local err, acc = skynet.call(".login", "lua", "guest")
    if err ~= "success" then
        response(id, 200, cjson.encode({msg = err}))
        return
    end

    response(id, 200, cjson.encode(acc))
end

local function wx_login(id, body)
    local msg = cjson.decode(body)
    local ret = skynet.call("wxlogin", "lua", "wxlogin", msg.code)
    if type(ret) ~= "table" then
        response(id, 1, "")
        return
    end

    local err, acc = skynet.call(".login", "lua", "wx_login", ret)
    if err ~= "success" then
        response(id, 1, "")
        return
    end

    response(id, 200, cjson.encode(acc))
end

local function wx_tmp_login(id, body)
    local msg = cjson.decode(body)
    local err, acc = skynet.call(".login", "lua", "wx_tmp_login", msg)
    if err ~= "success" then
        response(id, 1, "")
        return
    end

    local ret = skynet.call("wxlogin", "lua", "wxtmplogin", acc)
    if type(ret) ~= "table" then
        response(id, 1, "")
        return
    end

    local info =
    {
        account = msg.account,
        nickname = ret.nickname,
        sex = ret.sex,
        language = ret.language,
        city = ret.city,
        province = ret.province,
        country = ret.country,
        headimgurl = ret.headimgurl,
        privilege = ret.privilege,
        access_token = ret.access_token,
        access_time = ret.access_time,
        access_update = ret.access_update,
    }
    -- 更新信息
    local reat_ack = skynet.call(".login", "lua", "wx_login_update", info)
    if not reat_ack then
        response(id, 1, "")
        return
    end

    response(id, 200, cjson.encode(reat_ack))
end

local function handle(id)
    print("handle http")
    socket.start(id)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, _, _, _ = httpd.read_request(sockethelper.readfunc(id), 256)
    if not code or code ~= 200 then
        print("code error")
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
    if path == "/login" then
        login(id, content)
    elseif path == "/register" then
        register(id, content)
    elseif path == "/guest" then
        guest(id, content)
    elseif path == "/wx_login" then
        wx_login(id, content)
    elseif path == "/wx_tmp_login" then
        wx_tmp_login(id, content)
    end
    socket.close(id)
end

skynet.start(function()
    skynet.dispatch("lua", function (_,_,id)
        --handle(id)
        if not pcall(handle, id) then
            response(id, 200, "{\"msg\"=\"exception\"}")
        end
    end)
end)
