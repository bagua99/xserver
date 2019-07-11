local skynet = require "skynet"

local function main()
    skynet.newservice("debug_console", 2800)

    skynet.newservice("xlog")
    skynet.call(".xlog", "lua", "start")

    -- mysql
    skynet.newservice("mysql")
    skynet.call(".mysql", "lua", "start", {
        host = "127.0.0.1",
        port = 3306,
        database = "xserver",
        user = "bagua",
        password = "bagua99",
        max_db_count = tonumber(skynet.getenv("max_db_count")),
    })

    -- player_mgr
    skynet.newservice("player_mgr")

    -- room_mgr
    skynet.newservice("room_mgr")

    skynet.newservice("httpclient")
    skynet.newservice("httpserver")
    skynet.newservice("base_web_server")

    skynet.exit()
end

skynet.start(main)
