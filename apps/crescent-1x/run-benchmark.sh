#!/usr/bin/env bash
set -u

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

PROFILE="${1:-quick}"
HOST="${BENCHMARK_HOST:-127.0.0.1}"
ENV_PORT="$(awk -F= '$1 == "APP_PORT" {print $2; exit}' .env 2>/dev/null | tr -d '\r"' | xargs)"
PORT="${BENCHMARK_PORT:-${APP_PORT:-${ENV_PORT:-3000}}}"
BASE_URL="http://${HOST}:${PORT}"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_DIR="$BASE_DIR/reports/$STAMP"
SERVER_LOG="$REPORT_DIR/server.log"
REPORT="$REPORT_DIR/report.md"
SERVER_PID=""

mkdir -p "$REPORT_DIR"

cleanup() {
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

if [[ "$PROFILE" == "full" ]]; then
    DURATION="${BENCHMARK_DURATION:-30s}"
    THREADS="${BENCHMARK_THREADS:-4}"
    CONNECTIONS="${BENCHMARK_CONNECTIONS:-100}"
else
    DURATION="${BENCHMARK_DURATION:-10s}"
    THREADS="${BENCHMARK_THREADS:-2}"
    CONNECTIONS="${BENCHMARK_CONNECTIONS:-20}"
fi

run_cmd() {
    local label="$1"
    shift
    local output="$REPORT_DIR/${label}.txt"
    printf '\n### %s\n\n' "$label" >> "$REPORT"
    printf 'Command: `%s`\n\n' "$*" >> "$REPORT"
    if "$@" >"$output" 2>&1; then
        cat "$output" >> "$REPORT"
        printf '\n' >> "$REPORT"
        return 0
    fi
    local code=$?
    printf 'Command failed with exit code `%s`\n\n' "$code" >> "$REPORT"
    cat "$output" >> "$REPORT"
    printf '\n' >> "$REPORT"
    return "$code"
}

printf '# Crescent Benchmark Report\n\n' > "$REPORT"
printf -- '- Date: `%s`\n- Profile: `%s`\n- Target: `%s`\n- Threads/connections: `%s/%s`\n- Duration per wrk case: `%s`\n\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PROFILE" "$BASE_URL" "$THREADS" "$CONNECTIONS" "$DURATION" >> "$REPORT"
printf '## Environment\n\n' >> "$REPORT"
printf -- '- Host: `%s`\n- Port: `%s`\n- Server command: `luvit app.lua`\n\n' "$HOST" "$PORT" >> "$REPORT"

printf 'Preparing database migration...\n'
if ! luvit crescent-cli.lua migrate >"$REPORT_DIR/migrate.log" 2>&1; then
    printf 'Migration failed. See %s\n' "$REPORT_DIR/migrate.log"
    cat "$REPORT_DIR/migrate.log"
    exit 1
fi

if ! luvit -e 'require("bootstrap"); local db = require("crescent.database.mysql"); local _, err = db:query("TRUNCATE TABLE benchmark_records"); if err then error(err) end; db.closeAll()' >"$REPORT_DIR/reset.log" 2>&1; then
    printf 'Could not reset benchmark_records. See %s\n' "$REPORT_DIR/reset.log"
    cat "$REPORT_DIR/reset.log"
    exit 1
fi

printf 'Starting server with luvit app.lua...\n'
luvit app.lua >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

ready=0
for _ in $(seq 1 60); do
    if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
        ready=1
        break
    fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        printf 'Server exited before readiness.\n'
        cat "$SERVER_LOG"
        exit 1
    fi
    sleep 0.25
done

if [[ "$ready" -ne 1 ]]; then
    printf 'Server did not become ready.\n'
    cat "$SERVER_LOG"
    exit 1
fi

printf 'Server ready. Running functional checks...\n'
{
    printf '## Functional checks\n\n'
    for path in /health /benchmark/plain /benchmark/json /benchmark/params/a%20b /benchmark/db/count; do
        printf '### GET %s\n\n' "$path"
        curl --silent --show-error --include "$BASE_URL$path" || true
        printf '\n\n'
    done
    printf '### POST /benchmark/echo\n\n'
    curl --silent --show-error --include -H 'Content-Type: application/json' \
        --data '{"name":"functional-check","value":42}' "$BASE_URL/benchmark/echo" || true
    printf '\n\n'
} >> "$REPORT"

run_cmd "wrk-plain" wrk -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" --latency "$BASE_URL/benchmark/plain"
run_cmd "wrk-json" wrk -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" --latency "$BASE_URL/benchmark/json"
run_cmd "wrk-params" wrk -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" --latency "$BASE_URL/benchmark/params/a%20b?mode=load"
run_cmd "wrk-db-read" wrk -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" --latency "$BASE_URL/benchmark"
run_cmd "wrk-db-count" wrk -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" --latency "$BASE_URL/benchmark/db/count"
run_cmd "wrk-post-echo" wrk -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" --latency -s "$BASE_DIR/wrk-post.lua" "$BASE_URL/benchmark/echo"
run_cmd "wrk-post-db" wrk -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" --latency -s "$BASE_DIR/wrk-post.lua" "$BASE_URL/benchmark"

{
    printf '## Runtime snapshot\n\n'
    printf '```text\n'
    ps -p "$SERVER_PID" -o pid,etime,%cpu,%mem,rss,command 2>/dev/null || true
    printf '```\n\n'
    printf '## Interpretation\n\n'
    printf -- '- Compare Requests/sec and latency percentiles between plain, JSON, parameter, database read/count and POST cases.\n'
    printf -- '- Any `Non-2xx` line indicates application-level failures during the load case.\n'
    printf -- '- Database write results should be checked against the final row count; the benchmark table is intentionally disposable.\n'
    printf -- '- This run measures the application directly. Nginx/TLS/proxy overhead is not included.\n\n'
    printf '## Server log\n\nSee `server.log` in this report directory.\n'
} >> "$REPORT"

printf '\nReport generated: %s\n' "$REPORT"
printf 'Raw outputs: %s\n' "$REPORT_DIR"
