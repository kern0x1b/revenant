#!/bin/sh
# run.sh - the thirteen data and skeleton classes of ARKit that this series carries, against the host's own ARKit
# and SceneKit on Mac Catalyst (check.m says what is compared, and what is not: no session runs on either side).
#
# Each of the port's files is compiled with its one class renamed to CharonPort<name>, so the port's classes and
# the host's are in one process. The rename reaches the SDK's declaration of that class as well, which is the
# point: the port's @interface is the one compiled. Nothing here is a mutant run: the mutants of the neighbouring
# harnesses are written in python, and this package does not run python.

set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../.." && pwd)
ARKit=$repo/packages/a/apple-backports/ARKit
runs=${RUNS:-$repo/.agent-work/runs/arkit-absent-classes}
rm -rf "$runs"
mkdir -p "$runs"

sdk=$(xcrun --sdk macosx --show-sdk-path)
ios=$sdk/System/iOSSupport/System/Library/Frameworks
target="-target $(uname -m)-apple-ios14.0-macabi"
classes="ARFaceGeometry ARSCNFaceGeometry ARReferenceObject ARMeshGeometry ARGeometrySource ARGeometryElement ARMatteGenerator ARCollaborationData ARSkeleton ARSkeleton2D ARSkeleton3D ARBody2D ARGeoTrackingStatus"

for cls in $classes; do
    xcrun clang -fobjc-arc -w -O1 $target -isysroot "$sdk" -iframework "$ios" \
        -D"$cls=CharonPort$cls" -c "$ARKit/$cls.m" -o "$runs/$cls.o"
done

xcrun clang -fobjc-arc -w -O1 $target -isysroot "$sdk" -iframework "$ios" \
    "$here/check.m" "$runs"/*.o -framework Foundation -framework ARKit -framework SceneKit -o "$runs/check"

"$runs/check" | tee "$runs/out.txt"
grep -q '^VERDICT ok' "$runs/out.txt" || { echo "FAIL: the differential is not green"; exit 1; }
echo "ok the thirteen classes carry the host's superclass, properties and fresh-object values"
