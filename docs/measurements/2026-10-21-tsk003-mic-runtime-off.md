# 2026-10-21 — TSK-003: runtime mic switch `ipc_cmd -I OFF` (no CPU effect)

**Result:** `ipc_cmd -I OFF` does not reduce rmm CPU. rmm went from 52.8 % to 52.2 % (−0.6 points, inside window-to-window noise). The busiest rmm thread, probably the audio thread, went from 31.2 % to 31.5 %. This matches the static reading in `docs/research/rmm.md`: with the mic muted, the audio loop still runs speex preprocessing and AAC encoding and only zeroes the frame (`cfg[0x8c0] == 101`). The runtime switch is ruled out. The TSK-003 alternative, the rmm instruction patch at file offset `0x2ee64`, is next.

**Mode:** cpu, two runs of 3 × 300 s, back to back. A fresh mic-ON control replaces the TSK-002 baseline because conditions differ (0 RTSP clients now, 7–10 then).

## Settings

- Same boot for both runs (boot about 12:13Z UTC). Camera uptime at the control's first window: 9882 s
- Patches deployed: only `patches/mqttv4-0.4.1-motion-start-e6.json` (TSK-001)
- `camera.conf`: `SENSITIVITY=medium`, `MOTION_TRACKING=yes`
- RTSP clients: 0 established on port 554 at every window start and end
- No sniffer ran and no motion activity was recorded
- Mic switched OFF with `ipc_cmd -I OFF` at 15:13:05Z (rc 0) and back ON with `ipc_cmd -I ON` at 15:28:33Z (rc 0)

## Method

`scripts/cam-measure-cpu.sh`, unchanged (method in `2026-10-21-tsk002-stock-baseline.md`). Tables come from `scripts/cam-measure-summary.py`.

- Control (mic ON): about 14:57:53Z to 15:12:52Z, raw `2026-10-21-tsk003-mic-on-cpu-raw.txt`
- Mic OFF: about 15:13:10Z to 15:28:09Z, raw `2026-10-21-tsk003-mic-off-cpu-raw.txt`

## CPU

| run | window | length s | all processes % | rmm % | load1 mean | MemFree kB min/mean |
|---|---|---|---|---|---|---|
| mic ON | 1 | 299.0 | 60.5 | 52.9 | 6.11 | 596/669 |
| mic ON | 2 | 298.8 | 60.8 | 52.9 | 5.72 | 748/848 |
| mic ON | 3 | 298.5 | 59.9 | 52.6 | 5.89 | 672/859 |
| mic OFF | 1 | 299.1 | 59.7 | 52.3 | 5.61 | 596/702 |
| mic OFF | 2 | 299.3 | 59.2 | 51.8 | 5.75 | 688/868 |
| mic OFF | 3 | 299.2 | 59.8 | 52.5 | 5.88 | 748/851 |

Load1 mean over all samples: 5.91 mic ON, 5.75 mic OFF (n=18 each).

### rmm threads (mean of 3 windows, ≥ 0.5 %)

| tid | comm | mic ON % | mic OFF % | likely role |
|---|---|---|---|---|
| 1523 | rmm | 31.2 | 31.5 | audio capture (`0x36cf8`) |
| 1525 | rmm | 10.5 | 10.0 | motion detection + tracking |
| 1517 | rmm | 5.9 | 5.8 | ISP 3A |
| 1521 | rmm | 1.2 | 1.2 | |
| 1515 | hi_Adec0_Send | 1.2 | 1.1 | speaker decode |
| 1522 | rmm | 1.0 | 1.0 | |
| 1516 | hi_Adec0_Dec | 0.8 | 0.6 | speaker decode |
| 1519 | rmm | 0.5 | 0.5 | |

The roles come from CPU share and creation order, matched against `docs/research/rmm.md`. TIDs are one higher than the earlier boot recorded there. `/proc` does not show a thread's entry point, so these roles are inferred, not confirmed.

## Kill line

Not decided by this run: the runtime switch is only the first option in the TSK-003 criterion. The 2026-11-10 kill line applies to the patch result.
