# 0005. On-device sampling as the acceptance gate for performance changes

**Status:** accepted

## Context
Load average on this single-core camera is noisy (single samples 5.7–10.5 with motion), and earlier assumptions about where CPU goes were wrong until per-thread sampling showed it. The success metric includes CPU, latency and boot-time targets.

## Decision
Every change that claims a performance or reliability effect is measured with a repeatable on-device method, compared against a recorded baseline taken on the same settings:
- **CPU and RAM:** per-process and per-thread CPU from `/proc` stat deltas, plus MemFree and load, over a fixed window with no stream client.
- **Events:** lost starts counted by an IPC sniffer against MQTT `motion_start` messages, and motion-to-broker latency from their timestamps with the camera's NTP offset to the broker host recorded (< 100 ms). Long runs log to the SD card with a size cap, and CPU windows run without the sniffer.
- **Stills:** snapshot latency from timed CGI requests.
- **Boot:** from the reboot command's timestamp on the measuring host to the broker's connect log line, both on NTP-synced hosts.

## Consequences
- Claims rest on numbers with a method attached, comparable across changes.
- Each measurement costs a quiet window; boot timing needs a reboot, which needs the owner's OK. Changes are tested one at a time.
- Any measurement or change that alters camera runtime state (config, tracking, PTZ, reboot) runs only with the owner's explicit OK, through a `--yes` flag or prompt.
- The sampler itself must stay cheap (one persistent session, no tool spawning in the loop).
