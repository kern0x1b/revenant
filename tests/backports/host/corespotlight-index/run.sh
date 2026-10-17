#!/bin/sh
# run.sh - the host differential of CSSearchableIndex's delegate and external-provider fetch. differential.m is built once against
# the host's CoreSpotlight.framework and once against the port's CSSearchableIndex.m and the sources it links with (the host
# framework is not linked into that build, so the classes are the port's). The two outputs, with object addresses replaced, must
# be identical. A planted control then changes the fetch's error code in a scratch copy of the port, and the comparison must tell
# the copy apart: a diff that is empty for a mutant proves nothing about the port.
#
# The port's index writes its store under CHARON_SPOTLIGHT_SHARED_ROOT (CharonSpotlightStore.h), a path only root can create, and
# defaultSearchableIndex asks for the store directory when it is made. The attempt fails silently for an ordinary user, and nothing
# is written: the program indexes nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
spotlight=${SPOTLIGHT:-$here/../../../../packages/a/apple-backports/CoreSpotlight}
build=${CORESPOTLIGHT_INDEX_BUILD:-$(runs_folder charon-corespotlight-index-host)}
rm -rf "$build"
mkdir -p "$build/host" "$build/port/src" "$build/control/src"

# The port's sources the index links with: the index itself, and the item classes its store archives. CSSearchableItem.m does
# not implement compareByRank:, which the macOS header declares (macOS 13 and later, outside this family), so the port side allows
# that one warning and no other.
sources="CSSearchableIndex.m CSSearchableItem.m CSSearchableItemAttributeSet.m"
# The store header the index includes, which the port builds beside it.
headers="CharonSpotlightStore.h"

normalise() {
    sed -E 's/0x[0-9a-f]+/ADDR/g' "$1" > "$1.norm"
}

# The host side: the macOS framework, its own classes.
xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/differential.m" \
    -framework Foundation -framework CoreSpotlight -framework UniformTypeIdentifiers -o "$build/host/differential"
"$build/host/differential" > "$build/host.txt"
normalise "$build/host.txt"

# The port side: the port's sources, built with the host's headers and run.
port() {
    dir=$1
    objects=
    for source in $sources; do
        xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations -Wno-incomplete-implementation -c "$dir/$source" -o "$dir/$source.o"
        objects="$objects $dir/$source.o"
    done
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/differential.m" $objects \
        -framework Foundation -framework UniformTypeIdentifiers -o "$dir/differential"
    "$dir/differential"
}

for source in $sources; do
    cp "$spotlight/$source" "$build/port/src/"
done
for header in $headers; do cp "$spotlight/$header" "$build/port/src/"; done
port "$build/port/src" > "$build/port.txt"
normalise "$build/port.txt"

lines=$(wc -l < "$build/host.txt" | tr -d ' ')
if diff "$build/host.txt.norm" "$build/port.txt.norm" > "$build/diff.txt"; then
    echo "ok: the port answers all $lines lines of the host differential the same"
else
    cat "$build/diff.txt"
    echo "FAIL: the port differs from the host"
    exit 1
fi

# The planted control: in a scratch copy of the port, the fetch answers the unknown-error code instead of the remote connection code.
for source in $sources; do
    cp "$spotlight/$source" "$build/control/src/"
done
for header in $headers; do cp "$spotlight/$header" "$build/control/src/"; done
sed -i '' 's/code:CSIndexErrorCodeRemoteConnectionError userInfo:nil/code:CSIndexErrorCodeUnknownError userInfo:nil/' "$build/control/src/CSSearchableIndex.m"
grep -q 'code:CSIndexErrorCodeUnknownError userInfo:nil' "$build/control/src/CSSearchableIndex.m"
port "$build/control/src" > "$build/control.txt"
normalise "$build/control.txt"
if diff "$build/host.txt.norm" "$build/control.txt.norm" > "$build/control.diff"; then
    echo "FAIL: the planted mutant was not told apart from the host"
    exit 1
fi
echo "control: the planted mutant differs from the host, $(grep -c '^[<>]' "$build/control.diff") changed lines"
