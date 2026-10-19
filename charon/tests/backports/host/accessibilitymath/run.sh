#!/bin/sh
# accessibilitymath/run.sh - the AXMathExpression classes of iOS 18.2 and AXCustomContent of 14.0
# against the host's own Accessibility.framework.
#
# The system builds these sixteen classes and the port builds the same sixteen in
# Accessibility/CharonAXMathExpression.m and Accessibility/CharonAXCustomContent.m. The check is: build
# the same tree in both, ask both the same questions, and the two answers must be the same.
#
# It runs on the host because the host has the framework - its SDK carries AXMathExpression.h, the very
# file iPhoneOS 26.2 carries - and the two implementations are compiled into one program, the port's
# under names the system does not use, so neither can answer for the other. The port half links no
# Accessibility framework: its classes are its own.
#
# What is checked that is not a comparison of the two answers, and each says so: the cases whose labels
# start with "declaration." check a declaration, not the port's code. Their answers come from whichever
# header each side compiled against, so a change to Apple's header moves them and nothing in packages/
# can. They are counted apart from the behaviour cases and the summary line says how many of each.
#
# Three answers are declared to differ, all of them AXMathExpressionRow and AXMathExpressionTable
# answering the array their initialiser was given where the host answers nil; expected-differences.tsv
# carries the measurement and the reason. Nothing else is declared, so an answer that moves and was not
# declared is a failure of this case.
#
# Usage: sh tests/backports/host/accessibilitymath/run.sh
#        ACCESSIBILITY_SRC=<dir>   build another copy of the port's sources (mutants.sh)
#        BUILD=<dir>               where the two programs and their output go
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
sources=${ACCESSIBILITY_SRC:-$root/packages/a/apple-backports/Accessibility}
build=${BUILD:-$root/.agent-work/runs/accessibilitymath}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
if [ ! -f "$sdk/System/Library/Frameworks/Accessibility.framework/Headers/AXMathExpression.h" ]; then
    echo "this host's SDK has no AXMathExpression, so the oracle is not here" >&2
    exit 2
fi
target=arm64-apple-macos26.0
common="-target $target -isysroot $sdk -fobjc-arc -O0 -Wall -Wno-nonnull -Wno-objc-protocol-property-synthesis"

# The port's own spelling of every class this case names. A -D renames the declaration as well, which
# is what keeps the two halves from colliding, and the port's CharonAXMathExpression.h is what it
# renames the declarations in.
renames="-DAXMathExpression=CharonPortAXMathExpression
-DAXMathExpressionNumber=CharonPortAXMathExpressionNumber
-DAXMathExpressionIdentifier=CharonPortAXMathExpressionIdentifier
-DAXMathExpressionOperator=CharonPortAXMathExpressionOperator
-DAXMathExpressionText=CharonPortAXMathExpressionText
-DAXMathExpressionFenced=CharonPortAXMathExpressionFenced
-DAXMathExpressionRow=CharonPortAXMathExpressionRow
-DAXMathExpressionTable=CharonPortAXMathExpressionTable
-DAXMathExpressionTableRow=CharonPortAXMathExpressionTableRow
-DAXMathExpressionTableCell=CharonPortAXMathExpressionTableCell
-DAXMathExpressionUnderOver=CharonPortAXMathExpressionUnderOver
-DAXMathExpressionSubSuperscript=CharonPortAXMathExpressionSubSuperscript
-DAXMathExpressionFraction=CharonPortAXMathExpressionFraction
-DAXMathExpressionMultiscript=CharonPortAXMathExpressionMultiscript
-DAXMathExpressionRoot=CharonPortAXMathExpressionRoot
-DAXMathExpressionProvider=CharonPortAXMathExpressionProvider
-DAXCustomContent=CharonPortAXCustomContent"

host_build() {
    xcrun clang $common "$here/cases.m" -framework Foundation -framework Accessibility \
        -o "$build/host" 2> "$build/host-build.log" || return 1
}
port_build() {
    # the renames are a list of -D flags and have to reach the shell unquoted
    # shellcheck disable=SC2086
    xcrun clang $common $renames "$here/cases.m" \
        "$sources/CharonAXMathExpression.m" "$sources/CharonAXCustomContent.m" \
        -I"$sources" -framework Foundation -o "$build/port" 2> "$build/port-build.log" || return 1
}
for half in host port; do
    if ! $half"_build"; then
        echo "the $half half did not build" >&2
        tail -20 "$build/$half-build.log" >&2
        exit 1
    fi
    "$build/$half" > "$build/$half.tsv" 2> "$build/$half.stderr" || {
        echo "the $half half did not run to its end" >&2
        tail -20 "$build/$half.stderr" >&2
        exit 1
    }
done

cases=$(wc -l < "$build/host.tsv" | tr -d ' ')
# awk and not grep -c: a count of zero is an answer here, and grep -c exits 1 when it counted nothing,
# which under -e would end the script on a case that passed.
behaviour=$(awk '!/^declaration\./' "$build/host.tsv" | wc -l | tr -d ' ')
declarations=$(awk '/^declaration\./' "$build/host.tsv" | wc -l | tr -d ' ')
# The file's own rows and not its lines: it carries a header and lines that say why it has no rows, and
# counting lines would report differences nobody declared.
declared=$(awk -F'\t' 'NR>1 && $0 !~ /^#/ && NF>1' "$here/expected-differences.tsv" | wc -l | tr -d ' ')
echo "=== the two answers: $cases cases a side ($behaviour behaviour, $declarations declaration), $declared declared to differ"

# The comparison is in a condition and not under -e: a run whose answers do not match has to go on to
# print the diff, and a bare `python3 compare.py` under `set -e` leaves the script at that line, which
# is what the first version of the chart case did - a failure report six lines long that no failure
# could ever reach.
if python3 "$here/../common/compare.py" "$build/host.tsv" "$build/port.tsv" "$here/expected-differences.tsv"; then
    # Said with the verdict and not beside it, so the line cannot be read as "N cases nothing looked
    # at": compare.py has just compared them and found no undeclared difference, and this is what it
    # compared.
    echo "identical on all $((cases - declarations)) behaviour cases except the $declared declared above: the system and the port answer the same"
    echo "declaration cases: $declarations, which check a header and not the port's code; compared above, $declarations of $declarations the same"
    exit 0
fi
echo "the two answers do not match what this case declares"
if ! diff -u "$build/host.tsv" "$build/port.tsv"; then
    # The whole diff, and not a summary of it: the point of printing it is that a reader can see which
    # case moved without re-running anything.
    :
fi
exit 1
