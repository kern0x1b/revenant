#!/bin/sh
# run.sh — records what the system's NSItemProvider does for every case of device/itemprovider-cases.m, under Mac
# Catalyst, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-itemprovider)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/itemprovider-cases.m" -framework UIKit -framework Foundation -o "$build/record"
(cd "$build" && ./record "$build/itemprovider.json" > "$build/itemprovider.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/itemprovider.json" "$device/itemprovider-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/itemprovider_expectations/' "$device/itemprovider-expectations.h" && rm -f "$device/itemprovider-expectations.h.bak"
echo "records: $(runs_harness records "$build/itemprovider.json")"
