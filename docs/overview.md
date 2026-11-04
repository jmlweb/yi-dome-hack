# yi-dome-hack

The Yi Dome 720p runs yi-hack-v5 at load 5–10 with about 1 MB of free RAM. Home Assistant loses motion starts whenever the dome's auto-tracking is on. yi-dome-hack is a single-camera fork, installed from the SD card. It patches the closed vendor binaries and trims the boot, so the owner's Home Assistant gets every motion event quickly, with tracking on, from a lighter camera.

## Problem
With auto-tracking on, the stock `rmm` app sends a motion start that happens during a tracking cycle as IPC id `0x00e6`. The MQTT bridge (`mqttv4` 0.4.1) only knows `0x007c`, so HA sees the stops but not the starts. Evidence:
- the IPC sniffer logged `0xe6`-only starts at 00:36:03 and 00:38:42 on 2026-10-21, with no MQTT `motion_start`
- static analysis in `docs/research/rmm.md`

On top of that, stills take 4–13 s and boot to MQTT connect takes 46 s. About 29% of the camera's CPU goes to a microphone pipeline that nothing uses.

Workaround today: tracking off, and a power cycle when MQTT motion stops. This costs the dome's main feature and needs manual intervention. Why now: the 2026-10-20 investigation found the cause and a fix, and upstream has been idle since 2024-04.

## Users
Single owner. One Yi Dome 720p at home, consumed by Home Assistant on a separate host. The `binary_sensor` for motion drives lights automation, and the RTSP low stream feeds the live view.

## Success metric
By 2026-11-30, with auto-tracking on:
- 0 lost motion starts over 7 days
- motion reaches the MQTT broker in under 1 s (camera NTP offset to the broker host recorded and < 100 ms)
- still image (`res=low`): median under 2 s and max under 4 s over 20 requests
- boot to MQTT connect in under 30 s
- 1-min load average at least 20% below stock 0.4.1: mean of 60 s samples over 3 windows of 300 s each, same settings, no stream client, with a matching drop in per-process `rmm` CPU

A **lost start** is an IPC motion start (`0x7c` or `0xe6`) seen by the on-camera sniffer with no MQTT `motion_start` within 5 s, unless another start was seen in the preceding 60 s with no `0x7d` since (then it belongs to the open event). Each target is measured with the ADR-0005 method against a stock baseline recorded before any change.

## Riskiest assumption
With auto-tracking on, `rmm` emits `0x00e6` for tracking-cycle motion starts, and `dispatch` copies it to `mqttv4`'s queue, so a one-value patch makes HA see every start. Result: **held at the IPC level** (`0xe6` was the only start message for 2 observed tracking starts; which copy queue `mqttv4` reads is checked in TSK-001). Live test 2026-10-21 01:41:57–01:46:57: `0xe6` reached both copy queues, and the earlier `0xe6`-only starts prove the loss. TSK-001 tests it end to end: the patched bridge must publish `motion_start` for an `0xe6`-only start and the matching stop.

Second assumption (CPU target): stopping the mic pipeline cuts `rmm` CPU by about 25 points without breaking SD video recording. Result (TSK-003, 2026-10-21): **partly held**. Not starting the audio thread cuts rmm by 30.4 points, but `mp4record` then records nothing; the speex-only cut keeps recording but saves 7.3. the owner dropped SD recording (ADR-0008), so the load target stays.
If the riskiest assumption is refuted: stop per the kill criteria, or pivot by re-running `/flowstate:kickstart` with the new assumption.

## Kill criteria
Stop if by 2026-11-15 the patched camera still loses tracking-cycle motion starts over 48 h with tracking on; then stay on stock yi-hack-v5 0.4.1 with tracking off. If by 2026-11-10 TSK-003 cuts `rmm` CPU by fewer than 10 points, drop the load target and re-scope. Checked first against TSK-001's result: a refuted assumption meets them unless the user pivots.

## Scope
- In: tracking-cycle motion starts delivered to HA (event-bridge mapping)
- In: `rmm` without its audio thread (ADR-0008: no mic, no two-way talk)
- In: single RTSP stream (low by default, high by config, no audio)
- In: MQTT motion start/stop with HA auto-discovery
- In: snapshot endpoint and the httpd CGIs HA calls
- In: PTZ, IR, LED and switch control over MQTT
- In: still image under 2 s and the RTSP password off argv, through cross-built open components (ADR-0007)
- In: SSH and NTP
- Out: cloud, p2p, oss, watch_process, ONVIF/WSDD, FTP (server and upload), telnet, timelapse, proxychains
- Out: SD recording (`mp4record`, `clean_records`) and clip audio (ADR-0008)
- Out: sound and baby-cry detection, AI and face detection, cruise, update checks, web UI pages, other Yi models
- Out: replacing `rmm` or the video stack, and any NOR flash write

## Constraints
- Hardware: Hi3518EV200, ARMv5 at about 300 MHz, 18.6 MB RAM, uClibc 0.9.33; `rmm` is closed source.
- Install from the SD card only, with no further flash writes. The flash holds the yi-hack boot hook, which starts the stock Yi apps when no SD payload is present.
- Build host: Mac (arm64). The hisiv300 cross toolchain is not publicly available; source rebuilds use it if obtained, else a static ARMv5 build (ADR-0007).
- Credentials and network identifiers live only in `.env`; the repo stays private.
- Camera runtime changes need the owner's OK.

## Architecture
- ADR-0001: SD-only overlay install with no further flash writes, so every change is reversible.
- ADR-0002: verified in-place patches of closed binaries, because there is no source or public toolchain for `rmm`.
- ADR-0003: map the tracking-cycle start in the event bridge, the smallest blast radius for the motion fix.
- ADR-0004: allow-list boot for one model, so "disabled" services stop running and the payload shrinks.
- ADR-0005: on-device sampling gate, because load average is noisy and past CPU guesses were wrong.
- ADR-0006: secrets by file or environment and never in the repo, with one temporary argv exception for the stock RTSP server.
- ADR-0007: open yi-hack components rebuilt with an ARMv5 cross toolchain, for logic byte patches can't add (fast stills, credential files).
- ADR-0008: live view only; `rmm` runs without its audio thread and SD recording leaves the scope, for a 30-point CPU cut.
