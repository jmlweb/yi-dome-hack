# mp4record — why SD recording stops without the rmm audio thread

Target: `/home/app/mp4record` on the Yi Dome 720p (base firmware 1.9.1.0J_201809191135).
Identity: 49 160 bytes, sha256 `9efce368127725a4d661ebb01f9bfd29eafff95e4ae5b207a251225731947f82`
(read-only `cat` from the camera, 2026-10-21). Producer side: `/home/app/rmm`, sha256 `ce4e24aa…e50050`
(matches `docs/research/rmm.md`).
Method: static only. REA opened both targets, but no deep provider (Ghidra/Hopper/IDA) is configured,
so this uses Apple `objdump` (`--triple=armv7a`, a superset that decodes the ARMv5TE code) and a
script that resolves PC-relative literals to strings. No decompiled pseudocode. Nothing on the camera
was changed. The two endless-wait call sites (`0x92f8`, `0xa514`) and the retry loop (`0x9700`–`0x970c`) were re-checked
independently with `objdump` on 2026-10-21.

Tags: **[C]** confirmed from disassembly at the given address. **[I]** inferred.

## Binary shape

- ELF32 ARM EABI5, stripped, links only `librt`, `libpthread`, `libc` (uClibc). No vendor `.so`, so
  nothing to pull from `/home/app/locallib` or `/home/lib`. **[C]**
- Load `off 0 → vaddr 0x8000`, so **file offset = vaddr − 0x8000** (same as rmm). **[C]**
- `__func__` strings survive: `main`, `record_init`, `record_info_init`, `record_file`,
  `calc_aac_config`, `thread_handyman`, `thread_shortrec(_10s)`, `process_mq_msg`,
  `send_mp4rcd_heartbeat_msg`, and the `MediaData*` names. Function names below come from them.

| vaddr | name (from `__func__` strings / role) |
|---|---|
| `0x9134` | `main` |
| `0x95ec` | `calc_aac_config(adts_hdr, out_asc[2])` |
| `0x96a0` | wait-for-frame dispatcher (no timeout, see below) |
| `0x99c4` | `thread_handyman` (`/ipc_rcd` reader) |
| `0xa284` | `send_mp4rcd_heartbeat_msg` |
| `0xa3bc` | `record_file` (with `record_info_init` inlined) |
| `0xb614` | `MediaDataGetAddr(ch)` |
| `0xb6bc` | `MediaDataCreatShareMem(path, size)` |
| `0xb878` | `MediaDataInit` (`/tmp/view`) |
| `0xbc68` | `_MediaDataGetNewFrame(ch, buf, size, type, …)` |
| `0xbf98` | `MediaDataAudioGetByTs` |
| `0xc340` | `MediaDataVideoGetByTs` |
| `0xc67c` | `MediaDataGetNextFrame` |

## 1. IPC path rmm → mp4record

Three channels:

| object | kind | use | evidence |
|---|---|---|---|
| `/tmp/view` | file, `open(O_RDWR\|O_CREAT)` + `mmap`, size `0x9fc40` | **frame ring, video and audio** | `0xb878`–`0xb888` **[C]** |
| `/tmp/mmap.info` | file + `mmap`, size `0x93c` | shared config struct (`cfg`) | `main` `0x917c`–`0x918c` **[C]** |
| `/ipc_dispatch` | POSIX mq, `O_RDWR\|O_CREAT\|O_NONBLOCK` (`0x842`), maxmsg 4, msgsize 512 | mp4record → dispatch (heartbeat id `0x00e7`) | `0x9158`, `0xdfc4`, `0xa290` **[C]** |
| `/ipc_rcd` | POSIX mq, same flags | dispatch → mp4record commands (short recordings) | `0x916c`, `thread_handyman` `0x9a94` **[C]** |

### `/tmp/view` layout

- 4 channels. Per channel a `0x1910`-byte descriptor block at `base + ch*0x1910`: `u16` at `+0` and
  `+2` (two ring indices, equal means empty, `0xbca0`–`0xbca8`), then 200 entries of 32 bytes from
  `+0x10`. Entry fields used: `+0x0` u8 valid, `+0x4` data offset, `+0x8` size, `+0xc` timestamp,
  `+0x10` u8 frame type. **[C]** (`0xbc90`–`0xbd88`; the exact field names are **[I]**)
