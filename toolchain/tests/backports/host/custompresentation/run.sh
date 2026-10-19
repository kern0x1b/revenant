#!/bin/sh
# run.sh — records what the system's a custom presentation controller do for every case of device/custompresentation-cases.m, in a
# Mac Catalyst application with a window, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-custompresentation)}
sdk=$(xcrun --show-sdk-path)
app="$build/record.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/custompresentation-cases.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/record.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
CUSTOMPRES_RECORDS="$build/custompresentation.json" timeout 60 "$app/Contents/MacOS/app" > "$build/custompresentation.log" 2>&1 || true
xmake l "$here/../../common/embed.lua" "$build/custompresentation.json" "$device/custompresentation-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/custompresentation_expectations/' "$device/custompresentation-expectations.h" && rm -f "$device/custompresentation-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/custompresentation.json'))))")"
