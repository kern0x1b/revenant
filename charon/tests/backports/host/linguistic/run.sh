#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
harness=${LINGUISTIC_HARNESS:-$here/../../device}
build=${LINGUISTIC_BUILD:-$(runs_folder charon-linguistic-host)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -fvisibility=hidden -w -DNSLinguisticTagger=CharonHostNSLinguisticTagger -I"$FOUNDATION" -c "$FOUNDATION/NSLinguisticTagger+Units.m" -o "$build/units.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/units.o" \
    -framework Foundation -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