- Data area at `base + 0x6440` (`4 × 0x1910`) + per-channel offset (`0xbe60`–`0xbe6c`). **[C]**
- `MediaDataGetAddr` jump table (`0xb624`) → per-channel offset/size **[C]**:

| ch | data offset | size | role |
|---|---|---|---|
| 0 | `0x00000` | `0x64000` (400 KiB) | main H.264 (720p) **[I]** from track setup |
| 1 | `0x64000` | `0x25800` (150 KiB) | sub H.264 (360p) **[I]** |
| **2** | `0x89800` | `0x8000` (32 KiB) | **AAC audio (ADTS)** **[C]**: `record_info_init` reads ch 2 into `calc_aac_config` |
| 3 | `0x91800` | `0x8000` | unknown, not read by mp4record in the paths checked |

- Writer: rmm exports the same module (`MediaDataPut` at rmm `0x147884`). The **only audio writer** is
  rmm's AENC reader thread `ai_get_aacstream` (`0x35674`): `select` on `HI_MPI_AENC_GetFd`, then
  `HI_MPI_AENC_GetStream` (`0x357a0`), then, if `cfg[0x598] == 0`, `MediaDataPut(ch=2, …)` at
  `0x35838`. **[C]**
- `MediaDataCreatShareMem` clears the file only when its size differs (`0xb7a4`–`0xb7bc`). The ring
  contents therefore survive a process restart. **[C]**

## 2. Where mp4record blocks without audio

**The blocking point is a startup wait for one AAC frame. It has no timeout. It runs twice, and both
times before the recorder loop starts.**

### Wait dispatcher `0x96a0`

```
loop:  switch (type - 5)              ; jump table 0x96cc, 5..9
         7 -> 0xc2e0 -> _MediaDataGetNewFrame(ch, …, type 7)   ; SPS
         8 -> 0xbc28 -> 0xb8d0(…, 8)                           ; PPS
         9 -> 0xc320 -> _MediaDataGetNewFrame(ch, …, type 0)   ; any frame (audio)
         default -> 0xc67c MediaDataGetNextFrame
       if r == 0: return 0
       sleep_ms(300)                  ; 0xe18c, select()-based
       goto loop                      ; 0x970c: b 0x96c0, no counter, no timeout
```
**[C]** `0x96a0`–`0x97a0`.

`_MediaDataGetNewFrame` returns −1 at `0xbf48` ("media data empty") when ch 2's two indices are equal.
**[C]** With no producer, ch 2 never gets an entry. `0x96a0(9, 2, …)` then spins at 300 ms forever,
which matches mp4record's < 0.1 % CPU.

### Call sites

1. `main` → inlined `record_init`:
   - `0x91a0`–`0x91b8`: wait until `cfg[0x570] == 1 && cfg[0x564] == 0` (100 ms poll) **[C]**
   - `0x91c4`–`0x91d8`: wait until `time() > 0x569ddaa0` (clock set) **[C]**
   - `0x9220`/`0x9240`: main SPS/PPS; `0x9288`/`0x92ac`: sub SPS/PPS **[C]**
   - **`0x92f8`: `0x96a0(9, ch=2, buf, 4096, …)`, the audio wait** **[C]**
   - `0x9304`: `calc_aac_config(buf, 0x1bd48)`, then "got audio aac config, ts=%u" **[C]**
   - only after that: `0x9344` `pthread_create(thread_handyman 0x99c4)`, then wait for SD
     (`cfg[0x554] > 0`), `recordevent_init`, then `record_file` (`0x9410`) **[C]**
2. `record_file` → inlined `record_info_init`: the same sequence again; **audio wait at `0xa514`**,
   `calc_aac_config(buf, r5+500 = 0x1bd48)` at `0xa520`. **[C]**

Neither is re-entered. No branch inside `record_file` (`0xa3bc`–`0xac84`) targets `≤ 0xa560`, and the
recorder loop heads are `0xa564`/`0xa588`. **[C]**

### What the audio frame is used for

Only for the MP4 `esds`. `calc_aac_config` (`0x95ec`) builds the 2-byte AudioSpecificConfig from the
ADTS header (profile, sampling index, channel config) into `0x1bd48`. Bad values are only logged
(`0x9628`, `0x966c`), never rejected. **[C]** Each new file then gets an audio track unconditionally
(no branch in `0xa72c`–`0xa85c`) **[C]**:

