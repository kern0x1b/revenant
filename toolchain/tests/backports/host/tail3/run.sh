#!/bin/sh
# run.sh — records what the system's UIPresentationController does for every case of device/tail3-cases.m, in a
# Mac Catalyst application with a window, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-tail3)}
sdk=$(xcrun --show-sdk-path)
app="$build/record.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/../uikit2/windowed.m" "$here/record.m" "$device/tail3-cases.m" "$device/check.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/../uikit2/windowed.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
TAIL3_RECORDS="$build/tail3.json" "$app/Contents/MacOS/app" > "$build/tail3.log" 2>&1 || true
xmake l "$here/../../common/embed.lua" "$build/tail3.json" "$device/tail3-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/tail3_expectations/' "$device/tail3-expectations.h" && rm -f "$device/tail3-expectations.h.bak"
echo "records: $(runs_harness records "$build/tail3.json")"
