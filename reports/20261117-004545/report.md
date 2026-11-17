# Benchmark: Crescent 1.x × Crescent 2 × Node × Python

```
date=2026-11-17T03:45:45Z
machine=Apple M2 cpus=8 mem_gb=8
os=26.4.1
wrk=-t2 -c64 -d15s warmup=5s
mysql=9.5.0
openresty=1.31.1.1
luvit=luvit version: 2.18.1
node=v24.11.1 fastify=5.12.8 mysql2=3.24.6
python=3.13.14 fastapi=0.163.1 uvicorn=0.54.0 aiomysql=0.3.2
```

Valores: requisições por segundo (maior é melhor) e, entre parênteses, latência p99 em ms (menor é melhor). `⚠` = houve erros de socket ou respostas fora de 2xx. Detalhes brutos em `raw/`.

## 1 worker

| Cenário | Crescent 1.x (Luvit) | Crescent 2 (OpenResty) | Node + Fastify | Python + FastAPI |
|---|---:|---:|---:|---:|
| GET /plain — texto | 14.464 (72.98) | **80.725 (2.48)** | 63.592 (1.99) | 24.684 (5.08) |
| GET /json — JSON pequeno | 13.607 (430.47) | **80.774 (1.16)** | 59.849 (2.99) | 21.647 (5.85) |
| GET /params/{id}?q= — rota com parâmetro | 10.398 (27.14) | **79.845 (1.16)** | 61.504 (2.04) | 14.469 (11.35) |
| POST /echo — parse + serialização de JSON | 12.396 (38.88) | **73.059 (1.25)** | 53.879 (2.34) | 16.049 (8.06) |
| GET /db/{id} — 1 linha por PK (aleatória) | 5.472 (101.87) | **42.738 (2.07)** | 23.942 (17.04) | 6.655 (17.33) |
| GET /db — 20 linhas | 4.927 (38.69) | **22.365 (3.28)** | 22.001 (5.66) | 3.979 (18.84) |
| POST /db — INSERT | 2.522 (163.75) | **24.294 (159.41)** | 23.769 (29.98) | 10.024 (14.22) |
| GET /orm/{id} — 1 linha via Model (só Crescent) | 5.708 (34.23) | **32.815 (2.61)** | — | — |
| Memória RSS (MB, ociosa → pico) | 13 → 1510 | 14 → 15 | 84 → 356 | 54 → 54 |

## 4 workers

| Cenário | Crescent 2 (OpenResty) | Node + Fastify | Python + FastAPI |
|---|---:|---:|---:|
| GET /plain — texto | **195.256 (0.773)** | 184.627 (0.89) | 63.855 (2.29) |
| GET /json — JSON pequeno | **190.793 (0.89)** | 183.600 (0.85) | 57.744 (2.51) |
| GET /params/{id}?q= — rota com parâmetro | **185.555 (0.94)** | 174.966 (1.24) | 43.016 (3.65) |
| POST /echo — parse + serialização de JSON | **170.595 (1.67)** | 162.987 (1.02) | 45.413 (3.41) |
| GET /db/{id} — 1 linha por PK (aleatória) | **68.233 (57.36)** | 65.635 (8.85) | 25.264 (6.33) |
| GET /db — 20 linhas | **57.134 (12.57)** | 55.825 (27.95) | 14.417 (6.28) |
| POST /db — INSERT | 14.981 (149.57) | **19.867 (150.7)** | 11.466 (162.04) |
| GET /orm/{id} — 1 linha via Model (só Crescent) | **55.582 (38.24)** | — | — |
| Memória RSS (MB, ociosa → pico) | 28 → 37 | 414 → 957 | 270 → 272 |

