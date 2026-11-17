# Benchmark do Crescent

Este benchmark executa a aplicação diretamente com `luvit app.lua`, sem Nginx, TLS ou proxy. Ele cria a tabela descartável `benchmark_records`, executa verificações funcionais e mede endpoints HTTP e banco com `wrk`.

## Executar

Na raiz deste diretório:

```bash
./run-benchmark.sh quick
```

Para uma rodada mais longa:

```bash
./run-benchmark.sh full
```

Para descobrir o ponto de degradação por conexões simultâneas:

```bash
./run-capacity-test.sh
```

A matriz padrão testa `10 25 50 100 200 400 800` conexões, por `15s` em cada nível. Para uma rodada curta:

```bash
CAPACITY_DURATION=3s CAPACITY_CONNECTIONS="10 25 50 100" ./run-capacity-test.sh
```

O relatório marca cada nível como `healthy` ou `degraded`. Um nível é degradado quando há respostas não-2xx/erros ou p99 acima de `500ms`. O maior nível saudável é uma referência de capacidade para aquela máquina e configuração, não uma garantia de usuários humanos equivalentes.

Variáveis opcionais:

```bash
BENCHMARK_DURATION=30s BENCHMARK_THREADS=4 BENCHMARK_CONNECTIONS=100 ./run-benchmark.sh full
```

A porta é lida do `.env` (`APP_PORT`) ou pode ser sobrescrita com `BENCHMARK_PORT`.

## Cenários

- `/health`: health check mínimo.
- `/benchmark/plain`: texto, menor overhead de serialização.
- `/benchmark/json`: resposta JSON.
- `/benchmark/params/{id}`: roteamento e decodificação de parâmetro.
- `/benchmark/echo`: leitura e parsing de body JSON.
- `/benchmark`: leitura ORM limitada a 50 registros.
- `/benchmark/db/count`: consulta `COUNT` no MySQL.
- POST `/benchmark`: inserção ORM no MySQL usando `wrk-post.lua`.

## Relatório

Cada execução cria `reports/<timestamp>/report.md`, contendo:

- configuração da rodada;
- respostas funcionais;
- saída completa de cada caso `wrk`;
- snapshot do processo do servidor;
- interpretação dos indicadores;
- logs do servidor e arquivos brutos por cenário.

O runner executa `luvit crescent-cli.lua migrate` antes de iniciar o servidor. As tabelas do benchmark são isoladas e a tabela `benchmark_records` pode ser apagada sem afetar a aplicação existente.

## Indicadores

- `Requests/sec`: throughput observado.
- `Latency`: latência média e distribuição.
- `Non-2xx`: respostas de erro durante a carga.
- `p50`, `p75`, `p90`, `p99`: percentis de latência.

O benchmark não substitui uma rodada atrás do Nginx nem um teste distribuído. Esses cenários devem ser adicionados separadamente quando a configuração de produção estiver definida.
