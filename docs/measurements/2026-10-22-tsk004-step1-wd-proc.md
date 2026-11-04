# 2026-10-22 — TSK-004 step 1: watchdog reads /proc instead of spawning top and ps

**Result:** the watchdog's CPU, children included, falls from 5.1 % to 1.3 % (−3.8 points). Load1 mean 4.30 (TSK-009 4.76, −10 %). The per-process table shows `wd_rtsp.sh` going *up* from 0.2 % to 1.3 %, because the old cost sat in short-lived `top`, `ps`, `grep`, `netstat`, `cut` and `awk` children that the table does not see (see Method gap). Boot is unchanged: mqttv4 was running with both MQTT connections up by uptime 47.2, 47.1 and 59.4 s on 3 reboots, with the same process set and the same watchdog restarts as before.

## Change

- `wd_rtsp.sh` (sha256 `03b11a3d…e634` → `70e75e3d…24d5`, source `overlay/yi-hack-v5/script/wd_rtsp.sh`, backup `/tmp/sd/yi-dome-hack-backup/20261021T233220Z/`):
  - Each 10 s pass reads every `/proc/<pid>/stat` once with the `read` builtin and sets one flag per watched process: h264grabber, rRTSPServer, rmm, cloud and mqttv4. A zombie counts as running, as it did with `ps | grep`.
  - Config is read once at start.
  - The camera reboot on a missing rmm needs at least one readable `/proc` entry, so an unreadable `/proc` cannot trigger it.
- Dropped as dead code: stock `check_rtsp`'s "locked process" branch. `$RTSP_PORT` is unset in stock `wd_rtsp.sh`, so `netstat | grep ": "` always counted 0 and the branch never ran (checked on the camera 2026-10-22). Only the presence checks had effect, and those are kept.
- Spawns left in the loop: `sleep` once per pass; `date`, `killall` and restarts only when a check fires.
- Rollback: `scripts/cam-ssh.sh 'cp /tmp/sd/yi-dome-hack-backup/20261021T233220Z/tmp/sd/yi-hack-v5/script/wd_rtsp.sh /tmp/sd/yi-hack-v5/script/wd_rtsp.sh'`, then `busybox reboot`

## Settings

- `camera.conf`: `MOTION_TRACKING=yes`. Patches: TSK-001 mqttv4, TSK-009 rmm no-audio-thread started by `system.sh`
- Control: TSK-009 (`2026-10-21-tsk009-no-audio-thread-boot.md`), same patches, stock watchdog
- No RTSP client in any window (0/0 at both ends of each window)

## Boot (3 reboots, 23:33Z, 23:34Z, 23:35Z on 2026-10-21 UTC)

Polled from the Mac after SSH came back (`/proc/<pid>/stat` and established connections to port 1883 in `/proc/net/tcp`), then `scripts/cam-boot-check.sh`. Each first successful poll already showed everything up, so the uptimes are upper bounds.

| reboot | rmm exe | cloud | mqttv4 + both MQTT connections up (uptime) | watchdog log |
|---|---|---|---|---|
| 1 | SD patched | running | ≤ 47.2 s | rRTSPServer started, mqttv4 restarted once |
| 2 | SD patched | running | ≤ 47.1 s | same |
| 3 | SD patched | running | ≤ 59.4 s | same |

mqttv4 and rRTSPServer have the watchdog as parent on every boot, as before (LRN-012).

## CPU (3 × 300 s, uptime 194 s to 1094 s, 23:38Z to 23:53Z)

| window | length s | RTSP est. start/end | all processes % | rmm % | load1 mean | MemFree kB min/mean |
|---|---|---|---|---|---|---|
| 1 | 300.2 | 0/0 | 27.1 | 22.3 | 4.32 | 1188/1383 |
| 2 | 301.2 | 0/0 | 26.7 | 22.0 | 4.39 | 1180/1299 |
| 3 | 298.4 | 0/0 | 26.2 | 21.6 | 4.17 | 1396/1421 |

Raw: `2026-10-22-tsk004-step1-wd-proc-cpu-raw.txt`.

| process | TSK-009 % | step 1 % |
|---|---|---|
| rmm | 21.0 | 22.0 |
| wd_rtsp.sh own (utime+stime) | 0.2 | 1.3 |
| wd_rtsp.sh children (cutime+cstime) | 5.0 | 0.0 |
| **wd_rtsp.sh total** | **5.1** | **1.3** |
| rRTSPServer | 1.5 | 1.2 |
| h264grabber | 1.0 | 0.9 |
| all processes (table, children excluded) | 25.2 | 26.7 |
| load1 mean | 4.76 | 4.30 |

## Method gap

`cam-measure-summary.py` adds up each live process's utime+stime between snapshots. A child that starts and exits between snapshots is never listed, and its time only shows in its parent's cutime/cstime (fields 16–17 of `/proc/<pid>/stat`). Every earlier baseline (TSK-002, TSK-003, TSK-009) therefore leaves out about 5 points of watchdog spawns from "all processes". The step 1 numbers above come from the same raw files with an awk pass over the `wd_rtsp.sh` lines (100 ticks/s).

## Open

- The `/proc` scan is now the watchdog's main cost (1.3 %). Re-checking known pids each pass and rescanning only when one is gone would cut most of that; that is a separate change.
- `cam-measure-summary.py` should report cutime/cstime deltas so spawn-heavy parents stay visible.
