#!/bin/sh
# run.sh - the port's seven CFNetwork names (renamed revenantHost_*) against the host's own CFNetwork,
# which exports every one of them: the texts this port carries must be the texts the system has.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/CFNetwork}
harness=${CFNETWORKNAMES_HARNESS:-$here/../../device}
build=${CFNETWORKNAMES_BUILD:-$(runs_fresh revenant-cfnetworknames)}
rm -rf "$build"
mkdir -p "$build"
renames=""
for name in kCFHTTPVersion2_0 kCFHTTPVersion3_0 kCFStreamNetworkServiceTypeCallSignaling \
            kCFStreamPropertyAllowConstrainedNetworkAccess kCFStreamPropertyAllowExpensiveNetworkAccess \
            kCFStreamPropertyConnectionIsExpensive kCFStreamPropertySocketExtendedBackgroundIdleMode; do
    renames="$renames -D$name=revenantHost_$name"
done
# shellcheck disable=SC2086
for source in CFNetworkNames9 CFNetworkNames10 CFNetworkNames134 CFNetworkNames160; do
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$port/$source.m" -o "$build/$source.o"
done
xcrun clang -fobjc-arc -Wall -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build"/CFNetworkNames*.o \
    -framework Foundation -o "$build/differential"
"$build/differential"
