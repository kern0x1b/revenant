#!/bin/sh
# run.sh - the port's QR decoder (Graphics/RevenantQRDecode.c) against the HOST's own CIQRCodeGenerator and CIDetector.
#
# ciqr.m makes the codes on the host, reads each grid from its pixels (no detection in the decoding), and holds the
# decoder's message to the host's messageString for the same image. Then each code is damaged with a fixed seed.
#
#   1. the decoder and ciqr.m are compiled for the host, and the run must be green: every case and every damage trial
#   2. three plants, each on a scratch copy of the decoder with one line changed, must each turn the run red:
#      the syndrome roots shifted by one (a wrong generator polynomial), each Forney magnitude flipped (a wrong
#      correction) and the unmasking skipped
#
# No python. The build and the plants go under .agent-work/runs/ciqr, never /tmp.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$here/../../../..
gfx=${GFX:-$root/packages/a/apple-backports/Graphics}
build=${BUILD:-$root/.agent-work/runs/ciqr}
mkdir -p "$build"

build_run() {
    # build_run <directory of the decoder's sources> <output binary>
    xcrun clang -std=c99 -O2 -Wall -Wextra -c "$1/RevenantQRDecode.c" -I "$1" -o "$2.o"
    xcrun clang -fobjc-arc -Wall -Wextra -I "$1" "$here/ciqr.m" "$2.o" \
        -framework Foundation -framework CoreImage -framework CoreGraphics -o "$2"
}

differs=0
build_run "$gfx" "$build/ciqr"
set +e
"$build/ciqr" > "$build/ciqr.out" 2> "$build/ciqr.err"
hs=$?
set -e
echo "--- the clean run (exit $hs)"
cat "$build/ciqr.out"
if [ "$hs" -ne 0 ]; then
    differs=$((differs + 1))
    echo "CLEAN RUN RED: $(grep -c '^FAIL' "$build/ciqr.out") failing case line(s), stderr: $(wc -l < "$build/ciqr.err" | tr -d ' ') line(s)"
fi

plant() {
    # plant <name> <sed script>: the decoder with the script's change must turn the run red
    dir=$build/plant-$1
    mkdir -p "$dir"
    sed "$2" "$gfx/RevenantQRDecode.c" > "$dir/RevenantQRDecode.c"
    cp "$gfx/RevenantQRDecode.h" "$dir/RevenantQRDecode.h"
    if cmp -s "$gfx/RevenantQRDecode.c" "$dir/RevenantQRDecode.c"; then
        differs=$((differs + 1))
        echo "PLANT $1: the change did not apply to the source"
        return
    fi
    build_run "$dir" "$dir/ciqr"
    set +e
    "$dir/ciqr" > "$dir/ciqr.out" 2> "$dir/ciqr.err"
    ps=$?
    set -e
    if [ "$ps" -ne 0 ]; then
        echo "PLANT $1: red as it must be (exit $ps, $(grep -c '^FAIL' "$dir/ciqr.out") failing case line(s))"
    else
        differs=$((differs + 1))
        echo "PLANT $1: GREEN - the run did not see the change"
    fi
}

plant root-base 's/uint8_t root = gf->exp\[j\];/uint8_t root = gf->exp[j + 1];/'
plant flipped-correction 's/cw\[idx\] ^= gf_mul(gf, locator, gf_div(gf, ov, dv));/cw[idx] ^= gf_mul(gf, locator, gf_div(gf, ov, dv)) ^ 1;/'
plant skipped-mask 's/ ^ mask_inverts(maskIndex, r, c);/;/'

if [ "$differs" -eq 0 ]; then
    echo "GREEN: the decoder agrees with the host on every case and every damage trial; all three plants are red"
else
    echo "RED: $differs check(s) failed"
    exit 1
fi
