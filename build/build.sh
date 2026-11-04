#!/bin/sh
# Build one component for the camera: build/build.sh <component>
# Runs build/components/<component>.sh inside the pinned toolchain image;
# artifacts land in build/out/.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
component=${1:?usage: build/build.sh <component>}
script="$here/components/$component.sh"
[ -f "$script" ] || { echo "no such component: $component" >&2; exit 1; }

image=yi-dome-build:armv5-musl
docker build --platform linux/amd64 -t "$image" "$here"

mkdir -p "$here/out"
docker run --rm --platform linux/amd64 \
  -v "$here:/build" -w /work \
  "$image" sh -eu "/build/components/$component.sh"
