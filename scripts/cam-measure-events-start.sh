#!/bin/bash
# cam-measure events mode, Mac side: NTP offset, uptime-to-UTC anchor, then the sniffer under nohup.
# Usage: scripts/cam-measure-events-start.sh <repo root> <seconds> <local out dir>
set -euo pipefail
ROOT="$1"
SECS="$2"
OUT="$3"
SSH="$ROOT/scripts/cam-ssh.sh"
SNIFFER="$(dirname "$0")/cam-measure-events-sniffer.sh"
LOGDIR=/tmp/sd/yi-dome-hack-logs
mkdir -p "$OUT"

date -u +"mac_start %Y-%m-%dT%H:%M:%SZ" | tee "$OUT/start.txt"
# Query only (-w): the camera clock is not set. 185.125.190.58 is ntp.ubuntu.com, the broker host's own upstream,
# so camera and broker offsets are comparable. Anchor only once this reads under 100 ms (about 10 min after a boot).
"$SSH" 'busybox ntpd -w -d -p 185.125.190.58 2>&1 & p=$!; sleep 20; kill $p' 2>&1 | grep 'reply from' | tee -a "$OUT/start.txt"
# The anchor waits for the second to tick over, then reads uptime; the precision is one date spawn (a few ms).
"$SSH" 's0=$(date +%s); while [ "$(date +%s)" = "$s0" ]; do :; done; read up x < /proc/uptime; echo "anchor_epoch $((s0 + 1)) anchor_uptime $up"' | tee -a "$OUT/start.txt"

"$SSH" "mkdir -p $LOGDIR && cat > $LOGDIR/tsk002-events.sh" < "$SNIFFER"
"$SSH" "cd /; nohup sh $LOGDIR/tsk002-events.sh 3 $SECS $LOGDIR/tsk002-events.log >/dev/null 2>&1 &"
sleep 3
"$SSH" "cat $LOGDIR/tsk002-events.log" | tee -a "$OUT/start.txt"
