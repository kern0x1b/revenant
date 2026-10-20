#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
CORE=${CORE:-$here/../../../../packages/frameworks/apple-backports/CoreData}
harness=${CONSTRAINT_HARNESS:-$here/../../device}
build=${CONSTRAINT_BUILD:-$(runs_folder revenant-constraint-host)}
sources="NSQueryGenerationToken.m NSManagedObjectContext+QueryGeneration.m NSConstraintConflict.m"
renames="-DNSQueryGenerationToken=RevenantHostNSQueryGenerationToken -D_NSQueryGenerationToken=RevenantHost_NSQueryGenerationToken -DNSConstraintConflict=RevenantHostNSConstraintConflict"
renames="$renames -DqueryGenerationToken=revenantHostqueryGenerationToken -DsetQueryGenerationFromToken=revenantHostsetQueryGenerationFromToken"
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
