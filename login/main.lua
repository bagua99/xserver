local skynet = require "skynet"

local function main()
    skynet.newservice("debug_console", 1800)

    skynet.newservice("xlog")
    skynet.call("xlog", "lua", "start")

    -- mysql
    skynet.newservice("mysql")
    skynet.call("mysql", "lua", "start", {
        host = "127.0.0.1",
        port = 3306,
        database = "xserver",
        user = "bagua",
        password = "bagua99",
        max_db_count = tonumber(skynet.getenv("max_db_count")),
    })

    -- 登陆http服务
    skynet.newservice("httplogin")

    skynet.newservice("wxlogin")

    -- 登陆服务
    local login = skynet.newservice("login")
    skynet.call(login, "lua", "start")

    skynet.exit()
end

skynet.start(main)
