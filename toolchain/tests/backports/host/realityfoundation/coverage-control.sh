#!/bin/sh
# The guard's own control: three assertions, and every one of them fails the suite if it does not hold.
#
#   1. the pre-repair guard - the tracked fixture beside this script - accepts a tree where a row the
#      differential measures says nothing measures it. That is the r3 bug, kept as a fixture so the
#      comparison cannot drift with the history: `git show HEAD:`, which r4 used, names the repair
#      commit itself and so compared the repaired guard with itself while claiming otherwise.
#   2. the real guard rejects that same tree.
#   3. and the rows it flags are exactly the covered ones.
#
# Nothing here echoes a failure and carries on. A premise that does not hold exits non-zero, because
# the r4 review's finding was a branch that only echoed and left the suite green on a comparison that
# was not the one it named.
#
# The pre-repair copy is built here, every implemented row carrying the declaration sentence, because
# that is the state the bug lived in and a repaired tree would make the fixture look wrong for the
# wrong reason.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../.." && pwd)
runs="$repo/.agent-work/runs/realityfoundation"
mkdir -p "$runs"
coverage="$here/coverage.py"
fixture="$here/coverage-guard-pre-repair.py"
registry="$repo/packages/s/swift-runtime/registry/RealityFoundation.json"
pre="$runs/control-pre-repair.json"

declaration_sentence="the declaration in packages/s/swift-runtime/files/, which tests/backports/host/swiftregistry holds to a name, and the interface line it was read from. No check in this series measures it"
cp "$registry" "$pre"
python3 - "$pre" "$declaration_sentence" <<'PY'
import json, sys
path, sentence = sys.argv[1], sys.argv[2]
document = json.load(open(path))
for entry in document["entries"]:
    if entry.get("status") == "implemented":
        entry["source"] = sentence
json.dump(document, open(path, "w"), indent=4)
open(path, "a").write("\n")
PY

covered=$(python3 "$coverage" "$registry" 2>/dev/null | grep -c '^covered  ' || true)
[ -n "$covered" ] || covered=0
echo "control: a copy where all $covered covered rows say no measurement"

# 1. the fixture must accept that tree: the bug, as shipped
python3 "$here/coverage-fixture-check.py" "$fixture" "$coverage" "$pre" > "$runs/control-fixture.txt" 2>&1 || {
    echo "PREMISE FAILED: the pre-repair fixture does not accept the pre-repair tree, so this control"
    echo "  is not comparing what it names. Fixture output:"
    sed 's/^/    /' "$runs/control-fixture.txt" | head -6
    exit 1
}
echo "  the pre-repair fixture accepts it: $(tail -1 "$runs/control-fixture.txt") - the bug, as shipped"

# 2. the real guard must reject that same tree
if python3 "$coverage" --check "$pre" > "$runs/control-real.txt" 2>&1; then
    echo "PREMISE FAILED: the real guard accepts a covered row that claims no measurement, which is"
    echo "  the r3 defect the fixture is here to demonstrate. Nothing to see."
    exit 1
fi
echo "  the real guard rejects it: $(grep -m 1 'whose source is not what this loop decides' "$runs/control-real.txt")"

# 3. and it must flag exactly the covered rows
flagged=$(grep -c '^  MISMATCH' "$runs/control-real.txt" || true)
[ -n "$flagged" ] || flagged=0
if [ "$flagged" != "$covered" ]; then
    echo "PREMISE FAILED: the real guard flags $flagged rows and the report calls $covered covered."
    echo "  Those are meant to be the same set, and they are not."
    exit 1
fi
echo "  and it flags $flagged rows, which is exactly the $covered the report calls covered"

rm -f "$pre"

# 4. and the original ask: a hand-edited row, red first, repaired by --write
copy="$runs/control-hand-edit.json"
cp "$registry" "$copy"
python3 - "$copy" <<'PY'
import json, sys
path = sys.argv[1]
document = json.load(open(path))
for entry in document["entries"]:
    if entry.get("status") == "implemented":
        entry["source"] = "HAND EDITED BY THE CONTROL: the host differential measures every one of these"
        break
json.dump(document, open(path, "w"), indent=4)
open(path, "a").write("\n")
PY
echo "control: a hand-edited row, red first"
if python3 "$coverage" --check "$copy" > "$runs/control-red.txt" 2>&1; then
    echo "PREMISE FAILED: --check exited 0 on a hand-edited row, so the guard is not guarding"
    exit 1
fi
echo "  --check exits non-zero, and says so: $(grep -m 1 'CLAIMS A MEASUREMENT' "$runs/control-red.txt" | sed 's/^ *//')"
python3 "$coverage" --write "$copy" > /dev/null 2>&1
if ! python3 "$coverage" --check "$copy" > "$runs/control-green.txt" 2>&1; then
    echo "PREMISE FAILED: --check is still failing after --write regenerated the row"
    exit 1
fi
echo "  --write regenerates it and --check exits 0"
rm -f "$copy"
echo "control: OK - the fixture accepts what the real guard rejects, and both arms of the guard hold"
