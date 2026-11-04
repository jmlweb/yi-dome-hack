# 0006. Secrets travel by file or environment, never the repo; one temporary argv exception

**Status:** accepted

## Context
Upstream starts `rRTSPServer` with its password as a command-line argument (`-w`). The binary has no file or environment option (checked with `-h` on 2026-10-21), so `ps` on the camera shows it. Only a root shell on the camera can read it, and that shell already has full access. The repo will hold camera configs. The project owner requires that the camera password never leaks. Network identifiers (IPs, MACs, serials, MQTT prefix) must also stay out of version control.

## Decision
Credentials reach processes through permission-restricted files or environment variables. Credentials and network identifiers live only in the gitignored local env file and on the camera; the repo holds templates with placeholders. The single exception is the RTSP server's password argument, which stays until a source-built RTSP server reads it from a file (ADR-0007).

## Consequences
- No credential shows in logs or git history, and only the RTSP server's shows in the camera's process list, to root.
- Any new process that needs a credential must read it from a file or the environment, not argv.
- Removing the exception depends on the cross build; until then the RTSP password must differ from the SSH/root password.
- Setting up a fresh checkout needs a manual step to fill the env file.
