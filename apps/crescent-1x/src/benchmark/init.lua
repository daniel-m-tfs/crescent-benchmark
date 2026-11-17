-- src/benchmark/init.lua
-- Módulo Benchmark - Agrupa controllers, services e rotas

local Module = {}

function Module.register(app)
    -- Registra rotas do módulo
    local routes = require("src.benchmark.routes.benchmark")
    routes(app, "/benchmark")
    
    print("✓ Módulo Benchmark carregado")
end

return Module
