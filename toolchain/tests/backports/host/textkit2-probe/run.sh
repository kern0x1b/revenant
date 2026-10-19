#!/bin/sh
# run.sh: a host-only measurement of the TextKit 2 members the port has not built (NSTextLayoutManager and its fragments, the viewport
# controller, the text view's manager, and the two delegate callbacks of the content storage and the layout manager). The host's own UIKit under
# Mac Catalyst runs in a bundled app with a window and the iPad idiom, and prints one "check<TAB>value" line per answer. There is no port side:
# the answers are the reasons the rows in the registry stay owed (facts/UIKit/TextLayoutManager16.md), not a differential.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${TEXTKIT2_PROBE_BUILD:-$(runs_fresh revenant-textkit2-probe)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w"
bundle="$build/RevenantTK2.app"
mkdir -p "$bundle/Contents/MacOS"
cp "$here/app/Info.plist" "$bundle/Contents/Info.plist"
xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/RevenantTK2"
codesign -s - --force --deep "$bundle" > /dev/null 2>&1
REVENANT_SCENE_OUT="$build/host.txt" timeout 120 "$bundle/Contents/MacOS/RevenantTK2" > "$build/host.log" 2>&1 || true
if [ ! -s "$build/host.txt" ]; then
    echo "FAIL textkit2-probe: the app wrote nothing (see $build/host.log)"
    exit 1
fi
cat "$build/host.txt"
