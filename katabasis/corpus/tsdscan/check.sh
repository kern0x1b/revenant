#!/bin/sh
# check.sh -- corpus/tsdscan: a control for xlate's own build-time TSD-offset scan
# (xlate/src/tsd_scan.cpp). Host-only, no device: this is a static property of xlate itself (it
# refuses to emit lifted code for an image that reads TPIDRRO_EL0 at an unaudited offset), checked
# by running xlate directly against two builds of main.c rather than through a full
# scripts/translate.sh lift -- neither build needs to run anywhere, only to be fed to xlate.
#   1. TSD_OFFSET=0x358 (Swift's __PTK_FRAMEWORK_SWIFT_KEY7, the one offset runtime/runtime.c's
#      fake TSD block is measured and sized for): xlate must accept the image.
#   2. TSD_OFFSET=0x40 (an offset nothing has ever measured a guest touching): xlate must refuse
#      to build it, naming the offset in its own error message AND each of main.c's three cases by
#      its function -- read_tsd_slot (straight line), dead_path_clobber (the clobber on one arm of
#      a branch) and callee_reads_tsd (the base crossing a call in a callee-saved register). Naming
#      all three is the point: two of them are the false negatives an address-ordered,
#      per-function sweep of the scan had, so a scanner that caught only the first would pass a
#      check that no longer proves what it is for.
set -eu
LAB=$(cd "$(dirname "$0")/../.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
out=${1:-$here/out}
mkdir -p "$out"
xlate="$LAB/xlate/build/xlate"
[ -x "$xlate" ] || { echo "xlate not built: cmake --build $LAB/xlate/build --target xlate" >&2; exit 1; }

# The logs and the binaries go first: a build that fails leaves the previous run's output on disk,
# and a reader takes that for this run's answer -- which is how a check reports numbers its own
# source never produced.
rm -f "$out/good" "$out/bad" "$out/good.log" "$out/bad.log" "$out/good.json" "$out/bad.json"

xcrun clang -arch arm64 -O2 -w -DTSD_OFFSET=0x358 "$here/main.c" -o "$out/good"
xcrun clang -arch arm64 -O2 -w -DTSD_OFFSET=0x40  "$here/main.c" -o "$out/bad"

"$xlate" --base 0x10000000 --objc-manifest "$out/good.json" "$out/good" > "$out/good.log" 2>&1 \
  || { echo "FAIL: xlate refused the one audited offset (0x358)"; cat "$out/good.log"; exit 1; }

if "$xlate" --base 0x10000000 --objc-manifest "$out/bad.json" "$out/bad" > "$out/bad.log" 2>&1; then
  echo "FAIL: xlate accepted an unaudited TPIDRRO_EL0 offset (0x40)"
  cat "$out/bad.log"
  exit 1
fi
grep -q 'not on the audited allow-list' "$out/bad.log" || { echo "FAIL: xlate refused main for a different reason"; cat "$out/bad.log"; exit 1; }
grep -q '0x40' "$out/bad.log" || { echo "FAIL: the refusal did not name the offset"; cat "$out/bad.log"; exit 1; }
for fn in read_tsd_slot dead_path_clobber callee_reads_tsd; do
  grep -q "$fn" "$out/bad.log" || { echo "FAIL: the refusal did not name $fn, so this shape of access is not caught"; cat "$out/bad.log"; exit 1; }
done

echo "ok"
