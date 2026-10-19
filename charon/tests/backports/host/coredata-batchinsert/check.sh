#!/bin/sh
# The committed check for NSBatchInsertRequest: the framework's own class and the port's, asked the
# same ten questions, and the diff between the two answers.
#
#   ./check.sh        the control: an empty diff is green
#   ./check.sh mutant the wrong-ivar mutant: -init and the handler cross-assignment, in turn
#
# The mutants are steps of THIS check, not a separate entry point. mutant-init.sh is the driver for
# the -init one - it copies the port's source, mutates the copy, checks the copy BUILDS, runs the
# listing and diffs it against reference-host.tsv - and it is called from here so that one command
# is the whole check. mutant-init.py is the mutation, kept apart from the shell so that a
# multi-line edit cannot splice into a driver again, which is what broke an earlier version of this.
#
# Nothing persisted - the store in the other probe is NSInMemoryStoreType - and no CloudKit here.
# The reference is reference-host.tsv, generated on the host at build time and committed with the
# versions it came from (reference-host.OS.txt).
#
# THE PORT BINARY RENAMES THE CLASS, with -DNSBatchInsertRequest=CharonBatchInsertRequest, because it
# links -framework CoreData and the runtime answers "Class NSBatchInsertRequest is implemented in
# both CoreData and .../port" otherwise - a real collision for anything that links both. That is also
# why -init's reason text is the LITERAL and not NSStringFromClass: a class-name substitution would
# spell the renamed class where Apple spells NSBatchInsertRequest.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
FP=${COREDATA:-$here/../../../../packages/a/apple-backports}
build=${COREDATA_CHECK:-$here/../../../../.agent-work/runs/coredata-check}
rm -rf "$build"; mkdir -p "$build"

cp "$FP/CoreData/NSBatchInsertRequest.m" "$build/port.m"
grep -v '#import "CharonCoreData.h"' "$build/port.m" > "$build/port.buildable.m"
mv "$build/port.buildable.m" "$build/port.m"

echo "=== the port builds"
xcrun clang -fobjc-arc -w -DNSBatchInsertRequest=CharonBatchInsertRequest \
    -I"$FP/CoreData" -c "$build/port.m" -o "$build/port.o"

echo "=== the host and the port, as two processes"
xcrun clang -fobjc-arc -w "$here/per-initializer.m" \
    -framework Foundation -framework CoreData -o "$build/host"
xcrun clang -fobjc-arc -w -DNSBatchInsertRequest=CharonBatchInsertRequest \
    "$here/per-initializer.m" "$build/port.o" \
    -framework Foundation -framework CoreData -o "$build/port"

"$build/host" > "$build/host.txt" 2>/dev/null
"$build/port" > "$build/port.txt" 2>/dev/null
for side in host port; do
    lines=$(wc -l < "$build/$side.txt" | tr -d ' ')
    if [ "$lines" -lt 20 ]; then
        echo "NO ANSWER: the $side run printed $lines line(s) and twenty-two were asked for, so a"
        echo "diff of two empty or short files would be a green that measured nothing."
        exit 3
    fi
done

if [ "${1:-}" = "mutant" ]; then
    # Mutant 1: -init stops raising, via the driver, which checks the copy compiles.
    echo "=== MUTANT 1: -init stops raising"
    if ! "$here/mutant-init.sh"; then
        echo "MUTANT 1 FAILED: the driver does not report a red, so the check is not defended"
        exit 5
    fi
    # Mutant 2: the two handler initialisers put the handler in the other ivar again - the defect
    # a724920f found, mutated so the check the reviewer reads is the one that goes red on it.
    echo
    echo "=== MUTANT 2: the handler cross-assignment is back"
    python3 "$here/mutant-ivar.py" "$FP/CoreData/NSBatchInsertRequest.m" "$build/port.m"
    grep -v '#import "CharonCoreData.h"' "$build/port.m" > "$build/port.buildable.m"
    mv "$build/port.buildable.m" "$build/port.m"
    xcrun clang -fobjc-arc -w -DNSBatchInsertRequest=CharonBatchInsertRequest \
        -I"$FP/CoreData" -c "$build/port.m" -o "$build/port.o"
    xcrun clang -fobjc-arc -w -DNSBatchInsertRequest=CharonBatchInsertRequest \
        "$here/per-initializer.m" "$build/port.o" \
        -framework Foundation -framework CoreData -o "$build/port"
    "$build/port" > "$build/port.txt" 2>/dev/null || true
    if diff "$here/reference-host.tsv" "$build/port.txt" > "$build/diff2"; then
        echo "MUTANT 2 FAILED: the listing is identical to the host's, so the cross-assignment"
        echo "is not being measured and the check is not defended on that axis"
        exit 6
    fi
    grep -E 'initWithEntity:.*Handler:\.detail' "$build/diff2" || true
    echo "MUTANT 2: RED - $(wc -l < "$build/diff2" | tr -d ' ') line(s) differ"
    exit 0
fi

if diff "$build/host.txt" "$build/port.txt" > "$build/diff"; then
    echo "VERDICT: green - the port answers exactly what Apple's own answers, on all 22 lines"
    exit 0
fi
cat "$build/diff"
echo "VERDICT: RED - $(wc -l < "$build/diff" | tr -d ' ') line(s) differ"
exit 1
