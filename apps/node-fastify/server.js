// Node.js + Fastify benchmark app: same endpoints as every app in ../.
// WORKERS > 1 forks that many processes sharing the port (node:cluster).
import cluster from 'node:cluster';
import Fastify from 'fastify';
import mysql from 'mysql2/promise';

const PORT = Number(process.env.PORT || 8103);
const WORKERS = Number(process.env.WORKERS || 1);

if (WORKERS > 1 && cluster.isPrimary) {
  for (let i = 0; i < WORKERS; i++) cluster.fork();
} else {
  const pool = mysql.createPool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'crescent_bench',
    connectionLimit: Number(process.env.DB_POOL || 16),
  });

  const app = Fastify({ logger: false });

  app.get('/plain', async (req, reply) => {
    reply.type('text/plain; charset=utf-8');
    return 'Hello, World!';
  });

  app.get('/json', async () => ({ message: 'Hello, World!' }));

  app.get('/params/:id', async (req) => ({ id: req.params.id, q: req.query.q }));

  app.post('/echo', async (req) => req.body);

  app.get('/db/:id', async (req, reply) => {
    const [rows] = await pool.execute('SELECT id, name, value FROM bench_items WHERE id = ?', [Number(req.params.id)]);
    if (!rows[0]) return reply.code(404).send({ error: 'not found' });
    return rows[0];
  });

  app.get('/db', async () => {
    const [rows] = await pool.query('SELECT id, name, value FROM bench_items ORDER BY id LIMIT 20');
    return rows;
  });

  app.post('/db', async (req, reply) => {
    const name = String(req.body?.name ?? 'item');
    const value = Number(req.body?.value) || 0;
    const [result] = await pool.execute('INSERT INTO bench_items (name, value) VALUES (?, ?)', [name, value]);
    return reply.code(201).send({ id: result.insertId, name, value });
  });

  await app.listen({ host: '127.0.0.1', port: PORT });
}
