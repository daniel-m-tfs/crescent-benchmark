-- bench.lua — Crescent 1.x (Luvit) benchmark entrypoint.
-- Same endpoints as every app in ../ (see ../../README.md). No logging,
-- CORS, rate limit or security middleware: only the framework core.
-- Start: PORT=8101 DB_NAME=crescent_bench ... luvit bench.lua
require("./bootstrap")

-- The 1.x env helper gives the .env file priority over the process
-- environment; the runner passes everything through the environment.
require("crescent.utils.env")._cache = {}

local Crescent = require("crescent")
local MySQL = require("crescent.database.mysql")
local Model = require("crescent.database.model")

local Item = Model:extend({
    table = "bench_items",
    primary_key = "id",
    timestamps = false,
    fillable = { "name", "value" },
})

local port = tonumber(os.getenv("PORT") or "8101")
local app = Crescent.new({
    server = {
        host = "127.0.0.1",
        port = port,
        max_body_size = 1024 * 1024,
        request_timeout = 30000,
        max_concurrent_requests = 100000,
    },
})

local function row(r)
    return { id = tonumber(r.id), name = r.name, value = tonumber(r.value) }
end

app:get("/plain", function(ctx)
    return ctx.text(200, "Hello, World!")
end)

app:get("/json", function(ctx)
    return ctx.json(200, { message = "Hello, World!" })
end)

app:get("/params/{id}", function(ctx)
    return ctx.json(200, { id = ctx.params.id, q = ctx.query.q })
end)

app:post("/echo", function(ctx)
    return ctx.json(200, ctx.body)
end)

app:get("/db/{id}", function(ctx)
    local rows, err = MySQL:query("SELECT id, name, value FROM bench_items WHERE id = ?", { tonumber(ctx.params.id) })
    if not rows then return ctx.error(500, "db error", err) end
    if not rows[1] then return ctx.json(404, { error = "not found" }) end
    return ctx.json(200, row(rows[1]))
end)

app:get("/db", function(ctx)
    local rows, err = MySQL:query("SELECT id, name, value FROM bench_items ORDER BY id LIMIT 20")
    if not rows then return ctx.error(500, "db error", err) end
    local out = {}
    for i, r in ipairs(rows) do out[i] = row(r) end
    return ctx.json(200, out)
end)

app:post("/db", function(ctx)
    local body = ctx.body or {}
    local result, err = MySQL:insert("INSERT INTO bench_items (name, value) VALUES (?, ?)",
        { tostring(body.name or "item"), tonumber(body.value) or 0 })
    if not result then return ctx.error(500, "db error", err) end
    local id = type(result) == "table" and (result.insert_id or result.id) or result
    return ctx.json(201, { id = tonumber(id), name = body.name, value = body.value })
end)

app:get("/orm/{id}", function(ctx)
    local item = Item:find(tonumber(ctx.params.id))
    if not item then return ctx.json(404, { error = "not found" }) end
    return ctx.json(200, { id = tonumber(item.id), name = item.name, value = tonumber(item.value) })
end)

app:listen(port, "127.0.0.1")
