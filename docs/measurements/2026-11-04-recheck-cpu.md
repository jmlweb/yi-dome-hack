# 2026-11-04 — CPU re-check, no change deployed

**Result:** the camera was in the TSK-004 step 2 state (cloud off), not step 1. Against the step 2 control (fresh boot, `2026-10-22`): all processes 26.8 % (step 2: 25.3 %), rmm 22.0 % (20.4 %), load1 mean 4.76 (4.58). About 1.5 points higher than step 2, on a camera that had been up 12.4 days. Stock is 60.4 % / 52.8 % / 5.91.

Correction (2026-11-05): the first version of this note compared against step 1. The camera's `system.sh` and `wd_rtsp.sh` matched the step 2 hashes `c88928ce` and `24241097`, and no `cloud` process was running.

## Settings

- Camera up 12.4 days (uptime 1 074 824 s) at the start. No reboot. No RTSP client (only the listening socket on port 554).
- `camera.conf`: `MOTION_TRACKING=yes`, `SENSITIVITY=medium`. `system.conf`: `DISABLE_CLOUD=yes`, `REC_WITHOUT_CLOUD=yes`.
- Patches: TSK-001 mqttv4, TSK-009 rmm no-audio-thread, TSK-004 step 1 watchdog and step 2 cloud off (`system.sh` `c88928ce`, `wd_rtsp.sh` `24241097`).
- Control: the TSK-004 step 2 CPU windows of 2026-10-22 (rmm 20.4 %, all 25.3 %, load1 4.58; raw `2026-10-22-tsk004-step2-cloud-off-cpu-raw.txt`) and the stock baseline in `2026-10-21-tsk002-stock-baseline.md`.

## CPU (3 × 300 s)

| window | length s | RTSP est. start/end | all processes % | rmm % | load1 mean | MemFree kB min/mean |
|---|---|---|---|---|---|---|
| 1 | 299.4 | 0/0 | 27.3 | 22.5 | 4.89 | 1276/1469 |
| 2 | 299.6 | 0/0 | 26.8 | 22.1 | 4.65 | 1488/1489 |
| 3 | 299.6 | 0/0 | 26.4 | 21.6 | 4.76 | 1048/1415 |

Raw: `2026-11-04-recheck-cpu-raw.txt`. Summary: `cam-measure-summary.py` (its snapshot section was fed an old file and is ignored).

| metric | stock | step 2 (10-22) | now (12.4 days up) |
|---|---|---|---|
| rmm % | 52.8 | 20.4 | 22.0 |
| all processes % (table) | 60.4 | 25.3 | 26.8 |
| wd_rtsp.sh % | 5.1 incl. children | 1.5 | 1.3 |
| load1 mean | 5.91 | 4.58 | 4.76 |
| MemFree mean kB | ~800 | not recorded here | ~1 470 |

Largest rmm threads: tid 1525 at 11.9 %, tid 1518 at 5.5 %.
