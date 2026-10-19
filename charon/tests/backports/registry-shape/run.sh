#!/bin/sh
# registry-shape's own run. Three things, and each of them must fail loudly if it is not true:
#
#   1. a known-good framework passes, with a nonzero count of rows examined;
#   2. a mutant with one class row planted implemented that nothing answers - no class, no member, no
#      symbol, no registered name, and no header of the package declaring it - is caught and named;
#   3. a mutant with one constant row planted implemented whose name the band's own exports do not
#      carry is caught and named.
#
#   sh tests/backports/registry-shape/run.sh <gate-output-dir> [FRAMEWORK] [TREE]
#
# TREE is the tree the gate gated; the check refuses to run without it, and the gate log's own tree
# line is what it compares against, so a gate output from another tree cannot be read as this one's.
#
# The gate's own output directory is the input, so this runs straight after a band's own gate. The
# mutants change the registry and nothing else: the tree is symlinked to the real one beside a copied
# registry, so no file of anyone's is touched and no worktree is needed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tree=$(cd "$here/../../.." && pwd)
gate=$(cd "$1" && pwd)
framework=${2:-GameController}
tree=${3:-$tree}
build=${BUILD:-$tree/.agent-work/registry-shape}
mkdir -p "$build"

echo "== the real tree, which must pass"
python3 "$here/registry-shape.py" "$gate" --tree "$tree" --build "$build" "$framework" || {
    echo "self-test: the real tree failed, and a check that fails on a good tree is not a check"
    exit 1
}

