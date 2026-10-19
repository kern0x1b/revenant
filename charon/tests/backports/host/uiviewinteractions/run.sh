#!/bin/sh
# run.sh — records what the system's own UIKit answers for every case of device/uiviewinteractions-cases.m,
# under Mac Catalyst, and writes the answers where the device test reads them. The reordering inside a live
# collection view is checked on the device, in device/collectiontransition.m.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-uiviewinteractions)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/uiviewinteractions-cases.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$build/record"
(cd "$build" && ./record "$build/uiviewinteractions.json" > "$build/uiviewinteractions.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/uiviewinteractions.json" "$device/uiviewinteractions-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/uiviewinteractions_expectations/' "$device/uiviewinteractions-expectations.h" && rm -f "$device/uiviewinteractions-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/uiviewinteractions.json'))))")"
