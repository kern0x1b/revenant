#!/bin/sh
# colour/run.sh - ask the host's own AXNameFromColor over a dense sample, fit against it, and check the
# answers the fit is measured on.
#
# Four things, in this order:
#
#   1. the probe, built for the host and run over the fit sample, and the size of what it wrote;
#   2. the known-answer check: the 21 edge cases the probe asked, with the answers recorded below, so a
#      host that answered them differently fails this run instead of quietly moving every figure the two
#      fits print. `--wrong-expectation` changes one of the recorded answers on purpose, so the control
#      for the control is in the script: the check must go red, and the run says whether it did;
#   3. the four nearest-prototype agreements, one per colour space the plan named;
#   4. the hue-angle verdict, which is the second model and is wrong too.
#
# What this script does with samples: it writes the fit sample, from a seed it takes or is given, and
# nothing else. There is no held-out sample here and none is claimed - the rule is not identified, so
# nothing has been measured against a sample the rule did not see, and a second probe written before the
# rule exists would be a file that asserts nothing. What is owed is in this directory's README.
#
# Usage: sh tests/backports/colour/run.sh [--wrong-expectation]
#        BUILD=<dir>   where the sample and the probe go
#        SEED=<n>      the sample's seed; the default is the one the recorded numbers came from
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common/runs.sh" "$here"
build=${BUILD:-$(runs_folder revenant-accessibility-colour)}
seed=${SEED:-20260929}
wrong=0
for argument in "$@"; do
    case "$argument" in
        --wrong-expectation) wrong=1 ;;
        *) echo "usage: run.sh [--wrong-expectation]" >&2; exit 2 ;;
    esac
done
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)

# The known-answer check, in the run rather than in a separate file, because it reads the sample this
# run wrote and the answers this file records.
known_answer_check() {
    mismatches=0
    total=0
    while read -r colour name; do
        [ -n "$colour" ] || continue
        total=$((total + 1))
        r=$(printf '%s' "$colour" | cut -d, -f1)
        g=$(printf '%s' "$colour" | cut -d, -f2)
        b=$(printf '%s' "$colour" | cut -d, -f3)
        got=$(awk -F'\t' -v r="$r" -v g="$g" -v b="$b" '$1=="e" && $2==r && $3==g && $4==b {print $5}' "$build/fit.tsv")
        if [ "$got" != "$name" ]; then
            echo "known-answer	$colour	the host answered '$got' where this file records '$name'"
            mismatches=$((mismatches + 1))
        fi
    done < "$build/expected.txt"
    echo "known-answer	$total recorded, $mismatches mismatched"
    if [ "$mismatches" -ne 0 ]; then
        if [ "$wrong" -eq 1 ]; then
            echo "control	the check went red as it must, so it can fail"
            return 0
        fi
        echo "known-answer	FAILED: the host's answers have moved and every figure the fits print is stale"
        return 1
    fi
    echo "known-answer	ok"
    if [ "$wrong" -eq 1 ]; then
        echo "control	FAILED: the check passed with a deliberately wrong expectation, so it examines nothing"
        return 1
    fi
    return 0
}

xcrun clang -target arm64-apple-macos26.0 -isysroot "$sdk" -fobjc-arc -O2 -Wall -Wno-nonnull \
    "$here/probe-dense.m" -framework Foundation -framework CoreGraphics -framework Accessibility \
    -o "$build/probe-dense" 2> "$build/build.log" || {
        echo "the probe did not build" >&2
        tail -20 "$build/build.log" >&2
        exit 1
    }

echo "=== the probe"
"$build/probe-dense" "$build/fit.tsv" "$seed"
bytes=$(wc -c < "$build/fit.tsv" | tr -d ' ')
lines=$(wc -l < "$build/fit.tsv" | tr -d ' ')
echo "sample	$bytes bytes, $lines lines, in $build"

echo
echo "=== the known-answer check: the host's answers to the 21 edge cases"
# The answers recorded here are the host's, from the run the figures in this directory's README came from.
# One per line: the colour, a space, the name.
cat > "$build/expected.txt" <<'EXPECTED'
0,0,0 black
255,255,255 white
128,128,128 gray
200,200,200 gray
1,1,1 black
254,254,254 white
255,0,0 dark red
0,255,0 vibrant green
0,0,255 very dark blue
255,255,0 very light vibrant yellow
0,255,255 vibrant cyan
255,0,255 dark magenta
128,0,0 dark red
0,128,0 green
0,0,128 very dark blue
255,165,0 bright orange
165,42,42 dark red
255,192,203 light red
128,128,0 yellow
0,128,128 cyan
128,0,128 dark magenta
EXPECTED
if [ "$wrong" -eq 1 ]; then
    # The control for the control: one recorded answer is deliberately wrong, so this run must fail, and
    # a check that cannot fail is not a check.
    sed -i '' 's/^255,165,0 bright orange$/255,165,0 dark magenta/' "$build/expected.txt"
    echo "control	one recorded answer was changed on purpose; the check below must fail"
fi
known_answer_check

# Each fit writes its own output to a file, its own status is checked, and only then is the file
# grepped. A fit behind a pipe takes grep's status instead of its own, so a fit that crashes or that
# refuses its sample left the run running and exiting 0 with a block of figures on screen; this shape is
# the one the rest of this tree's runners use, because it is the only one where a tool's failure is the
# script's failure.
fit() {
    # $1 the tool, $2 the file its output goes to, $3 the lines to show
    if ! xmake l "$1" "$build/fit.tsv" > "$build/$2.txt" 2>&1; then
        echo "$1 failed, and this run stops here:" >&2
        cat "$build/$2.txt" >&2
        exit 1
    fi
    grep -E "$3" "$build/$2.txt"
}

echo
echo "=== the four spaces, nearest prototype per hue word"
fit "$here/fit.lua" fit "^fit rows|^distinct|^space|^near-neutral|^refused"
echo
echo "=== the hue angle as a partition"
fit "$here/fit-angle.lua" fit-angle "^distinct colours|^chromatic points|^contiguous runs|^refused"
