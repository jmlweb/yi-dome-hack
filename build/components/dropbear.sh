# Static dropbearmulti for the ARM926EJ-S. Runs inside the build image.
# The CPU lists no thumb feature in /proc/cpuinfo, so everything is built -marm
# and the result is checked for Thumb code before it leaves the container.
set -eu

VERSION=2026.94
SHA256=e098034a843699200c8c977a991fff73159735bf795d5f72ef672c41a6b1ae81

curl -fsSL -o dropbear.tar.bz2 \
  "https://matt.ucc.asn.au/dropbear/releases/dropbear-${VERSION}.tar.bz2"
echo "${SHA256}  dropbear.tar.bz2" | sha256sum -c -
tar -xjf dropbear.tar.bz2
cd "dropbear-${VERSION}"

export CC="${CROSS}-gcc" CFLAGS="-Os -march=armv5te -mtune=arm926ej-s -marm -mfloat-abi=soft"
./configure --host="${CROSS}" --disable-zlib --disable-lastlog --disable-utmp \
  --disable-utmpx --disable-wtmp --disable-wtmpx --disable-pututline \
  --disable-pututxline --enable-static >/dev/null

make -j"$(nproc)" PROGRAMS="dropbear dbclient dropbearkey scp" MULTI=1 >/dev/null
attrs=$("${CROSS}-readelf" -A dropbearmulti)
echo "$attrs" | grep -q 'Tag_CPU_arch: v5TE' || { echo "not v5TE:" >&2; echo "$attrs" >&2; exit 1; }
# Tag_THUMB_ISA_use only says Thumb is permitted; $t mapping symbols (present
# before strip, libc objects included) say Thumb code was actually emitted.
syms=$("${CROSS}-readelf" -s dropbearmulti)
arm=$(echo "$syms" | grep -c ' \$a' || true)
thumb=$(echo "$syms" | grep -c ' \$t' || true)
echo "mapping symbols: \$a=$arm \$t=$thumb"
[ "$arm" -gt 0 ] || { echo "no \$a symbols: symbol table missing, Thumb check is void" >&2; exit 1; }
[ "$thumb" -eq 0 ] || { echo "Thumb code present: $thumb \$t symbols" >&2; exit 1; }
"${CROSS}-strip" dropbearmulti

cp dropbearmulti /build/out/dropbearmulti
cd /build/out
file dropbearmulti
echo "$attrs" | grep -E 'Tag_CPU_arch|Tag_ARM_ISA|Tag_THUMB|Tag_ABI_VFP|Tag_FP'
ls -l dropbearmulti
sha256sum dropbearmulti
