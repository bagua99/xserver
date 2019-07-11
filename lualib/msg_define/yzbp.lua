local tbl = {
    -- 永州包牌
    {id=601, name = "yzbp.GAME_PlayerEnterAck"},
    {id=602, name = "yzbp.GAME_PlayerLeaveAck"},
    {id=603, name = "yzbp.GAME_EnterGameAck"},
    {id=604, name = "yzbp.GAME_GameSceneAck"},
    {id=605, name = "yzbp.GAME_ReadyReq"},
    {id=606, name = "yzbp.GAME_ReadyAck"},
    {id=607, name = "yzbp.GAME_GameStartAck"},
    {id=608, name = "yzbp.GAME_CallScoreReq"},
    {id=609, name = "yzbp.GAME_CallScoreAck"},
    {id=610, name = "yzbp.GAME_MainCardReq"},
    {id=611, name = "yzbp.GAME_MainCardAck"},
    {id=612, name = "yzbp.GAME_SendBackCardAck"},
    {id=613, name = "yzbp.GAME_BuryCardReq"},
    {id=614, name = "yzbp.GAME_BuryCardAck"},
    {id=615, name = "yzbp.GAME_SurrenderReq"},
    {id=616, name = "yzbp.GAME_SurrenderAck"},
    {id=617, name = "yzbp.GAME_SurrenderVoteReq"},
    {id=618, name = "yzbp.GAME_SurrenderVoteAck"},
    {id=619, name = "yzbp.GAME_SurrenderVoteResultAck"},
    {id=620, name = "yzbp.GAME_OutCardReq"},
    {id=621, name = "yzbp.GAME_OutCardAck"},
    {id=622, name = "yzbp.GAME_BuckleBottomAck"},
    {id=623, name = "yzbp.GAME_PromptAck"},
    {id=624, name = "yzbp.GAME_GameEndAck"},
    {id=625, name = "yzbp.GAME_GameTotalEndAck"},
}

local M = {}

function M.register(f)
    for i,v in ipairs(tbl) do
        f(v.id, v.name)
    end
end

return M
