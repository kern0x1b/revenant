#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
CORE=${CORE:-$here/../../../../packages/a/apple-backports/CoreData}
harness=${HISTORY11_HARNESS:-$here/../../device}
build=${HISTORY11_BUILD:-$(runs_folder charon-history11-host)}
sources="NSPersistentHistoryChangeRequest.m NSPersistentHistoryToken.m NSPersistentHistoryResult.m NSPersistentHistoryTransaction.m NSPersistentHistoryChange.m CoreDataConstants11.m CoreDataConstants12.m NSPersistentStoreCoordinator+HistoryToken.m NSManagedObjectContext+TransactionAuthor.m"
renames=""
for name in NSPersistentHistoryChangeRequest NSPersistentHistoryToken NSPersistentHistoryResult NSPersistentHistoryTransaction NSPersistentHistoryChange \
            NSPersistentHistoryTrackingKey NSBinaryStoreSecureDecodingClasses NSBinaryStoreInsecureDecodingCompatibilityOption \
            NSCoreDataCoreSpotlightExporter NSPersistentHistoryTokenKey NSPersistentStoreRemoteChangeNotification NSPersistentStoreURLKey; do
    renames="$renames -D$name=CharonHost$name"
done
renames="$renames -DcurrentPersistentHistoryTokenFromStores=charonHostcurrentPersistentHistoryTokenFromStores -DtransactionAuthor=charonHosttransactionAuthor -DsetTransactionAuthor=charonHostsetTransactionAuthor"
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
