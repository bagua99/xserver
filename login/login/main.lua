local skynet = require "skynet"
require "skynet.manager"
local utils = require "utils"
local token = require "token"
local account_mgr = require "account_mgr"
local lobby_dispatch = require "lobby_dispatch"

local CMD = {}

function CMD.start(_)
    account_mgr:init()
    lobby_dispatch:init()
end

-- 注册
function CMD.register(info)
    local err, acc = account_mgr:register(info)
    if err ~= "success" then
        return err
    end

    local retinfo = utils.copy_table(acc)
    retinfo.userid = acc.userid
    retinfo.openid = acc.openid
    retinfo.token = token.get_token(retinfo)
    acc.token = retinfo.token

    return "success", retinfo
end

-- 验证
function CMD.verify(info)
    local err, acc = account_mgr:verify(info.account, info.password)
    if err ~= "success" then
        return err
    end

    local retinfo = utils.copy_table(acc)
    retinfo.token = token.get_token(retinfo)
    acc.token = info.token
    return "success", retinfo
end

-- 微信登录
function CMD.wx_login(info)
    skynet.send(".xlog", "lua", "log", "wx_login "..utils.table_2_str(info))
    info.account = "wxqd"..info.openid
    info.nickname = utils.filter_spec_chars(info.nickname)
    info.headimgurl = utils.base64encode(info.headimgurl)

    local acc = account_mgr:wx_login(info)
    acc.refresh_token = info.refresh_token
    acc.refresh_time = info.refresh_time
    acc.access_token = info.access_token
    acc.access_time = info.access_time
    account_mgr:update_account(acc)

    info.userid = acc.userid
    info.openid = acc.openid
    info.token = token.get_token(info)
    acc.token = info.token

    info.refresh_token = nil    -- 清除微信refresh_token
    info.access_token = nil     -- 清除微信access_token
    return "success",info
end

function CMD.guest()
    local acc = account_mgr:guest()
    local info = utils.copy_table(acc)
    info.token = token.get_token(info)
    info.ip, info.port = lobby_dispatch:dispatch()
    acc.token = info.token

    return "success", info
end

-- 微信临时登录
function CMD.wx_tmp_login(info)
    local acc = account_mgr:get_by_account(info.account)
    if not acc then
        return "fail", nil
    end

    if not acc.refresh_token or not acc.refresh_time then
        return "fail", nil
    end

    if os.time() >= acc.refresh_time then
        return "fail", nil
    end

    skynet.send(".xlog", "lua", "log", "wx_tmp_login userid="..acc.userid)

    local ret = utils.copy_table(acc)
    ret.token = token.get_token(ret)
    return "success", ret
end

function CMD.wx_login_update(info)
    local acc = account_mgr:get_by_account(info.account)
    if not acc then
        return nil
    end

    acc.sex = info.sex
    acc.headimgurl = utils.base64encode(info.headimgurl)
    acc.nickname = utils.filter_spec_chars(info.nickname)
    acc.language = info.language
    acc.city = info.city
    acc.province = info.province
    acc.country = info.country
    acc.privilege = info.privilege
    if info.access_update then
        acc.access_token = info.access_token
        acc.access_time = info.access_time
        account_mgr:update_account(info)
    end
    acc.token = token.get_token(acc)

    local msg = utils.copy_table(acc)
    msg.token = token.get_token(msg)

    msg.refresh_token = nil    -- 清除微信refresh_token
    msg.access_token = nil     -- 清除微信access_token
    return msg
end

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "login接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)

    skynet.register(".login")
end)
