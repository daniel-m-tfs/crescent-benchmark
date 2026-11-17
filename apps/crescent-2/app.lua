-- Benchmark app: framework core only (no request log, security headers,
-- CORS or rate limit), the same baseline as the other apps.
local Crescent = require("crescent")
local Config = require("crescent.config")

local app = Crescent.new(Config.load())
require("src.bench").register(app)

return app
