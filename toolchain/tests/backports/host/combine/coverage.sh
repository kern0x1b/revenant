#!/bin/sh
# Does the built armv7 module still carry what the facts say it carries?
#
# The facts file for this package states how many of the corpus rows for `Combine` the
# built module declares, and how many it does not, broken down by family. Those numbers
# were written by hand, and a hand-written number in a facts file is a claim, not a check.
# This script computes them - from the same tool the corpus was built with, reading Apple's
# declarations and ours out of the two `.swiftinterface` files - and compares them with
# what the facts say. A mismatch is a failure, not a note: the facts are what the next round
# reads, so if they are stale the next round is reading nothing.
#
# It needs the armv7 module built, and builds it if it is not there: the same swiftc the
# package uses, the same swift-runtime resource directory, through the same three steps.
set -eu
echo "FAIL host/combine/coverage.sh: its Python steps are gone and not yet ported to Lua: coverage.py" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
repo=$(cd "$here/../../../.." && pwd)
build=${COMBINE_COVERAGE_BUILD:-$(runs_folder revenant-combine-coverage)}
sources=${COMBINE_SOURCES:-}
facts=$repo/../docs/reference/combine/CombineKit.md
corpus=${CORPUS:-$(xmake l "$repo/modules/workspace.lua" corpus sdk-26.2-surface.tsv)}
sdk26=$(xmake l "$repo/modules/workspace.lua" sdk)
swifc=${SWIFTC:-/usr/bin/swiftc}
revenant_swifc=${REVENANT_SWIFTC:-}

if [ -z "$sources" ]; then
    sources=$(ls -d "$HOME"/.xmake/packages/c/combine/*/*/src 2>/dev/null | tail -1 || true)
fi
if [ -z "$sources" ] || [ ! -d "$sources/Combine" ]; then
    # Said in the words the host sweep reads, because otherwise this is invisible there: a script that
    # exits 1 with no line beginning FAIL/note/skip is counted DEAD, which reads as "nobody has run this
    # lately" rather than "the input is not on this machine". The name of the missing input is the whole
    # point of the line, so it is one line and it names the input.
    echo "FAIL: combine sources not found - set COMBINE_SOURCES to the src/ directory of an installed"
    echo "      revenant@combine, the one holding Combine/ and CombineHelpers/, or install revenant@combine once"
    exit 1
fi
for needed in "$corpus" "$repo/tools/corpus/swiftinterface.lua" "$facts"; do
    [ -r "$needed" ] || { echo "missing $needed"; exit 1; }
done
[ -d "$sdk26" ] || { echo "missing the 26.2 SDK at $sdk26"; exit 1; }

# The armv7 module, built the way the package builds it: the whole
# Combine module in one compile, the runtime's resource directory, the revenant SDK.
#
# REVENANT_SDK and REVENANT_SWIFTC are named rather than guessed. There are several builds of
# the toolchain and several of the 16.4 SDK in the store, and a mismatched pair refuses a
# 6.1.3 target outright ("Swift requires a minimum deployment target of iOS 7.0.0") - which
# says nothing about the code. The pair the package used is the one whose swifc is
# SWIFT_EXEC in the envs of any installed revenant@swift-runtime manifest, and whose SDK is
# the 16.4 the toolchain's config names:
#   grep -o 'sdk=[0-9.]*' ~/.xmake/packages/c/combine/*/*/manifest.txt
runtime=$(ls -d "$HOME"/.xmake/packages/s/swift-runtime/6.4.0/*/lib/swift 2>/dev/null | head -1 || true)
[ -n "$runtime" ] || { echo "missing revenant@swift-runtime; build it once"; exit 1; }
[ -n "$revenant_swifc" ] && [ -n "$iossdk" ] || {
    echo "set REVENANT_SWIFTC to the swiftc of the revenant runtime the package used and"
    echo "REVENANT_SDK to its 16.4 SDK; the store holds several of each and only the pair"
    echo "the package built with will accept -target armv7-apple-ios6.1.3"
    exit 1
}

rm -rf "$build"
mkdir -p "$build/stage/Combine" "$build/swift/Combine.swiftmodule" "$build/objects"
cp -R "$sources/Combine/." "$build/stage/Combine/"
clang++ -target armv7-apple-ios6.1.3 -std=c++17 -O2 -I "$sources/CombineHelpers/include" \
    -c "$sources/CombineHelpers"/*.cpp -o "$build/objects/CombineHelpers.o"
if ! "$revenant_swifc" -target armv7-apple-ios6.1.3 -wmo -module-name Combine -O -parse-as-library \
        -clang-target armv7-apple-ios6.1.3 \
        -sdk "$iossdk" -resource-dir "$runtime" \
        -Xfrontend -bundled-swift-runtime -runtime-compatibility-version none \
        -plugin-path "$runtime/../host/plugins" \
        -I "$build/swift/Combine.swiftmodule" -I "$sources/CombineHelpers/include" \
        -Xcc -fmodule-map-file="$sources/CombineHelpers/include/module.modulemap" \
        -emit-module -emit-module-path "$build/swift/Combine.swiftmodule/armv7-apple-ios.swiftmodule" \
        -c $(find "$build/stage/Combine" -name '*.swift') -o "$build/objects/Combine.o"; then
    echo "the armv7 module did not build; there is nothing to count"
    exit 1
fi

# The interface the toolchain synthesises out of what was built, and the same for Apple.
mkdir -p "$build/interface"
if ! "$revenant_swifc" -frontend -emit-module-interface-path "$build/interface/ours.swiftinterface" \
        -emit-module-interface -o "$build/interface/ours.swiftmodule" \
        -target armv7-apple-ios6.1.3 -sdk "$iossdk" -resource-dir "$runtime" \
        -I "$build/swift/Combine.swiftmodule" -I "$sources/CombineHelpers/include" \
        -Xcc -fmodule-map-file="$sources/CombineHelpers/include/module.modulemap" 2>/dev/null; then
    "$revenant_swifc" -target armv7-apple-ios6.1.3 -sdk "$iossdk" -resource-dir "$runtime" \
        -module-name Combine -I "$build/swift/Combine.swiftmodule" \
        -I "$sources/CombineHelpers/include" \
        -Xcc -fmodule-map-file="$sources/CombineHelpers/include/module.modulemap" \
        -emit-module-interface-path "$build/interface/ours.swiftinterface" \
        -emit-module -emit-module-path "$build/interface/ours.swiftmodule"
fi

# The count, from the corpus's own tool on both sides.
python3 "$here/coverage.py" "$corpus" "$sources" "$build/interface/ours.swiftinterface" \
    --facts "$facts" --apple-sdk "$sdk26"
