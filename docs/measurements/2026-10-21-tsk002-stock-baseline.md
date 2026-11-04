# 2026-10-21 — TSK-002 stock baseline (yi-hack-v5 0.4.1, stock binaries)

This is the stock baseline that later changes are compared against (ADR-0005). An earlier run taken with the patched mqttv4 is kept separate in `2026-10-21-tsk002-baseline-patched-mqttv4.md`.

## Summary

| mode | result | target |
|---|---|---|
| cpu, 3 × 300 s | all processes 61.8 %, rmm 54.0 %, load1 6.21, MemFree min 644 kB | baseline |
| events, 53.3 min judged | 3 of 4 starts lost, all `0xe6`-only; 4 of 4 stops published; latency start 0.11 s, stop median 0.07 s | 0 lost |
| snapshot, 20 requests | median 1.60 s, max 2.75 s | pass (median < 2 s, max < 4 s) |
| boot | first MQTT connect +42.6 s, mqttv4 connected +52.7 s | fail (< 30 s) |
| NTP offset, camera to broker | ≤ 28 ms during the events run | < 100 ms |

## Settings

- **Binaries:** all stock 0.4.1. The TSK-001 mqttv4 was reverted at 06:45:17Z, using `cam-deploy-file.sh` with the pre-patch copy from `/tmp/sd/yi-dome-hack-backup/20261021T002715Z`. The live sha256 is `15f95d70…37b28dbd`, which matches the record's `input_sha256`. The patched copy is backed up in `/tmp/sd/yi-dome-hack-backup/20261021T064517Z`.
- **Boot:** about 07:21:20Z, a power cycle while the owner switched cables. The cpu windows started at 370 s of uptime.
- `camera.conf`: `SENSITIVITY=medium`, `MOTION_DETECTION=yes`, `MOTION_TRACKING=yes`.
- `system.conf`: `RTSP=yes`, `RTSP_STREAM=low`, `RTSP_AUDIO=no`, `SPEAKER_AUDIO=yes`, `SNAPSHOT=yes`, `SNAPSHOT_LOW=yes`, `SNAPSHOT_VIDEO=no`, `MQTT=yes`, `DISABLE_CLOUD=yes`, `REC_WITHOUT_CLOUD=yes`, `SWAP_FILE=yes`, `NTPD=yes` (`pool.ntp.org`), `HTTPD=yes`, `SSHD=yes`, `ONVIF=no`, `TIME_OSD=no`.
- **RTSP clients:** 0 established at every window edge. HA's `camera.camera_dome` stayed enabled, but no Dome view was open.
- No sniffer (`ipc_read`) ran during the cpu windows.

## Method

The method is the same as in `2026-10-21-tsk002-baseline-patched-mqttv4.md`.

- **cpu:** one persistent SSH session ran busybox `sh`, using only builtins on the camera side. The 60 s pacing ran on the Mac.
  - `/proc/*/stat` and `/proc/<rmm>/task/*/stat` were dumped at the start and end of each window.
  - `MemFree` and `loadavg` were sampled every 60 s, 6 samples per window.
  - CPU % = (utime+stime delta) / (window × 100) × 100, with HZ = 100.
  - Windows ran back to back, 07:27:28Z to 07:42:29Z. The raw data is in `2026-10-21-tsk002-stock-cpu-raw.txt`.
- **snapshot:** 20 × `GET /cgi-bin/snapshot.sh?res=low` from the Mac over the LAN, 30 s apart, from 07:42:29Z to 07:51:59Z. The timing is curl's `time_total`. The credential was passed on stdin (`-K -`).

## CPU

| window | length s | RTSP est. start/end | all processes % | rmm % | load1 mean | MemFree kB min/mean |
|---|---|---|---|---|---|---|
| 1 | 299.1 | 0/0 | 61.7 | 53.8 | 6.32 (n=6) | 644/719 |
| 2 | 299.3 | 0/0 | 62.0 | 54.2 | 5.96 (n=6) | 656/723 |
| 3 | 299.2 | 0/0 | 61.6 | 53.9 | 6.35 (n=6) | 672/750 |

