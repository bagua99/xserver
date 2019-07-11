local skynet = require "skynet"
local utils = require "utils"

local M = {}

function M:init()
    -- 当前最大id
    self.max_id = 0
    -- 增加数量(ID不够时每次新分配数量)
    self.add_count = 10000

    -- id表
    self.id_tbl = {}
    -- 账号表
    self.account_tbl = {}
    -- 剩余玩家id
    self.left_id_tbl = {}

    -- 载入用户
    self:load_all()
end

function M:load_all()
    local accounts = skynet.call(".mysql", "lua", "load_all_account")
    for _, obj in ipairs(accounts) do
        self.account_tbl[obj.account] = obj
        self.id_tbl[obj.userid] = obj.account
        if obj.userid > self.max_id then
            self.max_id = obj.userid
        end
    end

    -- 初始化剩余玩家id
    for i = self.max_id + 1, self.max_id + self.add_count do
        table.insert(self.left_id_tbl, i)
    end
    self.max_id = self.max_id + self.add_count

    skynet.send(".xlog", "lua", "log", "加载所有用户成功，max_id="..self.max_id..
        ",left_id_tbl="..#self.left_id_tbl)
end

function M:gen_id()
    if #self.left_id_tbl <= 0 then
        skynet.send(".xlog", "lua", "log", "玩家ID被用完,重新分配")
        -- 初始化剩余玩家id
        for i = self.max_id + 1, self.max_id + self.add_count do
            table.insert(self.left_id_tbl, i)
        end
        self.max_id = self.max_id + self.add_count
        skynet.send(".xlog", "lua", "log", "玩家ID被用完,重新分配，max_id="..
            self.max_id..",left_id_tbl="..#self.left_id_tbl)
    end

    local index = 1
    local id = self.left_id_tbl[index]
    table.remove(self.left_id_tbl, index)

    return id
end

function M:get_by_account(account)
    return self.account_tbl[account]
end

-- 验证账号密码
function M:verify(account, password)
    local acc = self.account_tbl[account]
    if not acc then
        return "account not exist"
    end
    if acc.password ~= password then
        return "wrong password"
    end

    return "success", acc
end

-- 注册账号
function M:register(info)
    if self.account_tbl[info.account] then
        return "account exists"
    end

    local userid = self:gen_id()
    local acc = {
        userid = userid,
        account = info.account,
        password = info.password,
        sex = info.sex,
        openid = "0",
        headimgurl = info.headimgurl,
        nickname = info.nickname,
        unionid = "0",
    }
    self.account_tbl[info.account] = acc
    skynet.send(".mysql", "lua", "new_account", acc)

    return "success", acc
end

-- 注册微信账号
function M:wx_login(info)
    skynet.send(".xlog", "lua", "log", "微信账号登录"..utils.table_2_str(info))
    local acc = self.account_tbl[info.account]
    if not acc then
        acc = utils.copy_table(info)
        acc.userid = self:gen_id()
        self.account_tbl[info.account] = acc
        skynet.send(".mysql", "lua", "new_account", acc)
    end

    return acc
end

function M:guest()
    local account
    local code
    local time = os.time()
    while true do
        code = time .. math.random(1, 100)
        account = "guest" .. code
        if not self.account_tbl[account] then
            break
        end
    end

    local userid = self:gen_id()
    local acc = {
        userid = userid,
        account = account,
        password = tostring(time),
        sex = math.random(1,2),
        openid = "1",
        headimgurl = "",
        nickname = "游客"..math.random(100,999),
        unionid = "1",
    }
    self.account_tbl[account] = acc
    skynet.send(".mysql", "lua", "new_account", acc)

    return acc
end

function M:update_account(info)
    local acc = self:get_by_account(info.account)
    if not acc then
        return
    end

    -- 更新mysql
    skynet.send(".mysql", "lua", "update_account", acc)
end

return M
