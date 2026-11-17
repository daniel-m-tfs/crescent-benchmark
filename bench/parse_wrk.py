"""Turns one `wrk --latency` output into a CSV row (see run.sh header)."""
import re
import sys

UNITS = {"us": 0.001, "ms": 1.0, "s": 1000.0, "m": 60000.0}


def ms(text):
    m = re.match(r"([\d.]+)(us|ms|s|m)$", text)
    return round(float(m.group(1)) * UNITS[m.group(2)], 3) if m else ""


def main(path, app, workers, scenario, rss):
    out = open(path, encoding="utf-8", errors="replace").read()
    rps = re.search(r"Requests/sec:\s+([\d.]+)", out)
    avg = re.search(r"Latency\s+(\S+)", out)
    pct = dict(re.findall(r"^\s+(50|90|99)%\s+(\S+)", out, re.M))
    total = re.search(r"(\d+) requests in", out)
    sock = re.search(r"Socket errors: connect (\d+), read (\d+), write (\d+), timeout (\d+)", out)
    non2xx = re.search(r"Non-2xx or 3xx responses: (\d+)", out)
    errors = sum(int(x) for x in sock.groups()) if sock else 0
    row = [
        app, workers, scenario,
        rps.group(1) if rps else "0",
        ms(avg.group(1)) if avg else "",
        ms(pct.get("50", "")), ms(pct.get("90", "")), ms(pct.get("99", "")),
        total.group(1) if total else "0",
        errors,
        non2xx.group(1) if non2xx else 0,
        rss,
    ]
    print(",".join(str(x) for x in row))


if __name__ == "__main__":
    main(*sys.argv[1:6])
