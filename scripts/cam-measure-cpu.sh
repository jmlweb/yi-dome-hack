#!/bin/bash
# cam-measure cpu mode: 3 windows of 300 s in one persistent SSH session.
# The camera shell only runs builtins (read, case, echo); the 60 s pacing sleeps run on the Mac,
# so no tool spawns on the camera inside the sampling loop (ADR-0004, ADR-0005).
# Usage: scripts/cam-measure-cpu.sh <repo root> <output file>
ROOT="$1"
OUT="$2"

remote_defs() {
  cat <<'EOF'
snap() {
  read up idle < /proc/uptime
  echo "SNAP $1 $up"
  r=
  for f in /proc/[0-9]*/stat; do
    read l < $f 2>/dev/null || continue
    echo "P $l"
    set -- $l
    [ "$2" = "(rmm)" ] && r=$1
  done
  echo "RMM $r"
  for f in /proc/$r/task/[0-9]*/stat; do
    read l < $f 2>/dev/null && echo "T $l"
  done
  echo "ENDSNAP"
}
mem() {
  read up idle < /proc/uptime
  while read k v u; do
    case $k in MemFree:) echo "MEM $up $v" ;; esac
  done < /proc/meminfo
  read a b c d e < /proc/loadavg
  echo "LOAD $up $a $b $c $d"
}
rtsp() {
  n=0
  while read sl loc rem st rest; do
    case "$loc $st" in *:022A\ 01) n=$((n+1)) ;; esac
  done < /proc/net/tcp
  echo "RTSP $1 $n"
}
EOF
}

{
  remote_defs
  for w in 1 2 3; do
    echo "rtsp start$w; snap start$w; mem"
    for s in 1 2 3 4 5; do
      sleep 60
      echo "mem"
    done
    echo "snap end$w; rtsp end$w"
  done
  echo "exit"
} | "$ROOT/scripts/cam-ssh.sh" sh > "$OUT" 2>&1
echo "cpu windows done: $(grep -c '^SNAP' "$OUT") snaps"
