#!/bin/sh
# run.sh — records what the system's Foundation answers for every case of device/foundation14-cases.h, under Mac Catalyst
# with the region of the host's own locale set to en_US, and writes the answers, and the streams and archives the host
# made for the device to read, where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-foundation14)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" -framework Foundation -o "$build/record"
"$build/record" "$device/foundation14-expectations.h" -AppleLocale en_US -AppleLanguages "(en)"
echo "records: $(grep -c '^    "' "$device/foundation14-expectations.h")"
