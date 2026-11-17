#!/usr/bin/env bash
# Runs the same HTTP scenarios against every app in apps/, one app at a time,
# and writes reports/<stamp>/{report.md,results.csv,raw/}.
#
#   bench/run.sh                         # all apps, 1 and 4 workers, 15s per scenario
#   bench/run.sh --quick                 # 5s per scenario, 2s warm-up
#   bench/run.sh --workers 1 crescent-2 node-fastify
#   bench/run.sh --rounds 3              # repeat everything; the report uses the median
#
# Options (or environment): --workers "1 4" (WORKERS_LIST), --duration 15s
# (DURATION), --warmup 5s (WARMUP), --connections 64 (CONNECTIONS),
# --threads 2 (THREADS), --rounds 1 (ROUNDS). Each round rotates the app
# order so no app is always measured first or last.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$ROOT/bench"

WORKERS_LIST="${WORKERS_LIST:-1 4}"
DURATION="${DURATION:-15s}"
WARMUP="${WARMUP:-5s}"
CONNECTIONS="${CONNECTIONS:-64}"
THREADS="${THREADS:-2}"
ROUNDS="${ROUNDS:-1}"
APPS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --quick) DURATION=5s; WARMUP=2s ;;
        --workers) WORKERS_LIST="$2"; shift ;;
        --duration) DURATION="$2"; shift ;;
        --warmup) WARMUP="$2"; shift ;;
        --connections) CONNECTIONS="$2"; shift ;;
        --threads) THREADS="$2"; shift ;;
        --rounds) ROUNDS="$2"; shift ;;
        -h|--help) sed -n 2,12p "$0"; exit 0 ;;
        -*) echo "unknown option: $1" >&2; exit 2 ;;
        *) APPS+=("$1") ;;
    esac
    shift
done
[ ${#APPS[@]} -gt 0 ] || APPS=(crescent-1x crescent-2 node-fastify python-fastapi)

OPENRESTY="${OPENRESTY_BIN:-/opt/homebrew/opt/openresty/bin/openresty}"
for tool in wrk mysql curl luvit node python3; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done
[ -x "$OPENRESTY" ] || { echo "OpenResty not found at $OPENRESTY (set OPENRESTY_BIN)" >&2; exit 1; }
[ -f "$BENCH/.env" ] || { echo "create bench/.env from bench/env.example" >&2; exit 1; }

set -a; . "$BENCH/.env"; set +a
export DB_NAME=crescent_bench
mysql_cli() { MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$@"; }

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/reports/$STAMP"
RAW="$OUT/raw"
mkdir -p "$RAW"
CSV="$OUT/results.csv"
echo "round,app,workers,scenario,requests_per_sec,latency_avg_ms,p50_ms,p90_ms,p99_ms,requests,errors,non_2xx,rss_mb" > "$CSV"

# name|method path|wrk script (empty = none)|expected status
SCENARIOS=(
    "plain|/plain||200"
    "json|/json||200"
    "params|/params/42?q=lua||200"
    "echo|/echo|wrk-echo.lua|200"
    "db-one|/db/1|wrk-db-one.lua|200"
    "db-list|/db||200"
    "db-insert|/db|wrk-insert.lua|201"
    "orm-one|/orm/1|wrk-orm-one.lua|200"
)

port_of() {
    case "$1" in
        crescent-1x) echo 8101 ;; crescent-2) echo 8102 ;;
        node-fastify) echo 8103 ;; python-fastapi) echo 8104 ;;
    esac
}

SERVER_PID=""
start_app() {
    local app="$1" workers="$2" port="$3" log="$4" dir="$ROOT/apps/$1"
    # Same total database connections for everyone: 64 split across workers.
    export DB_POOL=$(( 64 / workers ))
    case "$app" in
        crescent-1x)
            (cd "$dir" && PORT="$port" exec luvit bench.lua) >"$log" 2>&1 &
            ;;
        crescent-2)
            mkdir -p "$dir/logs" "$dir/tmp"
            sed "s/__WORKERS__/$workers/; s/__PORT__/$port/" "$dir/conf/nginx.bench.conf" > "$dir/conf/nginx.bench.run.conf"
            : > "$dir/logs/error.log"
            APP_ENV=bench "$OPENRESTY" -p "$dir/" -c conf/nginx.bench.run.conf -g "daemon off;" >"$log" 2>&1 &
            ;;
        node-fastify)
            (cd "$dir" && NODE_ENV=production WORKERS="$workers" PORT="$port" exec node server.js) >"$log" 2>&1 &
            ;;
        python-fastapi)
            (cd "$dir" && exec .venv/bin/uvicorn main:app --host 127.0.0.1 --port "$port" \
                --workers "$workers" --loop uvloop --http httptools --no-access-log --log-level warning) >"$log" 2>&1 &
            ;;
    esac
    SERVER_PID=$!
    for _ in $(seq 1 100); do
        curl -fs "http://127.0.0.1:$port/json" >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    echo "  $app did not start; see $log" >&2
    return 1
}

descendants() {
    local pid="$1" child
    echo "$pid"
    for child in $(pgrep -P "$pid" 2>/dev/null); do descendants "$child"; done
}

rss_mb() {
    local total=0 pid kb
    for pid in $(descendants "$SERVER_PID"); do
        kb=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ') || true
        total=$(( total + ${kb:-0} ))
    done
    echo $(( total / 1024 ))
}

