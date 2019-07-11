local M = {}

function M:init(info)
    self.roomid = info.room.roomid
    self.ownerid = info.player.userid
    self.options = {}
end

function M:get_option(key)
    return self.options[key]
end

function M:dump()
    return self.options
end

return M
