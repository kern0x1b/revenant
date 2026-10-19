#!/bin/sh
# run.sh - the host differential of CSUserQueryContext. differential.m is built once against the host's CoreSpotlight.framework and
# once against the port's CSUserQueryContext.m and CSSearchQueryContext.m. The two outputs must be identical. A planted control drops
# the copy of disableSemanticSearch in a scratch copy of the port, and the comparison must tell it apart.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
spotlight=${SPOTLIGHT:-$here/../../../../packages/a/apple-backports/CoreSpotlight}
build=${CORESPOTLIGHT_USERQUERY_BUILD:-$(runs_folder revenant-corespotlight-userquery-host)}
rm -rf "$build"
mkdir -p "$build/host" "$build/port/src" "$build/control/src"

normalise() {
    sed -E 's/0x[0-9a-f]+/ADDR/g' "$1" > "$1.norm"
}

xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/differential.m" \
    -framework Foundation -framework CoreSpotlight -o "$build/host/differential"
"$build/host/differential" > "$build/host.txt"
normalise "$build/host.txt"

port() {
    dir=$1
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations -c "$dir/CSSearchQueryContext.m" -o "$dir/CSSearchQueryContext.o"
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations -c "$dir/CSUserQueryContext.m" -o "$dir/CSUserQueryContext.o"
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/differential.m" "$dir/CSSearchQueryContext.o" "$dir/CSUserQueryContext.o" \
        -framework Foundation -o "$dir/differential"
    "$dir/differential"
}

cp "$spotlight/CSUserQueryContext.m" "$spotlight/CSSearchQueryContext.m" "$build/port/src/"
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

cp "$spotlight/CSUserQueryContext.m" "$spotlight/CSSearchQueryContext.m" "$build/control/src/"
sed -i '' 's|copy->_disableSemanticSearch = _disableSemanticSearch;||' "$build/control/src/CSUserQueryContext.m"
if grep -q 'copy->_disableSemanticSearch = _disableSemanticSearch;' "$build/control/src/CSUserQueryContext.m"; then
    echo "FAIL: the planted change did not apply"
    exit 1
fi
port "$build/control/src" > "$build/control.txt"
normalise "$build/control.txt"
if diff "$build/host.txt.norm" "$build/control.txt.norm" > "$build/control.diff"; then
    echo "FAIL: the planted mutant was not told apart from the host"
    exit 1
fi
echo "control: the planted mutant differs from the host, $(grep -c '^[<>]' "$build/control.diff") changed lines"
