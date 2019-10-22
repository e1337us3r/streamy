local redis = require "resty.redis"
local red = redis:new()

red:set_timeouts(1000, 1000, 1000) -- 1 sec

local ok, err = red:connect("redis", 6379)
if not ok then
    ngx.status = ngx.INTERNAL_SERVER_ERROR
    ngx.say("failed to connect: ", err)
    return
end

local res, err = red:get(ngx.var[1])
if not res then
    ngx.status = ngx.INTERNAL_SERVER_ERROR
    ngx.say("Failed to get stream from cache: ", err)
    return
end

if res == ngx.null then
    ngx.status = ngx.NOT_FOUND
    ngx.say("Steam not found.")
    return
end


-- put it into the connection pool of size 100,
-- with 10 seconds max idle time
local ok, err = red:set_keepalive(10000, 100)
if not ok then
    ngx.status = ngx.INTERNAL_SERVER_ERROR
    ngx.say("failed to set keepalive: ", err)
    return
end

ngx.req.set_uri("/hls/".. res .. "/"..ngx.var[2]..".ts",false)
