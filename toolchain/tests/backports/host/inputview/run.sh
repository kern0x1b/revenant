#!/bin/sh
# run.sh — records what the system's UIInputView does for every case of device/inputview-cases.m, in a
# Mac Catalyst application with a window, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-inputview)}
sdk=$(xcrun --show-sdk-path)
app="$build/record.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/../uikit2/windowed.m" "$here/record.m" "$device/inputview-cases.m" "$device/check.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/../uikit2/windowed.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
INPUTVIEW_RECORDS="$build/inputview.json" "$app/Contents/MacOS/app" > "$build/inputview.log" 2>&1 || true
xmake l "$here/../../common/embed.lua" "$build/inputview.json" "$device/inputview-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/inputview_expectations/' "$device/inputview-expectations.h" && rm -f "$device/inputview-expectations.h.bak"
echo "records: $(runs_harness records "$build/inputview.json")"
