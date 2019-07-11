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
lua_cpath = root.."luaclib/?.so"
-- preload = "./examples/preload.lua"	-- run preload.lua before every lua service run
--snax = root.."examples/?.lua;"..root.."test/?.lua"
-- snax_interface_g = "snax_g"
cpath = root.."cservice/?.so"
-- daemon = "./skynet.pid"

--our path
luaservice = "./login/?.lua;./login/?/main.lua;"..luaservice
lua_path = "./lualib/?.lua;"..root.."/lualib/skynet/?.lua;"..root.."/lualib/skynet/db/?.lua;"..lua_path
lua_cpath = "./luaclib/?.so;"..lua_cpath

-- 配置信息
-- 最大数据库连接数量
max_db_count = 10
-- 登录服端口
LOGIN_LISTEN_PORT = 8888
