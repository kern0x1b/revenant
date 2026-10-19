#!/bin/sh
# The measurement the layers family is written against, asked of the host's own MLCompute and printed
# so that it can be read and compared rather than believed. Neither program is a test: they ask, they
# record, and they exit whatever the framework's own answer is. What the answers are is written down in
# facts/MLCompute/Engine.md and facts/MLCompute/Layers.md, and the differential holds the port to them
# once the port has the layers.
#
# engine.m asks what the framework computes for a layer, through an inference graph so the numbers come
# from its own arithmetic. factories.m asks what the layer factories keep, and refuse, and name.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${MLCOMPUTE_MEASURE_BUILD:-$(runs_folder charon-mlcompute-measure)}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -fobjc-arc -w -I$here"
libs="-framework MLCompute -framework Foundation"

for name in engine factories; do
    xcrun clang $common "$here/$name.m" $libs -o "$build/$name"
    "$build/$name" > "$build/$name.txt"
    echo "== $name: $(wc -l < "$build/$name.txt" | tr -d ' ') answers, $build/$name.txt"
done
