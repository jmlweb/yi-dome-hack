# 0007. Rebuild the open-source components with an ARMv5 cross toolchain

**Status:** accepted

## Context
Two targets need new code, not byte patches:
- the still-image target (< 2 s, now 4–13 s), because `mqttv4` runs the snapshot synchronously in its IPC thread, and the grabber is slow on this load
- removing the RTSP password from argv (ADR-0006)

`mqttv4`, `rRTSPServer` and the snapshot tools are open source in yi-hack-v5. The vendor toolchain (`arm-hisiv300-linux`, uClibc 0.9.33) is not publicly available.

## Decision
The open yi-hack components are rebuilt from source with an ARMv5 cross toolchain run in a container: the vendor toolchain if one is obtained, otherwise a statically linked ARMv5 build that does not depend on the camera's C library. Closed vendor binaries stay under ADR-0002.

## Consequences
- New logic becomes possible: snapshot off the IPC thread, credential files, fewer IPC queues.
- A static build costs flash and RAM per binary; each rebuilt binary must pass the ADR-0005 gate against the binary it replaces.
- Once `mqttv4` is rebuilt, the ADR-0003 mapping moves into its source and the byte patch is retired.