```
0xa7c0  0xf308(file, 1, 16000, 1024, 16, 64)   ; add AAC track, 16 kHz, 1024 samples/frame
0xa7d4  0xf444(file, 1, 0x1bd48, 2)             ; set 2-byte ASC (esds)
```
The meaning of the `0xf308`/`0xf444` arguments is **[I]** from the values; that `0xf444` gets `0x1bd48`
with length 2 is **[C]**. `[r5+0x44]` (the audio ts filled by the wait) is read only by the two log
calls (`0x9308`, `0xa524`). **[C]**

### Rejected candidates

- **Steady-state loop does not need audio.** At `0xa89c` it calls `MediaDataGetNextFrame(ch=2)`. A
  miss sets `r6 = 0` and falls through to the sub (`0xa918`, ch 1) and main (`0xa95c`, ch 0) video
  reads. **[C]**
- **Sync helper `0x8fcc`** (main/sub timestamp alignment, "got differ") calls
  `MediaDataAudioGetByTs(2, …)` at `0x9104` and ignores the result (`0x9108` `mov r0,#1`). It has no
  sleep loop of its own. **[C]**
- **Reads do not consume frames.** `_MediaDataGetNewFrame` never stores to the entry's valid byte; it
  only checks it at `0xbea0`. **[C]** One frame left in ch 2 therefore satisfies both waits.

**Measured vs static:** the code path to the wait is **[C]**. That the patch C run actually stalled at
`0x92f8` is **[I]**. The cfg gate at `0x91a0` would show the same symptom, but rmm has no
immediate-offset store to `cfg[0x570]`/`0x564`/`0x574`/`0x554` (bounded search), so that gate does not
depend on rmm's audio thread.

## 3. Is there a video-only mode?

**No, within the searched code.** **[C]** (bounded)

- mp4record reads these `cfg` offsets: `0x4a0`, `0x550`, `0x554`, `0x564`, `0x570`, `0x574`, `0x578`,
  `0x5a4`. None of them guards the audio wait or the audio track. The waits at `0x92f8`/`0xa514` and
  the track setup at `0xa7c0`/`0xa7d4` are unconditional.
- mp4record does not read `cfg[0x82c]`, `cfg[0x8c0]` (mic mute, 101) or `cfg[0x598]`. A `0x82c` load
  at `0xd9xx` is in the log-socket code on another struct, not `cfg`. **[C]**
- The mic setting does not help either: with `cfg[0x8c0] == 101`, rmm still encodes and puts zeroed
  frames (rmm.md, and `0x36e6c`–`0x36e74` → AENC path). **[C]**
- rmm `cfg[0x598]` **does** gate the audio `MediaDataPut` (`0x357b0`). It is also read next to the
  video put sites (`0x388d4`, `0x38c4c`). Setting it would starve ch 2 the same way patch C does. Its
  meaning ("pause media put"?) is **[I]**.

## 4. Missing producer, or a missing flag?

**The missing producer.** **[C]** The chain is:

`AI thread 0x36cf8: HI_MPI_AI_GetFrame (0x36e28) → [speex 0x36e64] → HI_MPI_AENC_SendFrame (0x36e84)`
→ `ai_get_aacstream 0x35674: HI_MPI_AENC_GetStream (0x357a0) → MediaDataPut(ch 2) (0x35838)`
→ `/tmp/view` ch 2 → mp4record `0x96a0(9, 2, …)`.

Under patch C, AENC gets no input, so `ai_get_aacstream` only hits its `select` timeout (`0x357cc`) and
never puts. mp4record waits on ch 2 data itself, not on a header or flag that the audio thread writes.
No rmm store to the cfg words that mp4record polls was found (immediate offsets only; bounded).

## Side finding: mqttv4 not starting with patch C

- With the audio wait stuck in `main` (`0x92f8`), `thread_handyman` (created at `0x9344`) never runs,
  so **nothing drains `/ipc_rcd`**. The `/ipc_dispatch` heartbeat `0x00e7` (`0xa284`, sent only from
  the `record_file` loop at `0xa598`) **is never sent**. **[C]** for the code order, **[I]** for the
  runtime state.
- No confirmed link to mqttv4. Possible effects: a sender blocking on a full 4-message `/ipc_rcd`, or a
  dispatch watchdog reacting to the missing heartbeat. Both are **[I]**. mp4record's own sends are
  `O_NONBLOCK`.

