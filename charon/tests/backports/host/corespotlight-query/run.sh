#!/bin/sh
# run.sh - the host differential of CSSearchQuery. differential.m is built once against the host's CoreSpotlight.framework, which
# searches the host's own index, and once against the port's sources, which search the port's store. The port's store is under
# CHARON_SPOTLIGHT_SHARED_ROOT, a path under /var/mobile that this host cannot write, so the port is built from a copy in which
# only that one path is replaced by a folder of the run. Every query's line must then be the same on both sides, after object
# addresses are replaced. A planted control makes != answer like == in a scratch copy, and the comparison must tell it apart.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
spotlight=${SPOTLIGHT:-$here/../../../../packages/a/apple-backports/CoreSpotlight}
build=${CORESPOTLIGHT_QUERY_BUILD:-$(runs_folder charon-corespotlight-query-host)}
rm -rf "$build"
mkdir -p "$build/host" "$build/port/src" "$build/port/store" "$build/control/src"

normalise() {
    sed -E 's/0x[0-9a-f]+/ADDR/g' "$1" > "$1.norm"
}

# The host side: the macOS framework and its own index.
xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/differential.m" \
    -framework Foundation -framework CoreSpotlight -o "$build/host/differential"
"$build/host/differential" > "$build/host.txt"
normalise "$build/host.txt"

# The port side: the port's sources, with the store path of the copy pointed at a folder of this run.
copy_port() {
    dir=$1
    for file in CSSearchQuery.m CSSearchableIndex.m CSSearchableItem.m CSSearchableItemAttributeSet.m CSSearchQueryContext.m CharonSpotlightStore.h; do
        cp "$spotlight/$file" "$dir/"
    done
    sed -i '' "s|#define CHARON_SPOTLIGHT_SHARED_ROOT @\"/var/mobile/Library/Caches/org.charon.corespotlight\"|#define CHARON_SPOTLIGHT_SHARED_ROOT @\"$build/port/store\"|" "$dir/CharonSpotlightStore.h"
    grep -q "$build/port/store" "$dir/CharonSpotlightStore.h"
}
port() {
    dir=$1
    objects=""
    for file in CSSearchQuery CSSearchableIndex CSSearchableItem CSSearchableItemAttributeSet CSSearchQueryContext; do
        xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations -Wno-incomplete-implementation -I"$dir" -c "$dir/$file.m" -o "$dir/$file.o"
        objects="$objects $dir/$file.o"
    done
    # The error domain is the generator's constant, rendered from 10.0 and not defined by hand in the sources; the port links
    # the same generated file the band links. The generator's output is git-ignored, so a missing file is named, not guessed.
    gen="$spotlight/../.gen/CoreSpotlight"
    [ -f "$gen/CoreSpotlightConstants100.m" ] || { echo "missing $gen/CoreSpotlightConstants100.m: run the generator (the gate writes it)" >&2; exit 1; }
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations -c "$gen/CoreSpotlightConstants100.m" -o "$dir/CoreSpotlightConstants100.o"
    objects="$objects $dir/CoreSpotlightConstants100.o"
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations -I"$dir" "$here/differential.m" $objects -framework Foundation -o "$dir/differential"
    "$dir/differential"
}

copy_port "$build/port/src"
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

# The planted control: != answers like ==. The change is checked to have happened.
copy_port "$build/control/src"
sed -i '' 's|return equal ? matches : !matches;|return equal ? matches : matches;|' "$build/control/src/CSSearchQuery.m"
grep -q 'return equal ? matches : matches;' "$build/control/src/CSSearchQuery.m"
# The mutant may fail to answer; its stderr is kept beside its answer, so the diff below names what it did instead of hiding it.
port "$build/control/src" > "$build/control.txt" 2> "$build/control.err" || true
normalise "$build/control.txt"
if diff "$build/host.txt.norm" "$build/control.txt.norm" > "$build/control.diff"; then
    echo "FAIL: the planted mutant was not told apart from the host"
    exit 1
fi
echo "control: the planted mutant differs from the host, $(grep -c '^[<>]' "$build/control.diff") changed lines"
