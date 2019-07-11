local M = {}

function M:init()
    math.randomseed(os.time())
    self.used = {}
end

function M:gen_id()
    local id
    while true do
        id =  math.random(100000, 999999)
        if not self.used[id] then
            self.used[id] = os.time()
            break
        end
    end

    return id
end

function M:revert_id(id)
    if id <= 0 then
        return
    end

    self.used[id] = nil
end

function M:use_id(id)
    if id <= 0 then
        return
    end

    self.used[id] = os.time()
end

return M
