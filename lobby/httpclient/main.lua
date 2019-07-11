local skynet = require "skynet"
require "skynet.manager"
local httpc = require "http.httpc"
local cjson = require "cjson"

local function request(host, url, msg)
    local content = cjson.encode(msg)
    local header = {}
    local respheader = {}
    local status, body = httpc.request("post", host, url, respheader, header,content)
    if status ~= 200 then
        return {}
    end
    return cjson.decode(body)
end

local CMD = {}

function CMD.post(host, url, msg)
    print(host, url, msg)
    return request(host, url, msg)
end

skynet.start(function()
    httpc.dns() -- set dns server
    httpc.timeout = 100 -- set timeout 1 second

    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "httpclient接收到非法lua消息: "..cmd)
            return
        end

        if session == 0 then
            f(...)
        else
            skynet.ret(skynet.pack(f(...)))
        end
    end)

    skynet.register(".httpclient")
end)
