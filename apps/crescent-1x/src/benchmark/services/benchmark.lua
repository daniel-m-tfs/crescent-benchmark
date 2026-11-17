-- src/benchmark/services/benchmark.lua
-- Service para lógica de negócio de benchmark

local BenchmarkService = {}
local Benchmark = require("src.benchmark.models.benchmark")

function BenchmarkService:getAll()
    return Benchmark:query():orderBy("id", "DESC"):limit(50):get()
end

function BenchmarkService:getById(id)
    return Benchmark:find(id)
end

function BenchmarkService:create(body)
    body = body or {}
    body.name = body.name or ("load-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999)))
    return Benchmark:create(body)
end

function BenchmarkService:count()
    return Benchmark:query():count()
end

function BenchmarkService:update(id, body)
    local benchmark = Benchmark:find(id)
    if not benchmark then
        return nil, nil
    end

    local ok, err = benchmark:update(body)
    if not ok then
        return nil, err
    end

    return benchmark
end

function BenchmarkService:delete(id)
    local benchmark = Benchmark:find(id)
    if benchmark then
        benchmark:delete()
        return true
    end
    return false
end

return BenchmarkService
