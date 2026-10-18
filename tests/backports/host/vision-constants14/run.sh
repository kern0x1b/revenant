#!/bin/sh
# run.sh - the 82 string constants iOS 14 added to Vision (the pose observation keys, joint and group names, and the
# video processing options) against the host's own Vision, name by name, in two processes.
#
#   1. probe.m is COMPILED against the host's Vision framework (a bare macOS tool) and run
#   2. the same probe is COMPILED against the port's Vision14_0Constants.m, with no framework linked, and run
#   3. the two outputs are compared line by line; any value that differs is named
#   4. a plant on a scratch copy of the port's file - one value changed - must turn the comparison red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/generated.sh"
ensure_generated "$here" Vision
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
build=${BUILD:-$here/../../../../.agent-work/runs/vision-constants14}
mkdir -p "$build"
source="$appledir/Vision/Vision14_0Constants.m"
[ -f "$source" ] || { echo "no $source"; exit 1; }
# the 3D group key is the generator's (spec/Vision/constants.tsv takes its value from the 26.2 cache): run gen for Vision first
generated="$appledir/.gen/Vision/VisionConstants140.m"
[ -f "$generated" ] || { echo "no $generated: run xmake l tools/gen.lua gen --tree <charon> --framework Vision --sdk <sdk>"; exit 1; }

xcrun clang -fobjc-arc -w -framework Foundation -framework Vision "$here/probe.m" -o "$build/host"
xcrun clang -fobjc-arc -w -framework Foundation "$here/probe.m" "$source" "$generated" -o "$build/port"
"$build/host" > "$build/host.txt"
"$build/port" > "$build/port.txt"

count=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$count" != 82 ]; then
    echo "FAIL: the host printed $count constants, expected 82"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "port: the 82 constants are the host's, byte for byte"
else
    echo "FAIL: the port's constants differ from the host's:"
    sed 's/^/    /' "$build/diff.txt"
    exit 1
fi

# The plant: one value changed in a scratch copy. The comparison above must be able to see it.
plant="$build/plant.m"
sed 's/@"left_foot_joint"/@"left_foot_joint_plant"/' "$source" > "$plant"
if cmp -s "$plant" "$source"; then
    echo "FAIL: the plant did not change the file, so it proves nothing"
    exit 1
fi
xcrun clang -fobjc-arc -w -framework Foundation "$here/probe.m" "$plant" "$generated" -o "$build/plant"
"$build/plant" > "$build/plant.txt"
if diff -q "$build/host.txt" "$build/plant.txt" > /dev/null; then
    echo "FAIL: the plant was not seen by the comparison"
    exit 1
fi
echo "plant: the changed value is seen: $(diff "$build/host.txt" "$build/plant.txt" | grep -c '^>') line(s) differ"
