#!/bin/bash
# cam-measure snapshot mode: 20 requests to /cgi-bin/snapshot.sh?res=low, 30 s apart (start to start).
# The httpd credential reaches curl on stdin (-K -), never on argv (ADR-0006).
# Usage: scripts/cam-measure-snapshot.sh <repo root> <output file> <jpeg dir>
ROOT="$1"
OUT="$2"
DIR="$3"
ip=$(sed -n 's/^YI_IP=//p' "$ROOT/.env")
pw=$(sed -n 's/^YI_RTSP_PASSWORD=//p' "$ROOT/.env")
mkdir -p "$DIR"
: > "$OUT"
for i in $(seq 1 20); do
  start=$(date +%s)
  stamp=$(date -u +%H:%M:%S)
  res=$(printf 'user = "root:%s"\n' "$pw" | curl -K - -s --max-time 15 -o "$DIR/$i.jpg" \
    -w '%{http_code} %{size_download} %{time_total}' "http://$ip/cgi-bin/snapshot.sh?res=low")
  echo "$i $stamp $res" >> "$OUT"
  [ "$i" -lt 20 ] && sleep $((30 - ($(date +%s) - start)))
done
echo "snapshot run done: $(wc -l < "$OUT") requests"
