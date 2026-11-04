# 2026-10-21 — TSK-003: rmm without the audio thread (patch C)

**Result:** not starting the audio thread cuts rmm from 52.8 % to 22.4 % (−30.4 points) and all processes from about 60 % to 28 %. MemFree rises from about 800 kB to about 1 700 kB mean. **SD recording stops:** mp4record writes no clip and no `tmp.mp4.tmp` for the whole run, and its CPU falls to under 0.1 %. HA live view keeps working. Patch C meets the CPU target but fails the TSK-003 criterion that SD recording keeps working, so it was rolled back.

Compared with patch A (`2026-10-21-tsk003-rmm-skip-speex.md`, −7.3 points with recording intact), the audio thread costs about 30 points, of which speex is about 7.6 and capture plus AAC encoding about 23.

## Patch

- Record: `patches/rmm-1.9.1.0J-no-audio-thread.json` (file offset `0x24218`, `bl pthread_create` → `mov r0,#0`; thread entry `0x36cf8` confirmed from the literal at vaddr `0x2c698`; input sha256 `ce4e24aa…e50050`, output sha256 `60a399ac…4e9956`)
- Installed as a new file, `/tmp/sd/yi-dome-hack/rmm-no-audio/rmm`. Stock `/home/app/rmm` untouched
- Started at boot: `system.sh` line 223 (`DISABLE_CLOUD=yes` branch) changed from `./rmm` to the SD path, deployed with `scripts/cam-deploy-file.sh` (input sha256 `0b2a0b05…ba60e`, output `3188bb1b…e84e61`, backup `/tmp/sd/yi-dome-hack-backup/20261021T181000Z/`)

## Settings

- Boot with patch C at about 18:10Z. mqttv4 was not running after boot and `wd_rtsp.sh` did not restart it; it was started by hand at about 18:13Z and connected to the broker. Cause not found. On the stock reboot afterwards, mqttv4 started normally
- `MOTION_TRACKING=yes`, `SENSITIVITY=medium`. Only the TSK-001 mqttv4 patch otherwise
- RTSP clients per window (start/end): 1/0, 0/0, 0/0
- Control: the mic-ON stock run in `2026-10-21-tsk003-mic-runtime-off.md` (an earlier boot the same day)
- Rollback at 18:29:22Z: `system.sh` restored from the backup (sha256 back to `0b2a0b05…ba60e`), then `busybox reboot`. After the reboot, stock rmm ran from `/home/app/rmm`, mqttv4 started at boot and `tmp.mp4.tmp` was growing again

## Method

`scripts/cam-measure-cpu.sh`, unchanged, 3 × 300 s, camera uptime 233 s to 1133 s (about 18:14Z to 18:29Z). Raw: `2026-10-21-tsk003-no-audio-thread-cpu-raw.txt`. Recording checked by listing `/tmp/sd/record` before and after the run.

## CPU

| window | length s | RTSP est. start/end | all processes % | rmm % | load1 mean | MemFree kB min/mean |
|---|---|---|---|---|---|---|
| 1 | 300.1 | 1/0 | 30.0 | 22.3 | 5.05 | 1500/1805 |
| 2 | 299.2 | 0/0 | 27.4 | 22.6 | 4.88 | 1460/1700 |
| 3 | 299.7 | 0/0 | 27.0 | 22.4 | 5.55 | 1436/1573 |

Load1 mean over all samples: 5.16 (n=18). Control: 5.91.

### rmm threads, control against patch C (mean of 3 windows)

| role (inferred) | control % | patch C % |
|---|---|---|
| audio capture (`0x36cf8`) | 31.2 | not started |
| motion detection + tracking | 10.5 | 11.5 |
| ISP 3A | 5.9 | 5.9 |
| hi_Adec0_Send | 1.2 | 1.3 |
| hi_Adec0_Dec | 0.8 | 0.8 |
| rmm total | 52.8 | 22.4 |

Thread count: 12 instead of 13. Roles are matched by CPU share and creation order.

## Open

- mp4record needs audio frames to write clips. A full CPU cut with recording would need either fake audio frames (for example the speex-skip patch plus a cheaper encoder path) or a recorder that tolerates video-only input.
- Why mqttv4 did not start at boot with patch C.
