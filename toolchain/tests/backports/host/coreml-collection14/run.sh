#!/bin/sh
# run.sh - the one constant of the iOS 14 model-collection family, MLModelCollectionDidChangeNotification, against the host's
# own Core ML, in two processes:
#
#   1. probe.m is COMPILED against the host's CoreML framework (a bare macOS tool) and run
#   2. the same probe is COMPILED against the port's MLModelCollection14.m, with no framework linked, and run
#   3. the outputs are compared line by line; a plant on a scratch copy of the port's file - the value changed - must turn it red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
build=${BUILD:-$(runs_folder coreml-collection14)}
mkdir -p "$build"
source="$appledir/CoreML/MLModelCollection14.m"
[ -f "$source" ] || { echo "no $source"; exit 1; }

xcrun clang -fobjc-arc -w -DHOST_DLSYM -framework Foundation "$here/probe.m" -o "$build/host"
xcrun clang -fobjc-arc -w -framework Foundation "$here/probe.m" "$source" -o "$build/port"
"$build/host" > "$build/host.txt"
"$build/port" > "$build/port.txt"
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "port: MLModelCollectionDidChangeNotification is the host's: $(cat "$build/host.txt")"
else
    echo "FAIL: the port's constant differs from the host's:"
    sed 's/^/    /' "$build/diff.txt"
    exit 1
fi

# The plant: the value changed in a scratch copy. The comparison above must be able to see it.
plant="$build/plant.m"
sed 's/@"MLModelCollectionDidChangeNotification"/@"MLModelCollectionDidChangeNotificationPlant"/' "$source" > "$plant"
if cmp -s "$plant" "$source"; then
    echo "FAIL: the plant did not change the file, so it proves nothing"
    exit 1
fi
xcrun clang -fobjc-arc -w -framework Foundation "$here/probe.m" "$plant" -o "$build/plant"
"$build/plant" > "$build/plant.txt"
if diff -q "$build/host.txt" "$build/plant.txt" > /dev/null; then
    echo "FAIL: the plant was not seen by the comparison"
    exit 1
fi
echo "plant: the changed value is seen: $(diff "$build/host.txt" "$build/plant.txt" | grep -c '^>') line(s) differ"
