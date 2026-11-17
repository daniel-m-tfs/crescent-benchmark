# Crescent Capacity Test

- Date: `2026-09-16T19:43:05Z`
- Target: `http://127.0.0.1:8080/benchmark/json`
- Endpoint: `http://127.0.0.1:8080/benchmark/json`
- Threads: `2`
- Duration per level: `3s`
- Connection levels: `10 25 50 100`

## Definition

Each connection is an open HTTP client connection, not a human user. A real user may open multiple connections or make requests at a different rate. The useful capacity point is the highest level that keeps the service error-free and within the chosen latency target.
Default degradation rule: any non-2xx response, connection error, or p99 latency above 500ms marks that level as degraded.

## Results

| Connections | Requests/sec | p50 | p99 | Non-2xx/errors | Assessment |
|---:|---:|---:|---:|---:|---|
| 10 | 10061.79 | 816.00us | 7.17ms | 0 | healthy |
| 25 | 9610.09 | 2.21ms | 12.75ms | 0 | healthy |
| 50 | 9479.57 | 4.38ms | 28.95ms | 0 | healthy |
| 100 | 9639.92 | 7.89ms | 261.07ms | 0 | healthy |

## Capacity interpretation

- The recommended capacity is the last `healthy` row, not the first row that returns errors.
- Repeat with `CAPACITY_DURATION=60s` and realistic endpoints before using the result for production sizing.
- This test excludes Nginx, TLS, network distance, multiple workers and other users of the host.
- For a production limit, repeat at the same time while monitoring CPU, RSS, open files, MySQL connections and slow queries.

Raw outputs are in `/Volumes/ssd/Tyne Forge Systems/projetos/Crescent/benchmark/reports/capacity-20260916-164305`.
