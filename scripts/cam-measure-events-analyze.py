"""cam-measure events mode: lost starts and motion-to-broker latency.

Camera times: /proc/uptime mapped to UTC by two anchors (start and end), each corrected by the camera's
NTP offset at that moment (busybox ntpd: offset = server - local), interpolated linearly between them.
Broker times: mosquitto_sub %U on the broker host (its own NTP offset is a few ms and is reported, not applied).

Usage: scripts/cam-measure-events-analyze.py <ipc log> <start anchor> <start offset s> <end anchor> <end offset s> <mqtt text file>...
Anchors are "epoch:uptime".
"""
import statistics
import sys
from datetime import datetime, timezone

IDS = {"7c": "start", "e6": "start_c", "7d": "stop"}
RETAINED_BURST_S = 1.5
DUP_WINDOW_S = 1.0
MATCH_WINDOW_S = 5.0
OPEN_EVENT_S = 60.0


def utc(t):
    return datetime.fromtimestamp(t, timezone.utc).strftime("%H:%M:%S.%f")[:-3] + "Z"


def mapper(a0, o0, a1, o1):
    e0, u0 = (float(x) for x in a0.split(":"))
    e1, u1 = (float(x) for x in a1.split(":"))

    def to_utc(up):
        t0 = e0 + (up - u0) + o0
        t1 = e1 + (up - u1) + o1
        w = min(max((up - u0) / (u1 - u0), 0.0), 1.0)
        return t0 + (t1 - t0) * w

    drift = (e1 + o1) - (e0 + o0 + (u1 - u0))
    return to_utc, drift


def read_ipc(path, to_utc):
    events, start, end = [], None, None
    for raw in open(path):
        parts = raw.split()
        if parts[0] == "start_uptime":
            start = float(parts[1])
        elif parts[0] == "end_uptime":
            end = float(parts[1])
        else:
            up, hexbytes = float(parts[0]), parts[1:]
            events.append((to_utc(up), IDS[hexbytes[8]]))
    return events, to_utc(start), to_utc(end)


def read_mqtt(paths):
    kept = []
    topics = {}
    for path in paths:
        lines = []
        for raw in open(path):
            parts = raw.rstrip("\n").split(" ", 3)
            if len(parts) < 3:
                continue
            # Multi-line payloads (motion_files JSON) continue on lines with no timestamp.
            try:
                t = float(parts[0])
            except ValueError:
                continue
            topic = parts[1]
            payload = parts[3] if len(parts) > 3 else ""
            lines.append((t, topic, payload))
        if not lines:
            continue
        first = lines[0][0]
        for t, topic, payload in lines:
            if t - first <= RETAINED_BURST_S:
                continue
            topics[topic] = topics.get(topic, 0) + 1
            kept.append((t, topic, payload))
    kept.sort()
    merged = []
    for t, topic, payload in kept:
        if any(topic == mt and payload == mp and abs(t - mtime) <= DUP_WINDOW_S for mtime, mt, mp in merged[-20:]):
            continue
        merged.append((t, topic, payload))
    return merged, topics


def main():
    ipc_path, a0, o0, a1, o1, *mqtt_paths = sys.argv[1:]
    to_utc, drift = mapper(a0, float(o0), a1, float(o1))
    ipc, w_start, w_end = read_ipc(ipc_path, to_utc)
    mqtt, topics = read_mqtt(mqtt_paths)
    mqtt = [m for m in mqtt if w_start <= m[0] <= w_end + MATCH_WINDOW_S]
    starts = [m[0] for m in mqtt if m[2] == "motion_start"]
    stops = [m[0] for m in mqtt if m[2] == "motion_stop"]

    print(f"Window {utc(w_start)} to {utc(w_end)} ({w_end - w_start:.0f} s); anchor drift over the window {drift * 1000:+.0f} ms")
    print("MQTT topics in window (after dedupe):", ", ".join(f"{k}={v}" for k, v in sorted(topics.items())))
    print()

    used = set()
    rows, lost, expected_quiet, latencies = [], 0, 0, {"start": [], "stop": []}
    last_start, last_stop = None, None
    for t, kind in ipc:
        is_start = kind in ("start", "start_c")
        pool = starts if is_start else stops
        match = next((m for m in pool if m not in used and 0 <= m - t <= MATCH_WINDOW_S), None)
        note = ""
        if match is not None:
            used.add(match)
            lat = match - t
            latencies["start" if is_start else "stop"].append(lat)
            note = f"{utc(match)} | {lat:+.3f}"
        elif is_start:
            inside_open = last_start is not None and t - last_start <= OPEN_EVENT_S and (last_stop is None or last_stop < last_start)
            if inside_open:
                expected_quiet += 1
                note = "none | inside open event (not counted)"
            else:
                lost += 1
                note = "none | **LOST**"
        else:
            note = "none | stop not published"
        rows.append(f"| {utc(t)} | `0x{[k for k, v in IDS.items() if v == kind][0]}` | {note} |")
        if is_start:
            last_start = t
        else:
            last_stop = t

    print("| IPC (camera, NTP-corrected) | id | MQTT (broker) | latency s |")
    print("|---|---|---|---|")
    print("\n".join(rows))
    n_starts = sum(1 for _, k in ipc if k != "stop")
    counted = n_starts - expected_quiet
    print()
    print(f"IPC starts: {n_starts} ({sum(1 for _, k in ipc if k == 'start')} x 0x7c, {sum(1 for _, k in ipc if k == 'start_c')} x 0xe6); "
          f"stops: {sum(1 for _, k in ipc if k == 'stop')}")
    print(f"Lost starts: {lost} of {counted} counted ({expected_quiet} inside an open event, not counted)")
    unmatched = [utc(m) for m in starts + stops if m not in used]
    print(f"MQTT start/stop with no IPC match: {len(unmatched)} {unmatched}")
    for k, v in latencies.items():
        if v:
            print(f"Latency {k}: n={len(v)} median {statistics.median(v):.3f} s, min {min(v):.3f}, max {max(v):.3f}")


if __name__ == "__main__":
    main()
