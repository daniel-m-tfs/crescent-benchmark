-- crescent/server.lua
-- Servidor HTTP principal do framework Crescent

-- Usa os módulos pré-carregados ou carrega normalmente
local http = _G._http or require("http")
local url = _G._url or require("url")
local router_lib = require("crescent.core.router")
local context_lib = require("crescent.core.context")
local request_lib = require("crescent.core.request")
local response_lib = require("crescent.core.response")

local Server = {}
Server.__index = Server
local request_sequence = 0

local DEFAULT_CONFIG = {
    server = {
        host = "0.0.0.0",
        port = 8080,
        max_body_size = 10 * 1024 * 1024, -- 10MB
        request_timeout = 30000,
        max_concurrent_requests = 1000
    }
}

-- Faz merge raso de `config` sobre `defaults`, mesclando um nível de tabelas
-- aninhadas (ex.: config.server preenche só as chaves que faltam)
local function merge_config(defaults, config)
    local result = {}
    for k, v in pairs(defaults) do
        result[k] = v
    end

    if config then
        for k, v in pairs(config) do
            if type(v) == "table" and type(result[k]) == "table" then
                local merged = {}
                for kk, vv in pairs(result[k]) do merged[kk] = vv end
                for kk, vv in pairs(v) do merged[kk] = vv end
                result[k] = merged
            else
                result[k] = v
            end
        end
    end

    return result
end

-- Cria nova instância do servidor
-- @param config table opcional: mesmo formato de config/development.lua
-- (server, cors, security, logging, database, jwt, api). Só `server` é
-- consumido diretamente pelo core (host/port/max_body_size); as demais
-- seções ficam disponíveis em app.config para uso opcional pela aplicação,
-- ex.: app:use(cors.create(app.config.cors))
function Server.new(config)
    return setmetatable({
        router = router_lib.new(),
        middlewares = {},
        error_handler = nil,
        not_found_handler = nil,
        active_requests = 0,
        config = merge_config(DEFAULT_CONFIG, config)
    }, Server)
end

-- Adiciona middleware global
function Server:use(middleware)
    if type(middleware) ~= "function" then
        error("Middleware must be a function")
    end
    table.insert(self.middlewares, middleware)
    return self
end

-- Define handler de erro customizado
function Server:on_error(handler)
    self.error_handler = handler
    return self
end

-- Define handler 404 customizado
function Server:on_not_found(handler)
    self.not_found_handler = handler
    return self
end

-- Métodos de roteamento
function Server:get(path, handler)
    router_lib.add_route(self.router, "GET", path, handler)
    return self
end

function Server:post(path, handler)
    router_lib.add_route(self.router, "POST", path, handler)
    return self
end

function Server:put(path, handler)
    router_lib.add_route(self.router, "PUT", path, handler)
    return self
end

function Server:patch(path, handler)
    router_lib.add_route(self.router, "PATCH", path, handler)
    return self
end

function Server:delete(path, handler)
    router_lib.add_route(self.router, "DELETE", path, handler)
    return self
end

function Server:options(path, handler)
    router_lib.add_route(self.router, "OPTIONS", path, handler)
    return self
end

function Server:head(path, handler)
    router_lib.add_route(self.router, "HEAD", path, handler)
    return self
end

-- Define prefixo global
function Server:prefix(p)
    router_lib.set_prefix(self.router, p)
    return self
end

-- Limpa prefixo
function Server:clear_prefix()
    router_lib.clear_prefix(self.router)
    return self
end

-- Grupo de rotas com prefixo
function Server:group(prefix, fn)
    router_lib.push_prefix(self.router, prefix)
    local ok, err = pcall(fn, self)
    router_lib.pop_prefix(self.router)
    
    if not ok then
        error(err)
    end
    
    return self
end

-- Executa cadeia de middlewares.
-- Retorna (ok, err, halted):
--   true, nil, false    -> cadeia completou normalmente
--   false, err, false   -> exceção Lua real dentro de um middleware
--   false, nil, true    -> um middleware parou a cadeia intencionalmente
--                          (return false, o mecanismo OFICIAL de halt usado
--                          por auth/cors/security) — isso NÃO é um erro.
-- Antes, "parada intencional" e "exceção real" colapsavam no mesmo
-- `ok=false`, então todo 401/403/429 legítimo acionava self.error_handler
-- com err=nil como se fosse um erro não tratado.
local function run_middlewares(middlewares, ctx, index)
    index = index or 1

    if index > #middlewares then
        return true
    end

    local middleware = middlewares[index]

    local next_fn = function()
        return run_middlewares(middlewares, ctx, index + 1)
    end

    local ok, result = pcall(middleware, ctx, next_fn)

    if not ok then
        return false, result, false
    end

    -- Se middleware retornou false, parou a cadeia intencionalmente
    if result == false then
        return false, nil, true
    end

    -- Continua
    return true
end

