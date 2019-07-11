local utils = require "utils"
local crc32 = require "crc32"
local msg_define = require "msg_define.mgr"
local pbc = require "pbc"

local M = {}

-- 组包
function M.pack(name, msg)
    local proto_id = msg_define.name_2_id(name)
    local buf = pbc:encode(name, msg)
    local len = 2 + #buf
    local head = string.pack(">HH", len, proto_id)
    return head .. buf
end

-- 拆包
function M.unpack(data)
    local data = utils.xor(data)
    local id = string.unpack(">H", data)
    local buf = string.sub(data, 3, #data-10)
    local name = msg_define.id_2_name(id)
    local msg = pbc:decode(name, buf)
    -- 包序号
    local index = string.sub(data, 2+#buf+1,2+#buf+2)
    index = string.unpack(">H", index)
    -- 包crc32校验
    local crcdata = string.sub(data, 1, #data-8)
    local crc = string.sub(data,2+#buf+3)
    if crc ~= crc32.hash(crcdata) then
        print("数据包校验crc32失败")
        return
    end

    return name, msg, index
end

return M
