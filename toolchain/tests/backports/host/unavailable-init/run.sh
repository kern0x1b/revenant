#!/bin/sh
# run.sh - the -init and +new that the SDK 26.2 headers of these frameworks close with NS_UNAVAILABLE,
# held to what Apple's own class was measured to do about them.
#
#   1. probe.m asks the host's own framework, ONE CLASS PER PROCESS: is the selector in the class's own
#      method list (the corpus row's question), and what does a caller reach at run time (the behaviour).
#      One process per class because a class's -init can take the host down - measured, PKIdentityElement,
#      PKIdentityIntentToStore, PKIssuerProvisioningExtensionPassEntry and PKVehicleConnectionSession all
#      die with SIGSEGV when initialised directly - and a probe that stopped at the first of those would
#      answer one class and call it a measurement.
#   2. check_host.py holds that against expectations.tsv, per framework, for the rows whose oracle is the
#      host. A difference means the oracle moved, which is the one thing the table exists to notice.
#   3. check_port.py holds the PORT to the same table, per framework: where Apple's class defines a
#      selector, the class's @implementation block must answer with the macro the table names and the
#      compiled object must carry it; where Apple's class carries neither, the block must not define it
#      and the object must not carry it.
#   4. the plants, each of which must turn step 3 red, and the check's own control.
#
# A framework with no host binary at all - HomeKit, whose directory holds only PlugIns - has no host half
# and its rows carry `ios16` as their oracle: the arm64e cache of iOS 16.0, which is a real release's own
# metadata and answers the row's question. There is NO test on the framework path before the probe runs,
# on purpose: this OS ships these frameworks out of the dyld shared cache and there is no file under
# /System/Library/Frameworks/<F>.framework/<F> at all (measured 2026-10-03: the binary comes from the
# cache, the symlink dangles, and dlopen of the same path succeeds). dlopen is the question.
set -eu
echo "FAIL host/unavailable-init/run.sh: its Python steps are gone and not yet ported to Lua: the inline block PY at line 47; check_host.py; check_port.py; the inline block PY2 at line 117; plants.py" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
charon=${REVENANT:-$here/../../../..}
charon=$(cd "$charon" && pwd)
appledir="$charon/packages/frameworks/apple-backports"
build=${BUILD:-$(runs_fresh revenant-unavailable-init)}
mkdir -p "$build"
survived=0

cc=$(ls -d "$HOME"/.xmake/packages/l/llvm/*/*/bin/clang 2>/dev/null | head -1)
sdk=${BP_SDK:-$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/iPhoneOS16.4.sdk | head -1)}
if [ -z "$cc" ] || [ -z "$sdk" ]; then
    echo "FAIL no pinned toolchain: expected clang under \$HOME/.xmake/packages/l/llvm/*/*/bin and the"
    echo "     iPhoneOS 16.4 SDK the port builds against (BP_SDK, or the iphoneos-sdk package under $HOME/.xmake)."
    exit 1
fi

# The frameworks, the classes and the sources and objects to check are the table's rows, not a list
# written twice. A framework named on the command line wins over the table's own set.
python3 - "$here/expectations.tsv" "$build" "$@" <<'PY'
import os
import sys
table, outdir, asked = sys.argv[1], sys.argv[2], sys.argv[3:]
header, rows = None, []
for line in open(table, encoding="utf-8"):
    if line.startswith("#") or not line.strip():
        continue
    fields = line.rstrip("\n").split("\t")
    if header is None:
        header = fields
        continue
    rows.append(dict(zip(header, fields)))
for name in (asked or sorted({r["framework"] for r in rows})):
    mine = [r for r in rows if r["framework"] == name]
    if not mine:
        continue
    for column, suffix in (("class", "classes"), ("port-source", "sources"), ("port-object", "objects")):
        seen = []
        for row in mine:
            if row[column] not in seen:
                seen.append(row[column])
        with open("%s/%s.%s" % (outdir, name, suffix), "w") as handle:
            handle.write("".join(value + "\n" for value in seen))
open("%s/frameworks" % outdir, "w").write("".join(
    name + "\n" for name in (asked or sorted({r["framework"] for r in rows})) if
    os.path.exists("%s/%s.classes" % (outdir, name))))
PY

echo "--- the host's own frameworks, one class per process, and the table each is held to"
xcrun clang -fobjc-arc -w "$here/probe.m" -framework Foundation -o "$build/probe"
for framework in $(cat "$build/frameworks"); do
    binary="/System/Library/Frameworks/$framework.framework/$framework"
    : > "$build/$framework.host"
    while read -r class; do
        [ -n "$class" ] || continue
        if ! echo "$class" | timeout 10 "$build/probe" "$binary" > "$build/one.out" 2>&1; then
            echo "CLASS $class did not survive the host: Apple's own class, asked directly"
        fi
        cat "$build/one.out" >> "$build/$framework.host"
    done < "$build/$framework.classes"
    python3 "$here/check_host.py" "$framework" "$build/$framework.host"
done

echo "--- the port: the source, the macro's own body, and the compiled armv7 objects"
for framework in $(cat "$build/frameworks"); do
    mkdir -p "$build/objects/$framework"
    for source in $(cat "$build/$framework.sources"); do
        "$cc" -target armv7-apple-ios6.1.3 -isysroot "$sdk" -I "$appledir" \
            -I "$appledir/$framework" -fobjc-arc -c "$appledir/$source" \
            -o "$build/objects/$framework/$(basename "$source").o" > "$build/cc.log" 2>&1 ||
            { echo "COMPILE FAILED for $source:"; cat "$build/cc.log"; exit 1; }
    done
    python3 "$here/check_port.py" "$appledir" "$build/objects/$framework" "$charon" "$framework"
