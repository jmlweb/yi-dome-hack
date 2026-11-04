#!/bin/bash
# Sets system.conf PASSWORD (RTSP, ONVIF and httpd auth) to YI_RTSP_PASSWORD from .env (ADR-0006).
# Usage: scripts/cam-set-rtsp-password.sh --yes
# Takes effect on the next boot: system.sh builds the rRTSPServer argv and httpd.conf from it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH="$ROOT/scripts/cam-ssh.sh"
CONF=/tmp/sd/yi-hack-v5/etc/system.conf

if [ "$#" -ne 1 ] || [ "$1" != "--yes" ]; then
  echo "refused: pass --yes" >&2
  exit 1
fi

env_value() { sed -n "s/^$1=//p" "$ROOT/.env"; }
new_password="$(env_value YI_RTSP_PASSWORD)"
if [ -z "$new_password" ] || [ "$new_password" = "$(env_value YI_PASSWORD)" ]; then
  echo "refused: YI_RTSP_PASSWORD is unset or equals YI_PASSWORD (ADR-0006)" >&2
  exit 1
fi
# system.sh embeds it unescaped in user:pass@ RTSP URLs and in httpd.conf "/:user:pass"
if ! [[ "$new_password" =~ ^[A-Za-z0-9._~-]{12,}$ ]]; then
  echo "refused: YI_RTSP_PASSWORD must be 12+ chars of A-Z a-z 0-9 . _ ~ -" >&2
  exit 1
fi

backup_file="/tmp/sd/yi-dome-hack-backup/$(date -u +%Y%m%dT%H%M%SZ)$CONF"
echo "backup: $backup_file"
"$SSH" "mkdir -p \$(dirname $backup_file) && cp $CONF $backup_file"

# The password travels on stdin and is written with shell builtins, so it is in no process argv.
printf '%s\n' "$new_password" | "$SSH" "IFS= read -r p
while IFS= read -r line; do
  case \"\$line\" in
    PASSWORD=*) printf 'PASSWORD=%s\n' \"\$p\" ;;
    *) printf '%s\n' \"\$line\" ;;
  esac
done < $CONF > $CONF.new && mv $CONF.new $CONF"

printf '%s\n' "$new_password" | "$SSH" "IFS= read -r p
[ \"\$(sed -n 's/^PASSWORD=//p' $CONF)\" = \"\$p\" ] && echo 'verified: PASSWORD updated' || { echo 'abort: PASSWORD mismatch' >&2; exit 1; }"

echo "rollback: scripts/cam-ssh.sh 'cp $backup_file $CONF'"
echo "next: reboot the camera, then update the password in HA (yi-hack integration and any RTSP URL)"
