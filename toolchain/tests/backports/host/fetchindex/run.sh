#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
CORE=${CORE:-$here/../../../../packages/a/apple-backports/CoreData}
harness=${FETCHINDEX_HARNESS:-$here/../../device}
build=${FETCHINDEX_BUILD:-$(runs_folder charon-fetchindex-host)}
sources="NSFetchIndexElementDescription.m NSFetchIndexDescription.m NSEntityDescription+Indexes.m"
renames="-DNSFetchIndexElementDescription=CharonHostNSFetchIndexElementDescription -DNSFetchIndexDescription=CharonHostNSFetchIndexDescription"
renames="$renames -Dindexes=charonHostindexes -DsetIndexes=charonHostsetIndexes -DcoreSpotlightDisplayNameExpression=charonHostcoreSpotlightDisplayNameExpression -DsetCoreSpotlightDisplayNameExpression=charonHostsetCoreSpotlightDisplayNameExpression"
rm -rf "$build"
mkdir -p "$build"
objects=""
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -I"$CORE" -c "$CORE/$source" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework CoreData -framework Foundation -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
