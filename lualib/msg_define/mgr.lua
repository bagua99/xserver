local id_2_name_tbl = {}
local  name_2_id_tbl = {}

local M = {}

function M.init()
    M.register_mod("msg_define.protocol")
    M.register_mod("msg_define.pdk")
    M.register_mod("msg_define.nn")
    M.register_mod("msg_define.dgnn")
    M.register_mod("msg_define.nxphz")
    M.register_mod("msg_define.csmj")
    M.register_mod("msg_define.yzbp")
end

function M.register_mod(mod)
    local m = require(mod)
    m.register(M.register)
end

function M.register(id, name)
    id_2_name_tbl[id] = name
    name_2_id_tbl[name] = id
end

function M.name_2_id(name)
    return name_2_id_tbl[name]
end

function M.id_2_name(id)
    return id_2_name_tbl[id]
end

M.init()

return M
