local utils = require "utils"
local crypt = require "skynet.crypt"
local md5 = require "md5"

local M = {}

local key = "lehu"
function M.crypt(host)
    local str = crypt.hexencode(utils.xor(host, key))
    local sign = crypt.hexencode(md5.sum(str.."hello"))

    return str..sign
end

return M
