#!/bin/sh
# run.sh - the six sensor-data classes of ARKit, the port's against the host's own ARKit on Mac Catalyst.
#
# The host's ARKit.framework is the iOSSupport copy inside the macOS SDK: it has every class here, with
# the superclass the port declares, so it is an oracle for the class shape and for the probe's two
# constructors. Each class's file is compiled from the port's tree with that one class renamed to
# RevenantPort<name>, so the port's code and the host's both run in one process (check.m says what is
# compared, and what is not: no session runs on either side).
#
# Nothing here is a mutant run: the mutants of the neighbouring harnesses are written in python, and this
# package does not run python. A change that broke a class would show in the shape comparison above.

set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
repo=$(cd "$here/../../../.." && pwd)
ARKit=$repo/packages/a/apple-backports/ARKit
runs=${RUNS:-$(runs_folder arkit-sensorshells-host)}
rm -rf "$runs"
mkdir -p "$runs"

sdk=$(xcrun --sdk macosx --show-sdk-path)
ios=$sdk/System/iOSSupport/System/Library/Frameworks
target="-target $(uname -m)-apple-ios14.0-macabi"
classes="ARDepthData ARFaceAnchor AREnvironmentProbeAnchor ARMeshAnchor ARObjectAnchor ARDirectionalLightEstimate"

# the port's six files, each compiled with its own class renamed; the rename reaches the SDK's declaration
# of that class as well, which is the point: the port's @interface is the one compiled
for cls in $classes; do
    xcrun clang -fobjc-arc -w -O1 $target -isysroot "$sdk" -iframework "$ios" \
        -D"$cls=RevenantPort$cls" -c "$ARKit/$cls.m" -o "$runs/$cls.o"
done

xcrun clang -fobjc-arc -w -O1 $target -isysroot "$sdk" -iframework "$ios" \
    "$here/check.m" "$runs"/*.o -framework Foundation -framework ARKit -o "$runs/check"

"$runs/check" | tee "$runs/plain.txt"
grep -q '^VERDICT ok' "$runs/plain.txt" || { echo "FAIL: the differential is not green"; exit 1; }
echo "ok the six sensor-data classes carry the host's shape, and the probe's constructors answer as the host's do"
