#!/bin/sh
# The differential: does this port's Combine behave as the host's own Combine does?
#
# One source - Harness.swift, Table.swift and main.swift here - is compiled twice, once
# against the host's own Combine and once against the module this port builds, and the two
# runs are compared line for line. A differing line is a place where a caller of the two
# would see something different.
#
# The module is built HERE, from the fork's own sources and this repository's layer, before
# either probe is built against it. That is the whole point: a run that linked a prebuilt
# object would measure the object, so a change to the module's Swift could sit in the
# sources and the run would answer `identical`. A mutation of the source read as a pass,
# which is the one thing this test must never do. README.md has the mutation and what it
# prints.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
repo=$(cd "$here/../../../.." && pwd)
build=${COMBINE_DIFFERENTIAL_BUILD:-$(runs_folder charon-combine-differential)}
sources=${COMBINE_SOURCES:-}
swifc=${SWIFTC:-/usr/bin/swiftc}
clangxx=${CLANGXX:-clang++}

# The pin is read out of the recipe rather than written here, so there is one commit and not two.
# `git archive` reads the tree at that commit without a checkout and without moving styx's HEAD,
# which is why it and not `git worktree` or `git checkout`.
recipe="$repo/packages/s/styx/xmake.lua"
styx=${STYX_REPO:-$HOME/Git/projects/ios/styx}
pinned=$(sed -n 's/.*add_versions([^,]*, *"\{0,1\}\([0-9a-f]\{40\}\)"\{0,1\}).*/\1/p' "$recipe" | head -1 || true)
have_pinned=no
if [ -d "$styx/.git" ] && [ -n "$pinned" ] && git -C "$styx" cat-file -e "$pinned^{commit}" 2>/dev/null; then
    have_pinned=yes
fi
if [ ! -d "$repo/packages/s/styx/files/CombineKit" ]; then
    echo "no layer at $repo/packages/s/styx/files/CombineKit; this is a worktree of charon."
    exit 1
fi

rm -rf "$build"
mkdir -p "$build/stage/Combine" "$build/swift/CombineKit.swiftmodule" "$build/objects"

# The fork's own sources are not in this repository - the recipe fetches them - so they come
# from $COMBINE_SOURCES, from the xmake source cache when the package has been built, or from
# this machine's own styx repository at the commit the recipe pins. All three name the same
# thing: the directory that holds `Combine`, `CombineHelpers` and so on, which is the repository's
# top-level `Sources` directory. The check below is that "$sources/Combine" is a directory, and the
# message says exactly that. Nothing is staged before the build directory is emptied, so the copy
# below cannot be the one `rm -rf` takes.
if [ -z "$sources" ]; then
    sources=$(ls -d "$HOME"/.xmake/cache/packages/*/s/styx/*/source/styx/Sources 2>/dev/null | head -1 || true)
fi
if [ -z "$sources" ] && [ "$have_pinned" = yes ]; then
    mkdir -p "$build/styx"
    if git -C "$styx" archive "$pinned" Sources | tar -x -C "$build/styx"; then
        sources="$build/styx/Sources"
    fi
fi
if [ -z "$sources" ] || [ ! -d "$sources/Combine" ]; then
    # Said in the words the host sweep reads. Without a line beginning FAIL/note/skip a run that exits 1
    # is counted DEAD, which reads as "nobody has run this lately" rather than "the input is not on this
    # machine" - and this test's input is not in the xmake package cache here, so the run says where it can
    # be: this machine's own styx repository holds the commit the recipe pins, and one fetch brings it.
    echo "FAIL: styx sources not found - set COMBINE_SOURCES to the top-level Sources/ directory of"
    echo "      kern0x1b/styx at the commit packages/s/styx/xmake.lua pins, or build charon@styx once so the"
    echo "      xmake package cache holds it, or fetch the pin into this machine's styx repository with"
    echo "      git -C $styx fetch origin $pinned"
    exit 1
fi
echo "sources: $sources"

# ---------------------------------------------------------------- the module

# The host copy is called CombineKit, not Combine. On macOS the SDK's own Foundation
# imports Apple's Combine, and a module called Combine links Apple's Combine beside it
# through the autolink its interface carries; the two sets of classes then collide. Twelve
# files of the sources name the module's own types with the module's own prefix, which only
# resolves when the module carries that name, so the staged copy has that prefix rewritten
# to the name it is built under. OCombine is a nested namespace of the fork's own whose name
# ends in the same six letters, so it is put aside for the moment the substitution happens.
cp -R "$sources/Combine/." "$build/stage/Combine/"
rm -rf "$build/stage/Combine/Foundation" "$build/stage/Combine/Schedulers"
# One source of each file. The layer is ours and the fork's sources are the fork's; if the
# fork's tree also carried a file of one of the layer's names, the copy below would put two
# different files at one name and the build would compile whichever one the compiler picked -
# so a change to the fork's copy would be measured as if nothing had changed. The run refuses
# that instead of guessing.
layer="$repo/packages/s/styx/files/CombineKit"
clash=""
for file in "$layer"/*.swift; do
    name=$(basename "$file")
    hit=$(find "$sources/Combine" -name "$name" -print -quit)
    if [ -n "$hit" ]; then
        clash="$clash$name: $hit
"
    fi
done
if [ -n "$clash" ]; then
    echo "the fork's sources carry a file of the layer's name, so one of them would be compiled"
    echo "in place of the other and the run would measure whichever the compiler picked:"
    echo "$clash"
    exit 1
fi
mkdir -p "$build/stage/Combine/CombineKit"
cp "$layer"/*.swift "$build/stage/Combine/CombineKit/"
find "$build/stage" -name '*.swift' -print0 \
    | xargs -0 sed -i '' -e 's/OCombine/@@NESTED@@/g' -e 's/Combine\./CombineKit./g' \
                          -e 's/@@NESTED@@/OCombine/g'

helpers="$sources/CombineHelpers"
"$clangxx" -target arm64-apple-macosx11.0 -std=c++17 -O2 \
    -I "$helpers/include" \
    -c "$helpers/CombineHelpers.cpp" -o "$build/objects/CombineHelpers.o"
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
echo "module: $(find "$build/stage/Combine" -name '*.swift' | wc -l | tr -d ' ') Swift files, $(ls "$layer" | wc -l | tr -d ' ') of them ours"

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
