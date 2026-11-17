-- Benchmark endpoints: same contract as every app in benchmark/apps/.
local Model = require("crescent.model")

local Item = Model:extend({
    table = "bench_items",
    primary_key = "id",
    timestamps = false,
    fillable = { "name", "value" },
})

local SELECT_ONE = "SELECT id, name, value FROM bench_items WHERE id = ?"
local SELECT_LIST = "SELECT id, name, value FROM bench_items ORDER BY id LIMIT 20"
local INSERT = "INSERT INTO bench_items (name, value) VALUES (?, ?)"

local function row(r)
    return { id = tonumber(r.id), name = r.name, value = tonumber(r.value) }
end

local Module = {}

function Module.register(app)
    app:get("/plain", function(ctx)
        return ctx:text(200, "Hello, World!")
    end)

    app:get("/json", function(ctx)
        return ctx:json(200, { message = "Hello, World!" })
    end)

    app:get("/params/{id}", function(ctx)
        return ctx:json(200, { id = ctx.params.id, q = ctx.query.q })
    end)

    app:post("/echo", function(ctx)
        return ctx:json(200, ctx.body)
    end)

    app:get("/db/{id}", function(ctx)
        local rows, err = ctx.db:query(SELECT_ONE, { tonumber(ctx.params.id) })
        if not rows then return ctx:error(500, "db error", err) end
        if not rows[1] then return ctx:json(404, { error = "not found" }) end
        return ctx:json(200, row(rows[1]))
    end)

    app:get("/db", function(ctx)
        local rows, err = ctx.db:query(SELECT_LIST)
        if not rows then return ctx:error(500, "db error", err) end
        local out = {}
        for i, r in ipairs(rows) do out[i] = row(r) end
        return ctx:json(200, out)
    end)

    app:post("/db", function(ctx)
        local body = ctx.body or {}
        local name, value = tostring(body.name or "item"), tonumber(body.value) or 0
        local result, err = ctx.db:execute(INSERT, { name, value })
        if not result then return ctx:error(500, "db error", err) end
        return ctx:json(201, { id = tonumber(result.insert_id), name = name, value = value })
    end)

    app:get("/orm/{id}", function(ctx)
        local item = Item:find(tonumber(ctx.params.id))
        if not item then return ctx:json(404, { error = "not found" }) end
        return ctx:json(200, { id = item.id, name = item.name, value = item.value })
    end)
end

return Module