## Fix options, ranked

CPU figures: patch C removes 30.4 points of rmm (measured). Patch A (speex skipped) removes 7.3
(measured). The audio thread is 31.2 % stock.

| # | option | CPU saved | risk | rules |
|---|---|---|---|---|
| 1 | **rmm: throttle the audio loop.** Replace `0x36e5c` `mov r0,r8` with `mov r0,#N` and `0x36e64` `bl speex_preprocess_run` with `bl sleep@plt` (`0x29700`). One AI frame per N s is captured, sent to AENC and put into ch 2. | most of 30 points **[I]** (speex gone; AAC and capture cut by ~16·N×) | medium: AI frame held N s before release; AENC needs ~1.6 AI frames (640 samples) per 1024-sample AAC frame, so the first ch 2 frame takes ~2N s; clips get a sparse audio track (possible A/V offset or odd duration). Pairing path (`r6 == 1`, `0x36f90`) unchanged | in scope: rmm record under ADR-0002, one change |
| 2 | **mp4record: drop the audio wait and use a fixed ASC.** At both sites, replace the 4-instruction run wait + `calc_aac_config` with `mov r0,#0x14; strb r0,[r5,#off]; mov r0,#0x08; strb r0,[r5,#off+1]`: site 1 `0x92f8`–`0x9304`, off 412 (`r5 = 0x1bbac`); site 2 `0xa514`–`0xa520`, off 500 (`r5 = 0x1bb54`). Both target `0x1bd48`. Combine with patch C. | 30.4 (measured for patch C) | medium: audio track has 0 samples. How the finaliser (`0xf7a0`) and players handle an empty AAC track is unknown. `14 08` = AAC-LC, 16 kHz, **mono** (mono **[I]**); check the stock clip's ASC with ffprobe first. The 4 slots per site are `bl 0x96a0; mov r0,…; add r1,r5,#off; bl 0x95ec` (`0x92f8`–`0x9304`, `0xa514`–`0xa520`) **[C]**; the skipped ts field `+0x44` only feeds the log **[C]** | **needs a new ADR first**: `patches/` may target only rmm or the mqttv4 start-id mapping (ADR-0002/ADR-0007) |
| 3 | **Boot helper writes one ADTS frame into `/tmp/view` ch 2** (ring survives restarts, one frame satisfies both waits, reads do not consume) + patch C | 30.4 | high: hand-written ring descriptors; unknown whether rmm resets ch 2 at init or whether ordering versus mp4record start holds | new service under ADR-0004 allow-list; no binary patch |
| 4 | rmm: skip AI capture, feed AENC a silent frame continuously | small: AAC encoding (~23 points) stays | low | ADR-0002 — **not worth it** |
| — | existing video-only mode | — | — | none found (§3) |

Recommendation: test **1** first (stays within the current ADRs, one patch). Use N = 1 so the startup
wait clears quickly. Measure CPU with `cam-measure` and check one clip with ffprobe/ffmpeg. If the
sparse audio track breaks clips, write the ADR for **2**.

Variant of 1, untested: make the thread put one frame and then park. This needs the sleep after
`HI_MPI_AENC_SendFrame` and `ReleaseFrame`, i.e. the back-edge `0x36e9c` `b 0x36e10` must branch to a
park loop. No free slot was identified for that yet.

## Open questions

- Runtime confirmation of the stall: under patch C, `/tmp/log.txt` should show "got video sub sps pps"
  and no "got audio aac config". This depends on the `0xd948` → `/tmp/logsock` output reaching that
  log (**[I]**).
- `/ipc_rcd` depth under patch C: `cat /dev/mqueue/ipc_rcd` (QSIZE), not shell `read`. Then compare
  the mqttv4 start-up in `system.sh` against mp4record's `/ipc_rcd`/heartbeat.
- How `0xf7a0` (file close) and `0xf6dc` (sample write) handle zero or sparse audio samples.
- Meaning of rmm `cfg[0x598]` and of `cfg[0x82c] == 1` (branch at `0x36e4c` to `0x36f70` in the audio
  loop).
- Channel 3 of `/tmp/view` (offset `0x91800`, 32 KiB): who writes it?
- Pseudocode for `0x96a0`, `0xa3bc` and rmm `0x35674` once a Ghidra provider is configured.
