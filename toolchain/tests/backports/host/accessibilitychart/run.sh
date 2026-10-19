#!/bin/sh
# accessibilitychart/run.sh - the chart and data classes of iOS 15.0 against the host's own
# Accessibility.framework.
#
# The system builds these seven classes and the port builds the same seven in
# Accessibility/RevenantChartDescriptors.m. The check is: build the same tree in both and ask both the
# same questions, and the two answers must be the same.
#
# It runs on the host because the host has the framework - its SDK carries AXAudiograph.h, the very
# file the port's own SDK of 16.4 carries - and the two implementations are compiled into one program,
# the port's under names the system does not use, so neither can answer for the other. The port half
# links no Accessibility framework: its classes are its own.
#
# Three things are checked that are not a comparison of the two answers, and each says so:
#
#   * the cases whose labels start with "declaration." check a declaration, not the port's code. Their
#     members come from whichever header each side compiled against, so a change to Apple's header moves
#     them and nothing in packages/ can. They are counted apart from the behaviour cases and the summary
#     line says how many of each there were.
#   * AXLiveAudioGraph publishes sound, and a program cannot read sound, so what is compared for it is
#     the shape of the class and how many times each of its three members was called.
#   * the once-only part of the inert contract is a log line, which is not a value, so it is counted on
#     the port alone: the port must write exactly one line per member of the graph however many times the
#     case called it, and the counts it is held to are the ones the case printed. The host writes no such
#     line because the system's three methods publish sound, which is the whole difference between the
#     two implementations here and it is not hidden by leaving it out of the comparison.
#
# Usage: sh tests/backports/host/accessibilitychart/run.sh
#        ACCESSIBILITY_SRC=<dir>   build another copy of the port's sources (mutants.sh)
#        BUILD=<dir>               where the two programs and their output go
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
sources=${ACCESSIBILITY_SRC:-$root/packages/a/apple-backports/Accessibility}
build=${BUILD:-$(runs_folder revenant-accessibilitychart)}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
if [ ! -f "$sdk/System/Library/Frameworks/Accessibility.framework/Headers/AXAudiograph.h" ]; then
    echo "this host's SDK has no AXAudiograph, so the oracle is not here" >&2
    exit 2
fi
target=arm64-apple-macos26.0
common="-target $target -isysroot $sdk -fobjc-arc -O0 -Wall -Wno-nonnull -Wno-objc-protocol-property-synthesis"

# The port's own spelling of every class this case names, and of the two protocol names it looks up as
# strings. A -D renames the declaration as well, which is what keeps the two halves from colliding.
renames="-DAXChartDescriptor=RevenantPortAXChartDescriptor
-DAXDataSeriesDescriptor=RevenantPortAXDataSeriesDescriptor
-DAXDataPoint=RevenantPortAXDataPoint
-DAXDataPointValue=RevenantPortAXDataPointValue
-DAXNumericDataAxisDescriptor=RevenantPortAXNumericDataAxisDescriptor
-DAXCategoricalDataAxisDescriptor=RevenantPortAXCategoricalDataAxisDescriptor
-DAXLiveAudioGraph=RevenantPortAXLiveAudioGraph
-DAXChart=RevenantPortAXChart
-DAXDataAxisDescriptor=RevenantPortAXDataAxisDescriptor
-DAXCHART_PROTOCOL=@\"RevenantPortAXChart\"
-DAXDATAAXISDESCRIPTOR_PROTOCOL=@\"RevenantPortAXDataAxisDescriptor\""

# The protocols' metadata is what lets a caller declare conformance, and in the port it comes from the
# object modules/apple/backports.lua generates out of the registry's implemented protocol rows. Only the
# port half is given it, because that object is part of what the port ships and the host half has no such
# object to give: the system's Accessibility framework carries the protocol itself, and cases.m's own
# adopter class is what puts it in the host program. Giving this file to both halves would have made the
# AXChart cases compare the case's own file with itself, which is what the review found.
cat > "$build/protocols.m" <<'PROTOCOLS'
#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
static void revenant_case_protocols(void) __attribute__((used));
static void revenant_case_protocols(void)
{
    (void)@protocol(AXChart);
    (void)@protocol(AXDataAxisDescriptor);
}
PROTOCOLS

host_build() {
    xcrun clang $common "$here/cases.m" -framework Foundation -framework Accessibility \
        -framework CoreGraphics -o "$build/host" 2> "$build/host-build.log" || return 1
}
port_build() {
    # the renames are a list of -D flags and have to reach the shell unquoted
    # shellcheck disable=SC2086
    xcrun clang $common $renames "$here/cases.m" "$sources/RevenantChartDescriptors.m" "$build/protocols.m" \
        -I"$root/packages/a/apple-backports" -framework Foundation -framework CoreGraphics \
        -o "$build/port" 2> "$build/port-build.log" || return 1
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
# print the diff, and a bare `python3 compare.py` under `set -e` leaves the script at that line, which is
# what the first version did - a failure report six lines long that no failure could ever reach.
if xmake l "$here/../common/compare.lua" "$build/host.tsv" "$build/port.tsv" "$here/expected-differences.tsv"; then
    # The once-only part of the inert contract, counted on the port alone against the case's own counts.
    log=$build/port.stderr
    for member in start updateValue stop; do
        calls=$(awk -F'\t' -v m="graph.calls.$member" '$1==m {print $2}' "$build/port.tsv")
        lines=$(awk -v member="AXLiveAudioGraph +$member:" 'index($0, member) {n++} END {print n+0}' "$log")
        if [ "$lines" -ne 1 ]; then
            echo "the port wrote $lines lines for +[AXLiveAudioGraph $member], and the case called it ${calls} times: an inert member says so once, and once is what a caller gets"
            exit 1
        fi
        echo "say-once: +[AXLiveAudioGraph $member] called ${calls} times, $lines line in the port's log"
    done
    echo "identical on all $((behaviour)) behaviour cases: the system and the port answer the same"
    # Said with the verdict and not beside it, so the line cannot be read as "13 cases nothing looked at":
    # compare.py has just compared them and found no difference, and this is what it compared.
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
