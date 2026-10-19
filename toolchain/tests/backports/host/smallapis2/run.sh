#!/bin/sh
# run.sh — records what the system's UIPresentationController does for every case of device/smallapis2-cases.m, in a
# Mac Catalyst application with a window, and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-smallapis2)}
sdk=$(xcrun --show-sdk-path)
app="$build/record.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/../uikit2/windowed.m" "$here/record.m" "$device/smallapis2-cases.m" "$device/check.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/../uikit2/windowed.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
SMALLAPIS2_RECORDS="$build/smallapis2.json" "$app/Contents/MacOS/app" > "$build/smallapis2.log" 2>&1 || true
# The recorder writes the file every run, so a run that cannot answer a case must not be allowed to overwrite what the last good
# run recorded: the three appearance-proxy cases need a layout pass the windowed host gives them only when the run loop has run,
# and a run that starts before the window is ready records "none" or a black colour where the answer is a colour. The check runs
# before the header is written, so a refused run leaves the header as it was. It prints "records: N" when the run answered.
if xmake l "$here/../uikit2/check_records.lua" "$build/smallapis2.json"; then
    xmake l "$here/../../common/embed.lua" "$build/smallapis2.json" "$device/smallapis2-expectations.h" foundation2_expectations
    sed -i.bak 's/foundation2_expectations/smallapis2_expectations/' "$device/smallapis2-expectations.h" && rm -f "$device/smallapis2-expectations.h.bak"
else
    echo "run recorded answers that do not look like answers; $device/smallapis2-expectations.h left as it was"
    exit 1
fi
