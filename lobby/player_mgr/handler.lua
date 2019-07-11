local skynet = require "skynet"
local token = require "token"
local player_mgr = require "player_mgr"

local M = {}

-- 登录
function M.login_lobby(msg)
    -- cjson返回为double,number取整
    msg.userid = math.modf(msg.userid)
    msg.sex = math.modf(msg.sex)
    if not token.verify_token(msg) then
        skynet.send(".xlog", "lua", "log", "登录失败：verify token failed")
        return {result = "token failed"}
    end

    local p = player_mgr:load(msg.userid)
    if p == nil then
        skynet.send(".xlog", "lua", "log", "创建玩家："..msg.userid)
        p = player_mgr:create(msg)
    end

    -- 加载玩家失败
    if not p then
        return {result = "player not find"}
    end

    -- 向房间管理器申请房间信息
    local info = skynet.call(".room_mgr", "lua",
        "get_player_info", p.userid)

    local ret = {
        result = "success",
        sign = p.sign,
        score = p.score,
        roomcard = p.roomcard,
        roomid = info.roomid,
        gameid = info.gameid,
        ticket = info.ticket,
        ip = info.ip,
        port = info.port
    }

    return ret
end

-- 创建房间
function M.create_room(msg)
    local p = player_mgr:get(msg.userid)
    if not p then
        return {result = "relogin"}
    end

    if p.sign ~= msg.sign then
        print(p.sign, msg.sign)
        return {result = "sign fail"}
    end

    msg.roomcard = p.roomcard
    msg.player = {
        userid = p.userid,
        score = p.score,
        account = msg.account,
        nickname = msg.nickname,
        headimgurl = msg.headimgurl,
        sex = msg.sex,
    }

    local ret = skynet.call(".room_mgr", "lua", "create_room", msg)
    if not ret then
        return {result = "createroom fail"}
    else
        if not ret.result then
            return {result = "createroom fail"}
        else
            if ret.result ~= "success" then
                return {result = ret.result}
            end
        end
    end

    -- 更新玩家房卡
    local endcard = p.roomcard - ret.costcard
    player_mgr:update(msg.userid, "roomcard", endcard)
    -- 记录房卡消耗
    local roomcard_msg =
    {
        userid = msg.userid,
        add_type = msg.gameid,
        roomid = ret.roomid,
        begin_roomcard = p.roomcard + ret.costcard,
        end_roomcard = p.roomcard,
        cost_roomcard = -ret.costcard,
        date = os.date("%Y-%m-%d %H:%M:%S"),
    }
    skynet.send(".mysql", "lua", "roomcard_log", roomcard_msg)

    return {
        result = "success",
        gameid = msg.gameid,
        roomid = ret.roomid,
        ticket = ret.ticket,
        ip = ret.ip,
        port = ret.port,
    }
end

-- 加入房间
function M.join_room(msg)
    local p = player_mgr:get(msg.userid)
    if not p then
        return {result = "relogin"}
    end

    if p.sign ~= msg.sign then
        return {result = "sign fail"}
    end

    msg.player = {
        userid = p.userid,
        score = p.score,
        account = msg.account,
        nickname = msg.nickname,
        headimgurl = msg.headimgurl,
        sex = msg.sex,
    }

    local ret = skynet.call(".room_mgr", "lua", "join_room", msg)
    if not ret then
        return {result = "join fail"}
    else
        if not ret.result then
            return {result = "join fail"}
        else
            if ret.result ~= "success" then
                return {result = ret.result}
            end
        end
    end

    return {
        result = "success",
        roomid = msg.roomid,
        ticket = ret.ticket,
        gameid = ret.gameid,
        ip = ret.ip,
        port = ret.port,
    }
end

-- 房间结束
function M.finish_room(msg)
    if not msg or not msg.game then
        return
    end

    local p = player_mgr:get(msg.game.masterid)
    if not p then
        return
    end

    -- 判断房间是否存在 todo

    if not msg.game.costcard or msg.game.costcard <= 0 then
        return
    end
    local costcard = msg.game.costcard

    -- 更新玩家房卡
    local endcard = p.roomcard + costcard
    player_mgr:update(msg.game.masterid, "roomcard", endcard)
    -- 记录房卡消耗
    local roomcard_msg =
    {
        userid = msg.game.masterid,
        add_type = msg.game.gameid,
        roomid = msg.game.roomid,
        begin_roomcard = p.roomcard - costcard,
        end_roomcard = p.roomcard,
        cost_roomcard = costcard,
        date = os.date("%Y-%m-%d %H:%M:%S"),
    }
    skynet.send(".mysql", "lua", "roomcard_log", roomcard_msg)
