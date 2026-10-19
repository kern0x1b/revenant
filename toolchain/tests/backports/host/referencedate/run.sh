#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
harness=${REFERENCEDATE_HARNESS:-$here/../../device}
build=${REFERENCEDATE_BUILD:-$(runs_folder revenant-referencedate-host)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -fvisibility=hidden -w -DNSDateComponentsFormatter=RevenantHostNSDateComponentsFormatter -c "$FOUNDATION/NSDateComponentsFormatter.m" -o "$build/port.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/port.o" \
    -framework Foundation -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
