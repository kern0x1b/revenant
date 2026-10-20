#!/bin/sh
# run.sh — records what the system's the font descriptor keys does for every case of device/fontkeys-cases.m, under Mac
# Catalyst, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-fontkeys)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/fontkeys-cases.m" -framework UIKit -framework Foundation -o "$build/record"
(cd "$build" && ./record "$build/fontkeys.json" > "$build/fontkeys.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/fontkeys.json" "$device/fontkeys-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/fontkeys_expectations/' "$device/fontkeys-expectations.h" && rm -f "$device/fontkeys-expectations.h.bak"
echo "records: $(runs_harness records "$build/fontkeys.json")"
