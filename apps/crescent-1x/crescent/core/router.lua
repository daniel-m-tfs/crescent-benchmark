-- crescent/core/router.lua
-- Sistema de roteamento HTTP com suporte a parâmetros dinâmicos

local path_utils = require("crescent.utils.path")

local M = {}

local function decode_path_component(value)
    local invalid = false
    local decoded = value:gsub("%%([0-9a-fA-F][0-9a-fA-F])", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    if decoded:find("%%") then
        invalid = true
    end
    if invalid or decoded:find("%z") then
        return nil
    end
    return decoded
end

-- Métodos HTTP suportados
local METHODS = {"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"}

-- Cria nova instância do router
function M.new()
    local routes = {}
    for _, method in ipairs(METHODS) do
        routes[method] = {}
    end
    
    return {
        routes = routes,
        _base_prefix = "",
        _prefix_stack = {}
    }
end

-- Compara duas rotas por especificidade: menos parâmetros dinâmicos vence
-- (rota mais literal). Em empate, preserva a ordem de registro original via
-- `order` (table.sort não é estável, então o desempate por índice original
-- é o que garante isso). Isso resolve a colisão onde `/users/{id}` (o
-- último segmento de qualquer rota é compilado como opcional em path.lua,
-- então `/users/{id}` também casa `/users` e `/users/qualquer-coisa`)
-- engolia silenciosamente rotas literais registradas depois dela, como
-- `/users/search`, só porque vinha primeiro na ordem de registro.
local function route_specificity_less(a, b)
    if #a.names ~= #b.names then
        return #a.names < #b.names
    end
    return a._order < b._order
end

-- Adiciona uma rota
function M.add_route(router, method, path, handler)
    if type(handler) ~= "function" then
        error("Handler must be a function")
    end

    if type(method) ~= "string" or not router.routes[method] then
        error("Unsupported HTTP method: " .. tostring(method))
    end

    -- Valida path
    if not path_utils.is_safe(path) then
        error("Unsafe path: " .. tostring(path))
    end

    -- Calcula prefixo atual
    local prefix = M.get_current_prefix(router)
    local fullPath = path_utils.join(prefix, path)
    fullPath = path_utils.normalize(fullPath)

    -- Compila path
    local pattern, names = path_utils.compile(fullPath)

    local list = router.routes[method]
    table.insert(list, {
        pattern = pattern,
        names = names,
        handler = handler,
        path = fullPath,
        _order = #list + 1
    })

    -- Reordena por especificidade (ver route_specificity_less). Feito no
    -- registro, não a cada request, então match_route continua O(n) sem
    -- custo de sort por requisição.
    table.sort(list, route_specificity_less)
end

function M.allowed_methods(router, path)
    local allowed = {}
    for _, method in ipairs(METHODS) do
        for _, route in ipairs(router.routes[method] or {}) do
            if path:match(route.pattern) then
                allowed[#allowed + 1] = method
                break
            end
        end
    end
    return allowed
end

-- Busca rota correspondente
function M.match_route(router, method, path)
    local list = router.routes[method] or {}

    for _, route in ipairs(list) do
        local caps = {path:match(route.pattern)}
        if #caps > 0 then
            local params = {}
            for i, name in ipairs(route.names) do
                local v = caps[i]
                if v == "" then
                    v = nil
                end
                if v then
                    v = decode_path_component(v)
                    if not v then return nil end
                end
                params[name] = v
            end
            return route.handler, params, route.path
        end
    end

    return nil
end

-- Define prefixo global
function M.set_prefix(router, prefix)
    router._base_prefix = prefix or ""
end

-- Limpa prefixo global
function M.clear_prefix(router)
    router._base_prefix = ""
end

-- Adiciona prefixo temporário (grupo)
function M.push_prefix(router, prefix)
    table.insert(router._prefix_stack, prefix or "")
end

-- Remove prefixo temporário
function M.pop_prefix(router)
    table.remove(router._prefix_stack)
end

-- Calcula prefixo atual (base + stack)
function M.get_current_prefix(router)
    local acc = router._base_prefix or ""
    for _, p in ipairs(router._prefix_stack) do
        acc = path_utils.join(acc, p)
    end
    return acc
end

return M