done

# A plant is the port's own tree with one line changed, compiled and asked again. The framework, the file
# and the needle come from plants.py, which reads them out of the table, so a plant always applies to a
# row that exists.
plant() {
    label=$1; framework=$2; file=$3; from=$4; to=$5
    : > "$build/mutant-cc.log"
    rm -rf "$build/mutant"
    mkdir -p "$build/mutant/$framework"
    # Every header of the package and of the framework's own folder, rather than a list of the ones one
    # framework happened to need: a plant that does not build because a header was left behind proves
    # nothing, and the list is what left it behind (measured: RevenantHomeKitConstants.h).
    for header in "$appledir"/*.h; do cp "$header" "$build/mutant/"; done
    for header in "$appledir/$framework"/*.h; do cp "$header" "$build/mutant/$framework/"; done
    for source in $(cat "$build/$framework.sources"); do cp "$appledir/$source" "$build/mutant/$framework/"; done
    if ! python3 - "$build/mutant/$framework/$file" "$from" "$to" <<'PY2'
import sys
path, needle, replacement = sys.argv[1:4]
# plants.py writes a newline as the two characters \n so that one plant is one line of its output, so
# BOTH halves are put back before the file is read: unescaping only the replacement is what made every
# two-line needle report that it did not apply.
needle = needle.replace("\\n", "\n")
replacement = replacement.replace("\\n", "\n")
text = open(path, encoding="utf-8").read()
if needle not in text:
    sys.exit(1)
open(path, "w", encoding="utf-8").write(text.replace(needle, replacement, 1))
PY2
    then
        echo "MUTATION DID NOT APPLY: $label"
        survived=$((survived + 1))
        return
    fi
    built=$build/mutant/objects
    mkdir -p "$built"
    ok=1
    for source in $(cat "$build/$framework.sources"); do
        "$cc" -target armv7-apple-ios6.1.3 -isysroot "$sdk" -I "$build/mutant" \
            -I "$build/mutant/$framework" -fobjc-arc -c "$build/mutant/$framework/$(basename "$source")" \
            -o "$built/$(basename "$source").o" >> "$build/mutant-cc.log" 2>&1 ||
            { echo "=== $source" >> "$build/mutant-cc.log"; ok=0; }
    done
    if [ "$ok" = 0 ]; then
        echo "MUTANT DID NOT BUILD, which is not the same as being noticed: $label"
        grep -m 2 ": error:" "$build/mutant-cc.log" | cut -c1-140 | sed 's/^/  /'
        survived=$((survived + 1))
        return
    fi
    if python3 "$here/check_port.py" "$build/mutant" "$built" "$charon" "$framework" \
        > "$build/mutant.out" 2>&1; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "  caught: $(grep -m 1 '^FAIL' "$build/mutant.out" | cut -c1-110)"
    fi
}

echo "--- the plants"
while IFS="$(printf '\t')" read -r label framework file from to; do
    [ -n "${label:-}" ] || continue
    plant "$label" "$framework" "$file" "$from" "$to"
done <<PLANTS
$(python3 "$here/plants.py" "$here/expectations.tsv" "$appledir" $(cat "$build/frameworks"))
PLANTS

echo "--- the check's own control: an object carrying neither selector must not look green"
# The control needs a framework that owes a selector; HomeKit's twenty rows all say `none`, so for it
# there is nothing an empty object could contradict, and the control runs against one that owes. `nil` owes
# as much as `raise` does - the object's list has to carry the selector either way, which is the half of the
# check an empty object contradicts - so both count.
# Only among the frameworks THIS run built, which a subset run is: the control copies the objects of the
# framework it picks, and picking one this run did not build is a cp of nothing (measured: asking for
# AVFoundation alone picked HealthKit, whose objects were not built, and the control never ran).
control=$(awk -F'\t' -v built=" $(tr '\n' ' ' < "$build/frameworks")" \
    '($10 == "raise" || $10 == "nil") && index(built, " " $1 " ") { print $1; exit }' \
    "$here/expectations.tsv")
victim=$(awk -F'\t' -v f="$control" 'NR > 1 && $1 == f && ($10 == "raise" || $10 == "nil") { print $NF; exit }' \
    "$here/expectations.tsv")
: > "$build/empty.o"
rm -rf "$build/empty"
mkdir -p "$build/empty"
cp "$build/objects/$control"/*.o "$build/empty/"
cp "$build/empty.o" "$build/empty/$victim"
if python3 "$here/check_port.py" "$appledir" "$build/empty" "$charon" "$control" > "$build/empty.out" 2>&1; then
    echo "FAIL an object with no -init was accepted"
    survived=$((survived + 1))
else
    echo "  caught: $(grep -m 1 '^FAIL' "$build/empty.out" | cut -c1-110)"
fi

if [ "$survived" -ne 0 ]; then echo "$survived plants survived; this check proves nothing"; exit 1; fi
classes=$(cat "$build"/*.classes | grep -c .)
echo "unavailable-init: OK - $classes classes over $(tr '\n' ' ' < "$build/frameworks"), every plant noticed, the control red"
