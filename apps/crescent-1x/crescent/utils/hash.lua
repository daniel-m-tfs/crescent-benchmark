local openssl = require('openssl')
local digest = openssl.digest
local hmac = openssl.hmac
local env = require('crescent.utils.env')

local hash = {}

-- Configurações padrão.
--
-- Sobre o valor de DEFAULT_ITERATIONS: a recomendação OWASP atual para
-- PBKDF2-HMAC-SHA256 é ~600.000 iterações (mínimo defensável ~210.000).
-- 10.000 (valor anterior) é patamar de ~2013, fraco demais hoje.
--
-- MAS: pbkdf2() abaixo é um loop PURO em Lua (chama hmac.digest milhares de
-- vezes; a binding openssl usada aqui não expõe um PBKDF2 nativo em C) —
-- e o Luvit é single-thread/event-loop (libuv): cada chamada de
-- hash.encrypt()/verify() BLOQUEIA o processo inteiro (todas as outras
-- conexões sendo servidas) pela duração do cálculo. Medido neste ambiente:
-- ~2.2µs por iteração, ou seja 600k iterações ~= 1.3s de bloqueio total do
-- event loop POR LOGIN — inaceitável, seria um DoS auto-infligido sob
-- concorrência. 100.000 (~220ms bloqueando) é um meio-termo mais seguro que
-- o valor anterior sem travar o servidor inteiro por mais de um instante;
-- ainda assim, ajuste PASSWORD_HASH_ITERATIONS conforme o hardware/carga
-- real do seu deploy. O fix correto de verdade seria mover o cálculo pra
-- fora do event loop principal (thread pool) ou usar um KDF nativo em C.
local DEFAULT_ITERATIONS = tonumber(env.get("PASSWORD_HASH_ITERATIONS")) or 100000
local SALT_LENGTH = 16
local HASH_LENGTH = 32
local MAX_ITERATIONS = 1000000

local function validate_iterations(iterations)
    if type(iterations) ~= "number" or iterations % 1 ~= 0
        or iterations < 1 or iterations > MAX_ITERATIONS then
        error("PBKDF2 iterations must be an integer between 1 and " .. MAX_ITERATIONS, 3)
    end
end

-- ==========================================
-- GERAÇÃO DE SALT ALEATÓRIO
-- ==========================================

local function generateSalt()
    return openssl.random(SALT_LENGTH)
end

local function bytesToHex(bytes)
    local hex = {}
    for i = 1, #bytes do
        hex[i] = string.format("%02x", string.byte(bytes, i))
    end
    return table.concat(hex)
end

local function hexToBytes(hex)
    local bytes = {}
    for i = 1, #hex, 2 do
        local byte = tonumber(hex:sub(i, i + 1), 16)
        table.insert(bytes, string.char(byte))
    end
    return table.concat(bytes)
end

-- ==========================================
-- PBKDF2 IMPLEMENTATION
-- ==========================================

local function pbkdf2(password, salt, iterations, keyLength)
    local function f(password, salt, iterations, blockIndex)
        local block = salt .. string.pack(">I4", blockIndex)
        local u = hmac.digest('sha256', block, password, true)
        local result = u
        
        for i = 2, iterations do
            u = hmac.digest('sha256', u, password, true)
            -- XOR result with u
            local xor_result = {}
            for j = 1, #result do
                xor_result[j] = string.char(
                    bit.bxor(string.byte(result, j), string.byte(u, j))
                )
            end
            result = table.concat(xor_result)
        end
        
        return result
    end
    
    local blocks = math.ceil(keyLength / 32) -- SHA256 produces 32 bytes
    local derivedKey = {}
    
    for i = 1, blocks do
        derivedKey[i] = f(password, salt, iterations, i)
    end
    
    return string.sub(table.concat(derivedKey), 1, keyLength)
end

-- ==========================================
-- ENCRYPT (HASH) PASSWORD
-- ==========================================

function hash.encrypt(password, iterations)
    if type(password) ~= "string" or password == "" then
        error("Password must be a non-empty string", 2)
    end
    
    iterations = iterations or DEFAULT_ITERATIONS
    validate_iterations(iterations)
    
    -- Gera salt aleatório único
    local salt = generateSalt()
    
    -- Gera hash usando PBKDF2
    local derivedKey = pbkdf2(password, salt, iterations, HASH_LENGTH)
    
    -- Retorna formato: iterations$salt$hash (tudo em hex)
    return string.format("%d$%s$%s", 
        iterations,
        bytesToHex(salt),
        bytesToHex(derivedKey)
    )
end

-- ==========================================
-- VERIFY (DECRYPT/COMPARE) PASSWORD
-- ==========================================

function hash.verify(password, hashedPassword)
    if type(password) ~= "string" or password == "" then
        error("Password must be a non-empty string", 2)
    end
    
    if type(hashedPassword) ~= "string" or hashedPassword == "" then
        error("Hashed password must be a non-empty string", 2)
    end
    
    -- Parse o formato: iterations$salt$hash
    local parts = {}
    for part in string.gmatch(hashedPassword, "[^$]+") do
        table.insert(parts, part)
    end
    
    if #parts ~= 3 then
        -- Antes lançava erro aqui — mas verify() é fundamentalmente uma
        -- comparação booleana (mesmo contrato de secureCompare, que retorna
        -- false), chamada tipicamente como `if hash.verify(pw, stored) then`
        -- sem pcall. Um hash salvo em formato antigo/corrompido no banco
        -- não deveria derrubar a request com uma exceção não tratada —
        -- deveria simplesmente significar "não bate".
        return false
    end
    
    local iterations = tonumber(parts[1])
    if not iterations or iterations % 1 ~= 0 or iterations < 1 or iterations > MAX_ITERATIONS then
        return false
    end
    if #parts[2] ~= SALT_LENGTH * 2 or not parts[2]:match("^[0-9a-fA-F]+$") then
        return false
    end
    if #parts[3] ~= HASH_LENGTH * 2 or not parts[3]:match("^[0-9a-fA-F]+$") then
        return false
    end
    local salt = hexToBytes(parts[2])
    local originalHash = parts[3]
    
    -- Gera hash da senha fornecida com o mesmo salt
    local derivedKey = pbkdf2(password, salt, iterations, HASH_LENGTH)
    local newHash = bytesToHex(derivedKey)
    
    -- Comparação segura contra timing attacks
    return hash.secureCompare(newHash, originalHash)
end

-- ==========================================
-- COMPARAÇÃO SEGURA (TIMING-SAFE)
-- ==========================================

function hash.secureCompare(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then
        return false
    end

    local result = bit.bxor(#a, #b)
    local length = math.max(#a, #b)
    for i = 1, length do
        result = bit.bor(result, bit.bxor(string.byte(a, i) or 0, string.byte(b, i) or 0))
    end
    
    return result == 0
end

-- ==========================================
-- HASH SIMPLES (NÃO PARA SENHAS)
-- ==========================================

function hash.sha256(data)
    if type(data) ~= "string" then
        error("Data must be a string", 2)
    end
    return digest.digest('sha256', data)
end

function hash.md5(data)
    if type(data) ~= "string" then
        error("Data must be a string", 2)
    end
    return digest.digest('md5', data)
end

return hash
