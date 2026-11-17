# Crescent Benchmark Report

- Date: `2026-09-16T19:34:52Z`
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
Date: Wed, 16 Sep 2026 19:34:52 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"ok","timestamp":1789587292}

### GET /benchmark/plain

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:34:52 GMT
Transfer-Encoding: chunked
Connection: keep-alive

crescent-benchmark-ok


### GET /benchmark/json

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:34:52 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"timestamp":1789587292,"service":"crescent","ok":true}

### GET /benchmark/params/a%20b

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:34:52 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"id":"a b","query":[]}

### GET /benchmark/db/count

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:34:52 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"count":1}

### POST /benchmark/echo

HTTP/1.1 200 OK
Date: Wed, 16 Sep 2026 19:34:52 GMT
Transfer-Encoding: chunked
Connection: keep-alive

{"raw":"{\"name\":\"functional-check\",\"value\":42}","body":{"value":42,"name":"functional-check"}}


### wrk-plain

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark/plain`

Running 10s test @ http://127.0.0.1:8080/benchmark/plain
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     2.32ms    2.76ms  44.21ms   94.84%
    Req/Sec     5.14k     1.56k    6.87k    74.50%
  Latency Distribution
     50%    1.81ms
     75%    2.31ms
     90%    3.64ms
     99%   13.97ms
  102337 requests in 10.01s, 13.76MB read
Requests/sec:  10225.38
Transfer/sec:      1.38MB


### wrk-json

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark/json`

Running 10s test @ http://127.0.0.1:8080/benchmark/json
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     2.91ms    5.55ms 104.77ms   96.50%
    Req/Sec     4.80k     1.80k   11.39k    72.64%
  Latency Distribution
     50%    1.88ms
     75%    2.53ms
     90%    4.43ms
     99%   30.88ms
  96086 requests in 10.10s, 15.94MB read
Requests/sec:   9511.00
Transfer/sec:      1.58MB


### wrk-params

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark/params/a%20b?mode=load`

Running 10s test @ http://127.0.0.1:8080/benchmark/params/a%20b?mode=load
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     6.16ms    5.96ms 100.22ms   96.75%
    Req/Sec     1.81k   402.42     2.22k    80.50%
  Latency Distribution
     50%    4.91ms
     75%    5.44ms
     90%    8.22ms
     99%   35.94ms
  36100 requests in 10.02s, 5.34MB read
Requests/sec:   3602.51
Transfer/sec:    545.30KB


### wrk-db-read

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark`

Running 10s test @ http://127.0.0.1:8080/benchmark
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     5.58ms    3.00ms  51.80ms   88.98%
    Req/Sec     1.86k   339.73     2.67k    79.00%
  Latency Distribution
     50%    4.69ms
     75%    6.87ms
     90%    8.28ms
     99%   16.40ms
  37050 requests in 10.01s, 7.74MB read
Requests/sec:   3701.92
Transfer/sec:    791.73KB


### wrk-db-count

Command: `wrk -t2 -c20 -d10s --latency http://127.0.0.1:8080/benchmark/db/count`

Running 10s test @ http://127.0.0.1:8080/benchmark/db/count
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    10.49ms    5.42ms  83.01ms   92.95%
    Req/Sec     0.99k   212.12     1.42k    66.00%
  Latency Distribution
     50%    9.56ms
     75%   10.87ms
     90%   13.89ms
     99%   32.28ms
  19794 requests in 10.01s, 2.44MB read
Requests/sec:   1976.98
Transfer/sec:    249.12KB


### wrk-post-echo

Command: `wrk -t2 -c20 -d10s --latency -s /Volumes/ssd/Tyne Forge Systems/projetos/Crescent/benchmark/wrk-post.lua http://127.0.0.1:8080/benchmark/echo`

Running 10s test @ http://127.0.0.1:8080/benchmark/echo
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     2.45ms    2.01ms  31.43ms   90.93%
    Req/Sec     4.56k     1.46k    6.35k    65.84%
  Latency Distribution
     50%    2.04ms
     75%    2.57ms
     90%    4.25ms
     99%   10.45ms
  91635 requests in 10.10s, 16.87MB read
Requests/sec:   9069.21
Transfer/sec:      1.67MB


### wrk-post-db

Command: `wrk -t2 -c20 -d10s --latency -s /Volumes/ssd/Tyne Forge Systems/projetos/Crescent/benchmark/wrk-post.lua http://127.0.0.1:8080/benchmark`

Running 10s test @ http://127.0.0.1:8080/benchmark
  2 threads and 20 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     9.71ms    7.61ms 139.30ms   94.80%
    Req/Sec     1.12k   281.28     1.69k    66.00%
  Latency Distribution
     50%    8.19ms
     75%    9.33ms
     90%   13.66ms
     99%   45.58ms
  22259 requests in 10.01s, 4.89MB read
Requests/sec:   2223.89
Transfer/sec:    500.65KB

## Runtime snapshot

```text
  PID ELAPSED  %CPU %MEM    RSS COMMAND
94662   01:11  31.0  8.7 732560 /opt/homebrew/Cellar/luvit/2.18.1_2/bin/luvi -- /opt/homebrew/bin/luvit app.lua
```

## Interpretation

- Compare Requests/sec and latency percentiles between plain, JSON, parameter, database read/count and POST cases.
- Any `Non-2xx` line indicates application-level failures during the load case.
- Database write results should be checked against the final row count; the benchmark table is intentionally disposable.
- This run measures the application directly. Nginx/TLS/proxy overhead is not included.

## Server log

See `server.log` in this report directory.
