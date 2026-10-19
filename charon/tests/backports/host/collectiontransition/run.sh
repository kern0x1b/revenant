#!/bin/sh
# run.sh — records what the system's own UIKit answers for every case of device/collectiontransition-cases.m,
# under Mac Catalyst, and writes the answers where the device test reads them. The driven transition
# needs a live collection view in a window and is checked on the device, in device/collectiontransition.m.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-collectiontransition)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/collectiontransition-cases.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$build/record"
(cd "$build" && ./record "$build/collectiontransition.json" > "$build/collectiontransition.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/collectiontransition.json" "$device/collectiontransition-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/collectiontransition_expectations/' "$device/collectiontransition-expectations.h" && rm -f "$device/collectiontransition-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/collectiontransition.json'))))")"
