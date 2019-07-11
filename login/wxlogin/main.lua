local skynet = require "skynet"
require "skynet.manager"
local https = require "https"
local dns = require "dns"
local cjson = require "cjson"

local AppID = "wx17eaba1ec30075bd"
local AppSecret = "66df51f440b3e7cd9c45f9f8c8b131b9"

local host = "api.weixin.qq.com"
local host_ip
local function get_access_token(code)
    skynet.send("xlog", "lua", "log", "get_access_token code="..code)
    if not host_ip then
        host_ip = dns.resolve(host)
    end
    local path = "/sns/oauth2/access_token?"
    local query ="appid="..AppID.."&secret="..AppSecret.."&code="..code.."&grant_type=authorization_code"
    local respheader = {}
    local status, body = https.request("GET",host_ip, path..query, respheader)

    skynet.send("xlog", "lua", "log", "status="..status.." body="..body)
    return cjson.decode(body)
end

local function refresh_access_token(refresh_token)
    skynet.send("xlog", "lua", "log", "refresh_access_token token="..refresh_token)
    if not host_ip then
        host_ip = dns.resolve(host)
    end
    local path = "/sns/oauth2/refresh_token?"
    local query ="appid="..AppID.."&grant_type=refresh_token&refresh_token="..refresh_token
    local respheader = {}
    local status, body = https.request("GET",host_ip, path..query, respheader)

    skynet.send("xlog", "lua", "log", "status="..status.." body="..body)
    return cjson.decode(body)
end

local function get_userinfo(access_token, openid)
    if not host_ip then
        host_ip = dns.resolve(host)
    end
    local path = "/sns/userinfo?"
    local query = "access_token="..access_token.."&openid="..openid

    local respheader = {}
    local status, body = https.request("GET",host_ip, path..query, respheader)
    skynet.send("xlog", "lua", "log", "status="..status.." body="..body)
    return cjson.decode(body)
end

local CMD = {}

function CMD.start(_)
end

function CMD.wxlogin(code)
    local token_msg = get_access_token(code)
    if not token_msg or not token_msg.access_token or not token_msg.openid then
        return nil
    end
    local msg = get_userinfo(token_msg.access_token, token_msg.openid)
    msg.refresh_token = token_msg.refresh_token
    msg.refresh_time = os.time() + 29*24*3600   -- 官方说明30天有效期
    msg.access_token = token_msg.access_token
    msg.access_time = os.time() + 5400          -- 官方说明2小时有效期
    return msg
end

function CMD.wxtmplogin(acc)
    local msg
    -- 过期了,刷新
    if acc.access_time <= os.time() then
        local token_msg = refresh_access_token(acc.refresh_token)
        if token_msg.access_token and token_msg.openid then
            local access_token = token_msg.access_token
            local openid = token_msg.openid
            msg = get_userinfo(access_token, openid)
            msg.access_token = access_token
            msg.access_time = os.time() + 5400          -- 官方说明2小时有效期
            msg.access_update = true
        end
    else
        msg = get_userinfo(acc.access_token, acc.openid)
        -- 错误返回,用refresh_token去试
        if msg.errcode then
            local token_msg = refresh_access_token(acc.refresh_token)
            local access_token = token_msg.access_token
            local openid = token_msg.openid
            msg = get_userinfo(access_token, openid)
            msg.access_token = access_token
            msg.access_time = os.time() + 5400          -- 官方说明2小时有效期
            msg.access_update = true
        end
    end

    return msg
end

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "wxlogin接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
    dns.server()
    skynet.register("wxlogin")
end)
