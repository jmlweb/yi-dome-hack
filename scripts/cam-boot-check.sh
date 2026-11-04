#!/bin/bash
# Read-only post-boot check: uptime, rmm binary, and pid/state/ppid of the boot services.
# Reads process names from /proc/<pid>/stat only; cmdlines can carry the RTSP password (ADR-0006).
# A zombie (state Z) still matches the watchdog's `ps | grep`, so it is listed, not hidden.
# Usage: scripts/cam-boot-check.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/scripts/cam-ssh.sh" '
read up idle < /proc/uptime; echo "uptime $up"
r=$(pidof rmm); [ -n "$r" ] && ls -l /proc/$r/exe | sed "s/.*-> /rmm exe /"
for f in /proc/[0-9]*/stat; do
  { read l < $f; } 2>/dev/null || continue
  set -- $l
  case "$2" in
    "(rmm)"|"(dispatch)"|"(mp4record)"|"(mqttv4)"|"(mqtt-config)"|"(h264grabber)"|"(rRTSPServer)"|"(wd_rtsp.sh)"|"(cloud)")
      echo "proc $2 pid=$1 state=$3 ppid=$4" ;;
  esac
done
echo "wd_rtsp.log:"; busybox tail -4 /tmp/sd/wd_rtsp.log
'
