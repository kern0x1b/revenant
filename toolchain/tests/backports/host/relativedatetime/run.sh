#!/bin/sh
# run.sh — records what the system's NSRelativeDateTimeFormatter answers for every case of device/relativedatetime-cases.h,
# under Mac Catalyst, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-relativedatetime)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" -framework UIKit -framework Foundation -o "$build/record"
"$build/record" "$device/relativedatetime-expectations.h"
echo "records: $(grep -c '^    "' "$device/relativedatetime-expectations.h")"
