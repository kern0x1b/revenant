#!/bin/sh
# The port's biquad and DFT objects held against the host's own vDSP, case by case: the same inputs through
# each, comparing every element either of them wrote.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
build=${VDSPVSMSMA_BUILD:-$(runs_folder revenant-vdspvsmsma-host)}

# SAN=1 builds and links the renamed port objects and the differential under AddressSanitizer, through
# this script's own flags, so the objects are made exactly the way the plain run makes them. An
# ad-hoc command that renames differently builds different objects and says nothing.
san=""
if [ "${SAN:-}" = 1 ]; then san="-fsanitize=address -fno-omit-frame-pointer"; fi

# FPC=off adds -ffp-contract=off to BOTH the objects and the differential, so the two sides of the comparison
# are built the same way and a contraction in one of them cannot masquerade as a difference in the arithmetic.
fpcontract=""
if [ "${FPC:-}" = off ]; then fpcontract="-ffp-contract=off"; fi
rm -rf "$build"
mkdir -p "$build"

# Every API name the object files define is renamed in the port's own translation units, so this one can
# hold the port's answers and the host's side by side. The names come from the port's registry, not from a
# list kept here, so a name added to any of the files is renamed too.
renames=""
for name in $(xmake l "$here/../registry-functions.lua" "$here/../../../../packages/a/apple-backports/registry/Accelerate" ios6vectorops.json); do
    renames="$renames -D$name=revenant_host_$name"
done

objects=""
# vDSPBiquad6.m and the four multi-section objects it delegates into: the six rows are one-line calls into
# the shared helpers, so the objects have to be linked together for the delegation to mean anything.
for source in vDSPVectorOps6.m; do
    xcrun clang -fobjc-arc -w $san $fpcontract $renames -I"$ACCELERATE" -c "$ACCELERATE/$source" -o "$build/$(basename "$source").o"
    objects="$objects $build/$(basename "$source").o"
done

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations $san $fpcontract \
    "$here/differential.m" $objects \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
