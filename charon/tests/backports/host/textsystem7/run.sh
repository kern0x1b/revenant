#!/bin/sh
# run.sh — records what the system's NSItemProvider does for every case of device/textsystem7-cases.m, under Mac
# Catalyst, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-textsystem7)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/textsystem7-cases.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$build/record"
(cd "$build" && ./record "$build/textsystem7.json" > "$build/textsystem7.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/textsystem7.json" "$device/textsystem7-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/textsystem7_expectations/' "$device/textsystem7-expectations.h" && rm -f "$device/textsystem7-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/textsystem7.json'))))")"
