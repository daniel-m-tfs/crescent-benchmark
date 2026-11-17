-- migrations/20260916163140_create_benchmark_records_table.lua
-- Migration: create_benchmark_records_table

local Migration = {}

-- Executa a migration (criar tabelas, adicionar colunas, etc)
function Migration:up()
    return [[
        CREATE TABLE IF NOT EXISTS benchmark_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
end

-- Desfaz a migration (remover tabelas, colunas, etc)
function Migration:down()
    return [[
        DROP TABLE IF EXISTS benchmark_records;
    ]]
end

return Migration
