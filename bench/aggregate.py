"""Collapses the rounds of results.csv into one row per (app, workers, scenario).

Throughput and latencies use the median across rounds; rps_min/rps_max show
the spread; errors are summed; memory is the maximum observed.
"""
import csv
from statistics import median


def _f(value):
    return float(value) if value not in ("", None) else None


def load(path):
    groups = {}
    for r in csv.DictReader(open(path)):
        key = (r["app"], int(r["workers"]), r["scenario"])
        groups.setdefault(key, []).append(r)
    out = []
    for (app, workers, scenario), rs in groups.items():
        def med(col):
            vals = [_f(r[col]) for r in rs if _f(r[col]) is not None]
            return round(median(vals), 3) if vals else None
        rps = [_f(r["requests_per_sec"]) for r in rs if _f(r["requests_per_sec"]) is not None]
        rss = [_f(r["rss_mb"]) for r in rs if _f(r["rss_mb"]) is not None]
        out.append({
            "app": app, "workers": workers, "scenario": scenario, "rounds": len(rs),
            "rps": round(median(rps), 2) if rps else None,
            "rps_min": min(rps) if rps else None,
            "rps_max": max(rps) if rps else None,
            "avg": med("latency_avg_ms"), "p50": med("p50_ms"), "p90": med("p90_ms"), "p99": med("p99_ms"),
            "requests": int(sum(_f(r["requests"]) or 0 for r in rs)) if rps else None,
            "errors": int(sum(_f(r["errors"]) or 0 for r in rs)) if rps else None,
            "non2xx": int(sum(_f(r["non_2xx"]) or 0 for r in rs)) if rps else None,
            "rss": int(max(rss)) if rss else None,
            # idle rows: median idle memory is more representative than max
            "rss_idle": int(median(rss)) if rss and scenario == "idle" else None,
        })
    return out
