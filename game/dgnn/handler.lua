local skynet = require "skynet"
local player_mgr = require "player_mgr"
local room = require "room"
local match = require "match"

local M = {
    tbl = {}
}

function M.chat(userid, msg)
    local p = player_mgr:get(userid)
    if not p then
        return
    end

    local broad = {
        wChairID = p.seat,
        nMsgID = msg.nMsgID,
        text = msg.text,
    }

    player_mgr:broadcast("protocol.ChatAck", broad)
end

function M.GameSceneReq(userid, _)
    local p = player_mgr:get(userid)
    if not p then
        return
    end
    -- 上线
    p:online()

    -- 创建玩家对象
    local enter_msg =
    {
        err = 0,
        players = player_mgr:dump(match, userid),
        room =
        {
             options = room.dump(),
        },
    }
    p:send("dgnn.GAME_EnterGameAck", enter_msg)

    -- 返回信息
    local scene_msg =
    {
        err = 0,
        room =
        {
             options = room.dump(),
        },
        status = match.status,
        players = player_mgr:dump(match, p.userid),
        bank_seat = match.bank_user,
        bank_score = match.bank_score,
        nDissoveSeat = match.nDissoveSeat,
        nDissoveTime = match:getDissoveTime(),
        vote = player_mgr:get_vote_state(),
        bank_count = match.bank_count
    }
    p:send("dgnn.GAME_GameSceneAck", scene_msg)

    -- 广播
    local broad = {
        userData = p:dump(match, false)
    }
    player_mgr:broadcast_but(p.userid,"dgnn.GAME_PlayerEnterAck", broad)
end

function M.GameLBSVoteReq(userid, msg)
    match:GameLBSVoteReq(userid, msg)
end

function M.VoiceChatReq(userid, msg)
    local p = player_mgr:get(userid)
    if not p then
        return
    end

    local broad = {
       userid  = p.userid,
       voice = msg.voice
    }

    player_mgr:broadcast_but(p.userid, "protocol.VoiceChatAck", broad)
end

-- 离开请求
function M.GameLeaveReq(userid, msg)
    match:GameLeaveReq(userid, msg)
end

-- 投票请求
function M.GameVoteReq(userid, msg)
    match:GameVoteReq(userid, msg)
end

-- 准备、取消准备
function M.GAME_ReadyReq(userid, msg)
    local p = player_mgr:get(userid)
    if not p then
        print("ready can't find player")
        return
    end
    if p.out then
        return
    end
    if match.status ~= "ready" then
        print("nn not ready status")
        return
    end

    p:setReady(msg.bAgree)

    local broad = {
        wChairID = p.seat,
        bAgree = msg.bAgree
    }
    player_mgr:broadcast("dgnn.GAME_ReadyAck", broad)

    -- 所有人准备好了
    if room.get_status() == "play" and player_mgr:check_ready() then
        skynet.timeout(50, function() match:to_callscore() end)
    end
end

-- 请求下庄
function M.GAME_XiaZhuang(userid, _)
    local p = player_mgr:get(userid)
    if not p then
        return
    end

    -- 非庄家
    if match.bank_user ~= p.seat then
        return
    end

    -- 非结算状态
    if match.status ~= "ready" then
        return
    end

    -- 当庄次数不够
    if match.bank_count < room.min_bank_count then
        return
    end

    match:xia_zhuang()

    if not match:next_zhuang(p.seat) then
        player_mgr:notify_big_result()
        match:big_result()
    else
        p:setReady(true)
        if player_mgr:check_ready() then
            match:to_callscore()
        end
    end
end

-- 房主点击开始开始
function M.GAME_BeginReq(userid,  _)
    local p = player_mgr:get(userid)
    if not p then
        return
    end

    if room.get_option("master_id") ~= userid then
        print("error game begin req not room master_id")
        return
    end

    if player_mgr:check_begin() then
        match:begin()
        room.set_status("play")
    end
end

-- 下注
function M.GAME_CallScoreReq(userid, msg)
    local p = player_mgr:get(userid)
    if not p then
        print("callscore can't find player")
        return
    end

    if p.out then
        return
    end

    if match.status ~= "callscore" then
        print("nn not callscore status")
        return
    end

    if p.seat == match.bank_user then
        return
    end

    if p.score <= 0 then
        return
    end

    local t = {1,2,3,4,5}
    local callscore = t[msg.nScoreIndex] or 1
    if callscore*3 > p.score then
        return
    end

    p:call_score(callscore)

    local broad = {
        nCallScoreUser = p.seat,
        nCallScore = callscore
    }
    player_mgr:broadcast_but(p.userid, "dgnn.GAME_CallScoreAck", broad)

    broad.cards = p.cards
    broad.type = p:get_card_type()
    p:send("dgnn.GAME_CallScoreAck", broad)

    -- 所有人下完注
    if player_mgr:check_call_score(match) then
        match:to_suanniu()
    end
end

-- 自动算牛
function M.GAME_GameSuanNiuReq(userid, _)
    local p = player_mgr:get(userid)
    if not p then
        return
    end

    if p.out then
        return
    end

    if match.status ~= "suanniu" then
        return
    end

    if not p:suan_niu() then
        return
    end

    local broad = {
        seat = p.seat,
        cards = p.cards,
        type = p:get_card_type()
    }
    player_mgr:broadcast("dgnn.GAME_GameSuanNiuAck", broad)
     -- 回放
    table.insert(match.record.game.data, {time = os.time(), name = "dgnn.GAME_GameSuanNiuAck", msg = broad})

    if player_mgr:check_suanniu() then
         match:result()
    end
end

function M.register()
    M.tbl = {
        ["protocol.ChatReq"] = M.chat,
        ["protocol.VoiceChatReq"] = M.VoiceChatReq,
        ["protocol.GameSceneReq"] = M.GameSceneReq,
        ["protocol.GameLBSVoteReq"] = M.GameLBSVoteReq,
        ["protocol.GameLeaveReq"] = M.GameLeaveReq,
        ["protocol.GameVoteReq"] = M.GameVoteReq,
        ["dgnn.GAME_ReadyReq"] = M.GAME_ReadyReq,
        ["dgnn.GAME_XiaZhuang"] = M.GAME_XiaZhuang,
        ["dgnn.GAME_BeginReq"] = M.GAME_BeginReq,
        ["dgnn.GAME_GameBankReq"] = M.GAME_GameBankReq,
        ["dgnn.GAME_CallScoreReq"] = M.GAME_CallScoreReq,
        ["dgnn.GAME_GameSuanNiuReq"] = M.GAME_GameSuanNiuReq,
    }
end

function M.dispatch(userid, name, msg)
    local f = M.tbl[name]
    if f then
        f(userid, msg)
    else
        error("nn msg have no handler "..name)
    end
end

return M
