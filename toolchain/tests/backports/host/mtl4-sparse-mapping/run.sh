#!/bin/sh
# run.sh - the port's sparse mapping refusals (Metal/MTL4SparseMapping26.m) beside macOS 26 Metal's own answers.
#
# Metal's refusals are measured in child processes, and the decisions are compiled for the host beside them. The
# port's MTL4CommandQueue methods are not built here (see differential.m). Metal's buffer refusals are assertions,
# so a child that makes one exits 134; a call Metal accepts exits 0, and the port's texture refusals are checked as
# the port's own answers, named in facts/Metal/SparseMapping26.md.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METAL=${METAL:-$here/../../../../packages/frameworks/apple-backports/Metal}
BUILD=${BUILD:-$(runs_fresh revenant-mtl4-sparse-mapping)}
xcrun clang -O -fobjc-arc -fvisibility=hidden -Wno-objc-designated-initializers -c "$METAL/MTL4SparseMapping26.m" -o "$BUILD/MTL4SparseMapping26.o"
xcrun clang -O -fobjc-arc "$here/differential.m" "$BUILD/MTL4SparseMapping26.o" -framework Foundation -framework Metal -o "$BUILD/differential"
"$BUILD/differential" "$BUILD"
