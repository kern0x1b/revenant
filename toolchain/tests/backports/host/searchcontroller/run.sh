#!/bin/sh
# run.sh — records what the system's UISearchController does for every case of device/searchcontroller-cases.m, in an
# application under Mac Catalyst, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-searchcontroller)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
bundle="$build/record.app"
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS"
xcrun clang $target -fobjc-arc -w -I"$device" "$here/record.m" "$device/searchcontroller-cases.m" -framework UIKit -framework Foundation -o "$bundle/Contents/MacOS/app"
cp "$here/record.plist" "$bundle/Contents/Info.plist"
codesign -s - --force "$bundle" > /dev/null 2>&1
"$bundle/Contents/MacOS/app" "$build/searchcontroller.json" > "$build/searchcontroller.log" 2>&1
xmake l "$here/../../common/embed.lua" "$build/searchcontroller.json" "$device/searchcontroller-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/searchcontroller_expectations/' "$device/searchcontroller-expectations.h" && rm -f "$device/searchcontroller-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/searchcontroller.json'))))")"
