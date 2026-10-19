#!/bin/sh
# The port's single-precision vDSP_DFT_Interleaved family held against the host's own vDSP, by differential.m: which
# lengths each side accepts over 1 to 1024, and the transform's values against a double-precision reference under the
# bound the facts file states. The port's object is compiled with its six function names renamed to revenant_host_*
# (the names come from the registry), so the port and the host sit in one binary.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
build=${VDSPDFT_BUILD:-$(runs_folder revenant-vdspdft15-host)}
rm -rf "$build"
mkdir -p "$build"

renames=""
for name in $(xmake l "$here/../registry-functions.lua" "$here/../../../../packages/a/apple-backports/registry/Accelerate" ios15dftinterleaved.json); do
    renames="$renames -D$name=revenant_host_$name"
done

# The single-precision object only: the double-precision family is not held to a bound yet (its row stays owed).
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w $renames -I"$ACCELERATE" -c "$ACCELERATE/vDSPDFTInterleaved15.m" -o "$build/vDSPDFTInterleaved15.o"

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations \
    "$here/differential.m" "$build/vDSPDFTInterleaved15.o" \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
