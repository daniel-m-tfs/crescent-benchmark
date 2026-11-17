# Benchmark: Crescent 1.x × Crescent 2 × Node × Python

Resultados publicados: https://crescent.tyne.com.br/benchmark.html

Quatro aplicações com **exatamente os mesmos endpoints**, medidas uma de cada
vez, na mesma máquina, com o mesmo MySQL e a mesma carga (`wrk`).

| App | Stack | Pasta |
|---|---|---|
| Crescent 1.x | Luvit (LuaJIT + libuv), driver `luasql-mysql` | `apps/crescent-1x/` |
| Crescent 2 | OpenResty (Nginx + LuaJIT), `lua-resty-mysql` | `apps/crescent-2/` |
| Node | Node.js + Fastify 5, `mysql2` | `apps/node-fastify/` |
| Python | FastAPI + uvicorn (uvloop, httptools), `aiomysql` | `apps/python-fastapi/` |

## Rodar

Requisitos: `wrk`, `mysql` (cliente), `luvit`, OpenResty (Homebrew; outro caminho
via `OPENRESTY_BIN`), LuaRocks, Node 20+, Python 3.11+ e um MySQL local.

```bash
cp bench/env.example bench/.env        # credenciais do MySQL (usuário que pode criar banco)
(cd apps/node-fastify && npm install)
(cd apps/python-fastapi && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt)
(cd apps/crescent-2 && ./deps.sh)      # etlua, lua-resty-http, lua-resty-mail (LuaRocks)
luarocks install luasql-mysql         # driver do Crescent 1.x

bench/run.sh                 # completo: 1 e 4 workers, 15s por cenário (~20 min)
bench/run.sh --quick         # 5s por cenário
bench/run.sh --workers 1 crescent-2 node-fastify   # só alguns apps
```

O resultado fica em `reports/<data>/` (só a rodada publicada no site vai para o
repositório): `report.md` (tabelas), `results.csv`
(tudo em números), `environment.txt` (versões e máquina) e `raw/` (saída
completa de cada `wrk`, logs dos servidores e a checagem de contrato).

## O que é medido

| Cenário | Requisição | Mede |
|---|---|---|
| plain | `GET /plain` → `Hello, World!` | custo mínimo do HTTP + framework |
| json | `GET /json` → `{"message":"Hello, World!"}` | + serialização JSON |
| params | `GET /params/42?q=lua` | + roteamento com parâmetro e query string |
| echo | `POST /echo` com JSON de ~70 bytes | + leitura e parse do corpo |
| db-one | `GET /db/{id}`, id aleatório 1–1000 | 1 SELECT por chave primária |
| db-list | `GET /db` | SELECT de 20 linhas + JSON maior |
| db-insert | `POST /db` | 1 INSERT (com commit) |
| orm-one | `GET /orm/{id}` (só Crescent) | o mesmo que db-one, via `Model:find` |

Cada app passa por uma **checagem de contrato** antes de ser medido (as
respostas precisam bater); se falhar, ele é pulado e o motivo fica no log.

## Regras para ser justo

- **Um app por vez.** Os outros ficam parados; o banco é recriado (1000 linhas
  iguais) antes de cada app.
- **Mesma carga:** `wrk -t2 -c64`, aquecimento de 5s descartado, 15s medidos
  por cenário.
- **Só o núcleo do framework:** nenhum log de acesso, CORS, rate limit ou
  headers de segurança em nenhum dos apps.
- **Configuração de produção:** Crescent 2 com `lua_code_cache on` e app
  montada no `init_by_lua`; Node com `NODE_ENV=production`; uvicorn com uvloop
  e httptools, sem access log.
- **Workers:** a rodada "1 worker" é a comparação direta (um processo cada). Na
  rodada "4 workers", Crescent 2 usa `worker_processes 4`, Node usa
  `node:cluster` com 4 processos e uvicorn `--workers 4`. O Crescent 1.x não
  entra: o Luvit roda num processo só.
- **Conexões com o banco:** 64 no total para todos (64 ÷ número de workers por
  processo).
- **Banco pelo driver:** os cenários `db-*` usam SQL parametrizado direto no
  driver de cada stack. O cenário `orm-one` mostra o custo extra do ORM do
  Crescent.

## Limites (leia antes de citar números)

- Tudo roda **na mesma máquina**: o `wrk` e o MySQL competem por CPU com o app.
  Em 4 workers isso pesa mais. Os números servem para **comparar** os apps
  entre si nesta máquina, não como capacidade absoluta de produção.
- O MySQL é local e as consultas são triviais; numa aplicação real o banco
  costuma ser o gargalo e as diferenças entre frameworks diminuem.
- O `mysql2` (Node) usa *prepared statements* do servidor em `execute`; os
  outros usam o protocolo de texto com valores escapados. É o jeito idiomático
  de cada driver.
- O Crescent 1.x usa `luasql`, que é **bloqueante**: enquanto uma consulta
  roda, o processo inteiro espera.
- Sem TLS e sem proxy na frente.
- No macOS o nginx **não** deve usar `listen ... reuseport`: lá o `SO_REUSEPORT` não
  distribui conexões entre workers (no Linux distribui) e o Crescent 2 ficava preso a
  um worker. A configuração do benchmark usa o `listen` padrão.

`reports/legacy-1x/` guarda os relatórios antigos do benchmark só do 1.x
(setembro de 2026), feitos com outra metodologia; não compare diretamente.
