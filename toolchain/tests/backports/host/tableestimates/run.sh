#!/bin/sh
# run.sh — records what the system's NSItemProvider does for every case of device/tableestimates-cases.m, under Mac
# Catalyst, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-tableestimates)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/tableestimates-cases.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$build/record"
(cd "$build" && ./record "$build/tableestimates.json" > "$build/tableestimates.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/tableestimates.json" "$device/tableestimates-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/tableestimates_expectations/' "$device/tableestimates-expectations.h" && rm -f "$device/tableestimates-expectations.h.bak"
echo "records: $(runs_harness records "$build/tableestimates.json")"
