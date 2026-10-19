#!/bin/sh
# run.sh — records what the system's UIPreviewAction does for every case of device/previewaction-cases.m, under Mac
# Catalyst, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-previewaction)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/previewaction-cases.m" -framework UIKit -framework Foundation -o "$build/record"
(cd "$build" && ./record "$build/previewaction.json" > "$build/previewaction.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/previewaction.json" "$device/previewaction-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/previewaction_expectations/' "$device/previewaction-expectations.h" && rm -f "$device/previewaction-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/previewaction.json'))))")"
