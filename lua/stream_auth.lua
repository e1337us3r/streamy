ngx.req.read_body()
local args, err = ngx.req.get_post_args()
if not args then
    ngx.say("failed to get post args: ", err)
    return
end
local mysql = require "resty.mysql"
local db, err = mysql:new()
if not db then
    ngx.say("failed to instantiate mysql: ", err)
    return
end

db:set_timeout(1000) -- 1 sec

local ok, err, errcode, sqlstate = db:connect{
    host = "db",
    port = 3306,
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
local quoted_name = ngx.quote_sql_str(args.name)

local res, err, errcode, sqlstate =
    db:query("select id from stream where id=" .. quoted_name )
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

ngx.exit(ngx.OK)
