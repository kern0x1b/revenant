#!/bin/sh
# run.sh — records what the system's UIPresentationController does for every case of device/presentation-cases.m, in a
# Mac Catalyst application with a window, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-presentation)}
sdk=$(xcrun --show-sdk-path)
app="$build/record.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/../uikit2/windowed.m" "$here/record.m" "$device/presentation-cases.m" "$device/check.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/../uikit2/windowed.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
PRESENTATION_RECORDS="$build/presentation.json" "$app/Contents/MacOS/app" > "$build/presentation.log" 2>&1 || true
xmake l "$here/../../common/embed.lua" "$build/presentation.json" "$device/presentation-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/presentation_expectations/' "$device/presentation-expectations.h" && rm -f "$device/presentation-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/presentation.json'))))")"
