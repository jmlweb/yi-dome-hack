# 0003. Map the tracking-cycle motion start in the event bridge, not in the producer

**Status:** accepted

## Context
With auto-tracking on, `rmm` sends motion starts as IPC id `0x00e6` instead of `0x007c` (verified live on 2026-10-21). The MQTT bridge `mqttv4` ignores `0x00e6`, so HA misses starts. The id could be changed in the producer (`rmm`), which every consumer would then see (`mp4record`, `cloud`), or in the consumer (`mqttv4`), which only the MQTT path would see.

## Decision
The IPC-to-MQTT bridge recognises the tracking-cycle start id as a motion start. The producer and the other consumers keep their stock behaviour.

## Consequences
- The smallest blast radius: SD recording and the stock apps see exactly what they saw before.
- The bridge holds the knowledge of vendor message ids; any later source rebuild of the bridge must carry the mapping.
- If another consumer turns out to need the same mapping, a new ADR moves it to the producer.
