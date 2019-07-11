-- 游戏管理器(包含若干游戏)

local game = require "game"

local M = {}

function M:init()
    -- 游戏房卡
    self.game_card = {
        -- 跑得快
        [1] = {2, 4},
        -- 普通牛牛
        [2] = {1, 2},
        -- 地锅牛牛
        [3] = {4},
        -- 宁乡跑胡子
        [4] = {2, 4},
        -- 长沙麻将
        [5] = {2, 4},
        -- 永州包牌
        [6] = {2, 4},
    }

    self.tbl = {}
    for k, _ in pairs(self.game_card) do
        self.tbl[k] = game.new()
    end
end

function M:get(id)
    return self.tbl[id]
end

function M.get_roomcard(gameid, options)
    if not M.game_card[gameid] then
        print("get_roomcard error gameid=", gameid)
        return nil
    end
    local tbl_card = M.game_card[gameid]

    local index = nil
    for _, tData in pairs(options) do
        if tData.key == "room_card" then
            index = tData.snvalue
        end
    end
    if index == nil then
        print("get_roomcard error index==nil")
        return nil
    end

    if index <= 0 or index > #tbl_card then
        print("get_roomcard error index="..index..",nLen="..#tbl_card)
        return nil
    end
    local cost_card = tbl_card[index]
    local t =
    {
        ["key"] = "cost_card",
        ["snvalue"] = cost_card,
    }
    table.insert(options, t)

    return cost_card
end

return M