mutant="$build/mutant"
port="$tree/packages/a/apple-backports"
rm -rf "$mutant"
mkdir -p "$mutant/packages/a/apple-backports/registry/$framework"
ln -s "$port/$framework" "$mutant/packages/a/apple-backports/$framework"
# the modules the reader imports, by symlink: the mutant changes the registry and nothing else
ln -s "$tree/modules" "$mutant/modules"
for header in "$port"/*.h; do
    [ -e "$header" ] && ln -s "$header" "$mutant/$(basename "$header")"
done
copy_registry() {
    rm -f "$mutant/packages/a/apple-backports/registry/$framework/"*.json
    for f in "$port/registry/$framework/"*.json; do
        cp "$f" "$mutant/packages/a/apple-backports/registry/$framework/"
    done
}
copy_registry

plant() {
    python3 - "$mutant" "$framework" "$1" "$2" "$3" <<'PYEOF'
import json, os, sys
tree, framework, api, kind, status = sys.argv[1:6]
folder = tree + "/packages/a/apple-backports/registry/" + framework
target = None
for name in sorted(os.listdir(folder)):
    if name.startswith("absent_"):
        target = os.path.join(folder, name)
if target is None:
    target = os.path.join(folder, "absent_%s.json" % framework)
held = json.load(open(target)) if os.path.exists(target) else {"framework": framework, "entries": []}
for entry in held["entries"]:
    if entry["api"] == api:
        entry["kind"], entry["status"] = kind, status
        break
else:
    held["entries"].append({"api": api, "kind": kind, "introduced": "7.0",
                            "status": status, "reason": "planted by run.sh"})
json.dump(held, open(target, "w"), indent=1)
print(f"planted {api} as {kind} {status}")
PYEOF
}

expect() {
    grep -q "$1" "$build/$2" || { echo "self-test: the mutant was not caught the way it should have:"; cat "$build/$2"; exit 1; }
    grep -q "$3" "$build/$2" || { echo "self-test: the mutant failed without naming the row"; cat "$build/$2"; exit 1; }
    sed -n "/$1/,+1p" "$build/$2" | sed 's/^/  /'
}

echo
echo "== a mutant: a class row planted implemented that nothing answers"
copy_registry
# a name in no library, no header, and no literal: nothing can answer it
plant "ZZNoClassAnywhereCarriesThisName" class implemented
if python3 "$here/registry-shape.py" "$gate" --tree "$mutant" --build "$build/mutant-build" "$framework" \
        > "$build/mutant-class.log" 2>&1; then
    echo "self-test: a class row listed implemented that nothing builds was NOT caught"
    exit 1
fi
expect "listed as implemented, but nothing of that name is built: 1" mutant-class.log ZZNoClassAnywhereCarriesThisName

echo
echo "== a mutant: a constant row planted implemented that the band's own exports do not carry"
copy_registry
plant "ZZNoConstantAnywhereIsExported" constant implemented
if python3 "$here/registry-shape.py" "$gate" --tree "$mutant" --build "$build/mutant-build" "$framework" \
        > "$build/mutant-constant.log" 2>&1; then
    echo "self-test: a constant row listed implemented that nothing builds was NOT caught"
    exit 1
fi
expect "listed as implemented, but nothing of that name is built: 1" mutant-constant.log ZZNoConstantAnywhereIsExported

echo
echo "== a mutant: a class row planted absent that the library does answer"
copy_registry
answered=$(python3 - "$gate" "$framework" "$build" <<'PYEOF'
import subprocess, sys
gate, framework, build = sys.argv[1:4]
out = subprocess.run(["xmake", "l", "tests/backports/registry-shape/found.lua", ".", gate + "/lib" + framework + "Backports.dylib",
                      "armv7", build + "/self-test-found.tsv"], capture_output=True, text=True)
for line in open(build + "/self-test-found.tsv", "rb"):
    kind, _, name = line.rstrip(b"\n").partition(b"\t")
    if kind == b"C" and name.startswith(b"GC"):
        print(name.decode())
        break
PYEOF
)
[ -n "$answered" ] || { echo "self-test: no class name to plant; the gate's library for $framework read nothing"; exit 1; }
plant "$answered" class absent
if python3 "$here/registry-shape.py" "$gate" --tree "$mutant" --build "$build/mutant-build" "$framework" \
        > "$build/mutant-absent.log" 2>&1; then
    echo "self-test: a class row listed absent that the library answers was NOT caught"
    exit 1
fi
expect "listed as absent, but what is built answers it: 1" mutant-absent.log "$answered"

rm -rf "$mutant"

# ---- the two regression cases ------------------------------------------------------------------------------------
# Both of these bugs were found in this check and neither has a test unless one is written here: a
# check that found two bugs and guards neither regresses silently. Each case puts the bug back into a
# scratch COPY of the tool - the copy carries found.lua and exports.lua beside it, so the reader
# directory is right and nothing in the tree is touched - and requires the check to go RED on a tree
# the real tool calls green.

buggy_tool() {
    rm -rf "$build/bug-tool"
    mkdir -p "$build/bug-tool"
    cp "$here/registry-shape.py" "$here/found.lua" "$here/exports.lua" "$build/bug-tool/"
    python3 - "$build/bug-tool/registry-shape.py" "$1" "$2" <<'PYEOF'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if old not in text:
    sys.exit("the text to put the bug back into is not in the tool: the case is stale")
open(path, "w").write(text.replace(old, new, 1))
PYEOF
    echo "put the bug back into a scratch copy: $1"
}

echo
echo "== the regression case for read_found reading bytes keys against string keys"
# With this, every kind byte fails the membership test, so found.classes, found.symbols,
# found.registered and found.answered all read as empty and every implemented row of those kinds
# reads as unbuilt. Measured with the bug put back, on this tree's UIKit: 0 classes, 0 symbols,
# 0 registered names, and 731 rows listed implemented that nothing builds.
buggy_tool '        key = kind.decode("ascii", "replace")
        if key in sets:
            sets[key].add' \
          '        if kind in sets:
            sets[kind].add'
if python3 "$build/bug-tool/registry-shape.py" "$gate" --tree "$tree" --build "$build/bug-build" UIKit \
        > "$build/regression-read-found.log" 2>&1; then
    echo "self-test: the bytes-versus-strings bug is NOT caught: the buggy copy passed"
    exit 1
fi
grep -q "UIKit: .*, 0 classes, 0 symbols, 0 registered names" "$build/regression-read-found.log" || {
    echo "self-test: the buggy copy failed, but not the way this case is about:"; cat "$build/regression-read-found.log"; exit 1; }
grep -q "listed as implemented, but nothing of that name is built: [1-9]" "$build/regression-read-found.log" || {
    echo "self-test: the buggy copy read nothing built but still called every row built"; exit 1; }
sed -n '/^UIKit: /p' "$build/regression-read-found.log" | sed 's/^/  /'
sed -n '/listed as implemented/p' "$build/regression-read-found.log" | sed 's/^/  /'
rm -rf "$build/bug-tool"

echo
echo "== the regression case for the exports exemption reading the loop's last name"
# With this, the exemption looks up the last row's name instead of its own, so every row exempt only
# because the band's own exports carry it is reported as unbuilt. Measured with the bug put back:
# UIKit's three CG names and four UIAccessibility notification names all read as unbuilt.
buggy_tool '        bare = re.sub(r"\(\)$", "", api)      # this row'"'"'s own name, not the loop'"'"'s last' \
          '        bare = LAST_BARE_PLACEHOLDER'
python3 - "$build/bug-tool/registry-shape.py" <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path).read()
# drop the per-row line and leave the loop's last value in place, which is what the bug was
text = text.replace('        bare = LAST_BARE_PLACEHOLDER\n', '', 1)
open(path, "w").write(text)
PYEOF
if python3 "$build/bug-tool/registry-shape.py" "$gate" --tree "$tree" --build "$build/bug-build" UIKit \
        > "$build/regression-exports.log" 2>&1; then
    echo "self-test: the last-name bug is NOT caught: the buggy copy passed"
    exit 1
fi
grep -q "UIAccessibilityClosedCaptioningStatusDidChangeNotification" "$build/regression-exports.log" || {
    echo "self-test: the buggy copy failed, but not on the row this case is about:"; cat "$build/regression-exports.log"; exit 1; }
sed -n '/listed as implemented/,+1p' "$build/regression-exports.log" | sed 's/^/  /'
rm -rf "$build/bug-tool"

echo
echo "== a mutant: a row whose minimum is above every deployment, which the check drops in silence"
# the three mutants above ended by removing the farm, so it is made again here
mkdir -p "$mutant/packages/a/apple-backports/registry/$framework"
ln -sf "$port/$framework" "$mutant/packages/a/apple-backports/$framework"
ln -sfn "$tree/modules" "$mutant/modules"
for header in "$port"/*.h; do
    [ -e "$header" ] && [ ! -e "$mutant/$(basename "$header")" ] && ln -s "$header" "$mutant/$(basename "$header")"
done
copy_registry
python3 - "$mutant" "$framework" <<'PYEOF'
import json, os, sys
tree, framework = sys.argv[1], sys.argv[2]
folder = tree + "/packages/a/apple-backports/registry/" + framework
for name in sorted(os.listdir(folder)):
    if not name.startswith("absent_"):
        continue
    path = os.path.join(folder, name)
    held = json.load(open(path))
    for entry in held["entries"]:
        if entry["api"] == "ZZNoClassAnywhereCarriesThisName":
            entry["kind"], entry["status"], entry["minimum"] = "class", "implemented", "99.0"
            break
    else:
        held["entries"].append({"api": "ZZNoClassAnywhereCarriesThisName", "kind": "class",
                                "introduced": "7.0", "minimum": "99.0", "status": "implemented",
                                "reason": "planted by run.sh"})
    json.dump(held, open(path, "w"), indent=1)
    print("planted ZZNoClassAnywhereCarriesThisName as class implemented with minimum 99.0")
    break
PYEOF
python3 "$here/registry-shape.py" "$gate" --tree "$tree" --build "$build" "$framework" > "$build/clean-tree.log" 2>&1
# a row the deployment is not asked about is correctly not a failure, so what this case requires is
# that it is NAMED and that the run's output differs from the clean tree's - a minimum typed wrong
# then shows up as a row nobody examined, instead of hiding an API in silence
python3 "$here/registry-shape.py" "$gate" --tree "$mutant" --build "$build/mutant-build" "$framework" \
        > "$build/mutant-range.log" 2>&1 || true
grep -q "note: rows this deployment is not asked about, dropped by in_range" "$build/mutant-range.log" || {
    echo "self-test: the minimum-99.0 row was not named as dropped"; cat "$build/mutant-range.log"; exit 1; }
grep -q "ZZNoClassAnywhereCarriesThisName" "$build/mutant-range.log" || {
    echo "self-test: the note did not name the dropped row"; cat "$build/mutant-range.log"; exit 1; }
if cmp -s "$build/clean-tree.log" "$build/mutant-range.log"; then
    echo "self-test: the minimum-99.0 mutant produced output identical to the clean tree"
    exit 1
fi
sed -n '/note: rows this deployment/,+1p' "$build/mutant-range.log" | sed 's/^/  /'

echo
echo "== the copies in found.lua, against the current backports.lua"
# the check compares the copies against the TREE's backports.lua, and the copies are the tool's own,
# so the tool's tree is the one that answers
python3 "$here/lines-copied.py" "$here/../../.." || exit 1

echo
echo "== and the real tool on the same tree and framework, which must be green again"
python3 "$here/registry-shape.py" "$gate" --tree "$tree" --build "$build" UIKit | tail -5 | sed 's/^/  /'

echo
echo "self-test: the real tree passed with a nonzero count, all three mutants and the out-of-range mutant were caught and named, both regression cases caught their bug, and every copy still matches the current backports.lua"
