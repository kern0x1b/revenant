#!/bin/sh
# settings/run.sh - the port's own settings answers, asked of the port's own objects.
#
# The host is not called, and the reason is in check.m's own header: the five settings values read a
# user's preference, AXOpenSettingsFeature opens a window on somebody's screen, and the three hearing
# functions enumerate the signed-in user's accessories. Nothing here is compared with the system, because
# nothing here has a system answer to be compared with; each answer is a reading of the release, measured
# by axs-census.lua, or of the header, and the readings are named next to the assertions.
#
# The control is the program: it asserts that a name which is not the port's is not one of its constants,
# that the port's error domain is not a system domain, and that nothing the library announces is posted.
#
# Usage: sh tests/backports/settings/run.sh
#        ACCESSIBILITY_SRC=<dir>   build another copy of the port's sources (mutants.sh)
#        BUILD=<dir>               where the program and its output go
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common/runs.sh" "$here"
root=$(cd "$here/../../.." && pwd)
sources=${ACCESSIBILITY_SRC:-$root/packages/a/apple-backports/Accessibility}
build=${BUILD:-$(runs_folder charon-accessibility-settings)}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-macos26.0 -isysroot "$sdk" -fobjc-arc -O0 -Wall -Wno-nonnull \
    "$here/check.m" \
    "$sources/CharonAXSettings17.m" "$sources/CharonAXSettings18.m" "$sources/CharonAXSettings26.m" \
    -I"$sources" -framework Foundation -framework Accessibility -o "$build/check" 2> "$build/build.log" || {
        echo "the settings check did not build" >&2
        tail -20 "$build/build.log" >&2
        exit 1
    }
"$build/check"

# The three hearing rows, compiled for the port's own target because their declarations are
# API_UNAVAILABLE(macos): the compiler holds their signatures against the SDK's, and nm over the object
# holds that the port defines them. They are not RUN here - there is no iOS runtime on this machine - and
# the owed line for that is in facts/Accessibility/Accessibility.md.
ios_sdk=$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
xcrun clang -target armv7-apple-ios6.0 -isysroot "$ios_sdk" -fobjc-arc -O0 -Wall -Wno-nonnull \
    -Wno-unguarded-availability -Wno-unguarded-availability-new \
    -I"$sources" -c "$here/hearing-check.m" -o "$build/hearing-check.o" 2> "$build/hearing.log" || {
        echo "the hearing check did not compile" >&2
        tail -20 "$build/hearing.log" >&2
        exit 1
    }
# What is held for the three hearing rows, and it is less than the other twenty: the compiler held
# their signatures against the SDK's, and nm holds that the port defines them at 15.0. They are NOT run,
# because their declarations are API_UNAVAILABLE(macos) and this machine has no iOS runtime, so the
# answers are readings of the census and not answers a program produced. The owed line and the command
# that settles it are in facts/Accessibility/Accessibility.md.
ios_flags="-target armv7-apple-ios6.0 -isysroot $ios_sdk -fobjc-arc -Os -g0 -Wall -Wno-nonnull"
# shellcheck disable=SC2086
xcrun clang $ios_flags -Wno-unguarded-availability -Wno-unguarded-availability-new \
    -I"$sources" -c "$sources/CharonHearing15.m" -o "$build/CharonHearing15.o" 2> "$build/hearing-obj.log" || {
        echo "the hearing object did not compile" >&2
        tail -20 "$build/hearing-obj.log" >&2
        exit 1
    }
echo "hearing: compiled for armv7-apple-ios6.0, and the port defines:"
defined=$(nm -gU "$build/CharonHearing15.o" | awk '{ print $NF }' | grep -E '^_AX(MFiHearingDevice|SupportsBidirectional)' | sort)
echo "$defined" | sed 's/^_/  /'
missing=0
for symbol in _AXMFiHearingDevicePairedUUIDs _AXMFiHearingDeviceStreamingEar \
               _AXSupportsBidirectionalAXMFiHearingDeviceStreaming; do
    if ! echo "$defined" | grep -qx "$symbol"; then
        echo "check	the port defines ${symbol#_}	FAILED	not defined in the object"
        missing=$((missing + 1))
    fi
done
[ "$missing" -eq 0 ] || { echo "hearing: $missing of the three functions the port must define are not there"; exit 1; }
# What the OWED line is held by, named on the run itself rather than only in the facts and the README:
# the compile of hearing-check.m against the SDK's declarations, the nm assertion above, and the census.
echo "hearing: OWED - not run here, because the declarations are API_UNAVAILABLE(macos) and this machine has no iOS runtime"
echo "hearing: held by the compile above, by the nm assertion above, and by axs-census.lua; the command that would settle it is in this directory's README.md"
