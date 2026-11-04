# 0002. Verified in-place patches of closed or unbuildable binaries

**Status:** accepted

## Context
`rmm` (the Yi video/motion/audio app) is closed source with no SDK. The cross toolchain for rebuilding yi-hack binaries is not publicly available. Static analysis (`docs/research/rmm.md`) found two small binary changes:
- a single-constant change in the `mqttv4` bridge that fixes the motion-start loss (ADR-0003)
- a single-instruction change in `rmm` that removes the ~29% CPU mic pipeline, if the runtime mic switch does not

## Decision
Changes to shipped binaries are declarative patch records (file, offset, expected original bytes, replacement bytes, input and output hashes) applied by a script that refuses to write when the input hash or original bytes differ. Each record is applied and measured on its own before it is combined with others.

## Consequences
- Fixes ship without a compiler and are reproducible from the upstream release.
- A patch is tied to one exact binary build; a different base firmware needs new analysis.
- Behaviour changes that need new code (threads, new logic) cannot be done this way and need source builds (ADR-0007).
