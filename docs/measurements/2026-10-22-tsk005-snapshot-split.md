# 2026-10-22 — TSK-005: snapshot time split (CGI and MQTT paths)

**Result:** a still at `res=low` takes about 1.1 s on both paths. The 2 s target is met today, and the 4–13 s in `docs/evaluation.md` did not reproduce. The grab itself is 0.57 s. The cost that remains is in `mqttv4`: each motion start blocks its IPC thread for about 1.1 s (0.5 s configured delay plus the grab), and IPC messages that arrive during that window wait. In this run, only duplicate starts (RPT-001) waited, and no event-opening start was delayed.

## Camera state

TSK-004 step 2: cloud off, `wd_rtsp.sh` 24241097, `system.sh` c88928ce. Patched `mqttv4` (TSK-001 `0xe6` mapping). `rmm` stock. Settings as in `2026-10-21-tsk002-stock-baseline.md` (`SNAPSHOT=yes`, `SNAPSHOT_LOW=yes`, `RTSP_STREAM=low`), auto-tracking on. `mqttv4.conf`: `MOTION_IMAGE_DELAY=0.5`, `MQTT_QOS=1`.

## Method

Both paths end in the same grabber: `imggrabber -m <camver> -r low` (stdout JPEG, "native api").

- **CGI total:** `scripts/cam-measure-snapshot.sh`, 20 × `GET /cgi-bin/snapshot.sh?res=low` from the Mac, 30 s apart, 13:55:21Z–14:04:51Z, curl `time_total`. Raw: `2026-10-22-tsk005-snapshot-raw.txt`.
- **Grab only:** `scripts/cam-measure-grab.sh` (new, read-only), `imggrabber` run on the camera with no httpd or CGI, in one SSH session, 30 s apart, timed by `/proc/uptime` deltas (10 ms resolution), from about 14:05Z. Raw: `2026-10-22-tsk005-grab-raw.txt` (`<n> <uptime> <seconds> <bytes>`).
- **MQTT path:** a session on the broker host ran `mosquitto_sub -R -i tsk005-capture -t '<prefix>/#' -F '%U %t %l'` inside `the mosquitto container`, 21:54:24Z–22:24:24Z, broker clock offset +2.8 ms at the start and −0.5 ms at the end. the owner walked past 3 times. `%l` is the payload length: 12 = `motion_start`, 11 = `motion_stop`. Raw: `2026-10-22-tsk005-mqtt.txt`.

The CGI and grab loops ran one after the other, never together. Both runs were cut by unexplained camera reboots (see Caveats).

## CGI path

| | n | median | min | max |
|---|---|---|---|---|
| curl total (HTTP 200) | 19 | 1.05 s | 1.01 s | 1.63 s |
| `imggrabber` on the camera | 15 | 0.57 s | 0.56 s | 0.72 s |
| difference of medians (httpd fork, CGI shell, Wi-Fi) | | 0.48 s | | |

The CGI path has no IPC queue; the 0.48 s is process spawning and transfer. Request #8 (13:58:51Z) got no answer within 15 s because the camera was rebooting. Request #9 ran 40 s after boot (1.47 s) and is kept. Against the stock baseline (median 1.60 s, max 2.75 s), the CGI total is 0.55 s faster at the median. No single change is credited: TSK-003 (rmm audio thread) and TSK-004 steps 1–2 lie between the two runs.

## MQTT path

30 `motion_start`, 30 `motion_detection_image`, 3 `motion_stop` (3 walk-pasts). Every start was followed by exactly one image.

| | value |
|---|---|
| `motion_start` publish → image publish, median | 1.11 s |
| min / max | 1.09 s / 1.25 s |
| breakdown | 0.5 s `MOTION_IMAGE_DELAY` + 0.57 s grab + about 0.04 s JPEG publish |

**Queue wait.** `mqttv4` runs the delay and the grab inside its IPC thread. In 7 of the 30 starts, the start was published within 0.04–0.27 s after the previous image. These are IPC messages that arrived while the thread was blocked and were drained right after. Their true arrival time needs the IPC sniffer, but each waited at most about 1.1 s. Grouped by `motion_stop` boundaries, all 7 were duplicate starts inside an already open event; none of the 3 event-opening starts came within 0.3 s of an image. So the blocking grab did not delay any event start here. Once RPT-001 is fixed, it can only delay messages that land within about 1.1 s after a start, such as a `0x7d` stop of a very short event or a sound event.

**Duplicate starts.** There were 30 starts for 3 events (about 10 per event, 1–2 s apart). This is RPT-001 (the patched `mqttv4` publishes a start for every `0x7c`/`0xe6` inside an open event), and each duplicate triggers its own image grab. RPT-001 and TSK-006 (snapshot off the IPC thread) remove both costs.

## Verdict for `docs/evaluation.md`

The still target (`res=low` median < 2 s, max < 4 s) is reachable, and in this state it is already met on both paths: CGI median 1.05 s / max 1.63 s, MQTT motion image 1.11 s / 1.25 s. The open issue is not still-image time. What is left is the synchronous grab inside `mqttv4`'s IPC thread, which here only delayed RPT-001 duplicates. Fixing RPT-001 removes most of that cost (one grab per event, not about 10), and TSK-006's async snapshot then only matters for messages within about 1.1 s of a start.

## Caveats

- The camera rebooted 7 times between 13:58Z and 15:51Z (HA uptime and status history from the broker host). Five of those reboots came with nothing from this task running. The cause is unknown; see RPT-004. The run before 13:58Z was on 13.8 h of uptime, and the MQTT run was on a 6 h uptime.
- Grab n = 15, not 20: the SSH session died in the 14:12:53Z reboot. The spread (0.56–0.72 s) is narrow enough that the missing 5 do not change the median.
- The CGI and grab windows are not the same 10 minutes, so the 0.48 s overhead is a difference of medians, not paired.
