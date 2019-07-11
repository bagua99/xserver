local skynet = require "skynet"

local function main()
    skynet.newservice("debug_console",
        skynet.getenv("DEBUG_CONSOLE_PORT"))

    skynet.newservice("xlog")
    skynet.call("xlog", "lua", "start")

    skynet.newservice("httpclient")

    -- watchdog
    skynet.uniqueservice("dog")
    skynet.call("dog", "lua", "start", {
        addr = "0.0.0.0",
        port = skynet.getenv("GAME_PORT")
    })

    -- room_mgr
    skynet.uniqueservice("room_mgr")
    skynet.call("room_mgr", "lua", "start")

    -- http
    skynet.newservice("http")

    skynet.newservice("monitor")

    skynet.exit()
end

skynet.start(main)
