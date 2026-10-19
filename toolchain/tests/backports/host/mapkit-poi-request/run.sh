#!/bin/sh
# The points-of-interest request's own numbers, compared against the HOST's own
# MKLocalPointsOfInterestRequest: the four members' values, for the same circles and the same regions,
# plus the copy the header's own NSCopying promises.
#
# The port's object is built here as a macOS dylib with its class RENAMED, because the class name is
# Apple's and two classes of one name cannot both be live: the rename is the only way both can answer
# the same circle in one probe. Apple's own is reached through the unrenamed name.
#
# THE MUTANT is the same dylib with no recompile -- the runner allocates a subclass at run time whose
# -radius answers the region's diagonal instead of its larger half-span, which is the reading this
# port's first version used -- so a run in which the mutant does not go red means the comparison cannot
# see a wrong number, and this probe fails.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/MapKit}
build=${MAPKIT_POI_BUILD:-$(runs_folder charon-mapkit-poi-request)}
rm -rf "$build"
mkdir -p "$build"
# CATALYST, because the port's own request imports MapKit, whose headers reach UIKit, and macOS has no
# UIKit outside a Catalyst build. MapKit on a Catalyst build is Apple's own MapKit, so the oracle is
# still Apple's framework.
MACOSX_SDK=$(xcrun --sdk macosx --show-sdk-path)
TARGET="-target arm64-apple-ios17.0-macabi -isysroot $MACOSX_SDK -isystem $MACOSX_SDK/System/iOSSupport/usr/include -F $MACOSX_SDK/System/iOSSupport/System/Library/Frameworks"
# CHARON_HOST_PROBE: the host's own MapKit declares the class the port also declares.
# AND ONLY THE REQUEST is renamed: MKPointOfInterestFilter is the host's own class and CharonMapKit is
# this port's own, so neither collides. CharonMapKit.m is in the build because the port's own
# charon_sayOnce lives there, which the request's initialisers and its filter call.
xcrun clang -fobjc-arc -Wall -Wno-unguarded-availability-new -fPIC -dynamiclib $TARGET -DCHARON_HOST_PROBE=1 \
    -DMKLocalPointsOfInterestRequest=charonHost_MKLocalPointsOfInterestRequest \
    -I"$port" -framework Foundation -framework MapKit -framework CoreLocation -framework UIKit \
    "$port/MKLocalPointsOfInterestRequest14.m" "$port/CharonMapKit.m" -o "$build/libport.dylib" 2> "$build/cc.log" \
    || { grep -m5 ': error:' "$build/cc.log" || true; exit 1; }
xcrun clang -fobjc-arc -Wall -Wno-unguarded-availability-new $TARGET -framework Foundation -framework MapKit \
    -framework CoreLocation "$here/runner.m" -o "$build/runner" 2> "$build/runner.log" \
    || { grep -m5 ': error:' "$build/runner.log" || true; exit 1; }

CHARON_PORT_DYLIB="$build/libport.dylib" "$build/runner" > "$build/port.txt" 2>&1 && status=0 || status=$?
# The MUTANT run is EXPECTED to exit non-zero -- the mutant is what makes the comparison fail -- so its
# status is read and reported rather than swallowed, and what the probe judges is its TRANSCRIPT.
if CHARON_PORT_DYLIB="$build/libport.dylib" CHARON_MUTANT=1 "$build/runner" > "$build/mutant.txt" 2>&1; then
    mutant_status=0
else
    mutant_status=$?
fi

if [ "$status" -ne 0 ]; then
    echo "mapkit-poi-request: FAILED, the port's request does not answer the host's own values:"
    grep -E 'MISMATCH|VERDICT' "$build/port.txt" || cat "$build/port.txt"
    exit 1
fi
echo "mapkit-poi-request: $(grep -c '^compare .* ok' "$build/port.txt") comparisons agree with the host's own class," \
     "radius apart by at most $(awk '/^compare .* ok/ { value = $(NF - 1); gsub(/%/, "", value); if (value + 0 > worst) worst = value + 0 } END { printf "%.3f", worst }' "$build/port.txt")%"

if grep -q 'MISMATCH' "$build/mutant.txt"; then
    echo "mapkit-poi-request: the mutant goes red (exit $mutant_status), so the comparison above can see a wrong number"
else
    echo "mapkit-poi-request: FAILED, the mutant answered the host's own values, so this comparison cannot see a wrong number"
    exit 1
fi
