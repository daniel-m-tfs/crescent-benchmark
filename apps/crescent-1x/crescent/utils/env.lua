-- crescent/utils/env.lua
-- Utilitário para carregar variáveis de ambiente de arquivo .env

local M = {}

-- Carrega arquivo .env e retorna tabela com variáveis
function M.load(filepath)
    filepath = filepath or ".env"
    local env_vars = {}
    
    local file = io.open(filepath, "r")
    if not file then
        return env_vars -- Retorna vazio se arquivo não existe
    end
    
    for line in file:lines() do
        -- Remove espaços em branco
        line = line:match("^%s*(.-)%s*$")
        
        -- Ignora linhas vazias e comentários
        if line ~= "" and not line:match("^#") then
            -- Parse KEY=VALUE
            line = line:gsub("^export%s+", "")
            local key, value = line:match("^([^=]+)=(.*)$")
            if key and value then
                -- Remove espaços do key
                key = key:match("^%s*(.-)%s*$")
                local quoted = value:match('^"(.-)"$') or value:match("^'(.-)'$")
                -- Remove aspas do value se existirem; comentários inline só
                -- valem para valores não-quotados.
                if quoted ~= nil then
                    value = quoted
                else
                    value = value:gsub("%s+#.*$", "")
                    value = value:match("^%s*(.-)%s*$")
                end
                env_vars[key] = value
            end
        end
    end
    
    file:close()
    return env_vars
end

-- Obtém valor de variável de ambiente (primeiro do .env, depois do sistema)
function M.get(key, default)
    -- Carrega .env na primeira chamada
    if not M._cache then
        M._cache = M.load()
    end
    
    -- Prioridade: .env > sistema > default
    return M._cache[key] or os.getenv(key) or default
end

-- Limpa cache (útil para testes)
function M.clear_cache()
    M._cache = nil
end

return M
