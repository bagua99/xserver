local skynet = require "skynet"
require "skynet.manager"
local mysql = require "mysql"
local utils = require "utils"
local db

local CMD = {}

function CMD.start(conf)
    db = require("db").new(conf)
    skynet.send(".xlog", "lua", "log", string.format(
        "连接mysql,host=%s,port=%d,database=%s",
        conf.host,
        conf.port,
        conf.database)
    )
end

function CMD.new_account(acc)
    local sql = string.format(
        "insert into account(account,password,sex,headimgurl,nickname,userid,openid) values(%s,%s,%d,%s,%s,%d,%s);",
        mysql.quote_sql_str(acc.account),
        mysql.quote_sql_str(acc.password),
        acc.sex,
        mysql.quote_sql_str(acc.headimgurl),
        mysql.quote_sql_str(acc.nickname),
        acc.userid,
        mysql.quote_sql_str(acc.openid)
    )
    skynet.send(".xlog", "lua", "log", sql)
    utils.print(db:query(sql))
end

function CMD.load_all_account()
    skynet.send(".xlog", "lua", "log", "load all account")
    local accounts = db:query("select * from account;")
    return accounts
end

function CMD.update_account(acc)
    local sql = string.format(
        "update account set sex=%d,headimgurl=%s,nickname=%s,"..
        "refresh_token=%s,refresh_time=%d,access_token=%s,access_time=%d,"..
        "language=%s,city=%s,province=%s,country=%s,privilege=%s where account=%s;",
        acc.sex,
        mysql.quote_sql_str(acc.headimgurl),
        mysql.quote_sql_str(acc.nickname),
        mysql.quote_sql_str(acc.refresh_token),
        acc.refresh_time,
        mysql.quote_sql_str(acc.access_token),
        acc.access_time,
        mysql.quote_sql_str(acc.language),
        mysql.quote_sql_str(acc.city),
        mysql.quote_sql_str(acc.province),
        mysql.quote_sql_str(acc.country),
        mysql.quote_sql_str(acc.privilege),
        mysql.quote_sql_str(acc.account)
    )
    skynet.send(".xlog", "lua", "log", sql)
    utils.print(db:query(sql))
end

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, ...)
        local f = CMD[cmd]
        if not f then
            assert(f, "mysql接收到非法lua消息: "..cmd)
            return
        end

        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)

    skynet.register(".mysql")
end)
