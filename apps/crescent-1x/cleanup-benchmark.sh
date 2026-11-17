#!/usr/bin/env bash
set -u
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

luvit -e 'require("bootstrap"); local db = require("crescent.database.mysql"); local _, err = db:query("TRUNCATE TABLE benchmark_records"); if err then error(err) end; db.closeAll(); print("benchmark_records truncated")'
