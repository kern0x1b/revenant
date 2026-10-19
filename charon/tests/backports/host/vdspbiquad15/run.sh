#!/bin/sh
# The port's vDSPBiquad15.m held against the host's own vDSP, case by case: the same inputs through each,
# comparing every element either of them wrote.
#
# **No setup crosses between the two sides.** vDSP.h declares the single-section setup with no published
# layout, so each side builds its own with its own vDSP_biquad_CreateSetup and reads the change back
# through its own vDSP_biquad. The port's objects are compiled with the names renamed, which is what lets
# both libraries be in one process at all.
#
# SAN=1 builds and links the renamed port objects and the differential under AddressSanitizer, through this
# script's own flags, so the objects are made exactly the way the plain run makes them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
build=${VDSPBIQUAD15_BUILD:-$here/../../../../.agent-work/runs/vdspbiquad15-host}

san=""
if [ "${SAN:-}" = 1 ]; then san="-fsanitize=address -fno-omit-frame-pointer"; fi
rm -rf "$build"
mkdir -p "$build"

# Every API name the port's objects define is renamed in the port's own translation units, so this one can
# hold the port's answers and the host's side by side. The names come from the port's registry, not from a
# list kept here, so a name added to any of the files is renamed too.
renames=""
for name in $(python3 - "$here" <<'PY'
import json, os, sys
registry = os.path.join(sys.argv[1], "..", "..", "..", "..", "packages", "a", "apple-backports", "registry", "Accelerate")
for part in ("ios6biquad.json", "ios15biquad.json"):
    path = os.path.join(registry, part)
    if not os.path.exists(path):
        continue
    for entry in json.load(open(path))["entries"]:
        if entry["kind"] == "function":
            print(entry["api"].rstrip("()"))
PY
); do
    renames="$renames -D$name=charon_host_$name"
done

objects=""
# vDSPBiquad6.m and the 15.0 object: the 15.0 file holds two functions that take the setup vDSPBiquad6.m
# allocates, so the two have to be linked together for the case to mean anything.
for source in vDSPBiquad6.m vDSPBiquad15.m; do
    xcrun clang -fobjc-arc -w $san $renames -I"$ACCELERATE" -c "$ACCELERATE/$source" -o "$build/$(basename "$source").o"
    objects="$objects $build/$(basename "$source").o"
done

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations $san \
    "$here/differential.m" $objects \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
