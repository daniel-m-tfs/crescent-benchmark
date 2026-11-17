-- crescent/core/request.lua
-- Processamento e validação de requisições HTTP

local json = _G._json or require("json")
local string_utils = require("crescent.utils.string")

local M = {}

-- Tamanho máximo do body (10MB por padrão)
local MAX_BODY_SIZE = 10 * 1024 * 1024

-- Lê o body da requisição de forma assíncrona
function M.read_body(req, max_size, callback, timeout_ms)
    max_size = max_size or MAX_BODY_SIZE
    if type(max_size) ~= "number" or max_size < 0 or max_size % 1 ~= 0 then
        return callback(nil, nil, "invalid body size limit")
    end

    local headers = req.headers or {}
    local content_length = headers["content-length"]
    local expected_size
    if content_length ~= nil then
        if type(content_length) ~= "string" or not content_length:match("^%d+$") then
            return callback(nil, nil, "invalid content-length")
        end
        expected_size = tonumber(content_length)
        if not expected_size or expected_size > max_size then
            return callback(nil, nil, "content-length exceeds maximum")
        end
    end

    local chunks = {}
    local total_size = 0
    local timer = _G._timer
    local timeout_handle

    -- Garante no máximo UMA chamada de callback. Sem isso, exceder max_size
    -- chama callback(...) e req:destroy(), mas nada impedia o evento "end"
    -- (ou "error") de disparar depois e chamar callback(...) de novo com
    -- argumentos diferentes — handler rodando duas vezes, res:finish()
    -- chamado duas vezes, etc.
    local settled = false
    local function settle(...)
        if settled then return end
        settled = true
        if timeout_handle and timer then
            pcall(function() timer.clearTimer(timeout_handle) end)
        end
        return callback(...)
    end

    if timeout_ms and timeout_ms > 0 and timer then
        timeout_handle = timer.setTimeout(timeout_ms, function()
            pcall(function() req:destroy() end)
            settle(nil, nil, "request body timeout")
        end)
    end

    req:on("data", function(chunk)
        if settled then return end

        total_size = total_size + #chunk

        -- Proteção contra DoS: limita tamanho do body
        if total_size > max_size then
            pcall(function() req:destroy() end)
            return settle(nil, nil, "body too large")
        end

        chunks[#chunks + 1] = chunk
    end)

    req:on("end", function()
        if settled then return end

        local raw = table.concat(chunks)
        if expected_size and total_size ~= expected_size then
            return settle(nil, nil, "content-length mismatch")
        end
        local ct = (req.headers["content-type"] or ""):lower()

        -- Parse JSON se aplicável
        if ct:find("application/json", 1, true) and raw ~= "" then
            local ok, data = pcall(json.parse, raw)
            if ok then
                settle(raw, data)
            else
                settle(raw, nil, "invalid json")
            end
        else
            settle(raw, nil)
        end
    end)

    req:on("error", function(err)
        settle(nil, nil, "request error: " .. tostring(err))
    end)
end

-- Valida Content-Type
function M.validate_content_type(req, expected)
    local ct = (req.headers["content-type"] or ""):lower()
    if type(expected) == "string" then
        return ct:find(expected, 1, true) ~= nil
    elseif type(expected) == "table" then
        for _, exp in ipairs(expected) do
            if ct:find(exp, 1, true) then
                return true
            end
        end
    end
    return false
end

-- Valida tamanho do body via Content-Length
function M.validate_content_length(req, max_size)
    max_size = max_size or MAX_BODY_SIZE
    local cl = req.headers["content-length"]
    
    if cl then
        local size = tonumber(cl)
        if size and size > max_size then
            return false, "content-length exceeds maximum"
        end
    end
    
    return true
end

-- Configura tamanho máximo do body
function M.set_max_body_size(size)
    MAX_BODY_SIZE = size
end

-- Obtém tamanho máximo do body
function M.get_max_body_size()
    return MAX_BODY_SIZE
end

return M
