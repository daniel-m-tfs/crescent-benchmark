-- crescent/core/response.lua
-- Utilidades para envio de respostas HTTP

local json = _G._json or require("json")
local headers_utils = require("crescent.utils.headers")

local M = {}

function M.is_safe_header_value(value)
    return headers_utils.is_safe_value(value)
end

local function finish_response(res, body)
    if res._head_request then
        return res:finish()
    end
    return res:finish(body)
end

-- Serializa Model(s) para array
local function serialize_data(obj)
    -- Se é um Model individual com método toArray
    if type(obj) == "table" and type(obj.toArray) == "function" then
        return obj:toArray()
    end
    
    -- Se é um array/table
    if type(obj) == "table" then
        local result = {}
        local is_array = false
        
        -- Verifica se é array (tem índices numéricos sequenciais)
        if #obj > 0 then
            is_array = true
            for i, item in ipairs(obj) do
                if type(item) == "table" and type(item.toArray) == "function" then
                    result[i] = item:toArray()
                else
                    result[i] = item
                end
            end
        else
            -- É um objeto/hash
            for k, v in pairs(obj) do
                if type(v) == "table" and type(v.toArray) == "function" then
                    result[k] = v:toArray()
                else
                    result[k] = v
                end
            end
        end
        
        return result
    end
    
    -- Retorna como está (primitivos)
    return obj
end

-- Envia resposta JSON
function M.json(res, status, obj, extra_headers)
    if res.finished then return end
    
    res:setHeader("Content-Type", "application/json; charset=utf-8")
    
    -- Headers extras (se fornecidos)
    if type(extra_headers) == "table" then
        for k, v in pairs(extra_headers) do
            if headers_utils.is_safe_value(v) then
                res:setHeader(k, v)
            end
        end
    end
    
    -- Serializa ANTES de escrever o header de status — se a serialização
    -- falhar, precisamos poder responder com um status de erro real (500)
    -- em vez de já ter commitado o status de sucesso original e mandar um
    -- corpo de erro com um código 200 (writeHead não pode ser desfeito).
    local serialized = serialize_data(obj)
    local ok, encoded = pcall(json.stringify, serialized)

    if ok then
        res:writeHead(status or 200)
        finish_response(res, encoded)
    else
        res:writeHead(500)
        finish_response(res, '{"error":"json encoding error"}')
    end
end

-- Envia resposta de texto
function M.text(res, status, str, extra_headers)
    if res.finished then return end
    
    res:setHeader("Content-Type", "text/plain; charset=utf-8")
    
    -- Headers extras (se fornecidos)
    if type(extra_headers) == "table" then
        for k, v in pairs(extra_headers) do
            if headers_utils.is_safe_value(v) then
                res:setHeader(k, v)
            end
        end
    end
    
    res:writeHead(status or 200)
    finish_response(res, str or "")
end

-- Envia resposta HTML
function M.html(res, status, html, extra_headers)
    if res.finished then return end
    
    res:setHeader("Content-Type", "text/html; charset=utf-8")
    
    -- Headers extras (se fornecidos)
    if type(extra_headers) == "table" then
        for k, v in pairs(extra_headers) do
            if headers_utils.is_safe_value(v) then
                res:setHeader(k, v)
            end
        end
    end
    
    res:writeHead(status or 200)
    finish_response(res, html or "")
end

-- Renderiza e envia uma view (template)
function M.view(res, status, view_path, data, extra_headers)
    if res.finished then return end
    
    local etlua = require("crescent.utils.etlua")
    
    -- Renderiza o template
    local html, err = etlua.render_file(view_path, data or {})
    
    if not html then
        -- Erro ao renderizar template
        M.error(res, 500, "Template rendering error", err)
        return
    end
    
    -- Envia como HTML
    M.html(res, status, html, extra_headers)
end

-- Envia erro padronizado
function M.error(res, status, message, details)
    local error_obj = {
        error = message or "internal error",
        status = status or 500
    }
    
    if details then
        error_obj.details = details
    end
    
    M.json(res, status, error_obj)
end

-- Envia resposta de redirecionamento
function M.redirect(res, location, status, options)
    if res.finished then return end

    if not headers_utils.is_safe_value(location) then
        return M.error(res, 400, "invalid redirect location")
    end

    options = options or {}
    local external_host = location:match("^https?://([^/%?#]+)")
    if external_host then
        local allowed = options.allow_external == true
        if allowed and type(options.allowed_hosts) == "table" then
            allowed = false
            for _, host in ipairs(options.allowed_hosts) do
                if host == external_host then
                    allowed = true
                    break
                end
            end
        elseif allowed and type(options.allowed_hosts) ~= "table" then
            allowed = false
        end
        if not allowed then
            return M.error(res, 400, "external redirect not allowed")
        end
    elseif not location:match("^/") then
        return M.error(res, 400, "invalid redirect location")
    end
    
    res:setHeader("Location", location)
    res:writeHead(status or 302)
    res:finish()
end

-- Envia resposta vazia (204 No Content)
function M.no_content(res)
    if res.finished then return end
    
    res:writeHead(204)
    res:finish()
end

-- Define headers de segurança padrão
function M.set_security_headers(res)
    res:setHeader("X-Content-Type-Options", "nosniff")
    res:setHeader("X-Frame-Options", "DENY")
    res:setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
end

-- Define headers CORS
function M.set_cors_headers(res, options)
    options = options or {}

    if options.credentials and (options.origin == "*" or options.origin == nil) then
        error("CORS credentials require an explicit origin")
    end

    local origin = options.origin or "*"
    local methods = options.methods or "GET,POST,PUT,PATCH,DELETE,OPTIONS"
    local headers = options.headers or "Content-Type, Authorization"
    if not headers_utils.is_safe_value(origin)
        or not headers_utils.is_safe_value(methods)
        or not headers_utils.is_safe_value(headers) then
        error("Invalid CORS header value")
    end
    
    res:setHeader("Access-Control-Allow-Origin", origin)
    res:setHeader("Access-Control-Allow-Methods", 
                  methods)
    res:setHeader("Access-Control-Allow-Headers", 
                  headers)
    
    if options.credentials then
        res:setHeader("Access-Control-Allow-Credentials", "true")
    end
    
    if options.max_age then
        res:setHeader("Access-Control-Max-Age", tostring(options.max_age))
    end
end

return M
