# 0001. SD-only overlay install, no further flash writes

**Status:** accepted

## Context
The camera has 16 MB of NOR flash with no recovery path we control. The flash is not stock: yi-hack-v5 0.4.1 installed its boot hook there (`/etc/init.d/S20yi-hack-v5`, `/home/yi-hack-v5`). On boot it runs `/tmp/sd/yi-hack-v5/script/system.sh` if that directory exists, and otherwise starts the stock Yi apps. The payload and the stock `/home/app` binaries are separate. the owner's safety constraint: no flash writes without his explicit OK.

## Decision
Every change ships as files on the removable SD card that overlay or replace the upstream payload there. Patched vendor binaries are copies on the SD card, launched in place of the flash originals. The NOR partitions get no further writes.

## Consequences
- Restoring the SD card's previous files returns the camera to the current, known-good state. Removing the card falls back to the stock Yi apps through the existing boot hook.
- Anything that needs a flash-resident change (bootloader, kernel, rootfs scripts, the boot hook) is out of scope unless a new ADR allows it.
- Boot depends on the SD card being readable; a failed card means stock Yi behaviour, not a brick.
