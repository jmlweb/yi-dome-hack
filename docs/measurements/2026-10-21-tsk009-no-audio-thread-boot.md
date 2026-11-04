# 2026-10-21 — TSK-009: rmm without the audio thread, started at boot

**Result:** with the patched rmm started by `system.sh` and `mp4record` no longer started, rmm runs at 21.0 % (control 52.8 %, −31.8 points) and all processes at 25 % (control 60 %). Load1 mean 4.76 (control 5.91, −19 %). MemFree mean about 1 700 kB (control about 800 kB). mqttv4 was running and connected within 47 s on 3 consecutive reboots. A 58-minute events run with tracking on lost no motion starts: 9 IPC starts (8 `0xe6`, 1 `0x7c`), 9 MQTT `motion_start`. HA live view, snapshot and MQTT switches worked (checked by the owner).

## Change

- `system.sh` (sha256 `0b2a0b05…ba60e` → `0ef987a0…f608`, backup `/tmp/sd/yi-dome-hack-backup/20261021T203354Z/`): the `DISABLE_CLOUD=yes` branch starts `/tmp/sd/yi-dome-hack/rmm-no-audio/rmm` (`patches/rmm-1.9.1.0J-no-audio-thread.json`, sha256 `60a399ac…4e9956`) instead of `./rmm`, and its `REC_WITHOUT_CLOUD` block that starts `mp4record` is removed (ADR-0008)
- Rollback: `scripts/cam-ssh.sh 'cp /tmp/sd/yi-dome-hack-backup/20261021T203354Z/tmp/sd/yi-hack-v5/script/system.sh /tmp/sd/yi-hack-v5/script/system.sh'`, then `busybox reboot`

## Settings

- `camera.conf`: `MOTION_TRACKING=yes`, `SENSITIVITY=medium`. Only other patch: TSK-001 mqttv4
- Control: the mic-ON stock run in `2026-10-21-tsk003-mic-runtime-off.md`
- RTSP clients per CPU window (start/end): 1/0, 0/0, 0/0. No RTSP client during the events run except the owner's HA check
- Motion during the events run came mostly from a 3D printer in view

## Boot (3 reboots, 20:34Z, 20:37Z, 20:39Z)

Checked with `scripts/cam-boot-check.sh` (reads `/proc/<pid>/stat` only) and established connections to port 1883 in `/proc/net/tcp`, polled from the Mac.

| reboot | rmm exe | mp4record | mqttv4 started (uptime) | both MQTT connections up |
|---|---|---|---|---|
| 1 | SD patched | not running | ≤ 45 s | by 175 s (first check) |
| 2 | SD patched | not running | 44.5 s | by 117 s (first check) |
| 3 | SD patched | not running | 44 s | 46.8 s |

On every boot, stock ones included (watchdog log entries of earlier boots), the `mqttv4` launched by `system.sh` exits and `wd_rtsp.sh` restarts it twice; the second restart stays up. The mqttv4 failure seen with patch C on 2026-10-21 (`2026-10-21-tsk003-rmm-no-audio-thread.md`) did not reproduce. That boot still ran `mp4record`, stalled before it drains `/ipc_rcd` (`docs/research/mp4record.md`); the link is suspected, not proven.

## CPU (3 × 300 s, uptime 65 s to 965 s, about 20:41Z to 20:56Z)

| window | length s | RTSP est. start/end | all processes % | rmm % | load1 mean | MemFree kB min/mean |
|---|---|---|---|---|---|---|
| 1 | 299.7 | 1/0 | 26.3 | 21.3 | 4.55 | 772/1531 |
| 2 | 299.6 | 0/0 | 24.8 | 20.9 | 4.84 | 1428/1667 |
| 3 | 299.6 | 0/0 | 24.5 | 20.8 | 4.91 | 1700/1831 |

Raw: `2026-10-21-tsk009-cpu-raw.txt`. Window 1 began about 1 minute after boot, earlier than the 3-minute rule in the cam-measure skill; its numbers match windows 2 and 3 within 0.5 points.

