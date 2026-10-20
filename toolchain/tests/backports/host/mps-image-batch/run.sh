#!/bin/sh
# run.sh - the port's MPSImageBatchIncrementReadCount and MPSImageBatchSynchronize beside Metal Performance Shaders'
# own, on the macOS host. The port's file is compiled with both symbols renamed, and the differential runs Apple's
# functions from the framework on the same batches (see differential.m).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
MPS=${MPS:-$here/../../../../packages/frameworks/apple-backports/MetalPerformanceShaders}
BUILD=${BUILD:-$(runs_fresh revenant-mps-image-batch)}
renames="-DMPSImageBatchIncrementReadCount=RevenantHostMPSImageBatchIncrementReadCount -DMPSImageBatchSynchronize=RevenantHostMPSImageBatchSynchronize"
xcrun clang -O -fobjc-arc -fvisibility=hidden -Wno-objc-designated-initializers $renames -I"$MPS" \
    -c "$MPS/MPSImageBatch11.m" -o "$BUILD/MPSImageBatch11.o"
xcrun clang -O -fobjc-arc "$here/differential.m" "$BUILD/MPSImageBatch11.o" -framework Foundation -framework Metal \
    -framework MetalPerformanceShaders -o "$BUILD/differential"
"$BUILD/differential" "$BUILD"
