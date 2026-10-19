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
root=$(cd "$here/../../../.." && pwd)
reg=$root/packages/a/apple-backports/registry/Metal/absent_Metal.json
pkg=$root/packages/a/apple-backports
factsroot=$root/packages/a/apple-backports/facts
work=${WORK:-$root/.agent-work/runs/metal-census/facts-pointers}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -rf "$work"
mkdir -p "$work"

# $1 registry, $2 package dir -> one line per implemented row that cannot be followed.
broken() {
    python3 - "$1" "$2" <<'PY'
import glob, json, os, re, sys
reg, pkg = sys.argv[1], sys.argv[2]
doc = json.load(open(reg, encoding="utf-8"))
for row in doc["entries"]:
    if row.get("status") != "implemented":
        continue
    api, facts = row["api"], row.get("facts")
    if not facts:
        print("%-46s no facts pointer at all" % api)
        continue
    path = os.path.join(pkg, facts)
    if not os.path.isfile(path):
        print("%-46s points at %s, which does not exist" % (api, facts))
        continue
    # and the file must actually LEAD to the symbol, ON AN IDENTIFIER BOUNDARY. A bare substring
    # test is not enough and this is how it failed: MTLAccelerationStructure is a substring of
    # MTLAccelerationStructureCommandEncoder, so a row re-pointed at a facts file that names only
    # the command encoder passed. A file is evidence only if it names THIS symbol and not as a
    # prefix of a longer one, so the match needs a boundary on both sides.
    text = open(path, encoding="utf-8").read()
    if not re.search(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % re.escape(api), text):
        print("%-46s points at %s, which names it only inside a longer identifier" % (api, facts)) \
            if re.search(re.escape(api), text) else \
            print("%-46s points at %s, which never mentions it" % (api, facts))
PY
}

# THE RED CONTROL: a copy of the registry with one row's pointer made to lead nowhere, and one with
# it removed, and BOTH must be named. A check that cannot go red proves nothing.
if [ -n "${SELF_TEST:-}" ]; then
    selfreg="$work/registry.json"
    cp "$reg" "$selfreg"
    python3 - "$selfreg" "$factsroot" <<'PY2'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
rows = [r for r in doc["entries"] if r.get("status") == "implemented" and r.get("facts")]
assert len(rows) >= 3, "the control needs three implemented rows with a pointer"
doc["_control_missing_file"] = rows[0]["api"]
doc["_control_no_pointer"] = rows[1]["api"]
rows[0]["facts"] = "facts/Metal/NoSuchFile.md"
rows[1].pop("facts", None)
# THE THIRD NEGATIVE, and it is the reviewer's own case: a row re-pointed at a REAL file that
# names the row's API only INSIDE a longer identifier - Heaps.md names
# MTLAccelerationStructureCommandEncoder, which contains MTLAccelerationStructure. A bare substring
# test passes that; only an identifier-boundary match refuses it. The file is found rather than
# hard-coded, by the property the control needs: it names a longer identifier built from the row's
# API, and does not name the row's own API on a boundary.
import glob, os, re as _re
# Find the PAIR by the property the control needs, not by guessing a row: a row whose API, with
# "CommandEncoder" appended, is named by some facts file that does NOT name the row's own API on a
# boundary. MTLAccelerationStructure and Heaps.md are such a pair - Heaps.md names
# MTLAccelerationStructureCommandEncoder and never MTLAccelerationStructure on its own - and that is
# the reviewer's case, but nothing here is written down for it.
row = None
for candidate in rows:
    api = candidate["api"]
    longer = api + "CommandEncoder"
    for cand in sorted(glob.glob(os.path.join(sys.argv[2], "**", "*.md"), recursive=True)):
        text = open(cand, encoding="utf-8", errors="replace").read()
        if _re.search(_re.escape(longer), text) and not _re.search(
                r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % _re.escape(api), text):
            row, found = candidate, cand
            break
    if row:
        break
assert row, "the control needs a row named only inside a longer identifier somewhere"
row["facts"] = os.path.relpath(found, os.path.dirname(os.path.dirname(sys.argv[2])))
doc["_control_substring"] = row["api"]
doc["_control_substring_file"] = row["facts"]
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
PY2
    miss=$(python3 -c "import json;d=json.load(open('$selfreg'));print(d['_control_missing_file'])")
    none=$(python3 -c "import json;d=json.load(open('$selfreg'));print(d['_control_no_pointer'])")
    out=$(broken "$selfreg" "$pkg" || true)
    printf '%s\n' "$out" | grep -q "$miss" || {
        echo "FAIL: the control's missing-file row was not named" >&2; exit 1; }
    echo "  ok   the self-test's NEGATIVE 1: a pointer to a file that does not exist is named"
    printf '%s\n' "$out" | grep -q "$none" || {
        echo "FAIL: the control's pointer-less row was not named" >&2; exit 1; }
    echo "  ok   the self-test's NEGATIVE 2: an implemented row with no pointer is named"
    sub=$(python3 -c "import json;d=json.load(open('$selfreg'));print(d['_control_substring'])")
    printf '%s\n' "$out" | grep -q "$sub" || {
        echo "FAIL: the control's substring row was not named" >&2; exit 1; }
    echo "  ok   the self-test's NEGATIVE 3: a row named only inside a longer identifier is named"
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
count=$(python3 -c "
import json
d = json.load(open('$reg', encoding='utf-8'))
print(sum(1 for r in d['entries'] if r.get('status') == 'implemented'))")
echo "  every implemented row's facts pointer leads to a file that mentions it: $count row(s)"
echo "check-facts-pointers: OK"
# THE SCRATCH IS REMOVED HERE.
rm -rf "$work"
