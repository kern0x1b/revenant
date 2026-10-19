#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-naturallanguage-record)}
xcrun clang -fobjc-arc -w -I"$device" "$here/record.m" -framework NaturalLanguage -framework Foundation -o "$build/record"
"$build/record" "$device/naturallanguage-expectations.h"
echo "records: $(grep -c '^    "' "$device/naturallanguage-expectations.h")"
