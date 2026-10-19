#!/bin/sh
# run.sh — differential host test for the notification values. The backported sources are compiled for
# Mac Catalyst with their classes renamed, so the backport and the system UserNotifications stand side
# by side in one process and are asked the same questions.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh charon-usernotifications)}
sources=${SOURCES:-$(cat "$here/sources.txt")}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-property-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers"
rm -rf "$BUILD/plain" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet -I"$UIKIT" -c "$UIKIT/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
echo "renamed:$renames"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$UIKIT" -c "$UIKIT/$source" -o "$BUILD/renamed/$source.o"
done
xcrun clang $target -fobjc-arc $quiet -I"$UIKIT" "$here/differential.m" "$BUILD"/renamed/*.o \
    -framework UserNotifications -framework UIKit -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
# The expectations file is TRACKED, and the device-side usernotifications.m compiles against it, so
# the redirect used to write into it directly: the shell truncates the target before the binary has
# produced a byte, and anything that ends this line early - the sweep's own 120 s kill, a signal, a
# failed build above - leaves the tree with a truncated expectations file. Measured: after a full
# host sweep the file was 610 rows short of HEAD, and a completed run regenerates the same 5760 rows,
# so nothing about the content was in question and everything about the exposure was.
#
# So it is written beside the tree and moved into place only once the run that produced it has ended
# with status 0. A failure leaves the tracked file exactly as it was, which is the only outcome that
# can be right: a half-written expectations header is a tree that no longer says what it said.
expectations=$here/../../device/usernotifications-expectations.h
staged=$BUILD/usernotifications-expectations.h
"$BUILD/differential" --expectations > "$staged"
mv "$staged" "$expectations"
