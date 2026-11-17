-- config/development.lua
-- Configuração para ambiente de desenvolvimento

local env = require("crescent.utils.env")

local function positive_integer(value, name)
    value = tonumber(value)
    if not value or value < 1 or value % 1 ~= 0 then
        error(name .. " must be a positive integer")
    end
    return value
end

local app_port = positive_integer(env.get("APP_PORT", "8080"), "APP_PORT")
local db_port = positive_integer(env.get("DB_PORT", "3306"), "DB_PORT")
local rate_max = positive_integer(env.get("RATE_LIMIT_MAX", "100"), "RATE_LIMIT_MAX")
local rate_window = positive_integer(env.get("RATE_LIMIT_WINDOW", "60"), "RATE_LIMIT_WINDOW")

return {
    -- Servidor
    server = {
        host = env.get("APP_HOST", "0.0.0.0"),
        port = app_port,
        max_body_size = 10 * 1024 * 1024, -- 10MB
        request_timeout = positive_integer(env.get("REQUEST_TIMEOUT_MS", "30000"), "REQUEST_TIMEOUT_MS"),
        max_concurrent_requests = positive_integer(env.get("MAX_CONCURRENT_REQUESTS", "1000"), "MAX_CONCURRENT_REQUESTS")
    },
    
    -- CORS (permissivo em dev)
    cors = {
        enabled = true,
        origin = env.get("CORS_ORIGIN", "*"),
        methods = env.get("CORS_METHODS", "GET,POST,PUT,PATCH,DELETE,OPTIONS"),
        headers = "Content-Type, Authorization",
        credentials = false
    },
    
    -- Segurança
    security = {
        headers = true, -- Adiciona headers de segurança
        rate_limit = env.get("RATE_LIMIT_ENABLED", "false") == "true",
        rate_limit_max = rate_max,
        rate_limit_window = rate_window,
        body_size_limit = true,
        path_traversal = true
    },
    
    -- Logging
    logging = {
        enabled = true,
        level = "detailed" -- "basic", "detailed", "custom"
    },
    
    -- Database (usa .env para dados sensíveis)
    database = {
        host = env.get("DB_HOST", "localhost"),
        port = db_port, -- 3306 = MySQL (o framework é MySQL-only; 5432 seria Postgres)
        name = env.get("DB_NAME", "dev_db"),
        user = env.get("DB_USER", "dev_user"),
        password = env.get("DB_PASSWORD", "dev_pass")
    },
    
    -- JWT
    jwt = {
        secret = env.get("JWT_SECRET", "change_this_in_production")
    },
    
    -- API
    api = {
        key = env.get("API_KEY")
    }
}
