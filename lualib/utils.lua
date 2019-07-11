local M = {}

function M.str_2_table(str)
    local func_str = "return "..str
    local func = load(func_str)
    return func()
end

local function serialize(obj)
    local lua = ""
    local t = type(obj)
    if t == "number" then
        lua = lua .. obj
    elseif t == "boolean" then
        lua = lua .. tostring(obj)
    elseif t == "string" then
        lua = lua .. string.format("%q", obj)
    elseif t == "table" then
        lua = lua .. "{"
        for k, v in pairs(obj) do
            lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
        end
        local metatable = getmetatable(obj)
        if metatable ~= nil and type(metatable.__index) == "table" then
            for k, v in pairs(metatable.__index) do  
                lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
            end
        end
        lua = lua .. "}"
    elseif t == "nil" then
        return "nil"
    elseif t == "userdata" then
        return "userdata"
    elseif t == "function" then
        return "function"
    elseif t == "thread" then
        return "thread"
    else
        error("can not serialize a " .. t .. " type.")
    end
    return lua
end

M.table_2_str = serialize

function M.print(o)
    print(serialize(o))
end

function M.obj_serialize(o)
    return serialize(o)
end

function M.print_array(o)
    local str = "{"
    for k,v in ipairs(o) do
        str = str .. serialize(v) .. ","
    end
    str = str .. "}"
    print(str)
end

function M.dump_table_2_file(tbl, name)
    local str = M.table_2_str(tbl)

    str = "return "..str
    local file = io.open(name, "w");
    file:write(str)
    file:close()
end

function M.copy_array(t)
    local tmp = {}
    for _,v in ipairs(t) do
        table.insert(tmp, v)
    end

    return tmp
end

function M.copy_table(t)
    if type(t) ~= "table" then
        return nil
    end

    local r = {}
    for i,v in pairs(t) do
        local v_type = type(v)
        if v_type == "table" then
            r[i] = M.copy_table(v)
        elseif v_type == "thread" then
            r[i] = v
        elseif v_type == "userdata" then
            r[i] = v
        else
            r[i] = v
        end
    end

    return r
end

function M.rand_table(t)
    local n = #t
    for i = 1, n do
        local j = math.random(i, n)
        if j > i then
            t[i], t[j] = t[j], t[i]
        end
    end
end

local b64chars = 'srqponml-_9876543YXWVUTSRQPONMLKJI210kjiCBAhgfedcbaZHGFzyxwvutED'
function M.base64encode(source_str)
    local s64 = ''
    local str = source_str

    while #str > 0 do
        local bytes_num = 0
        local buf = 0

        for byte_cnt=1,3 do
            buf = (buf * 256)
            if #str > 0 then
                buf = buf + string.byte(str, 1, 1)
                str = string.sub(str, 2)
                bytes_num = bytes_num + 1
            end
        end

        for group_cnt=1,(bytes_num+1) do
            local b64char = math.fmod(math.floor(buf/262144), 64) + 1
            s64 = s64 .. string.sub(b64chars, b64char, b64char)
            buf = buf * 64
        end

        for fill_cnt=1,(3-bytes_num) do
            s64 = s64 .. '.'
        end
    end

    return s64 
end

function M.base64decode(str64)
    if not str64 then return nil end
    if #str64 < 3 then return "" end
    local temp={}
    for i=1,64 do
        temp[string.sub(b64chars,i,i)] = i
    end
    temp['.']=0
    local str=""
    for i=1,#str64,4 do
        if i>#str64 then
            break
        end
        local data = 0
        local str_count=0
        for j=0,3 do
            local str1=string.sub(str64,i+j,i+j)
            if not temp[str1] then
                return
            end
            if temp[str1] < 1 then
                data = data * 64
            else
                data = data * 64 + temp[str1]-1
                str_count = str_count + 1
            end
        end
        for j=16,0,-8 do
            if str_count > 0 then
                str=str..string.char(math.floor(data/2^j))
                data=data % (2^j)
                str_count = str_count - 1
            end
        end
    end

    local last = tonumber(string.byte(str, string.len(str), string.len(str)))
    if last == 0 then
        str = string.sub(str, 1, string.len(str) - 1)
    end
    return str
end

function M.decodeurl(s)
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    return s
end

function M.encodeurl(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

function M.xor(str, key)
    local ret = ""
    local key = key or "cigam"
    for i=1,#str do
       local data = string.byte(str, i)
       local temp = data ~  string.byte(string.sub(key, 1, 1))
       for i = 2, string.len(key) do
           temp = temp ~ string.byte(string.sub(key, i, i))
       end
       ret = ret .. string.char(temp)
    end
    return ret
end

-- 过滤特殊字符
function M.filter_spec_chars(s)  
    local ss = {}  
    for k = 1, #s do  
        local c = string.byte(s,k)  
        if not c then break end  
        if (c>=48 and c<=57) or (c>= 65 and c<=90) or (c>=97 and c<=122) then  
            table.insert(ss, string.char(c))  
        elseif c>=228 and c<=233 then  
            local c1 = string.byte(s,k+1)  
            local c2 = string.byte(s,k+2)  
            if c1 and c2 then  
                local a1,a2,a3,a4 = 128,191,128,191  
                if c == 228 then a1 = 184  
                elseif c == 233 then a2,a4 = 190,c1 ~= 190 and 191 or 165  
                end  
                if c1>=a1 and c1<=a2 and c2>=a3 and c2<=a4 then  
                    k = k + 2  
                    table.insert(ss, string.char(c,c1,c2))  
                end  
            end  
        end  
    end  
    return table.concat(ss)  
end

return M

