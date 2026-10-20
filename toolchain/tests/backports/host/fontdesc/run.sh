#!/bin/sh
# run.sh — records what the system's UIPresentationController does for every case of device/fontdesc-cases.m, in a
# Mac Catalyst application with a window, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-fontdesc)}
sdk=$(xcrun --show-sdk-path)
app="$build/record.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/../uikit2/windowed.m" "$here/record.m" "$device/fontdesc-cases.m" "$device/check.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/../uikit2/windowed.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
FONTDESC_RECORDS="$build/fontdesc.json" "$app/Contents/MacOS/app" > "$build/fontdesc.log" 2>&1 || true
xmake l "$here/../../common/embed.lua" "$build/fontdesc.json" "$device/fontdesc-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/fontdesc_expectations/' "$device/fontdesc-expectations.h" && rm -f "$device/fontdesc-expectations.h.bak"
echo "records: $(runs_harness records "$build/fontdesc.json")"
