#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
CORE=${CORE:-$here/../../../../packages/a/apple-backports/CoreData}
harness=${BATCHUPDATE_HARNESS:-$here/../../device}
build=${BATCHUPDATE_BUILD:-$(runs_folder charon-batchupdate-host)}
sources="NSPersistentStoreResult.m NSBatchUpdateRequest.m NSAsynchronousFetchRequest.m NSBatchDeleteRequest.m NSBatchDeleteRequest+ObjectIDs.m NSBatchDeleteResult.m NSManagedObjectContext+ExecuteRequest.m"
renames=""
for name in NSPersistentStoreResult NSPersistentStoreAsynchronousResult NSAsynchronousFetchResult NSAsynchronousFetchRequest NSBatchUpdateRequest NSBatchUpdateResult NSBatchDeleteRequest NSBatchDeleteResult; do
    renames="$renames -D$name=CharonHost$name"
done
renames="$renames -DexecuteRequest=charonHostexecuteRequest -DinitWithObjectIDs=charonHostinitWithObjectIDs"
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
