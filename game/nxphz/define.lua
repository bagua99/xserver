
local M = {}

-- 游戏休闲状态
M.GAME_FREE             = 0
-- 游戏开始状态
M.GAME_PLAY             = 1

-- 正常结束
M.END_NORMAL            = 1
-- 解散结束
M.END_DISSOLVE          = 2

-- 游戏人数
M.GAME_PLAYER           = 3
-- 无效
M.INVALID_SEAT          = 0xFF

-- 动作定义
M.ACK_NULL              = 0x00					-- 空
M.ACK_TI                = 0x01					-- 提
M.ACK_PAO               = 0x02					-- 跑
M.ACK_WEI               = 0x04					-- 偎
M.ACK_CHI               = 0x08					-- 吃
M.ACK_CHI_EX            = 0x10					-- 吃
M.ACK_PENG              = 0x20					-- 碰
M.ACK_CHIHU             = 0x40					-- 胡

-- 吃牌类型
M.CK_NULL               = 0x00					-- 无效类型
M.CK_XXD                = 0x01					-- 小小大搭
M.CK_XDD                = 0x02					-- 小大大搭
M.CK_EQS                = 0x04					-- 二七十吃
M.CK_LEFT               = 0x10					-- 靠左对齐
M.CK_CENTER             = 0x20					-- 居中对齐
M.CK_RIGHT              = 0x40					-- 靠右对齐

-- 胡息类型
M.HUXI_TI_S             = 9                     -- 小提胡息
M.HUXI_TI_B             = 12                    -- 大提胡息
M.HUXI_PAO_S            = 6                     -- 小提胡息
M.HUXI_PAO_B            = 9                     -- 大提胡息
M.HUXI_WEI_S            = 3                     -- 小偎胡息
M.HUXI_WEI_B            = 6                     -- 大偎胡息
M.HUXI_PENG_S           = 1                     -- 小碰胡息
M.HUXI_PENG_B           = 3                     -- 大碰胡息
M.HUXI_27A_S            = 3                     -- 小27A胡息
M.HUXI_27A_B            = 6                     -- 大27A胡息
M.HUXI_123_S            = 3                     -- 小123胡息
M.HUXI_123_B            = 6                     -- 大123胡息

-- 数值定义
M.MAX_WEAVE                 = 7					-- 最大组合
M.MAX_WEAVE_CARD_COUNT		= 4					-- 组合最大牌数量
M.MAX_CARD					= 20				-- 最大牌
M.MAX_COUNT					= 21				-- 最大数目
M.MAX_REPERTORY				= 80				-- 最大库存
M.MAX_LEFT					= 19				-- 最大剩余牌
M.MIN_HU_XI					= 15				-- 胡牌最小胡息

M.MAX_ANALY_NUM             = 100
M.ANALYTYPE_PENG            = 1
M.ANALYTYPE_FENSHUN         = 2
M.ANALYTYPE_SHUN            = 3
M.ANALYTYPE_DXD             = 4

M.LIMIT_BASE                = 5                 -- 上限倍率

-- 胡牌类型
M.tHuPaiType =
{
	["TianHu"] = 5,				                -- 天胡
	["DiHu"] = 5,						        -- 地胡
	["PengPengHu"] = 5,				            -- 碰碰胡
	["HeiHu"] = 5,					            -- 黑胡
	["ShiHong"] = 2,					        -- 十红
	["YiDianHong"] = 4,				            -- 一点红
	["ShiBaDa"] = 5,				            -- 十八大
	["ShiBaXiao"] = 5,				            -- 十八小
	["ErBi"] = 2,					            -- 二比
	["SanBi"] = 3,					            -- 三比
	["SiBi"] = 4,					            -- 四比
	["ShuangPiao"] = 2,				            -- 双飘
}

return M
