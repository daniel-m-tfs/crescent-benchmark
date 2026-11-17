"""Python + FastAPI benchmark app: same endpoints as every app in ../.

Start: uvicorn main:app --host 127.0.0.1 --port 8104 --workers N
       --loop uvloop --http httptools --no-access-log
"""
import os
from contextlib import asynccontextmanager

import aiomysql
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, PlainTextResponse

pool = None


@asynccontextmanager
async def lifespan(app):
    global pool
    pool = await aiomysql.create_pool(
        host=os.environ.get("DB_HOST", "127.0.0.1"),
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ.get("DB_USER"),
        password=os.environ.get("DB_PASSWORD", ""),
        db=os.environ.get("DB_NAME", "crescent_bench"),
        minsize=1,
        maxsize=int(os.environ.get("DB_POOL", "16")),
        autocommit=True,
    )
    yield
    pool.close()
    await pool.wait_closed()


app = FastAPI(lifespan=lifespan)


@app.get("/plain", response_class=PlainTextResponse)
async def plain():
    return "Hello, World!"


@app.get("/json")
async def json_():
    return {"message": "Hello, World!"}


@app.get("/params/{id}")
async def params(id: str, q: str | None = None):
    return {"id": id, "q": q}


@app.post("/echo")
async def echo(request: Request):
    return await request.json()


@app.get("/db/{id}")
async def db_one(id: int):
    async with pool.acquire() as conn, conn.cursor(aiomysql.DictCursor) as cur:
        await cur.execute("SELECT id, name, value FROM bench_items WHERE id = %s", (id,))
        row = await cur.fetchone()
    if row is None:
        return JSONResponse({"error": "not found"}, status_code=404)
    return row


@app.get("/db")
async def db_list():
    async with pool.acquire() as conn, conn.cursor(aiomysql.DictCursor) as cur:
        await cur.execute("SELECT id, name, value FROM bench_items ORDER BY id LIMIT 20")
        return await cur.fetchall()


@app.post("/db", status_code=201)
async def db_create(request: Request):
    body = await request.json()
    name = str(body.get("name", "item"))
    try:
        value = int(body.get("value", 0))
    except (TypeError, ValueError):
        value = 0
    async with pool.acquire() as conn, conn.cursor() as cur:
        await cur.execute("INSERT INTO bench_items (name, value) VALUES (%s, %s)", (name, value))
        new_id = cur.lastrowid
    return {"id": new_id, "name": name, "value": value}
