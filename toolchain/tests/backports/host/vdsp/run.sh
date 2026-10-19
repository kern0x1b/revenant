#!/bin/sh
# The port's vDSPFixed7.m, vDSPElementwise8.m and RevenantVDSPKernel.c held against the host's own vDSP, case
# by case: the same inputs through each, comparing every element either of them wrote.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
build=${VDSP_BUILD:-$(runs_folder revenant-vdsp-host)}
rm -rf "$build"
mkdir -p "$build"

# Every API name the two object files define is renamed in the port's own translation units, so this one
# can hold the port's answers and the host's side by side. The names come from the port's registry, not
# from a list kept here, so a name added to either file is renamed too.
renames=""
for name in $(python3 - "$here" <<'PY'
import json, os, sys
registry = os.path.join(sys.argv[1], "..", "..", "..", "..", "packages", "a", "apple-backports", "registry", "Accelerate")
for part in ("ios7vdsp.json", "ios8vdsp.json"):
    for entry in json.load(open(os.path.join(registry, part)))["entries"]:
        if entry["kind"] == "function":
            print(entry["api"].rstrip("()"))
PY
); do
    renames="$renames -D$name=revenant_host_$name"
done

objects=""
for source in RevenantVDSPKernel.c vDSPFixed7.m vDSPElementwise8.m; do
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
