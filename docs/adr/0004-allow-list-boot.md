# 0004. Allow-list boot for a single camera model

**Status:** accepted

## Context
Upstream yi-hack-v5 supports several camera models and many optional services, gated by `system.conf` flags. Several "off" flags still start processes: `DISABLE_CLOUD=yes` keeps `cloud` uploading, and the watchdog polls `top` every 10 s. The fork targets one camera (Yi Dome 720p, `yi_dome`, base firmware 1.9.1.0J) consumed only by Home Assistant.

## Decision
Startup launches only the services on an explicit allow-list. Files for other camera models and for services outside the scope are removed from the payload, not merely disabled. Health checks read kernel process state instead of spawning tools.

## Consequences
- Fewer processes, smaller payload, and no hidden "disabled but running" services.
- Re-enabling a removed feature means restoring files, not flipping a flag.
- The payload no longer works on other Yi models.
