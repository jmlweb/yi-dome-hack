#!/bin/bash
# Runs one command on the camera over SSH with the askpass helper. Commands that change
# camera state (config, tracking, PTZ, reboot, process restarts) need the owner's OK first (ADR-0005).
# Usage: scripts/cam-ssh.sh '<remote command>'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
env_value() { sed -n "s/^$1=//p" "$ROOT/.env"; }
export SSH_ASKPASS="$ROOT/scripts/cam-askpass.sh" SSH_ASKPASS_REQUIRE=force
exec ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o PubkeyAuthentication=no \
  "$(env_value YI_USER)@$(env_value YI_IP)" "$1"
