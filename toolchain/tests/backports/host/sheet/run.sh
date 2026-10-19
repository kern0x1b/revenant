#!/bin/sh
# run.sh - records what the host's own UISheetPresentationController and its detents answer for every case of
# device/sheet-cases.m's sheet_api_run, under Mac Catalyst, and writes the answers where the device test reads them.
# The layout cases are not recorded: the host shows a sheet in a window of its own.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-sheet)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios16.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/sheet-cases.m" -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -o "$build/record"
SHEET_RECORDS="$build/sheet.json" "$build/record" > "$build/sheet.log"
xmake l "$here/../../common/embed.lua" "$build/sheet.json" "$device/sheet-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/sheet_expectations/' "$device/sheet-expectations.h" && rm -f "$device/sheet-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/sheet.json'))))")"
