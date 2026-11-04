# rmm — static and runtime analysis

Target: `/home/app/rmm` on the Yi Dome 720p (base firmware 1.9.1.0J_201809191135).
Source: `rmm.7z` inside `home_v201` of yi-hack-v5 0.4.1 (jffs2 after a 64-byte uImage header).
Identity: 1 648 868 bytes, md5 `9e1e664cab590d2a6004da06c6e58d0e`, sha256
`ce4e24aab5539289271f9cdd4a005f896669cfb368d8733ceeaf388670e50050` — md5 matches the live camera binary.
Analysed 2026-10-21. Static: Apple `objdump` (ARMv5TE) over the dynamic symbol table; REA opened the
target but no deep provider (Ghidra/Hopper/IDA) is installed, so there is no decompiled pseudocode yet.
Runtime: per-thread `/proc/<pid>/task/<tid>/stat` deltas and PC/`wchan` samples on the camera (read-only).

## Binary shape

- ELF32 ARM EABI5, dynamically linked against uClibc 0.9.33 (`libpthread`, `libm`, `librt`, `libdl`,
  `libgcc_s`, `libc`), stripped of `.symtab` but **exports ~2 170 `.text` symbols** in `.dynsym`.
- The HiSilicon MPP SDK (ISP/AE/AWB, VI, VPSS, VENC, AI/AO/AENC/ADEC, region), FDK-AAC, speex,
  zbar (QR Wi-Fi pairing) and the Yi application code are all **statically linked**. The only
  `hisilib` shipped as `.so` are the audio "hive" VQE plugins (`libhive_*.so`). The sensor driver is
  `/home/app/locallib/libsns_ov9732.so` (OmniVision OV9732).
- Load: `LOAD off 0 → vaddr 0x8000` (r-x), so **file offset = vaddr − 0x8000**.
- No source exists. A "fork" means binary patching, an `LD_PRELOAD` shim, or a replacement app.

## Threads and CPU (live, RTSP low, OSD off, tracking off, no client, 30 s window)

| TID | Entry (vaddr) | Role (evidence) | CPU |
|---|---|---|---|
| 1522 | `0x36cf8` | **audio capture**: `HI_MPI_AI_GetFrame` → `speex_preprocess_run` → `HI_MPI_AENC_SendFrame` (AAC encode in caller) | **29.5%** |
| 1524 | `0x39d00` | motion detection + tracking: polls VPSS (`VpssUserGetFrame`), `modet_process`, `motrk_process` | 10.1% |
| 1516 | SDK | ISP 3A loop (`ISP_GetFrameEdge`) | 7.6% |
| 1514/1515 | SDK | `hi_Adec0_Send` / `hi_Adec0_Dec` (speaker decode) | 2.2% |
| others | `0x35da0`, `0x3732c`, `0x38f7c`, `0x38400`×2, `0x35674` | msg, misc, AENC stream reader | < 2% each |

Running-PC samples of 1522 land in speex preprocess/echo internals (`0x158xxx–0x165xxx`),
`FDKaacEnc_QCMain`, `dit_fft` and `MPI_AENC_*`. Thread entries come from the `pthread_create` calls
in `main` (`0x2c154 … 0x2c250`); creation order matches the TID order.

**Correction to the earlier "rmm is irreducible" claim:** about 60% of `rmm`'s CPU is the
microphone pipeline (noise preprocessing plus AAC encoding), which runs even with `RTSP_AUDIO=no`.
Video encoding runs in hardware.

## Audio thread `0x36cf8` (per-frame loop at `0x36e10`)

```
init: speex_preprocess_state_init(640, 16000) -> r8 ; second state (640, 8000) for pairing mode
loop: HI_MPI_AI_GetFrame
      if pairing_flag == 0:                       ; normal path
          speex_preprocess_run(r8, frame)         ; 0x36e64
      else:                                       ; sound-wave Wi-Fi pairing path
          speex_preprocess_run(state8k) ; XY_pulse_ana_gezhi ; XY_rtc_burr_rmv ; XY_ns_process
      if cfg[0x8c0] == 101: memset(frame, 0)      ; mic mute, encoding still runs
      HI_MPI_AENC_SendFrame                       ; 0x36e84 (AAC encode)
      HI_MPI_AI_ReleaseFrame
```

## Motion / tracking IPC (all to the same POSIX mq handle at `[0x1d3824]`, via `mqueue_send` → `mq_send`)

Header: `u32 dst=1, u32 src=2, u16 id, u16 id, ...`

