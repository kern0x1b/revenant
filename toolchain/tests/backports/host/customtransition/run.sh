#!/bin/sh
# run.sh — records what the system's custom transitions do for every case of device/customtransition-cases.m, in a
# Mac Catalyst application with a window, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-customtransition)}
sdk=$(xcrun --show-sdk-path)
app="$build/record.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/customtransition-cases.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/record.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
CUSTOM_RECORDS="$build/customtransition.json" timeout 60 "$app/Contents/MacOS/app" > "$build/customtransition.log" 2>&1 || true
xmake l "$here/../../common/embed.lua" "$build/customtransition.json" "$device/customtransition-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/customtransition_expectations/' "$device/customtransition-expectations.h" && rm -f "$device/customtransition-expectations.h.bak"
echo "records: $(runs_harness records "$build/customtransition.json")"
