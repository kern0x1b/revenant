#!/bin/sh
# The host's answer on a failed allocation in CreateSetup, and the port's: probe.m, once against each. The port's
# objects are compiled with the revenant_host_ names (as in vdspdft15/run.sh), so both sit in one process per build.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/frameworks/apple-backports/Accelerate}
build=${VDSPDFTALLOC_BUILD:-$(runs_folder revenant-vdspdft-alloc-host)}
rm -rf "$build"
mkdir -p "$build"

xcrun clang -dynamiclib -fobjc-arc -w "$here/failnth.c" -o "$build/libfailnth.dylib"

# the host's table: probe.m against the host's own functions
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/probe.m" \
    -framework Foundation -framework Accelerate "$build/libfailnth.dylib" -o "$build/probe-host"

# the port: its two objects with the six names renamed, probe.m with REVENANT_PORT
renames=""
for name in $(xmake l "$here/../registry-functions.lua" "$here/../../../../packages/frameworks/apple-backports/registry/Accelerate" ios15dftinterleaved.json); do
    renames="$renames -D$name=revenant_host_$name"
done
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w $renames -I"$ACCELERATE" -c "$ACCELERATE/vDSPDFTInterleaved15.m" -o "$build/port15.o"
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w $renames -I"$ACCELERATE" -c "$ACCELERATE/vDSPDFTInterleavedD15.m" -o "$build/portD15.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -DREVENANT_PORT "$here/probe.m" "$build/port15.o" "$build/portD15.o" \
    -framework Foundation -framework Accelerate "$build/libfailnth.dylib" -o "$build/probe-port"

# the host's probe crashes in Execute only if it executes; it does not, so every line is printed
DYLD_INSERT_LIBRARIES="$build/libfailnth.dylib" "$build/probe-host" > "$build/host.log" 2>&1 || host_result=$?
DYLD_INSERT_LIBRARIES="$build/libfailnth.dylib" "$build/probe-port" > "$build/port.log" 2>&1 && port_result=0 || port_result=$?
cat "$build/host.log"
tail -1 "$build/port.log"
echo "host.log=$build/host.log port.log=$build/port.log"
exit "${port_result:-0}"
