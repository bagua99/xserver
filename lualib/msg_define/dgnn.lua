local tbl = {
    -- 地锅牛牛
    {id=301, name="dgnn.GAME_PlayerEnterAck"},
    {id=302, name="dgnn.GAME_PlayerLeaveAck"},
    {id=303, name="dgnn.GAME_EnterGameAck"},
    {id=304, name="dgnn.GAME_GameSceneAck"},
    {id=305, name="dgnn.GAME_ReadyReq"},
    {id=306, name="dgnn.GAME_ReadyAck"},
    {id=307, name="dgnn.GAME_XiaZhuang"},
    {id=308, name="dgnn.GAME_BeginReq"},
    {id=309, name="dgnn.GAME_GameStartAck"},
    {id=310, name="dgnn.GAME_CallScoreReq"},
    {id=311, name="dgnn.GAME_CallScoreAck"},
    {id=312, name="dgnn.GAME_GameEndAck"},
    {id=313, name="dgnn.GAME_GameXiaZhuangAck"},
    {id=314, name="dgnn.GAME_GameShangZhuangAck"},
    {id=315, name="dgnn.GAME_GameTotalEndAck"},
    {id=316, name="dgnn.GAME_GameSuanNiuBeginAck"},
    {id=317, name="dgnn.GAME_GameSuanNiuReq"},
    {id=318, name="dgnn.GAME_GameSuanNiuAck"},
    {id=319, name="dgnn.GAME_GameOutAck"},
}

local M = {}

function M.register(f)
    for i,v in ipairs(tbl) do
        f(v.id, v.name)
    end
end

return M
