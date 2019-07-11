local md5 = require "md5"
local crypt = require "skynet.crypt"
local utils = require "utils"

local app_key = "123"

local M = {}

function M.get_token(info)
    local str = app_key
    str = str .. info.userid
    str = str .. info.openid
    str = str .. info.nickname
    str = str .. info.sex
    str = str .. info.headimgurl
    local token = md5.sum(str)
    token = utils.base64encode(token)
    return token
end

local function check(info)
    if not info.userid then
        return
    end

    if not info.openid then
        return
    end

    if not info.nickname then
        return
    end

    if not info.sex then
        return
    end

    if not info.headimgurl then
        return
    end

    if not info.token then
        return
    end

    return true
end

function M.verify_token(info)
    if not check(info) then
        return false
    end

    local str = app_key
    str = str .. info.userid
    str = str .. info.openid
    str = str .. info.nickname
    str = str .. info.sex
    str = str .. info.headimgurl
    local token = md5.sum(str)
    token = utils.base64encode(token)

    if info.token ~= token then
        return false
    end

    return true
end

function M.get_random_token()
    local token = md5.sum(tostring(os.time()))
    token = crypt.base64encode(token)
    return token
end

return M
