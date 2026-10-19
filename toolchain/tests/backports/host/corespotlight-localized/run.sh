#!/bin/sh
# run.sh - the host differential of CSLocalizedString. differential.m is built once against the host's CoreSpotlight.framework and
# once against the port's CSLocalizedString.m. Every case is a preferred-language list (settings.txt: the 23 measured lists and the
# 12 held-out ones) with every key set (key-sets.txt: the 42 measured and the 19 held out). The two outputs must be identical. A
# planted control then makes the enumeration fallback the last key instead of the first, in a scratch copy of the port, and the
# comparison must tell that copy apart: a diff that is empty for a mutant proves nothing about the port.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
spotlight=${SPOTLIGHT:-$here/../../../../packages/a/apple-backports/CoreSpotlight}
build=${CORESPOTLIGHT_LOCALIZED_BUILD:-$(runs_folder charon-corespotlight-localized-host)}
rm -rf "$build"
mkdir -p "$build/host" "$build/port/src" "$build/control/src"

normalise() {
    sed -E 's/0x[0-9a-f]+/ADDR/g' "$1" > "$1.norm"
}

# One run of the program for every preferred-language list, with the key sets on its standard input.
run_all() {
    bin=$1
    out=$2
    : > "$out"
    while read -r name plist; do
        arg="($(printf '%s' "$plist" | sed 's/,/, /g'))"
        echo "settings $name $plist" >> "$out"
        "$bin" -AppleLanguages "$arg" < "$here/key-sets.txt" >> "$out"
    done < "$here/settings.txt"
}

# The host side: the macOS framework, its own class.
xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/differential.m" \
    -framework Foundation -framework CoreSpotlight -o "$build/host/differential"
run_all "$build/host/differential" "$build/host.txt"
normalise "$build/host.txt"

# The port side: the port's source, built with the host's headers and run.
port() {
    dir=$1
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations -c "$dir/CSLocalizedString.m" -o "$dir/CSLocalizedString.m.o"
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/differential.m" "$dir/CSLocalizedString.m.o" \
        -framework Foundation -o "$dir/differential"
    run_all "$dir/differential" "$dir/out.txt"
}

cp "$spotlight/CSLocalizedString.m" "$build/port/src/"
port "$build/port/src"
cp "$build/port/src/out.txt" "$build/port.txt"
normalise "$build/port.txt"

lines=$(wc -l < "$build/host.txt" | tr -d ' ')
if diff "$build/host.txt.norm" "$build/port.txt.norm" > "$build/diff.txt"; then
    echo "ok: the port answers all $lines lines of the host differential the same"
else
    head -20 "$build/diff.txt"
    echo "FAIL: the port differs from the host"
    exit 1
fi

# The planted control: the fallback is the last enumerated key. Each change is checked to have happened.
cp "$spotlight/CSLocalizedString.m" "$build/control/src/"
sed -i '' 's|answer = keys\[0\];|answer = keys[keys.count - 1];|' "$build/control/src/CSLocalizedString.m"
grep -q 'answer = keys\[keys.count - 1\];' "$build/control/src/CSLocalizedString.m"
port "$build/control/src"
cp "$build/control/src/out.txt" "$build/control.txt"
normalise "$build/control.txt"
if diff "$build/host.txt.norm" "$build/control.txt.norm" > "$build/control.diff"; then
    echo "FAIL: the planted mutant was not told apart from the host"
    exit 1
fi
echo "control: the planted mutant differs from the host, $(grep -c '^[<>]' "$build/control.diff") changed lines"
