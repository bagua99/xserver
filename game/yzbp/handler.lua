local match = require "match"
local room = require "room"
local player_mgr = require "player_mgr"

local M = {}

function M.chat(userid, msg)
    local _player = player_mgr:get(userid)
    if not _player then
        return
    end

    local broad =
    {
        wChairID = _player.seat,
        nMsgID = msg.nMsgID,
        text = msg.text,
    }
    player_mgr:broadcast("protocol.ChatAck", broad)
end

function M.VoiceChatReq(userid, msg)
    local _player = player_mgr:get(userid)
    if not _player then
        return
    end

    local broad =
    {
       userid  = _player.userid,
       voice = msg.voice
    }
    player_mgr:broadcast_but(_player.userid, "protocol.VoiceChatAck", broad)
end

function M.GameSceneReq(userid, msg)
    local _player = player_mgr:get(userid)
    if not _player then
        return
    end
    -- 上线
    _player:online()

    -- 返回信息
	local ack_msg =
    {
        err = 0,
        players = player_mgr:dump(),
        room =
        {
             options = room.dump(),
        },
    }
    _player:send("yzbp.GAME_EnterGameAck", ack_msg)

    -- 广播
    local broad =
    {
        userData = _player:dump()
    }
    player_mgr:broadcast_but(_player.userid, "yzbp.GAME_PlayerEnterAck", broad)

    -- 场景重连
    match:onGameScene(userid, msg)
end

function M.GameLBSVoteReq(userid, msg)
    match:GameLBSVoteReq(userid, msg)
end

function M.GameLeaveReq(userid, msg)
    match:GameLeaveReq(userid, msg)
end

function M.GameVoteReq(userid, msg)
    match:GameVoteReq(userid, msg)
end

function M.GAME_ReadyReq(userid, msg)
    match:GAME_ReadyReq(userid, msg)
end

function M.GAME_CallScoreReq(userid, msg)
    match:GAME_CallScoreReq(userid, msg)
end

function M.GAME_MainCardReq(userid, msg)
    match:GAME_MainCardReq(userid, msg)
end

function M.GAME_SurrenderReq(userid, msg)
    match:GAME_SurrenderReq(userid, msg)
end

function M.GAME_SurrenderVoteReq(userid, msg)
    match:GAME_SurrenderVoteReq(userid, msg)
end

function M.GAME_BuryCardReq(userid, msg)
    match:GAME_BuryCardReq(userid, msg)
end

function M.GAME_OutCardReq(userid, msg)
    match:GAME_OutCardReq(userid, msg)
end

function M.register()
    M.tbl =
    {
        ["protocol.ChatReq"] = M.chat,
        ["protocol.VoiceChatReq"] = M.VoiceChatReq,
        ["protocol.GameSceneReq"] = M.GameSceneReq,
        ["protocol.GameLBSVoteReq"] = M.GameLBSVoteReq,
        ["protocol.GameLeaveReq"] = M.GameLeaveReq,
        ["protocol.GameVoteReq"] = M.GameVoteReq,
        ["yzbp.GAME_ReadyReq"] = M.GAME_ReadyReq,
        ["yzbp.GAME_CallScoreReq"] = M.GAME_CallScoreReq,
        ["yzbp.GAME_MainCardReq"] = M.GAME_MainCardReq,
        ["yzbp.GAME_SurrenderReq"] = M.GAME_SurrenderReq,
        ["yzbp.GAME_SurrenderVoteReq"] = M.GAME_SurrenderVoteReq,
        ["yzbp.GAME_BuryCardReq"] = M.GAME_BuryCardReq,
        ["yzbp.GAME_OutCardReq"] = M.GAME_OutCardReq,
    }
end

function M.dispatch(userid, name, msg)
    local f = M.tbl[name]
    if f then
        f(userid, msg)
    else
        error("yzbp msg have no handler "..name)
    end
end

return M
