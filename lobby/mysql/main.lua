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

function CMD.load_player(userid)
    local sql = string.format("select * from player where userid=%d", userid)
    skynet.send(".xlog", "lua", "log", sql)
    return db:query(sql)
end

function CMD.new_player(obj)
    local sql = string.format(
        "insert into player(userid,score,roomcard,sign) values(%d,%d,%d,%s);",
        obj.userid, obj.score, obj.roomcard, mysql.quote_sql_str(obj.sign)
    )
    skynet.send(".xlog", "lua", "log", sql)
    utils.print(db:query(sql))
end

function CMD.save_player(obj)
    local sql = string.format(
        "update player set score=%d,roomcard=%d,sign=%s where userid=%d;",
        obj.score, obj.roomcard, mysql.quote_sql_str(obj.sign), obj.userid
    )
    skynet.send(".xlog", "lua", "log", sql)
    utils.print(db:query(sql))
end

function CMD.update_player(msg)
    local sql = "update player set "..msg.key.."="..msg.data.." where userid="..msg.userid..";"
    skynet.send(".xlog", "lua", "log", sql)
    utils.print(db:query(sql))
end

function CMD.roomcard_log(msg)
    local sql = string.format(
        "insert into roomcard_log(userid,add_type,roomid,begin_roomcard,end_roomcard,cost_roomcard,date) "..
        "values(%d,%d,%d,%d,%d,%d,%s);",
        msg.userid, msg.add_type, msg.roomid, msg.begin_roomcard, msg.end_roomcard, msg.cost_roomcard, mysql.quote_sql_str(msg.date)
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