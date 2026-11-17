"""Builds reports/<stamp>/report.md from results.csv and environment.txt."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from aggregate import load  # noqa: E402

LABELS = {
    "crescent-1x": "Crescent 1.x (Luvit)",
    "crescent-2": "Crescent 2 (OpenResty)",
    "node-fastify": "Node + Fastify",
    "python-fastapi": "Python + FastAPI",
}
APPS = list(LABELS)
SCENARIOS = [
    ("plain", "GET /plain — texto"),
    ("json", "GET /json — JSON pequeno"),
    ("params", "GET /params/{id}?q= — rota com parâmetro"),
    ("echo", "POST /echo — parse + serialização de JSON"),
    ("db-one", "GET /db/{id} — 1 linha por PK (aleatória)"),
    ("db-list", "GET /db — 20 linhas"),
    ("db-insert", "POST /db — INSERT"),
    ("orm-one", "GET /orm/{id} — 1 linha via Model (só Crescent)"),
]


def fmt_int(x):
    return f"{float(x):,.0f}".replace(",", ".")


def main(out_dir):
    out = Path(out_dir)
    rows = []
    for a in load(out / "results.csv"):
        rows.append({
            "app": a["app"], "workers": str(a["workers"]), "scenario": a["scenario"],
            "requests_per_sec": "" if a["rps"] is None else str(a["rps"]),
            "rps_min": a["rps_min"], "rps_max": a["rps_max"], "rounds": a["rounds"],
            "p99_ms": "" if a["p99"] is None else str(a["p99"]),
            "requests": str(a["requests"] or 0), "errors": str(a["errors"] or 0),
            "non_2xx": str(a["non2xx"] or 0),
            "rss_mb": str(a["rss_idle"] if a["scenario"] == "idle" else (a["rss"] or "")),
        })
    env = (out / "environment.txt").read_text().strip()
    by = {(r["app"], r["workers"], r["scenario"]): r for r in rows}
    workers_list = sorted({r["workers"] for r in rows}, key=int)

    md = ["# Benchmark: Crescent 1.x × Crescent 2 × Node × Python", ""]
    md += ["```", env, "```", ""]
    rounds = max((r["rounds"] for r in rows), default=1)
    md += [f"Mediana de {rounds} rodada(s). " if rounds > 1 else ""]
    md += ["Valores: requisições por segundo (maior é melhor) e, entre parênteses, "
           "latência p99 em ms (menor é melhor). Com mais de uma rodada, a faixa "
           "mín–máx de req/s aparece entre colchetes. `⚠` = houve erros de socket ou "
           "respostas fora de 2xx. Detalhes brutos em `raw/`.", ""]

    for w in workers_list:
        apps = [a for a in APPS if any(k[0] == a and k[1] == w for k in by)]
        if not apps:
            continue
        md += [f"## {w} worker{'s' if w != '1' else ''}", ""]
        md.append("| Cenário | " + " | ".join(LABELS[a] for a in apps) + " |")
        md.append("|---|" + "---:|" * len(apps))
        for key, label in SCENARIOS:
            cells, best = [], 0.0
            for a in apps:
                r = by.get((a, w, key))
                if r and r["requests_per_sec"]:
                    best = max(best, float(r["requests_per_sec"]))
            if best == 0:
                continue
            for a in apps:
                r = by.get((a, w, key))
                if not r or not r["requests_per_sec"]:
                    cells.append("—")
                    continue
                rps = float(r["requests_per_sec"])
                bad = int(r["errors"] or 0) + int(r["non_2xx"] or 0)
                cell = f"{fmt_int(rps)} ({r['p99_ms']})"
                if r["rounds"] > 1 and r["rps_min"] is not None:
                    cell += f" [{fmt_int(r['rps_min'])}–{fmt_int(r['rps_max'])}]"
                if rps == best:
                    cell = f"**{cell}**"
                if bad:
                    cell += " ⚠"
                cells.append(cell)
            md.append(f"| {label} | " + " | ".join(cells) + " |")
        mem = []
        for a in apps:
            idle = by.get((a, w, "idle"), {}).get("rss_mb", "")
            peak = max((int(r["rss_mb"]) for k, r in by.items()
                        if k[0] == a and k[1] == w and r["rss_mb"]), default=0)
            mem.append(f"{idle} → {peak}")
        md.append("| Memória RSS (MB, ociosa → pico) | " + " | ".join(mem) + " |")
        md.append("")

        problems = [r for r in rows if r["workers"] == w and r["scenario"] != "idle"
                    and (int(r["errors"] or 0) or int(r["non_2xx"] or 0))]
        if problems:
            md.append("Erros registrados:")
            for r in problems:
                md.append(f"- {LABELS[r['app']]} / {r['scenario']}: "
                          f"{r['errors']} erros de socket, {r['non_2xx']} respostas fora de 2xx "
                          f"(de {fmt_int(r['requests'])})")
            md.append("")

    (out / "report.md").write_text("\n".join(md) + "\n")


if __name__ == "__main__":
    main(sys.argv[1])
