local Env = require("crescent.env")

return {
    environment = "bench",
    debug = false,
    server = { host = "127.0.0.1", port = 8102, max_body_size = 1024 * 1024 },
    database = {
        host = Env.get("DB_HOST", "127.0.0.1"),
        port = Env.number("DB_PORT", 3306),
        database = Env.get("DB_NAME", "crescent_bench"),
        user = Env.get("DB_USER", "root"),
        password = Env.get("DB_PASSWORD", ""),
        pool_size = Env.number("DB_POOL", 16),
    },
}
