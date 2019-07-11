local files = {
    "proto/protocol.pb",
    "proto/pdk.pb",
    "proto/nn.pb",
    "proto/dgnn.pb",
    "proto/nxphz.pb",
    "proto/csmj.pb",
    "proto/yzbp.pb",
}

local M = {}

function M:init()
    self.protobuf = require "protobuf"

    for _,f in ipairs(files) do
        self.protobuf.register_file(f)
    end
end

function M:encode(name, msg)
    return self.protobuf.encode(name, msg)
end

function M:decode(name, data)
    return self.protobuf.decode(name, data)
end

return M
