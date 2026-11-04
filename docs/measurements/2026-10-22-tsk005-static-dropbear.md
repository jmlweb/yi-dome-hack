# 2026-10-22 — TSK-005: static ARMv5 dropbear runs on the camera

**Result:** a static `dropbearmulti` built in a container ran on the camera from the SD card. It served SSH on port 2222 next to the stock sshd, accepted a password login, and used less RAM than stock. ADR-0007's fallback path (a static ARMv5 build, no vendor toolchain) works.

## Build

| item | value |
|---|---|
| toolchain | Bootlin `armv5-eabi--musl--stable-2026.08-1` (gcc 15.3.0, binutils 2.45.1, musl 1.2.6, kernel headers 5.10), sha256 `a7db571e…dcf1a` |
| base image | `debian:bookworm-slim@sha256:7ff6ba31…3f8`, run as `linux/amd64` (Rosetta under OrbStack on the arm64 Mac) |
| source | `dropbear-2026.94.tar.bz2`, sha256 `e098034a…ae81` (pinned in `build/components/dropbear.sh`) |
| flags | `-Os -march=armv5te -mtune=arm926ej-s -marm -mfloat-abi=soft`, `--enable-static --disable-zlib`, no utmp/wtmp/lastlog |
| programs | `dropbear dbclient dropbearkey scp`, `MULTI=1` |
| output | `build/out/dropbearmulti`, 477 268 bytes, stripped, statically linked ELF32 ARM EABI5 |
| sha256 | `e06d9ce3dbc2c6cbc19f199906179483e0e80f07bd66f7e793ab521262248c74` (two consecutive builds gave the same hash) |

Command: `build/build.sh dropbear`.

**ISA check.** `readelf -A` reports `Tag_CPU_arch: v5TEJ`, matching the camera's `CPU architecture: 5TEJ`. It also reports `Tag_THUMB_ISA_use: Thumb-2`, but that attribute is merged from object metadata and only says what is permitted. The binding check is the mapping symbols before strip: 1273 `$a` (ARM) and 0 `$t` (Thumb). Whether the static libc members still carry their mapping symbols at link time was not checked, and neither was the input object that sets the `Thumb-2` attribute. The binary did run key generation, kex, ciphers and login on the ARM926 without SIGILL. TSK-010 checks the `libc.a`/`libgcc.a` members before the binary takes port 22. The build fails when `$t` is non-zero or `$a` is zero.

**Kernel.** The camera kernel is 3.4.35, and the toolchain headers are 5.10. musl 1.2 falls back on `ENOSYS` for time64 syscalls, and dropbear's `dbrandom.c` falls back to `/dev/urandom` when `getrandom()` (kernel 3.17+) returns `ENOSYS`. Nothing failed at run time.

## On-camera test

Setup: `/proc/cpuinfo` shows `ARM926EJ-S rev 5 (v5l)` with features `swp half fastmult edsp java`, and no `thumb`. The task note said `thumb`; that was wrong. The stock libc is uClibc 0.9.33.2, and the static binary does not use it.

Steps (camera state changed with the owner's OK):
1. Copied the binary to the new path `/tmp/sd/yi-hack-v5/test/dropbearmulti` over the stock SSH session (`cat >` on stdin). `cam-deploy-file.sh` was not used: it backs up and replaces an existing file, and this path replaced nothing. md5 matched the build (`ff922438…5043`; the camera has no `sha256sum`).
2. `dropbearmulti dropbearkey -t ed25519 -f /tmp/test_key` (tmpfs, throwaway).
3. `dropbearmulti dropbear -p 2222 -r /tmp/test_key -P /tmp/db2222.pid`, backgrounded.
4. From the Mac: `ssh -p 2222` with the askpass helper and a scratch `UserKnownHostsFile`. **Password login worked.**
5. Killed the daemon. The pid file went with it, and `/tmp/test_key` was truncated to 0 bytes (a local hook blocks `rm`, and busybox has no `unlink`; tmpfs clears it at reboot). The binary stays on the SD card for TSK-010.

Negotiated from OpenSSH 10.3p1:

| sshd | kex | host key | cipher |
|---|---|---|---|
| stock v2018.76 (port 22) | ecdh-sha2-nistp256 | (existing) | aes128-ctr + hmac-sha2-256 |
| static v2026.94 (port 2222) | ecdh-sha2-nistp256 | ssh-ed25519 | chacha20-poly1305 |

## RAM (`VmRSS` from `/proc/<pid>/status`, single reading each)

| process | stock v2018.76 (dynamic, uClibc) | static v2026.94 (musl) |
|---|---|---|
| listener | 236 kB | 196 kB |
| one interactive session child | 524 kB | 388 kB |

`MemFree` was 904 kB before the daemon started, 888 kB after, and 1140 kB during the session (normal churn, not a trend). No process was OOM-killed.

These numbers are not a like-for-like RAM cost. Stock `VmRSS` counts the uClibc pages it shares with every other process, while the static binary's pages belong to dropbear alone, so ADR-0007's "a static build costs RAM per binary" is neither confirmed nor refuted here. They are single readings, not a cam-measure window. TSK-010 compares Pss (`/proc/<pid>/smaps`) before the swap.

## Not covered

- `scp` and `dbclient` from the multi-binary were built but not exercised. TSK-010 tests `scp`.
- The existing host key (`/tmp/sd/yi-hack-v5/etc/dropbear/…`) was not loaded. TSK-010 checks that it loads before any swap.