stop_app() {
    [ -n "$SERVER_PID" ] || return 0
    local pids
    pids="$(descendants "$SERVER_PID" | tr '\n' ' ')"
    kill $pids 2>/dev/null || true
    for _ in $(seq 1 50); do kill -0 "$SERVER_PID" 2>/dev/null || break; sleep 0.1; done
    kill -9 $pids 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
}
trap stop_app EXIT INT TERM

# Checks that the app honours the shared contract before measuring it.
verify_app() {
    local base="$1" log="$2" ok=1 body
    check() { # name, expected substring, curl args...
        local name="$1" want="$2"; shift 2
        body="$(curl -s "$@")"
        printf '%-10s %s\n' "$name" "$body" >> "$log"
        case "$body" in *"$want"*) ;; *) echo "  contract FAILED: $name -> $body" >&2; ok=0 ;; esac
    }
    check plain 'Hello, World!' "$base/plain"
    check json '"message":"Hello, World!"' "$base/json"
    check params '"q":"lua"' "$base/params/42?q=lua"
    check echo '"Ada Lovelace"' -H 'Content-Type: application/json' -d @"$BENCH/wrk-echo.body" "$base/echo"
    check db-one '"item-7"' "$base/db/7"
    check db-list '"item-20"' "$base/db"
    check db-insert '"name":"load"' -H 'Content-Type: application/json' -d '{"name":"load","value":7}' "$base/db"
    [ "$ok" = 1 ]
}
printf '%s' '{"id":42,"name":"Ada Lovelace","tags":["lua","bench"],"active":true}' > "$BENCH/wrk-echo.body"

run_wrk() { # duration, url, script, output
    local args=(-t"$THREADS" -c"$CONNECTIONS" -d"$1" --latency)
    [ -n "$3" ] && args+=(-s "$BENCH/$3")
    wrk "${args[@]}" "$2" > "$4" 2>&1 || true
}

{
    echo "date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "machine=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m) cpus=$(sysctl -n hw.ncpu 2>/dev/null || nproc) mem_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))"
    echo "os=$(sw_vers -productVersion 2>/dev/null || uname -r)"
    echo "wrk=-t$THREADS -c$CONNECTIONS -d$DURATION warmup=$WARMUP rounds=$ROUNDS"
    echo "mysql=$(mysql_cli -N -e 'SELECT VERSION()')"
    echo "openresty=$("$OPENRESTY" -v 2>&1 | sed 's/.*openresty\///')"
    echo "luvit=$(luvit -v 2>/dev/null | head -1)"
    echo "node=$(node -v) fastify=$(node -p "require('$ROOT/apps/node-fastify/node_modules/fastify/package.json').version") mysql2=$(node -p "require('$ROOT/apps/node-fastify/node_modules/mysql2/package.json').version")"
    echo "python=$("$ROOT/apps/python-fastapi/.venv/bin/python" -V | cut -d' ' -f2) $("$ROOT/apps/python-fastapi/.venv/bin/python" -I -c 'import fastapi,uvicorn,aiomysql;print(f"fastapi={fastapi.__version__} uvicorn={uvicorn.__version__} aiomysql={aiomysql.__version__}")')"
} > "$OUT/environment.txt"

for round in $(seq 1 "$ROUNDS"); do
  # Rotate the app order every round.
  shift_by=$(( (round - 1) % ${#APPS[@]} ))
  ORDER=("${APPS[@]:$shift_by}" "${APPS[@]:0:$shift_by}")
  for workers in $WORKERS_LIST; do
    for app in "${ORDER[@]}"; do
        if [ "$app" = crescent-1x ] && [ "$workers" -gt 1 ]; then
            echo "== $app x$workers: skipped (Luvit runs a single process)"
            continue
        fi
        port="$(port_of "$app")"
        base="http://127.0.0.1:$port"
        tag="r$round-$app-w$workers"
        echo "== round $round/$ROUNDS: $app x$workers ($base)"
        mysql_cli < "$BENCH/schema.sql"
        start_app "$app" "$workers" "$port" "$RAW/$tag.server.log" || { stop_app; continue; }
        if ! verify_app "$base" "$RAW/$tag.contract.txt"; then stop_app; continue; fi
        idle="$(rss_mb)"
        echo "$round,$app,$workers,idle,,,,,,,,,$idle" >> "$CSV"
        for spec in "${SCENARIOS[@]}"; do
            IFS='|' read -r name path script _expect <<< "$spec"
            if [ "$name" = orm-one ] && [[ "$app" != crescent-* ]]; then continue; fi
            printf '   %-10s ' "$name"
            run_wrk "$WARMUP" "$base$path" "$script" /dev/null
            run_wrk "$DURATION" "$base$path" "$script" "$RAW/$tag.$name.txt"
            rss="$(rss_mb)"
            python3 -I "$BENCH/parse_wrk.py" "$RAW/$tag.$name.txt" "$round" "$app" "$workers" "$name" "$rss" >> "$CSV"
            tail -1 "$CSV" | awk -F, '{printf "%10s req/s  p99 %s ms  errors %s  non-2xx %s\n", $5, $9, $11, $12}'
        done
        stop_app
    done
  done
done

python3 -I "$BENCH/report.py" "$OUT"
echo
echo "Report: $OUT/report.md"
