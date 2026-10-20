#!/bin/sh
# The port's biquad and DFT objects held against the host's own vDSP, case by case: the same inputs through
# each, comparing every element either of them wrote.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
build=${VDSPBIQUAD_BUILD:-$(runs_folder revenant-vdspbiquad-host)}
rm -rf "$build"
mkdir -p "$build"

# Every API name the object files define is renamed in the port's own translation units, so this one can
# hold the port's answers and the host's side by side. The names come from the port's registry, not from a
# list kept here, so a name added to any of the files is renamed too.
renames=""
for name in $(runs_xmake l "$here/../registry-functions.lua" "$here/../../../../packages/a/apple-backports/registry/Accelerate" ios7biquad.json ios8biquad.json ios9biquad.json ios16biquad.json ios7dft.json); do
    renames="$renames -D$name=revenant_host_$name"
done

objects=""
for source in vDSPBiquadm7.m vDSPBiquadm8.m vDSPBiquadm9.m vDSPBiquadm16.m vDSPDFT7.m; do
    xcrun clang -fobjc-arc -w $renames -I"$ACCELERATE" -c "$ACCELERATE/$source" -o "$build/$(basename "$source").o"
    objects="$objects $build/$(basename "$source").o"
done

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations \
    "$here/differential.m" $objects \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
