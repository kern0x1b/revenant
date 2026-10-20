#!/bin/sh
# protocol-check.sh - can a caller find every protocol this library's registry claims, by the name the
# registry gives it?
#
# Two things come from the registry and nothing comes from a copy in this file:
#
#   * the NAMES, read out of registry/Accessibility's rows of kind "protocol" and status "implemented"
#     with python3, one macro each, into names.h;
#   * the SOURCES, written by modules/apple/backports.lua's own protocol_sources() - the function the
#     build calls, with the build's argument order - and compiled as it wrote them, one file per release.
#
# That is what makes a row naming a protocol that does not exist turn this red. The generated source for
# such a row is a forward reference, which clang makes a label and which links cleanly, so nothing in the
# build or the link complains; the name is in the binary and no caller can find it. So the check looks up
# every name the registry holds, and a name that does not resolve is the failure. The control is a name
# the registry does not hold, which must answer nil - without it, a check that said yes to everything
# would pass.
#
# It is a port-only program and not a second half of the differential, and the reason is recorded as an
# owed line in this directory's README.md rather than in a comment: see there.
set -eu
echo "FAIL host/accessibilitymap/protocol-check.sh: its Python steps are gone and not yet ported to Lua: the inline block PYTHON at line 38" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
. "$here/../../common/generated.sh"
ensure_generated "$here" Accessibility
root=$(cd "$here/../../../.." && pwd)
sources=${ACCESSIBILITY_SRC:-$root/packages/a/apple-backports/Accessibility}
registry=${REGISTRY_ROOT:-$root/packages/a/apple-backports}
build=${PROTOCOL_BUILD:-$(runs_folder revenant-accessibilitymap-protocol)}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)

# The names, from the registry. A copy of the registry is read when REGISTRY_ROOT points at one, which is
# how the rename mutant changes one and nothing else.
python3 - "$registry/registry/Accessibility" "$build/names.h" <<'PYTHON'
import glob, json, os, sys
folder, header = sys.argv[1], sys.argv[2]
rows = []
for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
    for row in json.load(open(path)).get("entries", []):
        if row.get("kind") == "protocol" and row.get("status") == "implemented":
            rows.append(row["api"])
with open(header, "w") as out:
    out.write("// Written by protocol-check.sh from registry/Accessibility's protocol rows, so that this check\n")
    out.write("// asks about what the registry claims. One macro per implemented protocol row.\n")
    out.write("#import <Foundation/Foundation.h>\n\n")
    out.write("#define REVENANT_PROTOCOLS @[%s]\n" % ", ".join('@"%s"' % n for n in rows))
    out.write("#define REVENANT_PROTOCOL_COUNT %d\n" % len(rows))
print("registry protocol rows read: %d" % len(rows))
for index, name in enumerate(rows, 1):
    print("  [%d] %s" % (index, name))
PYTHON

# The sources, from the build's own generator, every file it writes and none renamed into another: the
# first attempt at this collapsed them onto one name and silently dropped the 15.0 protocols.
(cd "$root" && xmake l tests/backports/host/accessibilitymap/protocol-names.lua \
    "$registry" "$build/generated" "$root/modules" > "$build/generated.log")
cat "$build/generated.log"
sources_m=$(ls "$build/generated"/*.m)

xcrun clang -target arm64-apple-macos26.0 -isysroot "$sdk" -fobjc-arc -O0 -Wall -Wno-nonnull \
    -include "$sources/RevenantBrailleMap.h" \
    "$here/protocol-check.m" "$sources/RevenantBrailleMap.m" $sources_m \
    -I"$root/packages/a/apple-backports" -I"$sources" -I"$build" -I"$root/packages/a/apple-backports/.gen/Accessibility" \
    -framework Foundation -framework CoreGraphics -o "$build/protocol" 2> "$build/build.log" || {
        echo "the protocol check did not build" >&2
        tail -20 "$build/build.log" >&2
        exit 1
    }
"$build/protocol"
