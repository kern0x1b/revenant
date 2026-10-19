#!/bin/sh
# run.sh — records what the system's NSOrderedCollectionDifference answers for every case of device/orderedcollections-cases.h
# and writes the fingerprints where the device test reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-orderedcollections)}
xcrun clang -fobjc-arc -w -I"$device" "$here/record.m" -framework Foundation -o "$build/record"
"$build/record" "$device/orderedcollections-expectations.h"
echo "records: $(grep -c '^    0x' "$device/orderedcollections-expectations.h")"
