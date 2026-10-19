#!/bin/sh
# run-app.sh - the bracketed capture probe (app/main.m) as an application installed on the emulated iPhone 4S at 6.1.3, run by
# `xmake emulate run /Applications/charonphotobracketprobe.app/charonphotobracketprobe`.
#
# The probe checks the AVCapturePhotoBracketSettings factories, members and refusals; the output's bracket limit, lens
# stabilization and refusals; a bracket of three auto exposures captured on the camera, whose callbacks must come in the
# order the header gives (begin once, then will, did and photo for each member, finish once) with each photo carrying its own
# bracket setting and count; a single capture through the 10.0 callback; and the AVCapturePhoto object from a BGRA buffer, a
# JPEG and an error. There is no host oracle for this class (the macOS build raises from every factory), so the checks are the
# header's own statements and the port's behaviour. The emulator's captures end in -11800 where the camera answers at all, so
# the bracket's callbacks are checked, and the pixels are not (facts/AVFoundation/AVCapturePhotoBracketSettings.md, "The emulator").
#
# Usage: sh tests/backports/emulate/photobracket/run-app.sh
# Run through coordination/heavy.sh (one emulator boot). The exit status is 0 only when the probe prints its "checks: N
# failed: F" line with F = 0, N matches the number of check lines, and every check line is "ok".
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
stamp=$(date +%Y%m%d-%H%M%S)
out=${PHOTOBRACKET_RUN:-$root/.agent-work/runs/v-impl-avf-1/photobracket-$stamp}
mkdir -p "$out"
cp "$here/app/xmake.lua" "$here/app/Info.plist" "$here/app/control" "$out/"
cp "$here/app/main.m" "$out/main.m"
cd "$out"
CHARPHOTOBRACKET_ROOT=$root CHARPHOTOBRACKET_MINIMUM=6.1.3 xmake f -p iphoneos -a armv7 -y >"$out/configure.log" 2>&1 || {
    echo "the probe did not configure; $out/configure.log says why" >&2
    tail -20 "$out/configure.log" >&2
    exit 1
}
CHARPHOTOBRACKET_ROOT=$root CHARPHOTOBRACKET_MINIMUM=6.1.3 xmake emulate -d iPhone4,1 -r 6.1.3 install >"$out/install.log" 2>&1 || {
    echo "the probe did not install; $out/install.log says why" >&2
    tail -20 "$out/install.log" >&2
    exit 1
}
set +e
CHARPHOTOBRACKET_ROOT=$root CHARPHOTOBRACKET_MINIMUM=6.1.3 xmake emulate -d iPhone4,1 -r 6.1.3 run /Applications/charonphotobracketprobe.app/charonphotobracketprobe >"$out/launch.log" 2>&1
run_status=$?
xmake emulate -d iPhone4,1 -r 6.1.3 log >"$out/emulate.log" 2>&1
set -e
echo "run folder: $out (run status $run_status: the probe's exit status is its failure count)"
# The probe's lines are the check lines and the count line; nothing else in the run log is judged.
sed -n '/^check /p;/^checks: /p' "$out/launch.log" > "$out/probe.lines"
want=$(sed -n 's/^checks: \([0-9][0-9]*\) failed: \([0-9][0-9]*\)$/\1/p' "$out/probe.lines" | tail -1)
bad=$(sed -n 's/^checks: \([0-9][0-9]*\) failed: \([0-9][0-9]*\)$/\2/p' "$out/probe.lines" | tail -1)
have=$(grep -c '^check ' "$out/probe.lines" || true)
fails=$(grep -c '^check .* FAIL' "$out/probe.lines" || true)
if [ -z "$want" ] || [ "$have" -ne "$want" ]; then
    echo "FAIL: the probe printed $have check lines but reported ${want:-no count}; see $out/launch.log" >&2
    exit 1
fi
if [ "$bad" -ne 0 ] || [ "$fails" -ne 0 ]; then
    echo "FAIL: $fails of $have checks failed (the failing lines are in $out/probe.lines)" >&2
    grep 'FAIL' "$out/probe.lines" >&2
    exit 1
fi
echo "ok  $have of $have checks passed on the 6.1.3 emulator ($out/probe.lines)"
