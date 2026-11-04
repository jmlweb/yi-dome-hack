"""Summarise cam-measure-cpu.sh and cam-measure-snapshot.sh raw output as markdown tables.

Usage: scripts/cam-measure-summary.py <cpu raw> <snapshot raw>
"""
import statistics
import sys

HZ = 100


def parse_stat(line):
    body = line[2:]
    pid, rest = body.split(" (", 1)
    comm, rest = rest.rsplit(") ", 1)
    fields = rest.split()
    # fields[0] is state (field 3); utime is field 14, stime field 15
    return int(pid), comm, int(fields[11]) + int(fields[12])


def parse_cpu(path):
    snaps, mems, loads, rtsp = {}, [], [], {}
    cur = None
    for raw in open(path):
        line = raw.rstrip("\n")
        if line.startswith("SNAP "):
            _, label, up = line.split()
            cur = {"up": float(up), "P": {}, "T": {}}
            snaps[label] = cur
        elif line.startswith("P ") and cur is not None:
            pid, comm, ticks = parse_stat(line)
            cur["P"][pid] = (comm, ticks)
        elif line.startswith("T ") and cur is not None:
            tid, comm, ticks = parse_stat(line)
            cur["T"][tid] = (comm, ticks)
        elif line.startswith("ENDSNAP"):
            cur = None
        elif line.startswith("MEM "):
            _, up, kb = line.split()
            mems.append((float(up), int(kb)))
        elif line.startswith("LOAD "):
            _, up, l1, l5, l15, _rq = line.split()
            loads.append((float(up), float(l1), float(l5), float(l15)))
        elif line.startswith("RTSP "):
            _, label, n = line.split()
            rtsp[label] = int(n)
    return snaps, mems, loads, rtsp


def deltas(a, b, key):
    out = {}
    for pid, (comm, t1) in b[key].items():
        if pid in a[key]:
            out[(pid, comm)] = t1 - a[key][pid][1]
    return out


def main(cpu_path, snap_path):
    snaps, mems, loads, rtsp = parse_cpu(cpu_path)
    per_window = []
    for w in (1, 2, 3):
        a, b = snaps[f"start{w}"], snaps[f"end{w}"]
        win = b["up"] - a["up"]
        p = deltas(a, b, "P")
        t = deltas(a, b, "T")
        w_mem = [kb for up, kb in mems if a["up"] <= up <= b["up"]]
        w_load = [l1 for up, l1, _, _ in loads if a["up"] <= up <= b["up"]]
        total = sum(p.values())
        per_window.append({"w": w, "win": win, "p": p, "t": t, "mem": w_mem, "load": w_load,
                           "total": total, "rtsp": (rtsp.get(f"start{w}"), rtsp.get(f"end{w}"))})

    print("## CPU windows\n")
    print("| window | length s | RTSP est. start/end | sum all procs % | rmm % | load1 mean | MemFree kB min/mean |")
    print("|---|---|---|---|---|---|---|")
    for r in per_window:
        rmm = sum(v for (pid, c), v in r["p"].items() if c == "rmm")
        pct = lambda ticks: ticks / (r["win"] * HZ) * 100
        print(f"| {r['w']} | {r['win']:.1f} | {r['rtsp'][0]}/{r['rtsp'][1]} | {pct(r['total']):.1f} | "
              f"{pct(rmm):.1f} | {statistics.mean(r['load']):.2f} (n={len(r['load'])}) | "
              f"{min(r['mem'])}/{statistics.mean(r['mem']):.0f} (n={len(r['mem'])}) |")

    all_load = [l for r in per_window for l in r["load"]]
    print(f"\nLoad1 mean over all samples: {statistics.mean(all_load):.2f} (n={len(all_load)})\n")

    names = sorted({c for r in per_window for (_, c) in r["p"]})
    rows = []
    for c in names:
        vals = [sum(v for (_, cc), v in r["p"].items() if cc == c) / (r["win"] * HZ) * 100 for r in per_window]
        if max(vals) >= 0.1:
            rows.append((statistics.mean(vals), c, vals))
    print("### Per-process CPU % (>= 0.1 % in any window)\n")
    print("| process | w1 | w2 | w3 | mean |")
    print("|---|---|---|---|---|")
    for mean, c, vals in sorted(rows, reverse=True):
        print(f"| {c} | {vals[0]:.1f} | {vals[1]:.1f} | {vals[2]:.1f} | {mean:.1f} |")

    print("\n### rmm threads CPU %\n")
    print("| tid | comm | w1 | w2 | w3 | mean |")
    print("|---|---|---|---|---|---|")
    tids = sorted({k for r in per_window for k in r["t"]})
    trows = []
    for k in tids:
        vals = [r["t"].get(k, 0) / (r["win"] * HZ) * 100 for r in per_window]
        trows.append((statistics.mean(vals), k, vals))
    for mean, (tid, comm), vals in sorted(trows, reverse=True):
        print(f"| {tid} | {comm} | {vals[0]:.1f} | {vals[1]:.1f} | {vals[2]:.1f} | {mean:.1f} |")

    print("\n## Snapshot run\n")
    times, rows = [], []
    for raw in open(snap_path):
        i, stamp, code, size, t = raw.split()
        rows.append((i, stamp, code, size, t))
        if code == "200" and int(size) > 0:
            times.append(float(t))
    print("| # | UTC | HTTP | bytes | s |")
    print("|---|---|---|---|---|")
    for i, stamp, code, size, t in rows:
        print(f"| {i} | {stamp} | {code} | {size} | {float(t):.2f} |")
    ok = len(times)
    print(f"\nOK {ok}/{len(rows)}; median {statistics.median(times):.2f} s; max {max(times):.2f} s; "
          f"min {min(times):.2f} s; pass (median < 2 s and max < 4 s): "
          f"{'yes' if ok == len(rows) and statistics.median(times) < 2 and max(times) < 4 else 'no'}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
