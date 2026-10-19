#!/bin/sh
# run.sh — records what the system's NSError does with a user info value provider for every case of device/errorprovider-cases.m
# and writes the answers where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-errorprovider)}
xcrun clang -fobjc-arc -w -I"$device" "$here/record.m" "$device/errorprovider-cases.m" -framework Foundation -o "$build/record"
ERRORPROVIDER_RECORDS="$build/errorprovider.json" "$build/record" > "$build/errorprovider.log"
xmake l "$here/../../common/embed.lua" "$build/errorprovider.json" "$device/errorprovider-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/errorprovider_expectations/' "$device/errorprovider-expectations.h" && rm -f "$device/errorprovider-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/errorprovider.json'))))")"
