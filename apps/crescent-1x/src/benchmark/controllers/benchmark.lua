-- src/benchmark/controllers/benchmark.lua
-- Controller para benchmark

local service = require("src.benchmark.services.benchmark")
local BenchmarkController = {}

function BenchmarkController:plain(ctx)
    return ctx.text(200, "crescent-benchmark-ok\n")
end

function BenchmarkController:json(ctx)
    return ctx.json(200, {
        ok = true,
        service = "crescent",
        timestamp = os.time()
    })
end

function BenchmarkController:params(ctx)
    return ctx.json(200, {
        id = ctx.params.id,
        query = ctx.query
    })
end

function BenchmarkController:echo(ctx)
    return ctx.json(200, {
        raw = ctx.raw,
        body = ctx.body,
        json_error = ctx.jsonErr
    })
end

function BenchmarkController:db_count(ctx)
    local count, err = service:count()
    if err then return ctx.error(503, "database unavailable", err) end
    return ctx.json(200, { count = count })
end

function BenchmarkController:index(ctx)
    local result, err = service:getAll()
    if err then return ctx.error(503, "database unavailable", err) end
    return ctx.json(200, result)
end

function BenchmarkController:show(ctx)
    local id = ctx.params.id
    local result = service:getById(id)
    
    if result then
        return ctx.json(200, result)
    end

    return ctx.json(404, { error = "Not found" })
end

function BenchmarkController:create(ctx)
    local body = ctx.body or {}
    local result, errors = service:create(body)

    if result then
        return ctx.json(201, result)
    end

    return ctx.json(422, { error = "Validation failed", details = errors })
end

function BenchmarkController:update(ctx)
    local id = ctx.params.id
    local body = ctx.body or {}
    local result, errors = service:update(id, body)

    if result then
        return ctx.json(200, result)
    elseif errors then
        return ctx.json(422, { error = "Validation failed", details = errors })
    else
        return ctx.json(404, { error = "Not found" })
    end
end

function BenchmarkController:delete(ctx)
    local id = ctx.params.id
    local success = service:delete(id)
    
    if success then
        return ctx.no_content()
    else
        return ctx.json(404, { error = "Not found" })
    end
end

return BenchmarkController
