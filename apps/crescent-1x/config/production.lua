-- config/production.lua
-- Configuração para ambiente de produção
-- IMPORTANTE: Use variáveis de ambiente (.env) para dados sensíveis

local env = require("crescent.utils.env")

local function positive_integer(value, name)
    value = tonumber(value)
    if not value or value < 1 or value % 1 ~= 0 then
        error(name .. " must be a positive integer")
    end
    return value
end

local app_port = positive_integer(env.get("APP_PORT", "8080"), "APP_PORT")
local db_port = positive_integer(env.get("DB_PORT"), "DB_PORT")
local rate_window = positive_integer(env.get("RATE_LIMIT_WINDOW", "60"), "RATE_LIMIT_WINDOW")
local rate_max = positive_integer(env.get("RATE_LIMIT_MAX", "100"), "RATE_LIMIT_MAX")
local request_timeout = positive_integer(env.get("REQUEST_TIMEOUT_MS", "30000"), "REQUEST_TIMEOUT_MS")
local max_concurrent_requests = positive_integer(env.get("MAX_CONCURRENT_REQUESTS", "1000"), "MAX_CONCURRENT_REQUESTS")

local function csv(value)
    local result = {}
    for item in tostring(value or ""):gmatch("[^,]+") do
        item = item:match("^%s*(.-)%s*$")
        if item ~= "" then result[#result + 1] = item end
    end
    return result
end

local allowed_origins = csv(env.get("CORS_ALLOWED_ORIGINS"))

local config = {
    -- Servidor
    server = {
        host = env.get("APP_HOST", "127.0.0.1"), -- Localhost quando atrás de Nginx/Apache
        port = app_port,
        max_body_size = 5 * 1024 * 1024, -- 5MB (mais restritivo)
        request_timeout = request_timeout,
        max_concurrent_requests = max_concurrent_requests
    },
    
    -- CORS (restritivo em prod)
    cors = {
        enabled = true,
        strict = true, -- Usa validação estrita de origins
        allowed_origins = allowed_origins,
        methods = env.get("CORS_METHODS", "GET,POST,PUT,PATCH,DELETE"),
        headers = "Content-Type, Authorization",
        credentials = true,
        max_age = 86400 -- 24 horas
    },
    
    -- Segurança
    security = {
        headers = true,
        rate_limit = env.get("RATE_LIMIT_ENABLED", "true") == "true",
        rate_limit_window = rate_window,
        rate_limit_max = rate_max,
        body_size_limit = true,
        path_traversal = true
    },
    
    -- Logging
    logging = {
        enabled = true,
        level = "basic" -- Menos verboso em produção
    },
    
    -- Database (SEMPRE use variáveis de ambiente em produção!)
    database = {
        host = env.get("DB_HOST"),
        port = db_port,
        name = env.get("DB_NAME"),
        user = env.get("DB_USER"),
        password = env.get("DB_PASSWORD") -- NUNCA commite senhas no código!
    },
    
    -- JWT (OBRIGATÓRIO em produção)
    jwt = {
        secret = env.get("JWT_SECRET") -- ERRO se não definido
    },
    
    -- API
    api = {
        key = env.get("API_KEY")
    }
}

-- Fail-fast: antes, faltar JWT_SECRET/credenciais de banco em produção não
-- era detectado no boot — o comentário "ERRO se não definido" ao lado de
-- jwt.secret era só aspiracional, nada validava de fato. A app subia
-- normalmente e só quebrava depois, no primeiro request que usasse auth
-- (erro dentro de auth.lua) ou banco (erro cru dentro de mysql.lua).
-- Melhor falhar alto e claro aqui, no carregamento da config, do que numa
-- request de produção real.
local missing = {}
if not config.jwt.secret or config.jwt.secret == "" then
    table.insert(missing, "JWT_SECRET")
end
if not config.database.name or config.database.name == "" then
    table.insert(missing, "DB_NAME")
end
if not config.database.user or config.database.user == "" then
    table.insert(missing, "DB_USER")
end
if #allowed_origins == 0 then
    table.insert(missing, "CORS_ALLOWED_ORIGINS")
end

if #missing > 0 then
    error("Configuração de produção incompleta — variáveis de ambiente faltando: " ..
          table.concat(missing, ", ") ..
          ". Defina no .env antes de subir em produção (ver INSTALLATION.md).")
end

return config