end

-- 赠卡
function M.send_card(msg)
    if not msg or not msg.userid or not msg.getid or not msg.sign then
        return {result = "fail"}
    end

    if type(msg.userid) ~= "number" or type(msg.count) ~= "number" or type(msg.getid) ~= "number" then
        return {result = "string fail"}
    end

    if msg.userid == msg.getid then
        return {result = "send self fail"}
    end

    if msg.count <= 0 then
        return {result = "count fial"}
    end

    local p = player_mgr:get(msg.userid)
    if not p then
        return {result = "fail"}
    end

    if p.openid == "0" or p.openid == "1" then
        return {result = "send limit"}
    end

    if p.sign ~= msg.sign then
        return {result = "sign fail"}
    end

    if p.roomcard < msg.count then
        return {result = "count less fail"}
    end

    -- 获取增加玩家
    local pGet = player_mgr:get(msg.getid)
    if not pGet then
        -- 数据库查询
        local _player = skynet.call(".mysql", "lua", "load_player", msg.getid)
        if not _player then
            return {result = "getid fial"}
        end

        -- 赠卡玩家
        p.roomcard = p.roomcard - msg.count
        skynet.call(".mysql", "lua", "save_player", p)
        -- 记录房卡消耗
        local roomcard_sendmsg =
        {
            userid = msg.userid,
            add_type = 0,
            roomid = 0,
            begin_roomcard = p.roomcard + msg.count,
            end_roomcard = p.roomcard,
            cost_roomcard = -msg.count,
            date = os.date("%Y-%m-%d %H:%M:%S"),
        }
        skynet.send(".mysql", "lua", "roomcard_log", roomcard_sendmsg)

        -- 给赠送玩家增加
        _player.roomcard = _player.roomcard + msg.count
        skynet.call(".mysql", "lua", "save_player", _player)
        -- 记录房卡消耗
        local roomcard_getmsg =
        {
            userid = msg.getid,
            add_type = 0,
            roomid = 0,
            begin_roomcard = _player.roomcard - msg.count,
            end_roomcard = _player.roomcard,
            cost_roomcard = msg.count,
            date = os.date("%Y-%m-%d %H:%M:%S"),
        }
        skynet.send(".mysql", "lua", "roomcard_log", roomcard_getmsg)
    else
        -- 赠卡玩家
        p.roomcard = p.roomcard - msg.count
        skynet.call(".mysql", "lua", "save_player", p)
         -- 记录房卡消耗
        local roomcard_sendmsg =
        {
            userid = msg.userid,
            add_type = 0,
            roomid = 0,
            begin_roomcard = p.roomcard + msg.count,
            end_roomcard = p.roomcard,
            cost_roomcard = -msg.count,
            date = os.date("%Y-%m-%d %H:%M:%S"),
        }
        skynet.send(".mysql", "lua", "roomcard_log", roomcard_sendmsg)

        -- 给赠送玩家增加
        pGet.roomcard = pGet.roomcard + msg.count
        skynet.call(".mysql", "lua", "save_player", pGet)
        -- 记录房卡消耗
        local roomcard_getmsg =
        {
            userid = msg.getid,
            add_type = 0,
            roomid = 0,
            begin_roomcard = pGet.roomcard - msg.count,
            end_roomcard = pGet.roomcard,
            cost_roomcard = msg.count,
            date = os.date("%Y-%m-%d %H:%M:%S"),
        }
        skynet.send(".mysql", "lua", "roomcard_log", roomcard_getmsg)
    end

    return {result="success", count = msg.count}
end

-- 更新玩家信息
function M.update_userinfo(msg)
    if not msg or not msg.userid or not msg.sign then
        return {result = "fail"}
    end

    local p = player_mgr:get(msg.userid)
    if not p then
        return {result = "fail"}
    end

    if p.sign ~= msg.sign then
        return {result = "sign fail"}
    end

    return {
        result = "success",
        score = p.score,
        roomcard = p.roomcard,
    }
end

return M
