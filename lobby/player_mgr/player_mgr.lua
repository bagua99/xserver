local skynet = require "skynet"
local crypt = require "skynet.crypt"
local md5 = require "md5"
local utils = require "utils"

local sign_key = "do you know"

local M = {}

function M:init()
    self.tbl = {}
end

function M:get(userid)
    return self.tbl[userid]
end

function M:load(userid)
    local obj = self.tbl[userid]
    if obj then
        return obj
    end

    obj = skynet.call("mysql", "lua", "load_player", userid)
    if not obj then
        return nil
    end

    self.tbl[userid] = obj
    return obj
end

function M:save(userid)
    local obj = self.tbl[userid]
    if not obj then
        return
    end

    -- 保存玩家信息
    skynet.send("mysql", "lua", "save_player", obj)
end

function M:create(info)
    local obj = utils.copy_table(info)
    obj.score = 0
    obj.roomcard = 5
    obj.roomid = 0
    obj.sign = crypt.hexencode(md5.sum(sign_key..obj.userid))
    self.tbl[info.userid] = obj

    -- 保存玩家信息
    skynet.send("mysql", "lua", "new_player", obj)

    return obj
end

function M:update(userid, key, data)
    local obj = self.tbl[userid]
    if not obj then
        return
    end

    if not obj[key] then
        return
    end

    self.tbl[userid][key] = data

    -- 保存玩家信息
    skynet.send("mysql", "lua", "update_player", {
        userid = userid,
        key = key,
        data = data,
    })
end

return M