| process | control % | TSK-009 % |
|---|---|---|
| rmm | 52.8 | 21.0 |
| mmcqd/1 (SD I/O) | 2.0 | < 0.1 |
| mp4record | 1.7 | not running |
| rRTSPServer | 1.2 | 1.5 |
| h264grabber | 1.0 | 1.0 |
| all processes | 60.4 | 25.2 |

## Events (21:11:46Z to 22:09:25Z, 3459 s)

- IPC: `cam-measure-events-sniffer.sh` on queue 3. Log: `2026-10-21-tsk009-events-ipc.log`. Anchors `1792617105:1905.55` (offset −11.5 ms) and `1792623294:8094.59` (offset −16.9 ms), both against 185.125.190.58; drift over the window −45 ms
- MQTT: a session on the broker host ran `mosquitto_sub -R -i tsk009-capture -t '<prefix>/#' -F '%U %t %l %p'` inside `the mosquitto container`, 21:06:06Z to 22:11:06Z, broker-host offset +1.1 ms. Kept lines (no image payloads, prefix masked): `2026-10-21-tsk009-events-mqtt.txt`
- Analysis: `scripts/cam-measure-events-analyze.py`

| IPC (camera, NTP-corrected) | id | MQTT motion_start/stop (broker) | MQTT − IPC s |
|---|---|---|---|
| 21:12:56.137Z | `0xe6` | 21:12:55.661Z start | −0.476 |
| 21:15:57.846Z | `0x7d` | 21:15:57.853Z stop | +0.007 |
| 21:16:09.806Z | `0xe6` | 21:16:09.337Z start | −0.469 |
| 21:38:14.366Z | `0x7d` | 21:38:14.371Z stop | +0.005 |
| 21:41:58.685Z | `0xe6` | 21:41:58.212Z start | −0.473 |
| 21:43:19.384Z | `0x7d` | 21:43:19.395Z stop | +0.010 |
| 21:44:00.184Z | `0x7c` | 21:44:00.191Z start | +0.007 |
| 21:44:01.214Z | `0xe6` | 21:44:01.479Z start (second start inside the open event, RPT-001) | +0.265 |
| 21:50:51.701Z | `0x7d` | 21:50:51.719Z stop | +0.018 |
| 21:51:06.521Z | `0xe6` | 21:51:06.064Z start | −0.457 |
| 21:52:12.220Z | `0x7d` | 21:52:12.229Z stop | +0.009 |
| 21:55:14.179Z | `0xe6` | 21:55:13.723Z start | −0.456 |
| 21:56:41.958Z | `0x7d` | 21:56:41.976Z stop | +0.018 |
| 22:01:42.886Z | `0xe6` | 22:01:42.426Z start | −0.460 |
| 22:02:48.726Z | `0x7d` | 22:02:48.741Z stop | +0.015 |
| 22:04:11.655Z | `0xe6` | 22:04:11.194Z start | −0.461 |

- **Lost starts: 0 of 9.** The analyzer reports 7 lost because it only matches MQTT messages after the IPC time. Each of those 7 `0xe6` starts has exactly one MQTT `motion_start` 0.456–0.476 s before it, with no `0x7c` before it. mqttv4 publishes a start only for `0x7c` or (patched) `0xe6`, so each of those MQTT starts comes from the `0xe6` that follows it
- **Latency:** stops median 0.010 s (n=7, max 0.018 s); `0x7c` start 0.007 s (n=1). `0xe6` start latency is not measurable with this sniffer: on `0xe6` the sniffer's timestamp lags by a constant ~0.46 s while stops line up within 20 ms. Suspected cause, unproven: `ipc_read`'s dump of a `0xe6` message waits in a pipe buffer until the next IPC message (tracking sends PTZ messages next)
- 7 stops in the window; the last start (22:04:11Z) had not ended when the window closed

## Open

- Fix the `0xe6` timestamp lag in the sniffer before TSK-008, so `0xe6` start latency becomes measurable
- Why `system.sh`'s first `mqttv4` exits on every boot (stock behaviour; the watchdog covers it)
