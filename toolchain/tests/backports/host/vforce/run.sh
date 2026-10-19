#!/bin/sh
# The port's vForce entries held against the host's own vForce, case by case, over the values that decide a
# cube root.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
build=${VFORCE_BUILD:-$(runs_folder revenant-vforce-host)}
rm -rf "$build"
mkdir -p "$build"

# Every API name the object defines is renamed in the port's own translation unit, so this one can hold the
# port's answers and the host's side by side. The names come from the port's registry, not from a list kept
# here, so a name added to the library is renamed too.
renames=""
for name in $(python3 - "$here" <<'PY'
import json, os, sys
registry = os.path.join(sys.argv[1], "..", "..", "..", "..", "packages", "a", "apple-backports", "registry", "Accelerate")
for part in ("ios8vforce.json",):
    path = os.path.join(registry, part)
    if not os.path.exists(path):
        continue
    for entry in json.load(open(path))["entries"]:
        if entry["kind"] == "function":
            print(entry["api"].rstrip("()"))
PY
); do
    renames="$renames -D$name=revenant_host_$name"
done

xcrun clang -fobjc-arc -w $renames -I"$ACCELERATE" -c "$ACCELERATE/vForce8.m" -o "$build/vForce8.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations \
    "$here/differential.m" "$build/vForce8.o" \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
