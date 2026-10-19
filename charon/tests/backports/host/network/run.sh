#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
harness=${NETWORK_HARNESS:-$here/../../device}
build=${NETWORK_BUILD:-$(runs_folder charon-network-host)}
rm -rf "$build"
mkdir -p "$build"
renames="-DCharonNWInterface=CharonHostNWInterface -DCharonNWPath=CharonHostNWPath -DCharonNWPathMonitor=CharonHostNWPathMonitor"
for name in $(grep -oE '^[A-Za-z0-9_ *]+[ *]nw_[a-z0-9_]+\(' "$FOUNDATION/NWPathMonitor.m" | sed 's/.*[ *]\(nw_[a-z0-9_]*\)(/\1/' | sort -u); do
    renames="$renames -D$name=charonhost_$name"
done
xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$FOUNDATION/NWPathMonitor.m" -o "$build/port.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/port.o" \
    -framework Network -framework SystemConfiguration -framework Foundation -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" | head -40 || true
echo "log=$build/log"
exit $result
