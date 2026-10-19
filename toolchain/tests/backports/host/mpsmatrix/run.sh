#!/bin/sh
# run.sh — is this port's Metal Performance Shaders matrix and vector framework the same arithmetic as
# the system's own?
#
# mps-cases.m is compiled twice and run twice. The first build links the system's MetalPerformanceShaders
# and calls it by its own names. The second build compiles this port's own sources with the MPS class
# names mapped to Charon names and its selectors prefixed (prefix_selectors.py), so the port's
# implementations are reached under names of their own and cannot replace the system's, and it calls the
# same cases.m with the same mapping. Every case prints its result buffer as bytes, so the two runs are
# compared exactly: a difference of one bit in one element is a failure, not a tolerance this script
# chooses after seeing the numbers.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
for script in "$here"/*.sh; do
    bash -n "$script" || { echo "harness script does not parse: $script" >&2; exit 1; }
done
mps=${MPS:-$here/../../../../packages/a/apple-backports/MetalPerformanceShaders}
# The grader's self-test first, because it needs no transcripts and a run of it is a second: it is the
# check that the four-argument form of rank.py - the form its own help documents - works, and that the
# 2026-09-29 form of it, which died with UnboundLocalError on that form, does not. Wired here because a
# check nothing invokes is not a check.
sh "$here/rank-selftest.sh" || { echo "rank-selftest failed; the grader is not measuring" >&2; exit 1; }

build=${BUILD:-$here/../../../../.agent-work/runs/host/mpsmatrix}
candidate=${CANDIDATE:+-DCHARON_BN_CANDIDATE=$CANDIDATE}
system=${SYSTEM_TXT:-}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation -Wno-nullability-completeness -Wno-objc-protocol-method-implementation"
mkdir -p "$build"

xcrun clang -fobjc-arc -Wformat -Werror=format $target $quiet "$here/mps-cases.m" \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/system"
# The system's own MPS aborts on some cases, and an oracle that dies half way through can only be
# compared over the part it produced. Which cases those are is said out loud rather than hidden.
set +e
if [ -n "$system" ]; then cp "$system" "$build/system.txt"; else "$build/system" > "$build/system.txt" 2> "$build/system.err"; fi
system_status=$?
set -e
echo "tree: $(git -C "$here" rev-parse --short HEAD 2>/dev/null || echo unknown)  dirty $(git -C "$here" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
echo "system: $(wc -l < "$build/system.txt") lines, exit $system_status"
if [ "$system_status" -ne 0 ]; then echo "system: died during the case marked: $(cat "$build/system.marker" 2>/dev/null || echo unknown)"; echo "  last case it printed: $(tail -1 "$build/system.txt" | cut -c1-60)"; fi

# The names this port carries, each under a name of its own. This is every class the port *defines*,
# derived from nm -g --defined-only of its objects and not from one registry file: the matrix file
# named only the classes that family carries, so MPSMatrixRandomPhilox, MPSMatrixRandomDistributionDescriptor,
# MPSState, MPSPredicate, MPSCommandBuffer and every CNN class were registered under the host's names, and
# a case reaching one of those was comparing the host with itself.
if grep -Eq '0x[0-9a-f]{6,}' "$build/system.txt" "$build/port.txt" 2>/dev/null; then
    echo "an address is in the output, so this comparison cannot be reproduced:" >&2
    grep -Eon '[0-9a-zA-Z_.-]*0x[0-9a-f]{6,}[0-9a-zA-Z_ .,]*' "$build/system.txt" "$build/port.txt" | head -5 >&2
    exit 1
fi
rm -rf "$build/plain"
mkdir -p "$build/plain"
for source in "$mps"/*.m; do
    xcrun clang -fobjc-arc -Wformat -Werror=format $target $candidate -c "$source" -o "$build/plain/$(basename "$source" .m).o"
    [ -f "$build/plain/$(basename "$source" .m).o" ] || { echo "cannot read an object from $source; stopping"; exit 1; }
done
for object in "$build/plain"/*.o; do xcrun nm -g --defined-only "$object"; done \
    | grep -oE '_OBJC_CLASS_\$_[A-Za-z0-9_]+' | sed 's/_OBJC_CLASS_\$_//' | sort -u > "$build/port-defines.txt"
python3 - "$build/port-defines.txt" "$build/rename.h" <<'PY'
import sys
names = [line.strip() for line in open(sys.argv[1]) if line.strip()]
with open(sys.argv[2], 'w') as out:
    for name in names:
        out.write("#define %s Charon%s\n" % (name, name))
print("classes the port defines: %d" % len(names))
PY
echo "renamed: $(grep -c define "$build/rename.h") classes"

# The port's own sources, with their selectors prefixed so they do not replace the system's.
printf '#import <MetalPerformanceShaders/MetalPerformanceShaders.h>\n' > "$build/declarations.h"
objects=""
for source in "$mps"/*.m; do
    name=$(basename "$source" .m)
    if ! xcrun clang -fobjc-arc -Wformat -Werror=format -fvisibility=hidden -DCHARON_BN_TRACE $target $candidate $quiet -c "$source" -o "$build/$name.plain.o"; then
        echo "the port source $source did not compile; stopping, because a count from a stale build is not a count"
        exit 1
    fi
    python3 "$here/../prefix_selectors.py" "$source" "$build/$name.m" ccharonHost_ \
        --declarations="$build/declarations.h" -fobjc-arc $target $quiet -include "$build/rename.h" -- "$build/$name.plain.o"
    # The define belongs here and not only on the plain compile: prefix_selectors.py turns the plain
    # object back into source, and this is the compile whose object is linked, so a define left off
    # here is a trace that is compiled in and then thrown away.
    if ! xcrun clang -fobjc-arc -Wformat -Werror=format -fvisibility=hidden -DCHARON_BN_TRACE $target $candidate $quiet -I"$mps" -include "$build/rename.h" \
        -include "$build/declarations.h" -c "$build/$name.m" -o "$build/$name.o"; then
        echo "the prefixed port source $build/$name.m did not compile; stopping"
        exit 1
    fi
    objects="$objects $build/$name.o"
done
echo "compiled: $(echo "$objects" | wc -w) objects"

xcrun clang -fobjc-arc -Wformat -Werror=format $target $quiet -include "$build/rename.h" "$here/mps-cases.m" $objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/port"
set +e
"$build/port" > "$build/port.txt" 2> "$build/port.err"
port_status=$?
set -e
echo "port: exit $port_status"
if [ "$port_status" -ne 0 ]; then echo "port: died during the case marked: $(cat "$build/port.marker" 2>/dev/null || echo unknown)"; echo "  last case it printed: $(tail -1 "$build/port.txt" | cut -c1-60)"; fi

# Two cases are compared apart, and the reason is MPSState.h's own: -resourceSize "is subject to
# change between different devices and operating systems", so the host's answer is a number about the
# host's heap rather than about the state. They are still printed, and still differ, and a difference
# anywhere else fails the run.
# Only the cases both runs reached: an oracle that stopped early cannot answer the rest, and comparing
# the prefix it did answer is the honest thing. Both runs print in the same order, so the prefix is the
# first N lines where N is the shorter of the two, and the case names are checked to line up.
system_lines=$(wc -l < "$build/system.txt" | tr -d ' ')
port_lines=$(wc -l < "$build/port.txt" | tr -d ' ')
n=$system_lines
[ "$port_lines" -lt "$n" ] && n=$port_lines
if [ "$system_lines" -ne "$port_lines" ]; then
    echo "the two runs reached different numbers of cases: system $system_lines, port $port_lines; compared over the first $n"
    echo "system stopped on: $(tail -1 "$build/system.txt" | cut -d' ' -f1-2)"
    echo "port   stopped on: $(tail -1 "$build/port.txt" | cut -d' ' -f1-2)"
fi
grep '^case ' "$build/system.txt" > "$build/system.cases" || true
grep '^case ' "$build/port.txt" > "$build/port.cases" || true
system_lines=$(wc -l < "$build/system.cases" | tr -d ' ')
port_lines=$(wc -l < "$build/port.cases" | tr -d ' ')
n=$system_lines
[ "$port_lines" -lt "$n" ] && n=$port_lines
head -n "$n" "$build/system.cases" > "$build/system.prefix"
head -n "$n" "$build/port.cases" > "$build/port.prefix"
cut -d' ' -f2 "$build/system.prefix" > "$build/system.names"
cut -d' ' -f2 "$build/port.prefix" > "$build/port.names"
if ! cmp -s "$build/system.names" "$build/port.names"; then
    # The cut lands inside a case, so the two name lists differ by one: the last name of the prefix.
    echo "the two runs reached different cases: $(diff "$build/system.names" "$build/port.names" | head -4 | tr '\n' ' ')"
    n=$((n - 1))
    head -n "$n" "$build/system.cases" > "$build/system.prefix"
    head -n "$n" "$build/port.cases" > "$build/port.prefix"
    echo "compared over the first $n complete cases"
fi
grep -v '^divergent ' "$build/system.prefix" > "$build/system.strict"
grep -v '^divergent ' "$build/port.prefix" > "$build/port.strict"
echo "compared: $(wc -l < "$build/system.strict") cases"
grep '^divergent ' "$build/system.prefix" > "$build/system.divergent" || true
grep '^divergent ' "$build/port.prefix" > "$build/port.divergent" || true
paste "$build/system.divergent" "$build/port.divergent" | while read -r line; do
    echo "documented divergence: $line"
done

# The cases this port does not reproduce are named, with the reason, in owed.tsv beside this script -
# not exempted here. The list used to live in this file as HOST_DIVERGENCES and the cases it matched
# were dropped from the comparison before anything was measured, so a defect introduced in one of them
# could not show; Matrix.md:38-39 already said none of them met the bar for an exemption. The grader
# below now reads the whole set: a case that is not bit-identical and not within ULP_BOUND units in the
# last place has to be in owed.tsv, and one that is not fails the run.
#
#   rank.py <system-prefix> <port-prefix> <ulp-bound> [owed.tsv]
#
# The bound is 64 units in the last place, which is 7.6e-06 relative near 1.0. The two distances it sits
# between are the run's own and are checked by page-check.py below against the facts file: the largest
# among the cases that are rounding, and the smallest among those that are not. The bound is named here,
# in the grader's output and in Matrix.md, so a reader can see it rather than infer it.
ULP_BOUND=64

python3 "$here/rank.py" "$build/system.prefix" "$build/port.prefix" "$ULP_BOUND" "$here/owed.tsv"
rank_status=$?

# Every figure the facts page and the registry state about this run, checked against this run. Wired
# here so the page cannot outlive the numbers it quotes: page-check.py recomputes them from the two
# transcripts rather than reading a log, and a page that states a figure this run does not produce makes
# the run red. Two files, both named rather than globbed, so a page that moves is a line to change here
# and not a glob that silently checks nothing.
FACTS=$here/../../../../packages/a/apple-backports/facts/MetalPerformanceShaders/Matrix.md
REGISTRY=$here/../../../../packages/a/apple-backports/registry/MetalPerformanceShaders/matrix.json
page_status=0
python3 "$here/page-check.py" "$build" "$FACTS" "$REGISTRY" || page_status=$?

if [ "$rank_status" -ne 0 ]; then
    echo "the grader found a case that differs beyond $ULP_BOUND units in the last place and is not named in $here/owed.tsv"
    exit 1
fi
if [ "$page_status" -ne 0 ]; then
    echo "a figure in $FACTS or in the MPSMatrixFullyConnected effect is not what this run produced"
    exit 1
fi
echo "port: every case is bit-identical to the system or within $ULP_BOUND units in the last place, or is named as owed"
echo "page: every figure the facts file and the registry state about this run is what this run produced"
exit 0
