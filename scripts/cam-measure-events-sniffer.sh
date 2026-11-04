#!/bin/sh
# cam-measure events mode, camera side. Runs under nohup on the camera.
# Reads one IPC copy queue, keeps only motion start (0x7c), tracking-cycle start (0xe6) and stop (0x7d),
# prefixes each with /proc/uptime read by the shell builtin, so the loop spawns no tools (ADR-0004).
# Usage (on the camera, started by cam-measure-events-start.sh): sh cam-measure-events-sniffer.sh <queue> <seconds> <log>
# ipc_read needs the yi-hack library path; busybox here has no mkfifo, so the reader's PID goes to tmpfs.
. /tmp/sd/yi-hack-v5/script/env.sh
Q="$1"
SECS="$2"
LOG="$3"
PIDFILE=/tmp/tsk002-ipc_read.pid
read up0 x < /proc/uptime
end=${up0%.*}
end=$((end + SECS))
echo "start_uptime $up0" > "$LOG"
# An idle camera sends no IPC lines, so the loop's end check alone could wait forever.
(sleep "$((SECS + 1))"; read p < "$PIDFILE" && kill "$p" 2>/dev/null) &
# With -d, ipc_read prints the hex dump on stderr, not stdout.
(/tmp/sd/yi-hack-v5/bin/ipc_read -n "$Q" -d 2>&1 & echo $! > "$PIDFILE"; wait) | {
  n=0
  while read -r line; do
    read up x < /proc/uptime
    [ "${up%.*}" -ge "$end" ] && break
    # ipc_read clears the queue's stale backlog at start; skip the first 2 s as well.
    [ "${up%.*}" -lt "$((${up0%.*} + 2))" ] && continue
    case "$line" in
      "01 00 00 00 02 00 00 00 7c 00 7c 00"*|"01 00 00 00 02 00 00 00 e6 00 e6 00"*|"01 00 00 00 02 00 00 00 7d 00 7d 00"*)
        echo "$up $line" >> "$LOG"
        n=$((n + 1))
        [ "$n" -ge 50000 ] && break
        ;;
    esac
  done
}
read up x < /proc/uptime
echo "end_uptime $up" >> "$LOG"
read p < "$PIDFILE" && kill "$p" 2>/dev/null
