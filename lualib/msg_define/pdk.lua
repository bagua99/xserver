local tbl = {
    -- 跑得快
    {id=101, name = "pdk.GAME_PlayerEnterAck"},
    {id=102, name = "pdk.GAME_PlayerLeaveAck"},
    {id=103, name = "pdk.GAME_EnterGameAck"},
    {id=104, name = "pdk.GAME_GameSceneAck"},
    {id=105, name = "pdk.GAME_ReadyReq"},
    {id=106, name = "pdk.GAME_ReadyAck"},
    {id=107, name = "pdk.GAME_GameStartAck"},
    {id=108, name = "pdk.GAME_OutCardReq"},
    {id=109, name = "pdk.GAME_OutCardAck"},
    {id=110, name = "pdk.GAME_PassCardReq"},
    {id=111, name = "pdk.GAME_PassCardAck"},
    {id=112, name = "pdk.GAME_GameEndAck"},
    {id=113, name = "pdk.GAME_GameTotalEndAck"},
    {id=114, name = "pdk.GAME_PromptAck"},
}

local M = {}

function M.register(f)
    for i,v in ipairs(tbl) do
        f(v.id, v.name)
    end
end

return M
