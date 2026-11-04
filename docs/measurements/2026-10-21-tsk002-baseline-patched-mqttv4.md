# 2026-10-21 — TSK-002 baseline: CPU and snapshot (patched mqttv4, not stock)

**Not a stock 0.4.1 baseline.** The camera ran the TSK-001 patched mqttv4 (`patches/mqttv4-0.4.1-motion-start-e6.json`, sha256 `80e5d1d7…1ce972`). the owner chose to measure it as it is and keep the numbers separate from a stock baseline. The patch changes only mqttv4's IPC id mapping, and mqttv4 used under 0.1 % CPU in every window. Even so, these numbers do not stand in for stock.

**Modes:** cpu (3 windows of 300 s) and snapshot (20 requests). The events run and the boot run are still open.

## Settings

- Camera uptime at the first window: 2018 s (boot about 00:19:50Z)
- Patches deployed: only the mqttv4 record above
- `camera.conf`: `SENSITIVITY=medium`, `MOTION_DETECTION=yes`, `MOTION_TRACKING=yes`. Tracking was on for every window. TSK-001 had left it at `no`, and it was found at `yes`
- `system.conf`: `RTSP=yes`, `RTSP_STREAM=low`, `RTSP_AUDIO=no`, `SPEAKER_AUDIO=yes`, `SNAPSHOT=yes`, `SNAPSHOT_LOW=yes`, `SNAPSHOT_VIDEO=no`, `MQTT=yes`, `DISABLE_CLOUD=yes`, `REC_WITHOUT_CLOUD=yes`, `SWAP_FILE=yes`, `NTPD=yes`, `HTTPD=yes`, `SSHD=yes`, `ONVIF=no`, `TIME_OSD=no`
- **RTSP clients connected:** the skill's no-client rule was not met. Between 7 and 10 established TCP connections on port 554 came from one LAN peer, probably HA's stream. the owner OK'd running anyway. Counts per window are in the table. rRTSPServer used about 6.6 % CPU, and `h264grabber` probably carries part of that load too
- No sniffer (`ipc_read`) ran. Motion activity during the windows was not recorded

## Method

- **cpu:** one persistent SSH session ran busybox `sh` on the camera. The camera side used only shell builtins (`read`, `case`, `echo`). The 60 s pacing `sleep` ran on the Mac and fed commands down the session's stdin, so nothing was spawned on the camera inside the loop.
  - At each window's start and end, the camera dumped `/proc/[0-9]*/stat` for every process and `/proc/<rmm pid>/task/*/stat` for each rmm thread.
  - `MemFree` from `/proc/meminfo` and `/proc/loadavg` were sampled at window start and then every 60 s, 6 samples per window.
  - RTSP connections were counted by reading `/proc/net/tcp` with builtins: local port `:022A` in state `01`.
  - CPU % = (utime+stime delta) / (window × 100) × 100. The window is the `/proc/uptime` delta between the two dumps, with HZ = 100.
  - Windows ran back to back, 00:53:26Z to 01:08:27Z.
  - Raw dump: `2026-10-21-tsk002-cpu-raw.txt` (this folder).
- **snapshot:** 20 × `GET /cgi-bin/snapshot.sh?res=low` from the Mac, over Wi-Fi on the same LAN, 30 s apart start to start, from 01:08:27Z to 01:17:58Z, right after the CPU windows. The timing is curl's `time_total`. The httpd credential went to curl on stdin (`-K -`), never on argv.

## CPU

| window | length s | RTSP est. start/end | all processes % | rmm % | load1 mean | MemFree kB min/mean |
|---|---|---|---|---|---|---|
| 1 | 297.6 | 7/9 | 67.8 | 53.2 | 6.56 (n=6) | 604/805 |
| 2 | 299.1 | 9/9 | 68.1 | 52.5 | 6.78 (n=6) | 640/817 |
| 3 | 298.9 | 9/10 | 66.3 | 51.9 | 5.86 (n=6) | 624/773 |

