#!/bin/sh
# run.sh — records what the system's NSItemProvider does for every case of device/foundation8b-cases.m, under Mac
# Catalyst, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-foundation8b)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/foundation8b-cases.m" -framework Foundation -o "$build/record"
(cd "$build" && ./record "$build/foundation8b.json" > "$build/foundation8b.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/foundation8b.json" "$device/foundation8b-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/foundation8b_expectations/' "$device/foundation8b-expectations.h" && rm -f "$device/foundation8b-expectations.h.bak"
echo "records: $(runs_harness records "$build/foundation8b.json")"
