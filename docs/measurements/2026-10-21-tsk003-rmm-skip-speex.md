# 2026-10-21 — TSK-003: rmm with speex preprocessing skipped (patch A)

**Result:** skipping `speex_preprocess_run` cuts rmm from 52.8 % to 45.5 % (−7.3 points). The busiest rmm thread, probably the audio thread, drops from 31.2 % to 23.6 % (−7.6 points). Other rmm threads stay within ±0.2 points. A 1-minute SD clip recorded under the patch has 720p and 360p H.264 video plus AAC audio, decodes cleanly, and shows a normal picture. The speex share of the audio thread is about 7.6 points; the remaining ~23.6 points are capture plus AAC encoding (`HI_MPI_AENC_SendFrame`), which patch A keeps.

**Kill line:** −7.3 points is under the 10-point line in TSK-003. Patch A alone does not meet the CPU target. Patches B (skip AAC encode) and C (no audio thread) from `docs/research/rmm.md` remain untested and target the other ~23.6 points.

## Patch

- Record: `patches/rmm-1.9.1.0J-skip-speex-preprocess.json` (file offset `0x2ee64`, `d6 88 04 eb` → `00 00 a0 e1`; input sha256 `ce4e24aa…e50050`, output sha256 `4183cd12…29b2f`)
- Installed as a new file, `/tmp/sd/yi-dome-hack/rmm-skip-speex/rmm`. Stock `/home/app/rmm` untouched. The folder keeps the process name `rmm`, which `cam-measure-cpu.sh` looks for

## Settings

- Same boot as the mic-ON control in `2026-10-21-tsk003-mic-runtime-off.md` (boot about 12:13Z UTC)
- Live swap at 15:46:13Z: `killall rmm`, then the patched copy started by hand from `/home/app` with the stock process's `LD_LIBRARY_PATH` and `TZ`. Restarted once at about 15:47Z to give the process the name `rmm`
- h264grabber lost its stream after the swap. It was killed at 15:48Z and restarted by `wd_rtsp.sh` at 15:48:58Z (a hand-started duplicate was killed). rRTSPServer was killed at 15:56Z and restarted by `wd_rtsp.sh` at 15:56:29Z
- `MOTION_TRACKING=yes`, `SENSITIVITY=medium`, mic ON. Only the TSK-001 mqttv4 patch otherwise
- RTSP clients per window (start/end): 2/5, 5/0, 0/0. rRTSPServer CPU is therefore not comparable with the control; rmm is
- Camera rebooted to stock at 16:05:04Z, right after the run

## Method

`scripts/cam-measure-cpu.sh`, unchanged, 3 × 300 s. Windows from about 15:49:27Z to 16:04:26Z. Raw: `2026-10-21-tsk003-skip-speex-cpu-raw.txt`. Clip check: `/tmp/sd/record/2026Y10M21D17H/55M00S.mp4` (camera local time, under the patch) copied to the Mac, `ffprobe` for streams, `ffmpeg -f null` decode, one frame extracted and viewed. The local copy was deleted afterwards.

## CPU

| window | length s | RTSP est. start/end | all processes % | rmm % | load1 mean | MemFree kB min/mean |
|---|---|---|---|---|---|---|
| 1 | 299.4 | 2/5 | 55.1 | 45.2 | 6.72 | 676/967 |
| 2 | 298.2 | 5/0 | 52.4 | 45.7 | 6.41 | 600/1086 |
| 3 | 299.2 | 0/0 | 51.6 | 45.4 | 5.27 | 756/859 |

Load1 mean over all samples: 6.13 (n=18). Control: 5.91.

### rmm threads, control (mic ON, stock rmm) against patch A (mean of 3 windows)

| role (inferred) | control tid | control % | patch tid | patch % | delta |
|---|---|---|---|---|---|
| audio capture (`0x36cf8`) | 1523 | 31.2 | 1182 | 23.6 | −7.6 |
| motion detection + tracking | 1525 | 10.5 | 1185 | 10.6 | +0.1 |
| ISP 3A | 1517 | 5.9 | 1176 | 5.8 | −0.1 |
| hi_Adec0_Send | 1515 | 1.2 | 1174 | 1.3 | +0.1 |
| hi_Adec0_Dec | 1516 | 0.8 | 1175 | 0.8 | 0.0 |
| rmm total | | 52.8 | | 45.5 | −7.3 |

Roles are matched by CPU share and creation order; `/proc` does not show thread entry points.

## Side effect: the live swap breaks HA live view

After the swap, HA showed no image even after h264grabber and rRTSPServer were restarted. The camera was then rebooted to stock. A live rmm swap is not a usable deploy path; a persistent patch has to start the patched rmm at boot (system.sh change), so every consumer attaches to it from the start.
