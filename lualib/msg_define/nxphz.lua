local tbl = {
    -- 宁乡跑胡子
    {id=401, name = "nxphz.GAME_PlayerEnterAck"},
    {id=402, name = "nxphz.GAME_PlayerLeaveAck"},
    {id=403, name = "nxphz.GAME_EnterGameAck"},
    {id=404, name = "nxphz.GAME_GameSceneAck"},
    {id=405, name = "nxphz.GAME_ReadyReq"},
    {id=406, name = "nxphz.GAME_ReadyAck"},
    {id=407, name = "nxphz.GAME_GameStartAck"},
    {id=408, name = "nxphz.GAME_OutCardReq"},
    {id=409, name = "nxphz.GAME_OutCardAck"},
	{id=410, name = "nxphz.GAME_OutCardNotifyAck"},
    {id=411, name = "nxphz.GAME_SendCardAck"},
    {id=412, name = "nxphz.GAME_OperateCardReq"},
    {id=413, name = "nxphz.GAME_OperateCardAck"},
    {id=414, name = "nxphz.GAME_TiCardAck"},
    {id=415, name = "nxphz.GAME_WeiCardAck"},
    {id=416, name = "nxphz.GAME_PaoCardAck"},
    {id=417, name = "nxphz.GAME_ChiCardAck"},
    {id=418, name = "nxphz.GAME_PengCardAck"},
    {id=419, name = "nxphz.GAME_GameEndAck"},
    {id=420, name = "nxphz.GAME_GameTotalEndAck"},
}

local M = {}

function M.register(f)
    for i,v in ipairs(tbl) do
        f(v.id, v.name)
    end
end

return M
