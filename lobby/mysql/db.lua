local skynet = require "skynet"
local mysql = require "mysql"

-- 数据库连接数量
local max_db_count = 10

local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)
    M.init(o, ...)
    return o
end

function M:init(conf)
    self.dbcon_tbl = {}
    local function on_connect(db)
        db:query("set character set 'utf8'")     -- 读库
        db:query("set names 'utf8'")             -- 写库
    end

    self.conf = {
        host = conf.host,
        port = conf.port,
        database = conf.database,
        user = conf.user,
        password = conf.password,
        on_connect = on_connect,
    }

	max_db_count = conf.max_db_count
	for i = 1, max_db_count do
		local db = mysql.connect(self.conf)
		self.dbcon_tbl[i] = db
	end
end

-- 执行sql语句
function M:query(sql)
    local index = math.random(1, max_db_count)
    local dbcon = self.dbcon_tbl[index]

	local sleep = 100
	local noerr, data = pcall(dbcon.query, dbcon, sql)
	while noerr ~= true do
		if sleep < 3200 then
			sleep = sleep * 2
		end
		skynet.sleep(sleep)
		noerr, data = pcall(dbcon.query, dbcon, sql)
	end

	return data
end

return M
