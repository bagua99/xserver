local M = {}

-- 游戏休闲状态
M.game_free = 0
-- 游戏开始状态
M.game_play = 1

-- 正常结束
M.end_normal = 1
-- 解散结束
M.end_dissolve = 2

-- 游戏人数
M.player_count = 3
-- 游戏牌数
M.card_count = 16
-- 无效
M.invalid_seat = 0xFF
-- 炸弹分数
M.bomb_score = 10

return M
