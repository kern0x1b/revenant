#!/bin/sh
# The port's channel moves held against the host's own vImage, case by case: the same channels in, the same
# channels out, every byte of every destination row compared including the bytes neither side may write.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=$here/../../../../packages/frameworks/apple-backports/Accelerate
REGISTRY=$here/../../../../packages/frameworks/apple-backports/registry/Accelerate
build=${VIMAGECHANNELS_BUILD:-$(runs_folder revenant-vimagechannels-host)}
rm -rf "$build"
mkdir -p "$build"

# **The port's objects are built with the package's own line** - `-Os -Wall -Wno-unguarded-availability-new
# -Wno-unguarded-availability` - and not with clang's default optimisation. That is not tidiness: these
# functions' buffers are declared `VIMAGE_NON_NULL`, and an attributed parameter is assumed non-null inside
# the function, so at -Os a plain `if (!src)` is folded away and the refusal the release makes is simply not
# in the object. Built this way, every case below runs against the same arithmetic the bands link.
package_cflags="-Os -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability"

# PLANT=<substring> builds one port file from a scratch copy with that line removed, and the run is then
# REQUIRED to fail: a red control for the NULL tests. The copy is made by a script that counts its target
# first, because `str.replace` on a missing needle is a silent no-op and a "planted" run over an unplanted
# file reports a mutant as applied (BRIEF.md, 2026-10-03). Nothing here writes to the tracked sources.
plant=""
if [ -n "${PLANT:-}" ]; then
    mkdir -p "$build/planted"
    for source in vImageChannels7.m vImageChannels8.m vImageChannels16.m; do
        cp "$ACCELERATE/$source" "$build/planted/$source"
    done
    # The shared header goes with them: the planted copy is compiled as its own directory, and without
    # RevenantChannels.h beside it every file fails on a missing include, which is a build failure and not a
    # measurement.
    cp "$ACCELERATE/RevenantChannels.h" "$build/planted/RevenantChannels.h"
    runs_harness plant "$build/planted" "$PLANT"
    ACCELERATE="$build/planted"
fi

# Every API name the objects define is renamed in the port's own translation units, so this one can hold the
# port's answers and the host's side by side. The names come from the port's registry, not from a list kept
# here, so a name added to the library is renamed too.
names=$(runs_xmake l "$here/../registry-functions.lua" "$REGISTRY" ios7channels.json ios8channels.json ios16channels.json)

renames=""
for name in $names; do
    renames="$renames -D$name=revenant_host_$name"
done

objects=""
for source in vImageChannels7.m vImageChannels8.m vImageChannels16.m; do
    # $package_cflags is deliberately unquoted: it is a list of flags, and the count of diagnostics per
    # object is what this prints, because a warning here is a warning the package build would print too.
    diagnostics=$(xcrun clang -c -fobjc-arc $package_cflags $renames -I"$ACCELERATE" \
        "$ACCELERATE/$source" -o "$build/$(basename "$source").o" 2>&1 | grep -v "^$" || true)
    errors=$(printf '%s\n' "$diagnostics" | grep -c " error: " || true)
    warnings=$(printf '%s\n' "$diagnostics" | grep -c " warning: " || true)
    printf '%-22s errors=%s warnings=%s, with the package line\n' "$source" "$errors" "$warnings"
    printf '%s\n' "$diagnostics" | grep " warning: " || true
    objects="$objects $build/$(basename "$source").o"
done

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations \
    "$here/differential.m" $objects \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
if [ -n "${PLANT:-}" ]; then
    # The control, and the shape of the red it takes matters. With the NULL test gone the port dereferences
    # the pointer the refusal used to catch, so the run ends on a signal rather than printing a FAIL line -
    # which is exactly the behaviour the test exists to prevent, and a weaker red than a mismatch would be.
    # What must NOT happen is a clean run, so the check is on the run's own verdict line.
    if [ "$result" = 0 ] || grep -q "checks, 0 failures" "$build/log"; then
        echo "PLANT: the run is green with the NULL test removed, so the control does not hold" >&2
        exit 1
    fi
    if grep -q "^FAIL" "$build/log"; then
        echo "PLANT: the control holds - without the NULL test a case fails:"
        grep -m3 "^FAIL" "$build/log"
    else
        echo "PLANT: the control holds - without the NULL test the run ends on a signal (exit $result),"
        echo "       which is the release's own behaviour on three of these inputs and is what the test stops"
    fi
    exit 0
fi
exit $result
