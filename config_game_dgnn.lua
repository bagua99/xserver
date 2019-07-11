root = "./skynet/"
thread = 8
harbor = 0
logger = nil
logpath = "."
start = "main"	-- main script
bootstrap = "snlua bootstrap"	-- The service for bootstrap
luaservice = root.."service/?.lua;"..root.."test/?.lua;"
lualoader = root .. "lualib/loader.lua"
lua_path = root.."lualib/?.lua;"..root.."lualib/?/init.lua"
lua_cpath = "./luaclib/?.so;".. root .. "luaclib/?.so"
-- preload = "./examples/preload.lua"	-- run preload.lua before every lua service run
snax = root.."examples/?.lua;"..root.."test/?.lua"
-- snax_interface_g = "snax_g"
cpath = root.."cservice/?.so"
-- daemon = "./skynet.pid"

--our path
luaservice = "./game/?.lua;./game/?/main.lua;"..luaservice
lua_path = "./lualib/?.lua;"..lua_path
lua_cpath = "./luaclib/?.so;"..lua_cpath

LOBBY_HOST = "127.0.0.1:7702"

DEBUG_CONSOLE_PORT = 7730
GAME_ID = 3
SERVER_ID = 1
GAME_WEB_PORT = 7731
SERVER_HOST = "127.0.0.1:7731"
GAME_ADDR = "127.0.0.1"
GAME_PORT = 7831

RECORD_HOST = "127.0.0.1:9100"
