local tbl = {
    -- 登陆协议
    {id=1, name = "protocol.CL_LoginLobbyReq"},
    {id=2, name = "protocol.CL_LoginLobbyAck"},
    {id=3, name = "protocol.CL_ReplayListReq"},
    {id=4, name = "protocol.CL_ReplayListAck"},
    {id=5, name = "protocol.CL_ReplayDetailReq"},
    {id=6, name = "protocol.CL_ReplayDetailAck"},
    {id=7, name = "protocol.CL_CreateGameReq"},
    {id=8, name = "protocol.CL_CreateGameAck"},
    {id=9, name = "protocol.CL_JoinGameReq"},
    {id=10, name = "protocol.CL_JoinGameAck"},
    {id=11, name = "protocol.CL_AddUserRoomCardReq"},
    {id=12, name = "protocol.CL_BroadCastAck"},
    {id=13, name = "protocol.CL_UpdateUserDataAck"},
    {id=14, name = "protocol.EnterGameReq"},
    {id=15, name = "protocol.EnterGameAck"},
    {id=16, name = "protocol.ChatReq"},
    {id=17, name = "protocol.ChatAck"},
    {id=18, name = "protocol.HeartBeatReq"},
    {id=19, name = "protocol.HeartBeatAck"},
    {id=20, name = "protocol.UserOfflineAck"},
    {id=21, name = "protocol.VoiceChatReq"},
    {id=22, name = "protocol.VoiceChatAck"},
    {id=23, name = "protocol.GameSceneReq"},
    {id=24, name = "protocol.GameLBSVoteReq"},
    {id=25, name = "protocol.GameLBSVoteAck"},
    {id=26, name = "protocol.GameLeaveReq"},
    {id=27, name = "protocol.GameLeaveAck"},
    {id=28, name = "protocol.GameVoteReq"},
    {id=29, name = "protocol.GameVoteAck"},
    {id=30, name = "protocol.GameVoteResultAck"},
}

local M = {}

function M.register(f)
    for i,v in ipairs(tbl) do
        f(v.id, v.name)
    end
end

return M
