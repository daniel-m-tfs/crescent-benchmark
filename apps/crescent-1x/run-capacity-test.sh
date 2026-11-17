#!/usr/bin/env bash
set -u

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

HOST="${BENCHMARK_HOST:-127.0.0.1}"
ENV_PORT="$(awk -F= '$1 == "APP_PORT" {print $2; exit}' .env 2>/dev/null | tr -d '\r"' | xargs)"
PORT="${BENCHMARK_PORT:-${APP_PORT:-${ENV_PORT:-3000}}}"
URL="http://${HOST}:${PORT}/benchmark/json"
DURATION="${CAPACITY_DURATION:-15s}"
THREADS="${CAPACITY_THREADS:-4}"
CONNECTIONS="${CAPACITY_CONNECTIONS:-10 25 50 100 200 400 800}"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_DIR="$BASE_DIR/reports/capacity-$STAMP"
REPORT="$REPORT_DIR/report.md"
SERVER_LOG="$REPORT_DIR/server.log"
SERVER_PID=""

mkdir -p "$REPORT_DIR"

cleanup() {
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

printf '# Crescent Capacity Test\n\n' > "$REPORT"
printf -- '- Date: `%s`\n- Target: `%s`\n- Endpoint: `%s`\n- Threads: `%s`\n- Duration per level: `%s`\n- Connection levels: `%s`\n\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$URL" "$URL" "$THREADS" "$DURATION" "$CONNECTIONS" >> "$REPORT"
printf '## Definition\n\n' >> "$REPORT"
printf '%s\n' 'Each connection is an open HTTP client connection, not a human user. A real user may open multiple connections or make requests at a different rate. The useful capacity point is the highest level that keeps the service error-free and within the chosen latency target.' >> "$REPORT"
printf '%s\n\n' 'Default degradation rule: any non-2xx response, connection error, or p99 latency above 500ms marks that level as degraded.' >> "$REPORT"

printf 'Preparing migration and resetting benchmark data...\n'
luvit crescent-cli.lua migrate >"$REPORT_DIR/migrate.log" 2>&1 || { cat "$REPORT_DIR/migrate.log"; exit 1; }
luvit -e 'require("bootstrap"); local db = require("crescent.database.mysql"); local _, err = db:query("TRUNCATE TABLE benchmark_records"); if err then error(err) end; db.closeAll()' >"$REPORT_DIR/reset.log" 2>&1 || { cat "$REPORT_DIR/reset.log"; exit 1; }

printf 'Starting server...\n'
luvit app.lua >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
ready=0
for _ in $(seq 1 60); do
    if curl -fsS "http://${HOST}:${PORT}/health" >/dev/null 2>&1; then ready=1; break; fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then cat "$SERVER_LOG"; exit 1; fi
    sleep 0.25
done
[[ "$ready" -eq 1 ]] || { cat "$SERVER_LOG"; exit 1; }

printf '## Results\n\n' >> "$REPORT"
printf '| Connections | Requests/sec | p50 | p99 | Non-2xx/errors | Assessment |\n' >> "$REPORT"
printf '|---:|---:|---:|---:|---:|---|\n' >> "$REPORT"

for connections in $CONNECTIONS; do
    output="$REPORT_DIR/wrk-$connections.txt"
    printf 'Running %s connections...\n' "$connections"
    wrk -t"$THREADS" -c"$connections" -d"$DURATION" --latency "$URL" >"$output" 2>&1 || true

    reqs="$(awk '/Requests\/sec:/ {print $2; exit}' "$output")"
    p50="$(awk '$1 == "50%" {print $2; exit}' "$output")"
    p99="$(awk '$1 == "99%" {print $2; exit}' "$output")"
    errors="$(awk '/Non-2xx or 3xx responses:/ {print $NF; exit}' "$output")"
    errors="${errors:-0}"
    reqs="${reqs:-n/a}"
    p50="${p50:-n/a}"
    p99="${p99:-n/a}"

    degraded="no"
    if [[ "$errors" != "0" && "$errors" != "n/a" ]]; then degraded="yes"; fi
    if [[ "$p99" == *ms ]] && awk -v value="${p99%ms}" 'BEGIN {exit !(value > 500)}'; then degraded="yes"; fi
    assessment="healthy"
    [[ "$degraded" == "yes" ]] && assessment="degraded"

    printf '| %s | %s | %s | %s | %s | %s |\n' "$connections" "$reqs" "$p50" "$p99" "$errors" "$assessment" >> "$REPORT"
done

printf '\n## Capacity interpretation\n\n' >> "$REPORT"
printf '%s\n' '- The recommended capacity is the last `healthy` row, not the first row that returns errors.' >> "$REPORT"
printf '%s\n' '- Repeat with `CAPACITY_DURATION=60s` and realistic endpoints before using the result for production sizing.' >> "$REPORT"
printf '%s\n' '- This test excludes Nginx, TLS, network distance, multiple workers and other users of the host.' >> "$REPORT"
printf '%s\n' '- For a production limit, repeat at the same time while monitoring CPU, RSS, open files, MySQL connections and slow queries.' >> "$REPORT"
printf '\nRaw outputs are in `%s`.\n' "$REPORT_DIR" >> "$REPORT"

printf '\nCapacity report generated: %s\n' "$REPORT"
