#!/bin/sh
# The differential: does this port's Combine behave as the host's own Combine does?
#
# One source - Harness.swift, Table.swift and main.swift here - is compiled twice, once
# against the host's own Combine and once against the module this port builds, and the two
# runs are compared line for line. A differing line is a place where a caller of the two
# would see something different.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${COMBINE_DIFFERENTIAL_BUILD:-$(runs_folder revenant-combine-differential)}
sources=${COMBINE_SOURCES:-}
swifc=${SWIFTC:-/usr/bin/swiftc}
clangxx=${CLANGXX:-clang++}

if [ -z "$sources" ]; then
    sources=$(ls -d "$HOME"/.xmake/packages/c/combine/*/*/src 2>/dev/null | tail -1 || true)
fi
if [ -z "$sources" ] || [ ! -d "$sources/Combine" ]; then
    echo "FAIL: combine sources not found - set COMBINE_SOURCES to the src/ directory of an installed"
    echo "      revenant@combine, the one holding Combine/ and CombineHelpers/, or install revenant@combine once"
    exit 1
fi
echo "sources: $sources"

rm -rf "$build"
mkdir -p "$build/stage/Combine" "$build/swift/CombineKit.swiftmodule" "$build/objects"

# ---------------------------------------------------------------- the module

cp -R "$sources/Combine/." "$build/stage/Combine/"
rm -rf "$build/stage/Combine/Foundation" "$build/stage/Combine/Schedulers"
find "$build/stage" -name '*.swift' -print0 \
    | xargs -0 sed -i '' -e 's/Combine\./CombineKit./g'

helpers="$sources/CombineHelpers"
"$clangxx" -target arm64-apple-macosx11.0 -std=c++17 -O2 \
    -I "$helpers/include" \
    -c "$helpers"/*.cpp -o "$build/objects/CombineHelpers.o"
# The module build's own exit status, checked where it is made: a module that does not
# compile has no interface to compare, and a run that went on to the probes would be
# comparing whatever the last good build left behind.
if ! "$swifc" -target arm64-apple-macosx11.0 -wmo -module-name CombineKit -O -parse-as-library \
        -I "$build/stage" -I "$helpers/include" \
        -Xcc -fmodule-map-file="$helpers/include/module.modulemap" \
        -emit-module -emit-module-path "$build/swift/CombineKit.swiftmodule/arm64-apple-macos.swiftmodule" \
        -c $(find "$build/stage/Combine" -name '*.swift') -o "$build/objects/Combine.o"; then
    echo "the module did not build; there is nothing to compare"
    exit 1
fi
echo "module: $(find "$build/stage/Combine" -name '*.swift' | wc -l | tr -d ' ') Swift files"

# ---------------------------------------------------------------- the two probes

# The three files are one source compiled twice; the only difference is the module each
# imports, which is a conditional at the top of each.
"$swifc" -O -D APPLE_COMBINE -o "$build/apple" -module-cache-path "$build/mc-apple" \
    "$here/Harness.swift" "$here/Table.swift" "$here/main.swift"
"$swifc" -O -o "$build/ours" -module-cache-path "$build/mc-ours" \
    -I "$build/swift" -I "$helpers/include" \
    -Xcc -fmodule-map-file="$helpers/include/module.modulemap" \
    "$here/Harness.swift" "$here/Table.swift" "$here/main.swift" \
    "$build/objects/Combine.o" "$build/objects/CombineHelpers.o"

if otool -L "$build/ours" | grep -q "System/Library/Frameworks/Combine.framework"; then
    echo "REFUSING: ours links Apple's Combine beside ours; the two would collide"
    exit 1
fi

# ---------------------------------------------------------------- the two runs

"$build/apple" > "$build/apple.txt"
"$build/ours" > "$build/ours.txt"
echo "cases: $(tail -1 "$build/apple.txt")"
if diff -u "$build/apple.txt" "$build/ours.txt" > "$build/diff.txt"; then
    echo "DIFFERENTIAL: identical"
else
    echo "DIFFERENTIAL: $(grep -c '^[-+][^-+]' "$build/diff.txt") differing lines, in $build/diff.txt"
    head -60 "$build/diff.txt"
    exit 1
fi
