#!/bin/sh
# run.sh — records what the system's NSItemProvider does for every case of device/exclusion-cases.m, under Mac
# Catalyst, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-exclusion)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/exclusion-cases.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$build/record"
(cd "$build" && ./record "$build/exclusion.json" > "$build/exclusion.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/exclusion.json" "$device/exclusion-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/exclusion_expectations/' "$device/exclusion-expectations.h" && rm -f "$device/exclusion-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/exclusion.json'))))")"
