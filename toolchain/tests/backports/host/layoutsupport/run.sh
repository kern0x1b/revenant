#!/bin/sh
# run.sh — records what the system's UIPresentationController does for every case of device/layoutsupport-cases.m, in a
# Mac Catalyst application with a window, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-layoutsupport)}
sdk=$(xcrun --show-sdk-path)
app="$build/record.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/../uikit2/windowed.m" "$here/record.m" "$device/layoutsupport-cases.m" "$device/check.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/../uikit2/windowed.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
LAYOUTSUPPORT_RECORDS="$build/layoutsupport.json" "$app/Contents/MacOS/app" > "$build/layoutsupport.log" 2>&1 || true
xmake l "$here/../../common/embed.lua" "$build/layoutsupport.json" "$device/layoutsupport-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/layoutsupport_expectations/' "$device/layoutsupport-expectations.h" && rm -f "$device/layoutsupport-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/layoutsupport.json'))))")"