Copy queues: `rmm` writes to the handle above; `ipc_multiplex.so` (`ipc_multiplex.c`, upstream 0.4.1) opens
`/ipc_dispatch_1` … `/ipc_dispatch_N` and copies every message onto each one. `mqttv4` reads
**`/ipc_dispatch_1`** (`IPC_QUEUE_NAME` in `include/ipc.h`, string at file offset `0x5d1e`); `ipc_read -n 2`
and `-n 3` read the other copies. Before the TSK-001 patch, the camera's `mqttv4` was byte-identical to upstream 0.4.1
(sha256 `15f95d70…37b28dbd`).

| id | Sender | Meaning | mqttv4 0.4.1 |
|---|---|---|---|
| `0x007c` | `send_motion_start_msg` | motion start (plain) | handled (`IPC_MOTION_START`) |
| `0x00e6` | `send_motion_flowwith_start_msg` | **motion start inside a tracking cycle** | **ignored** (handled after the TSK-001 patch: `patches/mqttv4-0.4.1-motion-start-e6.json`) |
| `0x6003` | `send_bigger_move_start_msg` | "bigger move" cloud report | ignored |
| `0x007d` | `send_motion_stop_msg` | motion stop | handled |
| `0x4006` | `rmm_ptz_direction_ctrl` | PTZ move (dir, speed), len 24 | n/a |
| `0x4007` | `rmm_ptz_direction_ctrl_stop` | **PTZ stop**, len 24 | n/a |
| `0x3000` | `send_video_occlusion_msg` | lens occluded | n/a |

The motion thread (`0x39d00`, around `0x3a1ac–0x3a560`): if tracking is on (`cfg[0x8b4] != 0`),
it runs `motrk_process` and moves the PTZ (`rmm_ptz_direction_ctrl(3|4)`). It then logs
`got a new motion start pause_motion =%d` and sends **`0xe6`**, not `0x7c`. Without tracking it calls
`modet_process`/`modet_isBiggerMove` and sends `0x7c` plus `0x6003`.

**Correction to the earlier report:** the bytes `01 00 00 00 02 00 00 00 07 40 07 40 18 00 …` are
`rmm_ptz_direction_ctrl_stop` (PTZ stop), not a motion start. Parsing `0x4007` as motion start would
fire on every PTZ stop, including manual moves from HA. The correct mqttv4 fix is to treat `0x00e6`
(`01 00 00 00 02 00 00 00 e6 00 e6 00`) as a motion start. To confirm, rerun the sniffer and look
for `e6 00 e6 00` during a tracking start.

## Ways to modify rmm

1. **Binary patch** (fixed-width ARM, file offset = vaddr − 0x8000). Run the patched copy from SD
   and keep the stock `/home/app/rmm` untouched. Candidate patches, all untested:

   | Goal | vaddr | file off | stock bytes (LE) | patch |
   |---|---|---|---|---|
   | skip mic noise preprocessing, keep AAC | `0x36e64` | `0x2ee64` | `d6 88 04 eb` | `00 00 a0 e1` (nop) |
   | skip AAC encode, i.e. no audio frames | `0x36e84` | `0x2ee84` | `f6 dc 00 eb` | `00 00 a0 e1` |
   | do not start the audio thread at all | `0x2c218` | `0x24218` | `f6 f4 ff eb` | `00 00 a0 e3` (`mov r0,#0`) |

   Risks: `mp4record` and two-way talk may expect audio frames, and the AENC reader thread
   (`0x35674`) would block. Test each patch alone, using the same `/proc` method.
2. **`LD_PRELOAD` shim** (the same mechanism yi-hack already uses for `dispatch`): it can only hook
   PLT imports (`pthread_create`, `mq_send`, `ioctl`, `open`), not internal calls. Examples: drop the
   audio thread by matching `start_routine == 0x36cf8`, or mirror `0xe6` as `0x7c` in `mq_send` so
   the stock mqttv4 works unchanged.
3. **Replacement app** (an OpenIPC-style streamer on the MPP SDK). The SDK is not available as
   shared libraries here (it is static inside `rmm`), so this needs the Hi3518EV200 SDK and a sensor
   driver port. It is out of reach for this project's scope.

## Open questions

- Which share of thread 1522 is speex versus AAC (needs per-function profiling or patch A alone).
- Whether `mp4record` tolerates missing audio (patches B and C).
- What `cfg` offsets `0x82c`, `0x578`, `0x590` and `0x8c0` mean (shared config struct written by `dispatch`).
- Pseudocode for `0x39d00` and `0x36cf8` once Ghidra is available.
