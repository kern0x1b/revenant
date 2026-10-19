#!/bin/sh
# run-app.sh - the release measurement (app/main.m): what the 6.1.3 release's own AVFoundation and CoreImage answer, with no port
# package linked. Its lines are "info name detail" (no pass or fail: a measurement is recorded in facts, not judged here).
#
# Usage: sh tests/backports/emulate/release-measure/run-app.sh
# Run through coordination/heavy.sh (one emulator boot). The exit status is 0 when the program prints "measure done".
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
stamp=$(date +%Y%m%d-%H%M%S)
out=${RELEASEMEASURE_RUN:-$root/.agent-work/runs/v-impl-avf-1/releasemeasure-$stamp}
mkdir -p "$out"
cp "$here/app/xmake.lua" "$here/app/Info.plist" "$here/app/control" "$out/"
cp "$here/app/main.m" "$out/main.m"
cd "$out"
CHARPHOTOBRACKET_ROOT=$root CHARPHOTOBRACKET_MINIMUM=6.1.3 xmake f -p iphoneos -a armv7 -y >"$out/configure.log" 2>&1 || {
    echo "the measurement did not configure; $out/configure.log says why" >&2
    tail -20 "$out/configure.log" >&2
    exit 1
}
CHARPHOTOBRACKET_ROOT=$root CHARPHOTOBRACKET_MINIMUM=6.1.3 xmake emulate -d iPhone4,1 -r 6.1.3 install >"$out/install.log" 2>&1 || {
    echo "the measurement did not install; $out/install.log says why" >&2
    tail -20 "$out/install.log" >&2
    exit 1
}
set +e
CHARPHOTOBRACKET_ROOT=$root CHARPHOTOBRACKET_MINIMUM=6.1.3 xmake emulate -d iPhone4,1 -r 6.1.3 run /Applications/charonreleasemeasure.app/charonreleasemeasure >"$out/launch.log" 2>&1
run_status=$?
xmake emulate -d iPhone4,1 -r 6.1.3 log >"$out/emulate.log" 2>&1
set -e
echo "run folder: $out (run status $run_status)"
sed -n '/^info /p;/^measure done/p' "$out/launch.log" > "$out/measure.lines"
grep -q '^measure done' "$out/measure.lines" || { echo "FAIL: no 'measure done' line; see $out/launch.log" >&2; exit 1; }
echo "ok  $(grep -c '^info ' "$out/measure.lines") measurement lines ($out/measure.lines)"
