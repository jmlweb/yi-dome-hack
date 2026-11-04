#!/bin/bash
# cam-measure grab mode: 20 on-camera imggrabber runs at res=low, 30 s apart, in one SSH session.
# Wall time comes from /proc/uptime deltas (10 ms resolution). Only imggrabber runs inside the
# timed window; ls and awk run after it, once per 30 s, not in a polling loop (ADR-0004).
# Read-only: the JPEG goes to one tmpfs file, emptied at the end.
# Output lines: <n> <uptime start> <grab seconds> <jpeg bytes>
# Usage: scripts/cam-measure-grab.sh <repo root> <output file>
ROOT="$1"
OUT="$2"
"$ROOT/scripts/cam-ssh.sh" '
. /tmp/sd/yi-hack-v5/script/env.sh
m=$(cat /home/app/.camver)
f=/tmp/grab-measure.jpg
i=1
while [ $i -le 20 ]; do
  read t0 idle < /proc/uptime
  imggrabber -m $m -r low > $f
  read t1 idle < /proc/uptime
  set -- $(ls -l $f)
  echo "$i $t0 $(echo "$t1 $t0" | awk "{printf \"%.2f\", \$1 - \$2}") $5"
  i=$((i + 1))
  [ $i -le 20 ] && sleep $((30 - ${t1%.*} + ${t0%.*}))
done
: > $f
' > "$OUT"
echo "grab run done: $(wc -l < "$OUT") runs"
