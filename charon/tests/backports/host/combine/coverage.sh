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
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
repo=$(cd "$here/../../../.." && pwd)
build=${COMBINE_COVERAGE_BUILD:-$(runs_folder charon-combine-coverage)}
sources=${COMBINE_SOURCES:-}
facts=$repo/packages/s/styx/facts/Combine/CombineKit.md
corpus=${CORPUS:-$HOME/Git/projects/ios/coordination/corpus/sdk-26.2-surface.tsv}
tools=${CORPUS_TOOLS:-$HOME/Git/projects/ios/coordination/corpus-tools}
sdk26=$HOME/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk
swifc=${SWIFTC:-/usr/bin/swiftc}
charon_swifc=${CHARON_SWIFTC:-}

if [ -z "$sources" ]; then
    sources=$(ls -d "$HOME"/.xmake/cache/packages/*/s/styx/*/source/styx/Sources 2>/dev/null | head -1 || true)
fi
if [ -z "$sources" ] || [ ! -d "$sources/Combine" ]; then
    # Said in the words the host sweep reads, because otherwise this is invisible there: a script that
    # exits 1 with no line beginning FAIL/note/skip is counted DEAD, which reads as "nobody has run this
    # lately" rather than "the input is not on this machine". The name of the missing input is the whole
    # point of the line, so it is one line and it names the input.
    echo "FAIL: styx sources not found - set COMBINE_SOURCES to the top-level Sources/ directory of"
    echo "      kern0x1b/styx at the commit packages/s/styx/xmake.lua pins, the one holding Combine/ and"
    echo "      CombineHelpers/, or build the package once so the xmake package cache holds it"
    exit 1
fi
for needed in "$corpus" "$tools/swiftinterface-surface.py" "$facts"; do
    [ -r "$needed" ] || { echo "missing $needed"; exit 1; }
done
[ -d "$sdk26" ] || { echo "missing the 26.2 SDK at $sdk26"; exit 1; }

# The armv7 module, built the way the package builds it: the layer copied in, the whole
# Combine module in one compile, the runtime's resource directory, the charon SDK.
#
# CHARON_SDK and CHARON_SWIFTC are named rather than guessed. There are several builds of
# the toolchain and several of the 16.4 SDK in the store, and a mismatched pair refuses a
# 6.1.3 target outright ("Swift requires a minimum deployment target of iOS 7.0.0") - which
# says nothing about the code. The pair the package used is the one whose swifc is
# SWIFT_EXEC in the envs of any installed charon@swift-runtime manifest, and whose SDK is
# the 16.4 the toolchain's config names:
#   grep -o 'sdk=[0-9.]*' ~/.xmake/packages/s/styx/*/*/manifest.txt
runtime=$(ls -d "$HOME"/.xmake/packages/s/swift-runtime/6.4.0/*/lib/swift 2>/dev/null | head -1 || true)
[ -n "$runtime" ] || { echo "missing charon@swift-runtime; build it once"; exit 1; }
[ -n "$charon_swifc" ] && [ -n "$iossdk" ] || {
    echo "set CHARON_SWIFTC to the swiftc of the charon runtime the package used and"
    echo "CHARON_SDK to its 16.4 SDK; the store holds several of each and only the pair"
    echo "the package built with will accept -target armv7-apple-ios6.1.3"
    exit 1
}

rm -rf "$build"
mkdir -p "$build/stage/Combine/CombineKit" "$build/swift/Combine.swiftmodule" "$build/objects"
cp -R "$sources/Combine/." "$build/stage/Combine/"
cp "$repo"/packages/s/styx/files/DispatchTimeDistance.swift "$build/stage/Combine/Schedulers" 2>/dev/null || true
mkdir -p "$build/stage/Combine/Schedulers"
cp "$repo"/packages/s/styx/files/DispatchTimeDistance.swift "$build/stage/Combine/Schedulers/"
cp "$repo"/packages/s/styx/files/CombineKit/*.swift "$build/stage/Combine/CombineKit/"
clang++ -target armv7-apple-ios6.1.3 -std=c++17 -O2 -I "$sources/CombineHelpers/include" \
    -c "$sources/CombineHelpers/CombineHelpers.cpp" -o "$build/objects/CombineHelpers.o"
if ! "$charon_swifc" -target armv7-apple-ios6.1.3 -wmo -module-name Combine -O -parse-as-library \
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
if ! "$charon_swifc" -frontend -emit-module-interface-path "$build/interface/ours.swiftinterface" \
        -emit-module-interface -o "$build/interface/ours.swiftmodule" \
        -target armv7-apple-ios6.1.3 -sdk "$iossdk" -resource-dir "$runtime" \
        -I "$build/swift/Combine.swiftmodule" -I "$sources/CombineHelpers/include" \
        -Xcc -fmodule-map-file="$sources/CombineHelpers/include/module.modulemap" 2>/dev/null; then
    "$charon_swifc" -target armv7-apple-ios6.1.3 -sdk "$iossdk" -resource-dir "$runtime" \
        -module-name Combine -I "$build/swift/Combine.swiftmodule" \
        -I "$sources/CombineHelpers/include" \
        -Xcc -fmodule-map-file="$sources/CombineHelpers/include/module.modulemap" \
        -emit-module-interface-path "$build/interface/ours.swiftinterface" \
        -emit-module -emit-module-path "$build/interface/ours.swiftmodule"
fi

# The count, from the corpus's own tool on both sides.
python3 "$here/coverage.py" "$corpus" "$sources" "$build/interface/ours.swiftinterface" \
    --facts "$facts" --apple-sdk "$sdk26"
