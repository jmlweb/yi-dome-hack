#!/bin/bash
# ssh askpass helper: prints the camera password from the local env file, so it
# never appears on a command line or in script output (ADR-0006)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
sed -n 's/^YI_PASSWORD=//p' "$ROOT/.env"