-- Processa requisição
function Server:_handle_request(req, res)
    local max_concurrent = self.config.server.max_concurrent_requests
    if type(max_concurrent) ~= "number" or max_concurrent < 1 or max_concurrent % 1 ~= 0 then
        error("server.max_concurrent_requests must be a positive integer")
    end
    if self.active_requests >= max_concurrent then
        res:setHeader("Retry-After", "1")
        response_lib.error(res, 503, "server busy")
        return
    end

    self.active_requests = self.active_requests + 1
    local released = false
    local timeout_timer
    local original_finish = res.finish
    local function release_request()
        if released then return end
        released = true
        self.active_requests = math.max(0, self.active_requests - 1)
        if timeout_timer and _G._timer then
            pcall(function() _G._timer.clearTimer(timeout_timer) end)
        end
    end

    if type(original_finish) == "function" then
        res.finish = function(response, body)
            release_request()
            return original_finish(response, body)
        end
    end
    if req and type(req.on) == "function" then
        req:on("close", release_request)
    end

    res._head_request = req.method == "HEAD"
    request_sequence = request_sequence + 1
    -- Cria context preliminar para middlewares
    local parsed_url = req.url and url.parse(req.url) or {}
    local path = parsed_url.pathname or "/"
    
    local ctx = context_lib.new(req, res, {
        handler = nil,
        params = {},
        route_path = nil
    })
    ctx.state.request_id = string.format("%d-%d", os.time(), request_sequence)
    res:setHeader("X-Request-ID", ctx.state.request_id)

    local request_timeout = self.config.server.request_timeout
    if request_timeout and request_timeout > 0 and _G._timer then
        timeout_timer = _G._timer.setTimeout(request_timeout, function()
            if not res.finished then
                response_lib.error(res, 504, "request timeout")
            end
        end)
    end
    
    -- Executa middlewares ANTES de procurar rotas (para arquivos estáticos)
    if #self.middlewares > 0 then
        local ok, err, halted = run_middlewares(self.middlewares, ctx)

        if not ok and not halted then
            -- Exceção real dentro de um middleware
            if self.error_handler then
                pcall(self.error_handler, ctx, err)
            else
                response_lib.error(res, 500, "middleware error", tostring(err))
            end
            return
        end

        -- Middleware parou a cadeia intencionalmente (halt) ou já respondeu
        if halted or res.finished then
            return
        end
    end
    
    -- Busca rota (agora após middlewares)
    local handler, params, route_path = router_lib.match_route(
        self.router, 
        req.method, 
        path
    )
    
    -- Atualiza context com informações da rota
    ctx.handler = handler
    ctx.params = params
    ctx.route_path = route_path
    for key, value in pairs(ctx.query) do
        if ctx.params[key] == nil then
            ctx.params[key] = value
        end
    end
    
    -- Handler 404 se rota não encontrada
    if not handler then
        -- Verifica se já foi enviada uma resposta (ex: arquivo estático)
        if res.finished then
            return
        end
        
        if self.not_found_handler then
            local ok, err = pcall(self.not_found_handler, ctx)
            if not ok then
                response_lib.error(res, 500, "error in not_found handler", err)
            end
        else
            local allowed = router_lib.allowed_methods(self.router, path)
            if #allowed > 0 then
                res:setHeader("Allow", table.concat(allowed, ", "))
                response_lib.error(res, 405, "method not allowed")
                return
            end
            response_lib.error(res, 404, "route not found", {
                method = ctx.method,
                path = ctx.path
            })
        end
        return
    end
    
    -- Lê body se necessário
    request_lib.read_body(req, self.config.server.max_body_size, function(raw, parsed, err)
        context_lib.set_body(ctx, raw, parsed, err)

        if err then
            local status = 400
            if err == "body too large" or err == "content-length exceeds maximum" then
                status = 413
            end
            if not res.finished then
                response_lib.error(res, status, err)
            end
            return
        end
        
        -- Executa handler da rota
        local ok, result = pcall(handler, ctx)
        
        if not ok then
            if self.error_handler then
                pcall(self.error_handler, ctx, result)
            else
                response_lib.error(res, 500, "handler error", tostring(result))
            end
            return
        end
        
        -- Se handler retornou algo e resposta ainda não foi enviada
        if result ~= nil and not res.finished then
            if type(result) == "table" then
                response_lib.json(res, 200, result)
            else
                response_lib.text(res, 200, tostring(result))
            end
        end
    end, self.config.server.request_timeout)
end

-- Inicia servidor
function Server:listen(port, host)
    port = port or self.config.server.port
    host = host or self.config.server.host

    http.createServer(function(req, res)
        self:_handle_request(req, res)
    end):listen(port, host)
    
    print(string.format("🌙 Crescent server listening on http://%s:%d", host, port))
    
    return self
end

-- Configura opção do servidor (host/port/max_body_size)
function Server:set(key, value)
    self.config.server[key] = value
    return self
end

function Server:get_active_requests()
    return self.active_requests
end

return Server
