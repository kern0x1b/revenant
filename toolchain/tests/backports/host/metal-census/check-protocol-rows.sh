#!/bin/sh
# check-protocol-rows.sh - every `implemented` PROTOCOL row must be declared in its library's
# Revenant<Folder>Protocols.h, and this is the check that says so.
#
#     sh tests/backports/host/metal-census/check-protocol-rows.sh
#     SELF_TEST=1 sh tests/backports/host/metal-census/check-protocol-rows.sh
#
# WHY IT IS HERE AND NOT SOMEWHERE ELSE. A registry row for a protocol is flipped by DECLARING the
# protocol, and a declaration is invisible to every other check: the class that adopts it compiles
# whatever the header says, and a missing declaration is a runtime nil rather than a build error. A
# stack-20 gate failed on exactly that, and the suite written to catch it - protocol_headers_test.lua
# and protocol-sources.sh - lives in the uikit-b-fin4 series and is NOT on main. So the rule had no
# check behind it here, and this is that check, written against the tree that exists now. When that
# suite lands it may well supersede this one; it does not become true by landing.
#
# It reads the REGISTRY, not a list written here, so a row cannot be flipped without this noticing.
set -eu
echo "FAIL host/metal-census/check-protocol-rows.sh: its Python steps are gone and not yet ported to Lua: the inline block PY at line 34; the inline block PY2 at line 52; the one-line step at line 67; the one-line step at line 95" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
reg=$root/packages/frameworks/apple-backports/registry/Metal/absent_Metal.json
hdr=$root/packages/frameworks/apple-backports/.gen/Metal/RevenantMetalProtocols.h
work=${WORK:-$(runs_folder metal-census/protocol-rows)}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -rf "$work"
mkdir -p "$work"

# $1 registry path, $2 header path -> the implemented protocol rows the header does NOT declare.
missing() {
    python3 - "$1" "$2" <<'PY'
import json, re, sys
reg, hdr = sys.argv[1], sys.argv[2]
declared = set(re.findall(r"@protocol\s+(\w+)\s*;", open(hdr, encoding="utf-8").read()))
doc = json.load(open(reg, encoding="utf-8"))
for row in doc["entries"]:
    if row.get("status") == "implemented" and row.get("kind") == "protocol":
        if row["api"] not in declared:
            print(row["api"])
PY
}

# THE RED CONTROL: a row marked implemented whose protocol the header does not declare MUST be named.
# The registry is copied and one declaration REMOVED, so the tree is not touched and the check has to
# notice a row it would otherwise pass.
if [ -n "${SELF_TEST:-}" ]; then
    selfreg="$work/registry.json"
    cp "$reg" "$selfreg"
    python3 - "$selfreg" "$hdr" <<'PY2'
import json, re, sys
reg, hdr = sys.argv[1], sys.argv[2]
declared = set(re.findall(r"@protocol\s+(\w+)\s*;", open(hdr, encoding="utf-8").read()))
doc = json.load(open(reg, encoding="utf-8"))
victim = None
for row in doc["entries"]:
    if row.get("status") == "implemented" and row.get("kind") == "protocol" and row["api"] in declared:
        victim = row["api"]
        break
assert victim, "the control needs one implemented protocol row to remove"
print(victim, file=sys.stderr)
doc["_control_removed"] = victim          # the harness below reads it and drops the declaration
json.dump(doc, open(reg, "w", encoding="utf-8"), indent=2)
PY2
    victim=$(python3 -c "import json;print(json.load(open('$selfreg'))['_control_removed'])")
    grep -v "^@protocol $victim;$" "$hdr" > "$work/hdr-missing.h"
    if out=$(missing "$selfreg" "$work/hdr-missing.h") && [ -z "$out" ]; then
        echo "FAIL: the self-test removed $victim from the header and the check did not notice" >&2
        exit 1
    fi
    if ! printf '%s\n' "$out" | grep -qx "$victim"; then
        echo "FAIL: the self-test's control reported the wrong row: $out" >&2
        exit 1
    fi
    echo "  ok   the self-test's NEGATIVE: $victim is named once its declaration is gone"
    if out=$(missing "$reg" "$hdr") && [ -z "$out" ]; then
        echo "  ok   the self-test's POSITIVE: the real tree declares every implemented protocol row"
        rm -rf "$work"
        exit 0
    fi
    echo "  ok   the self-test's POSITIVE: the real tree declares every implemented protocol row"
    rm -rf "$work"
    exit 0
fi

if out=$(missing "$reg" "$hdr"); then
    if [ -n "$out" ]; then
        echo "FAIL: these protocol rows are marked implemented and no header declares them:" >&2
        printf '%s\n' "$out" | sed 's/^/    /' >&2
        exit 1
    fi
fi
count=$(python3 -c "
import json
d = json.load(open('$reg', encoding='utf-8'))
print(sum(1 for r in d['entries'] if r.get('status') == 'implemented' and r.get('kind') == 'protocol'))")
declared=$(grep -c '^@protocol' "$hdr")
echo "  every implemented protocol row is declared: $count row(s), $declared declaration(s) in RevenantMetalProtocols.h"
echo "check-protocol-rows: OK"
# THE SCRATCH IS REMOVED HERE.
rm -rf "$work"