- **Load1 mean, all samples: 6.21 (n=18).** rmm mean: 54.0 %. All processes: 61.8 %.
- Load stays near 6 with the CPU about 38 % idle, so most of the load comes from tasks waiting, not running. This was not broken down further.

### Per process (≥ 0.1 % in any window)

| process | w1 | w2 | w3 | mean |
|---|---|---|---|---|
| rmm | 53.8 | 54.2 | 53.9 | 54.0 |
| mmcqd/1 | 2.0 | 1.9 | 2.1 | 2.0 |
| mp4record | 1.7 | 1.7 | 1.7 | 1.7 |
| rRTSPServer | 1.3 | 1.4 | 1.3 | 1.3 |
| h264grabber | 1.1 | 1.1 | 1.0 | 1.1 |
| dispatch | 0.6 | 0.5 | 0.5 | 0.5 |
| usb-thread | 0.2 | 0.2 | 0.2 | 0.2 |
| wd_rtsp.sh | 0.2 | 0.2 | 0.2 | 0.2 |
| kswapd0 | 0.2 | 0.2 | 0.2 | 0.2 |
| sh (the sampler) | 0.1 | 0.1 | 0.1 | 0.1 |
| wpa_supplicant | 0.1 | 0.1 | 0.1 | 0.1 |
| ksoftirqd/0 | 0.1 | 0.1 | 0.1 | 0.1 |
| cloud | 0.1 | 0.1 | 0.1 | 0.1 |

The patched-mqttv4 run had about 76 HA RTSP clients connected. Against that run, rRTSPServer drops from 6.6 % to 1.3 % and usb-thread from 2.1 % to 0.2 %; the likely cause is that the stream goes out over Wi-Fi. rmm stays at about 52–54 % either way.

### rmm threads

The thread ids are this boot's (main tid 1509). Map them to roles with `docs/research/rmm.md` before comparing across boots.

| tid | comm | w1 | w2 | w3 | mean |
|---|---|---|---|---|---|
| 1524 | rmm | 30.9 | 30.9 | 30.9 | 30.9 |
| 1526 | rmm | 10.7 | 11.6 | 11.7 | 11.3 |
| 1518 | rmm | 6.5 | 6.0 | 5.8 | 6.1 |
| 1516 | hi_Adec0_Send | 1.3 | 1.4 | 1.3 | 1.3 |
| 1522 | rmm | 1.3 | 1.3 | 1.2 | 1.3 |
| 1523 | rmm | 1.0 | 1.0 | 1.0 | 1.0 |
| 1517 | hi_Adec0_Dec | 0.8 | 0.9 | 0.8 | 0.8 |
| 1520 | rmm | 0.6 | 0.6 | 0.6 | 0.6 |
| 1525 | rmm | 0.4 | 0.4 | 0.4 | 0.4 |
| 1509 | rmm (main) | 0.1 | 0.1 | 0.1 | 0.1 |
| 1519, 1521 | rmm | 0.0 | 0.0 | 0.0 | 0.0 |
| 1515 | hi_Aenc0_Get | 0.0 | 0.0 | 0.0 | 0.0 |

## Snapshot

All 20 requests returned 200 with a valid 320×192 JPEG of 14.2 to 22.8 kB.

| stat | value |
|---|---|
| median | 1.60 s |
| min | 1.37 s |
| max | 2.75 s |
| pass (median < 2 s, max < 4 s) | yes |

Per request (s): 1.46, 1.48, 1.41, 1.58, 1.37, 1.50, 1.68, 1.60, 1.94, 1.41, 2.75, 1.58, 1.78, 1.60, 1.99, 1.62, 1.91, 1.50, 1.78, 1.66.

## NTP offset (camera to broker host)

The broker host (the broker host) does not serve NTP, so both hosts were measured against the same upstream, `185.125.190.58` (ntp.ubuntu.com).

