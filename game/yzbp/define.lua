local M = {}

-- 游戏休闲状态
M.game_free = 0
-- 游戏叫分状态
M.game_score = 1
-- 游戏叫主状态
M.game_main_card = 2
-- 游戏埋底状态
M.game_bury_card = 3
-- 游戏投降状态
M.game_surrender = 4
-- 游戏开始状态
M.game_play = 5

-- 正常结束
M.end_normal = 1
-- 解散结束
M.end_dissolve = 2
-- 投降结束
M.end_surrender = 3

-- 游戏人数
M.player_count = 4
-- 游戏牌数
M.card_count = 19
-- 无效
M.invalid_seat = 0xFF
-- 最低叫分
M.min_call_score = 80
-- 最高叫分
M.max_call_score = 200
-- 底牌数量
M.back_card_count = 8

-- 出牌
M.out_card_out = 0
-- 新一轮
M.out_card_new_turn = 1
-- 扣底
M.out_card_buckle_bottom = 2

return M
