#!/bin/sh
# The port's BLASThreading18.m held against the host's own Accelerate, case by case: the four answers the
# API gives, compared one by one, and then a measurement of whether the model changes how the library
# threads - which is the part no answer can show and the part the facts file states.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
build=${BLASTHREADING_BUILD:-$(runs_folder revenant-blasthreading-host)}
rm -rf "$build"
mkdir -p "$build"

# Every API name the object defines is renamed in the port's own translation unit, so this one can hold
# the port's answers and the host's side by side. The names come from the port's registry, not from a list
# kept here, so a name added to the library is renamed too.
renames=""
for name in $(runs_xmake l "$here/../registry-functions.lua" "$here/../../../../packages/a/apple-backports/registry/Accelerate" ios18blasthreading.json); do
    renames="$renames -D$name=revenant_host_$name"
done

xcrun clang -fobjc-arc -w $renames -c "$ACCELERATE/BLASThreading18.m" -o "$build/BLASThreading18.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations \
    "$here/differential.m" "$build/BLASThreading18.o" \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
