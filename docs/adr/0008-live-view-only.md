# 0008. Live view only: rmm runs without its audio thread, no SD recording

**Status:** accepted

## Context
`rmm`'s audio capture thread (entry `0x36cf8`: mic capture, speex preprocessing, AAC encoding) uses about 31 % of the camera's CPU, and nothing in the project's scope consumes its output (RTSP runs without audio). TSK-003 measured three ways to cut it, each 3 × 300 s against a stock control of 52.8 % rmm (`docs/measurements/2026-10-21-tsk003-*.md`):
- runtime `ipc_cmd -I OFF`: no effect (the mute only zeroes frames after encoding)
- skipping speex (`patches/rmm-1.9.1.0J-skip-speex-preprocess.json`): −7.3 points, recording intact; under the 10-point kill line
- not starting the thread (`patches/rmm-1.9.1.0J-no-audio-thread.json`): −30.4 points, about +900 kB free RAM, but `mp4record` writes no clips

`mp4record` waits, with no timeout, for one AAC frame in `/tmp/view` channel 2 before it records anything (`docs/research/mp4record.md`: call sites `0x92f8` and `0xa514`). It has no video-only mode. the owner uses only HA live view (RTSP) and MQTT; he does not use SD clips.

## Decision
The camera runs `rmm` with the no-audio-thread patch, started from the SD card by the boot script. SD recording (`mp4record`, `clean_records`), SD clip audio and two-way talk leave the scope. `mp4record` is removed from the boot allow-list (ADR-0004) instead of being left stalled.

## Consequences
- rmm drops from about 53 % to about 22 % CPU, which meets the load target without touching the video path.
- No SD clips. Getting them back means either an rmm patch that keeps a sparse audio stream (`docs/research/mp4record.md`, option 1) or an `mp4record` patch, which would need its own ADR (ADR-0002 limits `patches/` to `rmm` and the `mqttv4` mapping).
- `mp4record` sends a heartbeat to `dispatch` and drains `/ipc_rcd`. With it gone, any effect on `dispatch` or `mqttv4` must be checked; under the patch, `mqttv4` once failed to start at boot.
- The boot script starts the patched `rmm` from `/tmp/sd`; the stock `/home/app/rmm` stays untouched (ADR-0001), so a restored boot script returns the stock behaviour.
- ADR-0003's note that SD recording sees stock behaviour no longer applies; its decision stands.
