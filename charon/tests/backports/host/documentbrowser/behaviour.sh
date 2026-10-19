#!/bin/sh
# behaviour.sh -- run the document browser's five methods on the host, and then break each behaviour
# once and watch the test name it.
#
# The port's file is compiled against a stand-in for the one UIKit interface it needs, so what runs is
# the port's own code and not a description of it. Everything is built and run under
# .agent-work/runs/documentbrowser/, never in a system temp path and never in the shared SDK, and
# every mutant is restored from HEAD, so the tree is as it was whether this passes or not.
#
#   DDR_ROOT=<the checkout> sh tests/backports/host/documentbrowser/behaviour.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=${DDR_ROOT:-$here/../../../..}
runs=$root/.agent-work/runs/documentbrowser
port=$root/packages/a/apple-backports/UIKit/UIDocumentBrowserViewController.m
mkdir -p "$runs"

# The port's file as it is when the run starts, so every mutant is put back to exactly that and an
# uncommitted edit survives a run instead of being overwritten by HEAD.
saved=$runs/port-as-found.m
cp "$port" "$saved"

build_and_run() {
    label=$1
    work=$runs/$label
    rm -rf "$work"
    mkdir -p "$work"
    # The stand-in for UIView's animation is compiled in, and the port's file is told to use it.
    xcrun clang -fobjc-arc -DCHARON_TRANSITION_ANIMATION_STANDIN \
        -I "$here/host-stub" -I "$root/packages/a/apple-backports/UIKit" \
        -framework Foundation \
        "$port" "$root/packages/a/apple-backports/UIKit/UIDocumentBrowserTransitionController.m" \
        "$here/host-stub/UIKit/UIViewController.m" \
        "$here/host-stub/UIKit/UIViewControllerTransitioning.m" \
        "$here/behaviour.m" \
        -o "$work/behaviour" 2> "$work/build.log" || {
            echo "$label: BUILD-FAIL"; head -5 "$work/build.log"; return 1; }
    "$work/behaviour" > "$work/run.log" 2>&1 || true
    tail -1 "$work/run.log" | sed "s/^/$label: /"
    return 0
}

# The clean run first: it has to pass, or a mutant failing proves nothing.
echo "== the clean run"
build_and_run clean || exit 1
clean_failures=$(grep -c '^FAIL' "$runs/clean/run.log" || true)
if [ "$clean_failures" != "0" ]; then
    echo "the clean run already fails, so the mutants below would prove nothing"
    exit 1
fi

# One mutant per behaviour, each expected to turn one named check red. The file is restored from
# HEAD after every one, so the next mutant starts from the port's own source.
mutate() {
    name=$1
    from=$2
    to=$3
    expected=$4
    echo
    echo "== the mutant: $name"
    python3 - "$port" "$from" "$to" <<'PYMUT'
import sys
path, before, after = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
assert s.count(before) == 1, "the mutation site was not found exactly once"
open(path, "w").write(s.replace(before, after))
PYMUT
    build_and_run "mutant-$name" || true
    if grep -q "^FAIL .*$expected" "$runs/mutant-$name/run.log"; then
        echo "  red by name: $expected"
    else
        echo "  NOT CAUGHT: the mutant did not turn '$expected' red"
        mutant_missed=1
    fi
    # Restored from the copy taken when the run started, not from HEAD: a run must not silently
    # destroy an uncommitted edit of the port's file, which is how a real change went missing once.
    cp "$saved" "$port"
}

mutant_missed=0
mutate move-leaves-source \
    '? [files moveItemAtPath:documentURL.path toPath:destination.path error:NULL]' \
    '? [files copyItemAtPath:documentURL.path toPath:destination.path error:NULL]' \
    'a move takes the document from where it was'

mutate copy-removes-source \
    ': [files copyItemAtPath:documentURL.path toPath:destination.path error:NULL];' \
    ': ([files copyItemAtPath:documentURL.path toPath:destination.path error:NULL],
           [files removeItemAtPath:documentURL.path error:NULL]);' \
    'a copy leaves the source where it was'

mutate completion-called-twice \
    '    completionHandler(destination, nil);' \
    '    completionHandler(destination, nil);
    completionHandler(destination, nil);' \
    'a move answers its completion exactly once'

# The reveal-with-import path needs a document provider, which this release and this host have
# none of, so it is skipped above and cannot be mutated here. This one is the reveal behaviour that
# *is* run: a document that is here is answered with where it is, and a reveal that ignored that
# and always failed instead is caught by name.
mutate reveal-ignores-a-document-that-is-here \
    '    if ([files fileExistsAtPath:url.path]) {
        completion(url, nil);
        return;
    }' \
    '    if (0) {
        completion(url, nil);
        return;
    }' \
    'a reveal of a document that is here answers with where it is'

git -C "$root" diff --quiet -- packages/a/apple-backports/UIKit/UIDocumentBrowserViewController.m \
    && echo && echo "the port's file is as it was: git diff is empty" \
    || { echo; echo "the port's file is NOT as it was"; exit 1; }

if [ "$mutant_missed" = "0" ]; then
    echo
    echo "PASS: every behaviour runs, and every mutant is red by name"
else
    echo
    echo "FAIL: a mutant was not caught"
    exit 1
fi
