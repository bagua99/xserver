local tbl = {
    -- 地锅牛牛
    {id=501, name="csmj.GAME_PlayerEnterAck"},
    {id=502, name="csmj.GAME_PlayerLeaveAck"},
    {id=503, name="csmj.GAME_EnterGameAck"},
    {id=504, name="csmj.GAME_GameSceneAck"},
    {id=505, name="csmj.GAME_ReadyReq"},
    {id=506, name="csmj.GAME_ReadyAck"},
    {id=507, name="csmj.GAME_BeginReq"},
    {id=508, name="csmj.GAME_GameStartAck"},
    {id=509, name="csmj.GAME_GameEndAck"},
    {id=510, name="csmj.GAME_GameTotalEndAck"},
}

local M = {}

function M.register(f)
    for i,v in ipairs(tbl) do
        f(v.id, v.name)
    end
end

return M
