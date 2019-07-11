local skynet = require "skynet"
local player_mgr = require "player_mgr"
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
        nMsgID = msg.nMsgID
    }

    player_mgr:broadcast("protocol.ChatAck", broad)
end

-- 离开请求
function M.GAME_GameLeaveReq(userid, msg)
    match:GAME_GameLeaveReq(userid, msg)
end

-- 投票请求
function M.GAME_GameVoteReq(userid, msg)
    match:GAME_GameVoteReq(userid, msg)
end

-- 准备、取消准备
function M.GAME_ReadyReq(userid, msg)
    local p = player_mgr:get(userid)
    if not p then
        print("ready can't find player")
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
    player_mgr:broadcast("nn.GAME_ReadyAck", broad)

    -- 所有人准备好了
    if player_mgr:checkReady() then
        skynet.timeout(50, function() match:start() end)
    end
end

-- 开始
function M.GAME_BeginReq(_,  _)

end

-- 抢庄、不抢庄
function M.GAME_GameBankReq(_,  _)

end

-- 下注
function M.GAME_CallScoreReq(userid, msg)
    local p = player_mgr:get(userid)
    if not p then
        print("callscore can't find player")
        return
    end

    if match.status ~= "callscore" then
        print("nn not callscore status")
        return
    end

    local t = {1,3,5,10}
    local callscore = t[msg.nScoreIndex] or 1
    p:call_score(1)

    local broad = {
        nCallScoreUser = p.seat,
        nCallScore = callscore
    }
    player_mgr:broadcast("nn.GAME_CallScoreAck", broad)

    -- 所有人下完注
    if player_mgr:check_call_score() then
        match:fapai()
        match:result()
    end
end

function M.register()
    M.tbl = {
        ["protocol.ChatReq"] = M.chat,
        ["nn.GAME_GameLeaveReq"] = M.GAME_GameLeaveReq,
        ["nn.GAME_GameVoteReq"] = M.GAME_GameVoteReq,
        ["nn.GAME_ReadyReq"] = M.GAME_ReadyReq,
        ["nn.GAME_BeginReq"] = M.GAME_BeginReq,
        ["nn.GAME_GameBankReq"] = M.GAME_GameBankReq,
        ["nn.GAME_CallScoreReq"] = M.GAME_CallScoreReq
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
