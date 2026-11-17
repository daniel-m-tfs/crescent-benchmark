# Crescent Capacity Test

- Date: `2026-09-16T19:44:52Z`
- Target: `http://127.0.0.1:8080/benchmark/json`
- Endpoint: `http://127.0.0.1:8080/benchmark/json`
- Threads: `4`
- Duration per level: `60s`
- Connection levels: `10 25 50 100 200 400 800`

## Definition

Each connection is an open HTTP client connection, not a human user. A real user may open multiple connections or make requests at a different rate. The useful capacity point is the highest level that keeps the service error-free and within the chosen latency target.
Default degradation rule: any non-2xx response, connection error, or p99 latency above 500ms marks that level as degraded.

## Results

| Connections | Requests/sec | p50 | p99 | Non-2xx/errors | Assessment |
|---:|---:|---:|---:|---:|---|
| 10 | 6406.41 | 778.00us | 160.74ms | 0 | healthy |
| 25 | 1530.14 | 6.81ms | 456.53ms | 0 | healthy |
| 50 | 563.63 | 22.56ms | 1.56s | 0 | healthy |
| 100 | 6587.83 | 11.37ms | 915.19ms | 0 | degraded |
| 200 | 1642.94 | 55.14ms | 1.60s | 0 | healthy |
| 400 | 4941.95 | 41.13ms | 923.57ms | 0 | degraded |
| 800 | 4682.53 | 84.14ms | 664.34ms | 0 | degraded |

## Capacity interpretation

- The recommended capacity is the last `healthy` row, not the first row that returns errors.
- Repeat with `CAPACITY_DURATION=60s` and realistic endpoints before using the result for production sizing.
- This test excludes Nginx, TLS, network distance, multiple workers and other users of the host.
- For a production limit, repeat at the same time while monitoring CPU, RSS, open files, MySQL connections and slow queries.

Raw outputs are in `/Volumes/ssd/Tyne Forge Systems/projetos/Crescent/benchmark/reports/capacity-20260916-164452`.
