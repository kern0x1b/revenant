#!/bin/sh
# The nine MKMapViewDelegate messages, one case each, driven through the PORT'S OWN proxy on the
# host's own MKMapView, with a recording delegate. A Catalyst build, because the proxy lives on
# MKMapView and MKMapView is UIKit's.
#
# The mutant is the SAME dylib: the runner allocates a subclass of the host's own MKMapView at run time
# whose proxy method hands the program the wrong argument, so the port's source is byte-identical in
# both runs and the only difference is the argument. The probe FAILS if the mutant does not differ,
# because a green mutant is a comparison that decides nothing, and FAILS if the real run has fewer
# than nine cases, because then it is not covering the nine.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
port=${PORT:-$here/../../../../packages/a/apple-backports/MapKit}
# BUILD goes under the repository's own .agent-work, never the system temp: the run output is
# evidence and belongs with the band's runs, where it survives a reboot and is not mistaken
# for scratch. Same rule as the other probes in this package.
build=${MAPKIT_DELEGATE_BUILD:-$PWD/.agent-work/runs/mapkit-delegate}
mkdir -p "$build"
rm -f "$build"/cc.log "$build"/runner.log "$build"/*.txt "$build"/*.body "$build"/*.dylib "$build"/runner
MACOSX_SDK=$(xcrun --sdk macosx --show-sdk-path)
TARGET="-target arm64-apple-ios17.0-macabi -isysroot $MACOSX_SDK -isystem $MACOSX_SDK/System/iOSSupport/usr/include -F $MACOSX_SDK/System/iOSSupport/System/Library/Frameworks"
xcrun clang -fobjc-arc -Wall -fPIC -dynamiclib $TARGET -DCHARON_HOST_PROBE=1 \
    -DMKMapViewDelegate=charonHost_MKMapViewDelegate \
    -I"$port" -framework Foundation -framework MapKit -framework UIKit -framework CoreLocation \
    "$port/MKMapViewDelegateRenderers.m" -o "$build/libport.dylib" 2> "$build/cc.log" || {
        grep -m5 ': error:' "$build/cc.log" || true; exit 1; }
xcrun clang -fobjc-arc -Wall $TARGET -ldl -framework Foundation -framework MapKit \
    -framework UIKit -framework CoreLocation -framework CoreGraphics "$here/runner.m" -o "$build/runner" 2> "$build/runner.log" || {
        grep -m5 ': error:' "$build/runner.log" || true; exit 1; }
CHARON_PORT_DYLIB="$build/libport.dylib" "$build/runner" > "$build/real.txt" 2>&1 && true
CHARON_PORT_DYLIB="$build/libport.dylib" CHARON_MUTANT=1 "$build/runner" > "$build/mutant.txt" 2>&1 && true
cat "$build/real.txt"; cat "$build/mutant.txt"
body() { grep -E '^  [a-z]' "$1" | grep -v '^  (a subclass|#)'; }
body "$build/real.txt" > "$build/real.body"
body "$build/mutant.txt" > "$build/mutant.body"
cases=$(wc -l < "$build/real.body" | tr -d ' ')
echo "--- the real run made $cases call(s):"
if [ "$cases" -lt 9 ]; then
    echo "FAIL only $cases of the nine messages reached the delegate, so the probe is not covering them"
    exit 1
fi
echo "ok all nine messages reached the recording delegate, one case each"
if diff -q "$build/real.body" "$build/mutant.body" >/dev/null 2>&1; then
    echo "FAIL the mutant does not differ from the real run: this comparison cannot see a wrong"
    echo "     argument, so a green run here would decide nothing"
    exit 1
fi
echo "ok the mutant differs, so the comparison does see the value it is checking"
diff -u "$build/real.body" "$build/mutant.body" | sed -n '1,8p'
exit 0
