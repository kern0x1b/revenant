#!/bin/sh
# run.sh - the port's CIRectangleFeature, CIQRCodeFeature and CITextFeature against the HOST's own CoreImage, in two
# programs built from the same differential.m (no python: the names are read from the port's sources with sed).
#
#   1. differential.m is COMPILED against the host's CoreImage (a bare macOS tool) and run
#   2. the same source is COMPILED against the port's Graphics sources, with port-base.m as the release's CIFeature stand-in
#      and rename.h giving the port's classes a prefix in THIS BUILD ONLY: on macOS every process that uses Foundation has
#      CoreImage loaded, so an unrenamed port class is a duplicate of the host's, and the runtime answers with whichever
#      registered first (tests/backports/host/cibarcode/run.sh says the same)
#   3. the two outputs are compared with the "known:" lines removed; the known lines are compared with their pins
#      (known-host.txt, known-port.txt, the exact lines each side gave when the difference was measured), so a known
#      difference that changes on either side is red too; the four known differences are in differential.m's header
#   4. a plant on a scratch copy of the port's sources - one answer changed - must turn the comparison red: two plants
#      change a plain line, one changes only a known line, and each must be caught by the comparison or its pin
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
gfx="$appledir/Graphics"
build=${BUILD:-$(runs_folder cifeature)}
mkdir -p "$build"

# rename.h: every class the port's files declare, read from those files, renamed with a prefix in the port build only.
: > "$build/rename.h"
for name in $(sed -n -e 's/^@interface \(CI[A-Za-z]*\).*/\1/p' -e 's/^@implementation \(CI[A-Za-z]*\).*/\1/p' \
        "$gfx/CIFeature8.m" "$gfx/CIFeature9.m" "$gfx/CIQRCodeFeature11.m" "$here/port-base.m" | sort -u); do
    echo "#define $name RevenantPort$name" >> "$build/rename.h"
done

xcrun clang -fobjc-arc -w -framework Foundation -framework CoreImage -framework CoreText -framework CoreGraphics \
    "$here/differential.m" -o "$build/host"

port_build() {
    # port_build <directory of the port's Graphics sources> <output>
    # The three feature constants, copied from the port's own constants files (the files as a whole redefine symbols the
    # macOS CoreImage header declares, so they cannot be compiled against it).
    { echo '#import <Foundation/Foundation.h>'; sed -n '/^NSString \*const CIFeatureType/p' "$1/CIConstants80.m" "$1/CIConstants90.m"; } > "$build/port-constants.m"
    xcrun clang -fobjc-arc -w -DPORT -include "$build/rename.h" -framework Foundation -framework CoreGraphics \
        "$here/differential.m" "$here/port-base.m" "$build/port-constants.m" \
        "$1/CIFeature8.m" "$1/CIFeature9.m" "$1/CIQRCodeFeature11.m" \
        -o "$2"
}
port_build "$gfx" "$build/port"

set +e
"$build/host" > "$build/host.out" 2> "$build/host.err"; hs=$?
"$build/port" > "$build/port.out" 2> "$build/port.err"; ps=$?
set -e

differs=0
echo "--- the clean run (host exit $hs, port exit $ps)"
if [ "$hs" -ge 128 ]; then
    echo "HOST CRASHED (signal $((hs - 128))): not comparable"
    differs=$((differs + 1))
fi
[ "$ps" -eq 0 ] || { echo "PORT EXIT $ps"; differs=$((differs + 1)); }
grep -v '^known:' "$build/host.out" > "$build/host.cmp"
grep -v '^known:' "$build/port.out" > "$build/port.cmp"
if cmp -s "$build/host.cmp" "$build/port.cmp"; then
    echo "EQUAL: $(wc -l < "$build/host.cmp" | tr -d ' ') lines, the same on both sides once the known lines are apart"
else
    differs=$((differs + 1))
    echo "DIFFERS:"
    diff "$build/host.cmp" "$build/port.cmp" | sed 's/^/    /' || true
fi
echo "--- known differences (pinned, not compared): host / port"
sed -n '/^known:/p' "$build/host.out" > "$build/host.known"
sed -n '/^known:/p' "$build/port.out" > "$build/port.known"
sed 's/^/    host: /' "$build/host.known"
sed 's/^/    port: /' "$build/port.known"
if cmp -s "$here/known-host.txt" "$build/host.known" && cmp -s "$here/known-port.txt" "$build/port.known"; then
    echo "PINNED: the $(wc -l < "$build/host.known" | tr -d ' ') host and $(wc -l < "$build/port.known" | tr -d ' ') port known lines match their pins"
else
    differs=$((differs + 1))
    echo "KNOWN PINS CHANGED:"
    diff "$here/known-host.txt" "$build/host.known" | sed 's/^/    host pin: /' || true
    diff "$here/known-port.txt" "$build/port.known" | sed 's/^/    port pin: /' || true
fi

# A plant is a copy of the port's sources with one line changed, and the comparison (plain, or a known pin) must then differ.
plant() {
    # plant <file> <sed-expression> <label>
    file=$1; expr=$2; label=$3
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$gfx/CIFeature8.m" "$gfx/CIFeature9.m" "$gfx/CIQRCodeFeature11.m" "$gfx/CIConstants80.m" "$gfx/CIConstants90.m" \
        "$build/mutant/"
    sed "$expr" "$gfx/$file" > "$build/mutant/$file"
    if cmp -s "$gfx/$file" "$build/mutant/$file"; then
        echo "MUTATION DID NOT APPLY: $label"
        differs=$((differs + 1000))
        return
    fi
    port_build "$build/mutant" "$build/port-mutant"
    set +e
    "$build/port-mutant" > "$build/port-mutant.out" 2> "$build/port-mutant.err"
    set -e
    grep -v '^known:' "$build/port-mutant.out" > "$build/port-mutant.cmp"
    grep '^known:' "$build/port-mutant.out" > "$build/port-mutant.known"
    if cmp -s "$build/host.cmp" "$build/port-mutant.cmp" && cmp -s "$here/known-port.txt" "$build/port-mutant.known"; then
        echo "MUTANT SURVIVED: $label"
        differs=$((differs + 1000))
    else
        echo "  caught: $label"
    fi
}

echo "--- the plants"
plant CIFeature8.m 's/    return CIFeatureTypeQRCode;/    return CIFeatureTypeRectangle;/' "QR type answers the rectangle constant"
plant CIFeature9.m 's/        _bottomRight = bottomRightPoint;/        _bottomRight = CGPointZero;/' "text bottom-right corner lost"
plant CIFeature8.m 's/    return _messageString;/    return _messageString ?: @"fresh";/' "fresh QR messageString answers a string (known pin only)"

echo "--- verdict: $differs difference(s)"
[ "$differs" -eq 0 ]
