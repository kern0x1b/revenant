#!/bin/sh
# The port's indexed and sub-byte planar expansions held against the host's own vImage, byte for byte.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=$here/../../../../packages/a/apple-backports/Accelerate
REGISTRY=$here/../../../../packages/a/apple-backports/registry/Accelerate
build=${VIMAGEPACKED12U_BUILD:-$(runs_folder revenant-vimagepacked12u-host)}
rm -rf "$build"
mkdir -p "$build"

# Every API name the object defines is renamed in the port's own translation unit, so this one can hold the
# port's answers and the host's side by side. The names come from the port's registry.
names=$(python3 -c "
import json, sys
for entry in json.load(open(sys.argv[1]))['entries']:
    if entry['kind'] == 'function':
        print(entry['api'].rstrip('()'))
" "$REGISTRY/ios7packed12u.json")

renames=""
for name in $names; do
    renames="$renames -D$name=revenant_host_$name"
done

xcrun clang -fobjc-arc -w $renames -I"$ACCELERATE" -c "$ACCELERATE/vImagePacked12U7.m" -o "$build/vImagePacked12U7.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations \
    "$here/differential.m" "$build/vImagePacked12U7.o" \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
