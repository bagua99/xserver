local utils = require "utils"

-- 房间类，每个房间为一场比赛
local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)

    M.init(o, ...)

    return o
end

function M:init(info, addr)
    self.roomid = info.room.roomid
    self.owner = info.player.userid
    self.addr = addr
    self.ticket = tostring(math.random(os.time()))
    self.tbl_player =
    {
        [info.player.userid] = utils.copy_array(info.player)
    }
end

function M:get_addr()
    return self.addr
end

function M:add_player(player_info)
    self.tbl_player[player_info.userid] = utils.copy_array(player_info)
end

function M:remove_player(userid)
    self.tbl_player[userid] = nil
end

return M