- **Load1 mean, all samples: 6.40 (n=18).** rmm mean: 52.5 %.
- MemFree ran between 604 and 1428 kB. The 1428 kB reading was the first sample, taken just after the first dump.

### Per process (≥ 0.1 % in any window)

| process | w1 | w2 | w3 | mean |
|---|---|---|---|---|
| rmm | 53.2 | 52.5 | 51.9 | 52.5 |
| rRTSPServer | 6.4 | 6.8 | 6.7 | 6.6 |
| usb-thread | 2.2 | 2.3 | 1.8 | 2.1 |
| mmcqd/1 | 1.9 | 2.1 | 1.8 | 1.9 |
| mp4record | 1.7 | 1.7 | 1.7 | 1.7 |
| h264grabber | 0.9 | 1.0 | 0.9 | 0.9 |
| dispatch | 0.5 | 0.5 | 0.5 | 0.5 |
| kswapd0 | 0.3 | 0.2 | 0.2 | 0.2 |
| wd_rtsp.sh | 0.2 | 0.2 | 0.2 | 0.2 |
| wpa_supplicant | 0.1 | 0.1 | 0.1 | 0.1 |
| ksoftirqd/0 | 0.1 | 0.1 | 0.1 | 0.1 |
| sh (the sampler) | 0.1 | 0.1 | 0.1 | 0.1 |
| cloud | 0.1 | 0.1 | 0.1 | 0.1 |

### rmm threads

The thread ids are this boot's. Map them to roles with `docs/research/rmm.md` before comparing across boots.

| tid | comm | w1 | w2 | w3 | mean |
|---|---|---|---|---|---|
| 1522 | rmm | 30.8 | 30.6 | 31.4 | 30.9 |
| 1524 | rmm | 10.7 | 9.8 | 9.0 | 9.8 |
| 1516 | rmm | 6.1 | 6.4 | 6.2 | 6.3 |
| 1514 | hi_Adec0_Send | 1.3 | 1.4 | 1.4 | 1.3 |
| 1520 | rmm | 1.2 | 1.4 | 1.2 | 1.3 |
| 1521 | rmm | 1.1 | 1.0 | 1.0 | 1.1 |
| 1515 | hi_Adec0_Dec | 0.8 | 0.8 | 0.7 | 0.8 |
| 1518 | rmm | 0.5 | 0.5 | 0.5 | 0.5 |
| 1523 | rmm | 0.4 | 0.4 | 0.4 | 0.4 |
| 1507 | rmm (main) | 0.1 | 0.1 | 0.1 | 0.1 |
| 1517, 1519 | rmm | 0.0 | 0.0 | 0.0 | 0.0 |
| 1513 | hi_Aenc0_Get | 0.0 | 0.0 | 0.0 | 0.0 |

## Snapshot

All 20 requests returned 200 with a valid 320×192 JPEG of 13.9 to 14.2 kB.

| stat | value |
|---|---|
| median | 1.62 s |
| min | 1.54 s |
| max | 2.08 s |
| pass (median < 2 s, max < 4 s) | yes |

Per request (s): 1.89, 1.58, 1.58, 1.64, 1.58, 1.92, 1.63, 1.77, 1.56, 1.65, 1.67, 1.58, 1.54, 1.56, 1.61, 1.55, 2.08, 1.61, 2.07, 1.62.

## Open for TSK-002

- A stock 0.4.1 baseline still needs a revert to stock mqttv4. The pre-patch backup is in `/tmp/sd/yi-dome-hack-backup/20261021T002715Z` (sha256 `15f95d70…`).
- Events, 1 h: needs the NTP offset to the broker host first, and aborts if the offset is ≥ 100 ms.
- Boot run: needs the owner's OK.
- A repeat of the cpu mode with no RTSP client connected, to separate the stream's cost from idle.
