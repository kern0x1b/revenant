#!/bin/sh
# The differential for NSBatchInsertRequest, built against the port's own .m and run. The shape is
# tests/backports/host/fileprovider/run.sh: the port's file compiled for the host with xcrun clang,
# the probe built and run, and the mutant applied to a COPY so the tree is never edited.
#
#   ./run.sh            the control
#   ./run.sh mutant     the port's file with one line changed, which must turn the diff red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FP=${FILEPROVIDER:-$here/../../../../packages/a/apple-backports}
build=${COREDATA_BUILD:-$(runs_folder revenant-coredata-batchinsert)}
rm -rf "$build"; mkdir -p "$build"

cp "$FP/CoreData/NSBatchInsertRequest.m" "$build/port.pristine.m"   # what a mutant is compared against
sed -i.bak '/#import "RevenantCoreData.h"/d' "$build/port.pristine.m" 2>/dev/null || true
rm -f "$build"/*.bak

# Two builds of the SAME probe: once against the port's class, once against the framework's own.
# The host Mac has a real NSBatchInsertRequest from the same header, so the two runs are the same
# questions asked of two implementations, and the verdict is the diff between them.
# Nothing is persisted: the store is NSInMemoryStoreType, and there is no CloudKit here.
# The PORT binary renames the class, with -DNSBatchInsertRequest=RevenantBatchInsertRequest, because it
# links -framework CoreData and the runtime answers "Class NSBatchInsertRequest is implemented in both
# CoreData and .../differential-port" otherwise: two definitions of one class, and which one answers
# is not the run's to choose. check.sh's header records this and per-initializer.m is built both ways
# under it; this probe is built the same way, so the port side asks its own class the same questions
# the host side asks the framework's. That is also why the port's -init raises with the reason text
# spelled out rather than through NSStringFromClass: a class-name substitution would print the renamed
# class where Apple prints NSBatchInsertRequest.
xcrun clang -fobjc-arc -w "$here/differential-host.m" \
    -framework Foundation -framework CoreData -o "$build/differential-host"
"$build/differential-host" > "$build/host.tsv"
asked=$(wc -l < "$build/host.tsv" | tr -d ' ')
LC_ALL=C sort "$build/host.tsv" > "$build/host.sorted"

# One build path for the control and for every mutant below, so a mutant cannot be defended by a build
# the control does not make.
build_and_run() {
    cp "$1" "$build/port.m"
    xcrun clang -fobjc-arc -w -DNSBatchInsertRequest=RevenantBatchInsertRequest \
        -I"$FP/CoreData" -c "$build/port.m" -o "$build/port.o"
    xcrun clang -fobjc-arc -w -DNSBatchInsertRequest=RevenantBatchInsertRequest \
        "$here/differential.m" "$build/port.o" \
        -framework Foundation -framework CoreData -o "$build/differential-port"
    "$build/differential-port" > "$build/port.tsv"
    LC_ALL=C sort "$build/port.tsv" > "$build/port.sorted"
}

# Both runs must have answered the same questions: a diff of two files of different lengths is a
# verdict about the questions and not about the answers, and a diff of two empty files is a green that
# measured nothing. The count is the host's own, so a question added to the probe needs no number here.
if [ "$asked" -lt 20 ]; then
    echo "NO ANSWER: the host run printed $asked line(s) and twenty are asked for, so a diff of two"
    echo "empty or short files would be a green that measured nothing."
    exit 3
fi

# A MUTATION THAT CHANGED NOTHING IS NOT A MUTANT, and a runner that prints MUTANT either way makes a
# green control look defended: the copy is compared against the file as it was before the mutation.
mutate() { # NAME, SED EXPRESSION, WHAT IT BREAKS
    cp "$build/port.pristine.m" "$build/mutant.m"
    sed -i '' "$2" "$build/mutant.m"
    if cmp -s "$build/port.pristine.m" "$build/mutant.m"; then
        echo "MUTANT FAILED: $1 left the file byte-identical, so nothing was mutated and a green"
        echo "verdict would prove nothing. The sed target is not in the file."
        exit 2
    fi
    build_and_run "$build/mutant.m"
    answered=$(wc -l < "$build/port.tsv" | tr -d ' ')
    if [ "$answered" != "$asked" ]; then
        echo "MUTANT FAILED: $1 answered $answered line(s) where the host answered $asked, so the"
        echo "diff below would be about the questions and not about what the mutation broke."
        exit 2
    fi
    if diff "$build/host.sorted" "$build/port.sorted" > "$build/diff"; then
        echo "MUTANT FAILED: $1 is green, so $3 is not measured and the check is not defended on it"
        exit 2
    fi
    echo "MUTANT $1: RED - $(grep -c '^<' "$build/diff") line(s) differ, which is $3"
    grep '^<' "$build/diff" | head -4 | sed 's/^/    /'
}

if [ "${1:-}" = "mutant" ]; then
    # Each of the two rules the release's own class measured, one mutation each. A request with no
    # rows keeps neither the name nor the entity: the mutation puts the storage back unconditionally.
    mutate rows 's/if (self \&\& dictionaries.count) {/if (self) {/g' \
        "a request with no rows keeps what it was given"
    # -entity refuses a request that was made with a name: the mutation answers nil instead.
    mutate entity 's/if (!_revenantEntity \&\& _revenantEntityName) {/if (NO) {/' \
        "-entity answers nil where the release refuses"
    exit 0
fi

build_and_run "$build/port.pristine.m"
if [ "$(wc -l < "$build/port.tsv" | tr -d ' ')" != "$asked" ]; then
    echo "NO ANSWER: the port run did not answer the $asked questions the host run did."
    exit 3
fi

# The verdict is the host's answers against the port's. The table of expected values only
# DOCUMENTS the run now; it is not what green means.
echo "--- host.tsv"; cat "$build/host.tsv"
if diff "$build/host.sorted" "$build/port.sorted" > "$build/diff"; then
    echo "VERDICT: green - the port answers exactly what Apple's own answers, on all $asked lines"
    exit 0
fi
cat "$build/diff"
echo "VERDICT: RED - $(wc -l < "$build/diff" | tr -d ' ') line(s) of diff"
exit 1
