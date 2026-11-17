# Crescent Benchmark Report

- Date: `2026-09-16T19:38:59Z`
- Profile: `quick`
- Target: `http://127.0.0.1:8080`
- Threads/connections: `2/20`
- Duration per wrk case: `10s`

## Environment

- Host: `127.0.0.1`
- Port: `8080`
- Server command: `luvit app.lua`

## Functional checks

### GET /health

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:38:59 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"ok","timestamp":1789587539}

### GET /benchmark/plain

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:38:59 GMT
Transfer-Encoding: chunked
Connection: keep-alive

crescent-benchmark-ok


### GET /benchmark/json

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:38:59 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"service":"crescent","ok":true,"timestamp":1789587539}

### GET /benchmark/params/a%20b

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:38:59 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"id":"a b","query":[]}

### GET /benchmark/db/count

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:38:59 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"count":0}

### POST /benchmark/echo

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:38:59 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"raw":"{\"name\":\"functional-check\",\"value\":42}","body":{"name":"functional-check","value":42}}


### wrk-plain

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark/plain`

Running 10s test @ http://127.0.0.1:8080/benchmark/plain
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     2.25ms    2.25ms  37.80ms   94.03%
    Req/Sec     5.10k     1.57k    7.22k    72.00%
  Latency Distribution
     50%    1.83ms
     75%    2.32ms
     90%    3.60ms
     99%   11.77ms
  101581 requests in 10.02s, 13.66MB read
Requests/sec:  10140.99
Transfer/sec:      1.36MB


### wrk-json

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark/json`

Running 10s test @ http://127.0.0.1:8080/benchmark/json
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     2.81ms    4.86ms  85.72ms   96.04%
    Req/Sec     4.85k     1.82k    7.07k    64.00%
  Latency Distribution
     50%    1.85ms
     75%    2.52ms
     90%    4.46ms
     99%   26.40ms
  96458 requests in 10.01s, 16.01MB read
Requests/sec:   9640.46
Transfer/sec:      1.60MB


### wrk-params

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark/params/a%20b?mode=load`

Running 10s test @ http://127.0.0.1:8080/benchmark/params/a%20b?mode=load
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     6.52ms    6.56ms 106.01ms   95.53%
    Req/Sec     1.76k   490.73     2.22k    76.50%
  Latency Distribution
     50%    4.87ms
     75%    5.60ms
     90%    8.92ms
     99%   41.16ms
  35071 requests in 10.01s, 5.18MB read
Requests/sec:   3502.78
Transfer/sec:    530.21KB


### wrk-db-read

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark`

Running 10s test @ http://127.0.0.1:8080/benchmark
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     6.31ms    7.23ms  99.46ms   96.01%
    Req/Sec     1.85k   439.90     2.76k    77.50%
  Latency Distribution
     50%    4.80ms
     75%    6.76ms
     90%    8.78ms
     99%   45.15ms
  36877 requests in 10.01s, 4.22MB read
Requests/sec:   3684.82
Transfer/sec:    431.93KB


### wrk-db-count

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark/db/count`

Running 10s test @ http://127.0.0.1:8080/benchmark/db/count
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     6.03ms    3.57ms  62.46ms   91.40%
    Req/Sec     1.74k   362.24     3.56k    76.12%
  Latency Distribution
     50%    5.19ms
     75%    7.27ms
     90%    8.93ms
     99%   19.38ms
  34806 requests in 10.10s, 4.28MB read
Requests/sec:   3444.92
Transfer/sec:    434.07KB


### wrk-post-echo

Command: `wrk -t2 -c20 -d10s --latency -s /Volumes/ssd/Tyne Forge Systems/projetos/Crescent/benchmark/wrk-post.lua http://127.0.0.1:8080/benchmark/echo`

Running 10s test @ http://127.0.0.1:8080/benchmark/echo
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     2.65ms    3.09ms  77.03ms   94.31%
    Req/Sec     4.41k     1.57k    6.45k    65.50%
  Latency Distribution
     50%    2.06ms
     75%    2.73ms
     90%    4.54ms
     99%   12.24ms
  87907 requests in 10.01s, 16.18MB read
Requests/sec:   8782.33
Transfer/sec:      1.62MB


### wrk-post-db

Command: `wrk -t2 -c20 -d10s --latency -s /Volumes/ssd/Tyne Forge Systems/projetos/Crescent/benchmark/wrk-post.lua http://127.0.0.1:8080/benchmark`

Running 10s test @ http://127.0.0.1:8080/benchmark
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    10.61ms   13.04ms 196.22ms   96.68%
    Req/Sec     1.13k   290.72     1.77k    72.22%
  Latency Distribution
     50%    8.22ms
     75%    9.47ms
     90%   13.50ms
     99%   79.41ms
  22276 requests in 10.01s, 4.90MB read
Requests/sec:   2225.42
Transfer/sec:    500.97KB

## Runtime snapshot

```text
  PID ELAPSED  %CPU %MEM    RSS COMMAND
11864   01:11  46.3  8.7 731248 /opt/homebrew/Cellar/luvit/2.18.1_2/bin/luvi -- /opt/homebrew/bin/luvit app.lua
```

## Interpretation

- Compare Requests/sec and latency percentiles between plain, JSON, parameter, database read/count and POST cases.
- Any `Non-2xx` line indicates application-level failures during the load case.
- Database write results should be checked against the final row count; the benchmark table is intentionally disposable.
- This run measures the application directly. Nginx/TLS/proxy overhead is not included.

## Server log

See `server.log` in this report directory.
