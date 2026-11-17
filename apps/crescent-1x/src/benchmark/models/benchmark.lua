-- src/benchmark/models/benchmark.lua
-- Model para Benchmark usando Active Record ORM

local Model = require("crescent.database.model")

local Benchmark = Model:extend({
    table = "benchmark_records",
    primary_key = "id",
    timestamps = true,
    soft_deletes = false,
    
    fillable = {
        -- Adicione aqui os campos que podem ser preenchidos em massa
        "name",
    },
    
    hidden = {
        -- Campos que não devem aparecer em JSON/serialização
        -- "password"
    },

    guarded = {
        -- Campos protegidos contra mass assignment
        -- "id", "created_at", "updated_at"
    },
    
    validates = {
        -- Adicione validações aqui
        name = {required = true, min_length = 1, max_length = 255},
    },

    relations = {
        -- Defina relações aqui (cada uma é uma função que recebe a instância)
        -- posts = function(self) return self:hasMany(require("src.posts.models.post"), "user_id") end,
        -- profile = function(self) return self:belongsTo(require("src.profile.models.profile"), "user_id") end,
    }
})

-- Métodos personalizados do model
-- function Benchmark:customMethod()
--     -- Seu código aqui
-- end

return Benchmark
