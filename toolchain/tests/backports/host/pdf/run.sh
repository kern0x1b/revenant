#!/bin/sh
# run.sh — differential host test for the PDF renderer. The backported sources are compiled for
# Mac Catalyst with their classes renamed, so the backport and the system renderer stand side by
# side in one process: both draw the same document, and what each produced is compared page by
# page - the page count, each page's media box, and the pixels of each page rasterised at a known
# scale. The bytes of the two files are never compared: a PDF carries a creation date and an
# identifier, so two documents that say the same thing never match byte for byte.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh charon-pdf)}
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
    -framework UIKit -framework CoreGraphics -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"