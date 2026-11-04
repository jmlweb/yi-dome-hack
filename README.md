# yi-dome-hack

A personal fork of [alienatedsec/yi-hack-v5](https://github.com/alienatedsec/yi-hack-v5) 0.4.1 for one camera: the Yi Dome 720p (Hi3518EV200, 18 MB Linux RAM, OV9732 sensor, base firmware `1.9.1.0J_201809191135`). Home Assistant consumes it over MQTT and RTSP. The goal is learning: reliable motion events with auto-tracking on, and a lighter camera, by patching vendor binaries and trimming the boot instead of rewriting the video stack.

## Results so far

Measured on the real camera with `scripts/cam-measure-*` (method in `docs/measurements/`). Stock yi-hack-v5 0.4.1 against the current state:

| | Stock | Now |
|---|---|---|
| `rmm` CPU | 52.8 % | ~21 % |
| All processes | 60.4 % | ~25 % |
| Load1 mean | 5.91 | ~4.6 |

The main win is not starting `rmm`'s audio thread (`patches/rmm-1.9.1.0J-no-audio-thread.json`). The price is no SD clips and no two-way talk (ADR-0008).

## Layout

- `docs/adr/`: decisions. `docs/evaluation.md`, `docs/overview.md`: scope and measurement targets. `docs/research/`: reverse-engineering notes. `docs/measurements/`: results.
- `patches/`: binary patch records (file, offset, original bytes, replacement bytes, input and output sha256), applied by `scripts/patch-apply.py`, which aborts on any mismatch.
- `overlay/`: modified yi-hack-v5 boot scripts that go to `/tmp/sd/yi-hack-v5/script/` on the SD card.
- `scripts/`: patch, deploy, SSH and measurement helpers. Camera access uses `.env` (copy `.env.example`); credentials never go on a command line.
- `build/`: ARMv5 static cross-build in a container.

## What is not here

No vendor firmware and no vendor binaries (`rmm`, `mp4record`, stock `mqttv4`). You must extract them from your own camera; the patch records check the expected hashes before writing anything. Everything installs under `/tmp/sd/` only; nothing writes the camera's flash (ADR-0001), and removing the SD card returns it to stock behaviour.

## Warning

This runs on a camera with no recovery path you control. Use it at your own risk, on a camera you own, and read the ADRs first. Task and report IDs (`TSK-`, `RPT-`, `LRN-`) in the docs refer to a private backlog that is not published.

## License

GPL-3.0, see `LICENSE`. The scripts in `overlay/` are modified copies of yi-hack-v5 files, which is GPL-3.0; all credit for the base project goes to its authors.
