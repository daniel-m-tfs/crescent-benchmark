-- src/benchmark/routes/benchmark.lua
-- Rotas para benchmark
-- prefix definido em benchmark/init.lua

local controller = require("src.benchmark.controllers.benchmark")

return function(app, prefix)
    prefix = prefix or "/benchmark"

    app:get(prefix .. "/plain", function(ctx)
        return controller:plain(ctx)
    end)

    app:get(prefix .. "/json", function(ctx)
        return controller:json(ctx)
    end)

    app:get(prefix .. "/params/{id}", function(ctx)
        return controller:params(ctx)
    end)

    app:post(prefix .. "/echo", function(ctx)
        return controller:echo(ctx)
    end)

    app:get(prefix .. "/db/count", function(ctx)
        return controller:db_count(ctx)
    end)
    
    -- CRUD completo
    app:get(prefix, function(ctx)
        return controller:index(ctx)
    end)
    
    app:get(prefix .. "/{id}", function(ctx)
        return controller:show(ctx)
    end)
    
    app:post(prefix, function(ctx)
        return controller:create(ctx)
    end)
    
    app:put(prefix .. "/{id}", function(ctx)
        return controller:update(ctx)
    end)
    
    app:delete(prefix .. "/{id}", function(ctx)
        return controller:delete(ctx)
    end)
end