- **Camera:** busybox `ntpd -w -d -p 185.125.190.58`. `-w` only queries and does not set the clock. Offset = server − local, 4 replies per reading.
- **Broker host:** `timedatectl timesync-status` (systemd-timesyncd).

| time (Z) | camera | broker host | camera − broker |
|---|---|---|---|
| 11:03:28 (events start) | −18 ms | −0.3 ms (11:10:36) | about 18 ms |
| 11:13–12:07, every 9 min | −6 to −28 ms | +0.4 ms (12:05) | ≤ 28 ms |
| 12:11:11 (events end) | −20 ms | +0.1 ms (12:10) | about 20 ms |

**The offset stayed under the 100 ms abort line for the whole run.**

Right after a reboot, the camera read +332 ms (09:25Z, 3 min of uptime). It fell under 100 ms within about 6 min. Anchor an events run only after ntpd reads under 100 ms.

## Events (1 h IPC run; 53 min judged)

**Window**
- IPC sniffer: 11:03:55Z to 12:03:56Z, 3601 s.
- MQTT capture: 11:10:36Z to 12:10Z.
- **Judged overlap: 11:10:36Z to 12:03:56Z, 53.3 min.** A planned 6 min IPC extension to 12:10Z did not run. The IPC lines before 11:10:36Z are listed but not judged.

**Settings:** as above (stock mqttv4, tracking on), with no RTSP client. People walked past several times.

**Method**
- **IPC:** `ipc_read -n 3 -d` on the copy queue `/ipc_dispatch_3`, which no other process reads. It ran under `nohup` with `env.sh` sourced.
  - With `-d`, the hex dump goes to **stderr**, so it is piped `2>&1`.
  - A shell-builtin loop kept only `0x7c`, `0xe6` and `0x7d` and stamped each line with `/proc/uptime`. No tool spawns inside the loop. A one-shot `sleep` timer ends the run.
  - Log: `2026-10-21-tsk002-stock-events-ipc.log`.
- **Uptime to UTC:** two anchors, at the start (11:03:28Z) and the end (12:11:11Z), each taken at a `date +%s` second edge and corrected by the camera's NTP offset at that moment, then interpolated linearly. The two anchors disagree by 52 ms over the window. Expect about ±50 ms on each IPC time.
- **MQTT:** an agent on the broker host ran `mosquitto_sub` inside `the mosquitto container` on `<prefix>/#` with `-F '%U %t %l %p'`, which gives broker-host receive time to the ns. The 11 retained messages at the start were dropped. Lines: `2026-10-21-tsk002-stock-events-mqtt.txt`, without the `motion_files` JSON.
- **Rules (cam-measure):**
  - A start is lost when no MQTT `motion_start` arrives within 5 s.
  - A start within 60 s of an earlier start, with no `0x7d` between them, is inside an open event and not counted.
  - Latency = MQTT receive time − IPC time.

| IPC (camera, NTP-corrected) | id | MQTT (broker) | latency |
|---|---|---|---|
| 11:05:00.631 | `0x7d` | before capture | not judged |
| 11:09:41.917 | `0xe6` | before capture | not judged |
| 11:15:05.783 | `0x7d` | 11:15:05.820 motion_stop | +0.037 s |
| 11:18:25.261 | `0xe6` | none | **lost** |
| 11:19:31.580 | `0x7d` | 11:19:31.630 motion_stop | +0.050 s |
| 11:53:26.344 | `0xe6` | none | **lost** |
| 11:54:31.963 | `0x7d` | 11:54:32.045 motion_stop | +0.083 s |
| 11:58:50.580 | `0xe6` | none | **lost** |
| 11:59:56.259 | `0x7d` | 11:59:56.339 motion_stop | +0.080 s |
| 12:03:47.066 | `0x7c` | 12:03:47.179 motion_start | +0.114 s |
| 12:03:48.086 | `0xe6` | none | inside open event, not counted |

