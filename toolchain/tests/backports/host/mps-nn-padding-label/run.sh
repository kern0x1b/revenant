#!/bin/sh
# run.sh - the label and the nil answer of +[MPSNNDefaultPadding paddingWithMethod:], against Apple's objects in one
# process, for all 64 combinations of the align, remainder and size fields and the custom bit (cases.m).
#
# The port's MPSNNGraph11.m is built for macOS beside Apple's MetalPerformanceShaders, with every class it defines
# renamed RevenantHost<Name>, so Apple's classes and the port's coexist. MPSImageWalk13.m is built with it because
# MPSNNGraph11.m depends on it.
#
# A MUTANT runs last: the size names SizeSame and SizeFull are swapped in a copy of the port file, and the test must
# turn red.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
PORT=${PORT:-$here/../../../../packages/frameworks/apple-backports/MetalPerformanceShaders}
BUILD=${BUILD:-$(runs_folder mps-nn/padding-label)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation"
sources="MPSImageWalk13.m MPSNNGraph11.m"

rm -rf "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"
mkdir -p "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"

: > "$BUILD/classes.txt"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet -I"$PORT" -c "$PORT/$source" -o "$BUILD/plain/$source.o"
    xcrun nm -gU "$BUILD/plain/$source.o" | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' >> "$BUILD/classes.txt"
done
renames=""
for name in $(sort -u "$BUILD/classes.txt"); do
    renames="$renames -D$name=RevenantHost$name"
done

objects=""
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$PORT" -c "$PORT/$source" -o "$BUILD/renamed/$source.o"
    objects="$objects $BUILD/renamed/$source.o"
done

xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/cases.m" $objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$BUILD/cases"
"$BUILD/cases"

echo "the mutant: the size names SizeSame and SizeFull are swapped"
sed 's/@"SizeValidOnly", @"SizeSame", @"SizeFull"/@"SizeValidOnly", @"SizeFull", @"SizeSame"/' "$PORT/MPSNNGraph11.m" \
    > "$BUILD/mutant-src/MPSNNGraph11.m"
if cmp -s "$PORT/MPSNNGraph11.m" "$BUILD/mutant-src/MPSNNGraph11.m"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
mutant_objects=""
for source in MPSImageWalk13.m; do mutant_objects="$mutant_objects $BUILD/renamed/$source.o"; done
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$PORT" \
    -c "$BUILD/mutant-src/MPSNNGraph11.m" -o "$BUILD/mutant-graph.o"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/cases.m" $mutant_objects "$BUILD/mutant-graph.o" \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$BUILD/cases-mutant"
if "$BUILD/cases-mutant" > "$BUILD/mutant.out"; then
    echo "RUN FAILED: the mutant passed" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
echo "mutant red: $(tail -n 1 "$BUILD/mutant.out")"
