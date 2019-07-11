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
luaservice = "./lobby/?.lua;./lobby/?/main.lua;"..luaservice
lua_path = "./lualib/?.lua;"..root.."./lualib/?.lua;"..root.."/lualib/skynet/?.lua;"..root.."/lualib/skynet/db/?.lua;"..lua_path
lua_cpath = "./luaclib/?.so;"..lua_cpath

-- 最大数据库连接数量
max_db_count = 10
-- 客户端请求web
BASE_WEB_PORT = 7701
-- 服务器通信web
LOBBY_WEB_PORT = 7702
