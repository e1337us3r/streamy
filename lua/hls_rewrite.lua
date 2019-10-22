local redis = require "resty.redis"
local red = redis:new()

red:set_timeouts(1000, 1000, 1000) -- 1 sec

local ok, err = red:connect("redis", 6379)
if not ok then
    ngx.status = ngx.INTERNAL_SERVER_ERROR
    ngx.say("failed to connect: ", err)
    return
end

local resCache, err = red:get(ngx.var[1])
if  resCache == nil then
    ngx.req.set_uri("/hls/".. resCache .. "/index.m3u8",false)
    local ok, err = red:set_keepalive(10000, 100)

    if not ok then
        ngx.status = ngx.INTERNAL_SERVER_ERROR
        ngx.say("failed to set keepalive: ", err)
        return
    end
    return
end



local mysql = require "resty.mysql"
local db, err = mysql:new() 
if not db then 
    ngx.say("failed to instantiate mysql: ", err) return 
end 
db:set_timeout(1000) -- 1 sec 
local ok, err, errcode, sqlstate = db:connect{
    host = "db", port = 3306,
    database = "resty", 
    user = "root", 
    password = "example",
    charset = "utf8", 
    max_packet_size = 1024 * 1024,
} 
    
if not ok then 
    ngx.status = ngx.HTTP_NOT_FOUND
    ngx.say("failed to connect: ", err, ": ", errcode, " ", sqlstate)
    return 
end
        
local quoted_name = ngx.quote_sql_str(ngx.var[1])
local res, err, errcode, sqlstate = db:query("select id from stream where username=" .. quoted_name )
        
if not res then 
    ngx.status = ngx.HTTP_NOT_FOUND 
    ngx.say("bad result: ", err, ": ", errcode, ": ", sqlstate, ".") 
    return 
end
        
if table.getn(res) == 0 then
    ngx.status = ngx.HTTP_NOT_FOUND 
    ngx.say("Stream id not found.") 
    return 
end 

-- put it into the connection pool of size 100, 
-- with 10 seconds max idle timeout 
local ok, err = db:set_keepalive(10000, 100) 

if not ok then 
    ngx.status = ngx.HTTP_NOT_FOUND 
    ngx.say("failed to set keepalive: ", err) 
    return 
end 

-- cache the stream key
local resCache, err = red:set(ngx.var[1],res[1]["id"])
if not resCache then
    ngx.status = ngx.INTERNAL_SERVER_ERROR
    ngx.say("Failed to cache the stream key: ", err)
    return
end 

ngx.req.set_uri("/hls/".. res[1]["id"] .. "/index.m3u8",false)