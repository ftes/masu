"""Timeline summary: port TSV (TimelineFormatter) or Playwright JSON reporter output.

usage: python3 -I analyze.py FILE [--tests]
Prints: wall, sum of test durations, per-module(spec) span and busy time, and the tail
(how long only one lane ran at the end).
"""
import json
import sys
from collections import defaultdict


def port(path):
    starts, tests, mods = {}, [], {}
    for line in open(path):
        f = line.rstrip("\n").split("\t")
        ev, t, mod = f[0], int(f[1]), f[2]
        if not mod.startswith("MasuE2E."):
            continue
        if ev == "module_started":
            mods[mod] = [t, None]
        elif ev == "module_finished":
            mods[mod][1] = t
        elif ev == "test_started":
            starts[(mod, f[3])] = t
        elif ev == "test_finished" and f[5] != "excluded":
            s = starts.get((mod, f[3]), t - int(f[4]))
            tests.append((mod, f[3], s, t, int(f[4]), f[5]))
    return tests, {m: tuple(v) for m, v in mods.items()}


def js(path):
    d = json.load(open(path))
    tests = []

    def walk(suite, spec_file):
        for s in suite.get("suites", []):
            walk(s, spec_file)
        for spec in suite.get("specs", []):
            for t in spec["tests"]:
                for r in t["results"]:
                    if r["status"] == "skipped":
                        continue
                    from datetime import datetime

                    st = datetime.fromisoformat(r["startTime"].replace("Z", "+00:00")).timestamp() * 1000
                    tests.append((spec_file, spec["title"], st, st + r["duration"], r["duration"], r["status"], r["workerIndex"]))

    for s in d["suites"]:
        walk(s, s["file"])
    t0 = min(t[2] for t in tests)
    tests = [(m, n, s - t0, e - t0, dur, st) for (m, n, s, e, dur, st, w) in tests]
    mods = {}
    for m, n, s, e, *_ in tests:
        a, b = mods.get(m, (s, e))
        mods[m] = (min(a, s), max(b, e))
    return tests, mods


def main():
    path = sys.argv[1]
    tests, mods = js(path) if path.endswith(".json") else port(path)
    wall = max(t[3] for t in tests)
    total = sum(t[4] for t in tests)
    print(f"{path}: tests={len(tests)} wall={wall/1000:.1f}s sum_test={total/1000:.1f}s")
    busy = defaultdict(int)
    for m, n, s, e, dur, *_ in tests:
        busy[m] += dur
    for m, (s, e) in sorted(mods.items(), key=lambda kv: kv[1][0]):
        print(f"  {m:32} start={s/1000:6.1f} end={(e or 0)/1000:6.1f} span={((e or 0)-s)/1000:5.1f} tests={busy[m]/1000:5.1f}")
    # concurrency: how long 0/1/2+ tests ran at once
    evs = sorted([(t[2], 1) for t in tests] + [(t[3], -1) for t in tests])
    conc, last, hist = 0, 0, defaultdict(float)
    for t, d in evs:
        hist[conc] += t - last
        conc += d
        last = t
    print("  time at concurrency:", {k: round(v / 1000, 1) for k, v in sorted(hist.items())})
    if "--tests" in sys.argv:
        for m, n, s, e, dur, st, *_ in sorted(tests, key=lambda t: -t[4]):
            print(f"  {dur:6d} {st:7} {m} :: {n}")


main()
