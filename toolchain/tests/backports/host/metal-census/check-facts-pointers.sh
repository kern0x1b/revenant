#!/bin/sh
# check-facts-pointers.sh - every `implemented` row's facts pointer must LEAD to the file it names.
#
#     sh tests/backports/host/metal-census/check-facts-pointers.sh
#     SELF_TEST=1 sh tests/backports/host/metal-census/check-facts-pointers.sh
#
# A `facts` field is a promise a reader relies on: they ask the registry where a row is written down
# and go there. A pointer to a file that does not exist, or to one that never mentions the symbol, is
# a promise that cannot be kept, and NOTHING ELSE IN THE TREE NOTICES - the row compiles, the case
# runs, the gate passes. The 14.0 rows landed with no pointer at all, and the four rows that had one
# pointed at a file that did not exist. Both were invisible until this read the registry.
#
# It reads the REGISTRY, so a row cannot be flipped without a pointer that resolves.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
reg=$root/packages/frameworks/apple-backports/registry/Metal/absent_Metal.json
pkg=$root/packages/frameworks/apple-backports
factsroot=$root/packages/frameworks/apple-backports/facts
work=${WORK:-$(runs_folder metal-census/facts-pointers)}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -rf "$work"
mkdir -p "$work"

# $1 registry, $2 package dir -> one line per implemented row that cannot be followed.
broken() {
    runs_xmake l "$here/checks.lua" facts-broken "$1" "$2"
}

# THE RED CONTROL: a copy of the registry with one row's pointer made to lead nowhere, and one with
# it removed, and BOTH must be named. A check that cannot go red proves nothing. The control runs in
# process on a copy of the registry: a row with a pointer to a file that does not exist, a row with no
# pointer, and a row re-pointed at a REAL file that names the row's API only INSIDE a longer
# identifier - Heaps.md names MTLAccelerationStructureCommandEncoder, which contains
# MTLAccelerationStructure. A bare substring test passes that; only an identifier-boundary match
# refuses it.
if [ -n "${SELF_TEST:-}" ]; then
    runs_xmake l "$here/checks.lua" facts-control "$reg" "$factsroot" "$pkg" || { rm -rf "$work"; exit 1; }
    if out=$(broken "$reg" "$pkg") && [ -n "$out" ]; then
        echo "FAIL: the real tree has rows whose pointer does not lead:" >&2
        printf '%s\n' "$out" | sed 's/^/    /' >&2
        rm -rf "$work"; exit 1
    fi
    echo "  ok   the self-test's POSITIVE: every implemented row's pointer leads to the file"
    rm -rf "$work"
    exit 0
fi

if out=$(broken "$reg" "$pkg"); then
    if [ -n "$out" ]; then
        echo "FAIL: these implemented rows do not lead where their facts pointer says:" >&2
        printf '%s\n' "$out" | sed 's/^/    /' >&2
        exit 1
    fi
fi
count=$(runs_xmake l "$here/checks.lua" facts-count "$reg")
echo "  every implemented row's facts pointer leads to a file that mentions it: $count row(s)"
echo "check-facts-pointers: OK"
# THE SCRATCH IS REMOVED HERE.
rm -rf "$work"
