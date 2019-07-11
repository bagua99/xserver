local tbl = {
    -- 普通牛牛
    {id=201, name="nn.GAME_GameLeaveReq"},
    {id=202, name="nn.GAME_GameLeaveAck"},
    {id=203, name="nn.GAME_GameVoteReq"},
    {id=204, name="nn.GAME_GameVoteAck"},
    {id=205, name="nn.GAME_GameVoteResultAck"},
    {id=206, name="nn.GAME_PlayerEnterAck"},
    {id=207, name="nn.GAME_PlayerLeaveAck"},
    {id=208, name="nn.GAME_EnterGameAck"},
    {id=209, name="nn.GAME_GameSceneAck"},
    {id=210, name="nn.GAME_ReadyReq"},
    {id=211, name="nn.GAME_ReadyAck"},
    {id=212, name="nn.GAME_BeginReq"},
    {id=213, name="nn.GAME_GameStartAck"},
    {id=214, name="nn.GAME_CallScoreReq"},
    {id=215, name="nn.GAME_CallScoreAck"},
    {id=216, name="nn.GAME_BeginBankAck"},
    {id=217, name="nn.GAME_GameBankReq"},
    {id=218, name="nn.GAME_GameBankAck"},
    {id=219, name="nn.GAME_GameEndAck"},
    {id=220, name="nn.GAME_GameTotalEndAck"},
}

local M = {}

function M.register(f)
    for i,v in ipairs(tbl) do
        f(v.id, v.name)
    end
end

return M
