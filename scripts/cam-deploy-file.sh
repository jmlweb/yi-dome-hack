#!/bin/bash
# Replaces one file on the camera's SD overlay, with backup and rollback (ADR-0001, ADR-0005, ADR-0006).
# Usage: scripts/cam-deploy-file.sh <patched-file> <remote-path> <input-sha256> <output-sha256> --yes
# Remote path must sit under /tmp/sd/. Restart of the owning service is a separate step.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH="$ROOT/scripts/cam-ssh.sh"

if [ "$#" -ne 5 ] || [ "$5" != "--yes" ]; then
  echo "refused: pass <patched-file> <remote-path> <input-sha256> <output-sha256> --yes" >&2
  exit 1
fi
local_file="$1"
remote_path="$2"
input_sha="$3"
output_sha="$4"

case "$remote_path" in
  /tmp/sd/*) ;;
  *) echo "refused: remote path must be under /tmp/sd/" >&2; exit 1 ;;
esac

env_value() { sed -n "s/^$1=//p" "$ROOT/.env"; }
rtsp_password="$(env_value YI_RTSP_PASSWORD)"
if [ -z "$rtsp_password" ] || [ "$rtsp_password" = "$(env_value YI_PASSWORD)" ]; then
  echo "refused: YI_RTSP_PASSWORD is unset or equals YI_PASSWORD (ADR-0006)" >&2
  exit 1
fi

sha256_of() { shasum -a 256 "$1" | cut -d' ' -f1; }

if [ "$(sha256_of "$local_file")" != "$output_sha" ]; then
  echo "abort: local file does not match the record's output sha256" >&2
  exit 1
fi

current_copy="$(mktemp)"
trap 'rm -f "$current_copy"' EXIT
"$SSH" "cat $remote_path" > "$current_copy"
if [ "$(sha256_of "$current_copy")" != "$input_sha" ]; then
  echo "abort: camera file at $remote_path does not match the record's input sha256" >&2
  exit 1
fi

backup_dir="/tmp/sd/yi-dome-hack-backup/$(date -u +%Y%m%dT%H%M%SZ)"
backup_file="$backup_dir$remote_path"
echo "backup: $backup_file"
"$SSH" "mkdir -p $(dirname "$backup_file") && cp $remote_path $backup_file"

# Write beside the target and rename: a running process keeps its old inode, so this avoids "Text file busy".
"$SSH" "cat > $remote_path.new && chmod 755 $remote_path.new && mv $remote_path.new $remote_path" < "$local_file"

deployed_copy="$(mktemp)"
trap 'rm -f "$current_copy" "$deployed_copy"' EXIT
"$SSH" "cat $remote_path" > "$deployed_copy"
if [ "$(sha256_of "$deployed_copy")" != "$output_sha" ]; then
  echo "abort: deployed file sha256 does not match; rollback below" >&2
  echo "rollback: $SSH \"cp $backup_file $remote_path\"" >&2
  exit 1
fi

echo "deployed: $remote_path sha256 $output_sha"
echo "rollback: scripts/cam-ssh.sh 'cp $backup_file $remote_path'"
echo "restart the owning service next (mqttv4: killall mqttv4, then start it as system.sh does)"
