#!/bin/sh
# run.sh - the host differential of CSPerson and CSSearchQueryContext. differential.m is built once against the host's
# CoreSpotlight.framework and once against the port's CSPerson.m and CSSearchQueryContext.m (the host framework is not
# linked into that build, so the classes are the port's). The two outputs, with object addresses replaced, must be
# identical. A planted control then changes two behaviours in a scratch copy of the port, and the comparison must
# tell the copy apart: a diff that is empty for a mutant proves nothing about the port.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
spotlight=${SPOTLIGHT:-$here/../../../../packages/frameworks/apple-backports/CoreSpotlight}
build=${CORESPOTLIGHT_VALUES_BUILD:-$(runs_folder revenant-corespotlight-values-host)}
rm -rf "$build"
mkdir -p "$build/host" "$build/port/src" "$build/control/src"

normalise() {
    sed -E 's/0x[0-9a-f]+/ADDR/g' "$1" > "$1.norm"
}

# The host side: the macOS framework, its own classes.
xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/differential.m" \
    -framework Foundation -framework CoreSpotlight -o "$build/host/differential"
"$build/host/differential" > "$build/host.txt"
normalise "$build/host.txt"

# The port side: a directory holding the port's two sources, built with the host's headers and run.
port() {
    dir=$1
    for source in CSPerson.m CSSearchQueryContext.m; do
        xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations -c "$dir/$source" -o "$dir/$source.o"
    done
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/differential.m" \
        "$dir/CSPerson.m.o" "$dir/CSSearchQueryContext.m.o" -framework Foundation -o "$dir/differential"
    "$dir/differential"
}

cp "$spotlight/CSPerson.m" "$spotlight/CSSearchQueryContext.m" "$build/port/src/"
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

# The planted control: in a scratch copy of the port, copy drops the contact identifier and the context's default list of
# attributes is nil. Each change is checked to have happened; the mutant must then differ from the host.
cp "$spotlight/CSPerson.m" "$spotlight/CSSearchQueryContext.m" "$build/control/src/"
sed -i '' 's/    copy.contactIdentifier = self.contactIdentifier;/    (void)0;/' "$build/control/src/CSPerson.m"
sed -i '' 's/        _fetchAttributes = @\[\];/        _fetchAttributes = nil;/' "$build/control/src/CSSearchQueryContext.m"
grep -q '(void)0;' "$build/control/src/CSPerson.m"
grep -q '_fetchAttributes = nil;' "$build/control/src/CSSearchQueryContext.m"
port "$build/control/src" > "$build/control.txt"
normalise "$build/control.txt"
if diff "$build/host.txt.norm" "$build/control.txt.norm" > "$build/control.diff"; then
    echo "FAIL: the planted mutant was not told apart from the host"
    exit 1
fi
echo "control: the planted mutant differs from the host, $(grep -c '^[<>]' "$build/control.diff") changed lines"