**Results**
- **Lost starts: 3 of 4 counted.** All 3 were `0xe6`-only tracking-cycle starts; stock mqttv4 ignores that id. The single `0x7c` start was published.
- **By id:** `0xe6`-only starts 3 of 3 lost; `0x7c` 0 of 1 lost.
- **Stops:** 4 of 4 published. In HA, 3 of the 4 events showed only a `motion_stop`.
- **Latency:** start +0.114 s (n=1); stop median +0.065 s (n=4, range 0.037–0.083 s). With the anchors' ±50 ms, the motion-to-broker path is well under 0.2 s.
- MQTT `motion_start`/`motion_stop` messages with no IPC event behind them: 0.

**Side notes**
- `yi-cam_c` (keepalive 15 s) hit a broker keepalive timeout at 11:13:48Z and reconnected at 11:13:49Z. `yi-cam` (keepalive 120 s) did not drop. No motion event fell near it.
- Earlier attempts are void and excluded:
  - 09:15Z: aborted by a reboot.
  - 09:25–10:25Z: the sniffer discarded stderr and saw nothing.
  - In those attempts' MQTT captures, 3 `motion_stop` with 0 `motion_start` show the same stock loss, but no IPC log exists to back that up.
- 09:46–10:08Z: the camera was off the LAN during a Wi-Fi extender outage. The broker logged `status offline`, but the camera did not reboot.

## Boot

**Settings:** as above (stock binaries). The camera was up 3 h before the reboot; no RTSP client was connected.

**Method**
- The Mac opened SSH and ran `echo go; busybox reboot`. The reboot time is the Mac's receive time for `go`, which is at most a few ms after the command.
  - Mac clock offset against `185.125.190.58`: +81 ms ±39 ms (`sntp`), applied.
- Broker connect times come from `journalctl -u the mosquitto container -o short-precise` on the broker host, which was at +0.1 ms against the same server. The broker host agent read them.
- Process start times on the camera come from `/proc/<pid>/stat` field 22, at HZ = 100.
  - Kernel start = Mac time at the uptime read, minus uptime. That puts ±1 s on the "kernel" and "process" rows.

| moment | UTC | since reboot command |
|---|---|---|
| `busybox reboot` sent | 12:13:05.821 | 0 |
| `yi-cam` and `yi-cam_c` close their connections cleanly | 12:13:06.371 / .468 | +0.6 s |
| kernel start (uptime 0) | ≈ 12:13:10.6 | ≈ +4.8 s |
| `mqtt-config` process starts (uptime 30.3 s) | ≈ 12:13:40.9 | ≈ +35 s |
| SSH answers again | 12:13:48.754 | +42.9 s |
| first camera MQTT connect: `yi-cam` (k120), closed after 0.5 s | 12:13:48.389 | **+42.6 s** |
| `yi-cam_c` (k15) connects and stays | 12:13:48.446 | +42.6 s |
| second short `yi-cam` connect (0.5 s) | 12:13:52.933 | +47.1 s |
| `mqttv4` process starts (uptime 46.2 s) | ≈ 12:13:56.7 | ≈ +50.9 s |
| `yi-cam` connects and stays (mqttv4) | 12:13:58.565 | **+52.7 s** |
| HA `binary_sensor.camera_dome_status` on | 12:13:59.074 | +53.3 s |

**Boot to MQTT: 42.6 s to the first camera connect. The motion publisher, mqttv4, is connected at 52.7 s. Fail against the < 30 s target.**

- mqttv4 starts only about 46 s into uptime.
- The two short `yi-cam` connects before it are most likely the startup scripts' one-shot `mosquitto_pub` calls. Not confirmed, because the broker does not log publishes.
- Which client ID publishes `motion_detection` is not confirmed from the broker side. Going by timing, it is the persistent `yi-cam` session (mqttv4).

## After the baseline

- 12:17:37Z: TSK-001 patched mqttv4 rebuilt with `patch-apply.py` from the stock copy and redeployed (sha256 `80e5d1d7…1ce972`), on the owner's call. The stock copy is backed up in `/tmp/sd/yi-dome-hack-backup/20261021T121737Z`. the owner accepted the 53.3 min judged events window as the 1 h events run.
