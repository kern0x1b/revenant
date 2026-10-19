#!/bin/sh
# run.sh — differential host test for the persistent store description. The backported source is compiled
# with its class renamed, so the backport and the system's Core Data answer side by side in one process.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
CORE=${CORE:-$here/../../../../packages/a/apple-backports/CoreData}
BUILD=${BUILD:-$(runs_fresh revenant-coredata)}
rename="-DNSPersistentStoreDescription=RevenantHostNSPersistentStoreDescription"
xcrun clang -fobjc-arc -fvisibility=hidden -w $rename -I"$CORE" -c "$CORE/NSPersistentStoreDescription.m" -o "$BUILD/description.o"
xcrun clang -fobjc-arc -w -I"$CORE" "$here/differential.m" "$BUILD/description.o" -framework CoreData -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
