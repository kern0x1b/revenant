#!/bin/sh
# run.sh — records what the system's own UIKit answers for every case of device/uikitadditions-cases.m,
# under Mac Catalyst, and writes the answers where the device test reads them. The reordering inside a live
# collection view is checked on the device, in device/collectiontransition.m.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-uikitadditions)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/uikitadditions-cases.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$build/record"
(cd "$build" && ./record "$build/uikitadditions.json" > "$build/uikitadditions.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/uikitadditions.json" "$device/uikitadditions-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/uikitadditions_expectations/' "$device/uikitadditions-expectations.h" && rm -f "$device/uikitadditions-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/uikitadditions.json'))))")"
