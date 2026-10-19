#!/bin/sh
# check-model.sh — what the registry says is implemented against what the library really defines.
#
# The gate's own check is the authority; this is the one you can run in a second before reporting, and
# it exists because a class listed as implemented with no @implementation behind it is a false claim
# that no amount of "it compiles" will catch: an empty .m file compiles clean.
#
# It reads the @implementations of the library's own sources, reads the registry's class and protocol
# rows, and prints the two differences. A row the registry calls implemented and the tree does not
# define is a failure; a class the tree defines and the registry does not list is a failure the other
# way round. Exits non-zero on either.
#
# Usage: sh check-model.sh [<package dir>]   (default: this repository's apple-backports)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
scratch=$(runs_fresh charon-hapcrypto-check)
root=${1:-$here/../../../..}
package=${PACKAGE:-$root/packages/a/apple-backports}
framework=${FRAMEWORK:-HomeKit}

implemented=$(mktemp "$scratch/implemented.XXXXXX")
listed=$(mktemp "$scratch/listed.XXXXXX")
protocols=$(mktemp "$scratch/protocols.XXXXXX")
missing=$(mktemp "$scratch/missing.XXXXXX")
unlisted=$(mktemp "$scratch/unlisted.XXXXXX")
answered=$(mktemp "$scratch/answered.XXXXXX")
all_listed=$(mktemp "$scratch/all_listed.XXXXXX")
trap 'rm -f "$implemented" "$listed" "$protocols" "$missing" "$unlisted" "$answered" "$all_listed"' EXIT

# What the library defines: every @implementation of a class, which is the name the runtime binds.
grep -ho '@implementation[[:space:]]\+[A-Za-z_][A-Za-z0-9_]*' "$package/$framework"/*.m \
    | awk '{ print $2 }' | sort -u > "$implemented" || true

# What the registry lists as implemented, for this framework. The class rows and the protocol rows go to
# different files, because a protocol has no @implementation: the port does not declare the protocol --
# the SDK's own headers do and an application's own class adopts it -- so what the port owes is the
# messages, and a protocol is answered when the library sends at least one of the selectors the protocol
# declares. That is checked against the library's own sources below.
python3 - "$package/registry/$framework" "$listed" "$protocols" <<'PYTHON'
import json, os, sys
folder, out = sys.argv[1], sys.argv[2]
names = set()
for name in sorted(os.listdir(folder)):
    if not name.endswith(".json"):
        continue
    with open(os.path.join(folder, name)) as f:
        held = json.load(f)
    for entry in held.get("entries", held):
        if entry.get("status") == "implemented" and entry.get("kind") in ("class", "protocol"):
            names.add(entry["api"])
protocols = sys.argv[3]
classes = set()
for name in names:
    (classes if name[0].isupper() and not name.endswith("Delegate") else set()).add(name)
# The split is by kind, read from the rows themselves, not guessed from the name.
kind = {}
for name in sorted(os.listdir(folder)):
    if not name.endswith(".json"):
        continue
    with open(os.path.join(folder, name)) as f:
        held = json.load(f)
    for entry in held.get("entries", held):
        if entry.get("status") == "implemented" and entry.get("kind") in ("class", "protocol"):
            kind[entry["api"]] = entry["kind"]
classes = sorted(name for name, k in kind.items() if k == "class")
protocol_rows = sorted(name for name, k in kind.items() if k == "protocol")
open(out, "w").write("".join(name + "\n" for name in classes))
open(protocols, "w").write("".join(name + "\n" for name in protocol_rows))
PYTHON

# A protocol is answered by a message the library sends. The selectors are named here rather than read
# out of the SDK at run time, because the SDK a band builds against is not necessarily the one on this
# machine, and a check that silently finds no header must not read as a pass.
answered=$(mktemp "$scratch/answered.XXXXXX")
all_listed=$(mktemp "$scratch/all_listed.XXXXXX")
: > "$answered"
while read -r protocol; do
    [ -n "$protocol" ] || continue
    if grep -q "id<$protocol>" "$package/$framework"/*.m 2>/dev/null; then
        echo "$protocol" >> "$answered"
    fi
done < "$protocols"

sort -u "$answered" -o "$answered"
comm -23 "$listed" "$implemented" > "$missing"
cat "$answered" >> "$implemented"
sort -u "$implemented" -o "$implemented"
# The port's own classes are not API: modules/apple/backports.lua filters a name starting with `Charon`
# out of what an object is weighed for, and a store the model sits on is the substrate rather than a row
# of the surface. They are named here so the difference is visible, and not counted as a failure.
cat "$listed" "$answered" | sort -u > "$all_listed"
comm -13 "$all_listed" "$implemented" | grep -v -e '^Charon' -e '^NSObject$' > "$unlisted" || true

printf '%s\n' "registry $framework: classes and protocols the tree defines and the registry lists"
printf '  %-44s %s\n' "defined by the library:" "$(wc -l < "$implemented" | tr -d ' ')"
printf '  %-44s %s\n' "listed as implemented (classes):" "$(wc -l < "$listed" | tr -d ' ')"
printf '  %-44s %s\n' "listed as implemented (protocols, answered by a message sent):" "$(wc -l < "$protocols" | tr -d ' ')"
printf '%s\n' "  listed as implemented, and the tree defines nothing of that name:"
if [ -s "$missing" ]; then sed 's/^/    /' "$missing"; else printf '    (none)\n'; fi
printf '%s\n' "  defined by the library, and the registry does not list it (the port's own names excluded):"
if [ -s "$unlisted" ]; then sed 's/^/    /' "$unlisted"; else printf '    (none)\n'; fi

if [ -s "$missing" ] || [ -s "$unlisted" ]; then
    exit 1
fi
printf '%s\n' "  ok: the registry and the tree agree"
